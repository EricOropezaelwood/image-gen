#!/usr/bin/env bash
# Prune old generated images/videos from the ComfyUI output directory.
#
# The files are owned by the container's user (rootless Podman UID mapping),
# so a plain `rm` on the host fails with "permission denied". This deletes them
# *inside* the container via podman exec, where that user owns them.
#
# Usage:
#   bash scripts/cleanup_output.sh                # delete files older than 14 days
#   DAYS=7 bash scripts/cleanup_output.sh         # custom retention window
#   DRY_RUN=1 bash scripts/cleanup_output.sh      # just list what would be deleted
#   DAYS=0 bash scripts/cleanup_output.sh         # delete everything (>24h old)
set -euo pipefail

CONTAINER="${CONTAINER:-vivy-comfyui}"
DAYS="${DAYS:-14}"
OUTPUT="/opt/ComfyUI/output"

if ! podman ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    echo "[error] Container '${CONTAINER}' is not running."
    echo "        Start it first:  podman-compose up -d"
    exit 1
fi

# Match generated media only, recurse into video/ etc. Never touch other files.
FIND_EXPR=( -type f \( -iname '*.png' -o -iname '*.webp' -o -iname '*.jpg' \
    -o -iname '*.jpeg' -o -iname '*.mp4' -o -iname '*.webm' -o -iname '*.gif' \) \
    -mtime +"${DAYS}" )

if [[ "${DRY_RUN:-0}" == "1" ]]; then
    echo "[dry-run] Files older than ${DAYS} days that would be deleted:"
    podman exec --user user "${CONTAINER}" find "${OUTPUT}" "${FIND_EXPR[@]}" -print
    count=$(podman exec --user user "${CONTAINER}" find "${OUTPUT}" "${FIND_EXPR[@]}" -print | wc -l)
    echo "[dry-run] ${count} file(s) match. Re-run without DRY_RUN=1 to delete."
else
    echo "[cleanup] Deleting output files older than ${DAYS} days from ${OUTPUT}..."
    podman exec --user user "${CONTAINER}" find "${OUTPUT}" "${FIND_EXPR[@]}" -delete
    echo "[done]"
fi
