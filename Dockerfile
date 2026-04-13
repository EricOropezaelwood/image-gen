FROM ghcr.io/ai-dock/comfyui:latest-cuda

# Upgrade PyTorch to 2.7+ with CUDA 12.8 for full Blackwell (sm_120) support.
# The base image ships PyTorch 2.4.1+cu121 which lacks sm_120 kernels and
# throws "no kernel image is available" on RTX 5060 Ti / compute 12.0.
RUN /opt/environments/python/comfyui/bin/pip install --upgrade \
    torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/cu128

# Pull latest ComfyUI (adds EmptyHunyuanLatentVideo and other new nodes)
# and install its updated dependencies (sqlalchemy, alembic, etc.)
RUN cd /opt/ComfyUI \
    && git fetch origin \
    && git checkout master \
    && git pull origin master \
    && /opt/environments/python/comfyui/bin/pip install --upgrade \
       -r /opt/ComfyUI/requirements.txt

# gguf package required by ComfyUI-GGUF custom node (UNETLoaderGGUF).
# Must be in the image so it survives container recreates.
RUN /opt/environments/python/comfyui/bin/pip install gguf
