import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct HistorySidebarView: View {
    @ObservedObject var model: AppModel
    @State private var folderDropTarget: FolderDropTarget?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            HistoryScopePicker(
                model: model,
                folderDropTarget: $folderDropTarget
            )
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(AppTheme.border)
                        .frame(height: 1)
                }

            if model.visibleHistory.isEmpty {
                Spacer()
                HistoryEmptyState(scope: model.selectedHistoryScope, hasAnyHistory: !model.history.isEmpty)
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    List {
                        ForEach(model.visibleHistory) { entry in
                            HistoryRow(
                                entry: entry,
                                isSelected: entry.id == model.selectedHistoryID,
                                titleFontSize: model.settings.historyTitleFontSize,
                                folderBadgeColor: model.historyFolderColor(for: entry.folderID),
                                folders: model.historyFolders,
                                copy: { model.copyHistoryEntry(entry) },
                                canRevealImage: model.canRevealHistoryImage(entry),
                                revealImage: { model.revealHistoryImageInFinder(entry) },
                                rename: { model.renameHistoryEntry(entry, title: $0) },
                                moveToFolder: { model.moveHistoryEntry(entry, to: $0) },
                                moveToNewFolder: {
                                    let folder = model.createHistoryFolder()
                                    model.moveHistoryEntry(entry, to: folder.id)
                                    model.reopenHistoryEntry(entry)
                                },
                                delete: { model.deleteHistoryEntry(entry) },
                                reopen: { model.reopenHistoryEntry(entry) }
                            )
                            .id(entry.id)
                            .onDrag {
                                folderDropTarget = nil
                                return NSItemProvider(object: HistoryDragPayload.entry(entry.id) as NSString)
                            }
                            .listRowInsets(EdgeInsets(top: 5, leading: 8, bottom: 5, trailing: 8))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.sidebar)
                    .scrollContentBackground(.hidden)
                    .background(AppTheme.windowBackground)
                    .onAppear {
                        scrollToSelectedHistoryItem(proxy)
                    }
                    .onChange(of: model.selectedHistoryID) { _ in
                        scrollToSelectedHistoryItem(proxy)
                    }
                    .onChange(of: model.visibleHistory.first?.id) { _ in
                        scrollToSelectedHistoryItem(proxy)
                    }
                }
            }
        }
        .background(AppTheme.windowBackground)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("History")
                .font(.headline)

            Spacer()

            HistorySortMenu(selection: $model.historySortMode)

            HistoryActionButton(
                systemName: "folder.badge.plus",
                help: "New folder",
                action: { model.createHistoryFolder() }
            )
        }
        .padding(.leading, 14)
        .padding(.trailing, 8)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.windowBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 1)
        }
    }

    private func scrollToSelectedHistoryItem(_ proxy: ScrollViewProxy) {
        guard let id = model.selectedHistoryID ?? model.visibleHistory.first?.id else {
            return
        }

        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.18)) {
                proxy.scrollTo(id, anchor: .top)
            }
        }
    }
}

private struct HistorySortMenu: View {
    @Binding var selection: HistorySortMode

    @State private var isSortHovered = false

    var body: some View {
        ZStack {
            sortIcon

            HistorySortMenuBridge(selection: $selection)
                .frame(width: historyRowControlSize, height: historyRowControlSize)
        }
        .frame(width: historyRowControlSize, height: historyRowControlSize)
        .onHover { isSortHovered = $0 }
        .help("Sort history")
    }

    private var sortIcon: some View {
        Image(systemName: "arrow.up.arrow.down")
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(isSortHovered ? .accentColor : .secondary)
            .frame(width: historyRowControlSize, height: historyRowControlSize)
            .contentShape(RoundedRectangle(cornerRadius: 5))
            .background {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.accentColor.opacity(sortIconBackgroundOpacity))
            }
            .animation(.easeOut(duration: 0.12), value: isSortHovered)
    }

    private var sortIconBackgroundOpacity: Double {
        isSortHovered ? 0.10 : 0
    }
}

private struct HistorySortMenuBridge: NSViewRepresentable {
    @Binding var selection: HistorySortMode

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }

    func makeNSView(context: Context) -> SortMenuTriggerView {
        let view = SortMenuTriggerView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ view: SortMenuTriggerView, context: Context) {
        context.coordinator.selection = $selection
        view.coordinator = context.coordinator
    }

    final class Coordinator: NSObject {
        var selection: Binding<HistorySortMode>

        init(selection: Binding<HistorySortMode>) {
            self.selection = selection
        }

        func makeMenu() -> NSMenu {
            let menu = NSMenu()
            for mode in HistorySortMode.allCases {
                let item = NSMenuItem(
                    title: mode.menuTitle,
                    action: #selector(selectSortMode(_:)),
                    keyEquivalent: ""
                )
                item.image = NSImage(
                    systemSymbolName: selection.wrappedValue == mode ? "checkmark" : mode.systemName,
                    accessibilityDescription: nil
                )
                item.representedObject = mode.rawValue
                item.target = self
                menu.addItem(item)
            }
            return menu
        }

        @objc private func selectSortMode(_ sender: NSMenuItem) {
            guard let rawValue = sender.representedObject as? String,
                  let mode = HistorySortMode(rawValue: rawValue) else {
                return
            }
            selection.wrappedValue = mode
        }
    }

    final class SortMenuTriggerView: NSView {
        weak var coordinator: Coordinator?

        override func hitTest(_ point: NSPoint) -> NSView? {
            guard let event = window?.currentEvent else {
                return nil
            }

            if event.type == .leftMouseDown || event.type == .rightMouseDown {
                return self
            }
            return nil
        }

        override func mouseDown(with event: NSEvent) {
            showMenu(with: event)
        }

        override func rightMouseDown(with event: NSEvent) {
            showMenu(with: event)
        }

        private func showMenu(with event: NSEvent) {
            guard let menu = coordinator?.makeMenu() else {
                return
            }
            NSMenu.popUpContextMenu(menu, with: event, for: self)
        }
    }
}

private struct HistoryScopePicker: View {
    @ObservedObject var model: AppModel
    @Binding var folderDropTarget: FolderDropTarget?
    @State private var draggedFolderID: HistoryFolder.ID?
    @State private var folderRowFrames: [HistoryFolder.ID: CGRect] = [:]
    @AppStorage("historyFoldersExpanded") private var isFoldersExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HistoryScopeRow(
                title: "All Snaps",
                systemName: "clock.arrow.circlepath",
                count: model.historyCount(for: .all),
                isSelected: model.selectedHistoryScope == .all,
                action: { model.selectHistoryScope(.all) }
            )

            if !model.historyFolders.isEmpty {
                HistoryFoldersHeader(
                    isExpanded: $isFoldersExpanded,
                    collapseFolders: { model.selectHistoryScope(.all) }
                )

                if isFoldersExpanded {
                    ForEach(model.historyFolders) { folder in
                        HistoryFolderScopeRow(
                            folder: folder,
                            count: model.historyCount(for: .folder(folder.id)),
                            isSelected: model.selectedHistoryScope == .folder(folder.id),
                            select: { model.selectHistoryScope(.folder(folder.id)) },
                            rename: { model.renameHistoryFolder(folder, name: $0) },
                            updateColor: { model.updateHistoryFolderColor(folder, color: $0) },
                            isDragging: draggedFolderID == folder.id,
                            isAnyFolderDragging: draggedFolderID != nil,
                            folderDropTarget: $folderDropTarget,
                            folderDragChanged: { updateFolderDrag(sourceID: folder.id, y: $0) },
                            folderDragEnded: { finishFolderDrag(sourceID: folder.id, y: $0) },
                            moveDroppedEntries: { model.moveHistoryEntries(withIDs: $0, to: folder.id) },
                            deleteKeepingSnaps: { model.deleteHistoryFolderKeepingSnaps(folder) },
                            deleteWithSnaps: { model.deleteHistoryFolderAndSnaps(folder) }
                        )
                        .background {
                            GeometryReader { proxy in
                                Color.clear.preference(
                                    key: FolderRowFramePreferenceKey.self,
                                    value: [folder.id: proxy.frame(in: .named(historyFoldersCoordinateSpace))]
                                )
                            }
                        }
                    }
                }
            }
        }
        .coordinateSpace(name: historyFoldersCoordinateSpace)
        .onPreferenceChange(FolderRowFramePreferenceKey.self) { frames in
            folderRowFrames = frames
        }
    }

    private func updateFolderDrag(sourceID: HistoryFolder.ID, y: CGFloat) {
        if draggedFolderID != sourceID {
            draggedFolderID = sourceID
        }
        folderDropTarget = folderDropTarget(for: sourceID, dragLocationY: y)
    }

    private func finishFolderDrag(sourceID: HistoryFolder.ID, y: CGFloat) {
        defer {
            draggedFolderID = nil
            folderDropTarget = nil
        }

        let target = folderDropTarget ?? folderDropTarget(for: sourceID, dragLocationY: y)
        guard let target else {
            return
        }
        moveDroppedFolder(sourceID, to: target)
    }

    private func moveDroppedFolder(_ sourceID: HistoryFolder.ID, to target: FolderDropTarget) {
        model.moveHistoryFolder(withID: sourceID, relativeTo: target.folderID, placement: target.placement)
    }

    private func folderDropTarget(for sourceID: HistoryFolder.ID, dragLocationY y: CGFloat) -> FolderDropTarget? {
        let candidateFolders = model.historyFolders.filter { $0.id != sourceID }
        for folder in candidateFolders {
            guard let frame = folderRowFrames[folder.id] else {
                continue
            }
            if y < frame.midY {
                return FolderDropTarget(folderID: folder.id, placement: .before)
            }
        }

        guard let lastFolder = candidateFolders.last else {
            return nil
        }
        return FolderDropTarget(folderID: lastFolder.id, placement: .after)
    }
}

private struct HistoryFoldersHeader: View {
    @Binding var isExpanded: Bool
    let collapseFolders: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text("Folders")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(AppTheme.quietText)

            Spacer(minLength: 8)

            HistoryActionButton(
                systemName: isExpanded ? "chevron.down" : "chevron.right",
                help: isExpanded ? "Hide folders" : "Show folders",
                action: {
                    if isExpanded {
                        collapseFolders()
                    }
                    isExpanded.toggle()
                }
            )
        }
        .padding(.leading, 6)
        .padding(.trailing, 2)
        .padding(.top, 5)
    }
}

private struct HistoryScopeRow: View {
    let title: String
    let systemName: String
    let count: Int
    let isSelected: Bool
    var iconTint: Color = .secondary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(iconTint)
                    .frame(width: 16)

                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text("\(count)")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? AppTheme.selectedBackground : Color.clear)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isSelected ? AppTheme.selectedBorder : Color.clear, lineWidth: 1)
        }
    }
}

private struct HistoryFolderScopeRow: View {
    let folder: HistoryFolder
    let count: Int
    let isSelected: Bool
    let select: () -> Void
    let rename: (String) -> Void
    let updateColor: (HistoryFolderColor) -> Void
    let isDragging: Bool
    let isAnyFolderDragging: Bool
    @Binding var folderDropTarget: FolderDropTarget?
    let folderDragChanged: (CGFloat) -> Void
    let folderDragEnded: (CGFloat) -> Void
    let moveDroppedEntries: ([OCRHistoryEntry.ID]) -> Void
    let deleteKeepingSnaps: () -> Void
    let deleteWithSnaps: () -> Void

    @State private var isRenaming = false
    @State private var draftName = ""
    @State private var isSnapDropTarget = false
    @FocusState private var nameFieldFocused: Bool

    var body: some View {
        if isRenaming {
            renameRow
        } else {
            folderRow
            .simultaneousGesture(TapGesture(count: 2).onEnded { beginRename() })
            .simultaneousGesture(folderReorderGesture)
            .onDrop(of: [UTType.text], isTargeted: $isSnapDropTarget) { providers in
                providers.loadHistoryEntryIDs(moveDroppedEntries)
                return true
            }
            .overlay {
                FolderContextMenuBridge(
                    selectedColor: folder.color,
                    rename: beginRename,
                    updateColor: updateColor,
                    deleteKeepingSnaps: deleteKeepingSnaps,
                    deleteWithSnaps: deleteWithSnaps
                )
            }
            .overlay(alignment: .top) {
                if currentDropPlacement == .before {
                    FolderInsertionIndicator()
                }
            }
            .overlay(alignment: .bottom) {
                if currentDropPlacement == .after {
                    FolderInsertionIndicator()
                }
            }
            .opacity(isDragging ? 0.55 : 1)
        }
    }

    private var folderReorderGesture: some Gesture {
        DragGesture(minimumDistance: 5, coordinateSpace: .named(historyFoldersCoordinateSpace))
            .onChanged { value in
                folderDragChanged(value.location.y)
            }
            .onEnded { value in
                folderDragEnded(value.location.y)
            }
    }

    private var currentDropPlacement: HistoryFolderDropPlacement? {
        guard folderDropTarget?.folderID == folder.id else {
            return nil
        }
        return folderDropTarget?.placement
    }

    private var folderRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(folder.color.tint)
                .frame(width: 16)

            Text(folder.name)
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text("\(count)")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .monospacedDigit()

        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .contentShape(RoundedRectangle(cornerRadius: 6))
        .onTapGesture(perform: select)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill((showsSelectionBackground || isSnapDropTarget) ? AppTheme.selectedBackground : Color.clear)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder((showsSelectionBackground || isSnapDropTarget) ? AppTheme.selectedBorder : Color.clear, lineWidth: 1)
        }
    }

    private var showsSelectionBackground: Bool {
        isSelected && !isAnyFolderDragging
    }

    private var renameRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "folder")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(folder.color.tint)
                .frame(width: 16)

            TextField("Folder name", text: $draftName)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
                .focused($nameFieldFocused)
                .onAppear {
                    nameFieldFocused = true
                }
                .onSubmit(saveRename)

            HistoryActionButton(systemName: "checkmark", help: "Save folder name", tint: .green, action: saveRename)
            HistoryActionButton(systemName: "xmark", help: "Cancel", action: cancelRename)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private func beginRename() {
        draftName = folder.name
        withAnimation(.easeOut(duration: 0.12)) {
            isRenaming = true
        }
    }

    private func saveRename() {
        rename(draftName)
        withAnimation(.easeOut(duration: 0.12)) {
            isRenaming = false
        }
    }

    private func cancelRename() {
        withAnimation(.easeOut(duration: 0.12)) {
            isRenaming = false
        }
    }
}

private let historyFoldersCoordinateSpace = "history-folders"

private struct FolderRowFramePreferenceKey: PreferenceKey {
    static var defaultValue: [HistoryFolder.ID: CGRect] = [:]

    static func reduce(
        value: inout [HistoryFolder.ID: CGRect],
        nextValue: () -> [HistoryFolder.ID: CGRect]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, newValue in newValue })
    }
}

private struct FolderDropTarget: Equatable {
    let folderID: HistoryFolder.ID
    let placement: HistoryFolderDropPlacement
}

private struct FolderInsertionIndicator: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Color.accentColor)
            .frame(height: 2)
            .padding(.horizontal, 6)
            .offset(y: 0)
            .allowsHitTesting(false)
    }
}

private struct HistoryEmptyState: View {
    let scope: HistoryScope
    let hasAnyHistory: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: hasAnyHistory ? "folder" : "clock.arrow.circlepath")
                .font(.system(size: 30))
                .foregroundStyle(.tertiary)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var message: String {
        switch scope {
        case .all:
            return "No snaps yet"
        case .folder:
            return "No snaps in this folder"
        }
    }
}

private let historyRowControlSize: CGFloat = 24

private struct HistoryRow: View {
    let entry: OCRHistoryEntry
    let isSelected: Bool
    let titleFontSize: Int
    let folderBadgeColor: HistoryFolderColor?
    let folders: [HistoryFolder]
    let copy: () -> Void
    let canRevealImage: Bool
    let revealImage: () -> Void
    let rename: (String) -> Void
    let moveToFolder: (HistoryFolder.ID?) -> Void
    let moveToNewFolder: () -> Void
    let delete: () -> Void
    let reopen: () -> Void

    @State private var isRenaming = false
    @State private var draftTitle = ""
    @FocusState private var titleFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 6) {
                Text(entry.timeLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(height: historyRowControlSize, alignment: .center)

                HistoryFolderAssignmentMenu(
                    currentFolderID: entry.folderID,
                    folderBadgeColor: folderBadgeColor,
                    folders: folders,
                    moveToFolder: moveToFolder,
                    moveToNewFolder: moveToNewFolder
                )

                if isRenaming {
                    TextField("Name", text: $draftTitle)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                        .frame(height: historyRowControlSize)
                        .focused($titleFieldFocused)
                        .onAppear {
                            titleFieldFocused = true
                        }
                        .onSubmit(saveRename)

                    HistoryActionButton(systemName: "checkmark", help: "Save name", tint: .green, action: saveRename)
                    HistoryActionButton(systemName: "xmark", help: "Cancel", action: cancelRename)
                } else {
                    Button(action: reopen) {
                        HStack(spacing: 5) {
                            stateIndicator
                            Text(entry.title)
                                .font(.system(size: CGFloat(titleFontSize), weight: .semibold))
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .frame(maxWidth: .infinity, minHeight: historyRowControlSize, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Reopen and edit")
                    .simultaneousGesture(TapGesture(count: 2).onEnded { beginRename() })

                    HStack(spacing: 4) {
                        HistoryTextActionButton(title: "Copy", help: "Copy", action: copy)
                        HistoryActionButton(systemName: "trash", help: "Delete", tint: .red, action: delete)
                    }
                }
            }

            Button(action: reopen) {
                thumbnail
            }
            .buttonStyle(.plain)
            .help("Reopen and edit")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
        .graphitePanel(
            background: isSelected ? AppTheme.selectedBackground : Color.clear,
            border: isSelected ? AppTheme.selectedBorder : Color.clear,
            radius: 7
        )
        .contextMenu {
            Button("Rename", action: beginRename)
            Button("Copy", action: copy)

            if canRevealImage {
                Button {
                    revealImage()
                } label: {
                    Label("Reveal in Finder", systemImage: "folder")
                }
            }

            Divider()

            Button {
                delete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private var stateIndicator: some View {
        switch entry.state {
        case .recognizing:
            ProgressView()
                .controlSize(.mini)
                .frame(width: 12, height: 12)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.orange)
        case .recognized:
            EmptyView()
        }
    }

    private func beginRename() {
        draftTitle = entry.title
        withAnimation(.easeOut(duration: 0.12)) {
            isRenaming = true
        }
    }

    private func saveRename() {
        rename(draftTitle)
        withAnimation(.easeOut(duration: 0.12)) {
            isRenaming = false
        }
    }

    private func cancelRename() {
        withAnimation(.easeOut(duration: 0.12)) {
            isRenaming = false
        }
    }

    private var thumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(AppTheme.insetBackground)

            if let image = entry.image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(4)
            } else {
                Image(systemName: "function")
                    .font(.system(size: 18))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay {
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(AppTheme.border, lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 5))
    }
}

private struct HistoryFolderAssignmentMenu: View {
    let currentFolderID: HistoryFolder.ID?
    let folderBadgeColor: HistoryFolderColor?
    let folders: [HistoryFolder]
    let moveToFolder: (HistoryFolder.ID?) -> Void
    let moveToNewFolder: () -> Void

    @State private var isFolderMenuHovered = false
    @State private var isFolderMenuPressed = false

    var body: some View {
        ZStack {
            HistoryFolderAssignmentIcon(
                systemName: currentFolderID == nil ? "folder" : "folder.fill",
                color: folderBadgeColor?.tint ?? Color.secondary.opacity(0.45),
                isHovered: isFolderMenuHovered,
                isPressed: isFolderMenuPressed
            )

            FolderAssignmentMenuBridge(
                currentFolderID: currentFolderID,
                folders: folders,
                isHovered: $isFolderMenuHovered,
                isPressed: $isFolderMenuPressed,
                moveToFolder: moveToFolder,
                moveToNewFolder: moveToNewFolder
            )
        }
        .frame(width: historyRowControlSize, height: historyRowControlSize)
        .help("Move to folder")
    }
}

private struct HistoryFolderAssignmentIcon: View {
    let systemName: String
    let color: Color
    let isHovered: Bool
    let isPressed: Bool

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(color)
            .frame(width: historyRowControlSize, height: historyRowControlSize)
            .contentShape(RoundedRectangle(cornerRadius: 5))
            .background {
                RoundedRectangle(cornerRadius: 5)
                    .fill(color.opacity(folderIconBackgroundOpacity))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(color.opacity(isHovered || isPressed ? 0.35 : 0), lineWidth: 1)
            }
            .scaleEffect(isPressed ? 0.94 : isHovered ? 1.05 : 1)
            .animation(.easeOut(duration: 0.08), value: isPressed)
            .animation(.easeOut(duration: 0.12), value: isHovered)
    }

    private var folderIconBackgroundOpacity: Double {
        if isPressed {
            return 0.22
        }
        return isHovered ? 0.12 : 0
    }
}

private struct FolderAssignmentMenuBridge: NSViewRepresentable {
    let currentFolderID: HistoryFolder.ID?
    let folders: [HistoryFolder]
    @Binding var isHovered: Bool
    @Binding var isPressed: Bool
    let moveToFolder: (HistoryFolder.ID?) -> Void
    let moveToNewFolder: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            currentFolderID: currentFolderID,
            folders: folders,
            isHovered: $isHovered,
            isPressed: $isPressed,
            moveToFolder: moveToFolder,
            moveToNewFolder: moveToNewFolder
        )
    }

    func makeNSView(context: Context) -> MenuTriggerView {
        let view = MenuTriggerView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ view: MenuTriggerView, context: Context) {
        context.coordinator.currentFolderID = currentFolderID
        context.coordinator.folders = folders
        context.coordinator.isHovered = $isHovered
        context.coordinator.isPressed = $isPressed
        context.coordinator.moveToFolder = moveToFolder
        context.coordinator.moveToNewFolder = moveToNewFolder
        view.coordinator = context.coordinator
    }

    final class Coordinator: NSObject {
        var currentFolderID: HistoryFolder.ID?
        var folders: [HistoryFolder]
        var isHovered: Binding<Bool>
        var isPressed: Binding<Bool>
        var moveToFolder: (HistoryFolder.ID?) -> Void
        var moveToNewFolder: () -> Void

        init(
            currentFolderID: HistoryFolder.ID?,
            folders: [HistoryFolder],
            isHovered: Binding<Bool>,
            isPressed: Binding<Bool>,
            moveToFolder: @escaping (HistoryFolder.ID?) -> Void,
            moveToNewFolder: @escaping () -> Void
        ) {
            self.currentFolderID = currentFolderID
            self.folders = folders
            self.isHovered = isHovered
            self.isPressed = isPressed
            self.moveToFolder = moveToFolder
            self.moveToNewFolder = moveToNewFolder
        }

        func makeMenu() -> NSMenu {
            let menu = NSMenu()

            let noFolderItem = NSMenuItem(
                title: "No Folder",
                action: #selector(assignNoFolder),
                keyEquivalent: ""
            )
            noFolderItem.image = NSImage(
                systemSymbolName: currentFolderID == nil ? "checkmark" : "tray",
                accessibilityDescription: nil
            )
            noFolderItem.target = self
            menu.addItem(noFolderItem)

            if !folders.isEmpty {
                menu.addItem(.separator())
                for folder in folders {
                    let folderItem = NSMenuItem(
                        title: folder.name,
                        action: #selector(assignFolder(_:)),
                        keyEquivalent: ""
                    )
                    folderItem.image = NSImage(
                        systemSymbolName: currentFolderID == folder.id ? "checkmark" : "folder",
                        accessibilityDescription: nil
                    )
                    folderItem.representedObject = folder.id.uuidString
                    folderItem.target = self
                    menu.addItem(folderItem)
                }
            }

            menu.addItem(.separator())

            let newFolderItem = NSMenuItem(
                title: "New Folder",
                action: #selector(makeNewFolder),
                keyEquivalent: ""
            )
            newFolderItem.image = NSImage(systemSymbolName: "folder.badge.plus", accessibilityDescription: nil)
            newFolderItem.target = self
            menu.addItem(newFolderItem)

            return menu
        }

        @objc private func assignNoFolder() {
            moveToFolder(nil)
        }

        @objc private func assignFolder(_ sender: NSMenuItem) {
            guard let rawID = sender.representedObject as? String,
                  let folderID = HistoryFolder.ID(uuidString: rawID) else {
                return
            }
            moveToFolder(folderID)
        }

        @objc private func makeNewFolder() {
            moveToNewFolder()
        }
    }

    final class MenuTriggerView: NSView {
        weak var coordinator: Coordinator?

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            for trackingArea in trackingAreas {
                removeTrackingArea(trackingArea)
            }
            addTrackingArea(
                NSTrackingArea(
                    rect: .zero,
                    options: [.activeInKeyWindow, .inVisibleRect, .mouseEnteredAndExited],
                    owner: self
                )
            )
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            guard let event = window?.currentEvent else {
                return nil
            }

            if event.type == .leftMouseDown || event.type == .rightMouseDown {
                return self
            }
            return nil
        }

        override func mouseEntered(with event: NSEvent) {
            coordinator?.isHovered.wrappedValue = true
        }

        override func mouseExited(with event: NSEvent) {
            coordinator?.isHovered.wrappedValue = false
            coordinator?.isPressed.wrappedValue = false
        }

        override func mouseDown(with event: NSEvent) {
            showMenu(with: event)
        }

        override func rightMouseDown(with event: NSEvent) {
            showMenu(with: event)
        }

        private func showMenu(with event: NSEvent) {
            guard let menu = coordinator?.makeMenu() else {
                return
            }
            coordinator?.isPressed.wrappedValue = true
            NSMenu.popUpContextMenu(menu, with: event, for: self)
            coordinator?.isPressed.wrappedValue = false
        }
    }
}

private struct HistoryActionButton: View {
    let systemName: String
    let help: String
    var tint: Color = .accentColor
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .medium))
                .frame(width: historyRowControlSize, height: historyRowControlSize)
                .contentShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(HistoryActionButtonStyle(isHovered: isHovered, tint: tint))
        .onHover { isHovered = $0 }
        .help(help)
    }
}

private struct HistoryTextActionButton: View {
    let title: String
    let help: String
    var tint: Color = .accentColor
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .frame(height: historyRowControlSize)
                .contentShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(HistoryActionButtonStyle(isHovered: isHovered, tint: tint))
        .onHover { isHovered = $0 }
        .help(help)
    }
}

private struct HistoryActionButtonStyle: ButtonStyle {
    let isHovered: Bool
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(isHovered || configuration.isPressed ? tint : .secondary)
            .background {
                RoundedRectangle(cornerRadius: 5)
                    .fill(tint.opacity(configuration.isPressed ? 0.18 : isHovered ? 0.10 : 0))
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}

private struct FolderContextMenuBridge: NSViewRepresentable {
    let selectedColor: HistoryFolderColor
    let rename: () -> Void
    let updateColor: (HistoryFolderColor) -> Void
    let deleteKeepingSnaps: () -> Void
    let deleteWithSnaps: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            selectedColor: selectedColor,
            rename: rename,
            updateColor: updateColor,
            deleteKeepingSnaps: deleteKeepingSnaps,
            deleteWithSnaps: deleteWithSnaps
        )
    }

    func makeNSView(context: Context) -> ContextMenuView {
        let view = ContextMenuView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ view: ContextMenuView, context: Context) {
        context.coordinator.selectedColor = selectedColor
        context.coordinator.rename = rename
        context.coordinator.updateColor = updateColor
        context.coordinator.deleteKeepingSnaps = deleteKeepingSnaps
        context.coordinator.deleteWithSnaps = deleteWithSnaps
        view.coordinator = context.coordinator
    }

    final class Coordinator: NSObject {
        var selectedColor: HistoryFolderColor
        var rename: () -> Void
        var updateColor: (HistoryFolderColor) -> Void
        var deleteKeepingSnaps: () -> Void
        var deleteWithSnaps: () -> Void

        init(
            selectedColor: HistoryFolderColor,
            rename: @escaping () -> Void,
            updateColor: @escaping (HistoryFolderColor) -> Void,
            deleteKeepingSnaps: @escaping () -> Void,
            deleteWithSnaps: @escaping () -> Void
        ) {
            self.selectedColor = selectedColor
            self.rename = rename
            self.updateColor = updateColor
            self.deleteKeepingSnaps = deleteKeepingSnaps
            self.deleteWithSnaps = deleteWithSnaps
        }

        func makeMenu() -> NSMenu {
            let menu = NSMenu()

            let renameItem = NSMenuItem(
                title: "Rename Folder",
                action: #selector(renameFolder),
                keyEquivalent: ""
            )
            renameItem.image = NSImage(systemSymbolName: "square.and.pencil", accessibilityDescription: nil)
            renameItem.target = self
            menu.addItem(renameItem)

            let colorItem = NSMenuItem(title: "Change Folder Color", action: nil, keyEquivalent: "")
            colorItem.image = NSImage(systemSymbolName: "paintpalette", accessibilityDescription: nil)
            colorItem.submenu = makeColorMenu()
            menu.addItem(colorItem)

            menu.addItem(.separator())

            let keepSnapsItem = NSMenuItem(
                title: "Remove Folder, Keep Snaps",
                action: #selector(removeFolderKeepingSnaps),
                keyEquivalent: ""
            )
            keepSnapsItem.image = NSImage(systemSymbolName: "folder.badge.minus", accessibilityDescription: nil)
            keepSnapsItem.target = self
            menu.addItem(keepSnapsItem)

            let removeWithSnapsItem = NSMenuItem(
                title: "Remove Folder with Snaps",
                action: #selector(removeFolderWithSnaps),
                keyEquivalent: ""
            )
            removeWithSnapsItem.image = NSImage(systemSymbolName: "trash", accessibilityDescription: nil)
            removeWithSnapsItem.target = self
            menu.addItem(removeWithSnapsItem)

            return menu
        }

        private func makeColorMenu() -> NSMenu {
            let menu = NSMenu()
            for color in HistoryFolderColor.allCases {
                let colorItem = NSMenuItem(title: "", action: #selector(changeFolderColor(_:)), keyEquivalent: "")
                colorItem.image = color.menuSwatchImage(isSelected: color == selectedColor)
                colorItem.representedObject = color.rawValue
                colorItem.toolTip = color.title
                colorItem.target = self
                menu.addItem(colorItem)
            }
            return menu
        }

        @objc private func renameFolder() {
            rename()
        }

        @objc private func changeFolderColor(_ sender: NSMenuItem) {
            guard let rawValue = sender.representedObject as? String,
                  let color = HistoryFolderColor(rawValue: rawValue) else {
                return
            }
            updateColor(color)
        }

        @objc private func removeFolderKeepingSnaps() {
            deleteKeepingSnaps()
        }

        @objc private func removeFolderWithSnaps() {
            deleteWithSnaps()
        }
    }

    final class ContextMenuView: NSView {
        weak var coordinator: Coordinator?

        override func hitTest(_ point: NSPoint) -> NSView? {
            guard let event = window?.currentEvent else {
                return nil
            }

            if event.type == .rightMouseDown {
                return self
            }
            if event.type == .leftMouseDown,
               event.modifierFlags.contains(.control) {
                return self
            }
            return nil
        }

        override func rightMouseDown(with event: NSEvent) {
            showContextMenu(with: event)
        }

        override func mouseDown(with event: NSEvent) {
            if event.modifierFlags.contains(.control) {
                showContextMenu(with: event)
            } else {
                super.mouseDown(with: event)
            }
        }

        private func showContextMenu(with event: NSEvent) {
            guard let menu = coordinator?.makeMenu() else {
                return
            }
            NSMenu.popUpContextMenu(menu, with: event, for: self)
        }
    }
}

private extension HistoryFolderColor {
    func menuSwatchImage(isSelected: Bool) -> NSImage {
        let size = NSSize(width: 34, height: 18)
        let colorInset: CGFloat = 4
        let checkmarkRightX = size.width - colorInset
        let image = NSImage(size: size)
        image.lockFocus()

        let circleRect = NSRect(x: colorInset, y: 3, width: 12, height: 12)
        menuNSColor.setFill()
        NSBezierPath(ovalIn: circleRect).fill()
        NSColor.white.withAlphaComponent(0.35).setStroke()
        NSBezierPath(ovalIn: circleRect).stroke()

        if isSelected {
            let checkmark = NSBezierPath()
            checkmark.move(to: NSPoint(x: checkmarkRightX - 6, y: 8))
            checkmark.line(to: NSPoint(x: checkmarkRightX - 4, y: 6))
            checkmark.line(to: NSPoint(x: checkmarkRightX, y: 12))
            NSColor.labelColor.setStroke()
            checkmark.lineWidth = 1.6
            checkmark.lineCapStyle = .round
            checkmark.lineJoinStyle = .round
            checkmark.stroke()
        }

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private var menuNSColor: NSColor {
        switch self {
        case .gray:
            return .systemGray
        case .blue:
            return .systemBlue
        case .green:
            return .systemGreen
        case .yellow:
            return .systemYellow
        case .orange:
            return .systemOrange
        case .red:
            return .systemRed
        case .purple:
            return .systemPurple
        }
    }
}

private enum HistoryDragPayload {
    private static let entryPrefix = "snaptex-entry:"

    static func entry(_ id: OCRHistoryEntry.ID) -> String {
        "\(entryPrefix)\(id.uuidString)"
    }

    static func entryID(from string: String) -> OCRHistoryEntry.ID? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix(entryPrefix) {
            return OCRHistoryEntry.ID(uuidString: String(trimmed.dropFirst(entryPrefix.count)))
        }
        return OCRHistoryEntry.ID(uuidString: trimmed)
    }
}

private extension Array where Element == NSItemProvider {
    func loadHistoryEntryIDs(_ completion: @escaping ([OCRHistoryEntry.ID]) -> Void) {
        let group = DispatchGroup()
        var ids: [OCRHistoryEntry.ID] = []
        let lock = NSLock()

        for provider in self where provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { item, _ in
                defer { group.leave() }

                guard let string = historyDragString(from: item),
                      let id = HistoryDragPayload.entryID(from: string) else {
                    return
                }

                lock.lock()
                ids.append(id)
                lock.unlock()
            }
        }

        group.notify(queue: .main) {
            completion(ids)
        }
    }

    private func historyDragString(from item: NSSecureCoding?) -> String? {
        if let string = item as? String {
            return string
        }
        if let string = item as? NSString {
            return string as String
        }
        if let data = item as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
}
