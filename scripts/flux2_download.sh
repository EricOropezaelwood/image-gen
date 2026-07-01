#!/usr/bin/env bash
# Download FLUX.2 [klein] 4B (fp8, distilled) into the running vivy-comfyui container.
# Modern successor to FLUX.1-schnell — better prompt adherence, fits easily in 16 GB.
#
# Downloads (~4.4 GB new — the Qwen3-4B text encoder is shared with Z-Image and
# skipped if you already ran zimage_download.sh):
#   - Diffusion model: flux-2-klein-4b-fp8.safetensors  (4.07 GB) → diffusion_models/
#   - Text encoder:    qwen_3_4b.safetensors            (~4 GB)   → text_encoders/  (shared w/ Z-Image)
#   - VAE:             flux2-vae.safetensors            (0.34 GB) → vae/
#
# Usage: bash scripts/flux2_download.sh
#        HF_TOKEN=hf_xxx bash scripts/flux2_download.sh
set -euo pipefail

CONTAINER="${CONTAINER:-vivy-comfyui}"

if ! podman ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    echo "[error] Container '${CONTAINER}' is not running."
    echo "        Start it first:  podman-compose up -d"
    exit 1
fi

echo "[info] Downloading FLUX.2 [klein] 4B models inside '${CONTAINER}'..."

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

def dl(repo, repo_path, dest_dir, label):
    filename = Path(repo_path).name
    dest = os.path.join(dest_dir, filename)
    if os.path.exists(dest):
        print(f"  [skip] {filename} already exists")
        return
    print(f"\n[{label}] {filename}")
    cached = hf_hub_download(repo_id=repo, filename=repo_path)
    os.makedirs(dest_dir, exist_ok=True)
    shutil.copy2(cached, dest)
    print(f"  → {dest}")

# ── Diffusion model (4B fp8, guidance-distilled — few steps) ──────────────────
dl(
    "black-forest-labs/FLUX.2-klein-4b-fp8",
    "flux-2-klein-4b-fp8.safetensors",
    f"{BASE}/diffusion_models",
    "1/3 FLUX.2 klein 4B fp8 (4.07 GB)",
)

# ── Text encoder (Qwen3-4B — same file as Z-Image, skipped if present) ────────
dl(
    "Comfy-Org/z_image_turbo",
    "split_files/text_encoders/qwen_3_4b.safetensors",
    f"{BASE}/text_encoders",
    "2/3 Qwen3-4B text encoder (~4 GB, shared with Z-Image)",
)

# ── VAE ───────────────────────────────────────────────────────────────────────
dl(
    "Comfy-Org/flux2-dev",
    "split_files/vae/flux2-vae.safetensors",
    f"{BASE}/vae",
    "3/3 FLUX.2 VAE (0.34 GB)",
)

print("""
[done] FLUX.2 [klein] 4B downloaded.

Next steps in ComfyUI (http://vivy:8188):
  Workflows → Browse Templates → search "flux 2" → Flux 2 Klein

Node settings:
  Load Diffusion Model  → flux-2-klein-4b-fp8.safetensors
  Load CLIP             → qwen_3_4b.safetensors
  Load VAE              → flux2-vae.safetensors

Key settings (distilled model — use the template's defaults; approx):
  Steps  : 4-6
  CFG    : 1.0
  Sampler: euler   Scheduler: simple
  Size   : 1024x1024
""")
PYEOF
