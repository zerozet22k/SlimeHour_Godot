"""Checks that every card only uses stat keys, triggers, actions and conditions the engine handles.

python tools/validate.py
"""
import json, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
src = "\n".join(p.read_text(encoding="utf8") for p in (ROOT / "scripts").glob("*.gd"))
effects = (ROOT / "scripts/Effects.gd").read_text(encoding="utf8")
data = json.loads((ROOT / "data/cards.json").read_text(encoding="utf8"))
cards = data["cards"]
weapons = {w["id"] for w in json.loads((ROOT / "data/weapons.json").read_text(encoding="utf8"))}

# Stat keys must be read somewhere: st("key"), S.get("key"), S["key"] or wm(w, "key").
read_keys = set(re.findall(r'st\("([a-z_0-9]+)"\)', src)) | set(re.findall(r'S\.get\("([a-z_0-9]+)"', src)) \
    | set(re.findall(r'S\["([a-z_0-9]+)"\]', src)) | set(re.findall(r'wm\(w, "([a-z_0-9]+)"\)', src))
read_keys |= {"rerolls", "tdmg"}  # applied on pick / folded into S["more"] by Effects.recalc()
# Status chance keys are read through the STATUSES loop in Combat.hit().
statuses = re.search(r'const STATUSES = \[(.*?)\]', src).group(1)
read_keys |= set(re.findall(r'"([a-z]+)"', statuses))
# Actions are the match arms in Effects.act(); triggers are passed to Effects.trigger / tick / walked.
act_body = effects.split("static func act(")[1].split("static func ROAD")[0]
actions = set(re.findall(r'^\t\t"([a-z_]+)":', act_body, re.M))
triggers = set(re.findall(r'Effects\.trigger\(g, "([a-z]+)"', src)) | set(re.findall(r'trigger\(self, "([a-z]+)"', src))
triggers |= {"timer", "still", "lowhp", "walk"}
conditions = set(re.findall(r'^\t\t"([a-z]+)":\n\t\t\treturn', effects.split("static func condition")[1].split("static func tick")[0], re.M))

errors = []
for c in cards:
    cid = c["id"]
    for k in c["mods"]:
        if k not in read_keys:
            errors.append(f"{cid}: stat '{k}' is never read by the engine")
    for k in c.get("wmods", {}):
        if k not in read_keys:
            errors.append(f"{cid}: weapon mod '{k}' is never read")
    for p in c["procs"]:
        if p["on"] not in triggers:
            errors.append(f"{cid}: trigger '{p['on']}' is never fired")
        if p["do"] not in actions:
            errors.append(f"{cid}: action '{p['do']}' not implemented")
        if "if" in p and p["if"] not in conditions:
            errors.append(f"{cid}: condition '{p['if']}' not implemented")
    for w in c.get("req", {}).get("weapon", []):
        if w not in weapons:
            errors.append(f"{cid}: requires unknown weapon '{w}'")
    if not c["mods"] and not c["procs"] and not c.get("wmods") and not c.get("on_pick"):
        errors.append(f"{cid}: card does nothing")

print(f"{len(cards)} cards, {len(read_keys)} stat keys read, {len(actions)} actions, {len(triggers)} triggers, {len(conditions)} conditions")
for e in errors:
    print("FAIL", e)
print("OK" if not errors else f"{len(errors)} problems")
sys.exit(1 if errors else 0)
