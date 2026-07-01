#!/usr/bin/env bash
# Download Qwen-Image (Q4_K_M GGUF) into the running vivy-comfyui container.
# The text-rendering specialist — best open model for legible text inside images.
# Runs via the ComfyUI-GGUF custom node (already installed by hunyuan_install.sh).
#
# Downloads (~13.3 GB new — the Qwen2.5-VL text encoder is shared with HunyuanVideo
# and skipped if you already ran hunyuan_download.sh):
#   - Diffusion model: qwen-image-Q4_K_M.gguf                (13.07 GB) → diffusion_models/
#   - Text encoder:    qwen_2.5_vl_7b_fp8_scaled.safetensors (9.38 GB)  → text_encoders/  (shared w/ Hunyuan)
#   - VAE:             qwen_image_vae.safetensors            (0.25 GB)  → vae/
#
# Prereq: run scripts/hunyuan_install.sh once (installs the ComfyUI-GGUF node).
#
# Usage: bash scripts/qwen_image_download.sh
#        HF_TOKEN=hf_xxx bash scripts/qwen_image_download.sh
set -euo pipefail

CONTAINER="${CONTAINER:-vivy-comfyui}"

if ! podman ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    echo "[error] Container '${CONTAINER}' is not running."
    echo "        Start it first:  podman-compose up -d"
    exit 1
fi

if ! podman exec "${CONTAINER}" test -d /opt/ComfyUI/custom_nodes/ComfyUI-GGUF; then
    echo "[error] ComfyUI-GGUF node not found. Run this first:"
    echo "        bash scripts/hunyuan_install.sh"
    exit 1
fi

echo "[info] Downloading Qwen-Image GGUF models inside '${CONTAINER}'..."

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

# ── Diffusion model (Q4_K_M GGUF — best quality/VRAM ratio on 16 GB) ──────────
dl(
    "city96/Qwen-Image-gguf",
    "qwen-image-Q4_K_M.gguf",
    f"{BASE}/diffusion_models",
    "1/3 Qwen-Image Q4_K_M GGUF (13.07 GB)",
)

# ── Text encoder (Qwen2.5-VL — same file as Hunyuan, skipped if present) ──────
dl(
    "Comfy-Org/HunyuanVideo_1.5_repackaged",
    "split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors",
    f"{BASE}/text_encoders",
    "2/3 Qwen2.5-VL FP8 text encoder (9.38 GB, shared with Hunyuan)",
)

# ── VAE ───────────────────────────────────────────────────────────────────────
dl(
    "Comfy-Org/Qwen-Image_ComfyUI",
    "split_files/vae/qwen_image_vae.safetensors",
    f"{BASE}/vae",
    "3/3 Qwen-Image VAE (0.25 GB)",
)

print("""
[done] Qwen-Image (Q4_K_M GGUF) downloaded.

Next steps in ComfyUI (http://vivy:8188):
  Workflows → Browse Templates → search "qwen image" → Qwen-Image
  (swap the Load Diffusion Model node for UNETLoaderGGUF → the .gguf file)

Node settings:
  UNETLoaderGGUF   → qwen-image-Q4_K_M.gguf
  Load CLIP        → qwen_2.5_vl_7b_fp8_scaled.safetensors  (type: qwen_image)
  Load VAE         → qwen_image_vae.safetensors

Key settings (text-rendering specialist):
  Steps  : ~20
  CFG    : 2.5-4.0
  Sampler: euler   Scheduler: simple
  Size   : 1328x1328 (Qwen-Image's native resolution) or 1024x1024
""")
PYEOF
