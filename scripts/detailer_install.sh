#!/usr/bin/env bash
# Install ComfyUI-Impact-Pack (+ Impact-Subpack) into the running vivy-comfyui
# container. These provide the FaceDetailer / UltralyticsDetectorProvider nodes
# used by the hires-fix + face/hand detail workflow.
#
# Run this once, then run scripts/detailer_download.sh for the models.
#
# Usage: bash scripts/detailer_install.sh
set -euo pipefail

CONTAINER="${CONTAINER:-vivy-comfyui}"
PY=/opt/environments/python/comfyui/bin/python
PIP=/opt/environments/python/comfyui/bin/pip

# Pinned commits for reproducibility (neither repo publishes release tags).
IMPACT_PACK_REF="429d0159ad42"
IMPACT_SUBPACK_REF="50c7b71a6a22"

if ! podman ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    echo "[error] Container '${CONTAINER}' is not running."
    echo "        Start it first:  podman-compose up -d"
    exit 1
fi

clone_pinned() {
    local repo="$1" dir="$2" ref="$3" name="$4"
    if podman exec "${CONTAINER}" test -d "${dir}"; then
        echo "[info] ${name} already installed, skipping clone."
    else
        echo "[install] Cloning ${name} @ ${ref}..."
        podman exec --user user "${CONTAINER}" git clone "${repo}" "${dir}"
        podman exec --user user "${CONTAINER}" git -C "${dir}" checkout "${ref}"
    fi
    echo "[install] Installing ${name} requirements..."
    podman exec --user user "${CONTAINER}" \
        "${PIP}" install -q -r "${dir}/requirements.txt" || true
}

BASE=/opt/ComfyUI/custom_nodes
clone_pinned "https://github.com/ltdrdata/ComfyUI-Impact-Pack" \
    "${BASE}/ComfyUI-Impact-Pack" "${IMPACT_PACK_REF}" "ComfyUI-Impact-Pack"
clone_pinned "https://github.com/ltdrdata/ComfyUI-Impact-Subpack" \
    "${BASE}/ComfyUI-Impact-Subpack" "${IMPACT_SUBPACK_REF}" "ComfyUI-Impact-Subpack"

# ── Restart so ComfyUI loads the new custom nodes ────────────────────────────
echo "[install] Restarting container to load new custom nodes..."
podman restart "${CONTAINER}"

echo ""
echo "[done] Impact-Pack + Subpack installed."
echo "       Next: bash scripts/detailer_download.sh"
