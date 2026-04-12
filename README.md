# image-gen

Vivy server image generation stack. Two independent tools:

- **ComfyUI** — SDXL and FLUX.1-schnell, accessible at `http://vivy:8188`
- **Z-Image-Turbo** — Tongyi-MAI's model, accessed via a local Mac client that calls a server on Vivy

> Both share the same 16 GB GPU and **cannot run at the same time**. The Z-Image start script handles this automatically (pauses ComfyUI, restarts it on exit).

---

## First-time setup (run once on Vivy)

```bash
# 1. Fix directory ownership for rootless Podman
bash scripts/setup.sh

# 2. Build the image and start ComfyUI
podman-compose up -d --build

# 3. Download ComfyUI models (SDXL + FLUX.1-schnell)
bash scripts/download_models.sh
```

The `data/` directory lives at `/mnt/wdc4tb/vivy/comfyui-data` with a symlink at `data/` in the repo root — models are stored on the 4 TB drive.

---

## ComfyUI

Open `http://vivy:8188` in a browser.

**SDXL** — works with the default workflow out of the box.
| Setting | Value |
|---|---|
| Checkpoint | `sd_xl_base_1.0.safetensors` |
| Steps | 20–30 |
| Sampler | euler |
| Scheduler | karras |
| Size | 1024×1024 |

**FLUX.1-schnell** — load the FLUX workflow (UNETLoader → DualCLIPLoader → KSampler → VAEDecode).
| Setting | Value |
|---|---|
| Model | `unet/flux1-schnell-fp8.safetensors` |
| VAE | `vae/ae.safetensors` |
| CLIP | `clip_l.safetensors` + `t5xxl_fp8_e4m3fn.safetensors` |
| Steps | 4–8 |
| Sampler | euler |
| Scheduler | simple |
| CFG | 1.0 |

Images are saved on Vivy at `/mnt/wdc4tb/vivy/comfyui-data/output/`.

### Start / stop ComfyUI

```bash
podman-compose up -d      # start
podman-compose down       # stop
podman-compose logs -f    # tail logs
```

---

## Z-Image-Turbo

### On Vivy — start the inference server

```bash
bash scripts/zimage_start_server.sh
```

- First run downloads the model (~33 GB) to `/mnt/wdc4tb/vivy/z-image-turbo` and creates a venv at `/mnt/wdc4tb/vivy/z-image-venv`.
- ComfyUI is paused automatically and restarted when you Ctrl-C.
- Server listens on port `8190`.

### On your Mac — generate images

```bash
# One-time: install the requests library
pip install requests

# Generate
python client/zimage.py "a photo of a cat on the moon"
python client/zimage.py "cyberpunk city at night" --steps 30 --seed 42
python client/zimage.py "portrait" --width 768 --height 1280

# Custom server address (if vivy isn't in /etc/hosts)
python client/zimage.py "landscape" --server http://192.168.1.100:8190
# or
ZIMAGE_SERVER=http://192.168.1.100:8190 python client/zimage.py "landscape"
```

Images save to `~/Pictures/zimage/` and open automatically in Preview.

**All options:**
```
positional:
  prompt

optional:
  --server URL            default: http://vivy:8190 (or $ZIMAGE_SERVER)
  --negative-prompt TEXT
  --steps INT             default: 20
  --guidance-scale FLOAT  default: 3.5
  --width INT             default: 1024
  --height INT            default: 1024
  --seed INT
  --output-dir PATH       default: ~/Pictures/zimage
  --no-open               don't open the image after saving
```

### Check server health

```bash
curl http://vivy:8190/health
# {"status":"ok","model_loaded":true}
```

---

## Troubleshooting

**`CUDA out of memory`** — ComfyUI is still running and holding VRAM. The start script should stop it automatically; if it didn't, run `podman stop vivy-comfyui` manually.

**`Cannot reach server`** — the Z-Image server isn't running on Vivy, or port 8190 isn't reachable. SSH to Vivy and run `bash scripts/zimage_start_server.sh`.

**`no kernel image is available`** — PyTorch version doesn't support the RTX 5060 Ti (sm_120). Rebuild the ComfyUI image: `podman-compose up -d --build`.

**Permission denied on ComfyUI data dirs** — re-run `bash scripts/setup.sh`.
