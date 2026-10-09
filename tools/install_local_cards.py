"""Install named, visually reviewed local card images from staging."""

import sys
from pathlib import Path
from shutil import copy2
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
STAGE = ROOT.parent / "CrowdRush_local_staging" / "cards"
LIVE = ROOT / "assets" / "cards"

if len(sys.argv) < 2:
    raise SystemExit("Pass reviewed card IDs to install")
for cid in sys.argv[1:]:
    if not cid.replace("_", "").isalnum():
        raise SystemExit(f"Invalid card ID: {cid}")
    source = STAGE / f"{cid}.png"
    target = LIVE / f"{cid}.png"
    if target.exists():
        raise SystemExit(f"Already installed: {cid}")
    with Image.open(source) as image:
        if image.size != (420, 290):
            raise SystemExit(f"Wrong image size: {cid} {image.size}")
        corners = [image.getpixel(p) for p in [(0, 0), (419, 0), (0, 289), (419, 289)]]
        if all(min(pixel[:3]) > 230 for pixel in corners):
            image.crop((12, 9, 408, 281)).resize((420, 290), Image.Resampling.LANCZOS).save(target)
        else:
            copy2(source, target)
    print(f"installed {cid}")
