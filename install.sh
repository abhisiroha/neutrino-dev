#!/usr/bin/env bash
set -euo pipefail

# Offline-ready TabPFN installer:
# - Ensures uv is installed
# - Creates/updates a virtual environment
# - Installs local project deps (optional)
# - Installs TabPFN + TabPFN Extensions[all]
# - Installs TabPFN development dependencies
# - Downloads all TabPFN model weights for offline use
#
# Configurable environment variables:
#   VENV_DIR=.venv
#   PYTHON_BIN=python3
#   INSTALL_PROJECT_DEPS=0
#   INSTALL_TABPFN_EXTENSIONS=1
#   INSTALL_TABPFN_DEV_DEPS=1
#   DOWNLOAD_TABPFN_MODELS=1
#   TABPFN_VERSION=<optional-pin>
#   TABPFN_EXTENSIONS_VERSION=<optional-pin>
#   TABPFN_MODEL_CACHE_DIR=$HOME/.cache/tabpfn
#   HF_TOKEN=<huggingface-token>
#   TABPFN_DISABLE_TELEMETRY=1

command_exists() { command -v "$1" >/dev/null 2>&1; }
info() { echo "[info] $*"; }
warn() { echo "[warn] $*"; }
error() { echo "[error] $*"; }

VENV_DIR="${VENV_DIR:-.venv}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
INSTALL_PROJECT_DEPS="${INSTALL_PROJECT_DEPS:-0}"
INSTALL_TABPFN_EXTENSIONS="${INSTALL_TABPFN_EXTENSIONS:-1}"
INSTALL_TABPFN_DEV_DEPS="${INSTALL_TABPFN_DEV_DEPS:-1}"
DOWNLOAD_TABPFN_MODELS="${DOWNLOAD_TABPFN_MODELS:-1}"
TABPFN_VERSION="${TABPFN_VERSION:-}"
TABPFN_EXTENSIONS_VERSION="${TABPFN_EXTENSIONS_VERSION:-}"
TABPFN_MODEL_CACHE_DIR="${TABPFN_MODEL_CACHE_DIR:-$HOME/.cache/tabpfn}"

install_uv() {
  info "uv not found. Installing uv..."

  if command_exists curl; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
  elif command_exists wget; then
    wget -qO- https://astral.sh/uv/install.sh | sh
  else
    error "Neither curl nor wget is available to install uv."
    exit 1
  fi

  export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

  if ! command_exists uv; then
    if command_exists pipx; then
      warn "uv installer finished but uv is still not on PATH; trying pipx..."
      pipx install uv || pipx upgrade uv
      export PATH="$HOME/.local/bin:$PATH"
    fi
  fi

  if ! command_exists uv; then
    error "uv installation failed or uv is not on PATH."
    error "Try a new shell or ensure ~/.local/bin (or ~/.cargo/bin) is on PATH."
    exit 1
  fi

  info "uv installed: $(uv --version)"
}

ensure_uv() {
  if command_exists uv; then
    info "uv found: $(uv --version)"
  else
    install_uv
  fi
}

create_venv() {
  info "Creating/updating virtual environment at ${VENV_DIR} ..."
  uv venv "${VENV_DIR}" --python "${PYTHON_BIN}"

  VENV_PYTHON="${VENV_DIR}/bin/python"
  if [[ ! -x "${VENV_PYTHON}" ]]; then
    error "Expected python executable at ${VENV_PYTHON}, but it was not found."
    exit 1
  fi
}

sync_local_project() {
  if [[ "${INSTALL_PROJECT_DEPS}" != "1" ]]; then
    info "Skipping local project dependency install (INSTALL_PROJECT_DEPS=${INSTALL_PROJECT_DEPS})."
    return
  fi

  if [[ -f "pyproject.toml" ]]; then
    info "Syncing local project dependencies from pyproject.toml/uv.lock ..."
    uv sync --python "${VENV_PYTHON}"
  elif [[ -f "requirements.txt" ]]; then
    info "Installing local project dependencies from requirements.txt ..."
    uv pip install --python "${VENV_PYTHON}" -r requirements.txt
  else
    warn "No pyproject.toml or requirements.txt found. Continuing."
  fi
}

install_tabpfn_core() {
  info "Installing TabPFN core packages ..."
  local -a core_packages=("tabpfn" "huggingface_hub[cli]>=0.24.0")
  if [[ -n "${TABPFN_VERSION}" ]]; then
    core_packages[0]="tabpfn==${TABPFN_VERSION}"
  fi
  uv pip install --python "${VENV_PYTHON}" "${core_packages[@]}"
}

install_tabpfn_extensions() {
  if [[ "${INSTALL_TABPFN_EXTENSIONS}" != "1" ]]; then
    info "Skipping TabPFN extensions install (INSTALL_TABPFN_EXTENSIONS=${INSTALL_TABPFN_EXTENSIONS})."
    return
  fi

  info "Installing TabPFN extensions (all extras) ..."
  local extension_spec="tabpfn-extensions[all]"
  if [[ -n "${TABPFN_EXTENSIONS_VERSION}" ]]; then
    extension_spec="tabpfn-extensions[all]==${TABPFN_EXTENSIONS_VERSION}"
  fi
  uv pip install --python "${VENV_PYTHON}" "${extension_spec}"
}

install_tabpfn_dev_deps() {
  if [[ "${INSTALL_TABPFN_DEV_DEPS}" != "1" ]]; then
    info "Skipping TabPFN dev dependencies (INSTALL_TABPFN_DEV_DEPS=${INSTALL_TABPFN_DEV_DEPS})."
    return
  fi

  info "Installing TabPFN development dependencies ..."
  # Mirrors the upstream TabPFN dependency groups (dev + ci).
  local -a tabpfn_dev_packages=(
    "pre-commit>=4.3.0"
    "ruff==0.14.0"
    "mypy==1.19.1"
    "pytest-xdist>=3.8.0"
    "towncrier>=24.8.0"
    "mkdocs>=1.6.1"
    "mkdocs-material>=9.6.21"
    "mkdocs-autorefs>=1.4.3"
    "mkdocs-gen-files>=0.5.0"
    "mkdocs-literate-nav>=0.6.2"
    "mkdocs-glightbox>=0.5.1"
    "mkdocstrings[python]>=0.30.1"
    "markdown-exec[ansi]>=1.11.0"
    "mike>=2.1.3"
    "black>=25.9.0"
    "licensecheck>=2025.1.0"
    "onnx>=1.19.0"
    "pytest-mock>=3.14.1"
    "pytest>=8.4.2"
  )
  uv pip install --python "${VENV_PYTHON}" "${tabpfn_dev_packages[@]}"
}

login_huggingface_if_needed() {
  if [[ -n "${HF_TOKEN:-}" ]]; then
    info "Logging into Hugging Face using HF_TOKEN ..."
    HF_TOKEN="${HF_TOKEN}" "${VENV_PYTHON}" - <<'PY'
import os
from huggingface_hub import login

token = os.environ.get("HF_TOKEN")
if token:
    login(token=token, add_to_git_credential=False)
PY
  else
    warn "HF_TOKEN not set. Model download requires accepted license + an authenticated Hugging Face session."
    warn "If download fails, run: source ${VENV_DIR}/bin/activate && hf auth login"
  fi
}

download_tabpfn_models() {
  if [[ "${DOWNLOAD_TABPFN_MODELS}" != "1" ]]; then
    info "Skipping model download (DOWNLOAD_TABPFN_MODELS=${DOWNLOAD_TABPFN_MODELS})."
    return
  fi

  login_huggingface_if_needed

  export TABPFN_MODEL_CACHE_DIR
  info "Downloading all TabPFN model weights into ${TABPFN_MODEL_CACHE_DIR} ..."
  "${VENV_PYTHON}" - <<'PY'
import os
from pathlib import Path

from tabpfn.model.loading import download_all_models

cache_dir = Path(os.environ["TABPFN_MODEL_CACHE_DIR"]).expanduser()
cache_dir.mkdir(parents=True, exist_ok=True)

download_all_models(cache_dir)
print(f"[info] Model download completed in: {cache_dir}")
PY

  local model_count
  model_count="$(
    find "${TABPFN_MODEL_CACHE_DIR}" -type f \( -name "*.ckpt" -o -name "*.pt" \) \
      | wc -l | tr -d '[:space:]'
  )"
  info "Detected ${model_count} model checkpoint files in ${TABPFN_MODEL_CACHE_DIR}."
}

main() {
  ensure_uv
  create_venv
  sync_local_project
  install_tabpfn_core
  install_tabpfn_extensions
  install_tabpfn_dev_deps
  download_tabpfn_models

  info "TabPFN environment setup complete."
  info "Activate it with: source ${VENV_DIR}/bin/activate"
}

main "$@"
