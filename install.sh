#!/usr/bin/env bash
set -euo pipefail

# bootstrap_uv.sh
# - Ensures uv is installed
# - Creates/updates a .venv
# - Installs deps from uv.lock/pyproject.toml (preferred) or requirements.txt (fallback)

command_exists() { command -v "$1" >/dev/null 2>&1; }

install_uv() {
  echo "[info] uv not found. Installing uv..."

  # Preferred: official installer
  if command_exists curl; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
  elif command_exists wget; then
    wget -qO- https://astral.sh/uv/install.sh | sh
  else
    echo "[error] Neither curl nor wget is available to install uv."
    exit 1
  fi

  # Make uv available in current shell (common locations used by installer)
  export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

  if ! command_exists uv; then
    # Fallback: pipx if present
    if command_exists pipx; then
      echo "[warn] uv installer finished but uv still not on PATH; trying pipx..."
      pipx install uv || pipx upgrade uv
      export PATH="$HOME/.local/bin:$PATH"
    fi
  fi

  if ! command_exists uv; then
    echo "[error] uv installation did not succeed or uv is not on PATH."
    echo "       Try opening a new terminal or ensure ~/.local/bin (or ~/.cargo/bin) is in PATH."
    exit 1
  fi

  echo "[info] uv installed: $(uv --version)"
}

ensure_uv() {
  if command_exists uv; then
    echo "[info] uv found: $(uv --version)"
  else
    install_uv
  fi
}

create_and_install() {
  # Use a local venv named .venv by convention
  local venv_dir=".venv"

  # If a specific python is needed, set UV_PYTHON, e.g.:
  # export UV_PYTHON=python3.12
  echo "[info] Creating/updating venv at ${venv_dir} ..."
  uv venv "${venv_dir}"

  # Install dependencies:
  # Priority:
  #  1) uv sync (uses uv.lock if present; otherwise resolves from pyproject)
  #  2) requirements.txt
  if [[ -f "pyproject.toml" ]]; then
    echo "[info] Detected pyproject.toml. Syncing dependencies with uv..."
    # --frozen if you want to require uv.lock (recommended in CI)
    # uv sync --frozen
    uv sync
  elif [[ -f "requirements.txt" ]]; then
    echo "[info] No pyproject.toml found. Installing from requirements.txt..."
    uv pip install -r requirements.txt
  else
    echo "[warn] No pyproject.toml or requirements.txt found. Created venv only."
  fi

  echo "[info] Done."
  echo "       To activate: source ${venv_dir}/bin/activate"
}

main() {
  ensure_uv
  create_and_install
}

main "$@"
