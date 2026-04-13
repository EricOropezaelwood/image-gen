#!/usr/bin/env bash
# Download HunyuanVideo 1.5 GGUF model files into the running vivy-comfyui container.
# Run hunyuan_install.sh first to set up the ComfyUI-GGUF custom node.
#
# Downloads (~17.9 GB total):
#   - Transformer:   hunyuanvideo1.5_720p_t2v-Q4_K_M.gguf          (5.09 GB) → unet/
#   - Text encoder:  qwen_2.5_vl_7b_fp8_scaled.safetensors          (9.38 GB) → text_encoders/
#   - Text encoder:  byt5_small_glyphxl_fp16.safetensors             (0.44 GB) → text_encoders/
#   - VAE:           hunyuanvideo15_vae_fp16.safetensors              (2.52 GB) → vae/
#   - SR upscaler:   hunyuanvideo1.5_1080p_sr_distilled_fp16.st...   (0.47 GB) → diffusion_models/
#
# Usage: bash scripts/hunyuan_download.sh
#        HF_TOKEN=hf_xxx bash scripts/hunyuan_download.sh
set -euo pipefail

CONTAINER="${CONTAINER:-vivy-comfyui}"

if ! podman ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    echo "[error] Container '${CONTAINER}' is not running."
    echo "        Start it first:  podman-compose up -d"
    exit 1
fi

echo "[info] Downloading HunyuanVideo 1.5 GGUF models inside '${CONTAINER}'..."
echo "[info] Total download: ~18 GB"

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

def dl_direct(repo, filename, dest_dir, label):
    """For files with no subdirectory prefix in the repo — download straight to dest."""
    dest = os.path.join(dest_dir, filename)
    if os.path.exists(dest):
        print(f"  [skip] {filename} already exists")
        return
    print(f"\n[{label}] {filename}")
    os.makedirs(dest_dir, exist_ok=True)
    hf_hub_download(repo_id=repo, filename=filename, local_dir=dest_dir)
    print(f"  → {dest}")

def dl_flat(repo, repo_path, dest_dir, label):
    """For files nested under split_files/... in the repo — cache then copy to flat path."""
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

# ── Transformer (GGUF Q4_K_M — fits in 16 GB VRAM without offloading) ────────
dl_flat(
    "jayn7/HunyuanVideo-1.5_T2V_720p-GGUF",
    "720p/hunyuanvideo1.5_720p_t2v-Q4_K_M.gguf",
    f"{BASE}/unet",
    "1/5 Transformer GGUF Q4_K_M (5.09 GB)",
)

# ── Text encoders ─────────────────────────────────────────────────────────────
dl_flat(
    "Comfy-Org/HunyuanVideo_1.5_repackaged",
    "split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors",
    f"{BASE}/text_encoders",
    "2/5 Qwen 2.5 VL FP8 text encoder (9.38 GB)",
)

dl_flat(
    "Comfy-Org/HunyuanVideo_1.5_repackaged",
    "split_files/text_encoders/byt5_small_glyphxl_fp16.safetensors",
    f"{BASE}/text_encoders",
    "3/5 ByT5 text encoder (0.44 GB)",
)

# ── VAE ───────────────────────────────────────────────────────────────────────
dl_flat(
    "Comfy-Org/HunyuanVideo_1.5_repackaged",
    "split_files/vae/hunyuanvideo15_vae_fp16.safetensors",
    f"{BASE}/vae",
    "4/5 VAE (2.52 GB)",
)

# ── 1080p Super Resolution upscaler + latent upsampler ───────────────────────
dl_flat(
    "Comfy-Org/HunyuanVideo_1.5_repackaged",
    "split_files/diffusion_models/hunyuanvideo1.5_1080p_sr_distilled_fp16.safetensors",
    f"{BASE}/diffusion_models",
    "5/6 1080p SR upscaler (0.47 GB)",
)

dl_flat(
    "Comfy-Org/HunyuanVideo_1.5_repackaged",
    "split_files/latent_upscale_models/hunyuanvideo15_latent_upsampler_1080p.safetensors",
    f"{BASE}/latent_upscale_models",
    "6/6 Latent upsampler 1080p (0.19 GB)",
)

print("""
[done] All HunyuanVideo 1.5 models downloaded.

Next steps in ComfyUI (http://vivy:8188):
  1. Run:  bash scripts/hunyuan_install.sh  (if not already done)
  2. Workflows → Browse Templates → search "hunyuan 1.5" → Text-to-Video

Node settings:
  UNETLoaderGGUF       → hunyuanvideo1.5_720p_t2v-Q4_K_M.gguf
  DualCLIPLoader       → qwen_2.5_vl_7b_fp8_scaled.safetensors
                       → byt5_small_glyphxl_fp16.safetensors
  Load VAE             → hunyuanvideo15_vae_fp16.safetensors
  SR model (optional)  → hunyuanvideo1.5_1080p_sr_distilled_fp16.safetensors

Key settings:
  Steps    : 20-30 (faster than original HunyuanVideo)
  CFG      : 6.0
  Frames   : 25, 49, or 85 (must be 4n+1)
""")
PYEOF
