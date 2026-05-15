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
  <img alt="UniMERNet" src="https://img.shields.io/badge/OCR-UniMERNet-2f6fed">
</p>

## Install on macOS

Requirements: macOS 13+, Xcode Command Line Tools, and Miniforge or Conda.

```bash
xcode-select --install
./scripts/setup_unimernet_env.sh
./scripts/build_and_run.sh
```

The setup script creates a `snaptex` conda environment, clones UniMERNet into `~/Library/Application Support/snaptex/UniMERNet`, and downloads the `small` model. Override with `ENV_NAME`, `UNIMERNET_DIR`, or `MODEL_VARIANT`.

## Develop

```bash
swift test
PYTHONPATH=python conda run -n snaptex python -m unittest discover python/tests
```

## Credit

OCR is powered by [opendatalab/UniMERNet](https://github.com/opendatalab/UniMERNet).
