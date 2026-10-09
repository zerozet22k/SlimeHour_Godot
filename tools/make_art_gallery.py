"""Build a searchable local gallery of every game card and weapon image."""

import html
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
prompts = {}
for line in (ROOT / "tools/art_prompts.txt").read_text(encoding="utf-8").splitlines():
    parts = [part.strip() for part in line.split("|", 2)]
    if len(parts) == 3:
        prompts[parts[0]] = parts[2]

cards = json.loads((ROOT / "data/cards.json").read_text(encoding="utf-8"))["cards"]
weapons = json.loads((ROOT / "data/weapons.json").read_text(encoding="utf-8"))
entries = [("Card", card) for card in cards] + [("Weapon", weapon) for weapon in weapons]
tiles = []
for kind, item in entries:
    folder = "cards" if kind == "Card" else "weapons"
    relative = f"assets/{folder}/{item['id']}.png"
    image = ROOT / relative
    prompt = prompts.get(relative, "")
    name = html.escape(item["name"])
    desc = html.escape(item.get("desc", ""))
    path = html.escape(relative)
    category = html.escape(item.get("cat", "guns"))
    status = "ready" if image.exists() else "missing"
    tiles.append(
        f'<article class="tile" data-search="{html.escape((item["name"] + " " + item["id"] + " " + category + " " + item.get("desc", "")).lower(), quote=True)}" data-status="{status}">'
        f'<a href="../{path}" target="_blank"><div class="image">'
        + (f'<img src="../{path}" alt="{name}">' if image.exists() else '<span>IMAGE MISSING</span>')
        + '</div></a>'
        f'<div class="info"><small>{kind} · {category} · {status}</small><h2>{name}</h2><p>{desc}</p>'
        f'<code>{path}</code><details><summary>Generation prompt</summary><p class="prompt">{html.escape(prompt)}</p>'
        f'<button type="button" data-prompt="{html.escape(prompt, quote=True)}">Copy prompt</button></details></div></article>'
    )

output = ROOT / "tools/art_gallery.html"
output.write_text("""<!doctype html><html lang="en"><meta charset="utf-8"><title>Crowd Rush art gallery</title>
<style>
body{margin:0;background:#0b1020;color:#edf5ff;font:15px system-ui,sans-serif}header{position:sticky;top:0;z-index:2;background:#10182af2;padding:16px 24px;border-bottom:1px solid #375375}
h1{margin:0 0 12px;font-size:24px}input,select{background:#1b2941;color:white;border:1px solid #587393;border-radius:6px;padding:10px;font:inherit}input{width:min(440px,55vw)}
main{padding:22px;display:grid;grid-template-columns:repeat(auto-fill,minmax(250px,1fr));gap:16px}.tile{background:#151e31;border:1px solid #35506e;border-radius:8px;overflow:hidden}.tile[data-status=missing]{border-color:#a95057}
.image{height:165px;background:#211d34;display:grid;place-items:center;color:#fb8f98}.image img{width:100%;height:100%;object-fit:contain}.info{padding:12px}small{color:#6ee3ff;text-transform:uppercase}h2{margin:5px 0;font-size:19px}p{margin:7px 0 12px;color:#c0ccdc;min-height:38px}code{font-size:12px;word-break:break-all;color:#ffd06a}
details{margin-top:12px}summary{cursor:pointer;color:#90e8ff}.prompt{font-size:13px;line-height:1.5;min-height:0}button{background:#1a9fc1;color:white;border:0;border-radius:5px;padding:7px 11px;cursor:pointer}
</style><header><h1>Crowd Rush art gallery</h1><input id="search" placeholder="Search card name, effect, or ID…"> <select id="filter"><option value="all">All images</option><option value="ready">Existing</option><option value="missing">Missing</option></select> <span id="count"></span></header><main>
""" + "\n".join(tiles) + """</main><script>
const tiles=[...document.querySelectorAll('.tile')],search=document.querySelector('#search'),filter=document.querySelector('#filter'),count=document.querySelector('#count');
function update(){let n=0,q=search.value.toLowerCase().trim();for(const t of tiles){let show=t.dataset.search.includes(q)&&(filter.value==='all'||t.dataset.status===filter.value);t.hidden=!show;if(show)n++}count.textContent=n+' shown / '+tiles.length}
search.addEventListener('input',update);filter.addEventListener('change',update);update();
document.addEventListener('click',async e=>{if(e.target.matches('button[data-prompt]')){const p=e.target.dataset.prompt;try{if(navigator.clipboard){await navigator.clipboard.writeText(p)}else{const t=document.createElement('textarea');t.value=p;document.body.appendChild(t);t.select();document.execCommand('copy');t.remove()}e.target.textContent='Copied!';setTimeout(()=>e.target.textContent='Copy prompt',1200)}catch(err){e.target.textContent='Open prompt above to copy';}}});
</script></html>""", encoding="utf-8")
print(f"Wrote {output} with {len(entries)} entries")
