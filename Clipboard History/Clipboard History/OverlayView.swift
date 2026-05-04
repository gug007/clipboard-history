import SwiftUI

struct OverlayView: View {
    let onPaste: (String) -> Void
    let onDismiss: () -> Void

    @State private var query = ""
    @State private var selectionIndex = 0
    @FocusState private var searchFocused: Bool

    private let allItems: [String] = (1...50).map { i in
        "Clipboard item #\(i) — sample text for the M0 spike"
    }

    private var items: [String] {
        guard !query.isEmpty else { return allItems }
        return allItems.filter { $0.localizedCaseInsensitiveContains(query) }
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

            ScrollViewReader { proxy in
                List(Array(items.enumerated()), id: \.offset) { idx, item in
                    HStack(spacing: 10) {
                        Image(systemName: "doc.on.clipboard")
                            .foregroundStyle(.tertiary)
                        Text(item)
                            .lineLimit(1)
                            .font(.system(size: 13))
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .listRowBackground(
                        idx == selectionIndex
                            ? Color.accentColor.opacity(0.25)
                            : Color.clear
                    )
                    .listRowSeparator(.hidden)
                    .id(idx)
                    .contentShape(Rectangle())
                    .onTapGesture { onPaste(item) }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.plain)
                .onChange(of: selectionIndex) { _, new in
                    proxy.scrollTo(new, anchor: .center)
                }
            }

            Divider().opacity(0.3)

            HStack(spacing: 14) {
                hint("↑↓", "navigate")
                hint("⏎", "paste")
                hint("⎋", "close")
                Spacer()
                Text("M0 spike — \(items.count) items")
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
        .onAppear {
            searchFocused = true
            selectionIndex = 0
        }
        .onChange(of: query) { _, _ in
            selectionIndex = 0
        }
        .onKeyPress(.return) {
            if items.indices.contains(selectionIndex) {
                onPaste(items[selectionIndex])
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
            if selectionIndex < max(0, items.count - 1) { selectionIndex += 1 }
            return .handled
        }
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
