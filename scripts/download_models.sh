#!/usr/bin/env bash
# Download recommended ComfyUI models into the running vivy-comfyui container.
# Usage: bash scripts/download_models.sh
#
# Phase 1 — SDXL base (works immediately with the default Load Checkpoint workflow)
# Phase 2 — FLUX.1-schnell fp8 (best quality, needs the FLUX workflow)
#
# Optional env vars:
#   HF_TOKEN   — required only for gated repos (not needed for these models)
#   CONTAINER  — container name (default: vivy-comfyui)
set -euo pipefail

CONTAINER="${CONTAINER:-vivy-comfyui}"

if ! podman ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    echo "[error] Container '${CONTAINER}' is not running."
    echo "        Start it first:  podman-compose up -d"
    exit 1
fi

echo "[info] Downloading models inside '${CONTAINER}'..."

podman exec -i --user user "${CONTAINER}" \
    /opt/environments/python/comfyui/bin/python - <<'PYEOF'
import os
from huggingface_hub import hf_hub_download

token = os.environ.get("HF_TOKEN", "")
if token:
    from huggingface_hub import login
    login(token=token)

BASE = "/opt/ComfyUI/models"

def dl(repo, filename, dest_dir, label):
    print(f"\n[{label}] {repo}/{filename}")
    hf_hub_download(repo_id=repo, filename=filename, local_dir=dest_dir)
    print(f"  → {dest_dir}/{filename}")

# ── Phase 1: SDXL ────────────────────────────────────────────────────────────
# Single checkpoint file — works with Load Checkpoint + default workflow.
# 6.9 GB, ~20–30 steps, good general quality.
dl(
    "stabilityai/stable-diffusion-xl-base-1.0",
    "sd_xl_base_1.0.safetensors",
    f"{BASE}/checkpoints",
    "1/5 SDXL base",
)

# ── Phase 2: FLUX.1-schnell fp8 ──────────────────────────────────────────────
# Best open image quality. Needs a FLUX workflow (not the default one).
# Apache 2.0 license. 4–8 steps. ~14 GB total VRAM at inference.

dl(
    "Comfy-Org/flux1-schnell",
    "flux1-schnell-fp8.safetensors",
    f"{BASE}/unet",
    "2/5 FLUX.1-schnell model (fp8, ~8 GB)",
)

dl(
    "black-forest-labs/FLUX.1-schnell",
    "ae.safetensors",
    f"{BASE}/vae",
    "3/5 FLUX VAE",
)

dl(
    "comfyanonymous/flux_text_encoders",
    "clip_l.safetensors",
    f"{BASE}/clip",
    "4/5 CLIP-L text encoder",
)

dl(
    "comfyanonymous/flux_text_encoders",
    "t5xxl_fp8_e4m3fn.safetensors",
    f"{BASE}/clip",
    "5/5 T5-XXL text encoder (fp8, ~5 GB)",
)

print("""
[done] All models downloaded.

Start here — SDXL (Load Checkpoint node, default workflow):
  Checkpoint : sd_xl_base_1.0.safetensors
  Steps      : 20–30   Sampler: euler   Scheduler: karras
  Size       : 1024×1024

Next — FLUX.1-schnell (needs FLUX workflow):
  Model : unet/flux1-schnell-fp8.safetensors
  VAE   : vae/ae.safetensors
  CLIP  : clip/clip_l.safetensors + clip/t5xxl_fp8_e4m3fn.safetensors
  Steps : 4–8   Sampler: euler   Scheduler: simple   CFG: 1.0
""")
PYEOF
