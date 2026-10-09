"""Install visually reviewed local weapon renders, preserving originals outside the game."""

from pathlib import Path
from shutil import copy2
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
STAGE = ROOT.parent / "CrowdRush_local_staging"
BACKUP = STAGE / "original_weapons"
ACCEPTED = (
    "pistol", "revolver", "shotgun", "smg", "minigun", "sniper", "rocket",
    "laser", "tesla", "flame", "rail", "bees", "nailgun", "chicken",
    "bubble", "pinball", "splitbow", "grenade", "snow",
)

BACKUP.mkdir(parents=True, exist_ok=True)
for wid in ACCEPTED:
    candidate = STAGE / "weapons" / f"{wid}.png"
    live = ROOT / "assets" / "weapons" / f"{wid}.png"
    with Image.open(candidate) as im:
        assert im.size == (256, 256) and im.mode == "RGBA", candidate
        assert im.getextrema()[3][0] == 0, candidate
    original = BACKUP / f"{wid}.png"
    if not original.exists():
        copy2(live, original)
    copy2(candidate, live)
    print(f"installed {wid}")

# The original bowling cannon is clear, but its muzzle faced left.
live = ROOT / "assets" / "weapons" / "bowling.png"
original = BACKUP / "bowling.png"
if not original.exists():
    copy2(live, original)
with Image.open(original) as im:
    ImageOps.mirror(im).save(live)
print("oriented bowling")
