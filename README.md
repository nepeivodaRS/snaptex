<p align="center">
  <img src="Sources/SnapTexApp/Resources/logo.png" width="180" alt="SnapTex logo">
</p>

<h1 align="center">SnapTex</h1>

<p align="center">
  Native macOS LaTeX OCR for turning equation screenshots into clean, editable LaTeX.
</p>

<p align="center">
  <img alt="macOS 13+" src="https://img.shields.io/badge/macOS-13%2B-111111">
  <img alt="SwiftPM" src="https://img.shields.io/badge/SwiftPM-ready-f05138">
  <img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-0f766e">
  <img alt="OCR: UniMERNet and PaddleOCR" src="https://img.shields.io/badge/OCR-UniMERNet%20%2B%20PaddleOCR-2f6fed">
</p>

## Overview

SnapTex is a local macOS app for capturing equations from your screen and converting them into LaTeX. It pairs a native SwiftUI interface with local Python OCR workers, rendered previews, copy-ready output, and a lightweight recognition history.

## Core Features

- Capture an equation region with the Snip button or global shortcut.
- Paste or drag an equation image into the app.
- Edit, preview, copy, and format the recognized LaTeX.
- Export the rendered formula as PNG or EPS.
- Keep recent recognitions in a persistent history.
- Manage local OCR models from inside the app.

## Models

SnapTex supports local formula recognition with:

- [UniMERNet](https://github.com/opendatalab/UniMERNet): [tiny](https://huggingface.co/wanderkid/unimernet_tiny), [small](https://huggingface.co/wanderkid/unimernet_small), and [base](https://huggingface.co/wanderkid/unimernet_base).
- [PaddleOCR PP-FormulaNet_plus](https://github.com/PaddlePaddle/PaddleOCR): [S](https://huggingface.co/PaddlePaddle/PP-FormulaNet_plus-S), [M](https://huggingface.co/PaddlePaddle/PP-FormulaNet_plus-M), and [L](https://huggingface.co/PaddlePaddle/PP-FormulaNet_plus-L).

Missing models can be downloaded from the app when you select them.

## Install

Requirements:

- macOS 13 or later.
- Xcode Command Line Tools.
- Miniforge, Miniconda, Anaconda, or another `conda` installation.

Install command line tools if needed:

```bash
xcode-select --install
```

Prepare the OCR environment and default model:

```bash
./scripts/setup_snaptex_env.sh
```

Build, install, and launch SnapTex:

```bash
./scripts/build_and_run.sh
```

If you do not have a local signing identity yet, use an ad-hoc development build:

```bash
SNAPTEX_ALLOW_ADHOC_SIGNING=1 ./scripts/build_and_run.sh
```

The app is installed as:

```text
/Applications/snaptex.app
```

By default, setup-managed OCR files live under:

```text
~/Library/Application Support/snaptex
```

## Development

```bash
swift test
python -m pytest python/tests
```

## Credits

SnapTex uses [UniMERNet](https://github.com/opendatalab/UniMERNet), [PaddleOCR](https://github.com/PaddlePaddle/PaddleOCR), and [MathJax](https://www.mathjax.org/). Third-party code, models, and assets retain their own licenses.

## License

SnapTex is released under the [MIT License](LICENSE).
