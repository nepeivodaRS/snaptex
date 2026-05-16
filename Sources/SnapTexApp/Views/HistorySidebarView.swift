import AppKit
import SwiftUI

private let historySidebarHorizontalPadding: CGFloat = 12

struct HistorySidebarView: View {
    @ObservedObject var model: AppModel
    @State private var renamingFolderID: HistoryFolder.ID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            HistoryScopePicker(
                model: model,
                renamingFolderID: $renamingFolderID
            )
                .padding(.horizontal, historySidebarHorizontalPadding)
                .padding(.vertical, 8)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(AppTheme.border)
                        .frame(height: 1)
                }

            if model.visibleHistory.isEmpty {
                Spacer()
                HistoryEmptyState(
                    scope: model.selectedHistoryScope,
                    hasAnyHistory: !model.history.isEmpty,
                    metadataFontSize: model.settings.metadataFontSize
                )
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    List {
                        ForEach(model.visibleHistory) { entry in
                            HistoryRow(
                                entry: entry,
                                isSelected: entry.id == model.selectedHistoryID,
                                titleFontSize: model.settings.historyTitleFontSize,
                                metadataFontSize: model.settings.metadataFontSize,
                                folderBadgeColor: model.historyFolderColor(for: entry.folderID),
                                folders: model.historyFolders,
                                copy: { model.copyHistoryEntry(entry) },
                                canRevealImage: model.canRevealHistoryImage(entry),
                                revealImage: { model.revealHistoryImageInFinder(entry) },
                                rename: { model.renameHistoryEntry(entry, title: $0) },
                                moveToFolder: { model.moveHistoryEntry(entry, to: $0) },
                                moveToNewFolder: {
                                    let folder = model.createHistoryFolder()
                                    renamingFolderID = folder.id
                                    model.moveHistoryEntry(entry, to: folder.id)
                                    model.reopenHistoryEntry(entry)
                                },
                                delete: { model.deleteHistoryEntry(entry) },
                                reopen: { model.reopenHistoryEntry(entry) }
                            )
                            .id(entry.id)
                            .listRowInsets(EdgeInsets(
                                top: 5,
                                leading: historySidebarHorizontalPadding,
                                bottom: 5,
                                trailing: historySidebarHorizontalPadding
                            ))
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
                .font(.system(size: CGFloat(model.settings.paneTitleFontSize), weight: .semibold))

            Spacer()

            HistorySortMenu(selection: $model.historySortMode)

            HistoryActionButton(
                systemName: "folder.badge.plus",
                help: "New folder",
                action: {
                    let folder = model.createHistoryFolder()
                    renamingFolderID = folder.id
                }
            )
        }
        .padding(.leading, historySidebarHorizontalPadding)
        .padding(.trailing, historySidebarHorizontalPadding)
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
    @Binding var renamingFolderID: HistoryFolder.ID?
    @AppStorage("historyFoldersExpanded") private var isFoldersExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HistoryScopeRow(
                title: "All Captures",
                systemName: "clock.arrow.circlepath",
                count: model.historyCount(for: .all),
                isSelected: model.selectedHistoryScope == .all,
                labelFontSize: model.settings.labelFontSize,
                metadataFontSize: model.settings.metadataFontSize,
                action: { model.selectHistoryScope(.all) }
            )

            if !model.historyFolders.isEmpty {
                HistoryFoldersHeader(
                    labelFontSize: model.settings.labelFontSize,
                    isExpanded: $isFoldersExpanded,
                    collapseFolders: { model.selectHistoryScope(.all) }
                )

                if isFoldersExpanded {
                    let folderRows = model.historyFolders
                    ForEach(Array(folderRows.enumerated()), id: \.element.id) { index, folder in
                        HistoryFolderScopeRow(
                            folder: folder,
                            count: model.historyCount(for: .folder(folder.id)),
                            isSelected: model.selectedHistoryScope == .folder(folder.id),
                            labelFontSize: model.settings.labelFontSize,
                            metadataFontSize: model.settings.metadataFontSize,
                            select: { model.selectHistoryScope(.folder(folder.id)) },
                            rename: { model.renameHistoryFolder(folder, name: $0) },
                            updateColor: { model.updateHistoryFolderColor(folder, color: $0) },
                            canMoveUp: index > 0,
                            canMoveDown: index < folderRows.count - 1,
                            renamingFolderID: $renamingFolderID,
                            moveUp: { model.moveHistoryFolderUp(folder.id) },
                            moveDown: { model.moveHistoryFolderDown(folder.id) },
                            deleteKeepingSnaps: { model.deleteHistoryFolderKeepingSnaps(folder) },
                            deleteWithSnaps: { model.deleteHistoryFolderAndSnaps(folder) }
                        )
                    }
                }
            }
        }
        .onChange(of: renamingFolderID) { requestedID in
            if requestedID != nil {
                isFoldersExpanded = true
            }
        }
    }
}

private struct HistoryFoldersHeader: View {
    let labelFontSize: Int
    @Binding var isExpanded: Bool
    let collapseFolders: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text("Folders")
                .font(labelFont)
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

    private var labelFont: Font {
        .system(size: CGFloat(labelFontSize), weight: .semibold)
    }
}

private struct HistoryScopeRow: View {
    let title: String
    let systemName: String
    let count: Int
    let isSelected: Bool
    let labelFontSize: Int
    let metadataFontSize: Int
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
                    .font(labelFont)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text("\(count)")
                    .font(metadataFont)
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

    private var labelFont: Font {
        .system(size: CGFloat(labelFontSize), weight: .semibold)
    }

    private var metadataFont: Font {
        .system(size: CGFloat(metadataFontSize))
    }
}

private struct HistoryFolderScopeRow: View {
    let folder: HistoryFolder
    let count: Int
    let isSelected: Bool
    let labelFontSize: Int
    let metadataFontSize: Int
    let select: () -> Void
    let rename: (String) -> Void
    let updateColor: (HistoryFolderColor) -> Void
    let canMoveUp: Bool
    let canMoveDown: Bool
    @Binding var renamingFolderID: HistoryFolder.ID?
    let moveUp: () -> Void
    let moveDown: () -> Void
    let deleteKeepingSnaps: () -> Void
    let deleteWithSnaps: () -> Void

    @State private var isRenaming = false
    @State private var draftName = ""
    @FocusState private var nameFieldFocused: Bool

    var body: some View {
        Group {
            if isRenaming {
                renameRow
            } else {
                folderRow
                    .simultaneousGesture(TapGesture(count: 2).onEnded { beginRename() })
                    .overlay {
                        FolderContextMenuBridge(
                            selectedColor: folder.color,
                            rename: beginRename,
                            updateColor: updateColor,
                            deleteKeepingSnaps: deleteKeepingSnaps,
                            deleteWithSnaps: deleteWithSnaps
                        )
                    }
            }
        }
        .onAppear(perform: beginRenameIfRequested)
        .onChange(of: renamingFolderID) { requestedID in
            if requestedID != folder.id, isRenaming {
                saveRename(shouldClearRequestedRename: false)
                return
            }
            beginRenameIfRequested()
        }
    }

    private var folderRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(folder.color.tint)
                .frame(width: 16)

            Text(folder.name)
                .font(labelFont)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text("\(count)")
                .font(metadataFont)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            HStack(spacing: 2) {
                HistoryActionButton(
                    systemName: "chevron.up",
                    help: "Move folder up",
                    action: moveUp
                )
                .disabled(!canMoveUp)

                HistoryActionButton(
                    systemName: "chevron.down",
                    help: "Move folder down",
                    action: moveDown
                )
                .disabled(!canMoveDown)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .contentShape(RoundedRectangle(cornerRadius: 6))
        .onTapGesture(perform: select)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(showsSelectionBackground ? AppTheme.selectedBackground : Color.clear)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(showsSelectionBackground ? AppTheme.selectedBorder : Color.clear, lineWidth: 1)
        }
    }

    private var showsSelectionBackground: Bool {
        isSelected
    }

    private var renameRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "folder")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(folder.color.tint)
                .frame(width: 16)

            TextField("Folder name", text: $draftName)
                .textFieldStyle(.roundedBorder)
                .font(labelFont)
                .focused($nameFieldFocused)
                .onAppear {
                    nameFieldFocused = true
                }
                .onSubmit {
                    saveRename()
                }

            HistoryActionButton(systemName: "checkmark", help: "Save folder name", tint: .green) {
                saveRename()
            }
            HistoryActionButton(systemName: "xmark", help: "Cancel", action: cancelRename)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private var labelFont: Font {
        .system(size: CGFloat(labelFontSize), weight: .semibold)
    }

    private var metadataFont: Font {
        .system(size: CGFloat(metadataFontSize))
    }

    private func beginRenameIfRequested() {
        guard renamingFolderID == folder.id, !isRenaming else {
            return
        }
        beginRename()
    }

    private func beginRename() {
        if renamingFolderID != folder.id {
            renamingFolderID = folder.id
        }
        draftName = folder.name
        withAnimation(.easeOut(duration: 0.12)) {
            isRenaming = true
        }
    }

    private func saveRename(shouldClearRequestedRename: Bool = true) {
        rename(draftName)
        if shouldClearRequestedRename {
            clearRequestedRename()
        }
        withAnimation(.easeOut(duration: 0.12)) {
            isRenaming = false
        }
    }

    private func cancelRename() {
        clearRequestedRename()
        withAnimation(.easeOut(duration: 0.12)) {
            isRenaming = false
        }
    }

    private func clearRequestedRename() {
        if renamingFolderID == folder.id {
            renamingFolderID = nil
        }
    }
}

private struct HistoryEmptyState: View {
    let scope: HistoryScope
    let hasAnyHistory: Bool
    let metadataFontSize: Int

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: hasAnyHistory ? "folder" : "clock.arrow.circlepath")
                .font(.system(size: 30))
                .foregroundStyle(.tertiary)

            Text(message)
                .font(.system(size: CGFloat(metadataFontSize)))
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
    let metadataFontSize: Int
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
    @State private var isHovered = false
    @State private var hoverLocation = CGPoint(x: 0.5, y: 0.5)
    @State private var hoverEffectProgress = 0.0
    @State private var selectedIdleStrength = 0.0
    @State private var selectedFloatStrength = 0.0
    @State private var selectedFloatProgress = Double.zero
    @State private var selectedIdleStartDate = Date()
    @State private var isSelectedFloatAnimationRunning = false
    @FocusState private var titleFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 6) {
                Text(entry.timeLabel)
                    .font(metadataFont)
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
                        .font(metadataFont)
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
                        HistoryTextActionButton(
                            title: "Copy",
                            help: "Copy",
                            fontSize: metadataFontSize,
                            action: copy
                        )
                        HistoryActionButton(systemName: "trash", help: "Delete", tint: .red, action: delete)
                    }
                }
            }

            Button(action: reopen) {
                thumbnail
            }
            .buttonStyle(HistoryThumbnailButtonStyle())
            .help("Reopen and edit")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
        .modifier(HistoryRowPanel(
            background: rowBaseBackground,
            hoverProgress: hoverEffectProgress,
            isSelected: isSelected,
            radius: 7
        ))
        .modifier(HistoryDepthCardHoverEffect(
            progress: hoverEffectProgress,
            hoverLocation: hoverLocation,
            selectedIdleStrength: selectedIdleStrength,
            selectedFloatStrength: selectedFloatStrength,
            selectedFloatProgress: selectedFloatProgress,
            selectedIdleStartDate: selectedIdleStartDate,
            cornerRadius: 7
        ))
        .shadow(
            color: Color.black.opacity(shadowOpacity),
            radius: cardShadowRadius,
            y: cardShadowY
        )
        .overlay {
            HistoryCardHoverTrackingArea(
                hoverLocation: $hoverLocation,
                isHovered: $isHovered
            )
        }
        .onChange(of: isHovered) {
            updateHoverEffect(isActive: isSelected || $0)
            updateSelectedIdleAnimation()
        }
        .onChange(of: isSelected) {
            updateHoverEffect(isActive: isHovered || $0)
            updateSelectedIdleAnimation()
        }
        .onAppear {
            updateHoverEffect(isActive: isSelected || isHovered)
            updateSelectedIdleAnimation()
        }
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

    private var metadataFont: Font {
        .system(size: CGFloat(metadataFontSize))
    }

    private var rowBaseBackground: Color {
        if isSelected {
            return AppTheme.historySelectedBackground
        }
        return Color.white.opacity(historyCardBackgroundOpacity)
    }

    private var shadowOpacity: Double {
        if isSelected {
            return 0.10 - (hoverEffectProgress * 0.02) + selectedFloatStrength * 0.014
        }
        return 0.08 * hoverEffectProgress
    }

    private var cardShadowRadius: CGFloat {
        5 + hoverEffectProgress + selectedFloatStrength * 0.9
    }

    private var cardShadowY: CGFloat {
        1 + hoverEffectProgress + selectedFloatStrength * 0.55
    }

    private var thumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(AppTheme.controlBackground)

            if let image = entry.displayImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(4)
                    .opacity(thumbnailImageOpacity)
                    .brightness(thumbnailImageBrightness)
                    .contrast(thumbnailImageContrast)
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
        .transaction { transaction in
            transaction.animation = nil
            transaction.disablesAnimations = true
        }
        .contentShape(RoundedRectangle(cornerRadius: 5))
    }

    private func updateHoverEffect(isActive: Bool) {
        withAnimation(historyCardHoverAnimation(isActive: isActive)) {
            hoverEffectProgress = isActive ? 1 : 0
        }
    }

    private var isSelectedIdle: Bool {
        isSelected && !isHovered
    }

    private func updateSelectedIdleAnimation() {
        if isSelectedIdle {
            selectedIdleStartDate = Date()
        }

        let idleTransitionDuration = isSelectedIdle ? selectedIdleHoverEnterDuration : selectedIdleHoverExitDuration
        withAnimation(.easeInOut(duration: idleTransitionDuration)) {
            selectedIdleStrength = isSelectedIdle ? 1 : 0
            selectedFloatStrength = isSelected ? 1 : 0
        }

        guard isSelected else {
            isSelectedFloatAnimationRunning = false
            return
        }

        guard !isSelectedFloatAnimationRunning else {
            return
        }

        isSelectedFloatAnimationRunning = true
        DispatchQueue.main.async {
            guard isSelected else {
                return
            }

            withAnimation(.easeInOut(duration: selectedIdleHoverAnimationDuration).repeatForever(autoreverses: true)) {
                selectedFloatProgress = selectedFloatProgress <= 0.5 ? 1 : Double.zero
            }
        }
    }

    private var thumbnailImageOpacity: Double {
        return 1.0
    }

    private var thumbnailImageBrightness: Double {
        return 0.0
    }

    private var thumbnailImageContrast: Double {
        return 1.0
    }
}

private struct HistoryThumbnailButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

private let historyCardHoverEnterDuration = 0.28
private let historyCardHoverExitDuration = 0.46
private let historyCardHoverDampingFraction = 0.88
private let historyCardHoverBlendDuration = 0.06
private let historyCardHoverLocationFollowDuration = 0.18
private let historyCardHoverLocationSettleDuration = 0.14
private let historyCardHoverLocationDampingFraction = 0.82
private let historyCardHoverLocationBlendDuration = 0.04
private let historyCardBackgroundOpacity = 0.035
private let historyCardHoverBackgroundOpacityBoost = 0.020
private let selectedIdleHoverEnterDuration = 1.32
private let selectedIdleHoverExitDuration = 0.8
private let selectedIdleHoverAnimationDuration = 7.0
private let selectedIdleHoverHorizontalAmplitude: CGFloat = 0.36
private let selectedIdleHoverVerticalAmplitude: CGFloat = 0.12
private let protectedThumbnailOverlayHeight: CGFloat = 76

private func historyCardHoverAnimation(isActive: Bool) -> Animation {
    .spring(
        response: isActive ? historyCardHoverEnterDuration : historyCardHoverExitDuration,
        dampingFraction: historyCardHoverDampingFraction,
        blendDuration: historyCardHoverBlendDuration
    )
}

private func historyCardHoverLocationAnimation(response: Double) -> Animation {
    .interactiveSpring(
        response: response,
        dampingFraction: historyCardHoverLocationDampingFraction,
        blendDuration: historyCardHoverLocationBlendDuration
    )
}

private struct HistoryRowPanel: AnimatableModifier {
    let background: Color
    var hoverProgress: Double
    let isSelected: Bool
    let radius: CGFloat

    var animatableData: Double {
        get { hoverProgress }
        set { hoverProgress = newValue }
    }

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(background)

                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(Color.white.opacity(historyCardHoverBackgroundOpacityBoost))
                        .opacity(isSelected ? 0 : hoverProgress)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(border, lineWidth: 1)
            }
    }

    private var border: Color {
        let baseOpacity = max(1 - hoverProgress, 0)
        if isSelected {
            return AppTheme.selectedBorder.opacity(baseOpacity)
        }
        return AppTheme.border.opacity(0.72 * baseOpacity)
    }
}

private struct HistoryDepthCardAnimationValues: VectorArithmetic {
    var progress: Double
    var hoverX: Double
    var hoverY: Double
    var selectedIdleStrength: Double
    var selectedFloatStrength: Double
    var selectedFloatProgress: Double

    static var zero: HistoryDepthCardAnimationValues {
        HistoryDepthCardAnimationValues(
            progress: 0,
            hoverX: 0,
            hoverY: 0,
            selectedIdleStrength: 0,
            selectedFloatStrength: 0,
            selectedFloatProgress: 0
        )
    }

    static func + (lhs: HistoryDepthCardAnimationValues, rhs: HistoryDepthCardAnimationValues) -> HistoryDepthCardAnimationValues {
        HistoryDepthCardAnimationValues(
            progress: lhs.progress + rhs.progress,
            hoverX: lhs.hoverX + rhs.hoverX,
            hoverY: lhs.hoverY + rhs.hoverY,
            selectedIdleStrength: lhs.selectedIdleStrength + rhs.selectedIdleStrength,
            selectedFloatStrength: lhs.selectedFloatStrength + rhs.selectedFloatStrength,
            selectedFloatProgress: lhs.selectedFloatProgress + rhs.selectedFloatProgress
        )
    }

    static func - (lhs: HistoryDepthCardAnimationValues, rhs: HistoryDepthCardAnimationValues) -> HistoryDepthCardAnimationValues {
        HistoryDepthCardAnimationValues(
            progress: lhs.progress - rhs.progress,
            hoverX: lhs.hoverX - rhs.hoverX,
            hoverY: lhs.hoverY - rhs.hoverY,
            selectedIdleStrength: lhs.selectedIdleStrength - rhs.selectedIdleStrength,
            selectedFloatStrength: lhs.selectedFloatStrength - rhs.selectedFloatStrength,
            selectedFloatProgress: lhs.selectedFloatProgress - rhs.selectedFloatProgress
        )
    }

    static func += (lhs: inout HistoryDepthCardAnimationValues, rhs: HistoryDepthCardAnimationValues) {
        lhs = lhs + rhs
    }

    static func -= (lhs: inout HistoryDepthCardAnimationValues, rhs: HistoryDepthCardAnimationValues) {
        lhs = lhs - rhs
    }

    mutating func scale(by rhs: Double) {
        progress *= rhs
        hoverX *= rhs
        hoverY *= rhs
        selectedIdleStrength *= rhs
        selectedFloatStrength *= rhs
        selectedFloatProgress *= rhs
    }

    var magnitudeSquared: Double {
        progress * progress
            + hoverX * hoverX
            + hoverY * hoverY
            + selectedIdleStrength * selectedIdleStrength
            + selectedFloatStrength * selectedFloatStrength
            + selectedFloatProgress * selectedFloatProgress
    }
}

private struct HistoryDepthCardHoverEffect: AnimatableModifier {
    var progress: Double
    var hoverX: Double
    var hoverY: Double
    var selectedIdleStrength: Double
    var selectedFloatStrength: Double
    var selectedFloatProgress: Double
    let selectedIdleStartDate: Date
    let cornerRadius: CGFloat

    init(
        progress: Double,
        hoverLocation: CGPoint,
        selectedIdleStrength: Double,
        selectedFloatStrength: Double,
        selectedFloatProgress: Double,
        selectedIdleStartDate: Date,
        cornerRadius: CGFloat
    ) {
        self.progress = progress
        hoverX = Double(hoverLocation.x)
        hoverY = Double(hoverLocation.y)
        self.selectedIdleStrength = selectedIdleStrength
        self.selectedFloatStrength = selectedFloatStrength
        self.selectedFloatProgress = selectedFloatProgress
        self.selectedIdleStartDate = selectedIdleStartDate
        self.cornerRadius = cornerRadius
    }

    var animatableData: HistoryDepthCardAnimationValues {
        get {
            HistoryDepthCardAnimationValues(
                progress: progress,
                hoverX: hoverX,
                hoverY: hoverY,
                selectedIdleStrength: selectedIdleStrength,
                selectedFloatStrength: selectedFloatStrength,
                selectedFloatProgress: selectedFloatProgress
            )
        }
        set {
            progress = newValue.progress
            hoverX = newValue.hoverX
            hoverY = newValue.hoverY
            selectedIdleStrength = newValue.selectedIdleStrength
            selectedFloatStrength = newValue.selectedFloatStrength
            selectedFloatProgress = newValue.selectedFloatProgress
        }
    }

    private var hoverLocation: CGPoint {
        CGPoint(x: hoverX, y: hoverY)
    }

    func body(content: Content) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !usesAnimatedClock)) { timeline in
            let effectiveHoverLocation = effectiveHoverLocation(for: timeline.date)
            cardBody(content, effectiveHoverLocation: effectiveHoverLocation)
        }
    }

    private var usesAnimatedClock: Bool {
        progress > 0 || selectedFloatStrength > 0 || selectedIdleStrength > 0
    }

    private func cardBody(_ content: Content, effectiveHoverLocation: CGPoint) -> some View {
        content
            .rotation3DEffect(
                .degrees(xTilt(for: effectiveHoverLocation)),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.68
            )
            .rotation3DEffect(
                .degrees(yTilt(for: effectiveHoverLocation)),
                axis: (x: 0, y: -1, z: 0),
                perspective: 0.68
            )
            .scaleEffect(1 + progress * 0.006 + selectedScaleBoost(for: selectedFloatProgress))
            .offset(y: -progress + selectedLiftOffset + selectedFloatOffset(for: selectedFloatProgress))
            .overlay { foilOverlay(for: effectiveHoverLocation) }
            .overlay { depthBorder(for: effectiveHoverLocation) }
    }

    private func foilOverlay(for effectiveHoverLocation: CGPoint) -> some View {
        GeometryReader { proxy in
            HistoryFoilShader(
                hoverLocation: effectiveHoverLocation,
                cornerRadius: cornerRadius
            )
            .opacity(progress)
            .mask(alignment: .top) {
                VStack(spacing: 0) {
                    Rectangle()
                        .frame(height: max(proxy.size.height - protectedThumbnailOverlayHeight, 0))

                    Spacer(minLength: 0)
                }
            }
            .allowsHitTesting(false)
            .animation(.easeInOut(duration: 0.34), value: selectedIdleStrength)
        }
    }

    private func depthBorder(for effectiveHoverLocation: CGPoint) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(borderGradient(for: effectiveHoverLocation), lineWidth: 2.2)
                .blur(radius: 1.4)
                .opacity(0.06)

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(borderGradient(for: effectiveHoverLocation), lineWidth: 1.1)
                .opacity(0.36)
        }
        .opacity(progress)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .allowsHitTesting(false)
    }

    private func borderGradient(for effectiveHoverLocation: CGPoint) -> LinearGradient {
        LinearGradient(
            colors: [
                Color.clear,
                AppTheme.snipAccent.opacity(0.30),
                Color(red: 0.62, green: 0.70, blue: 1.00).opacity(0.28),
                Color(red: 1.00, green: 0.72, blue: 0.58).opacity(0.12),
                Color(red: 0.48, green: 0.95, blue: 0.82).opacity(0.22),
                Color.clear
            ],
            startPoint: UnitPoint(
                x: clampedUnit(effectiveHoverLocation.x - 0.28),
                y: clampedUnit(effectiveHoverLocation.y - 0.46)
            ),
            endPoint: UnitPoint(
                x: clampedUnit(effectiveHoverLocation.x + 0.42),
                y: clampedUnit(effectiveHoverLocation.y + 0.52)
            )
        )
    }

    private func xTilt(for effectiveHoverLocation: CGPoint) -> Double {
        Double((0.5 - effectiveHoverLocation.y) * 3.0 * progress)
    }

    private func yTilt(for effectiveHoverLocation: CGPoint) -> Double {
        Double((effectiveHoverLocation.x - 0.5) * 3.8 * progress)
    }

    private func effectiveHoverLocation(for date: Date) -> CGPoint {
        let idleHoverLocation = selectedIdleHoverLocation(for: date)
        let idleStrength = CGFloat(selectedIdleStrength)
        return CGPoint(
            x: hoverLocation.x + (idleHoverLocation.x - hoverLocation.x) * idleStrength,
            y: hoverLocation.y + (idleHoverLocation.y - hoverLocation.y) * idleStrength
        )
    }

    private func selectedIdleHoverLocation(for date: Date) -> CGPoint {
        let elapsed = max(0, date.timeIntervalSince(selectedIdleStartDate) - selectedIdleHoverEnterDuration)
        let phase = (elapsed / selectedIdleHoverAnimationDuration).truncatingRemainder(dividingBy: 1)
        return CGPoint(
            x: 0.5 + CGFloat(sin(phase * .pi * 2)) * selectedIdleHoverHorizontalAmplitude,
            y: 0.5 + CGFloat(sin(phase * .pi * 4)) * selectedIdleHoverVerticalAmplitude
        )
    }

    private var selectedLiftOffset: Double {
        return -selectedFloatStrength * 0.42
    }

    private func selectedFloatOffset(for floatProgress: Double) -> Double {
        return -selectedFloatStrength * (0.16 + floatProgress * 0.36)
    }

    private func selectedScaleBoost(for floatProgress: Double) -> Double {
        return selectedFloatStrength * (0.0015 + floatProgress * 0.0018)
    }
}

private struct HistoryFoilShader: View {
    let hoverLocation: CGPoint
    let cornerRadius: CGFloat

    var body: some View {
        ZStack {
            foilColorShift
            foilBanding
        }
        .blendMode(.screen)
        .saturation(1.20)
        .contrast(1.10)
        .brightness(-0.030)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var foilColorShift: some View {
        AngularGradient(
            colors: [
                Color(red: 0.38, green: 0.74, blue: 1.00).opacity(0.070),
                Color(red: 0.58, green: 0.52, blue: 0.94).opacity(0.064),
                Color(red: 0.36, green: 0.72, blue: 0.86).opacity(0.048),
                Color(red: 0.76, green: 0.58, blue: 0.92).opacity(0.056),
                Color(red: 0.94, green: 0.58, blue: 0.44).opacity(0.038),
                Color(red: 0.88, green: 0.76, blue: 0.36).opacity(0.032),
                Color(red: 0.38, green: 0.74, blue: 1.00).opacity(0.070)
            ],
            center: UnitPoint(
                x: clampedUnit(0.24 + hoverLocation.x * 0.52),
                y: clampedUnit(0.24 + hoverLocation.y * 0.52)
            )
        )
    }

    private var foilBanding: some View {
        LinearGradient(
            colors: [
                Color(red: 0.38, green: 0.74, blue: 1.00).opacity(0.038),
                Color(red: 0.58, green: 0.52, blue: 0.94).opacity(0.060),
                Color(red: 0.36, green: 0.72, blue: 0.86).opacity(0.046),
                Color(red: 0.76, green: 0.58, blue: 0.92).opacity(0.052),
                Color(red: 0.94, green: 0.58, blue: 0.44).opacity(0.038),
                Color(red: 0.88, green: 0.76, blue: 0.36).opacity(0.032)
            ],
            startPoint: UnitPoint(
                x: hoverLocation.x - 0.86,
                y: hoverLocation.y - 0.62
            ),
            endPoint: UnitPoint(
                x: hoverLocation.x + 0.86,
                y: hoverLocation.y + 0.66
            )
        )
    }

}

private struct HistoryCardHoverTrackingArea: NSViewRepresentable {
    @Binding var hoverLocation: CGPoint
    @Binding var isHovered: Bool

    func makeNSView(context: Context) -> TrackingView {
        let view = TrackingView()
        view.hoverLocation = $hoverLocation
        view.isHovered = $isHovered
        return view
    }

    func updateNSView(_ view: TrackingView, context: Context) {
        view.hoverLocation = $hoverLocation
        view.isHovered = $isHovered
    }

    final class TrackingView: NSView {
        var hoverLocation: Binding<CGPoint>?
        var isHovered: Binding<Bool>?
        private var lastInBoundsHoverLocation = CGPoint(x: 0.5, y: 0.5)

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            for trackingArea in trackingAreas {
                removeTrackingArea(trackingArea)
            }
            addTrackingArea(
                NSTrackingArea(
                    rect: .zero,
                    options: [.activeInKeyWindow, .inVisibleRect, .mouseEnteredAndExited, .mouseMoved],
                    owner: self
                )
            )
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }

        override func mouseEntered(with event: NSEvent) {
            updateLocation(
                from: event,
                animation: historyCardHoverLocationAnimation(response: historyCardHoverLocationSettleDuration)
            )
            isHovered?.wrappedValue = true
        }

        override func mouseMoved(with event: NSEvent) {
            updateLocation(
                from: event,
                animation: historyCardHoverLocationAnimation(response: historyCardHoverLocationFollowDuration)
            )
        }

        override func mouseExited(with event: NSEvent) {
            updateLocation(
                from: event,
                keepsLastInBoundsWhenOutside: true,
                animation: historyCardHoverLocationAnimation(response: historyCardHoverLocationSettleDuration)
            )
            isHovered?.wrappedValue = false
        }

        private func updateLocation(
            from event: NSEvent,
            keepsLastInBoundsWhenOutside: Bool = false,
            animation: Animation? = nil
        ) {
            let point = convert(event.locationInWindow, from: nil)
            guard bounds.width > 0, bounds.height > 0 else {
                setHoverLocation(CGPoint(x: 0.5, y: 0.5), animation: animation)
                return
            }

            let nextLocation = CGPoint(
                x: clampedUnit(point.x / bounds.width),
                y: clampedUnit(1 - point.y / bounds.height)
            )
            let isInBounds = bounds.contains(point)
            if isInBounds {
                lastInBoundsHoverLocation = nextLocation
            }

            setHoverLocation(
                keepsLastInBoundsWhenOutside && !isInBounds ? lastInBoundsHoverLocation : nextLocation,
                animation: animation
            )
        }

        private func setHoverLocation(_ location: CGPoint, animation: Animation?) {
            guard let animation else {
                hoverLocation?.wrappedValue = location
                return
            }

            withAnimation(animation) {
                hoverLocation?.wrappedValue = location
            }
        }
    }
}

private func clampedUnit(_ value: CGFloat) -> CGFloat {
    min(max(value, 0), 1)
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
    let fontSize: Int
    var tint: Color = .accentColor
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: CGFloat(fontSize), weight: .semibold))
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

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(foregroundColor(configuration: configuration))
            .background {
                RoundedRectangle(cornerRadius: 5)
                    .fill(backgroundColor(configuration: configuration))
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.12), value: isHovered)
    }

    private func foregroundColor(configuration: Configuration) -> Color {
        guard isEnabled else {
            return .secondary.opacity(0.35)
        }
        return isHovered || configuration.isPressed ? tint : .secondary
    }

    private func backgroundColor(configuration: Configuration) -> Color {
        guard isEnabled else {
            return Color.clear
        }
        return tint.opacity(configuration.isPressed ? 0.18 : isHovered ? 0.10 : 0)
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
