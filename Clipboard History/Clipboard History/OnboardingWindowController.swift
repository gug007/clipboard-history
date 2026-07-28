import AppKit
import CoreGraphics
import KeyboardShortcuts
import SwiftUI

@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    private static let completedKey = "Onboarding.completed.v1"

    static var isCompleted: Bool {
        UserDefaults.standard.bool(forKey: completedKey)
    }

    private var window: NSWindow?
    private let onComplete: () -> Void

    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
        super.init()
    }

    func show() {
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let root = OnboardingView { [weak self] launchAtLogin in
            guard let self else { return }
            LaunchAtLogin.shared.setEnabled(launchAtLogin)
            UserDefaults.standard.set(true, forKey: Self.completedKey)
            self.window?.close()
            self.onComplete()
        }
        let controller = NSHostingController(rootView: root)
        let window = NSWindow(contentViewController: controller)
        window.title = "Welcome to Clipboard History"
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 560, height: 520))
        window.minSize = NSSize(width: 560, height: 520)
        window.maxSize = NSSize(width: 560, height: 520)
        window.center()
        window.delegate = self
        self.window = window

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        guard !Self.isCompleted else { return }
        // Closing setup leaves recording paused. The user can reopen the app
        // from the menu bar without anything private being captured first.
        NSApp.setActivationPolicy(.accessory)
    }
}

private struct OnboardingView: View {
    let onComplete: (Bool) -> Void

    @State private var launchAtLogin = LaunchAtLogin.shared.isEnabled
    @State private var autoPasteGranted = CGPreflightPostEventAccess()

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 14) {
                Image(systemName: "list.clipboard.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.accentColor.gradient, in: RoundedRectangle(cornerRadius: 14))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Your clipboard, remembered.")
                        .font(.system(size: 24, weight: .bold))
                    Text("Private, local, and ready from anywhere on your Mac.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                onboardingRow(
                    icon: "lock.shield",
                    title: "Stays on this Mac",
                    detail: "No account, cloud sync, or clipboard telemetry."
                )
                onboardingRow(
                    icon: "eye.slash",
                    title: "Skips confidential copies",
                    detail: "Supported password managers, marked confidential items, and apps you exclude are ignored."
                )
                onboardingRow(
                    icon: "folder",
                    title: "Remembers real Finder items",
                    detail: "Files and folders are stored by reference, not duplicated."
                )
            }
            .padding(16)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Open clipboard history")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Change this shortcut any time in Settings.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .openHistory)
                        .accessibilityLabel("Shortcut to open clipboard history")
                }

                Divider().opacity(0.35)

                Toggle(isOn: $launchAtLogin) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Launch at login")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Keep history available after every restart.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
            }

            HStack(spacing: 10) {
                Image(systemName: autoPasteGranted ? "checkmark.circle.fill" : "keyboard")
                    .foregroundStyle(autoPasteGranted ? Color.green : Color.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(autoPasteGranted ? "Auto-paste is ready" : "Auto-paste is optional")
                        .font(.system(size: 12, weight: .semibold))
                    Text(
                        autoPasteGranted
                            ? "Return pastes directly into the app you were using."
                            : "Without this permission, a clip is copied and you press ⌘V yourself."
                    )
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                }
                Spacer()
                if !autoPasteGranted {
                    Button("Enable…") { requestAutoPasteAccess() }
                        .controlSize(.small)
                }
            }
            .padding(12)
            .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))

            HStack {
                Text("Your recording state changes only after you finish setup.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Start Clipboard History") {
                    onComplete(launchAtLogin)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 560, height: 520)
        .task {
            while !Task.isCancelled, !autoPasteGranted {
                try? await Task.sleep(for: .seconds(1))
                autoPasteGranted = CGPreflightPostEventAccess()
            }
        }
    }

    private func onboardingRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 20)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func requestAutoPasteAccess() {
        autoPasteGranted = CGRequestPostEventAccess()
    }
}
