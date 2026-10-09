"""Generate Crowd Rush art with Google Gemini image models instead of the local studio.

Needs your key in the environment (never paste it into a file in the project):
    PowerShell:  $env:GEMINI_API_KEY = "..."      cmd:  set GEMINI_API_KEY=...

    python tools/gen_gemini.py --list            show the image models your key can use
    python tools/gen_gemini.py --test 3          make 3 sample images into tools/gemini_test/ to judge quality/cost
    python tools/gen_gemini.py                   generate every image that is missing
    python tools/gen_gemini.py --redo            replace every image Gemini has not made yet (resumable)
    python tools/gen_gemini.py --redo a,b        regenerate these names        add --all to include ones Gemini already made
    python tools/gen_gemini.py --model NAME      pick a model (default: best image model found for your key)

Prompts are the same lines as tools/art_prompts.txt. Gemini understands negation, so a short
"no text" rule is added here (it would backfire on the local model).
"""
import io, os, sys, time
from pathlib import Path
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gen_assets as ga  # reuse prompt parsing + background keying + cropping

ROOT = Path(__file__).resolve().parents[1]
RULE = (" Absolutely no text, letters, numbers, words, logos, watermarks, signatures, frames or borders anywhere in the image."
        " Match a consistent cohesive art style across a set of game assets.")
ASPECT = {"icon": "1:1", "card": "3:2", "wide": "16:9"}
PREFERRED = ["gemini-3.1-flash-image", "gemini-3-pro-image", "gemini-2.5-flash-image"]


def client():
    key = os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY")
    if not key:
        sys.exit("Set GEMINI_API_KEY first (see the top of this file).")
    from google import genai
    return genai.Client(api_key=key)


def image_models(c):
    names = []
    for m in c.models.list():
        n = m.name.removeprefix("models/")
        if "image" in n and "gemini" in n:
            names.append(n)
    return names


def pick_model(c, wanted=None):
    if wanted:
        return wanted
    names = image_models(c)
    for pref in PREFERRED:
        hits = sorted([n for n in names if n.startswith(pref)], key=lambda n: ("preview" in n, n))
        if hits:
            return hits[0]
    sys.exit("No Gemini image model available for this key. Models seen: " + ", ".join(names))


def generate(c, model, prompt, mode, retries=6):
    from google.genai import types
    cfg = types.GenerateContentConfig(response_modalities=["IMAGE"],
                                      image_config=types.ImageConfig(aspect_ratio=ASPECT.get(mode, "1:1")))
    for attempt in range(retries):
        try:
            r = c.models.generate_content(model=model, contents=prompt + RULE, config=cfg)
            for part in r.candidates[0].content.parts:
                if getattr(part, "inline_data", None) and part.inline_data.data:
                    return Image.open(io.BytesIO(part.inline_data.data)).convert("RGB")
            raise RuntimeError("no image in response")
        except Exception as ex:
            if "402" in str(ex) or "prepayment credits are depleted" in str(ex).lower():
                raise RuntimeError("Gemini prepaid credits are depleted") from None
            wait = 8 * (attempt + 1)
            print(f"   retry in {wait}s: {str(ex)[:160]}", flush=True)
            time.sleep(wait)
    raise RuntimeError("gave up")


def finish(img, mode):
    if mode == "icon":
        return ga.key_white(img)
    if mode == "card":
        return ga.card_crop(img)
    return ga.wide_crop(img)


def main():
    args = sys.argv[1:]
    c = client()
    if "--list" in args:
        print("\n".join(image_models(c)))
        return
    model = pick_model(c, args[args.index("--model") + 1] if "--model" in args else None)
    print("model:", model, flush=True)
    entries = ga.read_prompts(ROOT / "tools" / "art_prompts.txt")
    if "--test" in args:
        n = int(args[args.index("--test") + 1])
        out = ROOT / "tools" / "gemini_test"
        out.mkdir(exist_ok=True)
        picks = [e for e in entries if e["mode"] == "card"][:n]
        for e in picks:
            finish(generate(c, model, e["prompt"], e["mode"]), e["mode"]).save(out / Path(e["out"]).name)
            print("test ->", out / Path(e["out"]).name, flush=True)
        return
    if "--redo" in args:
        i = args.index("--redo")
        names = args[i + 1].split(",") if i + 1 < len(args) and not args[i + 1].startswith("-") else None
        todo = [e for e in entries if names is None or Path(e["out"]).stem in names]
    else:
        todo = [e for e in entries if not (ROOT / e["out"]).exists()]
    # tools/gemini_done.txt remembers what Gemini already made, so a re-run never pays twice.
    done_file = ROOT / "tools" / "gemini_done.txt"
    already = set(done_file.read_text(encoding="utf8").split()) if done_file.exists() else set()
    if "--all" not in args:
        todo = [e for e in todo if e["out"] not in already]
    jobs = int(args[args.index("--jobs") + 1]) if "--jobs" in args else 4
    print(f"{len(todo)} images to generate with {jobs} parallel requests", flush=True)
    done = [0]

    def one(e):
        try:
            img = finish(generate(c, model, e["prompt"], e["mode"]), e["mode"])
        except Exception as ex:
            print("FAILED", e["out"], ex, flush=True)
            return
        (ROOT / e["out"]).parent.mkdir(parents=True, exist_ok=True)
        img.save(ROOT / e["out"])
        with open(done_file, "a", encoding="utf8") as f:
            f.write(e["out"] + chr(10))
        done[0] += 1
        print(f"[{done[0]}/{len(todo)}] {e['out']}", flush=True)

    from concurrent.futures import ThreadPoolExecutor
    with ThreadPoolExecutor(max_workers=jobs) as pool:
        list(pool.map(one, todo))


if __name__ == "__main__":
    main()
