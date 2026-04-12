#!/usr/bin/env python3
"""
Z-Image-Turbo client — runs on your Mac, calls the inference server on Vivy.

Usage:
    python client/zimage.py "a photo of a cat on the moon"
    python client/zimage.py "cyberpunk city" --steps 30 --seed 42 --width 1280 --height 720
    python client/zimage.py "portrait" --server http://192.168.1.100:8190

The server address can also be set via ZIMAGE_SERVER env var.
"""

import argparse
import datetime
import os
import subprocess
import sys
from pathlib import Path

try:
    import requests
except ImportError:
    sys.exit("requests is not installed. Run: pip install requests")


DEFAULT_SERVER = os.environ.get("ZIMAGE_SERVER", "http://vivy:8190")
OUTPUT_DIR = Path.home() / "Pictures" / "zimage"


def main():
    parser = argparse.ArgumentParser(description="Generate images via Z-Image-Turbo on Vivy")
    parser.add_argument("prompt", help="Text prompt")
    parser.add_argument("--server", default=DEFAULT_SERVER, help=f"Server URL (default: {DEFAULT_SERVER})")
    parser.add_argument("--negative-prompt", default="", help="Negative prompt")
    parser.add_argument("--steps", type=int, default=20, help="Inference steps (default: 20)")
    parser.add_argument("--guidance-scale", type=float, default=3.5, help="Guidance scale (default: 3.5)")
    parser.add_argument("--width", type=int, default=1024)
    parser.add_argument("--height", type=int, default=1024)
    parser.add_argument("--seed", type=int, default=None)
    parser.add_argument("--output-dir", type=Path, default=OUTPUT_DIR)
    parser.add_argument("--no-open", action="store_true", help="Don't open the image after saving")
    args = parser.parse_args()

    # Health check
    try:
        r = requests.get(f"{args.server}/health", timeout=5)
        r.raise_for_status()
        status = r.json()
        if not status.get("model_loaded"):
            sys.exit(f"Server responded but model isn't loaded yet: {status}")
    except requests.exceptions.ConnectionError:
        sys.exit(f"Cannot reach server at {args.server}. Is the server running?\n"
                 f"  ssh vivy 'bash ~/image-gen/scripts/zimage_start_server.sh'")

    payload = {
        "prompt": args.prompt,
        "negative_prompt": args.negative_prompt,
        "steps": args.steps,
        "guidance_scale": args.guidance_scale,
        "width": args.width,
        "height": args.height,
        "seed": args.seed,
    }

    print(f"[generate] prompt={args.prompt!r}  steps={args.steps}  seed={args.seed}")
    print(f"[generate] server={args.server}")

    try:
        r = requests.post(f"{args.server}/generate", json=payload, timeout=300, stream=True)
        r.raise_for_status()
    except requests.exceptions.HTTPError as e:
        sys.exit(f"Server error: {e}\n{r.text}")

    args.output_dir.mkdir(parents=True, exist_ok=True)
    ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    out_path = args.output_dir / f"zimage_{ts}.png"

    with open(out_path, "wb") as f:
        for chunk in r.iter_content(chunk_size=65536):
            f.write(chunk)

    print(f"[done] Saved to {out_path}")

    if not args.no_open:
        subprocess.run(["open", str(out_path)], check=False)


if __name__ == "__main__":
    main()
