import AppKit
import SwiftUI

final class OverlayPanelController {
    private let panel: NSPanel
    private var hostingView: NSHostingView<OverlayView>!
    private let store: HistoryStore

    var isVisible: Bool { panel.isVisible }

    init(store: HistoryStore) {
        self.store = store

        let size = NSSize(width: 720, height: 480)
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isReleasedWhenClosed = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.hidesOnDeactivate = false

        let host = NSHostingView(rootView: OverlayView(
            store: store,
            onPaste: { _ in },
            onDismiss: {}
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
            onPaste: { [weak self] entry in self?.paste(entry) },
            onDismiss: { [weak self] in self?.hide() }
        )
    }

    func toggle() { panel.isVisible ? hide() : show() }

    func show() {
        panel.center()
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        panel.orderOut(nil)
    }

    private func paste(_ entry: ClipEntry) {
        do {
            let payloads = try store.payloads(for: entry.id)
            switch entry.kind {
            case .text, .url, .richText:
                if let text = payloads.first?.inlineText {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }
            case .file, .multiFile:
                pasteFiles(payloads)
            case .image:
                break
            }
        } catch {
            print("[Paste] failed: \(error)")
        }
        hide()
    }

    private func pasteFiles(_ payloads: [ClipPayload]) {
        var resolved: [URL] = []
        for payload in payloads {
            guard let bookmark = payload.bookmarkData else { continue }
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
        guard !resolved.isEmpty else { return }

        let pb = NSPasteboard.general
        pb.clearContents()

        let items: [NSPasteboardItem] = resolved.enumerated().map { idx, url in
            let item = NSPasteboardItem()
            item.setString(url.absoluteString, forType: .fileURL)
            if idx == 0 {
                let paths = resolved.map { $0.path }
                item.setPropertyList(
                    paths,
                    forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")
                )
            }
            return item
        }
        pb.writeObjects(items)

        // Hold the security scope open for ~30s so destination apps can read.
        let urls = resolved
        Task {
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            for url in urls {
                url.stopAccessingSecurityScopedResource()
            }
        }
    }
}
