#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_NAME="${SNAPTEX_ENV_NAME:-${ENV_NAME:-snaptex}}"
MODEL_VARIANT="${SNAPTEX_MODEL_VARIANT:-${MODEL_VARIANT:-small}}"
APP_SUPPORT_DIR="${SNAPTEX_APP_SUPPORT_DIR:-$HOME/Library/Application Support/snaptex}"
UNIMERNET_DIR="${SNAPTEX_UNIMERNET_DIR:-${UNIMERNET_DIR:-$APP_SUPPORT_DIR/UniMERNet}}"

find_conda() {
  if [[ -n "${CONDA_EXE:-}" && -x "${CONDA_EXE:-}" ]]; then
    printf '%s\n' "$CONDA_EXE"
    return
  fi

  local conda_path
  conda_path="$(type -P conda 2>/dev/null || true)"
  if [[ -n "$conda_path" ]]; then
    printf '%s\n' "$conda_path"
    return
  fi

  local candidate
  for candidate in \
    "$HOME/miniforge3/bin/conda" \
    "$HOME/miniconda3/bin/conda" \
    "$HOME/anaconda3/bin/conda" \
    "/opt/homebrew/bin/conda" \
    "/usr/local/bin/conda"; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return
    fi
  done

  return 0
}

CONDA_BIN="$(find_conda)"
if [[ -z "$CONDA_BIN" ]]; then
  echo "conda was not found. Install Miniforge or set CONDA_EXE=/path/to/conda." >&2
  exit 1
fi

CONDA_ROOT="$("$CONDA_BIN" info --base)"
PYTHON_BIN="$CONDA_ROOT/envs/$ENV_NAME/bin/python"

if [[ ! -x "$PYTHON_BIN" ]]; then
  "$CONDA_BIN" create -y -n "$ENV_NAME" python=3.10
fi

if [[ -d "$UNIMERNET_DIR/.git" || -d "$UNIMERNET_DIR/unimernet" ]]; then
  echo "Using UniMERNet source at $UNIMERNET_DIR"
elif [[ -e "$UNIMERNET_DIR" ]]; then
  echo "$UNIMERNET_DIR exists but does not look like a UniMERNet checkout." >&2
  exit 1
else
  mkdir -p "$(dirname "$UNIMERNET_DIR")"
  git clone --depth 1 https://github.com/opendatalab/UniMERNet.git "$UNIMERNET_DIR"
fi

PYTHONNOUSERSITE=1 "$PYTHON_BIN" -m pip install --no-cache-dir -r "$ROOT_DIR/python/requirements.txt"
PYTHONNOUSERSITE=1 "$PYTHON_BIN" "$ROOT_DIR/scripts/download_model.py" \
  --variant "$MODEL_VARIANT" \
  --models-dir "$UNIMERNET_DIR/models"

echo "Environment: $ENV_NAME"
echo "Python: $PYTHON_BIN"
echo "UniMERNet: $UNIMERNET_DIR"
