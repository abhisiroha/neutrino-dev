# Neutrino Dev Setup

This repo is for setting up a full Python environment in this order:
1. Install `uv` (if needed)
2. Install project dependencies
3. Install TabPFN stack (core + extensions + models)

The setup script is:
`/Users/abhisheksiroha/neutrino-dev/install.sh`

## Get Started

### Prerequisites

- Linux/macOS with `bash`
- `python3` on PATH (or set `PYTHON_BIN`)
- Internet enabled during setup
- Hugging Face token with accepted TabPFN model access (`HF_TOKEN`)

### Run full setup

From repo root:

```bash
cd /Users/abhisheksiroha/neutrino-dev
HF_TOKEN=<your_hf_token> \
INSTALL_PROJECT_DEPS=1 \
bash install.sh
```

This command:
1. Ensures `uv` is installed
2. Creates/updates `.venv`
3. Installs repo dependencies (`uv sync`) when `INSTALL_PROJECT_DEPS=1`
4. Installs `tabpfn`
5. Installs `tabpfn-extensions[all]`
6. Installs TabPFN dev tooling
7. Downloads TabPFN models for offline usage

### Recommended for offline nodes

Use a shared model cache path before disabling internet:

```bash
cd /Users/abhisheksiroha/neutrino-dev
HF_TOKEN=<your_hf_token> \
INSTALL_PROJECT_DEPS=1 \
TABPFN_MODEL_CACHE_DIR=/opt/tabpfn-model-cache \
bash install.sh
```

## Verify

Run these checks after setup and before cutting internet:

1. Environment activates:
```bash
source /Users/abhisheksiroha/neutrino-dev/.venv/bin/activate
python --version
```

2. Core project dependencies import:
```bash
python -c "import pandas, pyarrow, sklearn, matplotlib; print('project deps ok')"
```

3. TabPFN imports:
```bash
python -c "import tabpfn, tabpfn_extensions; print(tabpfn.__version__)"
```

4. Model files are present:
```bash
find "${TABPFN_MODEL_CACHE_DIR:-$HOME/.cache/tabpfn}" -type f | head
```

5. Optional checkpoint count:
```bash
find "${TABPFN_MODEL_CACHE_DIR:-$HOME/.cache/tabpfn}" -type f \( -name "*.ckpt" -o -name "*.pt" \) | wc -l
```

## TabPFN

### What is installed

- `tabpfn`
- `tabpfn-extensions[all]`
- TabPFN dev dependencies (`ruff`, `mypy`, `pytest`, `mkdocs`, `black`, etc.)
- Local model weights via `download_all_models(...)`

### Useful environment variables

| Variable | Default | Purpose |
|---|---|---|
| `VENV_DIR` | `.venv` | Virtual environment location |
| `PYTHON_BIN` | `python3` | Python used for venv creation |
| `INSTALL_PROJECT_DEPS` | `0` | Set `1` to install repo dependencies with `uv sync` |
| `INSTALL_TABPFN_EXTENSIONS` | `1` | Install `tabpfn-extensions[all]` |
| `INSTALL_TABPFN_DEV_DEPS` | `1` | Install TabPFN dev toolchain |
| `DOWNLOAD_TABPFN_MODELS` | `1` | Download TabPFN model weights |
| `TABPFN_VERSION` | unset | Optional `tabpfn` pin |
| `TABPFN_EXTENSIONS_VERSION` | unset | Optional `tabpfn-extensions` pin |
| `TABPFN_MODEL_CACHE_DIR` | `$HOME/.cache/tabpfn` | Model cache directory |
| `HF_TOKEN` | unset | Hugging Face token for non-interactive auth |

### Common variants

Pin versions:

```bash
HF_TOKEN=<your_hf_token> \
INSTALL_PROJECT_DEPS=1 \
TABPFN_VERSION=6.3.2 \
TABPFN_EXTENSIONS_VERSION=0.2.2 \
bash /Users/abhisheksiroha/neutrino-dev/install.sh
```

Skip model download:

```bash
INSTALL_PROJECT_DEPS=1 \
DOWNLOAD_TABPFN_MODELS=0 \
bash /Users/abhisheksiroha/neutrino-dev/install.sh
```

## Troubleshooting

- `HF_TOKEN` missing:
  - Export `HF_TOKEN` or run `hf auth login` inside the venv.
- License/access errors on model download:
  - Confirm token access and accepted model terms on Hugging Face.
- `uv` still not found:
  - Open a new shell or add `~/.local/bin` to PATH.
- Wrong Python selected:
  - Use `PYTHON_BIN`, for example `PYTHON_BIN=python3.12`.
