from pathlib import Path
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[2]
files = sorted((root / "assets" / "weapons").glob("*.png"))
sheet = Image.new("RGB", (6 * 190, 4 * 220), "#263246")
draw = ImageDraw.Draw(sheet)
for i, path in enumerate(files):
    x, y = (i % 6) * 190, (i // 6) * 220
    with Image.open(path) as image:
        thumb = image.convert("RGBA").resize((180, 180), Image.Resampling.LANCZOS)
    sheet.paste(thumb, (x + 5, y + 5), thumb)
    draw.text((x + 5, y + 190), path.stem, fill="white")
sheet.save(root / "tools" / "art_review" / "weapons_sheet.png")
