"""Contact sheet of staged local cards with their actual gameplay descriptions."""

import argparse
import json
import textwrap
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
STAGE = ROOT.parent / "CrowdRush_local_staging" / "cards"
OUT = ROOT.parent / "CrowdRush_local_staging" / "card_review"

parser = argparse.ArgumentParser()
parser.add_argument("--start", type=int, default=0)
parser.add_argument("--count", type=int, default=12)
args = parser.parse_args()

cards = json.loads((ROOT / "data" / "cards.json").read_text(encoding="utf8"))["cards"]
staged = [c for c in cards if (STAGE / f"{c['id']}.png").exists()]
chosen = staged[args.start : args.start + args.count]
cols = 3
cell_w, cell_h = 430, 360
rows = (len(chosen) + cols - 1) // cols
sheet = Image.new("RGB", (cols * cell_w, max(1, rows) * cell_h), "#172237")
draw = ImageDraw.Draw(sheet)
font = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 16)
bold = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 18)

for i, card in enumerate(chosen):
    x, y = i % cols * cell_w, i // cols * cell_h
    with Image.open(STAGE / f"{card['id']}.png") as im:
        sheet.paste(im.convert("RGB"), (x + 5, y + 5))
    draw.text((x + 6, y + 298), card["id"], fill="#ffd24d", font=bold)
    lines = textwrap.wrap(card["desc"], width=47)[:2]
    for j, line in enumerate(lines):
        draw.text((x + 6, y + 321 + j * 18), line, fill="white", font=font)

OUT.mkdir(parents=True, exist_ok=True)
path = OUT / f"sheet_{args.start:03d}.png"
sheet.save(path)
print(path, len(chosen), "of", len(staged), "staged")
