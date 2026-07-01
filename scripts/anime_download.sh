#!/usr/bin/env bash
# Download anime SDXL checkpoints into the running vivy-comfyui container.
# These are plain SDXL finetunes — they use the standard Load Checkpoint
# workflow (no extra nodes), just like sd_xl_base_1.0.
#
# Downloads (~14 GB total, both are single-file checkpoints → checkpoints/):
#   - NoobAI-XL v1.1     (7.11 GB) — Illustrious finetune, broadest anime knowledge
#   - Illustrious-XL v1.0 (6.94 GB) — clean neutral base
#
# All token-free (ungated Hugging Face repos).
#
# Usage: bash scripts/anime_download.sh
set -euo pipefail

CONTAINER="${CONTAINER:-vivy-comfyui}"

if ! podman ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    echo "[error] Container '${CONTAINER}' is not running."
    echo "        Start it first:  podman-compose up -d"
    exit 1
fi

echo "[info] Downloading anime SDXL checkpoints inside '${CONTAINER}'..."
echo "[info] Total download: ~14 GB"

podman exec -i \
    -e "HF_TOKEN=${HF_TOKEN:-}" \
    -e "HF_HUB_CACHE=/opt/ComfyUI/models/.hf_cache" \
    --user user "${CONTAINER}" \
    /opt/environments/python/comfyui/bin/python - <<'PYEOF'
import os
from huggingface_hub import hf_hub_download

BASE = "/opt/ComfyUI/models"
DEST = f"{BASE}/checkpoints"

def dl(repo, filename, label):
    dest = os.path.join(DEST, filename)
    if os.path.exists(dest):
        print(f"  [skip] {filename} already exists")
        return
    print(f"\n[{label}] {filename}")
    os.makedirs(DEST, exist_ok=True)
    hf_hub_download(repo_id=repo, filename=filename, local_dir=DEST)
    print(f"  → {dest}")

# ── NoobAI-XL v1.1 (eps-pred — standard, no special sampler config) ──────────
dl(
    "Laxhar/noobai-XL-1.1",
    "NoobAI-XL-v1.1.safetensors",
    "1/2 NoobAI-XL v1.1 (7.11 GB)",
)

# ── Illustrious-XL v1.0 (clean neutral base) ─────────────────────────────────
dl(
    "OnomaAIResearch/Illustrious-XL-v1.0",
    "Illustrious-XL-v1.0.safetensors",
    "2/2 Illustrious-XL v1.0 (6.94 GB)",
)

print("""
[done] Anime checkpoints downloaded.

Use the default Load Checkpoint workflow in ComfyUI (http://vivy:8188) —
same as SDXL base, just pick one of these checkpoints:
  NoobAI-XL-v1.1.safetensors   or   Illustrious-XL-v1.0.safetensors

Key settings:
  Steps    : 24-28
  CFG      : 5-7
  Sampler  : euler_ancestral   Scheduler: normal
  Size     : 832x1216 (portrait) or 1024x1024

Prompt with Danbooru-style tags, not sentences:
  Positive: masterpiece, best quality, newest, absurdres, 1girl, solo, ...
  Negative: worst quality, low quality, lowres, jpeg artifacts,
            bad anatomy, bad hands, extra digits, watermark, signature
""")
PYEOF
