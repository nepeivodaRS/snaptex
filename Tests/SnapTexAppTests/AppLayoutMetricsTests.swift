import AppKit
import XCTest
@testable import SnapTexApp

final class AppLayoutMetricsTests: XCTestCase {
    func testMinimumWindowWidthFitsCurrentToolbarLabels() {
        let paneMinimumWidth = AppLayoutMetrics.historyPaneMinWidth
            + AppLayoutMetrics.capturePaneMinWidth
            + AppLayoutMetrics.outputPaneMinWidth
            + 32

        XCTAssertGreaterThanOrEqual(AppLayoutMetrics.mainWindowMinWidth, 1_200)
        XCTAssertGreaterThanOrEqual(AppLayoutMetrics.mainWindowMinWidth, paneMinimumWidth)
    }

    func testHistoryPaneAllowsWiderFolderOrganization() {
        XCTAssertGreaterThanOrEqual(AppLayoutMetrics.historyPaneMinWidth, 280)
        XCTAssertGreaterThanOrEqual(AppLayoutMetrics.historyPaneIdealWidth, 340)
        XCTAssertGreaterThanOrEqual(AppLayoutMetrics.historyPaneMaxWidth, 560)
    }

    func testToolbarLabelsReserveSingleLineWidths() {
        XCTAssertGreaterThanOrEqual(AppLayoutMetrics.toolbarModelLabelWidth, 76)
        XCTAssertGreaterThanOrEqual(AppLayoutMetrics.toolbarPassesLabelWidth, 82)
        XCTAssertGreaterThanOrEqual(AppLayoutMetrics.toolbarPrimaryActionMinWidth, 76)
        XCTAssertGreaterThanOrEqual(AppLayoutMetrics.toolbarActionButtonMinWidth, 82)
    }

    func testToolbarHasResponsiveFullAndCompactLayouts() throws {
        let source = try sourceFile("Sources/SnapTexApp/Views/ContentView.swift")

        XCTAssertTrue(source.contains("ViewThatFits(in: .horizontal)"))
        XCTAssertTrue(source.contains("FullToolbarLayout("))
        XCTAssertTrue(source.contains("CompactToolbarLayout("))
        XCTAssertTrue(source.contains("ToolbarActionStrip("))
        XCTAssertTrue(source.contains("RecognitionControlGroup("))
    }

    func testToolbarControlsUseStableMinimumWidths() throws {
        let source = try sourceFile("Sources/SnapTexApp/Views/ContentView.swift")

        XCTAssertTrue(source.contains(".frame(minWidth: AppLayoutMetrics.toolbarPrimaryActionMinWidth)"))
        XCTAssertTrue(source.contains(".frame(minWidth: AppLayoutMetrics.toolbarActionButtonMinWidth)"))
        XCTAssertTrue(source.contains(".fixedSize(horizontal: true, vertical: false)"))
    }

    func testCaptureEmptyStateDoesNotExposeSnipAndPasteActions() throws {
        let source = try sourceFile("Sources/SnapTexApp/Views/CapturePreviewPane.swift")

        XCTAssertFalse(source.contains("CaptureEmptyStateActions("))
        XCTAssertFalse(source.contains("model.snip()"))
        XCTAssertFalse(source.contains("model.pasteImageFromClipboard()"))
        XCTAssertFalse(source.contains("Label(\"Paste\", systemImage: \"doc.on.clipboard\")"))
    }

    func testOutputHeaderExposesCopyActionNextToLatexEditor() throws {
        let source = try sourceFile("Sources/SnapTexApp/Views/OutputPane.swift")

        XCTAssertTrue(source.contains("OutputCopyButton("))
        XCTAssertTrue(source.contains("model.copyLatex()"))
        XCTAssertTrue(source.contains("Label(\"Copy\", systemImage: \"doc.on.doc\")"))
    }

    func testGraphiteButtonsAnimateHoverState() throws {
        let source = try sourceFile("Sources/SnapTexApp/Support/AppTheme.swift")

        XCTAssertTrue(source.contains("GraphiteButtonBody"))
        XCTAssertTrue(source.contains("@State private var isHovered = false"))
        XCTAssertTrue(source.contains(".onHover"))
        XCTAssertTrue(source.contains(".animation(.easeOut(duration: 0.12), value: isHovered)"))
    }

    func testConfidenceIsNotDisplayedWithoutModelProvidedConfidence() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let sourceRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceFiles = [
            "Sources/SnapTexApp/Views/CapturePreviewPane.swift",
            "Sources/SnapTexApp/Views/OutputPane.swift"
        ]

        for sourceFile in sourceFiles {
            let source = try String(
                contentsOf: sourceRoot.appendingPathComponent(sourceFile),
                encoding: .utf8
            )
            XCTAssertFalse(source.contains("Confidence:"), sourceFile)
            XCTAssertFalse(source.contains("confidencePercent"), sourceFile)
        }
    }

    func testSnipButtonKeepsCropIcon() throws {
        let source = try sourceFile("Sources/SnapTexApp/Views/ContentView.swift")

        XCTAssertTrue(source.contains("Label(\"Snip\", systemImage: \"crop\")"))
    }

    func testRenderedPreviewHeaderExposesFormulaExportMenu() throws {
        let toolbarSource = try sourceFile("Sources/SnapTexApp/Views/ContentView.swift")
        let previewSource = try sourceFile("Sources/SnapTexApp/Views/CapturePreviewPane.swift")

        XCTAssertFalse(toolbarSource.contains("ExportFormulaMenu"))
        XCTAssertTrue(previewSource.contains("ExportFormulaMenu"))
        XCTAssertTrue(previewSource.contains("model.exportFormula(as: format)"))
        XCTAssertTrue(previewSource.contains("Label(\"Export\", systemImage: \"square.and.arrow.down\")"))
    }

    func testRenderedPreviewHeaderKeepsTitleSingleLine() throws {
        let source = try sourceFile("Sources/SnapTexApp/Views/CapturePreviewPane.swift")
        guard let titleRange = source.range(of: "Text(\"Rendered Output\")") else {
            XCTFail("Rendered Output header title should exist")
            return
        }

        XCTAssertTrue(source[titleRange.upperBound...].prefix(140).contains(".lineLimit(1)"))
    }

    func testExportMenuUsesHoverAnimation() throws {
        let source = try sourceFile("Sources/SnapTexApp/Views/CapturePreviewPane.swift")

        XCTAssertTrue(source.contains("@State private var isExportHovered = false"))
        XCTAssertTrue(source.contains("@State private var isExportPressed = false"))
        XCTAssertTrue(source.contains("ExportMenuLabel("))
        XCTAssertTrue(source.contains("ExportFormulaMenuBridge("))
        XCTAssertTrue(source.contains("isHovered: $isExportHovered"))
        XCTAssertTrue(source.contains("isPressed: $isExportPressed"))
        XCTAssertTrue(source.contains(".animation(.easeOut(duration: 0.12), value: isExportHovered)"))
        XCTAssertTrue(source.contains(".animation(.easeOut(duration: 0.08), value: isExportPressed)"))
    }

    func testRecognitionControlsUseIndividualSegmentHoverAndSlidingSelection() throws {
        let source = try sourceFile("Sources/SnapTexApp/Views/ContentView.swift")

        XCTAssertTrue(source.contains("Text(\"OCR model\")"))
        XCTAssertTrue(source.contains("Text(\"OCR passes\")"))
        XCTAssertTrue(source.contains("SmoothRecognitionSegmentedControl("))
        XCTAssertTrue(source.contains("@State private var hoveredOption: Option?"))
        XCTAssertTrue(source.contains("hoveredOption == option"))
        XCTAssertTrue(source.contains("private var selectedIndicator"))
        XCTAssertTrue(source.contains(".offset(x: CGFloat(selectedIndex) * segmentWidth + 2)"))
        XCTAssertTrue(source.contains(".animation(.spring(response: 0.28, dampingFraction: 0.82), value: selectedIndex)"))
        XCTAssertTrue(source.contains(".onHover { isHovered in"))
        XCTAssertFalse(source.contains("Picker(\"OCR model\""))
        XCTAssertFalse(source.contains("Picker(\"OCR passes\""))
        XCTAssertFalse(source.contains("HoverableRecognitionControl("))
    }

    func testRecognitionControlsAreDisabledOnlyForCurrentRecognizingItem() throws {
        let source = try sourceFile("Sources/SnapTexApp/Views/ContentView.swift")

        XCTAssertTrue(source.contains(".disabled(!model.canChangeRecognitionSettings)"))
        XCTAssertTrue(source.contains("model.isCurrentItemRecognizing"))
        XCTAssertFalse(source.contains(".disabled(model.isProcessing)"))
    }

    func testZoomControlsUseHoverAwareButtons() throws {
        let source = try sourceFile("Sources/SnapTexApp/Views/CapturePreviewPane.swift")

        XCTAssertTrue(source.contains("ZoomIconButton"))
        XCTAssertTrue(source.contains(".onHover"))
        XCTAssertFalse(source.contains(".buttonStyle(.borderless)"))
    }

    func testGraphiteThemeAvoidsBlueGradientStyling() throws {
        let sourceRoot = try Self.sourceRoot()
        let themeURL = sourceRoot.appendingPathComponent("Sources/SnapTexApp/Support/AppTheme.swift")

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: themeURL.path),
            "Graphite theme support should exist"
        )

        guard FileManager.default.fileExists(atPath: themeURL.path) else {
            return
        }

        let source = try String(contentsOf: themeURL, encoding: .utf8)
        XCTAssertTrue(source.contains("windowBackground"))
        XCTAssertFalse(source.contains("LinearGradient"))
        XCTAssertFalse(source.contains("Color.blue"))
        XCTAssertFalse(source.contains("Color.accentColor"))
    }

    func testToolbarAndHistoryHeaderUseWindowBackground() throws {
        let contentView = try sourceFile("Sources/SnapTexApp/Views/ContentView.swift")
        let historyView = try sourceFile("Sources/SnapTexApp/Views/HistorySidebarView.swift")

        XCTAssertFalse(contentView.contains(".background(AppTheme.panelBackground)"))
        XCTAssertFalse(historyView.contains(".background(AppTheme.panelBackground)"))
        XCTAssertTrue(contentView.contains(".background(AppTheme.windowBackground)"))
        XCTAssertTrue(historyView.contains(".background(AppTheme.windowBackground)"))
    }

    func testHistorySidebarUsesFolderTerminologyAndDragDrop() throws {
        let historyView = try sourceFile("Sources/SnapTexApp/Views/HistorySidebarView.swift")

        XCTAssertTrue(historyView.contains("Folders"))
        XCTAssertTrue(historyView.contains("onDrag"))
        XCTAssertTrue(historyView.contains("onDrop"))
        XCTAssertTrue(historyView.contains("Change Folder Color"))
        XCTAssertTrue(historyView.contains("Remove Folder with Snaps"))
        XCTAssertFalse(historyView.contains("Projects"))
        XCTAssertFalse(historyView.contains("Project name"))
        XCTAssertFalse(historyView.contains("New Project"))
    }

    func testFolderColorPickerUsesIconOnlyHoverSubmenu() throws {
        let historyView = try sourceFile("Sources/SnapTexApp/Views/HistorySidebarView.swift")

        XCTAssertTrue(historyView.contains("FolderContextMenuBridge: NSViewRepresentable"))
        XCTAssertTrue(historyView.contains("NSMenuItem(title: \"Change Folder Color\""))
        XCTAssertTrue(historyView.contains("HistoryFolderColor.allCases"))
        XCTAssertTrue(historyView.contains("NSMenuItem(title: \"\""))
        XCTAssertTrue(historyView.contains("Change Folder Color"))
        XCTAssertTrue(historyView.contains("image.isTemplate = false"))
        XCTAssertTrue(historyView.contains("NSSize(width: 34, height: 18)"))
        XCTAssertTrue(historyView.contains("let colorInset: CGFloat = 4"))
        XCTAssertTrue(historyView.contains("let checkmarkRightX = size.width - colorInset"))
        XCTAssertFalse(historyView.contains("Move Folder Up"))
        XCTAssertFalse(historyView.contains("Move Folder Down"))
        XCTAssertFalse(historyView.contains("canMoveUp"))
        XCTAssertFalse(historyView.contains("canMoveDown"))
        XCTAssertFalse(historyView.contains("FolderColorPalette"))
        XCTAssertFalse(historyView.contains(".popover(isPresented: $isColorPickerPresented"))
        XCTAssertFalse(historyView.contains("Text(color.title)"))
        XCTAssertFalse(historyView.contains("Label(\"Change Folder Color\""))
    }

    func testFolderRowsUseDragReorderingInsteadOfMoveMenuItems() throws {
        let historyView = try sourceFile("Sources/SnapTexApp/Views/HistorySidebarView.swift")

        XCTAssertTrue(historyView.contains("DragGesture(minimumDistance: 5, coordinateSpace: .named(historyFoldersCoordinateSpace))"))
        XCTAssertTrue(historyView.contains("FolderRowFramePreferenceKey"))
        XCTAssertTrue(historyView.contains("folderRowFrames"))
        XCTAssertTrue(historyView.contains("folderDropTarget(for:"))
        XCTAssertTrue(historyView.contains("isAnyFolderDragging"))
        XCTAssertTrue(historyView.contains("moveDroppedFolder"))
        XCTAssertTrue(historyView.contains("FolderInsertionIndicator"))
        XCTAssertTrue(historyView.contains("FolderDropTarget"))
        XCTAssertTrue(historyView.contains("HistoryFolderDropPlacement"))
        XCTAssertTrue(historyView.contains("model.moveHistoryFolder(withID: sourceID, relativeTo: target.folderID, placement: target.placement)"))
        XCTAssertFalse(historyView.contains("FolderReorderDropDelegate"))
        XCTAssertFalse(historyView.contains("HistoryDragPayload.folder"))
        XCTAssertFalse(historyView.contains("folderDropMidpointY"))
        XCTAssertFalse(historyView.contains("lastReorderTargetID"))
        XCTAssertFalse(historyView.contains("moveHistoryFolderUp"))
        XCTAssertFalse(historyView.contains("moveHistoryFolderDown"))
    }

    func testHistoryRowsUseIconOnlyFolderBadge() throws {
        let historyView = try sourceFile("Sources/SnapTexApp/Views/HistorySidebarView.swift")

        XCTAssertTrue(historyView.contains("folderBadgeColor"))
        XCTAssertTrue(historyView.contains("\"folder.fill\""))
        XCTAssertFalse(historyView.contains("Label(folderLabel"))
        XCTAssertFalse(historyView.contains("let folderLabel: String?"))
    }

    func testFoldersCanBeCollapsedFromFoldersHeader() throws {
        let historyView = try sourceFile("Sources/SnapTexApp/Views/HistorySidebarView.swift")

        XCTAssertTrue(historyView.contains("@AppStorage(\"historyFoldersExpanded\")"))
        XCTAssertTrue(historyView.contains("HistoryFoldersHeader"))
        XCTAssertTrue(historyView.contains("isExpanded.toggle()"))
        XCTAssertTrue(historyView.contains("if isFoldersExpanded {"))
    }

    func testHistoryHeaderExposesSortMenuNextToNewFolderButton() throws {
        let historyView = try sourceFile("Sources/SnapTexApp/Views/HistorySidebarView.swift")
        let historyFolder = try sourceFile("Sources/SnapTexApp/Models/HistoryFolder.swift")

        XCTAssertTrue(historyView.contains("HistorySortMenu("))
        XCTAssertTrue(historyView.contains("selection: $model.historySortMode"))
        XCTAssertTrue(historyView.contains("HistorySortMenuBridge: NSViewRepresentable"))
        XCTAssertTrue(historyView.contains(".frame(width: historyRowControlSize, height: historyRowControlSize)"))
        XCTAssertTrue(historyView.contains("private var sortIcon: some View"))
        XCTAssertTrue(historyView.contains("sortIconBackgroundOpacity"))
        XCTAssertTrue(historyView.contains(".onHover { isSortHovered = $0 }"))
        XCTAssertTrue(historyView.contains(".animation(.easeOut(duration: 0.12), value: isSortHovered)"))
        XCTAssertTrue(historyView.contains("mode.menuTitle"))
        XCTAssertTrue(historyFolder.contains("Sort by \\(title)"))
        XCTAssertTrue(historyFolder.contains("case time"))
        XCTAssertTrue(historyFolder.contains("case folder"))
        XCTAssertTrue(historyView.contains("folder.badge.plus"))
        XCTAssertFalse(historyView.contains(".menuStyle(.borderlessButton)"))
    }

    func testHistoryRowsUseLeftFolderBadgeForFolderAssignment() throws {
        let historyView = try sourceFile("Sources/SnapTexApp/Views/HistorySidebarView.swift")

        XCTAssertTrue(historyView.contains("HistoryFolderAssignmentMenu"))
        XCTAssertTrue(historyView.contains("HistoryFolderAssignmentIcon("))
        XCTAssertTrue(historyView.contains("FolderAssignmentMenuBridge: NSViewRepresentable"))
        XCTAssertTrue(historyView.contains("@State private var isFolderMenuHovered = false"))
        XCTAssertTrue(historyView.contains("@State private var isFolderMenuPressed = false"))
        XCTAssertTrue(historyView.contains("isHovered: $isFolderMenuHovered"))
        XCTAssertTrue(historyView.contains("isPressed: $isFolderMenuPressed"))
        XCTAssertTrue(historyView.contains("systemName: currentFolderID == nil ? \"folder\" : \"folder.fill\""))
        XCTAssertTrue(historyView.contains("color: folderBadgeColor?.tint ?? Color.secondary.opacity(0.45)"))
        XCTAssertTrue(historyView.contains("folderIconBackgroundOpacity"))
        XCTAssertTrue(historyView.contains(".scaleEffect(isPressed ? 0.94 : isHovered ? 1.05 : 1)"))
        XCTAssertTrue(historyView.contains("showMenu(with: event)"))
        XCTAssertFalse(historyView.contains("HistoryMoveMenu("))
        XCTAssertFalse(historyView.contains(".foregroundStyle(folderBadgeColor?.tint ?? Color.secondary.opacity(0.45))"))
    }

    func testRenderedPreviewZoomCanBeFixedPerSnap() throws {
        let capturePreview = try sourceFile("Sources/SnapTexApp/Views/CapturePreviewPane.swift")
        let entry = try sourceFile("Sources/SnapTexApp/Models/OCRHistoryEntry.swift")

        XCTAssertTrue(capturePreview.contains("model.renderedPreviewFontSize"))
        XCTAssertTrue(capturePreview.contains("model.toggleFixedRenderedPreviewZoom()"))
        XCTAssertTrue(capturePreview.contains("model.isRenderedPreviewZoomFixed"))
        XCTAssertTrue(capturePreview.contains("pin.fill"))
        XCTAssertTrue(entry.contains("fixedRenderedPreviewFontSize"))
        XCTAssertFalse(capturePreview.contains("@State private var previewFontSize"))
    }

    func testHistoryItemRenameLivesOnTitleDoubleClickAndContextMenu() throws {
        let historyView = try sourceFile("Sources/SnapTexApp/Views/HistorySidebarView.swift")

        XCTAssertTrue(historyView.contains("TapGesture(count: 2).onEnded { beginRename() }"))
        XCTAssertTrue(historyView.contains("Button(\"Rename\", action: beginRename)"))
        XCTAssertFalse(historyView.contains("HistoryActionButton(systemName: \"square.and.pencil\""))
    }

    func testHistoryRowActionsKeepControlsOnOneCenterLine() throws {
        let historyView = try sourceFile("Sources/SnapTexApp/Views/HistorySidebarView.swift")

        XCTAssertTrue(historyView.contains("HistoryTextActionButton(title: \"Copy\""))
        XCTAssertTrue(historyView.contains("private let historyRowControlSize: CGFloat = 24"))
        XCTAssertTrue(historyView.contains(".frame(width: historyRowControlSize, height: historyRowControlSize)"))
        XCTAssertFalse(historyView.contains("help: \"Copy again\""))
    }

    func testAppDelegateHandlesDockReopenWhenNoWindowIsVisible() throws {
        let source = try sourceFile("Sources/SnapTexApp/App/SnapTexApp.swift")

        XCTAssertTrue(source.contains("applicationShouldHandleReopen"))
        XCTAssertTrue(source.contains("makeKeyAndOrderFront"))
    }

    func testMainWindowAppliesNativeContentMinimumSize() throws {
        let source = try sourceFile("Sources/SnapTexApp/App/SnapTexApp.swift")

        XCTAssertTrue(source.contains("WindowMinimumSizeEnforcer("))
        XCTAssertTrue(source.contains("minSize: NSSize("))
        XCTAssertTrue(source.contains("width: AppLayoutMetrics.mainWindowMinWidth"))
        XCTAssertTrue(source.contains("height: AppLayoutMetrics.mainWindowMinHeight"))
        XCTAssertTrue(source.contains("window.contentMinSize = minSize"))
        XCTAssertTrue(source.contains("window.setContentSize(clampedContentSize)"))
    }

    func testSettingsUsesExplicitPresenterInsteadOfUnhandledSelector() throws {
        let source = try sourceFile("Sources/SnapTexApp/App/SnapTexApp.swift")

        XCTAssertTrue(source.contains("SettingsWindowPresenter.show"))
        XCTAssertFalse(source.contains("showSettingsWindow:"))
    }

    func testSettingsPresenterAppliesNativeMinimumSize() throws {
        let source = try sourceFile("Sources/SnapTexApp/App/SnapTexApp.swift")

        XCTAssertTrue(source.contains("minWidth: AppLayoutMetrics.settingsWindowMinWidth"))
        XCTAssertTrue(source.contains("idealWidth: AppLayoutMetrics.settingsWindowIdealWidth"))
        XCTAssertTrue(source.contains("minHeight: AppLayoutMetrics.settingsWindowMinHeight"))
        XCTAssertTrue(source.contains("idealHeight: AppLayoutMetrics.settingsWindowIdealHeight"))
        XCTAssertTrue(source.contains("window.contentMinSize = NSSize("))
        XCTAssertTrue(source.contains("width: AppLayoutMetrics.settingsWindowMinWidth"))
        XCTAssertTrue(source.contains("height: AppLayoutMetrics.settingsWindowMinHeight"))
    }

    func testSettingsCanRevealModelFilesInFinder() throws {
        let source = try sourceFile("Sources/SnapTexApp/Views/SettingsView.swift")

        XCTAssertTrue(source.contains("model.revealModelFilesInFinder(variant)"))
        XCTAssertTrue(source.contains("folder"))
        XCTAssertTrue(source.contains("Reveal local"))
    }

    @MainActor
    func testSettingsPresenterCreatesAndReusesOneWindow() {
        _ = NSApplication.shared
        SettingsWindowPresenter.closeForTesting()
        let model = AppModel(settingsStore: AppSettingsStore(defaults: Self.makeTestDefaults()))

        SettingsWindowPresenter.show(model: model)
        let countAfterFirstOpen = settingsWindowCount()
        let settingsWindow = settingsWindow()

        SettingsWindowPresenter.show(model: model)
        let countAfterSecondOpen = settingsWindowCount()

        XCTAssertEqual(1, countAfterFirstOpen)
        XCTAssertEqual(1, countAfterSecondOpen)
        XCTAssertEqual(AppLayoutMetrics.settingsWindowMinWidth, settingsWindow?.contentMinSize.width)
        XCTAssertEqual(AppLayoutMetrics.settingsWindowMinHeight, settingsWindow?.contentMinSize.height)

        SettingsWindowPresenter.closeForTesting()
    }

    private func sourceFile(_ path: String) throws -> String {
        try String(
            contentsOf: try Self.sourceRoot().appendingPathComponent(path),
            encoding: .utf8
        )
    }

    @MainActor
    private func settingsWindowCount() -> Int {
        NSApp.windows.filter { $0.title == "Settings" }.count
    }

    @MainActor
    private func settingsWindow() -> NSWindow? {
        NSApp.windows.first { $0.title == "Settings" }
    }

    private static func sourceRoot() throws -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private static func makeTestDefaults() -> UserDefaults {
        let suiteName = "SnapTexAppTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
