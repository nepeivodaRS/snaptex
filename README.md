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

## Install on macOS

Requirements: macOS 13+, Xcode Command Line Tools, and Miniforge or Conda.

```bash
xcode-select --install
./scripts/setup_snaptex_env.sh
./scripts/build_and_run.sh
```

The setup script creates a dedicated `snaptex` conda environment, installs UniMERNet plus PaddleOCR runtime dependencies, and downloads the default UniMERNet model into snaptex's macOS Application Support directory. Advanced installs can set `SNAPTEX_ENV_NAME`, `SNAPTEX_UNIMERNET_DIR`, or `SNAPTEX_MODEL_SIZE` (`s`, `m`, or `l`) before running the script. The legacy `SNAPTEX_MODEL_VARIANT` values `tiny`, `small`, and `base` still work.

## Credit

OCR is powered by [opendatalab/UniMERNet](https://github.com/opendatalab/UniMERNet) and PaddlePaddle's [PP-FormulaNet_plus](https://huggingface.co/PaddlePaddle/PP-FormulaNet_plus-L) models.
