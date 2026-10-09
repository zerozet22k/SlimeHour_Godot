"""Stage CrowdRush art with the user's local AI Studio models.

Examples:
  python tools/local_art_batch.py --weapons revolver,splitbow --model flux-klein
  python tools/local_art_batch.py --cards --limit 20 --model z-image

Results stay outside the Godot project until they are reviewed.
"""

import argparse
import json
from pathlib import Path
from PIL import Image

from gen_assets import card_crop, generate_direct, key_white
from local_card_scenes import SCENES as CARD_SCENES


ROOT = Path(__file__).resolve().parents[1]
STAGE = ROOT.parent / "CrowdRush_local_staging"
WEAPON_STYLE = (
    "One collectible item icon for a colorful cartoon top-down action game. "
    "The defining silhouette must match the named object. For guns, strict side profile with muzzle pointing RIGHT. "
    "Polished flat cel shading, thick dark navy outline, simple chunky silhouette, small clean highlights. "
    "Unified palette: warm amber-orange body, dark gunmetal barrel, cyan trim, brown grip. "
    "The weapon floats centered on a featureless pure white background with generous white margins. "
    "Only the weapon is visible; the white area beneath it is empty. No platform, floor, stand, cast shadow, glow, text or frame. "
)
CARD_STYLE = (
    "A polished 3:2 landscape game action illustration for a colorful top-down action game. "
    "Enemies are small colorful jelly blobs. Bold dark outlines, vivid colors, glossy highlights, dark indigo battlefield. "
    "One close-up focal action, correct physical direction and cause/result, simple composition. Illustration only. "
)
def weapon_prompt(weapon):
    wid = weapon["id"]
    subjects = {
        "revolver": "A classic six-chamber cowboy revolver with a visibly ROUND rotating cylinder, one straight barrel, curved trigger guard and wooden hand grip.",
        "smg": "A compact submachine gun with a large ROUND DRUM MAGAZINE hanging below the center, short barrel pointing right, folding stock at left.",
        "grenade": "A stubby grenade launcher with an oversized round revolving grenade drum below its body and a wide hollow muzzle pointing right.",
        "flame": "A flamethrower with a large rounded fuel canister strapped below its body, a hose feeding a wide nozzle pointing right, and one tiny flame at the tip.",
        "disc": "A single ROUND THROWING DISC seen at an angle, like a flying frisbee, with a thick amber ring and cyan serrated metal edge. Completely circular object, no gun parts or handle.",
        "boomerang": "A single V-SHAPED THROWING BOOMERANG, two curved wooden arms joined at the center, amber wood with cyan edge stripes. No trigger or gun parts.",
        "bees": "A bulbous beehive-shaped launcher: striped rounded honeycomb body, tiny nozzle pointing right, wooden grip below, two small bees on top.",
        "bowling": "A stubby bowling-ball cannon with a large shiny black BOWLING BALL visibly loaded in its wide circular muzzle, orange body and cyan trim.",
        "nailgun": "A recognizable construction nail gun with a long straight strip of silver nails as its magazine under the body, blunt muzzle pointing right, compact orange tool body.",
        "chicken": "A silly chicken launcher: one yellow rubber chicken visibly sticking out of the wide barrel on the right, orange body, wooden grip.",
        "bubble": "A toy bubble blaster with a wide ring-shaped muzzle pointing right and three floating iridescent soap bubbles at its tip, chunky orange body.",
        "pinball": "A pinball cannon with a spring plunger at the back and one shiny STEEL PINBALL visible in its open round muzzle at the right.",
        "snow": "A little snow cannon with a frosty cyan wide muzzle at the right and one large white snowball emerging from it, compact orange body.",
        "splitbow": "A compact fantasy crossbow in three-quarter top view. A broad pair of curved bow limbs visibly spans across the front of the stock, forming a wide V shape, with a taut string connecting their tips. A single long cyan arrow sits down the central rail and points RIGHT. Brown wooden stock and trigger grip below. The wide bow limbs and string dominate the silhouette, so it reads instantly as a crossbow rather than a firearm.",
    }
    subject = subjects.get(wid, weapon["art"].capitalize() + ".")
    return subject + " " + WEAPON_STYLE


def card_prompt(card):
    scene = CARD_SCENES.get(card["id"])
    if scene:
        return scene + " " + CARD_STYLE
    hero = "If the player is visible, show the adult cowboy in a brown hat, brass goggles and red scarf. " if "you" in card["desc"].lower() or "your" in card["desc"].lower() else ""
    return (
        f'Gameplay action to depict: {card["desc"]} '
        + "Depict only the objects involved in this effect, as one close-up instant in a single continuous scene. "
        + hero
        + "Show the mechanic with the right source, target, direction and visible result. "
        + "For bullets, pointed tips face their travel direction and trails stay behind. "
        + "If a specific count is given, draw that count. If a pickup drops, it emerges from the defeated enemy. "
        + CARD_STYLE
    )


def trim_card_border(image):
    corners = [image.getpixel(p) for p in [(0, 0), (419, 0), (0, 289), (419, 289)]]
    if all(min(pixel[:3]) > 230 for pixel in corners):
        image = image.crop((12, 9, 408, 281)).resize((420, 290), Image.Resampling.LANCZOS)
    return image


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--weapons", nargs="?", const="all")
    parser.add_argument("--cards", action="store_true")
    parser.add_argument("--limit", type=int, default=0)
    parser.add_argument("--redo", default="", help="Comma-separated IDs to regenerate even if staged")
    parser.add_argument("--model", choices=("z-image", "flux-klein"), default="flux-klein")
    args = parser.parse_args()
    if not args.weapons and not args.cards:
        parser.error("select --weapons or --cards")
    jobs = []
    if args.weapons:
        weapons = json.loads((ROOT / "data" / "weapons.json").read_text(encoding="utf8"))
        wanted = {x.strip() for x in args.weapons.split(",")}
        redo = {x.strip() for x in args.redo.split(",")}
        for weapon in weapons:
            if args.weapons == "all" or weapon["id"] in wanted:
                if weapon["id"] not in redo and (STAGE / "weapons" / (weapon["id"] + ".png")).exists():
                    continue
                jobs.append(("weapon", weapon, weapon_prompt(weapon)))
    if args.cards:
        cards = json.loads((ROOT / "data" / "cards.json").read_text(encoding="utf8"))["cards"]
        for card in cards:
            live = ROOT / "assets" / "cards" / (card["id"] + ".png")
            staged = STAGE / "cards" / (card["id"] + ".png")
            redo = {x.strip() for x in args.redo.split(",")}
            if not live.exists() and (not staged.exists() or card["id"] in redo):
                jobs.append(("card", card, card_prompt(card)))
    if args.limit > 0:
        jobs = jobs[: args.limit]
    print(f"Staging {len(jobs)} images with {args.model}", flush=True)
    for index, (kind, entry, prompt) in enumerate(jobs, 1):
        out = STAGE / ("weapons" if kind == "weapon" else "cards") / (entry["id"] + ".png")
        out.parent.mkdir(parents=True, exist_ok=True)
        try:
            image = generate_direct(prompt, (768, 768) if kind == "weapon" else (1024, 704), args.model)
            image = key_white(image) if kind == "weapon" else trim_card_border(card_crop(image))
            image.save(out)
            print(f"[{index}/{len(jobs)}] {entry['id']} -> {out}", flush=True)
        except Exception as exc:
            print(f"FAILED {entry['id']}: {exc}", flush=True)


if __name__ == "__main__":
    main()
