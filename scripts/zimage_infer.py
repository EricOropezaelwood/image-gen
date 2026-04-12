#!/usr/bin/env python3
"""Z-Image-Turbo inference — runs standalone, no ComfyUI required."""

import argparse
import datetime
from pathlib import Path

import torch
from diffusers import DiffusionPipeline


def main():
    parser = argparse.ArgumentParser(description="Run Z-Image-Turbo inference")
    parser.add_argument("prompt", help="Text prompt")
    parser.add_argument("--model", required=True, help="Path to Z-Image-Turbo directory")
    parser.add_argument("--negative-prompt", default="", help="Negative prompt")
    parser.add_argument("--steps", type=int, default=20, help="Inference steps")
    parser.add_argument("--guidance-scale", type=float, default=3.5)
    parser.add_argument("--width", type=int, default=1024)
    parser.add_argument("--height", type=int, default=1024)
    parser.add_argument("--seed", type=int, default=None)
    parser.add_argument("--output-dir", default="/mnt/wdc4tb/vivy/z-image-output")
    args = parser.parse_args()

    print(f"[info] Loading ZImagePipeline from {args.model}...")
    pipe = DiffusionPipeline.from_pretrained(
        args.model,
        trust_remote_code=True,
        torch_dtype=torch.bfloat16,
    ).to("cuda")

    generator = None
    if args.seed is not None:
        generator = torch.Generator("cuda").manual_seed(args.seed)

    print(f"[info] Generating: {args.prompt!r}")
    result = pipe(
        prompt=args.prompt,
        negative_prompt=args.negative_prompt or None,
        num_inference_steps=args.steps,
        guidance_scale=args.guidance_scale,
        width=args.width,
        height=args.height,
        generator=generator,
    )
    image = result.images[0]

    out_dir = Path(args.output_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    out_path = out_dir / f"zimage_{ts}.png"
    image.save(out_path)
    print(f"[done] {out_path}")


if __name__ == "__main__":
    main()
