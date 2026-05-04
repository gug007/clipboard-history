import AppKit
import SwiftUI

struct OverlayTabStrip: View {
    let groups: [ClipGroup]
    @Binding var selectedFilter: HistoryStore.Filter
    @Binding var isCreating: Bool
    let onCreateGroup: (String) -> Void
    let onRenameGroup: (ClipGroup, String) -> Void
    let onDeleteGroup: (ClipGroup) -> Void

    @State private var newName = ""
    @FocusState private var newFieldFocused: Bool

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                tab(label: "All", systemImage: nil, isSelected: selectedFilter == .all) {
                    selectedFilter = .all
                }
                tab(
                    label: "Favorites",
                    systemImage: "star.fill",
                    isSelected: selectedFilter == .favorites
                ) {
                    selectedFilter = .favorites
                }
                ForEach(groups) { group in
                    groupTab(group)
                }
                if isCreating {
                    creationField
                } else {
                    plusButton
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private func tab(
        label: String,
        systemImage: String?,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 10))
                }
                Text(label)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(
                        isSelected
                            ? Color.accentColor.opacity(0.25)
                            : Color.secondary.opacity(0.08)
                    )
            )
            .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func groupTab(_ group: ClipGroup) -> some View {
        let isSelected: Bool = {
            if case .group(let id) = selectedFilter { return id == group.id }
            return false
        }()
        tab(label: group.name, systemImage: nil, isSelected: isSelected) {
            selectedFilter = .group(group.id)
        }
        .contextMenu {
            Button("Rename…") { renameViaAlert(group) }
            Divider()
            Button("Delete Group", role: .destructive) { onDeleteGroup(group) }
        }
    }

    private var plusButton: some View {
        Button {
            newName = ""
            isCreating = true
            DispatchQueue.main.async { newFieldFocused = true }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.secondary.opacity(0.08))
                )
                .foregroundStyle(Color.secondary)
        }
        .buttonStyle(.plain)
        .help("New Group")
    }

    private var creationField: some View {
        HStack(spacing: 4) {
            TextField("New group", text: $newName)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused($newFieldFocused)
                .frame(width: 110)
                .onSubmit { commitCreation() }
                .onExitCommand { cancelCreation() }
                .onKeyPress(.return) {
                    commitCreation()
                    return .handled
                }
                .onKeyPress(.escape) {
                    cancelCreation()
                    return .handled
                }
            Button(action: commitCreation) {
                Image(systemName: "return")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Create (Return)")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.secondary.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(0.4), lineWidth: 1)
        )
    }

    private func commitCreation() {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            onCreateGroup(trimmed)
        }
        cancelCreation()
    }

    private func cancelCreation() {
        isCreating = false
        newName = ""
        newFieldFocused = false
    }

    private func renameViaAlert(_ group: ClipGroup) {
        let alert = NSAlert()
        alert.messageText = "Rename Group"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        field.stringValue = group.name
        alert.accessoryView = field
        if alert.runModal() == .alertFirstButtonReturn {
            onRenameGroup(group, field.stringValue)
        }
    }
}
