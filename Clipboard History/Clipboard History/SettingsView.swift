import SwiftUI
import AppKit
import KeyboardShortcuts
import UniformTypeIdentifiers

struct SettingsView: View {
    @State private var selection: Tab = .general
    @State private var settings = AppSettings.shared

    enum Tab: Hashable {
        case general, shortcuts, storage, privacy, about
    }

    private var detailTitle: String {
        switch selection {
        case .general:   return "General"
        case .shortcuts: return "Shortcuts"
        case .storage:   return "Storage"
        case .privacy:   return "Privacy"
        case .about:     return "About"
        }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                NavigationLink(value: Tab.general) {
                    Label("General", systemImage: "gear")
                }
                NavigationLink(value: Tab.shortcuts) {
                    Label("Shortcuts", systemImage: "keyboard")
                }
                NavigationLink(value: Tab.storage) {
                    Label("Storage", systemImage: "internaldrive")
                }
                NavigationLink(value: Tab.privacy) {
                    Label("Privacy", systemImage: "hand.raised")
                }
                NavigationLink(value: Tab.about) {
                    Label("About", systemImage: "info.circle")
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 170, ideal: 180, max: 200)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            Group {
                switch selection {
                case .general:   GeneralSettingsTab()
                case .shortcuts: ShortcutsSettingsTab()
                case .storage:   StorageSettingsTab()
                case .privacy:   PrivacySettingsTab()
                case .about:     AboutTab()
                }
            }
            .navigationTitle(detailTitle)
        }
        .frame(width: 700, height: 480)
        .preferredColorScheme(settings.appearance.colorScheme)
        .onDisappear {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

// MARK: - General

private struct GeneralSettingsTab: View {
    @State private var launch = LaunchAtLogin.shared
    @State private var settings = AppSettings.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Open clipboard history")
                            .font(.system(size: 13, weight: .semibold))
                        Spacer()
                        KeyboardShortcuts.Recorder(for: .openHistory)
                            .accessibilityLabel("Shortcut to open clipboard history")
                    }
                    Text("Press this shortcut from anywhere to open the history overlay.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Divider().opacity(0.35)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Launch at login")
                            .font(.system(size: 13, weight: .semibold))
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { launch.isEnabled },
                            set: { launch.setEnabled($0) }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                        .accessibilityLabel("Launch at login")
                    }
                    if launch.state == .requiresApproval {
                        HStack(spacing: 6) {
                            Text("Approval needed in System Settings → Login Items.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            Button("Open") { launch.openSystemSettings() }
                                .buttonStyle(.borderless)
                                .controlSize(.small)
                        }
                    } else {
                        Text("Start Clipboard History automatically when you log in.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }

                Divider().opacity(0.35)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Appearance")
                            .font(.system(size: 13, weight: .semibold))
                        Spacer()
                        Picker("", selection: Binding(
                            get: { settings.appearance },
                            set: { settings.appearance = $0 }
                        )) {
                            ForEach(AppearanceTheme.allCases, id: \.self) { theme in
                                Label(theme.label, systemImage: theme.iconName)
                                    .tag(theme)
                            }
                        }
                        .pickerStyle(.segmented)
                        .controlSize(.small)
                        .labelsHidden()
                        .fixedSize()
                        .accessibilityLabel("Appearance")
                    }
                    Text("Match the system look, or force Light or Dark mode.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollContentBackground(.hidden)
        .onAppear { launch.refresh() }
    }
}

// MARK: - Shortcuts

private struct ShortcutsSettingsTab: View {
    private var openShortcut: String? {
        KeyboardShortcuts.getShortcut(for: .openHistory)?.description
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("Open clipboard history")
                            .font(.system(size: 13, weight: .semibold))
                        if let openShortcut {
                            ShortcutKeyCap(keys: openShortcut)
                        }
                        Spacer()
                    }
                    Text(
                        openShortcut == nil
                            ? "No shortcut is set yet — choose one in General."
                            : "Works from any app. Change it in General."
                    )
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                }

                Divider().opacity(0.35)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Inside the overlay")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Press ⌘/ while the overlay is open to see this list there.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                ShortcutsGrid()

                Text(ShortcutsReference.windowTip)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Storage

private struct StorageSettingsTab: View {
    @State private var settings = AppSettings.shared
    @State private var clearConfirm = false
    @State private var clearMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                section(
                    title: "History size",
                    valueLabel: formatNumber(settings.retentionCap) + " items",
                    description: "Older items that aren't favorites or in a group are permanently removed once you exceed this cap."
                ) {
                    Slider(
                        value: Binding(
                            get: { Double(settings.retentionCap) },
                            set: { settings.retentionCap = Int($0) }
                        ),
                        in: 100...10_000,
                        step: 100,
                        onEditingChanged: { editing in
                            if !editing { enforceRetentionCap() }
                        }
                    )
                    .controlSize(.small)
                    .accessibilityLabel("History size")
                    .accessibilityValue("\(settings.retentionCap) items")
                }

                Divider().opacity(0.35)

                section(
                    title: "Maximum clipboard item size",
                    valueLabel: "\(settings.perFileSizeCapMB) MB",
                    description: "Oversized text, rich text, and clipboard images are skipped. Finder files and folders are stored only as references, so their size does not count."
                ) {
                    Slider(
                        value: Binding(
                            get: { Double(settings.perFileSizeCapMB) },
                            set: { settings.perFileSizeCapMB = Int($0) }
                        ),
                        in: 1...100,
                        step: 1
                    )
                    .controlSize(.small)
                    .accessibilityLabel("Maximum clipboard item size")
                    .accessibilityValue("\(settings.perFileSizeCapMB) megabytes")
                }

                Divider().opacity(0.35)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Danger zone")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    Button(role: .destructive) {
                        clearConfirm = true
                    } label: {
                        Label("Clear all history", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    if let msg = clearMessage {
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollContentBackground(.hidden)
        .confirmationDialog(
            "Clear all clipboard history?",
            isPresented: $clearConfirm
        ) {
            Button("Clear All", role: .destructive) { clearAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes every captured item, including favorites. This cannot be undone.")
        }
    }

    private func formatNumber(_ n: Int) -> String {
        n.formatted(.number.grouping(.automatic).locale(Locale(identifier: "en_US")))
    }

    private func enforceRetentionCap() {
        do {
            try (NSApp.delegate as? AppDelegate)?.historyStore?.enforceRetentionCap()
        } catch {
            NSLog("Retention update failed: %@", String(describing: error))
        }
    }

    @ViewBuilder
    private func section<Control: View>(
        title: String,
        valueLabel: String,
        description: String,
        @ViewBuilder control: () -> Control
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(valueLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            control()
            Text(description)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func clearAll() {
        let store = (NSApp.delegate as? AppDelegate)?.historyStore
        do {
            try store?.clearAll()
            clearMessage = "Cleared at \(Date().formatted(date: .omitted, time: .standard))"
        } catch {
            clearMessage = "Clear failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Privacy

private struct PrivacySettingsTab: View {
    @State private var settings = AppSettings.shared
    @State private var selection: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Excluded apps")
                    .font(.system(size: 13, weight: .semibold))
                Text("Anything copied while one of these apps is frontmost is never captured.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 12)

            List(selection: $selection) {
                ForEach(settings.excludedApps, id: \.self) { bundleID in
                    HStack(spacing: 10) {
                        Group {
                            if let icon = appIcon(for: bundleID) {
                                Image(nsImage: icon).resizable()
                            } else {
                                Image(systemName: "app.dashed").foregroundStyle(.tertiary)
                            }
                        }
                        .frame(width: 22, height: 22)
                        .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(displayName(for: bundleID))
                                .font(.system(size: 13))
                            Text(bundleID)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                    }
                    .tag(bundleID)
                    .padding(.vertical, 2)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(displayName(for: bundleID)), \(bundleID)")
                }
            }
            .accessibilityLabel("Excluded apps list")
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .padding(.horizontal, 16)

            HStack(spacing: 8) {
                Button {
                    addApp()
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel("Add app to exclusion list")
                Button {
                    removeSelected()
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(selection.isEmpty)
                .accessibilityLabel("Remove selected apps from exclusion list")
                Spacer()
                Button("Reset to defaults") {
                    settings.excludedApps = AppSettings.defaultExcludedApps
                    selection = []
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .accessibilityHint("Restores the built-in supported password-manager exclusions.")
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
        }
    }

    private func appIcon(for bundleID: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    private func displayName(for bundleID: String) -> String {
        let knownNames: [String: String] = [
            "com.1password.1password": "1Password 8",
            "com.agilebits.onepassword7": "1Password 7",
            "com.bitwarden.desktop": "Bitwarden",
            "com.dashlane.Dashlane": "Dashlane",
            "com.dashlane.5": "Dashlane (legacy)",
            "com.apple.keychainaccess": "Keychain Access",
            "com.apple.Passwords": "Passwords",
            "com.lastpass.LastPassMacApp": "LastPass",
            "com.lastpass.lastpassforsafari": "LastPass for Safari",
            "org.keepassxc.keepassxc": "KeePassXC"
        ]
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
              let bundle = Bundle(url: url)
        else { return knownNames[bundleID] ?? bundleID }
        return (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? knownNames[bundleID]
            ?? bundleID
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.title = "Choose an app to exclude"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK, let url = panel.url,
              let bundle = Bundle(url: url),
              let bid = bundle.bundleIdentifier
        else { return }
        if !settings.excludedApps.contains(bid) {
            settings.excludedApps.append(bid)
        }
    }

    private func removeSelected() {
        settings.excludedApps.removeAll { selection.contains($0) }
        selection = []
    }
}

// MARK: - About

private struct AboutTab: View {
    private var shortcutLabel: String {
        KeyboardShortcuts.getShortcut(for: .openHistory)?.description ?? "Set a shortcut in General"
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "list.clipboard")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.tint)
                .padding(.bottom, 4)
                .accessibilityHidden(true)
            VStack(spacing: 4) {
                Text("Clipboard History")
                    .font(.system(size: 20, weight: .semibold))
                Text("Version \(Bundle.main.shortVersion) (\(Bundle.main.buildNumber))")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Clipboard History, version \(Bundle.main.shortVersion), build \(Bundle.main.buildNumber)")
            Text("\(shortcutLabel) to open · pause from the menu bar")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .padding(.top, 6)
                .accessibilityLabel("\(shortcutLabel) opens clipboard history. Pause from the menu bar.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

private extension Bundle {
    var shortVersion: String {
        (object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0.0"
    }
    var buildNumber: String {
        (object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "0"
    }
}
