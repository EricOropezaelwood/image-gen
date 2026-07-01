#!/usr/bin/env bash
# Download the models for the hires-fix + FaceDetailer workflow into the running
# vivy-comfyui container. Run scripts/detailer_install.sh first (custom nodes).
#
# Downloads (~140 MB total, all token-free):
#   - 4x-UltraSharp.pth   (67 MB) → upscale_models/         (hires upscaler)
#   - face_yolov8m.pt     (52 MB) → ultralytics/bbox/       (face detector)
#   - hand_yolov8s.pt     (23 MB) → ultralytics/bbox/       (hand detector, optional)
#
# Usage: bash scripts/detailer_download.sh
set -euo pipefail

CONTAINER="${CONTAINER:-vivy-comfyui}"

if ! podman ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    echo "[error] Container '${CONTAINER}' is not running."
    echo "        Start it first:  podman-compose up -d"
    exit 1
fi

echo "[info] Downloading detailer/upscale models inside '${CONTAINER}'..."

podman exec -i \
    -e "HF_HUB_CACHE=/opt/ComfyUI/models/.hf_cache" \
    --user user "${CONTAINER}" \
    /opt/environments/python/comfyui/bin/python - <<'PYEOF'
import os
from huggingface_hub import hf_hub_download

BASE = "/opt/ComfyUI/models"

def dl(repo, filename, dest_dir, label):
    dest = os.path.join(dest_dir, filename)
    if os.path.exists(dest):
        print(f"  [skip] {filename} already exists")
        return
    print(f"\n[{label}] {filename}")
    os.makedirs(dest_dir, exist_ok=True)
    hf_hub_download(repo_id=repo, filename=filename, local_dir=dest_dir)
    print(f"  → {dest}")

# ── Hires upscaler ────────────────────────────────────────────────────────────
dl("Kim2091/UltraSharp", "4x-UltraSharp.pth",
   f"{BASE}/upscale_models", "1/3 4x-UltraSharp (67 MB)")

# ── Detection models (Ultralytics YOLO — for FaceDetailer) ───────────────────
dl("Bingsu/adetailer", "face_yolov8m.pt",
   f"{BASE}/ultralytics/bbox", "2/3 face_yolov8m (52 MB)")

dl("Bingsu/adetailer", "hand_yolov8s.pt",
   f"{BASE}/ultralytics/bbox", "3/3 hand_yolov8s (23 MB)")

print("""
[done] Detailer + upscale models downloaded.

See the README "Hires fix + FaceDetailer" section to assemble the workflow.
Quick recap of the node chain:
  KSampler (base) → VAE Decode
    → Upscale Image (using Model)  [4x-UltraSharp]
    → Upscale Image (to ~1.5x target)
    → VAE Encode → KSampler (hires, denoise ~0.4) → VAE Decode
    → FaceDetailer  [UltralyticsDetectorProvider → bbox/face_yolov8m.pt]
    → Save Image
""")
PYEOF
