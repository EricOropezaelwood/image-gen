# Pinned for reproducible builds. Bump the ARGs below to upgrade deliberately.
#
# Base image pinned by digest because ai-dock only publishes a moving `latest-cuda`
# tag. This digest == latest-cuda as of 2026-07-01. To refresh:
#   crane digest ghcr.io/ai-dock/comfyui:latest-cuda   (or `podman pull` + inspect)
FROM ghcr.io/ai-dock/comfyui:latest-cuda@sha256:9f99d5383690f85f3f8eb8ccdde41ca3edfbfaecf41dcf53291741c1e8db297e

# Versions — all resolved against live indexes on 2026-07-01.
ARG COMFYUI_REF=v0.27.0
ARG TORCH=2.9.1
ARG TORCHVISION=0.24.1
ARG TORCHAUDIO=2.9.1
ARG GGUF=0.19.0

ENV PIP=/opt/environments/python/comfyui/bin/pip

# Upgrade PyTorch to a cu128 build for full Blackwell (sm_120) support.
# The base image ships PyTorch 2.4.1+cu121, which lacks sm_120 kernels and
# throws "no kernel image is available" on the RTX 5060 Ti (compute 12.0).
# (This replaces the base torch rather than removing it — the old cu121 wheel
# stays in a lower layer; acceptable cost for a pinned, working stack.)
RUN $PIP install --no-cache-dir --upgrade \
    torch==${TORCH} torchvision==${TORCHVISION} torchaudio==${TORCHAUDIO} \
    --index-url https://download.pytorch.org/whl/cu128

# Pin ComfyUI to a specific release tag (adds native Z-Image and FLUX.2 nodes,
# EmptyHunyuanLatentVideo, etc.) and install its dependencies. Fetching the tag
# explicitly at depth 1 works whether or not the base clone is shallow.
RUN cd /opt/ComfyUI \
    && git fetch --depth 1 origin "refs/tags/${COMFYUI_REF}:refs/tags/${COMFYUI_REF}" \
    && git checkout "${COMFYUI_REF}" \
    && $PIP install --no-cache-dir --upgrade -r /opt/ComfyUI/requirements.txt

# gguf package required by the ComfyUI-GGUF custom node (UNETLoaderGGUF), used by
# HunyuanVideo and Qwen-Image. Baked into the image so it survives container recreates.
RUN $PIP install --no-cache-dir "gguf==${GGUF}"
