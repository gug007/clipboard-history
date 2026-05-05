import AppKit
import SwiftUI

final class OverlayPanelController {
    private let panel: NSPanel
    private var hostingView: NSHostingView<OverlayView>!
    private let store: HistoryStore
    private let state: PanelState
    private var lastPasteAt: Date?

    var isVisible: Bool { panel.isVisible }

    init(store: HistoryStore, state: PanelState) {
        self.store = store
        self.state = state

        let size = NSSize(width: 720, height: 480)
        panel = NSPanel(
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
    }

    func toggle() { panel.isVisible ? hide() : show() }

    func show() {
        centerPanelOnActiveScreen()
        panel.makeKeyAndOrderFront(nil)
    }

    private func centerPanelOnActiveScreen() {
        // Pick the screen the user is currently on (cursor location), falling back
        // to the key window's screen, then the main screen.
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) })
            ?? NSApp.keyWindow?.screen
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let visible = screen?.visibleFrame else {
            panel.center()
            return
        }
        let panelSize = panel.frame.size
        let origin = NSPoint(
            x: visible.minX + (visible.width - panelSize.width) / 2,
            y: visible.minY + (visible.height - panelSize.height) / 2
        )
        panel.setFrameOrigin(origin)
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
