"""Generate Crowd Rush art through the local AI Studio (http://127.0.0.1:7860).

Prompts live in tools/art_prompts.txt (one "path | mode | prompt" per line, sent exactly as written).
  python tools/gen_assets.py                 generate missing images
  python tools/gen_assets.py --redo          regenerate everything
  python tools/gen_assets.py --redo a,b,c    regenerate only these file names
  python tools/gen_assets.py --list-local    list images made by the local generator (assets/LOCAL_ART.json)
  python tools/gen_assets.py --model flux-klein --stage --cards --direct
      generate card scenes into tools/flux_staging without changing game assets
"""
import json, sys, time, urllib.request, urllib.parse, io, subprocess, tempfile
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[1]
BASE = "http://127.0.0.1:7860"

ICON_STYLE = ("cartoon video game icon, chunky bold shapes, thick black outline, vibrant saturated colors, "
              "glossy highlights, centered, single object, isolated on plain pure white background, no text, no letters")
CARD_STYLE = ("cartoon video game ability card illustration, bold chunky shapes, thick outlines, vibrant saturated colors, "
              "dramatic rim lighting, funny and energetic, dark navy background, centered composition, no text, no letters, no border")
WIDE_STYLE = ("cartoon video game key art, bold shapes, thick outlines, vibrant neon colors, dramatic lighting, "
              "dark night background, no text, no letters, no logo")


def post(path, data):
    req = urllib.request.Request(BASE + path, data=json.dumps(data).encode(), headers={"Content-Type": "application/json"})
    return json.loads(urllib.request.urlopen(req, timeout=120).read())


def get(path):
    return json.loads(urllib.request.urlopen(BASE + path, timeout=120).read())


SIZES = {"icon": (1024, 1024), "card": (1216, 832), "wide": (1536, 864)}


def generate(title, prompt, timeout=420, size=None, model="z-image"):
    thread = post("/api/threads", {"title": title, "kind": "asset"})
    tid = thread["id"]
    turn = post(f"/api/thread/{tid}/message", {"text": prompt, "mode": "exact", "llm": "qwen3:4b"})
    # The studio runs one job at a time; retry while it is busy.
    for _ in range(200):
        try:
            body = {"turn": turn["id"], "action": "new", "n": 1, "framing": "none", "image_model": model}
            if size:
                body["width"], body["height"] = size
            post(f"/api/thread/{tid}/generate", body)
            break
        except Exception:
            time.sleep(3)
    start = time.time()
    while time.time() - start < timeout:
        time.sleep(2)
        for t in get(f"/api/thread/{tid}")["turns"]:
            if t["id"] == turn["id"] and t.get("images"):
                url = BASE + "/file?p=" + urllib.parse.quote(t["images"][0])
                return Image.open(io.BytesIO(urllib.request.urlopen(url, timeout=120).read())).convert("RGB")
    raise TimeoutError(title)


def generate_direct(prompt, size, model):
    """Use ComfyUI directly without adding a conversation to AI Studio's sidebar."""
    studio_python = Path(r"C:\AI\ComfyUI_windows_portable\python_embeded\python.exe")
    generator = Path(r"C:\AI\tools\gen_images.py")
    with tempfile.TemporaryDirectory(prefix="crowdrush_art_") as tmp:
        tmp_path = Path(tmp)
        prompt_file = tmp_path / "prompt.txt"
        prompt_file.write_text(prompt, encoding="utf8")
        cmd = [str(studio_python), str(generator), "new", "--prompt-file", str(prompt_file),
               "--out", str(tmp_path), "--name", "card", "--n", "1", "--style", "none",
               "--width", str(size[0]), "--height", str(size[1]), "--model", model]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=420)
        if result.returncode:
            raise RuntimeError((result.stderr or result.stdout)[-1000:])
        paths = [line[6:].strip() for line in result.stdout.splitlines() if line.startswith("IMAGE ")]
        if not paths:
            raise RuntimeError("No image returned: " + result.stdout[-1000:])
        with Image.open(paths[0]) as image:
            return image.convert("RGB")


def key_white(img: Image.Image, size=256) -> Image.Image:
    """Remove the white backdrop connected to the border; keep black outlines intact."""
    a = np.asarray(img).astype(np.int16)
    near_white = (a.min(axis=2) > 222) & ((a.max(axis=2) - a.min(axis=2)) < 26)
    labels, _ = ndimage.label(near_white)
    border = set(np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))) - {0}
    background = np.isin(labels, list(border))
    background = ndimage.binary_dilation(background, iterations=1) & near_white | background
    alpha = np.where(background, 0, 255).astype(np.uint8)
    alpha = ndimage.gaussian_filter(alpha.astype(np.float32), 0.7).clip(0, 255).astype(np.uint8)
    rgba = np.dstack([a.astype(np.uint8), alpha])
    out = Image.fromarray(rgba, "RGBA")
    box = out.getbbox() or (0, 0, out.width, out.height)
    out = out.crop(box)
    side = max(out.width, out.height)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.paste(out, ((side - out.width) // 2, (side - out.height) // 2))
    return square.resize((size, size), Image.LANCZOS)


def card_crop(img: Image.Image) -> Image.Image:
    w, h = img.size
    if w > h:  # generated landscape already: just fit 420x290
        target_w = int(h * 420 / 290)
        left = (w - target_w) // 2
        return img.crop((left, 0, left + target_w, h)).resize((420, 290), Image.LANCZOS)
    target_h = int(w / 1.45)
    top = max(0, (h - target_h) // 2 - h // 20)
    return img.crop((0, top, w, top + target_h)).resize((420, 290), Image.LANCZOS)


def wide_crop(img: Image.Image) -> Image.Image:
    w, h = img.size
    target_h = int(w * 9 / 16)
    top = (h - target_h) // 2
    return img.crop((0, top, w, top + target_h)).resize((1280, 720), Image.LANCZOS)


def read_prompts(path):
    entries = []
    for line in Path(path).read_text(encoding="utf8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        line = line.split("   # TEXT-RISK")[0]
        parts = [x.strip() for x in line.split("|", 2)]
        if len(parts) == 3:
            entries.append({"out": parts[0], "mode": parts[1], "prompt": parts[2]})
    return entries


LOCAL_MANIFEST = ROOT / "assets" / "LOCAL_ART.json"


def mark_local(out, model):
    """Every image made by the local generator is listed in assets/LOCAL_ART.json,
    so it can be found and replaced with better art later (python tools/gen_assets.py --list-local)."""
    data = json.loads(LOCAL_MANIFEST.read_text(encoding="utf8")) if LOCAL_MANIFEST.exists() else {}
    data[out] = {"model": model, "date": time.strftime("%Y-%m-%d")}
    LOCAL_MANIFEST.write_text(json.dumps(data, indent=1, sort_keys=True), encoding="utf8")


def run(prompt_file, redo=None, model="z-image", output_root=ROOT, cards_only=False, direct=False):
    entries = read_prompts(prompt_file)
    if cards_only:
        entries = [e for e in entries if e["out"].startswith("assets/cards/")]
    if redo == "all":
        todo = entries
    elif redo:
        names = set(redo.split(","))
        todo = [e for e in entries if Path(e["out"]).stem in names]
    else:
        todo = [e for e in entries if not (output_root / e["out"]).exists()]
    print(f"{len(todo)} of {len(entries)} images to generate", flush=True)
    for i, e in enumerate(todo):
        out = output_root / e["out"]
        out.parent.mkdir(parents=True, exist_ok=True)
        mode = e.get("mode", "card")
        try:
            if direct:
                img = generate_direct(e["prompt"], SIZES.get(mode, SIZES["card"]), model)
            else:
                img = generate("crowdrush-" + out.stem, e["prompt"], size=SIZES.get(mode), model=model)
        except Exception as ex:
            print("FAILED", e["out"], ex, flush=True)
            continue
        if mode == "icon":
            img = key_white(img)
        elif mode == "card":
            img = card_crop(img)
        else:
            img = wide_crop(img)
        img.save(out)
        if output_root == ROOT:
            mark_local(e["out"], model)
        print(f"[{i + 1}/{len(todo)}] {e['out']}", flush=True)


if __name__ == "__main__":
    args = sys.argv[1:]
    if "--list-local" in args:
        data = json.loads(LOCAL_MANIFEST.read_text(encoding="utf8")) if LOCAL_MANIFEST.exists() else {}
        for k, v in sorted(data.items()):
            print(k, v["model"], v["date"])
        print(len(data), "locally generated images")
        sys.exit(0)
    model = args[args.index("--model") + 1] if "--model" in args else "z-image"
    if model not in ("z-image", "flux-klein"):
        sys.exit("--model must be z-image or flux-klein")
    redo = None
    if "--redo" in args:
        i = args.index("--redo")
        redo = args[i + 1] if i + 1 < len(args) and not args[i + 1].startswith("-") else "all"
    output_root = ROOT / "tools" / "flux_staging" if "--stage" in args else ROOT
    run(ROOT / "tools" / "art_prompts.txt", redo, model, output_root, "--cards" in args, "--direct" in args)
