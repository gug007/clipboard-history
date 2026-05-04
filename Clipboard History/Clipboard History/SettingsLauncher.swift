import SwiftUI
import AppKit

@MainActor
final class SettingsLauncher {
    static let shared = SettingsLauncher()

    private var bridgeWindow: NSPanel?
    private var openAction: (() -> Void)?
    private var pendingLaunch = false

    func launch() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        if let action = openAction {
            action()
            return
        }
        guard !pendingLaunch else { return }
        pendingLaunch = true
        installBridge()
    }

    private func installBridge() {
        let view = SettingsBridgeView { [weak self] action in
            guard let self else { return }
            self.openAction = action
            self.pendingLaunch = false
            DispatchQueue.main.async { action() }
        }
        let host = NSHostingView(rootView: view)
        let win = NSPanel(
            contentRect: NSRect(x: -1000, y: -1000, width: 1, height: 1),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        win.contentView = host
        win.isOpaque = false
        win.alphaValue = 0
        win.hasShadow = false
        win.ignoresMouseEvents = true
        win.collectionBehavior = [.transient, .ignoresCycle]
        win.orderFront(nil)
        bridgeWindow = win
    }
}

private struct SettingsBridgeView: View {
    let onCapture: (@escaping () -> Void) -> Void
    @Environment(\.openSettings) private var openSettings
    @State private var captured = false

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .onAppear {
                guard !captured else { return }
                captured = true
                let action = openSettings
                onCapture { action() }
            }
    }
}
