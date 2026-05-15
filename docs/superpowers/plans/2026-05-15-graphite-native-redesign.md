# Graphite Native Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restyle snaptex into the approved dark Graphite Native direction while preserving all existing OCR behavior and the Snip icon.

**Architecture:** Keep the existing SwiftUI view structure and add a small shared style support file for graphite colors, surfaces, and button styles. Apply those styles to the main window, history, capture/preview, output, and settings without changing model APIs or workflow.

**Tech Stack:** SwiftPM, SwiftUI, AppKit-hosted macOS app, XCTest.

---

## File Structure

- Create `Sources/SnapTexApp/Support/AppTheme.swift`: shared graphite colors, reusable surfaces, section headers, and button styles.
- Modify `Sources/SnapTexApp/Views/ContentView.swift`: graphite app background, toolbar surface, and toolbar control styling.
- Modify `Sources/SnapTexApp/Views/HistorySidebarView.swift`: graphite sidebar, selected row, thumbnail, and action button styling.
- Modify `Sources/SnapTexApp/Views/CapturePreviewPane.swift`: graphite capture and rendered preview surfaces.
- Modify `Sources/SnapTexApp/Views/OutputPane.swift`: graphite editor, output format menu, and alternatives styling.
- Modify `Sources/SnapTexApp/Views/SettingsView.swift`: matching graphite settings sections and logs panel.
- Modify `Tests/SnapTexAppTests/AppLayoutMetricsTests.swift`: add a source-level regression check that the Snip button still uses a `Label` with the `crop` icon.

### Task 1: Theme Support

**Files:**
- Create: `Sources/SnapTexApp/Support/AppTheme.swift`

- [ ] **Step 1: Add shared theme support**

Create a small support file with graphite colors and reusable SwiftUI styles:

```swift
import SwiftUI

enum AppTheme {
    static let windowBackground = Color(red: 0.067, green: 0.075, blue: 0.090)
    static let panelBackground = Color(red: 0.090, green: 0.102, blue: 0.122)
    static let raisedPanelBackground = Color(red: 0.110, green: 0.125, blue: 0.149)
    static let insetBackground = Color(red: 0.055, green: 0.063, blue: 0.075)
    static let border = Color.white.opacity(0.085)
    static let selectedBorder = Color.white.opacity(0.20)
    static let primaryForeground = Color(red: 0.067, green: 0.075, blue: 0.090)
    static let quietText = Color.white.opacity(0.58)

    static let panelCornerRadius: CGFloat = 8
}

struct GraphitePanelModifier: ViewModifier {
    var background: Color = AppTheme.panelBackground
    var border: Color = AppTheme.border

    func body(content: Content) -> some View {
        content
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.panelCornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.panelCornerRadius)
                    .strokeBorder(border, lineWidth: 1)
            }
    }
}

extension View {
    func graphitePanel(
        background: Color = AppTheme.panelBackground,
        border: Color = AppTheme.border
    ) -> some View {
        modifier(GraphitePanelModifier(background: background, border: border))
    }
}
```

- [ ] **Step 2: Run a build check**

Run: `swift build --product snaptex`

Expected: PASS.

### Task 2: Toolbar And Main Window

**Files:**
- Modify: `Sources/SnapTexApp/Views/ContentView.swift`

- [ ] **Step 1: Apply the graphite window and toolbar**

Wrap the main content in the graphite background and give the toolbar a grouped surface:

```swift
VStack(spacing: 0) {
    ToolbarView(model: model)
        .padding(.vertical, 10)
        .padding(.leading, AppLayoutMetrics.toolbarLeadingPadding)
        .padding(.trailing, AppLayoutMetrics.outputPaneContentPadding)
        .background(AppTheme.panelBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 1)
        }
    HSplitView { ... }
}
.background(AppTheme.windowBackground)
```

Keep `SnipButton` as a `Label("Snip", systemImage: "crop")`; only change its button style.

- [ ] **Step 2: Add toolbar button styles**

Use a light primary Snip style and subdued secondary bordered controls. The Snip label must remain:

```swift
Label("Snip", systemImage: "crop")
```

- [ ] **Step 3: Run the Snip icon regression test after Task 6 adds it**

Run: `swift test --filter AppLayoutMetricsTests/testSnipButtonKeepsCropIcon`

Expected after Task 6: PASS.

### Task 3: Main Pane Styling

**Files:**
- Modify: `Sources/SnapTexApp/Views/HistorySidebarView.swift`
- Modify: `Sources/SnapTexApp/Views/CapturePreviewPane.swift`
- Modify: `Sources/SnapTexApp/Views/OutputPane.swift`

- [ ] **Step 1: Style history**

Add the graphite sidebar background, selected row border, and quieter empty state. Keep all row actions and callbacks unchanged.

- [ ] **Step 2: Style capture and preview**

Use `graphitePanel` for the capture and rendered preview containers. Keep drag/drop behavior and zoom controls unchanged.

- [ ] **Step 3: Style output**

Use graphite surfaces for the editor, output format menu, empty alternatives state, and alternative rows. Keep the `TextEditor`, format menu actions, and alternative application behavior unchanged.

- [ ] **Step 4: Run app tests**

Run: `swift test --filter SnapTexAppTests`

Expected: PASS.

### Task 4: Settings Styling

**Files:**
- Modify: `Sources/SnapTexApp/Views/SettingsView.swift`

- [ ] **Step 1: Apply graphite section styling**

Use the shared graphite panel styling for settings sections and the logs pane. Keep controls, bindings, and deletion alerts unchanged.

- [ ] **Step 2: Build after settings changes**

Run: `swift build --product snaptex`

Expected: PASS.

### Task 5: Regression Test

**Files:**
- Modify: `Tests/SnapTexAppTests/AppLayoutMetricsTests.swift`

- [ ] **Step 1: Add source-level Snip icon test**

Add a test that reads `ContentView.swift` and verifies the Snip label keeps the `crop` icon:

```swift
func testSnipButtonKeepsCropIcon() throws {
    let testFile = URL(fileURLWithPath: #filePath)
    let sourceRoot = testFile
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let source = try String(
        contentsOf: sourceRoot.appendingPathComponent("Sources/SnapTexApp/Views/ContentView.swift"),
        encoding: .utf8
    )

    XCTAssertTrue(source.contains("Label(\"Snip\", systemImage: \"crop\")"))
}
```

- [ ] **Step 2: Run the new test**

Run: `swift test --filter AppLayoutMetricsTests/testSnipButtonKeepsCropIcon`

Expected: PASS.

### Task 6: Full Verification And Rebuild

**Files:**
- No source edits unless verification exposes a focused issue.

- [ ] **Step 1: Run full tests**

Run: `swift test`

Expected: PASS.

- [ ] **Step 2: Rebuild installed app in place**

Run: `./scripts/build_and_run.sh --verify`

Expected: PASS and `/Applications/snaptex.app` is updated in place with the existing bundle id.

- [ ] **Step 3: Inspect installed bundle id**

Run: `/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' /Applications/snaptex.app/Contents/Info.plist`

Expected: `dev.snaptex.app` unless the user has configured `SNAPTEX_BUNDLE_ID`.
