import AppKit
import SwiftUI

final class OverlayPanelController {
    private let panel: NSPanel
    private var hostingView: NSHostingView<OverlayView>

    var isVisible: Bool { panel.isVisible }

    init() {
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

        hostingView = NSHostingView(rootView: OverlayView(onPaste: { _ in }, onDismiss: {}))
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: container.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])
        panel.contentView = container

        hostingView.rootView = OverlayView(
            onPaste: { [weak self] s in self?.paste(s) },
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

    private func paste(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        hide()
    }
}
