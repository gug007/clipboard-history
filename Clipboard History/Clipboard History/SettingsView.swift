import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {
    var body: some View {
        TabView {
            StorageSettingsTab()
                .tabItem { Label("Storage", systemImage: "internaldrive") }
            PrivacySettingsTab()
                .tabItem { Label("Privacy", systemImage: "hand.raised") }
            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 520, height: 420)
    }
}

private struct StorageSettingsTab: View {
    @State private var settings = AppSettings.shared
    @State private var clearConfirm = false
    @State private var clearMessage: String?

    var body: some View {
        Form {
            Section("History size") {
                HStack {
                    Slider(
                        value: Binding(
                            get: { Double(settings.retentionCap) },
                            set: { settings.retentionCap = Int($0) }
                        ),
                        in: 100...10_000,
                        step: 100
                    )
                    Text("\(settings.retentionCap) items")
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 100, alignment: .trailing)
                }
                Text("Older non-favorited items are auto-removed once you exceed this cap.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Maximum file size to capture") {
                HStack {
                    Slider(
                        value: Binding(
                            get: { Double(settings.perFileSizeCapMB) },
                            set: { settings.perFileSizeCapMB = Int($0) }
                        ),
                        in: 1...100,
                        step: 1
                    )
                    Text("\(settings.perFileSizeCapMB) MB")
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 100, alignment: .trailing)
                }
                Text("Files larger than this still appear in history as metadata, but their bytes won't be uploaded to iCloud.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Danger zone") {
                Button(role: .destructive) {
                    clearConfirm = true
                } label: {
                    Label("Clear All History", systemImage: "trash")
                }
                if let msg = clearMessage {
                    Text(msg).font(.callout).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .confirmationDialog(
            "Clear all clipboard history?",
            isPresented: $clearConfirm
        ) {
            Button("Clear All", role: .destructive) {
                clearAll()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes every captured item, including favorites. This cannot be undone.")
        }
    }

    private func clearAll() {
        let store = (NSApp.delegate as? AppDelegate)?.historyStore
        do {
            try store?.clearAll()
            clearMessage = "History cleared at \(Date().formatted(date: .omitted, time: .standard))."
        } catch {
            clearMessage = "Clear failed: \(error.localizedDescription)"
        }
    }
}

private struct PrivacySettingsTab: View {
    @State private var settings = AppSettings.shared
    @State private var selection: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Excluded apps")
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 6)
            Text("Anything copied while one of these apps is frontmost is never captured. Password managers and Keychain Access are excluded by default.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            List(selection: $selection) {
                ForEach(settings.excludedApps, id: \.self) { bundleID in
                    HStack {
                        if let icon = appIcon(for: bundleID) {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 20, height: 20)
                        } else {
                            Image(systemName: "app.dashed")
                                .foregroundStyle(.tertiary)
                                .frame(width: 20, height: 20)
                        }
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
                }
            }
            .listStyle(.bordered(alternatesRowBackgrounds: true))
            .padding(.horizontal, 16)

            HStack(spacing: 8) {
                Button {
                    addApp()
                } label: {
                    Image(systemName: "plus")
                }
                Button {
                    removeSelected()
                } label: {
                    Image(systemName: "minus")
                }
                .disabled(selection.isEmpty)
                Spacer()
                Button("Reset to defaults") {
                    settings.excludedApps = AppSettings.defaultExcludedApps
                    selection = []
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
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
              let bundle = Bundle(url: url),
              let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
        else {
            return bundleID
        }
        return name
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

private struct AboutTab: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.clipboard")
                .font(.system(size: 60))
                .foregroundStyle(.tint)
            Text("Clipboard History")
                .font(.title)
                .fontWeight(.semibold)
            Text("Version \(Bundle.main.shortVersion) (\(Bundle.main.buildNumber))")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("⇧⌘V to open · paused/resumed from the menu bar")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
