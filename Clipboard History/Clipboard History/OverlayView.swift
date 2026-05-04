import SwiftUI
import GRDB

struct OverlayView: View {
    let store: HistoryStore
    let onPaste: (ClipEntry) -> Void
    let onDismiss: () -> Void

    @State private var items: [ClipItem] = []
    @State private var query = ""
    @State private var selectionIndex = 0
    @FocusState private var searchFocused: Bool

    private var displayed: [ClipItem] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return items }
        return items.filter {
            $0.entry.displayTitle.localizedCaseInsensitiveContains(q)
                || $0.entry.searchableText.localizedCaseInsensitiveContains(q)
        }
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
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider().opacity(0.3)

            if displayed.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    List(Array(displayed.enumerated()), id: \.offset) { idx, item in
                        EntryRow(item: item)
                            .listRowBackground(
                                idx == selectionIndex
                                    ? Color.accentColor.opacity(0.25)
                                    : Color.clear
                            )
                            .listRowSeparator(.hidden)
                            .id(idx)
                            .contentShape(Rectangle())
                            .onTapGesture { onPaste(item.entry) }
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.plain)
                    .onChange(of: selectionIndex) { _, new in
                        proxy.scrollTo(new, anchor: .center)
                    }
                }
            }

            Divider().opacity(0.3)

            HStack(spacing: 14) {
                hint("↑↓", "navigate")
                hint("⏎", "paste")
                hint("⎋", "close")
                Spacer()
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
        .onKeyPress(.return) {
            if displayed.indices.contains(selectionIndex) {
                onPaste(displayed[selectionIndex].entry)
            }
            return .handled
        }
        .onKeyPress(.escape) {
            onDismiss()
            return .handled
        }
        .onKeyPress(.upArrow) {
            if selectionIndex > 0 { selectionIndex -= 1 }
            return .handled
        }
        .onKeyPress(.downArrow) {
            if selectionIndex < max(0, displayed.count - 1) { selectionIndex += 1 }
            return .handled
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.clipboard")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text(items.isEmpty
                 ? "Your clipboard history will appear here"
                 : "No matches")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            if items.isEmpty {
                Text("Copy something to get started.")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    var body: some View {
        HStack(spacing: 10) {
            iconView
                .frame(width: 28, height: 28)
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
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var iconView: some View {
        if let data = item.firstIcon, let nsImage = NSImage(data: data) {
            Image(nsImage: nsImage)
                .resizable()
                .interpolation(.medium)
                .scaledToFit()
        } else {
            Image(systemName: defaultIconName)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
