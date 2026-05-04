import AppKit

final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let onOpen: () -> Void
    private let onTogglePause: () -> Void
    private let onOpenSettings: () -> Void
    private let onCheckForUpdates: () -> Void
    private(set) var isPaused: Bool

    init(
        initialPaused: Bool,
        onOpen: @escaping () -> Void,
        onTogglePause: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onCheckForUpdates: @escaping () -> Void
    ) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.onOpen = onOpen
        self.onTogglePause = onTogglePause
        self.onOpenSettings = onOpenSettings
        self.onCheckForUpdates = onCheckForUpdates
        self.isPaused = initialPaused
        super.init()
        updateIcon()
        statusItem.menu = makeMenu()
    }

    func setPaused(_ paused: Bool) {
        guard paused != isPaused else { return }
        isPaused = paused
        updateIcon()
        statusItem.menu = makeMenu()
    }

    private func updateIcon() {
        guard let button = statusItem.button else { return }
        let symbolName = isPaused ? "pause.circle" : "list.clipboard"
        button.image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: isPaused
                ? "Clipboard History (paused)"
                : "Clipboard History"
        )
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()

        let open = NSMenuItem(
            title: "Open Clipboard History  ⇧⌘V",
            action: #selector(openTapped),
            keyEquivalent: ""
        )
        open.target = self
        menu.addItem(open)

        menu.addItem(.separator())

        let pause = NSMenuItem(
            title: isPaused ? "Resume Recording" : "Pause Recording",
            action: #selector(pauseTapped),
            keyEquivalent: ""
        )
        pause.target = self
        menu.addItem(pause)

        menu.addItem(.separator())

        let settings = NSMenuItem(
            title: "Settings…",
            action: #selector(settingsTapped),
            keyEquivalent: ","
        )
        settings.target = self
        menu.addItem(settings)

        let updates = NSMenuItem(
            title: "Check for Updates…",
            action: #selector(checkForUpdatesTapped),
            keyEquivalent: ""
        )
        updates.target = self
        menu.addItem(updates)

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(
            title: "Quit Clipboard History",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        return menu
    }

    @objc private func openTapped() { onOpen() }

    @objc private func pauseTapped() {
        isPaused.toggle()
        updateIcon()
        statusItem.menu = makeMenu()
        onTogglePause()
    }

    @objc private func settingsTapped() { onOpenSettings() }

    @objc private func checkForUpdatesTapped() { onCheckForUpdates() }
}
