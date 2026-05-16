import AppKit
import XCTest
@testable import SnapTexApp

final class AppLayoutMetricsTests: XCTestCase {
    func testMinimumWindowWidthFitsCurrentToolbarLabels() {
        let paneMinimumWidth = AppLayoutMetrics.historyPaneMinWidth
            + AppLayoutMetrics.capturePaneMinWidth
            + AppLayoutMetrics.outputPaneMinWidth
            + 32
        let fullToolbarMinimumWidth = AppLayoutMetrics.toolbarPrimaryActionMinWidth
            + 8 + AppLayoutMetrics.toolbarPrimaryActionMinWidth
            + 24
            + 1
            + AppLayoutMetrics.toolbarModelLabelWidth + 6 + 190
            + 32 + 6 + 104
            + AppLayoutMetrics.toolbarPassesLabelWidth + 6 + 120
            + 12 * 2
            + AppLayoutMetrics.toolbarStatusWidth
            + 12 * 5
            + AppLayoutMetrics.toolbarLeadingPadding
            + AppLayoutMetrics.outputPaneContentPadding

        XCTAssertGreaterThanOrEqual(AppLayoutMetrics.mainWindowMinWidth, 1_320)
        XCTAssertGreaterThanOrEqual(AppLayoutMetrics.mainWindowMinWidth, paneMinimumWidth)
        XCTAssertGreaterThanOrEqual(AppLayoutMetrics.mainWindowMinWidth, fullToolbarMinimumWidth)
    }

    func testHistoryPaneAllowsWiderFolderOrganization() {
        XCTAssertGreaterThanOrEqual(AppLayoutMetrics.historyPaneMinWidth, 280)
        XCTAssertGreaterThanOrEqual(AppLayoutMetrics.historyPaneIdealWidth, 340)
        XCTAssertGreaterThanOrEqual(AppLayoutMetrics.historyPaneMaxWidth, 560)
    }

    func testToolbarLabelsReserveSingleLineWidths() {
        let metricsSource = try? sourceFile("Sources/SnapTexApp/Support/AppLayoutMetrics.swift")

        XCTAssertGreaterThanOrEqual(AppLayoutMetrics.toolbarModelLabelWidth, 44)
        XCTAssertGreaterThanOrEqual(AppLayoutMetrics.toolbarPassesLabelWidth, 54)
        XCTAssertGreaterThanOrEqual(AppLayoutMetrics.toolbarPrimaryActionMinWidth, 92)
        XCTAssertFalse(metricsSource?.contains("toolbarSecondaryActionMinWidth") == true)
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
        let toolbarSource = try sourceFile("Sources/SnapTexApp/Views/ContentView.swift")

        XCTAssertTrue(toolbarSource.contains(".frame(minWidth: AppLayoutMetrics.toolbarPrimaryActionMinWidth)"))
        XCTAssertFalse(toolbarSource.contains("AppLayoutMetrics.toolbarSecondaryActionMinWidth"))
        XCTAssertTrue(toolbarSource.contains(".fixedSize(horizontal: true, vertical: false)"))
    }

    func testToolbarDownloadStatusUsesModelNameWithoutRedundantModelSuffix() throws {
        let source = try sourceFile("Sources/SnapTexApp/Views/ContentView.swift")

        XCTAssertTrue(source.contains("Text(\"Downloading \\(activeDownload.variant.title)\")"))
        XCTAssertTrue(source.contains(".frame(width: AppLayoutMetrics.toolbarStatusWidth, alignment: .trailing)"))
        XCTAssertFalse(source.contains("Text(\"Downloading \\(activeDownload.variant.title) model\")"))
        XCTAssertFalse(source.contains(".frame(width: AppLayoutMetrics.toolbarStatusWidth, alignment: .leading)"))
    }

    func testCaptureEmptyStateDoesNotExposeSnipOrPasteLabel() throws {
        let source = try sourceFile("Sources/SnapTexApp/Views/CapturePreviewPane.swift")

        XCTAssertFalse(source.contains("CaptureEmptyStateActions("))
        XCTAssertFalse(source.contains("model.snip()"))
        XCTAssertFalse(source.contains("Label(\"Paste\", systemImage: \"doc.on.clipboard\")"))
    }

    func testToolbarExposesSnipAndFinderAddActions() throws {
        let source = try sourceFile("Sources/SnapTexApp/Views/ContentView.swift")
        let modelSource = try sourceFile("Sources/SnapTexApp/Stores/AppModel.swift")

        XCTAssertTrue(source.contains("SnipButton(model: model)"))
        XCTAssertTrue(source.contains("AddImageButton(model: model)"))
        XCTAssertTrue(source.contains("Label(\"Snip\", systemImage: \"crop\")"))
        XCTAssertTrue(source.contains("Label(\"Add\", systemImage: \"plus\")"))
        XCTAssertTrue(source.contains("model.addImageFromFinder()"))
        XCTAssertTrue(modelSource.contains("func addImageFromFinder()"))
        XCTAssertTrue(modelSource.contains("NSOpenPanel()"))
        XCTAssertTrue(modelSource.contains("panel.allowedContentTypes = [.image]"))
        XCTAssertFalse(source.contains("model.pasteImageFromClipboard()"))
        XCTAssertFalse(source.contains("model.retry()"))
        XCTAssertFalse(source.contains("model.copyLatex()"))
        XCTAssertFalse(source.contains("Label(\"Paste\", systemImage: \"doc.on.clipboard\")"))
        XCTAssertFalse(source.contains("Label(\"Retry\", systemImage: \"arrow.clockwise\")"))
        XCTAssertFalse(source.contains("Label(\"Copy\", systemImage: \"doc.on.doc\")"))
    }

    func testCaptureHeaderDoesNotExposeRetryOrAddActionsNextToTitle() throws {
        let source = try sourceFile("Sources/SnapTexApp/Views/CapturePreviewPane.swift")

        XCTAssertTrue(source.contains("private var captureHeader: some View"))
        XCTAssertTrue(source.contains("Text(\"Capture\")"))
        XCTAssertTrue(source.contains("Spacer()"))
        XCTAssertFalse(source.contains("CaptureHeaderActions(model: model)"))
        XCTAssertFalse(source.contains("private struct CaptureHeaderActions"))
        XCTAssertFalse(source.contains("model.pasteImageFromClipboard()"))
        XCTAssertFalse(source.contains("Label(\"Retry\", systemImage: \"arrow.clockwise\")"))
        XCTAssertFalse(source.contains("Label(\"Add\", systemImage: \"plus\")"))
        XCTAssertFalse(source.contains("Label(\"Paste\", systemImage: \"doc.on.clipboard\")"))
    }

    func testOutputHeaderExposesCopyActionNextToLatexEditor() throws {
        let source = try sourceFile("Sources/SnapTexApp/Views/OutputPane.swift")

        XCTAssertTrue(source.contains("OutputCopyButton("))
        XCTAssertTrue(source.contains("model.copyLatex()"))
        XCTAssertTrue(source.contains("Label(\"Copy\", systemImage: \"doc.on.doc\")"))
    }

    func testOutputUsesNSTextViewSyntaxEditor() throws {
        let outputSource = try sourceFile("Sources/SnapTexApp/Views/OutputPane.swift")
        let editorSource = try sourceFile("Sources/SnapTexApp/Views/LaTeXSyntaxTextView.swift")

        XCTAssertTrue(outputSource.contains("LaTeXSyntaxTextView("))
        XCTAssertTrue(outputSource.contains("validationIssue: model.validationIssue"))
        XCTAssertFalse(outputSource.contains("TextEditor(text: $model.latexOutput)"))
        XCTAssertTrue(editorSource.contains("NSViewRepresentable"))
        XCTAssertTrue(editorSource.contains("NSTextView"))
        XCTAssertTrue(editorSource.contains("LaTeXSyntaxHighlighter.highlightedString"))
    }

    func testOutputAlternativesHeadingDropsOCRPrefix() throws {
        let source = try sourceFile("Sources/SnapTexApp/Views/OutputPane.swift")

        XCTAssertTrue(source.contains("Text(\"Alternatives\")"))
        XCTAssertFalse(source.contains("Text(\"OCR Alternatives\")"))
    }

    func testGraphiteButtonsAnimateHoverState() throws {
        let source = try sourceFile("Sources/SnapTexApp/Support/AppTheme.swift")

        XCTAssertTrue(source.contains("GraphiteButtonBody"))
        XCTAssertTrue(source.contains("@State private var isHovered = false"))
        XCTAssertTrue(source.contains(".onHover"))
        XCTAssertTrue(source.contains(".animation(.easeOut(duration: 0.12), value: isHovered)"))
    }

    func testPrimaryToolbarActionsUseMatchingLiquidHoverStyle() throws {
        let contentView = try sourceFile("Sources/SnapTexApp/Views/ContentView.swift")
        let theme = try sourceFile("Sources/SnapTexApp/Support/AppTheme.swift")
        let addButtonSource = try viewSource(named: "AddImageButton", in: contentView)

        XCTAssertTrue(contentView.contains(".buttonStyle(LiquidSnipButtonStyle())"))
        XCTAssertTrue(addButtonSource.contains(".buttonStyle(LiquidSnipButtonStyle())"))
        XCTAssertTrue(addButtonSource.contains(".font(.system(size: CGFloat(model.settings.snipButtonFontSize), weight: .semibold))"))
        XCTAssertTrue(addButtonSource.contains(".frame(minWidth: AppLayoutMetrics.toolbarPrimaryActionMinWidth)"))
        XCTAssertTrue(theme.contains("struct LiquidSnipButtonStyle: ButtonStyle"))
        XCTAssertTrue(theme.contains("LiquidSnipTrackingArea("))
        XCTAssertTrue(theme.contains("RadialGradient("))
        XCTAssertTrue(theme.contains("AppTheme.snipAccent"))
        XCTAssertTrue(theme.contains("@State private var glowLocation = CGPoint(x: 48, y: 16)"))
        XCTAssertTrue(theme.contains(".onChange(of: mouseLocation) { updateGlowLocation($0) }"))
        XCTAssertTrue(theme.contains("private func updateGlowLocation(_ location: CGPoint)"))
        XCTAssertTrue(theme.contains(".spring(response: 0.68, dampingFraction: 0.72, blendDuration: 0.18)"))
        XCTAssertTrue(theme.contains("configuration.isPressed ? 0.34 : 0.30"))
        XCTAssertTrue(theme.contains("endRadius: max(proxy.size.width, proxy.size.height) * 1.55"))
        XCTAssertTrue(theme.contains("radius: isHovered && isEnabled ? 16 : 0"))
        XCTAssertTrue(theme.contains("return isHovered ? AppTheme.snipAccent.opacity(0.42) : Color.white.opacity(0.12)"))
        XCTAssertTrue(theme.contains(".animation(.easeInOut(duration: 0.32), value: isHovered)"))
        XCTAssertTrue(theme.contains(".cursorUpdate"))
        XCTAssertTrue(theme.contains("NSCursor.pointingHand.set()"))
        XCTAssertFalse(contentView.contains(".buttonStyle(GraphitePrimaryButtonStyle())"))
        XCTAssertFalse(addButtonSource.contains(".buttonStyle(GraphiteSecondaryButtonStyle())"))
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

        XCTAssertTrue(source.contains(".font(.system(size: CGFloat(model.settings.snipButtonFontSize), weight: .semibold))"))
        XCTAssertTrue(source.contains("Label(\"Snip\", systemImage: \"crop\")"))
        XCTAssertFalse(source.contains("Label(\"Snip\", systemImage: \"crop\")\n                .frame(minWidth: AppLayoutMetrics.toolbarPrimaryActionMinWidth)"))
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
        guard let titleRange = source.range(of: "Text(\"Output\")") else {
            XCTFail("Output header title should exist")
            return
        }

        XCTAssertTrue(source[titleRange.upperBound...].prefix(140).contains(".lineLimit(1)"))
        XCTAssertFalse(source.contains("Text(\"Rendered Output\")"))
    }

    func testRenderedPreviewHeaderStacksModelBelowTitleAndCentersActions() throws {
        let source = try sourceFile("Sources/SnapTexApp/Views/CapturePreviewPane.swift")

        XCTAssertTrue(source.contains("private let renderedOutputActionHeight: CGFloat = 30"))
        XCTAssertTrue(source.contains("private var renderedOutputHeader: some View"))
        XCTAssertTrue(source.contains("private var renderedOutputTitleBlock: some View"))
        XCTAssertTrue(source.contains("VStack(alignment: .leading, spacing: 2)"))
        XCTAssertTrue(source.contains("renderedOutputTitle.frame(height: renderedOutputActionHeight, alignment: .center)"))
        XCTAssertTrue(source.contains("Text(\"Model: \\(currentResultModel.title)\")"))
        XCTAssertTrue(source.contains("renderedOutputActions.frame(height: renderedOutputActionHeight, alignment: .center)"))
        XCTAssertTrue(source.contains("ExportFormulaMenu(model: model).frame(height: renderedOutputActionHeight, alignment: .center)"))
        XCTAssertTrue(source.contains("previewZoomControls.frame(height: renderedOutputActionHeight, alignment: .center)"))
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
        XCTAssertFalse(source.contains(".offset(y: isHovered && isEnabled && !isPressed ? -2 : 0)"))
    }

    func testRecognitionControlsUseIndividualSegmentHoverAndSlidingSelection() throws {
        let source = try sourceFile("Sources/SnapTexApp/Views/ContentView.swift")

        XCTAssertTrue(source.contains("Text(\"Model\")"))
        XCTAssertTrue(source.contains("Text(\"Passes\")"))
        XCTAssertFalse(source.contains("Text(\"OCR model\")"))
        XCTAssertFalse(source.contains("Text(\"OCR passes\")"))
        XCTAssertTrue(source.contains("SmoothRecognitionSegmentedControl("))
        XCTAssertTrue(source.contains("@State private var hoveredOption: Option?"))
        XCTAssertTrue(source.contains("hoveredOption == option"))
        XCTAssertTrue(source.contains("private var selectedIndicator"))
        XCTAssertTrue(source.contains(".offset(x: CGFloat(selectedIndex) * segmentWidth + 2)"))
        XCTAssertTrue(source.contains(".animation(.spring(response: 0.28, dampingFraction: 0.82), value: selectedIndex)"))
        XCTAssertTrue(source.contains(".onHover { isHovered in"))
        XCTAssertFalse(source.contains("Picker(\"Model\""))
        XCTAssertFalse(source.contains("Picker(\"Passes\""))
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

    func testOutputRetryIconKeepsCounterclockwiseGlyphAndRunsRecognition() throws {
        let source = try sourceFile("Sources/SnapTexApp/Views/CapturePreviewPane.swift")

        guard let iconRange = source.range(of: "systemName: \"arrow.counterclockwise\"") else {
            XCTFail("Retry icon should keep the counterclockwise glyph")
            return
        }

        let retryButtonSource = source[iconRange.lowerBound...].prefix(240)
        XCTAssertTrue(retryButtonSource.contains("help: \"Retry recognition\""))
        XCTAssertTrue(retryButtonSource.contains("isDisabled: !model.canRetry"))
        XCTAssertTrue(retryButtonSource.contains("model.retry()"))
        XCTAssertFalse(source.contains("model.resetRenderedPreviewZoom()"))
    }

    func testCaptureSurfaceDoesNotUseRecognizingGlowBorder() throws {
        let source = try sourceFile("Sources/SnapTexApp/Views/CapturePreviewPane.swift")

        XCTAssertFalse(source.contains("RecognitionGlowBorder"))
        XCTAssertFalse(source.contains(".repeatForever(autoreverses: false)"))
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
        XCTAssertFalse(historyView.contains("FolderColorPalette"))
        XCTAssertFalse(historyView.contains(".popover(isPresented: $isColorPickerPresented"))
        XCTAssertFalse(historyView.contains("Text(color.title)"))
        XCTAssertFalse(historyView.contains("Label(\"Change Folder Color\""))
    }

    func testFolderRowsUseArrowButtonsForReorderingInsteadOfDragging() throws {
        let historyView = try sourceFile("Sources/SnapTexApp/Views/HistorySidebarView.swift")

        XCTAssertTrue(historyView.contains("help: \"Move folder up\""))
        XCTAssertTrue(historyView.contains("help: \"Move folder down\""))
        XCTAssertTrue(historyView.contains("model.moveHistoryFolderUp(folder.id)"))
        XCTAssertTrue(historyView.contains("model.moveHistoryFolderDown(folder.id)"))
        XCTAssertTrue(historyView.contains("canMoveUp: index > 0"))
        XCTAssertTrue(historyView.contains("canMoveDown: index < folderRows.count - 1"))
        XCTAssertFalse(historyView.contains("DragGesture(minimumDistance: 5, coordinateSpace: .named(historyFoldersCoordinateSpace))"))
        XCTAssertFalse(historyView.contains("Image(systemName: \"line.3.horizontal\")"))
        XCTAssertFalse(historyView.contains(".help(\"Drag to reorder folders\")"))
        XCTAssertFalse(historyView.contains("FolderRowFramePreferenceKey"))
        XCTAssertFalse(historyView.contains("folderRowFrames"))
        XCTAssertFalse(historyView.contains("folderDropTarget(for:"))
        XCTAssertFalse(historyView.contains("isAnyFolderDragging"))
        XCTAssertFalse(historyView.contains("moveDroppedFolder"))
        XCTAssertFalse(historyView.contains("FolderInsertionIndicator"))
        XCTAssertFalse(historyView.contains("FolderDropTarget"))
        XCTAssertFalse(historyView.contains("FolderReorderDropDelegate"))
        XCTAssertFalse(historyView.contains("HistoryDragPayload.folder"))
        XCTAssertFalse(historyView.contains("folderDropMidpointY"))
        XCTAssertFalse(historyView.contains("lastReorderTargetID"))
    }

    func testHistoryRowsUseIconOnlyFolderBadge() throws {
        let historyView = try sourceFile("Sources/SnapTexApp/Views/HistorySidebarView.swift")

        XCTAssertTrue(historyView.contains("folderBadgeColor"))
        XCTAssertTrue(historyView.contains("\"folder.fill\""))
        XCTAssertFalse(historyView.contains("Label(folderLabel"))
        XCTAssertFalse(historyView.contains("let folderLabel: String?"))
    }

    func testHistoryRowsUseSnipCardTreatment() throws {
        let historyView = try sourceFile("Sources/SnapTexApp/Views/HistorySidebarView.swift")

        XCTAssertTrue(historyView.contains("private let historySidebarHorizontalPadding: CGFloat = 12"))
        XCTAssertFalse(historyView.contains("HistorySnipBadge("))
        XCTAssertFalse(historyView.contains("private struct HistorySnipBadge"))
        XCTAssertFalse(historyView.contains("Image(systemName: \"crop\")"))
        XCTAssertTrue(historyView.contains("AppTheme.historySnipBackground"))
        XCTAssertTrue(historyView.contains("AppTheme.historySelectedBackground"))
        XCTAssertTrue(historyView.contains(".opacity(0.72)"))
        XCTAssertTrue(historyView.contains("HistoryDepthCardHoverEffect"))
        XCTAssertTrue(historyView.contains("HistoryCardHoverTrackingArea"))
        XCTAssertTrue(historyView.contains("rotation3DEffect"))
        XCTAssertTrue(historyView.contains("hoverEffectProgress"))
        XCTAssertTrue(historyView.contains("isActive ? 0.28 : 1.15"))
        XCTAssertTrue(historyView.contains(".spring(response: 0.78, dampingFraction: 0.72, blendDuration: 0.18)"))
        XCTAssertTrue(historyView.contains("private var foilColorShift: some View"))
        XCTAssertTrue(historyView.contains("private var foilBanding: some View"))
        XCTAssertTrue(historyView.contains(".saturation(1.20)"))
        XCTAssertTrue(historyView.contains(".contrast(1.10)"))
        XCTAssertTrue(historyView.contains(".brightness(-0.030)"))
        XCTAssertTrue(historyView.contains("Color(red: 0.38, green: 0.74, blue: 1.00).opacity(0.070)"))
        XCTAssertTrue(historyView.contains("Color(red: 0.36, green: 0.72, blue: 0.86).opacity(0.048)"))
        XCTAssertTrue(historyView.contains(".blur(radius: 1.4)"))
        XCTAssertTrue(historyView.contains(".opacity(0.06)"))
        XCTAssertTrue(historyView.contains(".opacity(0.36)"))
        XCTAssertTrue(historyView.contains("x: hoverLocation.x - 0.86"))
        XCTAssertTrue(historyView.contains("x: hoverLocation.x + 0.86"))
        XCTAssertFalse(historyView.contains("private func foilPatternOverlay(in size: CGSize) -> some View"))
        XCTAssertFalse(historyView.contains("Canvas { context, canvasSize in"))
        XCTAssertFalse(historyView.contains("private func foilReflection(in size: CGSize) -> some View"))
        XCTAssertFalse(historyView.contains("private var holographicWash: some View"))
        XCTAssertFalse(historyView.contains("Color(red: 0.18, green: 0.96, blue: 0.76).opacity(0.078)"))
        XCTAssertFalse(historyView.contains("Color(red: 0.28, green: 0.82, blue: 1.00).opacity(0.092)"))
        XCTAssertFalse(historyView.contains(".brightness(-0.018)"))
        XCTAssertFalse(historyView.contains("Color(red: 1.00, green: 0.72, blue: 0.58).opacity(0.044)"))
        XCTAssertFalse(historyView.contains("Color.white.opacity(0.004)"))
        XCTAssertFalse(historyView.contains("Color.white.opacity(0.002)"))
        XCTAssertFalse(historyView.contains("Color.white.opacity(0.012)"))
        XCTAssertFalse(historyView.contains("Color.white.opacity(0.045)"))
        XCTAssertFalse(historyView.contains("Color.white.opacity(0.018)"))
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

    func testNewFoldersBeginRenamingAutomatically() throws {
        let historyView = try sourceFile("Sources/SnapTexApp/Views/HistorySidebarView.swift")

        XCTAssertTrue(historyView.contains("@State private var renamingFolderID: HistoryFolder.ID?"))
        XCTAssertTrue(historyView.contains("@Binding var renamingFolderID: HistoryFolder.ID?"))
        XCTAssertTrue(historyView.contains("renamingFolderID = folder.id"))
        XCTAssertTrue(historyView.contains("beginRenameIfRequested()"))
        XCTAssertTrue(historyView.contains(".onChange(of: renamingFolderID)"))
    }

    func testOnlyOneFolderRenameCanBeActiveAndSwitchingCommitsDraft() throws {
        let historyView = try sourceFile("Sources/SnapTexApp/Views/HistorySidebarView.swift")

        XCTAssertTrue(historyView.contains("saveRename(shouldClearRequestedRename: false)"))
        XCTAssertTrue(historyView.contains("if requestedID != folder.id, isRenaming"))
        XCTAssertTrue(historyView.contains("renamingFolderID = folder.id"))
        XCTAssertTrue(historyView.contains("private func saveRename(shouldClearRequestedRename: Bool = true)"))
    }

    func testSettingsTextSectionUsesSnapTitleAndLabelFontControls() throws {
        let settingsView = try sourceFile("Sources/SnapTexApp/Views/SettingsView.swift")
        let historyView = try sourceFile("Sources/SnapTexApp/Views/HistorySidebarView.swift")
        let contentView = try sourceFile("Sources/SnapTexApp/Views/ContentView.swift")
        let captureView = try sourceFile("Sources/SnapTexApp/Views/CapturePreviewPane.swift")
        let outputView = try sourceFile("Sources/SnapTexApp/Views/OutputPane.swift")

        XCTAssertTrue(settingsView.contains("SettingsFontRow("))
        XCTAssertTrue(settingsView.contains("title: \"History snap titles\""))
        XCTAssertTrue(settingsView.contains("description: \"Snap names in the History list\""))
        XCTAssertTrue(settingsView.contains("title: \"Sidebar labels\""))
        XCTAssertTrue(settingsView.contains("description: \"All Snaps, Folders, and folder names\""))
        XCTAssertTrue(settingsView.contains("title: \"Pane headings\""))
        XCTAssertTrue(settingsView.contains("description: \"History, Capture, Output, LaTeX\""))
        XCTAssertTrue(settingsView.contains("title: \"Toolbar controls\""))
        XCTAssertTrue(settingsView.contains("description: \"Model controls and status\""))
        XCTAssertTrue(settingsView.contains("title: \"Snip button\""))
        XCTAssertTrue(settingsView.contains("description: \"Main capture button text\""))
        XCTAssertTrue(settingsView.contains("title: \"Metadata text\""))
        XCTAssertTrue(settingsView.contains("description: \"Timestamps, counts, model info, and alternatives\""))
        XCTAssertTrue(settingsView.contains("title: \"LaTeX editor\""))
        XCTAssertTrue(settingsView.contains("labelFontSizeBinding"))
        XCTAssertTrue(settingsView.contains("paneTitleFontSizeBinding"))
        XCTAssertTrue(settingsView.contains("toolbarFontSizeBinding"))
        XCTAssertTrue(settingsView.contains("snipButtonFontSizeBinding"))
        XCTAssertTrue(settingsView.contains("metadataFontSizeBinding"))
        XCTAssertFalse(settingsView.contains("SettingsRow(\"History title\")"))
        XCTAssertFalse(settingsView.contains("SettingsRow(\"Snap title\")"))
        XCTAssertTrue(historyView.contains("labelFontSize: model.settings.labelFontSize"))
        XCTAssertTrue(historyView.contains("private var labelFont: Font"))
        XCTAssertTrue(historyView.contains("model.settings.paneTitleFontSize"))
        XCTAssertTrue(historyView.contains("metadataFontSize: model.settings.metadataFontSize"))
        XCTAssertTrue(contentView.contains("model.settings.toolbarFontSize"))
        XCTAssertTrue(contentView.contains("model.settings.snipButtonFontSize"))
        XCTAssertFalse(contentView.contains("private let snipButtonFontSize: CGFloat"))
        XCTAssertTrue(captureView.contains("model.settings.paneTitleFontSize"))
        XCTAssertTrue(captureView.contains("model.settings.metadataFontSize"))
        XCTAssertTrue(outputView.contains("model.settings.paneTitleFontSize"))
        XCTAssertTrue(outputView.contains("metadataFontSize: model.settings.metadataFontSize"))
    }

    func testSettingsFontRowsSupportTypingAndStepperAdjustment() throws {
        let settingsView = try sourceFile("Sources/SnapTexApp/Views/SettingsView.swift")

        XCTAssertTrue(settingsView.contains("TextField(\"\", value: $value, formatter: Self.fontSizeFormatter)"))
        XCTAssertTrue(settingsView.contains("Stepper(\"\", value: $value, in: 10...28, step: 1)"))
        XCTAssertTrue(settingsView.contains(".labelsHidden()"))
        XCTAssertTrue(settingsView.contains(".help(\"Increase or decrease by 1 pt\")"))
    }

    func testSettingsHistoryLimitSupportsUnlimitedAndStepperAdjustment() throws {
        let settingsView = try sourceFile("Sources/SnapTexApp/Views/SettingsView.swift")

        XCTAssertTrue(settingsView.contains("SettingsHistoryLimitRow("))
        XCTAssertTrue(settingsView.contains("Toggle(\"Unlimited\", isOn: $isUnlimited)"))
        XCTAssertTrue(settingsView.contains("private var limitControls: some View"))
        XCTAssertTrue(settingsView.contains("Text(\"Limited deletes oldest snaps beyond the limit. Unlimited keeps every snap.\")"))
        XCTAssertTrue(settingsView.contains("TextField(\"\", value: $limit, formatter: Self.historyLimitFormatter)"))
        XCTAssertTrue(settingsView.contains(".graphiteTextInput(width: 54)"))
        XCTAssertTrue(settingsView.contains("Stepper(\"\", value: $limit, in: 4...200, step: 1)"))
        XCTAssertTrue(settingsView.contains("Divider().frame(height: 18)"))
        XCTAssertTrue(settingsView.contains(".fixedSize(horizontal: true, vertical: false)"))
        XCTAssertTrue(settingsView.contains(".help(\"Increase or decrease by 1 item\")"))
        XCTAssertTrue(settingsView.contains(".disabled(isUnlimited)"))
    }

    func testSettingsExposeOpenAppShortcut() throws {
        let settingsView = try sourceFile("Sources/SnapTexApp/Views/SettingsView.swift")
        let appSource = try sourceFile("Sources/SnapTexApp/App/SnapTexApp.swift")

        XCTAssertTrue(settingsView.contains("SettingsRow(\"Open app\")"))
        XCTAssertTrue(settingsView.contains("ShortcutRecorderView(shortcut: $model.settings.openAppShortcut)"))
        XCTAssertTrue(appSource.contains("openAppHotKeyController"))
        XCTAssertTrue(appSource.contains("openMainWindow: @escaping () -> Void"))
        XCTAssertTrue(appSource.contains(".map(\\.openAppShortcut)"))
        XCTAssertTrue(appSource.contains("GlobalHotKeyController(hotKeyID: 2)"))
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

        XCTAssertTrue(historyView.contains("HistoryTextActionButton("))
        XCTAssertTrue(historyView.contains("title: \"Copy\""))
        XCTAssertTrue(historyView.contains("fontSize: metadataFontSize"))
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
        XCTAssertTrue(source.contains("WindowChromeConfigurator(hidesTitle: true, titlebarTitle: \"snaptex\")"))
        XCTAssertTrue(source.contains("configureWindowChrome(\n        window,\n        hidesTitle: title == \"snaptex\",\n        titlebarTitle: title == \"snaptex\" ? \"snaptex\" : nil\n    )"))
        XCTAssertTrue(source.contains(".windowStyle(.hiddenTitleBar)"))
        XCTAssertTrue(source.contains("configureTitlebarTitle(for: window, title: titlebarTitle)"))
        XCTAssertTrue(source.contains("NSTitlebarAccessoryViewController()"))
        XCTAssertTrue(source.contains("NSTextField(labelWithString: title)"))
        XCTAssertTrue(source.contains("window.removeTitlebarAccessoryViewController(at: index)"))
        XCTAssertFalse(source.contains("window.titlebarAccessoryViewControllers = window.titlebarAccessoryViewControllers.filter"))
        XCTAssertFalse(source.contains("MainWindowTitlebar()"))
        XCTAssertTrue(source.contains("minSize: NSSize("))
        XCTAssertTrue(source.contains("width: AppLayoutMetrics.mainWindowMinWidth"))
        XCTAssertTrue(source.contains("height: AppLayoutMetrics.mainWindowMinHeight"))
        XCTAssertTrue(source.contains("window.contentMinSize = minSize"))
        XCTAssertTrue(source.contains("window.setContentSize(clampedContentSize)"))
        XCTAssertTrue(source.contains("window.backgroundColor = AppTheme.windowBackgroundNSColor"))
        XCTAssertTrue(source.contains("window.titlebarAppearsTransparent = true"))
        XCTAssertTrue(source.contains("window.styleMask.insert(.fullSizeContentView)"))
        XCTAssertTrue(source.contains("window.titlebarSeparatorStyle = .none"))
        XCTAssertTrue(source.contains("window.contentView?.layer?.backgroundColor = AppTheme.windowBackgroundNSColor.cgColor"))
        XCTAssertTrue(source.contains("window.titleVisibility = hidesTitle ? .hidden : .visible"))
        XCTAssertTrue(source.contains("configureTitlebarBackground(for: window)"))
        XCTAssertTrue(source.contains("window.standardWindowButton(.closeButton)?.superview?.superview"))
    }

    func testMainWindowPaintsGraphiteBackgroundBehindTransparentTitlebar() throws {
        let source = try sourceFile("Sources/SnapTexApp/App/SnapTexApp.swift")

        XCTAssertTrue(source.contains("ZStack {\n                AppTheme.windowBackground.ignoresSafeArea()"))
        XCTAssertTrue(source.contains("ContentView(model: model)"))
        XCTAssertTrue(source.contains("WindowChromeConfigurator(hidesTitle: true, titlebarTitle: \"snaptex\")"))
        XCTAssertTrue(source.contains("AppLayoutMetrics.mainWindowTitlebarHeight"))
        XCTAssertTrue(source.contains("AppLayoutMetrics.mainWindowTitlebarTitleWidth"))
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
        XCTAssertTrue(source.contains("configureWindowChrome(window)"))
    }

    func testSettingsWindowLeavesRoomForDownloadingModelRowsAndResizableLogs() throws {
        let settingsView = try sourceFile("Sources/SnapTexApp/Views/SettingsView.swift")

        XCTAssertGreaterThanOrEqual(AppLayoutMetrics.settingsWindowMinWidth, 960)
        XCTAssertGreaterThanOrEqual(AppLayoutMetrics.settingsWindowIdealWidth, 1_080)
        XCTAssertGreaterThanOrEqual(AppLayoutMetrics.settingsControlsPaneMinWidth, 430)
        XCTAssertGreaterThanOrEqual(AppLayoutMetrics.settingsLogsPaneMinWidth, 460)
        XCTAssertGreaterThanOrEqual(AppLayoutMetrics.settingsModelTitleMinWidth, 104)
        XCTAssertTrue(settingsView.contains("HSplitView"))
        XCTAssertTrue(settingsView.contains("AppLayoutMetrics.settingsControlsPaneMinWidth"))
        XCTAssertTrue(settingsView.contains("AppLayoutMetrics.settingsLogsPaneMinWidth"))
        XCTAssertTrue(settingsView.contains("AppLayoutMetrics.settingsModelTitleMinWidth"))
    }

    func testSettingsTextInputsUseGraphiteChromeInsteadOfNativeRoundedBorder() throws {
        let settingsView = try sourceFile("Sources/SnapTexApp/Views/SettingsView.swift")
        let theme = try sourceFile("Sources/SnapTexApp/Support/AppTheme.swift")

        XCTAssertTrue(theme.contains("GraphiteTextInputModifier"))
        XCTAssertTrue(settingsView.contains(".graphiteTextInput(width: 54)"))
        XCTAssertTrue(settingsView.contains(".graphiteTextInput(width: 76, background: AppTheme.windowBackground)"))
        XCTAssertFalse(settingsView.contains(".textFieldStyle(.roundedBorder)"))
    }

    func testSettingsCanRevealModelFilesInFinder() throws {
        let source = try sourceFile("Sources/SnapTexApp/Views/SettingsView.swift")

        XCTAssertTrue(source.contains("model.revealModelFilesInFinder(variant)"))
        XCTAssertTrue(source.contains("folder"))
        XCTAssertTrue(source.contains("Reveal local"))
    }

    func testSettingsGroupsModelsByProviderWithRepositoryLinks() throws {
        let source = try sourceFile("Sources/SnapTexApp/Views/SettingsView.swift")
        let uniMERNetRange = try XCTUnwrap(source.range(of: ".uniMERNet"))
        let paddlePaddleRange = try XCTUnwrap(source.range(of: ".paddlePaddle"))

        XCTAssertTrue(source.contains("ModelProviderSubsection(provider: provider)"))
        XCTAssertTrue(source.contains("Link(destination: provider.repositoryURL)"))
        XCTAssertTrue(source.contains("Text(provider.title)"))
        XCTAssertTrue(source.contains("Image(systemName: \"arrow.up.right\")"))
        XCTAssertTrue(source.contains(".offset(x: isHeaderHovered ? 1 : 0, y: isHeaderHovered ? -1 : 0)"))
        XCTAssertTrue(source.contains("@State private var isHeaderHovered = false"))
        XCTAssertTrue(source.contains(".onHover { isHeaderHovered = $0 }"))
        XCTAssertTrue(source.contains(".animation(.easeOut(duration: 0.14), value: isHeaderHovered)"))
        XCTAssertTrue(source.contains("private var accentColor: Color"))
        XCTAssertTrue(source.contains(".font(.caption.weight(.semibold))"))
        XCTAssertFalse(source.contains(".fill(accentColor.opacity(isHeaderHovered"))
        XCTAssertFalse(source.contains("AppTheme.raisedPanelBackground.opacity(isHeaderHovered"))
        XCTAssertFalse(source.contains(".offset(x: isHeaderHovered ? 2 : 0, y: isHeaderHovered ? -2 : 0)"))
        XCTAssertTrue(source.contains(".paddlePaddle"))
        XCTAssertTrue(source.contains(".uniMERNet"))
        XCTAssertLessThan(uniMERNetRange.lowerBound, paddlePaddleRange.lowerBound)
    }

    func testSettingsSelectedModelUsesSoftFillAndAccentMarker() throws {
        let source = try sourceFile("Sources/SnapTexApp/Views/SettingsView.swift")

        XCTAssertTrue(source.contains("RoundedRectangle(cornerRadius: 2)"))
        XCTAssertTrue(source.contains(".fill(providerAccentColor)"))
        XCTAssertTrue(source.contains("isSelected ? selectedModelFill : Color.clear"))
        XCTAssertTrue(source.contains("private var selectedModelFill: Color"))
        XCTAssertTrue(source.contains("Color.white.opacity(0.075)"))
        XCTAssertFalse(source.contains("providerAccentColor.opacity(0.14)"))
        XCTAssertTrue(source.contains(".animation(.easeOut(duration: 0.14), value: isSelected)"))
        XCTAssertFalse(source.contains("strokeBorder(selectedModel"))
    }

    func testSettingsModelRowsUseLowContrastSeparators() throws {
        let source = try sourceFile("Sources/SnapTexApp/Views/SettingsView.swift")

        XCTAssertTrue(source.contains("ModelRowSeparator()"))
        XCTAssertTrue(source.contains("Color.white.opacity(0.045)"))
        XCTAssertFalse(source.contains("Divider().padding(.vertical, 2)"))
    }

    func testSettingsModelRowIconButtonsAnimateHover() throws {
        let source = try sourceFile("Sources/SnapTexApp/Views/SettingsView.swift")

        XCTAssertTrue(source.contains("SettingsIconActionButton("))
        XCTAssertTrue(source.contains("systemImage: \"folder\""))
        XCTAssertTrue(source.contains("systemImage: \"trash\""))
        XCTAssertTrue(source.contains("@State private var isHovered = false"))
        XCTAssertTrue(source.contains(".onHover { isHovered = $0 }"))
        XCTAssertTrue(source.contains(".animation(.easeOut(duration: 0.12), value: isHovered)"))
        XCTAssertTrue(source.contains("isDownloadBlocked: model.isModelDownloadBlocked(for: variant)"))
        XCTAssertTrue(source.contains("isDownloadBlocked ||"))
        XCTAssertTrue(source.contains("(isSelected && state.isInstalled)"))
        XCTAssertFalse(source.contains(".disabled(!variant.requiresManagedFiles"))
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
        XCTAssertGreaterThanOrEqual(settingsWindow?.contentMinSize.width ?? 0, AppLayoutMetrics.settingsWindowMinWidth)
        XCTAssertGreaterThanOrEqual(settingsWindow?.contentMinSize.height ?? 0, AppLayoutMetrics.settingsWindowMinHeight)

        SettingsWindowPresenter.closeForTesting()
    }

    private func sourceFile(_ path: String) throws -> String {
        try String(
            contentsOf: try Self.sourceRoot().appendingPathComponent(path),
            encoding: .utf8
        )
    }

    private func viewSource(named viewName: String, in source: String) throws -> Substring {
        guard let start = source.range(of: "private struct \(viewName)")?.lowerBound else {
            throw XCTSkip("Missing view source for \(viewName)")
        }
        let remainder = source[start...]
        let nextView = remainder.range(of: "\nprivate struct ", options: [], range: remainder.index(after: start)..<remainder.endIndex)
        return remainder[..<(nextView?.lowerBound ?? remainder.endIndex)]
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
