#!/usr/bin/env bash
# Run Z-Image-Turbo inference.
# Usage: bash scripts/zimage.sh "your prompt" [--steps 20] [--seed 42] ...
#
# First run:
#   - creates a Python venv on the 4TB drive
#   - downloads Z-Image-Turbo (~31 GB)
# Subsequent runs skip setup and go straight to inference.
#
# Output images saved to /mnt/wdc4tb/vivy/z-image-output/
set -euo pipefail

VENV="/mnt/wdc4tb/vivy/z-image-venv"
MODEL="/mnt/wdc4tb/vivy/z-image-turbo"
SCRIPT="$(cd "$(dirname "$0")" && pwd)/zimage_infer.py"

# ── One-time venv setup ──────────────────────────────────────────────────────
if [[ ! -f "$VENV/bin/python" ]]; then
    echo "[setup] Creating Python venv on 4TB drive..."
    python3 -m venv "$VENV"
    "$VENV/bin/pip" install -q --upgrade pip

    echo "[setup] Installing PyTorch with CUDA 12.8 (Blackwell sm_120 support)..."
    "$VENV/bin/pip" install -q \
        torch torchvision \
        --index-url https://download.pytorch.org/whl/cu128

    echo "[setup] Installing diffusers + transformers + server deps..."
    "$VENV/bin/pip" install -q \
        "diffusers>=0.31" \
        "transformers>=4.51" \
        accelerate \
        fastapi \
        "uvicorn[standard]"
fi

# ── One-time model download ──────────────────────────────────────────────────
if [[ ! -f "$MODEL/model_index.json" ]]; then
    echo "[setup] Downloading Tongyi-MAI/Z-Image-Turbo to $MODEL (~31 GB)..."
    "$VENV/bin/pip" install -q "huggingface_hub"
    "$VENV/bin/python" - <<PYEOF
from huggingface_hub import snapshot_download
snapshot_download(
    "Tongyi-MAI/Z-Image-Turbo",
    local_dir="$MODEL",
    ignore_patterns=["*.gitattributes", "README.md"],
)
print("[setup] Download complete.")
PYEOF
fi

# ── Run inference ────────────────────────────────────────────────────────────
exec "$VENV/bin/python" "$SCRIPT" "$@" --model "$MODEL"
