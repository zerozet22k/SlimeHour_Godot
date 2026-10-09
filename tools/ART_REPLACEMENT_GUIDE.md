# Replace Crowd Rush art yourself

Open [art_gallery.html](art_gallery.html) in a browser. Search by the card's displayed name (for example, **Twin Barrels**). Each tile shows the current image, its file path, gameplay effect, and a copyable generation prompt. The gallery covers all 300 cards and 22 guns; missing images are marked.

Card art is in `assets/cards/`; gun art is in `assets/weapons/`. The game loads images by ID, so `assets/cards/twin_barrels.png` is the Twin Barrels card. The prompt catalog is `tools/art_prompts.txt`. `data/cards.json` contains each card's gameplay effect. The gallery can be regenerated with `python tools/make_art_gallery.py` after adding new cards.

## Twin Barrels prompt for ChatGPT Images

> Create a 3:2 landscape illustration for a colorful cartoon action game card. Show ONE compact orange and gunmetal sci-fi blaster in a slightly elevated side view, pointed RIGHT. It has ONE grip and trigger, and exactly TWO clearly separate cylindrical barrel tubes stacked vertically at the front; both barrel openings are visible and point RIGHT. Each barrel fires exactly ONE cyan-tipped orange bullet to the RIGHT, making two parallel rightward shots. Both bullet tips point right and their short motion trails stay to the left. Use thick dark navy outlines, polished cel shading, vivid orange and cyan highlights, and a simple dark indigo battlefield background. Keep the gun and both bullets large and readable at thumbnail size. No shot to the left, no third barrel, no extra gun, no writing, no card frame, no ground shadow.

Attach a good existing card such as `assets/cards/chain_lightning.png` as a **style reference** if you want a closer match to the game's art. Check the result before installing it: two visible right-facing barrels, two rightward bullets, one grip.

To install your downloaded image, run from the project folder:

```powershell
python tools/replace_card_art.py twin_barrels "C:\path\to\your\download.png"
```

The helper crops it to the game's 420 × 290 card format and backs up the previous PNG outside the project. Restart the running Godot game so it loads the replacement. For another card, use its ID from the gallery instead of `twin_barrels`.
