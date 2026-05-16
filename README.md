<p align="center">
  <img src="Sources/SnapTexApp/Resources/logo.png" width="92" alt="snaptex logo">
</p>

<h1 align="center">snaptex</h1>

<p align="center">
  Native macOS LaTeX OCR for turning equation screenshots into editable LaTeX.
</p>

<p align="center">
  <img alt="macOS 13+" src="https://img.shields.io/badge/macOS-13%2B-111111">
  <img alt="SwiftPM" src="https://img.shields.io/badge/SwiftPM-ready-f05138">
  <img alt="OCR models" src="https://img.shields.io/badge/OCR-UniMERNet%20%2B%20PaddlePaddle-2f6fed">
</p>

## What it does

SnapTex runs locally on macOS. Capture an equation, choose a UniMERNet or PaddlePaddle model size, then copy the LaTeX or export the rendered formula.

## Install

Requirements: macOS 13+, Xcode Command Line Tools, and Miniforge or Conda.

```bash
xcode-select --install
./scripts/setup_snaptex_env.sh
./scripts/build_and_run.sh
```

The setup script creates a dedicated `snaptex` conda environment, installs UniMERNet plus PaddleOCR runtime dependencies, and downloads the default UniMERNet model into snaptex's macOS Application Support directory.

Optional environment variables:

- `SNAPTEX_ENV_NAME`: conda environment name
- `SNAPTEX_UNIMERNET_DIR`: custom UniMERNet model directory
- `SNAPTEX_UNIMERNET_RUNTIME_DIR`: custom UniMERNet runtime checkout directory
- `SNAPTEX_MODEL_SIZE`: `s`, `m`, or `l`

The legacy `SNAPTEX_MODEL_VARIANT` values `tiny`, `small`, and `base` still work.

## Credit

OCR is powered by [OpenDataLab UniMERNet](https://github.com/opendatalab/UniMERNet) and [PaddlePaddle](https://github.com/PaddlePaddle), including [PP-FormulaNet_plus](https://huggingface.co/PaddlePaddle/PP-FormulaNet_plus-L).
