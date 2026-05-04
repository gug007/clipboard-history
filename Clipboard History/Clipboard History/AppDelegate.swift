import AppKit
import Sparkle

final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var historyStore: HistoryStore?
    private var watcher: ClipboardWatcher?
    private var menuBar: MenuBarController?
    private var overlay: OverlayPanelController?
    private var hotkey: HotkeyService?
    private let deviceId = AppDelegate.persistentDeviceId()
    private let panelState = PanelState()
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Touch the singleton so the first-launch default (register as login item) is applied.
        _ = LaunchAtLogin.shared

        let initialPaused = UserDefaults.standard.bool(forKey: Self.pausedKey)
        panelState.isPaused = initialPaused

        // Menu bar icon first — guarantees the user can always quit, regardless of below.
        menuBar = MenuBarController(
            initialPaused: initialPaused,
            onOpen: { [weak self] in self?.overlay?.toggle() },
            onTogglePause: { [weak self] in self?.handlePauseToggle() },
            onOpenSettings: { Self.openSettings() },
            onCheckForUpdates: { [weak self] in self?.checkForUpdates() }
        )

        let store: HistoryStore
        do {
            let url = try Self.databaseURL()
            print("[Startup] Database URL: \(url.path)")
            store = try HistoryStore(databaseURL: url)
            self.historyStore = store
            print("[Startup] HistoryStore opened successfully")
        } catch {
            print("[Startup] FATAL: HistoryStore failed: \(error)")
            return
        }

        let overlay = OverlayPanelController(store: store, state: panelState)
        self.overlay = overlay

        let deviceId = self.deviceId
        let watcher = ClipboardWatcher { [weak store] event in
            guard let store else { return }
            let entry: ClipEntry
            let payloads: [ClipPayload]
            switch event {
            case .text(let textEvent):
                let (e, p) = ClipEntry.fromText(
                    textEvent.text,
                    sourceApp: textEvent.sourceApp,
                    sourceAppName: textEvent.sourceAppName,
                    deviceId: deviceId
                )
                entry = e
                payloads = [p]
            case .files(let fileEvent):
                let (e, ps) = ClipEntry.fromFiles(fileEvent, deviceId: deviceId)
                entry = e
                payloads = ps
            }
            do {
                try store.append(entry, payloads: payloads)
            } catch {
                print("[Capture] append failed: \(error)")
            }
        }
        self.watcher = watcher
        watcher.start()
        if initialPaused {
            watcher.setPaused(true)
            print("[Startup] Restored paused state from previous session")
        }

        let hotkey = HotkeyService { [weak overlay] in overlay?.toggle() }
        self.hotkey = hotkey
        print("[Startup] All systems ready — global hotkey registered (paused=\(initialPaused))")
    }

    private func handlePauseToggle() {
        guard let menuBar else { return }
        let paused = menuBar.isPaused
        watcher?.setPaused(paused)
        panelState.isPaused = paused
        UserDefaults.standard.set(paused, forKey: Self.pausedKey)
        print("[Pause] now paused=\(paused)")
    }

    private static let pausedKey = "ClipboardHistory.isPaused"

    private static func openSettings() {
        SettingsLauncher.shared.launch()
    }

    private func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    private static func databaseURL() throws -> URL {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = appSupport.appendingPathComponent("Clipboard History", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("clipboard.sqlite")
    }

    private static func persistentDeviceId() -> String {
        let key = "ClipboardHistory.deviceId"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let new = UUID().uuidString
        UserDefaults.standard.set(new, forKey: key)
        return new
    }
}
