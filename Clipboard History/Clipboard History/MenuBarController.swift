import AppKit

final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let onOpen: () -> Void

    init(onOpen: @escaping () -> Void) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.onOpen = onOpen
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "list.clipboard",
                                    accessibilityDescription: "Clipboard History")
        }
        statusItem.menu = makeMenu()
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        let open = NSMenuItem(title: "Open Clipboard History  ⇧⌘V",
                              action: #selector(openTapped),
                              keyEquivalent: "")
        open.target = self
        menu.addItem(open)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Clipboard History",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        return menu
    }

    @objc private func openTapped() { onOpen() }
}
