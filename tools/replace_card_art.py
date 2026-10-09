"""Install one user-approved card PNG: python tools/replace_card_art.py twin_barrels C:/path/image.png"""

import argparse
import json
from pathlib import Path
from shutil import copy2
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
cards = json.loads((ROOT / "data/cards.json").read_text(encoding="utf-8"))["cards"]
ids = {card["id"] for card in cards}
parser = argparse.ArgumentParser(description="Replace one Crowd Rush card illustration")
parser.add_argument("card_id", choices=sorted(ids))
parser.add_argument("image", type=Path)
args = parser.parse_args()

target = ROOT / "assets/cards" / f"{args.card_id}.png"
backup = ROOT.parent / "CrowdRush_local_staging/user_replacements_backup" / f"{args.card_id}.png"
with Image.open(args.image) as source:
    image = ImageOps.fit(source.convert("RGB"), (420, 290), method=Image.Resampling.LANCZOS)
if target.exists() and not backup.exists():
    backup.parent.mkdir(parents=True, exist_ok=True)
    copy2(target, backup)
image.save(target)
print(f"Installed {target}")
print("Restart the Godot game to refresh its cached texture.")
