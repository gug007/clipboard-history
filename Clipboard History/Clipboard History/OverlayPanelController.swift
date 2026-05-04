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
            if let text = payloads.first?.inlineText {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            }
        } catch {
            NSLog("Paste failed: %@", String(describing: error))
        }
        hide()
    }
}
