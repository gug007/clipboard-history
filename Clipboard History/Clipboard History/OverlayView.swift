import AppKit
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
    @State private var groups: [ClipGroup] = []
    @State private var query = ""
    @State private var selectionIndex = 0
    @State private var selectedFilter: HistoryStore.Filter = .all
    @State private var isCreatingGroup = false
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
                    .onSubmit {
                        if displayed.indices.contains(selectionIndex) {
                            onPaste(displayed[selectionIndex].entry)
                        }
                    }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider().opacity(0.3)

            OverlayTabStrip(
                groups: groups,
                selectedFilter: $selectedFilter,
                isCreating: $isCreatingGroup,
                onCreateGroup: { name in createGroup(named: name) },
                onRenameGroup: { group, name in renameGroup(group, to: name) },
                onDeleteGroup: { group in deleteGroup(group) }
            )

            Divider().opacity(0.3)

            if displayed.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    List(Array(displayed.enumerated()), id: \.offset) { idx, item in
                        rowView(for: item, at: idx)
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
                Group {
                    hint("↑↓", "navigate")
                    hint("⏎", "paste")
                    hint("⌘D", "favorite")
                    hint("⌥1-9", "tabs")
                    hint("⌘⌫", "delete")
                    hint("⎋", "close")
                }
                .accessibilityHidden(true)
                Spacer()
                if state.isPaused {
                    pausedPill
                }
                Text("\(displayed.count) item\(displayed.count == 1 ? "" : "s")")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .accessibilityLabel("\(displayed.count) clipboard \(displayed.count == 1 ? "item" : "items")")
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
        }
        .task(id: selectedFilter) {
            do {
                for try await newItems in store.observeItems(limit: 100, filter: selectedFilter) {
                    items = newItems
                    if selectionIndex >= newItems.count {
                        selectionIndex = max(0, newItems.count - 1)
                    }
                }
            } catch {
                NSLog("Observation failed: %@", String(describing: error))
            }
        }
        .task {
            do {
                for try await newGroups in store.observeGroups() {
                    groups = newGroups
                    pruneSelectedFilterIfNeeded()
                }
            } catch {
                NSLog("Group observation failed: %@", String(describing: error))
            }
        }
        .onChange(of: query) { _, _ in
            selectionIndex = 0
        }
        .onChange(of: selectedFilter) { _, _ in
            selectionIndex = 0
        }
        .onKeyPress(phases: [.down]) { press in
            handleKey(press)
        }
    }

    private func pruneSelectedFilterIfNeeded() {
        if case .group(let id) = selectedFilter, !groups.contains(where: { $0.id == id }) {
            selectedFilter = .all
        }
    }

    private func createGroup(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            let group = try store.createGroup(name: trimmed)
            selectedFilter = .group(group.id)
        } catch {
            NSLog("createGroup failed: %@", String(describing: error))
        }
    }

    private func renameGroup(_ group: ClipGroup, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != group.name else { return }
        do {
            try store.renameGroup(id: group.id, to: trimmed)
        } catch {
            NSLog("renameGroup failed: %@", String(describing: error))
        }
    }

    private func deleteGroup(_ group: ClipGroup) {
        do {
            try store.deleteGroup(id: group.id)
            if selectedFilter == .group(group.id) {
                selectedFilter = .all
            }
        } catch {
            NSLog("deleteGroup failed: %@", String(describing: error))
        }
    }

    private func toggleMembership(entryId: String, group: ClipGroup) {
        do {
            let current = try store.groupIds(for: entryId)
            try store.setMembership(
                entryId: entryId,
                groupId: group.id,
                member: !current.contains(group.id)
            )
        } catch {
            NSLog("toggleMembership failed: %@", String(describing: error))
        }
    }

    private func memberGroupIds(for entryId: String) -> Set<String> {
        (try? store.groupIds(for: entryId)) ?? []
    }

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        let cmd = press.modifiers.contains(.command)
        let shift = press.modifiers.contains(.shift)
        let option = press.modifiers.contains(.option)

        if option && !cmd {
            if let result = handleOptionDigit(press), result == .handled {
                return .handled
            }
        }

        if !cmd {
            switch press.key {
            case .return:
                if isCreatingGroup { return .ignored }
                if displayed.indices.contains(selectionIndex) {
                    onPaste(displayed[selectionIndex].entry)
                }
                return .handled
            case .escape:
                if isCreatingGroup { return .ignored }
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
            selectedFilter = .favorites
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

    private func handleOptionDigit(_ press: KeyPress) -> KeyPress.Result? {
        let digitMap: [(KeyEquivalent, Int)] = [
            ("1", 1), ("2", 2), ("3", 3), ("4", 4), ("5", 5),
            ("6", 6), ("7", 7), ("8", 8), ("9", 9)
        ]
        for (key, n) in digitMap where press.key == key {
            switch n {
            case 1: selectedFilter = .all
            case 2: selectedFilter = .favorites
            default:
                let groupIndex = n - 3
                if groups.indices.contains(groupIndex) {
                    selectedFilter = .group(groups[groupIndex].id)
                }
            }
            return .handled
        }
        return nil
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: emptyIcon)
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(items.isEmpty ? "\(emptyText). \(emptyHint)" : emptyText)
    }

    private var emptyIcon: String {
        if state.isPaused && items.isEmpty { return "pause.circle" }
        switch selectedFilter {
        case .favorites: return "star"
        case .group: return "folder"
        case .all: return "list.clipboard"
        }
    }

    private var emptyText: String {
        if items.isEmpty {
            switch selectedFilter {
            case .all:
                return state.isPaused
                    ? "Recording is paused"
                    : "Your clipboard history will appear here"
            case .favorites:
                return "No favorites yet — press ⌘D on any item"
            case .group(let id):
                let name = groups.first(where: { $0.id == id })?.name ?? "this group"
                return "No items in \(name) yet — right-click any clip to add"
            }
        }
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Recording paused. Resume from the menu bar.")
    }

    @ViewBuilder
    private func rowView(for item: ClipItem, at idx: Int) -> some View {
        let isSelected = idx == selectionIndex
        let rowBackground: Color = isSelected ? Color.accentColor.opacity(0.25) : Color.clear
        let traits: AccessibilityTraits = isSelected ? [.isButton, .isSelected] : .isButton
        let favoriteActionName: String = item.entry.isPinned ? "Remove from favorites" : "Add to favorites"
        let canReveal = item.entry.kind == .file || item.entry.kind == .multiFile

        EntryRow(
            item: item,
            onToggleFavorite: { onToggleFavorite(item.entry) },
            onDelete: { onDelete(item.entry) }
        )
        .listRowBackground(rowBackground)
        .listRowSeparator(.hidden)
        .id(idx)
        .contentShape(Rectangle())
        .onTapGesture { onPaste(item.entry) }
        .contextMenu { rowContextMenu(for: item) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rowAccessibilityLabel(for: item))
        .accessibilityHint("Press Return to paste")
        .accessibilityAddTraits(traits)
        .accessibilityAction(named: favoriteActionName) { onToggleFavorite(item.entry) }
        .accessibilityAction(named: "Delete") { onDelete(item.entry) }
        .accessibilityAction(named: "Reveal in Finder") {
            if canReveal { onReveal(item.entry) }
        }
    }

    @ViewBuilder
    private func rowContextMenu(for item: ClipItem) -> some View {
        Button("Paste") { onPaste(item.entry) }
        if item.entry.kind == .file || item.entry.kind == .multiFile {
            Button("Reveal in Finder") { onReveal(item.entry) }
        }
        Divider()
        Button(item.entry.isPinned ? "Remove from Favorites" : "Add to Favorites") {
            onToggleFavorite(item.entry)
        }
        groupMembershipMenu(for: item)
        Divider()
        Button("Delete", role: .destructive) { onDelete(item.entry) }
    }

    @ViewBuilder
    private func groupMembershipMenu(for item: ClipItem) -> some View {
        let memberIds = memberGroupIds(for: item.entry.id)
        Menu("Groups") {
            if groups.isEmpty {
                Text("No groups yet")
            } else {
                ForEach(groups) { group in
                    Button {
                        toggleMembership(entryId: item.entry.id, group: group)
                    } label: {
                        Label(
                            group.name,
                            systemImage: memberIds.contains(group.id) ? "checkmark" : ""
                        )
                    }
                }
            }
            Divider()
            Button("New Group…") { addToNewGroup(entryId: item.entry.id) }
        }
    }

    private func addToNewGroup(entryId: String) {
        let alert = NSAlert()
        alert.messageText = "New Group"
        alert.informativeText = "Name this group and add the selected clip to it."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        field.placeholderString = "Group name"
        alert.accessoryView = field
        if alert.runModal() == .alertFirstButtonReturn {
            let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return }
            do {
                let group = try store.createGroup(name: name)
                try store.setMembership(entryId: entryId, groupId: group.id, member: true)
                selectedFilter = .group(group.id)
            } catch {
                NSLog("addToNewGroup failed: %@", String(describing: error))
            }
        }
    }

    private func rowAccessibilityLabel(for item: ClipItem) -> String {
        var parts: [String] = []
        parts.append(item.entry.displayTitle)
        switch item.entry.kind {
        case .text, .url, .richText:
            break
        case .file:      parts.append("file")
        case .multiFile: parts.append("multiple files")
        case .image:     parts.append("image")
        }
        if let sub = item.entry.displaySubtitle {
            parts.append(sub)
        }
        if item.entry.isPinned { parts.append("favorited") }
        if !item.groupNames.isEmpty {
            parts.append("in \(item.groupNames.joined(separator: ", "))")
        }
        if item.isStale { parts.append("file has been moved or deleted") }
        parts.append(accessibleRelativeTime(item.entry.createdAt))
        return parts.joined(separator: ", ")
    }

    private func accessibleRelativeTime(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f.localizedString(for: date, relativeTo: Date())
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
    @State private var showPreview = false

    var body: some View {
        HStack(spacing: 12) {
            iconView
                .opacity(item.isStale ? 0.4 : 1.0)
            VStack(alignment: .leading, spacing: 2) {
                Text(bodyText)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .font(.system(size: 13))
                    .strikethrough(item.isStale, color: .secondary)
                    .foregroundStyle(item.isStale ? Color.secondary : Color.primary)
                if item.entry.displaySubtitle != nil || !item.groupNames.isEmpty {
                    HStack(spacing: 6) {
                        if let sub = item.entry.displaySubtitle {
                            Text(sub)
                                .lineLimit(1)
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                        }
                        ForEach(item.groupNames, id: \.self) { name in
                            Text(name)
                                .font(.system(size: 9, weight: .medium))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(
                                    Capsule().fill(Color.accentColor.opacity(0.18))
                                )
                                .foregroundStyle(Color.accentColor)
                                .lineLimit(1)
                        }
                    }
                }
            }
            Spacer()
            if item.isStale {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                    .help("File has been moved or deleted")
                    .opacity(isHovering ? 1.0 : 0.0)
            }

            HStack(spacing: 4) {
                Button(action: onToggleFavorite) {
                    Image(systemName: "star")
                        .font(.system(size: 13, weight: item.entry.isPinned ? .semibold : .regular))
                        .foregroundStyle(item.entry.isPinned ? Color.yellow : Color.secondary)
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(item.entry.isPinned ? "Remove from Favorites (⌘D)" : "Add to Favorites (⌘D)")
                .opacity(item.entry.isPinned || isHovering ? 1.0 : 0.0)

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

            Text(relative(item.entry.createdAt))
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .frame(width: 64, alignment: .trailing)
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
            Button {
                showPreview.toggle()
            } label: {
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
            }
            .buttonStyle(.plain)
            .help("Show preview")
            .popover(isPresented: $showPreview, arrowEdge: .trailing) {
                PreviewPopover(image: nsImage)
            }
        } else {
            Image(systemName: defaultIconName)
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(.tertiary)
                .frame(width: 44, height: 44)
        }
    }

    private var defaultIconName: String {
        switch item.entry.kind {
        case .text:      return "textformat"
        case .file:      return "doc"
        case .image:     return "photo"
        case .multiFile: return "doc.on.doc"
        case .richText:  return "doc.richtext"
        case .url:       return "link"
        }
    }

    private var bodyText: String {
        switch item.entry.kind {
        case .text, .url, .richText:
            let lines = item.entry.searchableText
                .split(separator: "\n", maxSplits: 3, omittingEmptySubsequences: true)
                .prefix(3)
                .map { String($0.prefix(200)) }
            return lines.isEmpty ? item.entry.displayTitle : lines.joined(separator: "\n")
        case .file, .multiFile, .image:
            return item.entry.displayTitle
        }
    }

    private func relative(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: Date())
    }
}

private struct PreviewPopover: View {
    let image: NSImage

    private var fittedSize: CGSize {
        let maxSide: CGFloat = 360
        let minSide: CGFloat = 160
        let w = max(image.size.width, 1)
        let h = max(image.size.height, 1)
        let scale = min(maxSide / w, maxSide / h, 1)
        let fitted = CGSize(width: w * scale, height: h * scale)
        if max(fitted.width, fitted.height) < minSide {
            let up = minSide / max(fitted.width, fitted.height)
            return CGSize(width: fitted.width * up, height: fitted.height * up)
        }
        return fitted
    }

    var body: some View {
        Image(nsImage: image)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: fittedSize.width, height: fittedSize.height)
            .padding(10)
    }
}
