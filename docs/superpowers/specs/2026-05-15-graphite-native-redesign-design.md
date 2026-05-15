# Graphite Native Redesign Design

## Goal

Make snaptex feel more polished while staying minimal and native. The selected direction is Graphite Native: dark graphite surfaces, quiet contrast, subtle borders, and no decorative blue gradients or AI-style glow.

## Scope

- Restyle the main window without changing the History / Capture / Rendered Output / LaTeX workflow.
- Restyle settings so it matches the main app.
- Keep all existing actions, settings, keyboard shortcuts, OCR behavior, history behavior, and output formatting semantics.
- Keep the existing Snip button icon next to its label.
- Rebuild by updating `/Applications/snaptex.app` in place through the existing build script so the bundle id remains unchanged.

## Visual Design

The app uses a restrained graphite palette:

- Window background: near-black graphite.
- Pane surfaces: slightly raised dark graphite panels.
- Borders: low-contrast graphite strokes for separation.
- Primary action: a light native-feeling Snip button with the current icon and label.
- Selected history item: stronger surface plus border, not a bright color wash.
- Empty states: quieter icons and text, styled consistently with the panes.

The design should avoid blue gradients, decorative glow, oversized marketing-style elements, and broad layout changes.

## Components

- `ContentView` and toolbar: apply the dark graphite window background, grouped toolbar styling, and polished controls while preserving the current buttons and model/pass pickers.
- `HistorySidebarView`: add consistent dark sidebar surface, polished selected row styling, and refined thumbnails.
- `CapturePreviewPane`: apply graphite panels to capture and rendered preview surfaces, keeping drop behavior and zoom controls unchanged.
- `OutputPane`: apply graphite editor and alternatives styling, preserving the output format menu and editor behavior.
- `SettingsView`: update sections, logs, rows, and model management surfaces to match the graphite style.
- Shared styling should be kept small and local, likely in a compact support file or view modifiers if it reduces duplication without introducing broad abstraction.

## Testing And Verification

- Run the Swift test suite after changes.
- Rebuild with `./scripts/build_and_run.sh` so `/Applications/snaptex.app` is updated in place.
- Verify the app launches after rebuild.
- Visually inspect the rebuilt app for the selected Graphite Native direction and confirm the Snip button still includes its icon.
