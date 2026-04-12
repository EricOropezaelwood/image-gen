#!/usr/bin/env python3
"""
Z-Image-Turbo inference API.
Loads the model once at startup, serves /generate over HTTP.

Start with:  bash scripts/zimage_start_server.sh
"""

import io
import os
import argparse
from pathlib import Path

import torch
from diffusers import DiffusionPipeline
from fastapi import FastAPI, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel

# ── Config ────────────────────────────────────────────────────────────────────
MODEL_PATH = os.environ.get(
    "ZIMAGE_MODEL", "/mnt/wdc4tb/vivy/z-image-turbo"
)

# ── App + model ───────────────────────────────────────────────────────────────
app = FastAPI(title="Z-Image-Turbo")
pipe = None


@app.on_event("startup")
async def load():
    global pipe
    print(f"[startup] Loading ZImagePipeline from {MODEL_PATH}...")
    pipe = DiffusionPipeline.from_pretrained(
        MODEL_PATH,
        trust_remote_code=True,
        torch_dtype=torch.bfloat16,
    ).to("cuda")
    print("[startup] Model ready.")


# ── Request schema ────────────────────────────────────────────────────────────
class GenerateRequest(BaseModel):
    prompt: str
    negative_prompt: str = ""
    steps: int = 20
    guidance_scale: float = 3.5
    width: int = 1024
    height: int = 1024
    seed: int | None = None


# ── Endpoints ─────────────────────────────────────────────────────────────────
@app.get("/health")
def health():
    return {"status": "ok", "model_loaded": pipe is not None}


@app.post("/generate")
def generate(req: GenerateRequest):
    if pipe is None:
        raise HTTPException(503, "Model not loaded yet")

    generator = None
    if req.seed is not None:
        generator = torch.Generator("cuda").manual_seed(req.seed)

    print(f"[generate] prompt={req.prompt!r} steps={req.steps} seed={req.seed}")
    result = pipe(
        prompt=req.prompt,
        negative_prompt=req.negative_prompt or None,
        num_inference_steps=req.steps,
        guidance_scale=req.guidance_scale,
        width=req.width,
        height=req.height,
        generator=generator,
    )
    image = result.images[0]

    buf = io.BytesIO()
    image.save(buf, format="PNG")
    buf.seek(0)
    return StreamingResponse(buf, media_type="image/png")
