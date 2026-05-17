<p align="center">
  <img src="Sources/SnapTexApp/Resources/logo.png" width="180" alt="SnapTex logo">
</p>

<h1 align="center">SnapTex</h1>

<p align="center">
  Native macOS LaTeX OCR for turning equation screenshots into editable, rendered, and exportable LaTeX.
</p>

<p align="center">
  <img alt="macOS 13+" src="https://img.shields.io/badge/macOS-13%2B-111111">
  <img alt="SwiftPM" src="https://img.shields.io/badge/SwiftPM-ready-f05138">
  <img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-0f766e">
  <img alt="OCR: UniMERNet and PaddleOCR" src="https://img.shields.io/badge/OCR-UniMERNet%20%2B%20PaddleOCR-2f6fed">
</p>

## Overview

SnapTex is a local macOS app for capturing equations and converting them into LaTeX. It combines a native SwiftUI interface with Python OCR workers, model management, rendered previews, and a persistent recognition history.

The app is designed for fast desktop workflows: snip an equation, review the OCR result, choose an alternative when available, copy the LaTeX, or export the rendered formula.

## Features

- Native macOS app with menu bar access and configurable global shortcuts.
- Local OCR using formula recognition models from UniMERNet and PaddleOCR.
- Small, medium, and large model variants with in-app download and deletion controls.
- Editable LaTeX output with syntax highlighting and rendered MathJax preview.
- Recognition alternatives, output formatting, and automatic copy support.
- Formula export from the rendered preview.
- Persistent history with folders, sorting, limits, and stored capture images.
- Settings and logs for model paths, output behavior, shortcuts, typography, and runtime diagnostics.

## Requirements

- macOS 13 or later.
- Xcode Command Line Tools.
- Miniforge, Miniconda, Anaconda, or another `conda` installation.
- A local code-signing identity for stable macOS permissions, or explicit ad-hoc signing for disposable development builds.

## Setup

Install command line tools if they are not already available:

```bash
xcode-select --install
```

Create the Python OCR environment, install runtime dependencies, clone UniMERNet, and download the default model:

```bash
./scripts/setup_snaptex_env.sh
```

The setup script creates a dedicated `snaptex` conda environment and stores managed UniMERNet files under:

```text
~/Library/Application Support/snaptex
```

## Build And Run

Package, sign, install, and launch the app:

```bash
./scripts/build_and_run.sh
```

For a local development machine without a configured signing identity:

```bash
SNAPTEX_ALLOW_ADHOC_SIGNING=1 ./scripts/build_and_run.sh
```

The build output is created in `dist/` and installed as `/Applications/snaptex.app`.

## Configuration

Environment variables accepted by the setup and build scripts:

| Variable | Purpose |
| --- | --- |
| `SNAPTEX_ENV_NAME` | Conda environment name. Defaults to `snaptex`. |
| `SNAPTEX_MODEL_SIZE` | Default model size: `s`, `m`, or `l`. Defaults to `m`. |
| `SNAPTEX_UNIMERNET_DIR` | Managed UniMERNet model directory. |
| `SNAPTEX_UNIMERNET_RUNTIME_DIR` | UniMERNet runtime checkout directory. |
| `SNAPTEX_APP_SUPPORT_DIR` | Application support directory for managed files. |
| `SNAPTEX_SIGN_IDENTITY` | Code-signing identity used by `build_and_run.sh`. |
| `SNAPTEX_BUNDLE_ID` | Bundle identifier for packaged builds. |
| `SNAPTEX_ALLOW_ADHOC_SIGNING` | Set to `1` to allow ad-hoc signing. |

Legacy `SNAPTEX_MODEL_VARIANT` values `tiny`, `small`, and `base` are still accepted by the setup script.

## Project Layout

```text
Sources/SnapTexApp/      SwiftUI macOS app, views, app state, services, and resources
Sources/SnapTexCore/     Shared recognition models, formatting, worker protocol, and support code
python/snaptex_worker/   Python OCR worker used by the macOS app
scripts/                 Environment setup, model download, packaging, and app icon tooling
Tests/                   Swift and Python test coverage
```

## Credits

SnapTex uses formula recognition models provided by [opendatalab/UniMERNet](https://github.com/opendatalab/UniMERNet) and [PaddlePaddle/PaddleOCR](https://github.com/PaddlePaddle/PaddleOCR). [MathJax](https://www.mathjax.org/) is bundled locally to render LaTeX previews and formula exports inside the macOS app. Third-party projects and model assets retain their own licenses.

## License

SnapTex is released under the [MIT License](LICENSE).
