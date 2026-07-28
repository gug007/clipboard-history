import SwiftUI

/// The one place the overlay's key map is written down.
///
/// Rendered both inside the panel (Cmd-/) and in Settings, so the two can
/// never drift apart.
enum ShortcutsReference {
    struct Shortcut: Identifiable {
        let keys: String
        let label: String
        var id: String { keys + label }
    }

    struct Section: Identifiable {
        let title: String
        let shortcuts: [Shortcut]
        var id: String { title }
    }

    static let sections: [Section] = [
        Section(title: "Navigate", shortcuts: [
            Shortcut(keys: "↑ ↓", label: "Move selection"),
            Shortcut(keys: "⇞ ⇟", label: "Jump a page"),
            Shortcut(keys: "⌘↑ ⌘↓", label: "First / last clip"),
            Shortcut(keys: "⌃⇥ ⌃⇧⇥", label: "Next / previous tab"),
            Shortcut(keys: "⌥1–9", label: "Jump to tab"),
        ]),
        Section(title: "Use a clip", shortcuts: [
            Shortcut(keys: "⏎", label: "Paste highlighted clip"),
            Shortcut(keys: "⌘1–9", label: "Paste clip 1–9 directly"),
            Shortcut(keys: "⌘C", label: "Copy without pasting"),
            Shortcut(keys: "⌘Y", label: "Preview full contents"),
            Shortcut(keys: "⌘R", label: "Reveal file in Finder"),
        ]),
        Section(title: "Organize", shortcuts: [
            Shortcut(keys: "⌘D", label: "Star / un-star"),
            Shortcut(keys: "⌘⌫", label: "Delete clip"),
            Shortcut(keys: "⇧⌘F", label: "Jump to starred"),
        ]),
        Section(title: "Search & window", shortcuts: [
            Shortcut(keys: "⌘F", label: "Focus the search field"),
            Shortcut(keys: "⎋", label: "Clear search, then close"),
            Shortcut(keys: "⌘/", label: "Show this list"),
        ]),
    ]

    static let windowTip =
        "Drag any edge to resize the overlay · drag the background to move it"
}

struct ShortcutKeyCap: View {
    let keys: String

    var body: some View {
        // Deliberately not monospaced: SF Mono has no glyphs for ⇞ ⇟ ⌫ ⇥ ⎋
        // and renders them as replacement boxes.
        Text(keys)
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

struct ShortcutsGrid: View {
    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 24, alignment: .topLeading),
                GridItem(.flexible(), spacing: 24, alignment: .topLeading),
            ],
            alignment: .leading,
            spacing: 18
        ) {
            ForEach(ShortcutsReference.sections) { section in
                VStack(alignment: .leading, spacing: 6) {
                    Text(section.title)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    ForEach(section.shortcuts) { shortcut in
                        HStack(spacing: 8) {
                            ShortcutKeyCap(keys: shortcut.keys)
                            Text(shortcut.label)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(shortcut.keys), \(shortcut.label)")
                    }
                }
            }
        }
    }
}

/// In-panel keyboard reference, opened with Cmd-/.
///
/// The footer can only advertise a handful of keys before it becomes noise,
/// which left the faster shortcuts — direct paste, copy-without-paste, tab
/// cycling — effectively undiscoverable. This is where the full set lives.
struct OverlayShortcutsView: View {
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Keyboard shortcuts")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Close (⎋)")
                .accessibilityLabel("Close keyboard shortcuts")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)

            Divider().opacity(0.18)

            ScrollView {
                ShortcutsGrid()
                    .padding(16)
            }

            Divider().opacity(0.18)

            Text(ShortcutsReference.windowTip)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 24, y: 8)
    }
}
