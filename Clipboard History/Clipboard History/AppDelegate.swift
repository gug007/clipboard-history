import AppKit
import Sparkle

final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var historyStore: HistoryStore?
    private var watcher: ClipboardWatcher?
    private var menuBar: MenuBarController?
    private var overlay: OverlayPanelController?
    private var hotkey: HotkeyService?
    private var onboarding: OnboardingWindowController?
    private var pauseTimer: Timer?
    private var restoreIndefinitePauseAfterOnboarding = false
    private var restoreTimedPauseAfterOnboarding: Date?
    private lazy var deviceId = AppDelegate.persistentDeviceId()
    private let panelState = PanelState()
    private lazy var updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )
    #if DEBUG
    private var toggleSignalSource: DispatchSourceSignal?
    private var settingsSignalSource: DispatchSourceSignal?
    #endif

    func applicationDidFinishLaunching(_ notification: Notification) {
        // An app-hosted XCTest bundle launches the application first. Keep
        // tests isolated from the real database, pasteboard watcher, login
        // items, global shortcut, and updater.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            return
        }

        NSApp.setActivationPolicy(.accessory)

        // Initialize login-item state before onboarding reads it.
        _ = LaunchAtLogin.shared

        let needsOnboarding = !OnboardingWindowController.isCompleted
        let restoredPaused = UserDefaults.standard.bool(forKey: Self.pausedKey)
        let storedPauseUntil = UserDefaults.standard.object(forKey: Self.pausedUntilKey) as? Date
        let activePauseUntil = storedPauseUntil.flatMap { $0 > Date() ? $0 : nil }
        if storedPauseUntil != nil, activePauseUntil == nil {
            UserDefaults.standard.removeObject(forKey: Self.pausedUntilKey)
        }
        if needsOnboarding {
            restoreIndefinitePauseAfterOnboarding = restoredPaused
            restoreTimedPauseAfterOnboarding = activePauseUntil
        }
        // First launch is deliberately capture-free until the user finishes setup.
        let initialPaused = needsOnboarding || restoredPaused || activePauseUntil != nil
        let displayedPauseUntil = needsOnboarding ? nil : activePauseUntil
        panelState.isPaused = initialPaused
        panelState.pauseUntil = displayedPauseUntil

        // Menu bar icon first — guarantees the user can always quit, regardless of below.
        menuBar = MenuBarController(
            initialPaused: initialPaused,
            initialPauseUntil: displayedPauseUntil,
            onOpen: { [weak self] in self?.overlay?.toggle() },
            onTogglePause: { [weak self] in self?.handlePauseToggle() },
            onPauseFor: { [weak self] duration in self?.pauseRecording(for: duration) },
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
            Self.presentStartupFailure(error)
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
                    deviceId: deviceId,
                    timestamp: textEvent.timestamp
                )
                entry = e
                payloads = [p]
            case .richText(let richTextEvent):
                let (e, p) = ClipEntry.fromRichText(
                    richTextEvent,
                    deviceId: deviceId
                )
                entry = e
                payloads = [p]
            case .image(let imageEvent):
                let (e, p) = ClipEntry.fromImage(
                    imageEvent,
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
        if initialPaused {
            watcher.setPaused(true)
            print(
                needsOnboarding
                    ? "[Startup] Recording held until onboarding completes"
                    : "[Startup] Restored paused state from previous session"
            )
        }
        watcher.start()
        if let displayedPauseUntil {
            scheduleResume(at: displayedPauseUntil)
        }

        let hotkey = HotkeyService { [weak overlay] in overlay?.toggle() }
        self.hotkey = hotkey
        print("[Startup] All systems ready — global hotkey registered (paused=\(initialPaused))")

        if needsOnboarding {
            showOnboarding()
        }

        #if DEBUG
        // Test hook: `kill -USR1 <pid>` drives the same path as the global
        // hotkey, so the overlay can be exercised from scripts without
        // Accessibility/event-posting permissions.
        signal(SIGUSR1, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .main)
        source.setEventHandler { [weak self] in
            print("[Debug] SIGUSR1 → overlay.toggle()")
            self?.overlay?.toggle()
        }
        source.resume()
        toggleSignalSource = source

        // Companion hook: `kill -USR2 <pid>` opens Settings, which otherwise
        // needs a click in the menu bar and so is unreachable from a script.
        signal(SIGUSR2, SIG_IGN)
        let settingsSource = DispatchSource.makeSignalSource(signal: SIGUSR2, queue: .main)
        settingsSource.setEventHandler {
            print("[Debug] SIGUSR2 → openSettings()")
            Self.openSettings()
        }
        settingsSource.resume()
        settingsSignalSource = settingsSource
        #endif
    }

    private func handlePauseToggle() {
        guard let menuBar else { return }

        // Setup is the consent boundary for a new or upgraded install. If the
        // user closed it, choosing Resume takes them back to setup rather than
        // silently starting capture.
        if !menuBar.isPaused, !OnboardingWindowController.isCompleted {
            watcher?.setPaused(true)
            menuBar.setPaused(true)
            panelState.isPaused = true
            panelState.pauseUntil = nil
            showOnboarding()
            return
        }

        pauseTimer?.invalidate()
        pauseTimer = nil
        UserDefaults.standard.removeObject(forKey: Self.pausedUntilKey)

        let paused = menuBar.isPaused
        watcher?.setPaused(paused)
        panelState.isPaused = paused
        panelState.pauseUntil = nil
        UserDefaults.standard.set(paused, forKey: Self.pausedKey)
        print("[Pause] now paused=\(paused)")
    }

    private static let pausedKey = "ClipboardHistory.isPaused"
    private static let pausedUntilKey = "ClipboardHistory.pausedUntil"

    private func pauseRecording(for duration: TimeInterval) {
        let until = Date().addingTimeInterval(duration)
        watcher?.setPaused(true)
        menuBar?.setPaused(true, until: until)
        panelState.isPaused = true
        panelState.pauseUntil = until

        // A timed pause supersedes the persisted indefinite-pause flag.
        UserDefaults.standard.set(false, forKey: Self.pausedKey)
        UserDefaults.standard.set(until, forKey: Self.pausedUntilKey)
        scheduleResume(at: until)
        print("[Pause] paused until \(until)")
    }

    private func scheduleResume(at date: Date) {
        pauseTimer?.invalidate()
        let interval = max(0, date.timeIntervalSinceNow)
        let timer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.resumeTimedPauseIfDue()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pauseTimer = timer
    }

    private func resumeTimedPauseIfDue() {
        guard let stored = UserDefaults.standard.object(forKey: Self.pausedUntilKey) as? Date else {
            return
        }
        guard stored <= Date() else {
            scheduleResume(at: stored)
            return
        }

        pauseTimer?.invalidate()
        pauseTimer = nil
        UserDefaults.standard.removeObject(forKey: Self.pausedUntilKey)
        watcher?.setPaused(false)
        menuBar?.setPaused(false)
        panelState.isPaused = false
        panelState.pauseUntil = nil
        print("[Pause] timed pause ended")
    }

    private func showOnboarding() {
        if let onboarding {
            onboarding.show()
            return
        }
        let controller = OnboardingWindowController { [weak self] in
            self?.completeOnboarding()
        }
        onboarding = controller
        controller.show()
    }

    private func completeOnboarding() {
        pauseTimer?.invalidate()
        pauseTimer = nil

        let activeTimedPause = restoreIndefinitePauseAfterOnboarding
            ? nil
            : restoreTimedPauseAfterOnboarding.flatMap { $0 > Date() ? $0 : nil }
        let remainsPaused = restoreIndefinitePauseAfterOnboarding
            || activeTimedPause != nil

        watcher?.setPaused(remainsPaused)
        menuBar?.setPaused(remainsPaused, until: activeTimedPause)
        panelState.isPaused = remainsPaused
        panelState.pauseUntil = activeTimedPause
        UserDefaults.standard.set(
            restoreIndefinitePauseAfterOnboarding,
            forKey: Self.pausedKey
        )
        if let activeTimedPause {
            UserDefaults.standard.set(activeTimedPause, forKey: Self.pausedUntilKey)
            scheduleResume(at: activeTimedPause)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.pausedUntilKey)
        }
        restoreIndefinitePauseAfterOnboarding = false
        restoreTimedPauseAfterOnboarding = nil
        NSApp.setActivationPolicy(.accessory)
        onboarding = nil
        print("[Onboarding] Complete — recording paused=\(remainsPaused)")
    }

    private static func openSettings() {
        SettingsLauncher.shared.launch()
    }

    private func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    private static func presentStartupFailure(_ error: Error) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "Clipboard History couldn’t open its local database."
        alert.informativeText = """
            No clipboard content is being recorded. Quit and try again. If the problem continues, \
            keep the database for recovery and report this error:

            \(error.localizedDescription)
            """
        alert.addButton(withTitle: "Quit")
        alert.runModal()
        NSApp.terminate(nil)
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
