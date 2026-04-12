#!/usr/bin/env bash
# Download HunyuanVideo (original) model files into the running vivy-comfyui container.
#
# Downloads (~30 GB total):
#   - Text encoder:  clip_l.safetensors                      (0.25 GB) → text_encoders/
#   - Text encoder:  llava_llama3_fp8_scaled.safetensors     (4.9 GB)  → text_encoders/
#   - VAE:           hunyuan_video_vae_bf16.safetensors       (1.0 GB)  → vae/
#   - Diffusion:     hunyuan_video_t2v_720p_bf16.safetensors (26 GB)   → diffusion_models/
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

echo "[info] Downloading HunyuanVideo models inside '${CONTAINER}'..."
echo "[info] Total download: ~30 GB — the diffusion model alone is 26 GB"

# HF_HUB_CACHE is redirected to the 4TB-backed models directory so the
# huggingface download cache never touches the OS drive.
podman exec -i \
    -e "HF_TOKEN=${HF_TOKEN:-}" \
    -e "HF_HUB_CACHE=/opt/ComfyUI/models/.hf_cache" \
    --user user "${CONTAINER}" \
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

# ── Text encoders ─────────────────────────────────────────────────────────────
dl(
    "Comfy-Org/HunyuanVideo_repackaged",
    "split_files/text_encoders/clip_l.safetensors",
    f"{BASE}/text_encoders",
    "1/4 CLIP-L text encoder (0.25 GB)",
)

dl(
    "Comfy-Org/HunyuanVideo_repackaged",
    "split_files/text_encoders/llava_llama3_fp8_scaled.safetensors",
    f"{BASE}/text_encoders",
    "2/4 LLaVA-LLaMA3 text encoder FP8 (4.9 GB)",
)

# ── VAE ───────────────────────────────────────────────────────────────────────
dl(
    "Comfy-Org/HunyuanVideo_repackaged",
    "split_files/vae/hunyuan_video_vae_bf16.safetensors",
    f"{BASE}/vae",
    "3/4 VAE (1.0 GB)",
)

# ── Diffusion model ───────────────────────────────────────────────────────────
dl(
    "Comfy-Org/HunyuanVideo_repackaged",
    "split_files/diffusion_models/hunyuan_video_t2v_720p_bf16.safetensors",
    f"{BASE}/diffusion_models",
    "4/4 Diffusion model BF16 (26 GB) — this will take a while",
)

print("""
[done] All HunyuanVideo models downloaded.

In ComfyUI (http://vivy:8188):
  Workflows → Browse Templates → search "hunyuan" → Text-to-Video
  Or drag a workflow image from the docs into the canvas.

Verify these nodes:
  DualCLIPLoader       → clip_l.safetensors + llava_llama3_fp8_scaled.safetensors
  Load Diffusion Model → hunyuan_video_t2v_720p_bf16.safetensors
  Load VAE             → hunyuan_video_vae_bf16.safetensors
""")
PYEOF
