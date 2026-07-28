import AppKit
import SwiftUI

private func dlog(_ message: @autoclosure () -> String) {
    #if DEBUG
    let t = String(format: "%.3f", Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 1000))
    print("[Overlay \(t)] \(message())")
    #endif
}

private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    // canBecomeMain stays false (the NSPanel default): a hotkey palette only
    // needs key status to take typing, and main-window status gives the
    // panel activation-like behavior that fullscreen Spaces punish — none of
    // the proven overlay panels (Maccy, Ice) opt into it.
}

final class OverlayPanelController: NSObject, NSWindowDelegate {
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

        let size = AppSettings.shared.overlaySize
        panel = KeyablePanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.contentMinSize = AppSettings.minOverlaySize
        panel.contentMaxSize = AppSettings.maxOverlaySize
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        // .stationary is an Exposé/Mission-Control flag with no role for a
        // transient palette, and it's a named suspect for panels being
        // suppressed over fullscreen Spaces on macOS 26.
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.hidesOnDeactivate = false

        let host = NSHostingView(rootView: OverlayView(
            store: store,
            state: state,
            onPaste: { _ in },
            onCopy: { _ in },
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

        super.init()

        host.rootView = OverlayView(
            store: store,
            state: state,
            onPaste: { [weak self] entry in self?.paste(entry) },
            onCopy: { [weak self] entry in self?.copyToPasteboard(entry) },
            onDismiss: { [weak self] in self?.hide() },
            onToggleFavorite: { [weak self] entry in self?.toggleFavorite(entry) },
            onDelete: { [weak self] entry in self?.delete(entry) },
            onReveal: { [weak self] entry in self?.revealInFinder(entry) }
        )

        panel.delegate = self
        applyAppearance()
        observeAppearance()
        observeFocusLoss()
    }

    /// The panel is borderless, so its frame is its content: persist the size
    /// the user settled on and reopen at it next time.
    func windowDidEndLiveResize(_ notification: Notification) {
        AppSettings.shared.overlaySize = panel.frame.size
    }

    func toggle() {
        dlog("toggle() visible=\(panel.isVisible) key=\(panel.isKeyWindow) onActiveSpace=\(panel.isOnActiveSpace) frontmost=\(NSWorkspace.shared.frontmostApplication?.localizedName ?? "?")")
        guard panel.isVisible else {
            show()
            return
        }
        // A modal alert (New Group…, rename) is running on top of the
        // panel — hiding it from under the alert would strand the alert.
        guard NSApp.modalWindow == nil else { return }
        // The cursor sitting on the panel means the user sees it: dismiss.
        if panel.frame.contains(NSEvent.mouseLocation) {
            dlog("toggle(): cursor on panel → hide")
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
            dlog("toggle(): summon to \(target.frame)")
            applyAppearance()
            center(on: target)
            orderFront()
        } else {
            dlog("toggle(): plain dismiss")
            hide()
        }
    }

    func show() {
        dlog("show() begin axTrusted=\(AXIsProcessTrusted())")
        applyAppearance()
        let t0 = Date()
        if let target = Self.userScreen() {
            dlog("show(): userScreen=\(target.frame) took \(Int(Date().timeIntervalSince(t0) * 1000))ms")
            center(on: target)
        } else {
            dlog("show(): userScreen=nil took \(Int(Date().timeIntervalSince(t0) * 1000))ms")
            panel.center()
        }
        orderFront()
        dlog("show() done: visible=\(panel.isVisible) key=\(panel.isKeyWindow) onActiveSpace=\(panel.isOnActiveSpace)")
        #if DEBUG
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self else { return }
            dlog("show()+1s: visible=\(self.panel.isVisible) key=\(self.panel.isKeyWindow) onActiveSpace=\(self.panel.isOnActiveSpace) occlusionVisible=\(self.panel.occlusionState.contains(.visible))")
        }
        #endif
    }

    /// Order the panel front without activating the app. From a non-active
    /// app, makeKeyAndOrderFront can order the window beneath the active
    /// application's windows (documented since macOS 13.3); the regardless
    /// variant is how Spotlight-style panels (e.g. Maccy) summon reliably,
    /// including over fullscreen Spaces.
    private func orderFront() {
        panel.orderFrontRegardless()
        panel.makeKey()
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
            dlog("didResignKey fired")
            // Defer one runloop turn so key-window state has settled, then
            // keep the panel if focus moved to another window of this app —
            // the NSAlert.runModal flows (New Group…, rename) take key
            // status while the panel must stay up behind them.
            DispatchQueue.main.async {
                guard let self else { return }
                dlog("didResignKey deferred: visible=\(self.panel.isVisible) key=\(self.panel.isKeyWindow) modal=\(NSApp.modalWindow != nil) appKey=\(NSApp.keyWindow != nil)")
                guard self.panel.isVisible, !self.panel.isKeyWindow else { return }
                if NSApp.modalWindow != nil || NSApp.keyWindow != nil { return }
                dlog("didResignKey → hide")
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
            dlog("outsideClickMonitor → hide")
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
    /// The AX query runs synchronously against the frontmost app on the main
    /// thread, and an unresponsive app (observed: fullscreen Chrome) can sit
    /// on each call for the system default timeout of 6 seconds — the hotkey
    /// then appears dead and the panel materializes long after the user has
    /// moved on. So consult AX only when it can change the outcome: with a
    /// single display there is nothing to arbitrate, and with recent mouse
    /// use the cursor screen wins any disagreement anyway.
    private static func userScreen() -> NSScreen? {
        let screens = NSScreen.screens
        guard screens.count > 1 else { return screens.first }
        let cursorScreen = screen(nearest: NSEvent.mouseLocation)
        if mouseRecentlyUsed() {
            return cursorScreen ?? NSScreen.main ?? screens.first
        }
        guard let focusScreen = screenOfFrontmostFocusedWindow() else {
            return cursorScreen ?? NSScreen.main ?? screens.first
        }
        return focusScreen
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
        // A size dragged out on a large display must not overflow a smaller
        // one; setContentSize re-applies contentMinSize on its own.
        let desired = AppSettings.shared.overlaySize
        let fitted = NSSize(
            width: min(desired.width, visible.width - 32),
            height: min(desired.height, visible.height - 32)
        )
        if fitted != panel.frame.size {
            panel.setContentSize(fitted)
        }
        let panelSize = panel.frame.size
        let origin = NSPoint(
            x: visible.minX + (visible.width - panelSize.width) / 2,
            y: visible.minY + (visible.height - panelSize.height) / 2
        )
        panel.setFrameOrigin(origin)
    }

    /// Process-wide AX timeout, configured once before the first AX call:
    /// a stalled target app costs at most ~0.25s per call instead of the
    /// 6-second system default, keeping show() usable on the main thread.
    private static let axTimeoutConfigured: Bool = {
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 0.25)
        return true
    }()

    private static func screenOfFrontmostFocusedWindow() -> NSScreen? {
        _ = axTimeoutConfigured
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
                guard url.startAccessingSecurityScopedResource() else {
                    print("[Reveal] security-scoped access denied for \(payload.filename ?? "?")")
                    continue
                }
                guard (try? url.checkResourceIsReachable()) == true else {
                    url.stopAccessingSecurityScopedResource()
                    print("[Reveal] file is no longer reachable: \(payload.filename ?? "?")")
                    continue
                }
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

        print("[Paste] === paste() entered id=\(entry.id) kind=\(entry.kind) ===")
        // Never dismiss the picker or synthesize Cmd-V unless a new,
        // expected representation is demonstrably on the pasteboard.
        guard let writtenChangeCount = writeToPasteboard(entry) else {
            print("[Paste] aborted — pasteboard was not safely updated")
            return
        }
        lastPasteAt = Date()
        hide()
        Self.performAutoPasteAfterDelay(expectedChangeCount: writtenChangeCount)
    }

    /// Copy without the synthesized Cmd-V. The clip lands on the pasteboard and
    /// the panel closes, leaving the user to decide where and when it goes —
    /// the escape hatch for apps that reject synthetic paste events, and for
    /// grabbing a clip now to paste somewhere else later.
    private func copyToPasteboard(_ entry: ClipEntry) {
        if let last = lastPasteAt, Date().timeIntervalSince(last) < 0.4 { return }

        print("[Copy] === copy() entered id=\(entry.id) kind=\(entry.kind) ===")
        guard writeToPasteboard(entry) != nil else {
            print("[Copy] aborted — pasteboard was not safely updated")
            return
        }
        lastPasteAt = Date()
        hide()
    }

    /// Writes the entry onto the general pasteboard and returns the verified
    /// change count, or nil when nothing trustworthy was written.
    private func writeToPasteboard(_ entry: ClipEntry) -> Int? {
        let writtenChangeCount: Int?
        do {
            let payloads = try store.payloads(for: entry.id)
            print("[Paste] loaded \(payloads.count) payload(s)")
            switch entry.kind {
            case .text:
                if let text = payloads.first?.inlineText {
                    writtenChangeCount = pasteText(text)
                } else {
                    print("[Paste] WARN: text-kind entry but no inlineText payload")
                    writtenChangeCount = nil
                }
            case .url:
                if let text = payloads.first?.inlineText {
                    writtenChangeCount = pasteText(text, isURL: true)
                } else {
                    print("[Paste] WARN: URL entry but no inlineText payload")
                    writtenChangeCount = nil
                }
            case .richText:
                if let payload = payloads.first {
                    writtenChangeCount = pasteRichText(payload)
                } else {
                    print("[Paste] WARN: rich-text entry has no payload")
                    writtenChangeCount = nil
                }
            case .file, .multiFile:
                writtenChangeCount = pasteFiles(payloads)
            case .image:
                if let payload = payloads.first {
                    writtenChangeCount = pasteImage(payload)
                } else {
                    print("[Paste] WARN: image entry has no payload")
                    writtenChangeCount = nil
                }
            }
        } catch {
            print("[Paste] payload load failed: \(error)")
            writtenChangeCount = nil
        }
        return writtenChangeCount
    }

    private static func performAutoPasteAfterDelay(expectedChangeCount: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            guard NSPasteboard.general.changeCount == expectedChangeCount else {
                print("[Paste] pasteboard changed before Cmd-V — auto-paste cancelled")
                return
            }
            let mayPostEvents = CGPreflightPostEventAccess()
                || CGRequestPostEventAccess()
            guard mayPostEvents else {
                print("[Paste] PostEvent access NOT granted — pasteboard updated, press ⌘V manually.")
                return
            }
            guard NSPasteboard.general.changeCount == expectedChangeCount else {
                print("[Paste] pasteboard changed during permission check — auto-paste cancelled")
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

    private func pasteText(_ text: String, isURL: Bool = false) -> Int? {
        guard !text.isEmpty else {
            print("[Paste] refusing to write empty text")
            return nil
        }
        let item = NSPasteboardItem()
        guard item.setString(text, forType: .string) else {
            print("[Paste] could not prepare plain text")
            return nil
        }
        if isURL {
            // Keep .string as the guaranteed fallback for fields that do not
            // accept the richer public.url representation.
            _ = item.setString(text, forType: .URL)
        }
        return commit(item: item, requiredType: .string)
    }

    private func pasteRichText(_ payload: ClipPayload) -> Int? {
        let item = NSPasteboardItem()
        var requiredType: NSPasteboard.PasteboardType?

        if let text = payload.inlineText, !text.isEmpty,
           item.setString(text, forType: .string) {
            requiredType = .string
        }

        if let data = payload.inlineData, !data.isEmpty,
           let richType = Self.richPasteboardType(
               dataFormat: payload.dataFormat,
               uti: payload.uti
           ),
           item.setData(data, forType: richType) {
            requiredType = richType
        }

        guard let requiredType else {
            print("[Paste] rich-text payload has neither usable raw data nor plain text")
            return nil
        }
        return commit(item: item, requiredType: requiredType)
    }

    private func pasteImage(_ payload: ClipPayload) -> Int? {
        guard payload.payloadKind == .image,
              let data = payload.inlineData,
              !data.isEmpty,
              let imageType = Self.imagePasteboardType(
                  dataFormat: payload.dataFormat,
                  uti: payload.uti
              ),
              Self.hasValidImageHeader(data, type: imageType)
        else {
            print("[Paste] image payload is missing or invalid")
            return nil
        }

        let item = NSPasteboardItem()
        guard item.setData(data, forType: imageType) else {
            print("[Paste] could not prepare image data")
            return nil
        }
        return commit(item: item, requiredType: imageType)
    }

    private func commit(
        item: NSPasteboardItem,
        requiredType: NSPasteboard.PasteboardType
    ) -> Int? {
        guard item.setData(Data(), forType: Self.autoGeneratedType) else {
            print("[Paste] could not attach capture-suppression marker")
            return nil
        }

        let pb = NSPasteboard.general
        pb.clearContents()
        guard pb.writeObjects([item]) else {
            print("[Paste] pasteboard rejected prepared item")
            return nil
        }
        let types = Set(pb.types ?? [])
        guard types.contains(requiredType),
              types.contains(Self.autoGeneratedType)
        else {
            print("[Paste] pasteboard write could not be verified")
            return nil
        }
        return pb.changeCount
    }

    private func pasteFiles(_ payloads: [ClipPayload]) -> Int? {
        guard !payloads.isEmpty else {
            print("[Paste] file entry has no payloads")
            return nil
        }

        var resolved: [URL] = []
        var resolutionFailed = false
        for payload in payloads {
            guard payload.payloadKind == .file,
                  let bookmark = payload.bookmarkData else {
                print("[Paste] payload has no bookmark: \(payload.filename ?? "?")")
                resolutionFailed = true
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
                guard url.startAccessingSecurityScopedResource() else {
                    print("[Paste] security-scoped access denied for \(payload.filename ?? "?")")
                    resolutionFailed = true
                    continue
                }
                guard (try? url.checkResourceIsReachable()) == true else {
                    url.stopAccessingSecurityScopedResource()
                    print("[Paste] file is no longer reachable: \(payload.filename ?? "?")")
                    resolutionFailed = true
                    continue
                }
                resolved.append(url)
            } catch {
                print("[Paste] bookmark resolve failed for \(payload.filename ?? "?"): \(error)")
                resolutionFailed = true
            }
        }

        guard !resolutionFailed, resolved.count == payloads.count else {
            for url in resolved { url.stopAccessingSecurityScopedResource() }
            // Do not silently paste an incomplete selection. A complete list
            // of names is a deterministic, fresh plain-text fallback.
            let names = payloads.compactMap(\.filename)
            guard names.count == payloads.count else {
                print("[Paste] file references failed and a complete filename fallback is unavailable")
                return nil
            }
            print("[Paste] file references unavailable; using filenames as text fallback")
            return pasteText(names.joined(separator: "\n"))
        }

        let pb = NSPasteboard.general
        pb.clearContents()
        guard pb.writeObjects(resolved as [NSURL]) else {
            for url in resolved { url.stopAccessingSecurityScopedResource() }
            print("[Paste] pasteboard rejected file URLs")
            return nil
        }
        _ = pb.setPropertyList(
            resolved.map(\.path),
            forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")
        )
        guard pb.setData(Data(), forType: Self.autoGeneratedType) else {
            for url in resolved { url.stopAccessingSecurityScopedResource() }
            print("[Paste] could not attach capture-suppression marker to file URLs")
            return nil
        }
        let availableTypes = Set(pb.types ?? [])
        guard availableTypes.contains(.fileURL),
              availableTypes.contains(Self.autoGeneratedType)
        else {
            for url in resolved { url.stopAccessingSecurityScopedResource() }
            print("[Paste] file URL pasteboard write could not be verified")
            return nil
        }
        let changeCount = pb.changeCount

        let urls = resolved
        Task {
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            for url in urls { url.stopAccessingSecurityScopedResource() }
        }
        return changeCount
    }

    private static func richPasteboardType(
        dataFormat: String?,
        uti: String?
    ) -> NSPasteboard.PasteboardType? {
        for candidate in [dataFormat, uti].compactMap({ $0 }) {
            switch candidate {
            case NSPasteboard.PasteboardType.rtf.rawValue:
                return .rtf
            case NSPasteboard.PasteboardType.html.rawValue:
                return .html
            default:
                continue
            }
        }
        return nil
    }

    private static func imagePasteboardType(
        dataFormat: String?,
        uti: String?
    ) -> NSPasteboard.PasteboardType? {
        for candidate in [dataFormat, uti].compactMap({ $0 }) {
            switch candidate {
            case NSPasteboard.PasteboardType.png.rawValue:
                return .png
            case NSPasteboard.PasteboardType.tiff.rawValue:
                return .tiff
            default:
                continue
            }
        }
        return nil
    }

    private static func hasValidImageHeader(
        _ data: Data,
        type: NSPasteboard.PasteboardType
    ) -> Bool {
        let header = Array(data.prefix(8))
        switch type {
        case .png:
            return header.count >= 8
                && header[0...7].elementsEqual([137, 80, 78, 71, 13, 10, 26, 10])
        case .tiff:
            guard header.count >= 4 else { return false }
            return header[0...3].elementsEqual([73, 73, 42, 0])
                || header[0...3].elementsEqual([77, 77, 0, 42])
        default:
            return false
        }
    }

    private static let autoGeneratedType =
        NSPasteboard.PasteboardType("org.nspasteboard.AutoGeneratedType")
}
