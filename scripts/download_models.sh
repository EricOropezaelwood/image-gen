#!/usr/bin/env bash
# Download Tongyi-MAI/Z-Image-Turbo into ComfyUI's model tree.
# Run this once from the repo root before starting the stack:
#   bash scripts/download_models.sh
#
# Optional env vars:
#   HF_TOKEN   — HuggingFace token (required if the repo is gated)
#   MODEL_DIR  — override default ./data/comfyui/models
set -euo pipefail

MODEL_DIR="${MODEL_DIR:-./data/comfyui/models}"

# ── Ensure the full ComfyUI model tree exists ────────────────────────────────
mkdir -p \
    "$MODEL_DIR/checkpoints" \
    "$MODEL_DIR/clip" \
    "$MODEL_DIR/vae" \
    "$MODEL_DIR/unet" \
    "$MODEL_DIR/loras" \
    "$MODEL_DIR/controlnet" \
    "$MODEL_DIR/upscale_models"

# ── Check for huggingface-cli ────────────────────────────────────────────────
if ! command -v huggingface-cli &>/dev/null; then
    if command -v pipx &>/dev/null; then
        echo "[info] huggingface-cli not found — installing via pipx..."
        pipx install "huggingface_hub[cli]"
    else
        echo "[error] Neither huggingface-cli nor pipx found."
        echo "        Install pipx first:  sudo apt install pipx && pipx ensurepath"
        exit 1
    fi
fi

# ── Optional auth ────────────────────────────────────────────────────────────
if [[ -n "${HF_TOKEN:-}" ]]; then
    huggingface-cli login --token "$HF_TOKEN" --add-to-git-credential
fi

# ── Download Z-Image-Turbo ───────────────────────────────────────────────────
DEST="$MODEL_DIR/checkpoints/Z-Image-Turbo"
echo "[info] Downloading Tongyi-MAI/Z-Image-Turbo → $DEST"

huggingface-cli download Tongyi-MAI/Z-Image-Turbo \
    --local-dir "$DEST" \
    --exclude "*.gitattributes" "*.md"

echo ""
echo "[done] Files saved to $DEST"
echo ""
echo "Layout hint — Z-Image-Turbo uses a FLUX-like architecture."
echo "If ComfyUI cannot load the checkpoint directly, reorganise like so:"
echo ""
echo "  Diffusion model .safetensors  →  $MODEL_DIR/unet/"
echo "  VAE .safetensors              →  $MODEL_DIR/vae/"
echo "  CLIP / T5 text encoders       →  $MODEL_DIR/clip/"
echo ""
echo "Then use the 'Load Diffusion Model' node instead of 'Load Checkpoint'."
