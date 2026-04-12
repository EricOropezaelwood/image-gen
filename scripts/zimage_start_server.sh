#!/usr/bin/env bash
# Start the Z-Image-Turbo inference server on port 8190.
# Runs setup (venv + model download) if needed, then launches uvicorn.
#
# Usage:  bash scripts/zimage_start_server.sh
#         ZIMAGE_PORT=8191 bash scripts/zimage_start_server.sh
set -euo pipefail

VENV="/mnt/wdc4tb/vivy/z-image-venv"
MODEL="/mnt/wdc4tb/vivy/z-image-turbo"
PORT="${ZIMAGE_PORT:-8190}"
SCRIPT="$(cd "$(dirname "$0")" && pwd)/zimage_server.py"

# ── One-time venv setup ──────────────────────────────────────────────────────
if [[ ! -f "$VENV/bin/python" ]]; then
    echo "[setup] Creating Python venv on 4TB drive..."
    python3 -m venv "$VENV"
    "$VENV/bin/pip" install -q --upgrade pip

    echo "[setup] Installing PyTorch with CUDA 12.8 (Blackwell sm_120 support)..."
    "$VENV/bin/pip" install -q \
        torch torchvision \
        --index-url https://download.pytorch.org/whl/cu128

    echo "[setup] Installing diffusers + transformers..."
    "$VENV/bin/pip" install -q \
        "diffusers>=0.31" \
        "transformers>=4.51" \
        accelerate \
        fastapi \
        "uvicorn[standard]"
fi

# Install fastapi/uvicorn if they were added after the initial venv creation
if ! "$VENV/bin/python" -c "import fastapi, uvicorn" 2>/dev/null; then
    echo "[setup] Installing fastapi + uvicorn..."
    "$VENV/bin/pip" install -q fastapi "uvicorn[standard]"
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

# ── Free VRAM by pausing ComfyUI ─────────────────────────────────────────────
COMFYUI_WAS_RUNNING=false
if podman ps --format '{{.Names}}' 2>/dev/null | grep -q '^vivy-comfyui$'; then
    COMFYUI_WAS_RUNNING=true
    echo "[vram] Pausing vivy-comfyui to free GPU memory..."
    podman stop vivy-comfyui
fi

# Restart ComfyUI when this script exits (Ctrl-C or error)
cleanup() {
    echo ""
    if $COMFYUI_WAS_RUNNING; then
        echo "[vram] Restarting vivy-comfyui..."
        podman start vivy-comfyui
    fi
}
trap cleanup EXIT

# ── Start server ─────────────────────────────────────────────────────────────
echo "[server] Starting Z-Image-Turbo API on port $PORT..."
echo "[server] POST http://vivy:$PORT/generate"
echo "[server] GET  http://vivy:$PORT/health"
echo "[server] Press Ctrl-C to stop."

ZIMAGE_MODEL="$MODEL" "$VENV/bin/python" -m uvicorn \
    --app-dir "$(dirname "$SCRIPT")" \
    zimage_server:app \
    --host 0.0.0.0 \
    --port "$PORT" \
    --log-level info
