#!/usr/bin/env bash
# Download Z-Image-Turbo model files into the running vivy-comfyui container.
# Z-Image runs natively in ComfyUI — no separate server or client needed.
#
# Downloads (~16 GB total):
#   - Diffusion model: z_image_turbo_bf16.safetensors   (~12 GB) → diffusion_models/
#   - Text encoder:    qwen_3_4b.safetensors            (~4 GB)  → text_encoders/
#   - VAE:             ae.safetensors                   (~0.3 GB) → vae/
#
# The VAE is the same 16-channel Flux VAE downloaded by download_models.sh,
# so if you already fetched FLUX it will be skipped.
#
# Usage: bash scripts/zimage_download.sh
#        HF_TOKEN=hf_xxx bash scripts/zimage_download.sh
set -euo pipefail

CONTAINER="${CONTAINER:-vivy-comfyui}"

if ! podman ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    echo "[error] Container '${CONTAINER}' is not running."
    echo "        Start it first:  podman-compose up -d"
    exit 1
fi

echo "[info] Downloading Z-Image-Turbo models inside '${CONTAINER}'..."
echo "[info] Total download: ~16 GB"

podman exec -i \
    -e "HF_TOKEN=${HF_TOKEN:-}" \
    -e "HF_HUB_CACHE=/opt/ComfyUI/models/.hf_cache" \
    --user user "${CONTAINER}" \
    /opt/environments/python/comfyui/bin/python - <<'PYEOF'
import os
import shutil
from pathlib import Path
from huggingface_hub import hf_hub_download

token = os.environ.get("HF_TOKEN", "")
if token:
    from huggingface_hub import login
    login(token=token)

BASE = "/opt/ComfyUI/models"
REPO = "Comfy-Org/z_image_turbo"

def dl_flat(repo_path, dest_dir, label):
    """Files are nested under split_files/... — cache then copy to a flat path."""
    filename = Path(repo_path).name
    dest = os.path.join(dest_dir, filename)
    if os.path.exists(dest):
        print(f"  [skip] {filename} already exists")
        return
    print(f"\n[{label}] {filename}")
    cached = hf_hub_download(repo_id=REPO, filename=repo_path)
    os.makedirs(dest_dir, exist_ok=True)
    shutil.copy2(cached, dest)
    print(f"  → {dest}")

# ── Diffusion model (BF16 — fits in 16 GB VRAM, no offload needed) ────────────
dl_flat(
    "split_files/diffusion_models/z_image_turbo_bf16.safetensors",
    f"{BASE}/diffusion_models",
    "1/3 Diffusion model BF16 (~12 GB)",
)

# ── Text encoder (Qwen3-4B) ──────────────────────────────────────────────────
dl_flat(
    "split_files/text_encoders/qwen_3_4b.safetensors",
    f"{BASE}/text_encoders",
    "2/3 Qwen3-4B text encoder (~4 GB)",
)

# ── VAE (same Flux VAE as FLUX.1 — skipped if already present) ────────────────
dl_flat(
    "split_files/vae/ae.safetensors",
    f"{BASE}/vae",
    "3/3 VAE (~0.3 GB)",
)

print("""
[done] All Z-Image-Turbo models downloaded.

Next steps in ComfyUI (http://vivy:8188):
  Workflows → Browse Templates → search "z-image" → Z-Image Turbo

Node settings:
  Load Diffusion Model  → z_image_turbo_bf16.safetensors
  Load CLIP             → qwen_3_4b.safetensors  (type: qwen_image)
  Load VAE              → ae.safetensors

Key settings (Turbo is a distilled few-step model):
  Steps  : 8-9
  CFG    : 1.0
  Sampler: euler   Scheduler: simple
  Size   : 1024x1024
""")
PYEOF
