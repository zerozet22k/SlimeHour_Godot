extends RefCounted
## Bestiary combat descriptions, kept separate from card collection data.
const EnemyMixes = preload("res://scripts/EnemyMixes.gd")
const NOTES = {"blob":["LIVING BARRICADE","Nearby Blobs link to block short passages.","Disperse the pack with knockback or wide fire."],"zoomer":["MOMENTUM PREDATOR","Orbits in fast lateral sprints and builds momentum.","Cut across its path to force a slower turn."],"spitter":["ACID RIBBONS","Fires curving acid hooks and contaminates the road.","Avoid contaminated lanes and pressure its retreat."],"kaboomba":["CHAIN BOMBER","The death fuse explodes and arms nearby Kaboombas.","Detonate inside enemy packs, then escape the chain."],"skitter":["COMMITTED OVERDASH","Locks and rushes past without steering; obstacle impact stuns it.","Bait a rush into an obstacle or road edge."],"sapper":["PROXIMITY ENGINEER","Deploys persistent armed mines that detonate when approached.","Shoot mines before crossing or navigate around them."],"mirror":["WEAPON IMITATOR","Copies an incoming projectile's motion as a weaker spectral countershot.","Vary your fire and move after its warning."],"burrower":["TUNNEL FISSURE","Travels underground; tunnel collapse leaves a lingering crack.","Evade the tunnel's entire line, not just its exit."],"leech":["SUSTAINED SIPHON","Builds a health-draining blood tether until range or cover breaks it.","Break the beam with an obstacle or escape its range."],"ashwing":["DESTRUCTIBLE COCOON","First death becomes a 1.35s cocoon before returning with an ember nova.","Shoot the cocoon to prevent its resurrection."],"siren":["HORDE COMMAND","Rallies nearby monsters into a synchronized advance.","Kill the Siren before its next command."],"riot":["SLOW-TURN SHIELD","Cuts front-facing projectile damage by 85%, exposing its back.","Circle and shoot the uncovered rear."],"bull":["BULLDOZER","Charges through crowds and shoves movable road wreckage.","Flank the charge and clear its pushed obstacles."],"mortar":["ARTILLERY SALVO","Bombards a predicted escape corridor with successive shells.","Change direction between landing warnings."],"lancer":["PIERCING INTERCEPTOR","Aims down one warned narrow corridor and fires a fast piercing dart.","Exit the warned corridor sideways."],"tick":["LATCHING PARASITE","Attaches and slows the player until removed.","Dash or bash to shake parasites loose."],"mama":["EGG NESTER","Plants fragile nests that hatch into Minis after a countdown.","Destroy eggs before they hatch."],"totem":["DEFENSIVE ANCHOR","Visible links halve damage to nearby allies, including DoT.","Destroy the unshielded Totem first."],"blinky":["DIMENSIONAL CROSSFIRE","Teleports and attacks from both its destination and old-position echo.","Avoid both rift origins."],"chonk":["BELLY BREAKER","Heavy belly slam leaves a briefly exposed belly.","Bait the slam, then punish recovery."],"mitosis":["DISRUPTABLE DIVISION","Splits into Minis unless a status or strong finishing hit interrupts it.","Finish with burst or disabling effects."],"mini":["COWARDLY FLANKER","Scatters when aimed at, then returns from another angle.","Use wide-area damage and keep turning."],"goblin":["TREASURE ESCAPIST","Runs toward the road edge while avoiding the player.","Catch it before twelve seconds."],"nurse":["EMERGENCY MEDIC","Rescues injured allies with interruptible treatment.","Kill it for a guaranteed healing heart on either difficulty."],"larry":["SWEEPING LASER","Late-game: charges a continuous sweeping beam, then overheats.","Hide behind solid cover and punish the exposed overheat."],
"chonkzilla":["EARTHQUAKE BARRAGE","Maintains rotating bullet curtains and aimed volleys even during charges. Cracked armor unlocks stone crossfire and broken bullet rings.","Slip through the moving projectile gaps. The short charge glow locks its direction; a stone or wall collision stops its fire and breaks its armor."],
"heli":["AERIAL HUNTER","Follows strafing routes with dropped bombs and warning-locked guided missiles.","Leave bombing lanes and dodge or outrun the missile after lock."],
"necro":["SOUL COMMANDER","Leeches health through destructible anchors and possesses an undead soldier.","Eliminate ward anchors and possessed soldiers before confronting the commander."],
"kingblob":["LIVING MASS","Devours fragments to heal and grow; splits fast bodies around your last position.","Destroy detached mass before the King can consume it."],
"coilqueen":["BURROWING CONSTRICTOR","Closes venom walls, breeds hatchlings and erupts beneath a fixed warning.","Break the constriction, clear hatchlings and move after the ground warning locks."],
"glassoracle":["MOVEMENT ECHO","Shielded by mirror clones; fires delayed shots from your previous position.","Destroy mirrors to expose her, then move away from your past movement trail."],
"voidweaver":["GRAVITY ARCHITECT","Teleports between two warned rifts and plants temporary projectile-bending gravity knots.","Track both portal origins and leave the gravity radius."],
"dreadengine":["ARMORED SIEGE ENGINE","Operates sequential piston crushers and destructible armor pods that feed reactor heat.","Shoot armor pods, evade crossed crushers, and punish the overheated core."]}
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
