# image-gen

Vivy server image generation stack. Everything runs inside a single **ComfyUI** instance at `http://vivy:8188`:

- **Z-Image-Turbo** — Tongyi-MAI's 6B model. Fast, photorealistic — the default pick.
- **FLUX.2 [klein]** — 4B, best prompt adherence
- **Qwen-Image** — the specialist for legible text *inside* images
- **Anime** — NoobAI-XL / Illustrious-XL SDXL finetunes for illustrated/anime art
- **HunyuanVideo 1.5** — text-to-video
- **SDXL** / **FLUX.1-schnell** — older models, kept for their LoRA ecosystem

> All models share the same 16 GB GPU. ComfyUI loads and unloads them on demand, so you just switch workflows — no manual juggling.

---

## First-time setup (run once on Vivy)

```bash
# 1. Fix directory ownership for rootless Podman
bash scripts/setup.sh

# 2. Build the image and start ComfyUI
podman-compose up -d --build

# 3. Download Z-Image-Turbo (~16 GB) — the default image model
bash scripts/zimage_download.sh
```

Then download whichever other models you want (all optional, in any order):

```bash
bash scripts/flux2_download.sh        # FLUX.2 klein 4B — ~4.4 GB (reuses Z-Image encoder)
bash scripts/hunyuan_install.sh       # ComfyUI-GGUF node — needed for Qwen-Image & Hunyuan
bash scripts/qwen_image_download.sh   # Qwen-Image (text in images) — ~13 GB
bash scripts/anime_download.sh        # NoobAI-XL + Illustrious-XL (anime) — ~14 GB
bash scripts/download_models.sh       # legacy SDXL + FLUX.1-schnell
```

The `data/` directory lives at `/mnt/wdc4tb/vivy/comfyui-data` with a symlink at `data/` in the repo root — models are stored on the 4 TB drive.

---

## ComfyUI

Open `http://vivy:8188` in a browser. For new work, prefer **Z-Image-Turbo**
(default), **FLUX.2 klein** (prompt adherence), or **Qwen-Image** (text) below.
The two models here are older but kept for their large LoRA ecosystem.

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

Tongyi-MAI's 6B model — fast, photorealistic, and it runs **natively inside
ComfyUI** (no separate server or Mac client). The BF16 model fits in 16 GB VRAM
without CPU offload.

### Setup (run once on Vivy)

```bash
bash scripts/zimage_download.sh   # ~16 GB
```

### Generate images

Open `http://vivy:8188`, then **Workflows → Browse Templates → search "z-image" → Z-Image Turbo**.

| Node                | Value                                    |
| ------------------- | ---------------------------------------- |
| Load Diffusion Model | `z_image_turbo_bf16.safetensors`        |
| Load CLIP           | `qwen_3_4b.safetensors` (type: qwen_image) |
| Load VAE            | `ae.safetensors`                         |
| Steps               | 8–9 (distilled few-step model)           |
| CFG                 | 1.0                                      |
| Sampler             | euler                                    |
| Scheduler           | simple                                   |
| Size                | 1024×1024                                |

Images are saved on Vivy at `/mnt/wdc4tb/vivy/comfyui-data/output/`.

---

## FLUX.2 [klein]

Black Forest Labs' 4B model — the modern successor to FLUX.1-schnell, with
stronger prompt adherence. The fp8 build is only ~4 GB and shares the Qwen3-4B
text encoder with Z-Image.

### Setup (run once on Vivy)

```bash
bash scripts/flux2_download.sh   # ~4.4 GB (encoder reused from Z-Image)
```

### Generate images

Open `http://vivy:8188`, then **Workflows → Browse Templates → search "flux 2" → Flux 2 Klein**.

| Node                 | Value                             |
| -------------------- | --------------------------------- |
| Load Diffusion Model | `flux-2-klein-4b-fp8.safetensors` |
| Load CLIP            | `qwen_3_4b.safetensors`           |
| Load VAE             | `flux2-vae.safetensors`           |
| Steps                | 4–6 (distilled)                   |
| CFG                  | 1.0                               |
| Sampler              | euler                             |
| Scheduler            | simple                            |
| Size                 | 1024×1024                         |

---

## Qwen-Image

Alibaba's 20B model, run as a Q4_K_M GGUF (~13 GB) so it fits in 16 GB. Its
standout capability is rendering **legible text inside images** (signs, labels,
UI) — something SDXL/FLUX struggle with. Uses the ComfyUI-GGUF node and the
Qwen2.5-VL encoder already installed for HunyuanVideo.

### Setup (run once on Vivy)

```bash
bash scripts/hunyuan_install.sh       # if not already installed (ComfyUI-GGUF node)
bash scripts/qwen_image_download.sh   # ~13 GB (encoder reused from Hunyuan)
```

### Generate images

Open `http://vivy:8188`, then **Workflows → Browse Templates → search "qwen image" → Qwen-Image**,
and swap the Load Diffusion Model node for **UNETLoaderGGUF**.

| Node           | Value                                                 |
| -------------- | ----------------------------------------------------- |
| UNETLoaderGGUF | `qwen-image-Q4_K_M.gguf`                              |
| Load CLIP      | `qwen_2.5_vl_7b_fp8_scaled.safetensors` (qwen_image)  |
| Load VAE       | `qwen_image_vae.safetensors`                          |
| Steps          | ~20                                                   |
| CFG            | 2.5–4.0                                               |
| Sampler        | euler                                                 |
| Scheduler      | simple                                                |
| Size           | 1328×1328 (native) or 1024×1024                       |

---

## Anime (NoobAI-XL / Illustrious-XL)

For anime/illustrated art, the general models above fall short — the anime scene
runs on **SDXL finetunes** trained on Danbooru-tagged art. These are plain SDXL
checkpoints, so they use the **same default Load Checkpoint workflow as SDXL base**
(no extra nodes) and run easily on 16 GB.

### Setup (run once on Vivy)

```bash
bash scripts/anime_download.sh   # ~14 GB (both checkpoints)
```

- **NoobAI-XL v1.1** — Illustrious finetune, broadest anime character knowledge
- **Illustrious-XL v1.0** — clean neutral base

### Generate images

Use the default **Load Checkpoint** workflow and select one of the anime checkpoints.

| Setting   | Value                                        |
| --------- | -------------------------------------------- |
| Checkpoint | `NoobAI-XL-v1.1.safetensors` (or Illustrious) |
| Steps     | 24–28                                        |
| CFG       | 5–7                                          |
| Sampler   | euler_ancestral                              |
| Scheduler | normal                                       |
| Size      | 832×1216 (portrait) or 1024×1024             |

**Prompt with Danbooru tags, not sentences.** Quality tags matter:

```
Positive: masterpiece, best quality, newest, absurdres, 1girl, solo,
          silver hair, blue eyes, school uniform, cherry blossoms
Negative: worst quality, low quality, lowres, jpeg artifacts,
          bad anatomy, bad hands, extra digits, watermark, signature
```

> These finetunes are uncensored (typical of the anime-model scene) — lean on the
> negative prompt to steer output.

---

## HunyuanVideo 1.5 (Text-to-Video)

Runs inside ComfyUI via the ComfyUI-GGUF custom node. Uses the quantized GGUF
transformer (5 GB) so it fits comfortably in 16 GB VRAM without offloading —
significantly faster and better quality than the original HunyuanVideo BF16.

### Setup (run once on Vivy)

```bash
# 1. Install ComfyUI-GGUF custom node (restarts the container)
bash scripts/hunyuan_install.sh

# 2. Download models (~18 GB total)
bash scripts/hunyuan_download.sh
```

### Generate a video

Open `http://vivy:8188`, then **Workflows → Browse Templates → search "hunyuan 1.5" → Text-to-Video**.

| Node               | Value                                                 |
| ------------------ | ----------------------------------------------------- |
| UNETLoaderGGUF     | `unet/hunyuanvideo1.5_720p_t2v-Q4_K_M.gguf`           |
| DualCLIPLoader (1) | `text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors` |
| DualCLIPLoader (2) | `text_encoders/byt5_small_glyphxl_fp16.safetensors`   |
| Load VAE           | `vae/hunyuanvideo15_vae_fp16.safetensors`             |
| Steps              | 20–30                                                 |
| CFG                | 6.0                                                   |
| Resolution         | 848×480 (720p)                                        |
| Frames             | 25, 49, or 85 (must be `4n + 1`)                      |

### 1080p upscaling (optional second pass)

Add the SR node after generation using `diffusion_models/hunyuanvideo1.5_1080p_sr_distilled_fp16.safetensors`.
Settings: steps 6–8, CFG 1.0.

Videos are saved to `/mnt/wdc4tb/vivy/comfyui-data/output/`.

---

## Troubleshooting

**`CUDA out of memory`** — another model is still resident in VRAM. In ComfyUI, use **Manager → Unload Models** (or restart the container) before switching to a heavier workflow.

**`no kernel image is available`** — PyTorch version doesn't support the RTX 5060 Ti (sm_120). Rebuild the ComfyUI image: `podman-compose up -d --build`.

**Permission denied on ComfyUI data dirs** — re-run `bash scripts/setup.sh`.

## Host: `vivy`

MSI B450 TOMAHAWK (MS-7C02) desktop running Ubuntu (kernel 6.8.0-124-generic),
reachable at `192.168.50.82` on the LAN.

### Specs relevant to local AI workloads

| Component     | Detail                                     | Notes                                                                                                                                                                               |
| ------------- | ------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **GPU**       | NVIDIA GeForce RTX 5060 Ti, **16 GB** VRAM | Primary accelerator for both LLM and Stable Diffusion. Driver 590.48.01, CUDA 13.1, 180 W power cap.                                                                                |
| **CPU**       | AMD Ryzen 5 5600G (Cezanne APU)            | 6 cores / 12 threads, boost to ~4.46 GHz. AVX2 supported (useful for CPU-offloaded GGUF layers). Includes integrated Radeon graphics, so the NVIDIA card is fully free for compute. |
| **RAM**       | 48 GiB DDR4                                | Mixed kit (2×8 GB Corsair + 2×16 GB TeamGroup), running at **2133 MHz**. Ample for large model files and CPU offload, though clocked below the modules' rated speed.                |
| **OS disk**   | 240 GB Kingston SSD (`/`)                  | Root filesystem — keep the OS/container layer here.                                                                                                                                 |
| **Data disk** | 4 TB WD Red (`/mnt/wdc4tb`)                | Store model weights, LoRAs, checkpoints, and outputs here.                                                                                                                          |
| **Network**   | 1 GbE (Realtek, `enp34s0`)                 | IP `192.168.50.82`.                                                                                                                                                                 |

## Implications for local AI

- **VRAM is the binding constraint.** The RTX 5060 Ti's 16 GB comfortably runs
  7B–13B LLMs fully on GPU (quantized) and SDXL image generation. Larger models
  (30B+) need quantization plus CPU/RAM offload, which the 6-core Ryzen + 48 GB
  RAM can back.
- **LLM backend:** models are served by **ollama** (`llama-server`) on the GPU;
  anythingllm points at it. Leave headroom — a loaded 13B-class model already
  uses ~13 GB of the 16 GB.
- **Put weights on `/mnt/wdc4tb`**, not the 240 GB OS SSD — model libraries grow
  fast and the root disk is small.
- **Check GPU/VRAM usage:**
  ```bash
  nvidia-smi
  ```
