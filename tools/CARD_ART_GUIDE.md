# CrowdRush card art guide

Use `data/cards.json` as the source of truth for each card's gameplay effect. The short `art` phrase is an idea, not a complete image specification. Check the result against `desc` before putting it in `assets/cards/`.

## Visual anchors

- Hero: `assets/ui/hero.png` — adult cowboy with a brown hat, brass goggles, brown hair, and red scarf. Keep this identity when a card shows the player.
- Enemies: colorful, simple jelly blobs. Use `assets/cards/chain_lightning.png` for their current style.
- Action: large, readable at card size. Show one clear event, with room around the focal point.
- Projectiles: state the direction explicitly. For a left-to-right shot, every bullet tip faces right and its motion trail stays behind it on the left.
- Gameplay: if the effect splits, chains, pierces, returns, or fires backward, show its actual before-and-after path. Count targets and branches when the card description gives a count.
- Format: landscape illustration, dark neon battlefield, bold outlines, saturated color, no text, card frame, or UI.

## Review gate

1. Read the card's `desc` and effect before writing its prompt.
2. Specify source, direction, target, and visible result. Use a game image as a style reference when generating.
3. Inspect the full image and a small preview. Reject wrong-facing bullets, reversed guns, extra barrels/limbs, unrelated props, and art that does not explain the effect.
4. Put only approved images in `assets/cards/`. Keep experimental generations outside the Godot project.
5. Count missing assets after each batch; a successful generator response does not mean the set is complete.

## Reviewed examples

- `cluster_rounds.png`: one right-facing bullet branches into five right-facing bullets.
- `eyes_back.png`: the canonical hero has one visible rear eye.
- `fractal.png`: a right-facing bullet splits into medium fragments, then smaller fragments.
- `chain_lightning.png`: one hit arcs through three more enemies.
- `corpse_explosion.png`: a killed blob explodes next to other blobs.
- `domino_effect.png`: blasts propagate from one blob to the next.

The previous 57-image FLUX batch was rejected and moved to `C:/Users/zet22/Downloads/CrowdRush_backup_original/rejected_flux_cards/`. It must not be copied into the live asset folder without individual review.
