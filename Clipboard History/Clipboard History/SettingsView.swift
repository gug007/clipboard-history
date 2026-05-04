import SwiftUI
import AppKit
import KeyboardShortcuts
import UniformTypeIdentifiers

struct SettingsView: View {
    @State private var selection: Tab = .general

    enum Tab: Hashable {
        case general, storage, privacy, about
    }

    private var detailTitle: String {
        switch selection {
        case .general: return "General"
        case .storage: return "Storage"
        case .privacy: return "Privacy"
        case .about:   return "About"
        }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                NavigationLink(value: Tab.general) {
                    Label("General", systemImage: "gear")
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
                case .general: GeneralSettingsTab()
                case .storage: StorageSettingsTab()
                case .privacy: PrivacySettingsTab()
                case .about:   AboutTab()
                }
            }
            .navigationTitle(detailTitle)
        }
        .frame(width: 700, height: 480)
        .onDisappear {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

// MARK: - General

private struct GeneralSettingsTab: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Open clipboard history")
                            .font(.system(size: 13, weight: .semibold))
                        Spacer()
                        KeyboardShortcuts.Recorder(for: .openHistory)
                    }
                    Text("Press this shortcut from anywhere to open the history overlay.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
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
                    description: "Older non-favorited items are auto-removed once you exceed this cap."
                ) {
                    Slider(
                        value: Binding(
                            get: { Double(settings.retentionCap) },
                            set: { settings.retentionCap = Int($0) }
                        ),
                        in: 100...10_000,
                        step: 100
                    )
                    .controlSize(.small)
                }

                Divider().opacity(0.35)

                section(
                    title: "Maximum file size to capture",
                    valueLabel: "\(settings.perFileSizeCapMB) MB",
                    description: "Files larger than this still appear in history as metadata, but their bytes won't be uploaded to iCloud."
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
                }
            }
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
                Button {
                    removeSelected()
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(selection.isEmpty)
                Spacer()
                Button("Reset to defaults") {
                    settings.excludedApps = AppSettings.defaultExcludedApps
                    selection = []
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
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
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
              let bundle = Bundle(url: url)
        else { return bundleID }
        return (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
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
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "list.clipboard")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.tint)
                .padding(.bottom, 4)
            VStack(spacing: 4) {
                Text("Clipboard History")
                    .font(.system(size: 20, weight: .semibold))
                Text("Version \(Bundle.main.shortVersion) (\(Bundle.main.buildNumber))")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Text("⇧⌘V to open · pause from the menu bar")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .padding(.top, 6)
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
