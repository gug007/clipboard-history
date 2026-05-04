import AppKit
import Carbon.HIToolbox

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBar: MenuBarController?
    private var overlay: OverlayPanelController?
    private var hotkey: HotkeyService?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let overlay = OverlayPanelController()
        self.overlay = overlay

        menuBar = MenuBarController(onOpen: { [weak overlay] in overlay?.toggle() })

        let hotkey = HotkeyService { [weak overlay] in overlay?.toggle() }
        self.hotkey = hotkey
        hotkey.register(keyCode: UInt32(kVK_ANSI_V), modifiers: [.command, .shift])
    }
}
