import AppKit
import KeyboardShortcuts

final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let onOpen: () -> Void
    private let onTogglePause: () -> Void
    private let onPauseFor: (TimeInterval) -> Void
    private let onOpenSettings: () -> Void
    private let onCheckForUpdates: () -> Void
    private(set) var isPaused: Bool
    private(set) var pauseUntil: Date?

    init(
        initialPaused: Bool,
        initialPauseUntil: Date?,
        onOpen: @escaping () -> Void,
        onTogglePause: @escaping () -> Void,
        onPauseFor: @escaping (TimeInterval) -> Void,
        onOpenSettings: @escaping () -> Void,
        onCheckForUpdates: @escaping () -> Void
    ) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.onOpen = onOpen
        self.onTogglePause = onTogglePause
        self.onPauseFor = onPauseFor
        self.onOpenSettings = onOpenSettings
        self.onCheckForUpdates = onCheckForUpdates
        self.isPaused = initialPaused
        self.pauseUntil = initialPauseUntil
        super.init()
        updateIcon()
        statusItem.menu = makeMenu()
    }

    func setPaused(_ paused: Bool, until: Date? = nil) {
        guard paused != isPaused || until != pauseUntil else { return }
        isPaused = paused
        pauseUntil = paused ? until : nil
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
        menu.delegate = self

        let open = NSMenuItem(
            title: "Open Clipboard History",
            action: #selector(openTapped),
            keyEquivalent: ""
        )
        open.target = self
        open.setShortcut(for: .openHistory)
        menu.addItem(open)

        menu.addItem(.separator())

        let pause = NSMenuItem(
            title: isPaused ? "Resume Recording" : "Pause Recording",
            action: #selector(pauseTapped),
            keyEquivalent: ""
        )
        pause.target = self
        menu.addItem(pause)

        if let pauseUntil {
            let resumes = NSMenuItem(
                title: "Resumes \(pauseUntil.formatted(date: .omitted, time: .shortened))",
                action: nil,
                keyEquivalent: ""
            )
            resumes.isEnabled = false
            menu.addItem(resumes)
        } else if !isPaused {
            let timedPause = NSMenuItem(
                title: "Pause For",
                action: nil,
                keyEquivalent: ""
            )
            let timedMenu = NSMenu()
            timedMenu.addItem(timedPauseItem(title: "5 Minutes", seconds: 5 * 60))
            timedMenu.addItem(timedPauseItem(title: "30 Minutes", seconds: 30 * 60))
            timedMenu.addItem(timedPauseItem(title: "1 Hour", seconds: 60 * 60))
            timedMenu.addItem(timedPauseItem(title: "8 Hours", seconds: 8 * 60 * 60))
            timedPause.submenu = timedMenu
            menu.addItem(timedPause)
        }

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
        pauseUntil = nil
        updateIcon()
        statusItem.menu = makeMenu()
        onTogglePause()
    }

    private func timedPauseItem(title: String, seconds: TimeInterval) -> NSMenuItem {
        let item = NSMenuItem(
            title: title,
            action: #selector(timedPauseTapped(_:)),
            keyEquivalent: ""
        )
        item.target = self
        item.representedObject = NSNumber(value: seconds)
        return item
    }

    @objc private func timedPauseTapped(_ sender: NSMenuItem) {
        guard let seconds = (sender.representedObject as? NSNumber)?.doubleValue else { return }
        onPauseFor(seconds)
    }

    @objc private func settingsTapped() { onOpenSettings() }

    @objc private func checkForUpdatesTapped() { onCheckForUpdates() }
}

extension MenuBarController: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        KeyboardShortcuts.disable(.openHistory)
    }

    func menuDidClose(_ menu: NSMenu) {
        KeyboardShortcuts.enable(.openHistory)
    }
}
