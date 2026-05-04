import SwiftUI
import GRDB

struct OverlayView: View {
    let store: HistoryStore
    let state: PanelState
    let onPaste: (ClipEntry) -> Void
    let onDismiss: () -> Void
    let onToggleFavorite: (ClipEntry) -> Void
    let onDelete: (ClipEntry) -> Void
    let onReveal: (ClipEntry) -> Void

    @State private var items: [ClipItem] = []
    @State private var query = ""
    @State private var selectionIndex = 0
    @State private var favoritesOnly = false
    @FocusState private var searchFocused: Bool

    private var displayed: [ClipItem] {
        var result = items
        if favoritesOnly {
            result = result.filter { $0.entry.isPinned }
        }
        let q = query.trimmingCharacters(in: .whitespaces)
        if !q.isEmpty {
            result = result.filter {
                $0.entry.displayTitle.localizedCaseInsensitiveContains(q)
                    || $0.entry.searchableText.localizedCaseInsensitiveContains(q)
            }
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search clipboard history…", text: $query)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                    .font(.system(size: 14))
                    .onSubmit {
                        if displayed.indices.contains(selectionIndex) {
                            onPaste(displayed[selectionIndex].entry)
                        }
                    }
                Button {
                    favoritesOnly.toggle()
                    selectionIndex = 0
                } label: {
                    Image(systemName: favoritesOnly ? "star.fill" : "star")
                        .foregroundStyle(favoritesOnly ? Color.yellow : Color.secondary)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .help(favoritesOnly ? "Show all (⇧⌘F)" : "Show favorites only (⇧⌘F)")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider().opacity(0.3)

            if displayed.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    List(Array(displayed.enumerated()), id: \.offset) { idx, item in
                        EntryRow(
                            item: item,
                            onToggleFavorite: { onToggleFavorite(item.entry) },
                            onDelete: { onDelete(item.entry) }
                        )
                            .listRowBackground(
                                idx == selectionIndex
                                    ? Color.accentColor.opacity(0.25)
                                    : Color.clear
                            )
                            .listRowSeparator(.hidden)
                            .id(idx)
                            .contentShape(Rectangle())
                            .onTapGesture { onPaste(item.entry) }
                            .contextMenu {
                                Button("Paste") { onPaste(item.entry) }
                                if item.entry.kind == .file || item.entry.kind == .multiFile {
                                    Button("Reveal in Finder") { onReveal(item.entry) }
                                }
                                Divider()
                                Button(item.entry.isPinned ? "Remove from Favorites" : "Add to Favorites") {
                                    onToggleFavorite(item.entry)
                                }
                                Divider()
                                Button("Delete", role: .destructive) { onDelete(item.entry) }
                            }
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.plain)
                    .onChange(of: selectionIndex) { _, new in
                        proxy.scrollTo(new, anchor: .center)
                    }
                }
            }

            Divider().opacity(0.3)

            HStack(spacing: 12) {
                hint("↑↓", "navigate")
                hint("⏎", "paste")
                hint("⌘D", "favorite")
                hint("⌘⌫", "delete")
                hint("⌘R", "reveal")
                hint("⎋", "close")
                Spacer()
                if state.isPaused {
                    pausedPill
                }
                Text("\(displayed.count) item\(displayed.count == 1 ? "" : "s")")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .frame(width: 720, height: 480)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        )
        .task {
            searchFocused = true
            do {
                for try await newItems in store.observeItems(limit: 100) {
                    items = newItems
                    if selectionIndex >= newItems.count {
                        selectionIndex = max(0, newItems.count - 1)
                    }
                }
            } catch {
                NSLog("Observation failed: %@", String(describing: error))
            }
        }
        .onChange(of: query) { _, _ in
            selectionIndex = 0
        }
        .onKeyPress(phases: [.down]) { press in
            handleKey(press)
        }
    }

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        let cmd = press.modifiers.contains(.command)
        let shift = press.modifiers.contains(.shift)

        if !cmd {
            switch press.key {
            case .return:
                if displayed.indices.contains(selectionIndex) {
                    onPaste(displayed[selectionIndex].entry)
                }
                return .handled
            case .escape:
                onDismiss()
                return .handled
            case .upArrow:
                if selectionIndex > 0 { selectionIndex -= 1 }
                return .handled
            case .downArrow:
                if selectionIndex < max(0, displayed.count - 1) { selectionIndex += 1 }
                return .handled
            default:
                return .ignored
            }
        }

        // Cmd-modified shortcuts — match on `press.key` (more reliable than `characters` with modifiers).
        if press.key == .delete {
            if displayed.indices.contains(selectionIndex) {
                onDelete(displayed[selectionIndex].entry)
                if selectionIndex >= displayed.count - 1 {
                    selectionIndex = max(0, displayed.count - 2)
                }
            }
            return .handled
        }

        if press.key == "d" {
            if displayed.indices.contains(selectionIndex) {
                onToggleFavorite(displayed[selectionIndex].entry)
            }
            return .handled
        }

        if press.key == "r" {
            if displayed.indices.contains(selectionIndex) {
                let entry = displayed[selectionIndex].entry
                if entry.kind == .file || entry.kind == .multiFile {
                    onReveal(entry)
                } else {
                    print("[Reveal] entry kind \(entry.kind) is not a file — ignored")
                }
            }
            return .handled
        }

        if press.key == "f" && shift {
            favoritesOnly.toggle()
            selectionIndex = 0
            return .handled
        }

        let digitMap: [(KeyEquivalent, Int)] = [
            ("1", 1), ("2", 2), ("3", 3), ("4", 4), ("5", 5),
            ("6", 6), ("7", 7), ("8", 8), ("9", 9)
        ]
        for (key, n) in digitMap where press.key == key {
            let idx = n - 1
            if displayed.indices.contains(idx) {
                onPaste(displayed[idx].entry)
            }
            return .handled
        }

        return .ignored
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: emptyIcon)
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text(emptyText)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            if items.isEmpty {
                Text(emptyHint)
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyIcon: String {
        if state.isPaused && items.isEmpty { return "pause.circle" }
        if favoritesOnly { return "star" }
        return "list.clipboard"
    }

    private var emptyText: String {
        if items.isEmpty {
            return state.isPaused
                ? "Recording is paused"
                : "Your clipboard history will appear here"
        }
        if favoritesOnly { return "No favorites yet — press ⌘D on any item" }
        return "No matches"
    }

    private var emptyHint: String {
        state.isPaused
            ? "Resume from the menu bar to start capturing again."
            : "Copy something to get started."
    }

    private var pausedPill: some View {
        HStack(spacing: 4) {
            Image(systemName: "pause.fill")
                .font(.system(size: 9, weight: .bold))
            Text("Paused")
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(Color.orange)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Color.orange.opacity(0.15))
        .clipShape(Capsule())
    }

    private func hint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }
}

private struct EntryRow: View {
    let item: ClipItem
    let onToggleFavorite: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            iconView
            VStack(alignment: .leading, spacing: 2) {
                Text(item.entry.displayTitle)
                    .lineLimit(1)
                    .font(.system(size: 13))
                if let sub = item.entry.displaySubtitle {
                    Text(sub)
                        .lineLimit(1)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Text(relative(item.entry.createdAt))
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)

            HStack(spacing: 4) {
                Button(action: onToggleFavorite) {
                    Image(systemName: item.entry.isPinned ? "star.fill" : "star")
                        .font(.system(size: 13))
                        .foregroundStyle(item.entry.isPinned ? Color.yellow : Color.secondary)
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(item.entry.isPinned ? "Remove from Favorites (⌘D)" : "Add to Favorites (⌘D)")
                .opacity(item.entry.isPinned || isHovering ? 1.0 : 0.45)

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.secondary)
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Delete (⌘⌫)")
                .opacity(isHovering ? 1.0 : 0.0)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .onHover { hovering in
            isHovering = hovering
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if let data = item.firstIcon, let nsImage = NSImage(data: data) {
            Image(nsImage: nsImage)
                .resizable()
                .interpolation(.medium)
                .scaledToFit()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
                )
        } else {
            Image(systemName: defaultIconName)
                .font(.system(size: 22))
                .foregroundStyle(.tertiary)
                .frame(width: 44, height: 44)
        }
    }

    private var defaultIconName: String {
        switch item.entry.kind {
        case .text:      return "text.alignleft"
        case .file:      return "doc"
        case .image:     return "photo"
        case .multiFile: return "doc.on.doc"
        case .richText:  return "doc.richtext"
        case .url:       return "link"
        }
    }

    private func relative(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: Date())
    }
}
