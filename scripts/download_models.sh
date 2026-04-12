#!/usr/bin/env bash
# Download Tongyi-MAI/Z-Image-Turbo into ComfyUI's model tree.
# Run this from the repo root (container must be running):
#   bash scripts/download_models.sh
#
# Optional env vars:
#   HF_TOKEN   — HuggingFace token (required if the repo is gated)
#   CONTAINER  — container name (default: vivy-comfyui)
set -euo pipefail

CONTAINER="${CONTAINER:-vivy-comfyui}"
MODEL_DEST="/opt/ComfyUI/models/checkpoints/Z-Image-Turbo"

# ── Verify the container is running ─────────────────────────────────────────
if ! podman ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    echo "[error] Container '${CONTAINER}' is not running."
    echo "        Start it first:  podman-compose up -d"
    exit 1
fi

echo "[info] Downloading Tongyi-MAI/Z-Image-Turbo → ${CONTAINER}:${MODEL_DEST}"

# Run the download as uid 1000 inside the container so it has write access to
# the bind-mounted model directories (host ownership was set by podman unshare).
podman exec --user user "${CONTAINER}" \
    /opt/environments/python/comfyui/bin/python - <<PYEOF
import os
from huggingface_hub import snapshot_download

token = os.environ.get("HF_TOKEN", "")
if token:
    from huggingface_hub import login
    login(token=token)

snapshot_download(
    repo_id="Tongyi-MAI/Z-Image-Turbo",
    local_dir="${MODEL_DEST}",
    ignore_patterns=["*.gitattributes", "README.md"],
)
print("[done] Download complete: ${MODEL_DEST}")
PYEOF

echo ""
echo "Layout hint — Z-Image-Turbo uses a FLUX-like architecture."
echo "If ComfyUI cannot load it via 'Load Checkpoint', files may need"
echo "to be reorganised:"
echo "  Diffusion model  →  /opt/ComfyUI/models/unet/"
echo "  VAE              →  /opt/ComfyUI/models/vae/"
echo "  CLIP / T5        →  /opt/ComfyUI/models/clip/"
echo "Then use 'Load Diffusion Model' node instead of 'Load Checkpoint'."
