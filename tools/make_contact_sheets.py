"""Build labeled contact sheets for reviewing the staged card art."""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "tools" / "flux_staging" / "assets" / "cards"
DEST = ROOT / "tools" / "art_review"
DEST.mkdir(exist_ok=True)

files = sorted(SOURCE.glob("*.png"))
for start in range(0, len(files), 30):
    batch = files[start:start + 30]
    sheet = Image.new("RGB", (5 * 280, 6 * 225), "#182033")
    draw = ImageDraw.Draw(sheet)
    for i, path in enumerate(batch):
        x, y = (i % 5) * 280, (i // 5) * 225
        with Image.open(path) as image:
            thumb = image.convert("RGB").resize((270, 186), Image.Resampling.LANCZOS)
        sheet.paste(thumb, (x + 5, y + 4))
        draw.text((x + 6, y + 194), path.stem[:38], fill="white")
    sheet.save(DEST / f"contact_{start // 30 + 1:02d}.jpg", quality=90)
print(f"{len(files)} staged cards, {(len(files) + 29) // 30} contact sheets")
