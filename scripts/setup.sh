#!/usr/bin/env bash
# One-time setup — run this from the repo root before the first
# `podman-compose up -d` and after any `podman-compose down` that wipes data.
#
# WHY this is needed:
#   In rootless Podman the host user (uid 1000) maps to container uid 0 (root)
#   via the user namespace.  Directories created on the host are therefore
#   owned by container root, but ComfyUI runs as container uid 1000 / gid 1111
#   and cannot write to them.
#
#   `podman unshare` enters the rootless user namespace so that a `chown 1000:1111`
#   inside it translates to whatever host sub-uid/sub-gid maps to container
#   uid 1000 / gid 1111 — the exact ownership the container's process needs.
set -euo pipefail

echo "[setup] Creating ComfyUI data directories..."
mkdir -p data/comfyui/{output,input,user,custom_nodes}
mkdir -p data/comfyui/models/{checkpoints,loras,vae,vae_approx,unet,diffusion_models,controlnet,\
upscale_models,clip,text_encoders,latent_upscale_models,gligen,diffusers,hypernetworks,embeddings,style_models}

echo "[setup] Chowning to container uid 1000 / gid 1111 via podman unshare..."
podman unshare chown -R 1000:1111 data/comfyui/

echo "[setup] Done."
echo "        Start the stack:   podman-compose up -d"
echo "        Download models:   bash scripts/download_models.sh"
