#!/usr/bin/env bash
# Download HunyuanVideo 1.5 model files into the running vivy-comfyui container.
# Run hunyuan_install.sh first to set up the ComfyUI-GGUF custom node.
#
# Downloads (~17.5 GB total):
#   - Transformer:   hunyuanvideo1.5_720p_t2v-Q4_K_M.gguf    (5.09 GB) → unet/
#   - Text encoder:  qwen_2.5_vl_7b_fp8_scaled.safetensors   (9.38 GB) → text_encoders/
#   - Text encoder:  byt5_small_glyphxl_fp16.safetensors      (0.44 GB) → text_encoders/
#   - VAE:           hunyuanvideo15_vae_fp16.safetensors       (2.52 GB) → vae/
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

echo "[info] Downloading HunyuanVideo 1.5 models inside '${CONTAINER}'..."
echo "[info] Total download: ~17.5 GB"

podman exec -i -e "HF_TOKEN=${HF_TOKEN:-}" --user user "${CONTAINER}" \
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

# ── Transformer (GGUF Q4_K_M) ────────────────────────────────────────────────
dl(
    "jayn7/HunyuanVideo-1.5_T2V_720p-GGUF",
    "hunyuanvideo1.5_720p_t2v-Q4_K_M.gguf",
    f"{BASE}/unet",
    "1/4 Transformer Q4_K_M (5.09 GB)",
)

# ── Text encoders ─────────────────────────────────────────────────────────────
dl(
    "Comfy-Org/HunyuanVideo_1.5_repackaged",
    "split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors",
    f"{BASE}/text_encoders",
    "2/4 Qwen 2.5 VL text encoder FP8 (9.38 GB)",
)

dl(
    "Comfy-Org/HunyuanVideo_1.5_repackaged",
    "split_files/text_encoders/byt5_small_glyphxl_fp16.safetensors",
    f"{BASE}/text_encoders",
    "3/4 ByT5 text encoder (0.44 GB)",
)

# ── VAE ───────────────────────────────────────────────────────────────────────
dl(
    "Comfy-Org/HunyuanVideo_1.5_repackaged",
    "split_files/vae/hunyuanvideo15_vae_fp16.safetensors",
    f"{BASE}/vae",
    "4/4 VAE (2.52 GB)",
)

print("""
[done] All HunyuanVideo 1.5 models downloaded.

Load the workflow in ComfyUI:
  File → Load → workflows/hunyuan_720p.json

Key settings:
  Steps    : 30–50
  CFG      : 1.0
  Resolution: 720p (1280×720)
  Frames   : 25–85 (must be divisible by 4, plus 1 — e.g. 25, 49, 85)
""")
PYEOF
