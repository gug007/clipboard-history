import AppKit
import SwiftUI

private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class OverlayPanelController {
    private let panel: NSPanel
    private var hostingView: NSHostingView<OverlayView>!
    private let store: HistoryStore
    private let state: PanelState
    private var lastPasteAt: Date?
    private var focusLossObserver: NSObjectProtocol?
    private var outsideClickMonitor: Any?

    var isVisible: Bool { panel.isVisible }

    init(store: HistoryStore, state: PanelState) {
        self.store = store
        self.state = state

        let size = NSSize(width: 720, height: 480)
        panel = KeyablePanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isReleasedWhenClosed = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.hidesOnDeactivate = false

        let host = NSHostingView(rootView: OverlayView(
            store: store,
            state: state,
            onPaste: { _ in },
            onDismiss: {},
            onToggleFavorite: { _ in },
            onDelete: { _ in },
            onReveal: { _ in }
        ))
        host.translatesAutoresizingMaskIntoConstraints = false
        self.hostingView = host

        let container = NSView()
        container.addSubview(host)
        NSLayoutConstraint.activate([
            host.topAnchor.constraint(equalTo: container.topAnchor),
            host.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            host.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])
        panel.contentView = container

        host.rootView = OverlayView(
            store: store,
            state: state,
            onPaste: { [weak self] entry in self?.paste(entry) },
            onDismiss: { [weak self] in self?.hide() },
            onToggleFavorite: { [weak self] entry in self?.toggleFavorite(entry) },
            onDelete: { [weak self] entry in self?.delete(entry) },
            onReveal: { [weak self] entry in self?.revealInFinder(entry) }
        )

        applyAppearance()
        observeAppearance()
        observeFocusLoss()
    }

    func toggle() {
        guard panel.isVisible else {
            show()
            return
        }
        // A modal alert (New Group…, rename) is running on top of the
        // panel — hiding it from under the alert would strand the alert.
        guard NSApp.modalWindow == nil else { return }
        // The cursor sitting on the panel means the user sees it: dismiss.
        if panel.frame.contains(NSEvent.mouseLocation) {
            hide()
            return
        }
        // Visible but on a different screen than the user (e.g. left open on
        // another display): the user pressed the hotkey because they can't
        // see it — summon it instead of silently hiding it. While the panel
        // itself holds the keyboard, the AX focused-window signal points at
        // whatever app had focus before it opened — stale — so only a recent
        // mouse position can argue the user has moved to another screen;
        // otherwise this press is a plain dismiss.
        let target = panel.isKeyWindow
            ? (Self.mouseRecentlyUsed() ? Self.screen(nearest: NSEvent.mouseLocation) : nil)
            : Self.userScreen()
        if let target, panel.screen?.frame != target.frame {
            applyAppearance()
            center(on: target)
            panel.makeKeyAndOrderFront(nil)
        } else {
            hide()
        }
    }

    func show() {
        applyAppearance()
        if let target = Self.userScreen() {
            center(on: target)
        } else {
            panel.center()
        }
        panel.makeKeyAndOrderFront(nil)
    }

    private func applyAppearance() {
        switch AppSettings.shared.appearance {
        case .system: panel.appearance = nil
        case .light:  panel.appearance = NSAppearance(named: .aqua)
        case .dark:   panel.appearance = NSAppearance(named: .darkAqua)
        }
    }

    private func observeAppearance() {
        // withObservationTracking is one-shot — re-register after each fire.
        withObservationTracking {
            _ = AppSettings.shared.appearance
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                self?.applyAppearance()
                self?.observeAppearance()
            }
        }
    }

    private func observeFocusLoss() {
        // Spotlight-style dismissal: hide when the user's focus leaves the
        // app, so a forgotten panel can't sit on another display (where the
        // next hotkey press would toggle it *hidden*) or float over a
        // fullscreen Space the user switches into later.
        focusLossObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            // Defer one runloop turn so key-window state has settled, then
            // keep the panel if focus moved to another window of this app —
            // the NSAlert.runModal flows (New Group…, rename) take key
            // status while the panel must stay up behind them.
            DispatchQueue.main.async {
                guard let self else { return }
                guard self.panel.isVisible, !self.panel.isKeyWindow else { return }
                if NSApp.modalWindow != nil || NSApp.keyWindow != nil { return }
                self.hide()
            }
        }

        // The resign-key observer fires only for the panel itself, so a key
        // detour through another window of ours (alert, popover, status
        // menu) consumes it and the panel would linger after focus leaves
        // the app from there. Global monitors only see events delivered to
        // OTHER apps — clicks on our own windows never trigger this — so
        // any outside click while the panel is up means the user moved on.
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            guard let self, self.panel.isVisible else { return }
            if NSApp.modalWindow != nil { return }
            self.hide()
        }
    }

    deinit {
        if let focusLossObserver {
            NotificationCenter.default.removeObserver(focusLossObserver)
        }
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
        }
    }

    /// The screen the user is most plausibly looking at right now.
    ///
    /// Two signals are available and each one alone has shipped as a bug:
    /// the keyboard-focused window (wrong when a fullscreen app on another
    /// display still holds focus because focus follows clicks, not the
    /// mouse) and the cursor (wrong when the user types on one display with
    /// the mouse parked on another). When they disagree, trust whichever
    /// input device the user touched last: cursor if the mouse was used in
    /// the past few seconds, keyboard focus otherwise — which is also where
    /// the auto-paste ⌘V will land.
    private static func userScreen() -> NSScreen? {
        let cursorScreen = screen(nearest: NSEvent.mouseLocation)
        let focusScreen = screenOfFrontmostFocusedWindow()
        guard let focusScreen else {
            return cursorScreen ?? NSScreen.main ?? NSScreen.screens.first
        }
        guard let cursorScreen, cursorScreen.frame != focusScreen.frame else {
            return focusScreen
        }
        return mouseRecentlyUsed() ? cursorScreen : focusScreen
    }

    private static func mouseRecentlyUsed(within seconds: TimeInterval = 5) -> Bool {
        let types: [CGEventType] = [
            .mouseMoved, .leftMouseDown, .rightMouseDown, .otherMouseDown,
            .leftMouseDragged, .rightMouseDragged, .otherMouseDragged, .scrollWheel,
        ]
        return types.contains {
            CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0) < seconds
        }
    }

    /// Screen containing the point, tolerating the shared-edge exclusion of
    /// NSRect.contains (a cursor parked at the top edge after using the menu
    /// bar reports y == frame.maxY) and arrangement gaps, by falling back to
    /// the nearest screen.
    private static func screen(nearest point: NSPoint) -> NSScreen? {
        let screens = NSScreen.screens
        if let exact = screens.first(where: { NSMouseInRect(point, $0.frame, false) }) {
            return exact
        }
        return screens.min(by: {
            distanceSquared(from: point, to: $0.frame) < distanceSquared(from: point, to: $1.frame)
        })
    }

    private static func distanceSquared(from point: NSPoint, to rect: NSRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return dx * dx + dy * dy
    }

    private func center(on screen: NSScreen) {
        let visible = screen.visibleFrame
        let panelSize = panel.frame.size
        let origin = NSPoint(
            x: visible.minX + (visible.width - panelSize.width) / 2,
            y: visible.minY + (visible.height - panelSize.height) / 2
        )
        panel.setFrameOrigin(origin)
    }

    private static func screenOfFrontmostFocusedWindow() -> NSScreen? {
        guard
            let app = NSWorkspace.shared.frontmostApplication,
            app.processIdentifier != ProcessInfo.processInfo.processIdentifier
        else { return nil }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)

        var windowRef: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(
                axApp, kAXFocusedWindowAttribute as CFString, &windowRef
            ) == .success,
            let windowValue = windowRef
        else { return nil }
        let window = windowValue as! AXUIElement

        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(
                window, kAXPositionAttribute as CFString, &positionRef
            ) == .success,
            AXUIElementCopyAttributeValue(
                window, kAXSizeAttribute as CFString, &sizeRef
            ) == .success,
            let positionValue = positionRef,
            let sizeValue = sizeRef
        else { return nil }

        var position = CGPoint.zero
        var size = CGSize.zero
        guard
            AXValueGetValue(positionValue as! AXValue, .cgPoint, &position),
            AXValueGetValue(sizeValue as! AXValue, .cgSize, &size),
            let primary = NSScreen.screens.first
        else { return nil }

        // AX uses top-left origin anchored to the primary screen; NSScreen
        // uses bottom-left. Flip Y to find the matching NSScreen.
        let centerAX = CGPoint(
            x: position.x + size.width / 2,
            y: position.y + size.height / 2
        )
        let centerNS = NSPoint(
            x: centerAX.x,
            y: primary.frame.maxY - centerAX.y
        )
        return NSScreen.screens.first(where: { $0.frame.contains(centerNS) })
    }

    func hide() {
        panel.orderOut(nil)
    }

    private func toggleFavorite(_ entry: ClipEntry) {
        do {
            try store.toggleFavorite(id: entry.id)
        } catch {
            print("[Favorite] toggle failed: \(error)")
        }
    }

    private func delete(_ entry: ClipEntry) {
        do {
            try store.delete(id: entry.id)
        } catch {
            print("[Delete] failed: \(error)")
        }
    }

    private func revealInFinder(_ entry: ClipEntry) {
        guard let payloads = try? store.payloads(for: entry.id) else { return }
        var urls: [URL] = []
        for payload in payloads {
            guard let bookmark = payload.bookmarkData else { continue }
            var stale = false
            if let url = try? URL(
                resolvingBookmarkData: bookmark,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            ) {
                _ = url.startAccessingSecurityScopedResource()
                urls.append(url)
            }
        }
        guard !urls.isEmpty else {
            print("[Reveal] no resolvable URLs for entry \(entry.id)")
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
        hide()
        let stash = urls
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            for url in stash { url.stopAccessingSecurityScopedResource() }
        }
    }

    private func paste(_ entry: ClipEntry) {
        if let last = lastPasteAt, Date().timeIntervalSince(last) < 0.4 { return }
        lastPasteAt = Date()

        print("[Paste] === paste() entered id=\(entry.id) kind=\(entry.kind) ===")
        do {
            let payloads = try store.payloads(for: entry.id)
            print("[Paste] loaded \(payloads.count) payload(s)")
            switch entry.kind {
            case .text, .url, .richText:
                if let text = payloads.first?.inlineText {
                    pasteText(text)
                } else {
                    print("[Paste] WARN: text-kind entry but no inlineText payload")
                }
            case .file, .multiFile:
                pasteFiles(payloads)
            case .image:
                print("[Paste] image kind — not implemented")
            }
        } catch {
            print("[Paste] payload load failed: \(error)")
        }
        hide()
        Self.performAutoPasteAfterDelay()
    }

    private static func performAutoPasteAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let opts = [
                kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
            ] as CFDictionary
            guard AXIsProcessTrustedWithOptions(opts) else {
                print("[Paste] Accessibility NOT granted — pasteboard updated, press ⌘V manually.")
                return
            }
            let src = CGEventSource(stateID: .combinedSessionState)
            let v: CGKeyCode = 0x09
            if let down = CGEvent(keyboardEventSource: src, virtualKey: v, keyDown: true) {
                down.flags = .maskCommand
                down.post(tap: .cghidEventTap)
            }
            if let up = CGEvent(keyboardEventSource: src, virtualKey: v, keyDown: false) {
                up.flags = .maskCommand
                up.post(tap: .cghidEventTap)
            }
        }
    }

    private func pasteText(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        pb.setData(Data(), forType: Self.autoGeneratedType)
    }

    private func pasteFiles(_ payloads: [ClipPayload]) {
        var resolved: [URL] = []
        for payload in payloads {
            guard let bookmark = payload.bookmarkData else {
                print("[Paste] payload has no bookmark: \(payload.filename ?? "?")")
                continue
            }
            var stale = false
            do {
                let url = try URL(
                    resolvingBookmarkData: bookmark,
                    options: [.withSecurityScope],
                    relativeTo: nil,
                    bookmarkDataIsStale: &stale
                )
                _ = url.startAccessingSecurityScopedResource()
                resolved.append(url)
            } catch {
                print("[Paste] bookmark resolve failed for \(payload.filename ?? "?"): \(error)")
            }
        }
        guard !resolved.isEmpty else {
            // All bookmarks stale — fall back to copying filenames as text.
            let names = payloads.compactMap(\.filename).joined(separator: "\n")
            if !names.isEmpty {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(names, forType: .string)
                pb.setData(Data(), forType: Self.autoGeneratedType)
                print("[Paste] all bookmarks stale; pasted filenames as text fallback")
            } else {
                print("[Paste] no URLs resolved and no filenames available")
            }
            return
        }

        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects(resolved as [NSURL])
        pb.setPropertyList(
            resolved.map(\.path),
            forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")
        )
        pb.setData(Data(), forType: Self.autoGeneratedType)

        let urls = resolved
        Task {
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            for url in urls { url.stopAccessingSecurityScopedResource() }
        }
    }

    private static let autoGeneratedType =
        NSPasteboard.PasteboardType("org.nspasteboard.AutoGeneratedType")
}
