#!/usr/bin/env bash
# Install ComfyUI-GGUF custom node into the running vivy-comfyui container.
# Run this once before hunyuan_download.sh and before using HunyuanVideo.
#
# Usage: bash scripts/hunyuan_install.sh
set -euo pipefail

CONTAINER="${CONTAINER:-vivy-comfyui}"

if ! podman ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    echo "[error] Container '${CONTAINER}' is not running."
    echo "        Start it first:  podman-compose up -d"
    exit 1
fi

# ── Install ComfyUI-GGUF custom node ─────────────────────────────────────────
GGUF_DIR="/opt/ComfyUI/custom_nodes/ComfyUI-GGUF"

if podman exec "${CONTAINER}" test -d "${GGUF_DIR}"; then
    echo "[info] ComfyUI-GGUF already installed, skipping clone."
else
    echo "[install] Cloning ComfyUI-GGUF..."
    podman exec --user user "${CONTAINER}" \
        git clone https://github.com/city96/ComfyUI-GGUF "${GGUF_DIR}"
fi

echo "[install] Installing gguf Python package..."
podman exec --user user "${CONTAINER}" \
    /opt/environments/python/comfyui/bin/pip install -q gguf

# ComfyUI 0.19.0+ sets __path__=[] when loading __init__.py via spec_from_file_location,
# breaking relative imports in ComfyUI-GGUF. Patch to fix it.
echo "[install] Patching ComfyUI-GGUF __init__.py for ComfyUI 0.19.0+ compatibility..."
podman exec --user user "${CONTAINER}" /opt/environments/python/comfyui/bin/python - << 'PYEOF'
f = "/opt/ComfyUI/custom_nodes/ComfyUI-GGUF/__init__.py"
with open(f) as fp:
    content = fp.read()
if "if not __path__" not in content:
    patch = "import os as _os\nif not __path__:\n    __path__ = [_os.path.dirname(_os.path.abspath(__file__))]\n\n"
    with open(f, "w") as fp:
        fp.write(patch + content)
    print("  Patched.")
else:
    print("  Already patched.")
PYEOF

# ── Restart so ComfyUI picks up the new custom node ──────────────────────────
echo "[install] Restarting container to load new custom node..."
podman restart "${CONTAINER}"

echo ""
echo "[done] ComfyUI-GGUF installed."
echo "       Next: bash scripts/hunyuan_download.sh"
