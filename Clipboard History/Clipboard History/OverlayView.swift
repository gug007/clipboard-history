import AppKit
import SwiftUI
import GRDB

struct OverlayView: View {
    let store: HistoryStore
    let state: PanelState
    let onPaste: (ClipEntry) -> Void
    let onCopy: (ClipEntry) -> Void
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
    @State private var isPreviewing = false
    @State private var showShortcuts = false
    @FocusState private var searchFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    private let settings = AppSettings.shared

    /// Rows an arrow-key page jump covers. Fixed rather than measured: the
    /// list has no reliable viewport metric here, and a predictable stride is
    /// easier to build muscle memory around than a size-dependent one.
    private let pageStride = 8

    private struct ItemObservationRequest: Hashable {
        let filter: HistoryStore.Filter
        let query: String
    }

    private var itemObservationRequest: ItemObservationRequest {
        ItemObservationRequest(
            filter: selectedFilter,
            query: query.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private var isSearching: Bool {
        !itemObservationRequest.query.isEmpty
    }

    private var displayed: [ClipItem] {
        items
    }

    private var selectedItem: ClipItem? {
        displayed.indices.contains(selectionIndex) ? displayed[selectionIndex] : nil
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar

            Divider().opacity(0.18)

            OverlayTabStrip(
                groups: groups,
                selectedFilter: $selectedFilter,
                isCreating: $isCreatingGroup,
                onCreateGroup: { name in createGroup(named: name) },
                onRenameGroup: { group, name in renameGroup(group, to: name) },
                onDeleteGroup: { group in deleteGroup(group) }
            )

            Divider().opacity(0.18)

            if displayed.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    List(Array(displayed.enumerated()), id: \.element.id) { idx, item in
                        rowView(for: item, at: idx)
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.plain)
                    .environment(\.defaultMinListRowHeight, 0)
                    .onChange(of: selectionIndex) { _, new in
                        guard displayed.indices.contains(new) else { return }
                        proxy.scrollTo(displayed[new].id, anchor: .center)
                    }
                }
            }

            Divider().opacity(0.18)

            footer
        }
        .frame(
            minWidth: AppSettings.minOverlaySize.width,
            maxWidth: .infinity,
            minHeight: AppSettings.minOverlaySize.height,
            maxHeight: .infinity
        )
        .background {
            if colorScheme == .light {
                Color.white
            } else {
                Color(red: 0.165, green: 0.165, blue: 0.165)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .overlay { previewLayer }
        .overlay { shortcutsLayer }
        .preferredColorScheme(settings.appearance.colorScheme)
        .task {
            searchFocused = true
        }
        .task(id: itemObservationRequest) {
            let request = itemObservationRequest
            do {
                if !request.query.isEmpty {
                    try await Task.sleep(nanoseconds: 180_000_000)
                }
                try Task.checkCancellation()

                for try await newItems in store.observeItems(
                    limit: 100,
                    filter: request.filter,
                    query: request.query
                ) {
                    try Task.checkCancellation()
                    guard request == itemObservationRequest else { return }

                    let selectedID = displayed.indices.contains(selectionIndex)
                        ? displayed[selectionIndex].id
                        : nil
                    items = newItems
                    if let selectedID,
                       let newIndex = newItems.firstIndex(where: { $0.id == selectedID }) {
                        selectionIndex = newIndex
                    } else if selectionIndex >= newItems.count {
                        selectionIndex = max(0, newItems.count - 1)
                    }
                }
            } catch is CancellationError {
                // Expected when the query or active tab changes.
            } catch {
                guard !Task.isCancelled else { return }
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
        .onChange(of: itemObservationRequest) { _, _ in
            items = []
            selectionIndex = 0
            isPreviewing = false
        }
        .onKeyPress(phases: [.down]) { press in
            handleKey(press)
        }
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField("Search clipboard history…", text: $query)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .font(.system(size: 15))
                .onSubmit {
                    if let selectedItem {
                        onPaste(selectedItem.entry)
                    }
                }
            if !query.isEmpty {
                Button {
                    query = ""
                    searchFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Clear search (⎋)")
                .accessibilityLabel("Clear search")
                .transition(.opacity)
            }
            themeToggleButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .animation(.easeOut(duration: 0.12), value: query.isEmpty)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            Group {
                hint("↑↓", "navigate")
                hint("⏎", "paste")
                hint("⌘Y", "preview")
                hint("⌘C", "copy")
            }
            .accessibilityHidden(true)

            Button {
                showShortcuts = true
            } label: {
                hint("⌘/", "shortcuts")
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Show all keyboard shortcuts")
            .accessibilityLabel("Show all keyboard shortcuts")

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

    // MARK: - Overlaid layers

    @ViewBuilder
    private var previewLayer: some View {
        if isPreviewing, let selectedItem {
            ZStack {
                Color.black.opacity(0.28)
                    .contentShape(Rectangle())
                    .onTapGesture { isPreviewing = false }
                ClipPreviewView(
                    item: selectedItem,
                    store: store,
                    onPaste: { onPaste(selectedItem.entry) },
                    onCopy: { onCopy(selectedItem.entry) },
                    onClose: { isPreviewing = false }
                )
                .padding(24)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var shortcutsLayer: some View {
        if showShortcuts {
            ZStack {
                Color.black.opacity(0.28)
                    .contentShape(Rectangle())
                    .onTapGesture { showShortcuts = false }
                OverlayShortcutsView { showShortcuts = false }
                    .frame(maxWidth: 620, maxHeight: 400)
                    .padding(24)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .transition(.opacity)
        }
    }

    // MARK: - Groups

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

    /// Left-to-right order of the tab strip, so Ctrl-Tab walks exactly what
    /// the user sees.
    private var orderedFilters: [HistoryStore.Filter] {
        [.all, .favorites] + groups.map { HistoryStore.Filter.group($0.id) }
    }

    private func cycleTab(by delta: Int) {
        let all = orderedFilters
        guard !all.isEmpty else { return }
        guard let current = all.firstIndex(of: selectedFilter) else {
            selectedFilter = .all
            return
        }
        let next = (current + delta + all.count) % all.count
        selectedFilter = all[next]
    }

    // MARK: - Keyboard

    private func select(_ index: Int) {
        guard !displayed.isEmpty else { return }
        selectionIndex = min(max(index, 0), displayed.count - 1)
    }

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        let cmd = press.modifiers.contains(.command)
        let shift = press.modifiers.contains(.shift)
        let option = press.modifiers.contains(.option)

        // Escape unwinds one layer per press rather than always closing the
        // panel: cheat sheet, then preview, then a narrowing search, then out.
        if press.key == .escape {
            if isCreatingGroup { return .ignored }
            if showShortcuts {
                showShortcuts = false
                return .handled
            }
            if isPreviewing {
                isPreviewing = false
                return .handled
            }
            if !query.isEmpty {
                query = ""
                searchFocused = true
                return .handled
            }
            onDismiss()
            return .handled
        }

        if cmd && press.key == "/" {
            showShortcuts.toggle()
            return .handled
        }

        // The cheat sheet is deliberately modal: it covers the list, so letting
        // Return through would paste a clip the user can no longer see.
        if showShortcuts {
            if press.key == .return { showShortcuts = false }
            return .handled
        }

        if option && !cmd {
            if let result = handleOptionDigit(press), result == .handled {
                return .handled
            }
        }

        if !cmd {
            switch press.key {
            case .return:
                if isCreatingGroup { return .ignored }
                if let selectedItem {
                    onPaste(selectedItem.entry)
                }
                return .handled
            case .upArrow:
                select(selectionIndex - 1)
                return .handled
            case .downArrow:
                select(selectionIndex + 1)
                return .handled
            case .pageUp:
                select(selectionIndex - pageStride)
                return .handled
            case .pageDown:
                select(selectionIndex + pageStride)
                return .handled
            case .home:
                select(0)
                return .handled
            case .end:
                select(displayed.count - 1)
                return .handled
            case .tab:
                // Only Control-Tab cycles tabs. Claiming plain Tab would take
                // focus traversal away from keyboard-only users, and Ctrl-Tab
                // is what macOS already means by "next tab".
                guard press.modifiers.contains(.control), !isCreatingGroup else {
                    return .ignored
                }
                cycleTab(by: shift ? -1 : 1)
                return .handled
            default:
                return .ignored
            }
        }

        // Cmd-modified shortcuts — match on `press.key` (more reliable than
        // `characters` with modifiers).
        if press.key == .upArrow {
            select(0)
            return .handled
        }

        if press.key == .downArrow {
            select(displayed.count - 1)
            return .handled
        }

        if press.key == .delete {
            if let selectedItem {
                onDelete(selectedItem.entry)
                if selectionIndex >= displayed.count - 1 {
                    selectionIndex = max(0, displayed.count - 2)
                }
                isPreviewing = false
            }
            return .handled
        }

        if press.key == "d" {
            if let selectedItem {
                onToggleFavorite(selectedItem.entry)
            }
            return .handled
        }

        if press.key == "r" {
            if let selectedItem {
                let entry = selectedItem.entry
                if entry.kind == .file || entry.kind == .multiFile {
                    onReveal(entry)
                } else {
                    print("[Reveal] entry kind \(entry.kind) is not a file — ignored")
                }
            }
            return .handled
        }

        if press.key == "c" {
            if let selectedItem {
                onCopy(selectedItem.entry)
            }
            return .handled
        }

        if press.key == "y" {
            if selectedItem != nil {
                isPreviewing.toggle()
            }
            return .handled
        }

        if press.key == "f" && shift {
            selectedFilter = .favorites
            return .handled
        }

        if press.key == "f" || press.key == "k" {
            searchFocused = true
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

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: emptyIcon)
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
            Text(emptyText)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            if !isSearching && items.isEmpty {
                Text(emptyHint)
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
            if isSearching {
                Button("Clear search") {
                    query = ""
                    searchFocused = true
                }
                .buttonStyle(.link)
                .font(.system(size: 12))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            !isSearching && items.isEmpty ? "\(emptyText). \(emptyHint)" : emptyText
        )
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
        if isSearching {
            return "No matches"
        }
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
        if let pauseUntil = state.pauseUntil {
            return "Recording resumes at \(pauseUntil.formatted(date: .omitted, time: .shortened))."
        }
        return state.isPaused
            ? "Resume from the menu bar to start capturing again."
            : "Copy something to get started."
    }

    private var pausedPill: some View {
        HStack(spacing: 4) {
            Image(systemName: "pause.fill")
                .font(.system(size: 9, weight: .bold))
            Text(pausedLabel)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(Color.orange)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Color.orange.opacity(0.15))
        .clipShape(Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(pausedLabel). Resume from the menu bar.")
    }

    private var pausedLabel: String {
        guard let pauseUntil = state.pauseUntil else { return "Paused" }
        return "Paused until \(pauseUntil.formatted(date: .omitted, time: .shortened))"
    }

    // MARK: - Rows

    @ViewBuilder
    private func rowView(for item: ClipItem, at idx: Int) -> some View {
        let isSelected = idx == selectionIndex
        let traits: AccessibilityTraits = isSelected ? [.isButton, .isSelected] : .isButton
        let favoriteActionName: String = item.entry.isPinned ? "Remove from favorites" : "Add to favorites"
        let canReveal = item.entry.kind == .file || item.entry.kind == .multiFile

        EntryRow(
            item: item,
            isSelected: isSelected,
            shortcutIndex: idx < 9 ? idx + 1 : nil,
            onToggleFavorite: { onToggleFavorite(item.entry) },
            onDelete: { onDelete(item.entry) }
        )
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 1, leading: 8, bottom: 1, trailing: 8))
        .id(item.id)
        .contentShape(Rectangle())
        .onTapGesture { onPaste(item.entry) }
        .contextMenu { rowContextMenu(for: item, at: idx) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rowAccessibilityLabel(for: item))
        .accessibilityHint("Press Return to paste")
        .accessibilityAddTraits(traits)
        .accessibilityAction(named: favoriteActionName) { onToggleFavorite(item.entry) }
        .accessibilityAction(named: "Delete") { onDelete(item.entry) }
        .accessibilityAction(named: "Copy without pasting") { onCopy(item.entry) }
        .accessibilityAction(named: "Preview") {
            selectionIndex = idx
            isPreviewing = true
        }
        .accessibilityAction(named: "Reveal in Finder") {
            if canReveal { onReveal(item.entry) }
        }
    }

    @ViewBuilder
    private func rowContextMenu(for item: ClipItem, at idx: Int) -> some View {
        Button("Paste") { onPaste(item.entry) }
        Button("Copy") { onCopy(item.entry) }
        Button("Quick Look") {
            selectionIndex = idx
            isPreviewing = true
        }
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

    private var themeToggleButton: some View {
        let theme = settings.appearance
        return Button {
            settings.appearance = theme.next
        } label: {
            Image(systemName: theme.iconName)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Appearance: \(theme.label) — click to switch")
        .accessibilityLabel("Appearance")
        .accessibilityValue(theme.label)
        .accessibilityHint("Cycles between System, Light, and Dark")
    }

    private func hint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            ShortcutKeyCap(keys: key)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }
}

/// Bundle-identifier to app-icon lookup, memoized because a scrolling list
/// asks for the same handful of apps on every body evaluation and each miss
/// is a Launch Services round trip.
enum SourceAppIcon {
    private static var cache: [String: NSImage?] = [:]

    static func image(forBundleID bundleID: String?) -> NSImage? {
        guard let bundleID, !bundleID.isEmpty else { return nil }
        if let cached = cache[bundleID] { return cached }
        let icon = NSWorkspace.shared
            .urlForApplication(withBundleIdentifier: bundleID)
            .map { NSWorkspace.shared.icon(forFile: $0.path) }
        cache[bundleID] = icon
        return icon
    }
}

private struct EntryRow: View {
    let item: ClipItem
    let isSelected: Bool
    /// 1–9 for the rows Cmd-1…Cmd-9 paste directly, nil below the fold.
    let shortcutIndex: Int?
    let onToggleFavorite: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false
    @State private var showPreview = false

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            iconView
                .opacity(item.isStale ? 0.4 : 1.0)
            VStack(alignment: .leading, spacing: 2) {
                Text(bodyText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .font(.system(size: 13))
                    .strikethrough(item.isStale, color: .secondary)
                    .foregroundStyle(item.isStale ? Color.secondary : Color.primary)
                HStack(spacing: 6) {
                    sourceLabel
                    Text(relative(item.entry.createdAt))
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                    ForEach(item.groupNames, id: \.self) { name in
                        Text(name)
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(
                                Capsule().fill(Color.accentColor.opacity(0.16))
                            )
                            .foregroundStyle(Color.accentColor)
                            .lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 8)
            if item.isStale {
                // Always visible: a clip whose file has gone is the one thing
                // in this list that will not do what the user expects.
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                    .help("File has been moved or deleted")
            }

            trailingControls
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(rowBackground)
        )
        .onHover { hovering in
            isHovering = hovering
        }
        .animation(.easeOut(duration: 0.1), value: isHovering)
        .animation(.easeOut(duration: 0.1), value: isSelected)
    }

    /// Fixed-width so rows do not shift as controls fade in under the cursor.
    private var trailingControls: some View {
        HStack(spacing: 2) {
            Text(shortcutIndex.map { "⌘\($0)" } ?? "")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 22)
                .opacity(isHovering ? 0 : 1)
                .accessibilityHidden(true)

            Button(action: onToggleFavorite) {
                Image(systemName: item.entry.isPinned ? "star.fill" : "star")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(item.entry.isPinned ? Color.yellow : Color.secondary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(item.entry.isPinned ? "Remove from Favorites (⌘D)" : "Add to Favorites (⌘D)")
            .opacity(item.entry.isPinned || isHovering ? 1.0 : 0.0)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.secondary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Delete (⌘⌫)")
            .opacity(isHovering ? 1.0 : 0.0)
        }
    }

    @ViewBuilder
    private var sourceLabel: some View {
        if let source = subtitleText {
            HStack(spacing: 3) {
                if let icon = SourceAppIcon.image(forBundleID: item.entry.sourceApp) {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.medium)
                        .frame(width: 11, height: 11)
                        .accessibilityHidden(true)
                }
                Text(source)
                    .lineLimit(1)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var rowBackground: Color {
        if isSelected { return Color.accentColor.opacity(0.18) }
        if isHovering { return Color.primary.opacity(0.05) }
        return .clear
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
                    .frame(width: 36, height: 36)
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
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(.secondary)
                .frame(width: 36, height: 36)
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

    private var subtitleText: String? {
        guard let raw = item.entry.displaySubtitle else { return nil }
        if raw.hasPrefix("from ") {
            return String(raw.dropFirst(5))
        }
        return raw
    }

    private var bodyText: String {
        switch item.entry.kind {
        case .text, .url, .richText:
            let lines = item.entry.searchableText
                .split(separator: "\n", maxSplits: 2, omittingEmptySubsequences: true)
                .prefix(2)
                .map { String($0.prefix(200)) }
            return lines.isEmpty ? item.entry.displayTitle : lines.joined(separator: "\n")
        case .file, .multiFile, .image:
            return item.entry.displayTitle
        }
    }

    private func relative(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "now" }
        if interval < 3_600 { return "\(Int(interval / 60))m" }
        if interval < 86_400 { return "\(Int(interval / 3_600))h" }
        if interval < 604_800 { return "\(Int(interval / 86_400))d" }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
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
