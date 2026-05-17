<p align="center">
  <img src="Sources/SnapTexApp/Resources/logo.png" width="180" alt="SnapTex logo">
</p>

<h1 align="center">SnapTex</h1>

<p align="center">
  A native macOS workspace for turning equation screenshots into clean, editable LaTeX.
</p>

<p align="center">
  <img alt="macOS 13+" src="https://img.shields.io/badge/macOS-13%2B-111111">
  <img alt="SwiftPM" src="https://img.shields.io/badge/SwiftPM-ready-f05138">
  <img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-0f766e">
  <img alt="OCR: UniMERNet and PaddleOCR" src="https://img.shields.io/badge/OCR-UniMERNet%20%2B%20PaddleOCR-2f6fed">
</p>

## What It Does

SnapTex captures formulas from your screen, runs local OCR through a Python worker, and gives you LaTeX you can edit, preview, copy, organize, and export.

It is built as a SwiftUI macOS app with a restrained graphite interface, a persistent history sidebar, configurable shortcuts, local MathJax rendering, and managed OCR models from UniMERNet and PaddlePaddle.

## Highlights

- Snip, paste, drag, or add an image from Finder.
- Choose UniMERNet or PaddlePaddle models in small, medium, or large sizes.
- Download, reveal, and delete model files from the app.
- Run one, two, or three OCR passes when the selected model supports alternatives.
- Edit LaTeX with syntax highlighting and live rendered preview validation.
- Copy raw, inline, display, or `equation` formatted output.
- Export rendered formulas as transparent PNG or EPS.
- Keep a persistent recognition history with folders, sorting, thumbnails, retries, and per-item output settings.

## Requirements

- macOS 13 or later.
- Xcode Command Line Tools.
- Miniforge, Miniconda, Anaconda, or another `conda` installation.
- A stable local code-signing identity for regular development builds. Ad-hoc signing is supported for disposable builds, but macOS permissions may need to be regranted after rebuilds.

Install the Xcode Command Line Tools if needed:

```bash
xcode-select --install
```

## Quick Start

Prepare the Python OCR environment and default UniMERNet model:

```bash
./scripts/setup_snaptex_env.sh
```

Build, sign, install, and launch the app:

```bash
./scripts/build_and_run.sh
```

For a local throwaway build without a configured signing identity:

```bash
SNAPTEX_ALLOW_ADHOC_SIGNING=1 ./scripts/build_and_run.sh
```

The packaged app is written to `dist/snaptex.app` and installed as `/Applications/snaptex.app`.

## Setup Details

`scripts/setup_snaptex_env.sh` prepares the OCR side of the project. By default, it:

- creates or reuses a conda environment named `snaptex` with Python 3.10;
- installs PaddlePaddle, PaddleOCR, and the Python requirements in `python/requirements.txt`;
- clones the UniMERNet runtime into `~/Library/Application Support/snaptex/UniMERNet/runtime`;
- downloads the default UniMERNet `m` model into `~/Library/Application Support/snaptex/UniMERNet/models`.

Those locations are defaults, not hard-coded project assumptions. Use the environment variables below when you want a different conda environment, model directory, or UniMERNet checkout.

PaddlePaddle model files are downloaded on demand by the app and stored under the configured PaddlePaddle model root.

## Build Script

`scripts/build_and_run.sh` builds the SwiftPM executable, packages the macOS bundle, copies the bundled Python worker and MathJax resource, optionally bundles a usable UniMERNet runtime checkout, signs the app, installs it in `/Applications`, and launches it.

Supported modes:

```bash
./scripts/build_and_run.sh run
./scripts/build_and_run.sh debug
./scripts/build_and_run.sh logs
./scripts/build_and_run.sh telemetry
./scripts/build_and_run.sh verify
```

## Configuration

Common environment variables:

| Variable | Used by | Purpose |
| --- | --- | --- |
| `CONDA_EXE` | setup, app defaults | Explicit path to `conda` when it is not discoverable. |
| `SNAPTEX_ENV_NAME` | setup | Conda environment name. Defaults to `snaptex`. |
| `SNAPTEX_MODEL_SIZE` | setup | Default UniMERNet model size to download: `s`, `m`, or `l`. Defaults to `m`. |
| `SNAPTEX_APP_SUPPORT_DIR` | setup | Base directory for setup-managed files. Defaults to `~/Library/Application Support/snaptex`. |
| `SNAPTEX_UNIMERNET_DIR` | setup, app defaults | UniMERNet model root. Defaults to `~/Library/Application Support/snaptex/UniMERNet`. |
| `SNAPTEX_UNIMERNET_RUNTIME_DIR` | setup, build, app runtime | UniMERNet runtime checkout containing `unimernet/` and `configs/val/`. |
| `SNAPTEX_PADDLEPADDLE_DIR` | app defaults | PaddlePaddle model root. Defaults to `~/Library/Application Support/snaptex/PaddlePaddle`. |
| `SNAPTEX_SIGN_IDENTITY` | build | Code-signing identity for packaged builds. |
| `SNAPTEX_BUNDLE_ID` | build | Bundle identifier for packaged builds. Defaults to the installed app's bundle id, then `dev.snaptex.app`. |
| `SNAPTEX_ALLOW_ADHOC_SIGNING` | build | Set to `1` to allow explicit ad-hoc signing. |
| `SNAPTEX_ALLOW_BUNDLE_ID_MISMATCH` | build | Set to `1` to overwrite an installed app with a different bundle id. |

Legacy UniMERNet size names `tiny`, `small`, and `base` are still accepted by the setup script.

## Project Layout

```text
Sources/SnapTexApp/      SwiftUI macOS app, views, stores, services, and bundled resources
Sources/SnapTexCore/     Shared models, OCR worker protocol, formatting, validation, and support code
python/snaptex_worker/   JSON-lines Python OCR worker and model downloader
scripts/                 Setup, model download, packaging, signing, and icon helpers
Tests/                   Swift and Python test coverage
docs/superpowers/        Local design notes and implementation plans
```

## Development Checks

Run the Swift test suite:

```bash
swift test
```

Run the Python tests:

```bash
python -m pytest python/tests
```

## Credits

SnapTex uses formula recognition models from [opendatalab/UniMERNet](https://github.com/opendatalab/UniMERNet) and [PaddlePaddle/PaddleOCR](https://github.com/PaddlePaddle/PaddleOCR). [MathJax](https://www.mathjax.org/) is bundled locally for LaTeX preview and formula export rendering. Third-party code, models, and assets retain their own licenses.

## License

SnapTex is released under the [MIT License](LICENSE).
