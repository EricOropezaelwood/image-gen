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

# ── Resolve the HF download command ─────────────────────────────────────────
# huggingface-cli was deprecated in huggingface_hub >= 0.27; the binary is
# now called `hf`.  Try `hf` first, fall back to `huggingface-cli`, install
# via pipx if neither exists.
if command -v hf &>/dev/null; then
    HF_CMD="hf"
elif command -v huggingface-cli &>/dev/null; then
    HF_CMD="huggingface-cli"
else
    if command -v pipx &>/dev/null; then
        echo "[info] hf not found — installing huggingface_hub via pipx..."
        pipx install "huggingface_hub[cli]"
        pipx ensurepath
        # pipx puts binaries in ~/.local/bin; reload PATH for this session
        export PATH="$HOME/.local/bin:$PATH"
        HF_CMD="hf"
    else
        echo "[error] Neither hf/huggingface-cli nor pipx found."
        echo "        Install pipx first:  sudo apt install pipx && pipx ensurepath"
        exit 1
    fi
fi

echo "[info] Using HF command: $HF_CMD"

# ── Optional auth ────────────────────────────────────────────────────────────
if [[ -n "${HF_TOKEN:-}" ]]; then
    "$HF_CMD" auth login --token "$HF_TOKEN"
fi

# ── Download Z-Image-Turbo ───────────────────────────────────────────────────
DEST="$MODEL_DIR/checkpoints/Z-Image-Turbo"
echo "[info] Downloading Tongyi-MAI/Z-Image-Turbo → $DEST"

"$HF_CMD" download Tongyi-MAI/Z-Image-Turbo \
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
