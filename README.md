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
</p>

## Overview

SnapTex is a local macOS app for capturing equations from your screen and converting them into LaTeX. It pairs a native SwiftUI interface with local Python OCR workers, rendered previews, copy-ready output, and history.

## Core Features

- Capture an equation region with the Snip button or global shortcut.
- Edit, preview, copy, and format the recognized LaTeX.
- Export the rendered formula as PNG or EPS.
- Keep recent snapshots in a persistent history.
- Manage local OCR models from inside the app.

![SnapTex demo](docs/assets/snaptex-demo.gif)

## Models

SnapTex supports the following open-source OCR models:

- [UniMERNet](https://github.com/opendatalab/UniMERNet): [tiny](https://huggingface.co/wanderkid/unimernet_tiny), [small](https://huggingface.co/wanderkid/unimernet_small), and [base](https://huggingface.co/wanderkid/unimernet_base).
- [PaddleOCR](https://github.com/PaddlePaddle/PaddleOCR): [S](https://huggingface.co/PaddlePaddle/PP-FormulaNet_plus-S), [M](https://huggingface.co/PaddlePaddle/PP-FormulaNet_plus-M), and [L](https://huggingface.co/PaddlePaddle/PP-FormulaNet_plus-L).

## Install

SnapTex currently builds from source and uses a local Conda environment for the OCR workers.

Requirements:

- macOS 13 or later.
- Git.
- Xcode Command Line Tools.
- A Conda distribution, such as Miniforge, Miniconda, Anaconda, or another installation that provides a `conda` executable.

1. Install Apple's command line tools if they are not already installed:

   ```bash
   xcode-select --install
   ```

2. Make sure Conda is available.

   ```bash
   conda --version
   ```

   If `conda` is not found, install Miniforge with Homebrew:

   ```bash
   brew install --cask miniforge
   ```

   Then open a new terminal and try the commands above again. You can also initialize your shell and restart it:

   ```bash
   conda init "$(basename "${SHELL}")"
   ```

   SnapTex usually detects common Conda installs automatically. If your Conda installation is in a custom location, export its absolute path before running the setup script:

   ```bash
   export CONDA_EXE="$(conda info --base)/bin/conda"
   ```

3. Clone the repository and enter it:

   ```bash
   git clone https://github.com/nepeivodaRS/snaptex.git
   cd snaptex
   ```

4. Create the OCR environment and download the default model:

   ```bash
   ./scripts/setup_snaptex_env.sh
   ```

   This creates a Conda environment named `snaptex`, installs the Python OCR dependencies, clones the UniMERNet runtime, and downloads the default UniMERNet model under:

   ```text
   ~/Library/Application Support/snaptex/UniMERNet
   ```

   Verify that the environment Python exists:

   ```bash
   conda run -n snaptex python --version
   ```

   The setup script prints the Python path it created. It should end with `envs/snaptex/bin/python` under your Conda install root.

   To choose a different default UniMERNet model size during setup:

   ```bash
   SNAPTEX_MODEL_SIZE=tiny ./scripts/setup_snaptex_env.sh
   ```

   Supported setup values are `tiny`, `small`, and `base`; the aliases `s`, `m`, and `l` are also accepted. The app can also
   download and manage additional UniMERNet and PaddleOCR models after the environment is installed.

5. Build, install, and launch SnapTex:

   ```bash
   SNAPTEX_ALLOW_ADHOC_SIGNING=1 ./scripts/build_and_run.sh
   ```

   The script builds the Swift app, creates an app bundle, installs it at `/Applications/snaptex.app`, verifies the code signature, and opens the app.
   `SNAPTEX_ALLOW_ADHOC_SIGNING=1` is the recommended source-build path for users who do not have a local code-signing identity.
   Ad-hoc signing is useful for local testing, but macOS may ask you to re-grant permissions after rebuilds.

6. On first use, grant any macOS permissions SnapTex requests, such as Screen Recording for capturing equation regions. If permission changes, quit and reopen SnapTex.
   The first recognition after launching SnapTex can take longer because the OCR worker initializes and loads the selected model; later recognitions are faster.

The installed app is:

```text
/Applications/snaptex.app
```

To verify that the installed app launches:

```bash
SNAPTEX_ALLOW_ADHOC_SIGNING=1 ./scripts/build_and_run.sh --verify
```

If SnapTex reports `Conda environment Python was not found at /envs/snaptex/bin/python`, reset the saved app settings and relaunch with `CONDA_EXE` set to the absolute Conda path:

```bash
defaults delete dev.snaptex.app AppSettingsSnapshot 2>/dev/null || true
export CONDA_EXE="$(conda info --base)/bin/conda"
SNAPTEX_ALLOW_ADHOC_SIGNING=1 ./scripts/build_and_run.sh
```

## Uninstall

To fully remove a source-built SnapTex installation:

```bash
osascript -e 'quit app "snaptex"' 2>/dev/null || true
sudo rm -rf /Applications/snaptex.app
rm -rf "$HOME/Library/Application Support/snaptex"
defaults delete dev.snaptex.app 2>/dev/null || true
conda env remove -n snaptex
```

If `conda` is not available in your shell, use the absolute Conda path from the install guide:

```bash
"$CONDA_EXE" env remove -n snaptex
```

If you built SnapTex with a custom `SNAPTEX_BUNDLE_ID`, replace `dev.snaptex.app` with that bundle identifier in the `defaults delete` command.

## Development

```bash
swift test
python -m pytest python/tests
```

## Credits

[UniMERNet](https://github.com/opendatalab/UniMERNet), [PaddleOCR](https://github.com/PaddlePaddle/PaddleOCR), [MathJax](https://www.mathjax.org/).

Third-party code and models retain their own licenses.

## License

SnapTex is released under the [MIT License](LICENSE).
