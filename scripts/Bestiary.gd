extends RefCounted
## Bestiary combat descriptions, kept separate from card collection data.
const EnemyMixes = preload("res://scripts/EnemyMixes.gd")
const NOTES = {"blob":["BASIC CHASER","Moves straight toward you.","Group blobs for piercing or area damage."],"zoomer":["SPRINTER","Fast movement, low HP.","Defeat before it reaches you."],"spitter":["RANGED","Fires aimed shots; triple spread after Sector 6.","Strafe its projectiles."],"kaboomba":["FUSE BOMBER","Arms an 0.8-second fuse when killed or contacted; its blast also hurts nearby slimes.","Dash away from the blinking corpse before it explodes."],"chonk":["HEAVY","High HP; uses a belly flop from Sector 4.","Leave the 115-unit slam telegraph."],"mitosis":["SPLITTER","Spawns two Minis when killed.","Keep an area attack ready."],"mini":["SMALL CHASER","Low-health minion spawned by other monsters.","Clear with wide fire."],"riot":["SHIELDED","Reduces direct hits from the direction its shield faces.","Flank it or use explosives."],"bull":["CHARGER","Pauses to telegraph a straight-line charge.","Dash sideways."],"mama":["SUMMONER","Spawns two Minis approximately every four seconds.","Prioritize before the crowd expands."],"mortar":["ARTILLERY","Marks where its predicted shell will land.","Move out of the marked circle."],"totem":["SHIELD AURA","Grants allies within 230 units 50% damage reduction against hits and burn, poison or bleed ticks.","Destroy it first to strip the shields from all nearby enemies. Totems cannot shield themselves."],"blinky":["TELEPORTER","Pauses, then teleports close to your location.","Leave its destination indicator."],"tick":["LATCHER","Can latch onto you at close range.","Push it away before contact."],"goblin":["LOOT","Runs away and disappears after twelve seconds.","Catch it for bonus gold."],"ashwing":["REVENANT PHOENIX","After a fatal hit it cocoons for 1.35 seconds and rises once at 42% HP.","Watch the bright rebirth ring, then finish it a second time."],"mirror":["MIRROR COUNTER","Weapon hits can trigger a delayed copy shot toward your last position.","The cyan line shows where to dodge; it does not reflect damage instantly."],"burrower":["AMBUSHER","Marks a nearby landing zone, burrows in, then pauses briefly after emerging.","Move off the sand ring and punish the slow emergence."],"siren":["MOB SUPPORT","Emits a 180-unit rally pulse, temporarily speeding up normal mobs, never bosses.","Take out the Siren before its allies receive another boost."],"skitter":["FLANKER","Sidesteps rapidly and winds up a short lunge.","Watch the cyan wind-up and dash sideways."],"sapper":["BOMB PLANTER","Marks a predicted landing spot with an explosive trap.","Leave the warning circle before the blast."],"lancer":["PIERCING SNIPER","Pauses to lock your movement, then fires a fast dart.","Dodge after the aiming line locks."],"leech":["LIFE DRAINER","Steals health on a successful melee contact and heals itself.","Keep it outside melee range."],"chonkzilla":["BOSS: SLAM","Telegraphed stomps, bullet shockwaves, and staggered impact lanes. Gets faster below 65% HP.","Dash through wave gaps and leave marked impact circles."],"heli":["BOSS: AIR","Alternates aimed bullets, marked carpet bombs, rotating rings, and Kaboomba drops.","Keep moving; dodge out of bomb lanes."],"necro":["BOSS: MAGIC","Homing skull fans, rotating cursed shots, soul-blast traps, and summoned slimes.","Bait skulls wide, avoid marked traps, clear summons."],"kingblob":["BOSS: SPLIT","Marked jump slams and delayed chasing impact zones; splits into smaller kings.","Save your dash for the marked landing."]}
## Every curated mutation has a teachable attack role and counterplay.
const FUSION_NOTES = {
	"flank": ["PREDICTIVE STRIKER", "Warns its target point, then lunges diagonally instead of using both parents' full AI.", "Leave its marked landing line, then punish its short recovery."],
	"mine": ["TRAP SPECIALIST", "Marks a predicted destination and detonates a delayed ground trap.", "Reverse direction after the marker appears; avoid standing still."],
	"echo": ["ECHO BARRAGE", "Locks your movement before firing a warned multi-shot fan.", "Strafe after the aim locks. On Hard, anticipate a wider five-shot spread."],
	"brood": ["BROOD GENERATOR", "Periodically spawns a small supporting minion, limited by the enemy population cap.", "Prioritize the mutation before it fills the road with reinforcements."]
}

static func info(kind: String) -> Array:
	var recipe = EnemyMixes.recipe_for_id(kind)
	if not recipe.is_empty():
		return FUSION_NOTES.get(str(recipe["style"]), ["MUTATION", "An adapted fusion monster.", "Learn its warning."])
	if kind.begins_with("mix_"):
		var pair = kind.trim_prefix("mix_").split("_")
		if pair.size() == 2:
			var secondary = str(pair[1])
			var traits = EnemyMixes.traits_for(secondary)
			var inherited = str(traits[posmod(kind.hash(), traits.size())])
			return [
				"BODY-PART MUTATION: " + inherited.to_upper(),
				"One inherited " + inherited.replace("_", " ") + " feature from " + secondary.capitalize() + ". The base face stays intact.",
				"Combat traits from both parents can combine. Watch the inherited body feature and control the higher-threat ability."
			]
		return ["MUTATION", "A body-part variation from two familiar species.", "Identify both attacks and avoid being surrounded."]
	return NOTES.get(kind, ["UNKNOWN", "No information available.", "Watch this enemy carefully."])
