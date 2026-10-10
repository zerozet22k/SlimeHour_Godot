"""Single source of truth for Crowd Rush content.

Run:  python tools/build_data.py
Writes data/weapons.json, data/enemies.json, data/cards.json and tools/asset_manifest.json.

Cards are built from two things the engine implements (scripts/Effects.gd):
  mods  - stat keys added per stack (see STAT_KEYS)
  procs - {"on": trigger, "do": action, ...params}
tools/validate.py checks every key/trigger/action against the GDScript source.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# --------------------------------------------------------------------------- weapons
# speed px/s, life s, rate shots/s, spread radians. lv3/lv5 are weapon-specific perks.
W = []
def weapon(id, name, kind, desc, art, **kw):
    d = dict(id=id, name=name, kind=kind, desc=desc, art=art)
    d.update(dict(dmg=10, rate=2, mag=10, reload=1.2, speed=800, life=0.8, pellets=1, spread=0.0,
                  pierce=0, bounce=0, rico=0, size=4, knock=60, recoil=0, crit=0.0, color="7ff7ea",
                  blast=0, lv3="", lv5="", sfx="shot"))
    d.update(kw)
    W.append(d)

weapon("pistol", "Peashooter", "bullet", "Reliable. The last bullet in the mag deals 3x damage.",
       "a cute chunky sci-fi pistol", dmg=12, rate=4.0, mag=12, reload=0.85, speed=860, life=0.8, knock=70,
       lv3="+1 bullet per shot", lv5="Every 6th shot also fires a ring of 8 bullets", color="8ff8ff", sfx="pew")
weapon("revolver", "Six Shooter", "bullet", "Six heavy rounds that pierce. Crits deal 3x instead of 2x.",
       "a gleaming cowboy revolver with neon trim", dmg=36, rate=2.2, mag=6, reload=1.5, speed=1050, life=0.8,
       pierce=1, crit=0.12, knock=150, size=5, lv3="+2 pierce", lv5="Starting a reload fans 6 shots in an arc",
       color="ffe28a", sfx="bang")
weapon("shotgun", "Boomstick", "pellet", "7 pellets with brutal knockback. The recoil shoves you backward.",
       "a sawed-off double barrel shotgun", dmg=9, rate=1.35, mag=4, reload=1.25, speed=760, life=0.4,
       pellets=7, spread=0.55, knock=230, recoil=150, lv3="+3 pellets", lv5="Pellets ricochet once",
       color="ffc66b", sfx="boom")
weapon("smg", "Buzz SMG", "bullet", "Sprays a hose of small bullets.",
       "a compact submachine gun with drum magazine", dmg=6, rate=12, mag=36, reload=1.35, speed=880, life=0.6,
       spread=0.16, knock=30, size=3.2, lv3="+50% magazine", lv5="Every 8th bullet explodes", color="9ff0ff", sfx="tick")
weapon("minigun", "Lawnmower", "spin", "Spins up to absurd fire rates. You walk slower while it spins.",
       "a huge six barrel minigun", dmg=6, rate=20, mag=160, reload=2.6, speed=920, life=0.75, spread=0.13,
       knock=40, size=3.4, lv3="Spins up twice as fast", lv5="Bullets ricochet once", color="ffe9a8", sfx="tick")
weapon("sniper", "Long Goodbye", "bullet", "Massive damage, pierces 6. Double damage to unhurt enemies.",
       "a long sleek sniper rifle with scope", dmg=95, rate=0.85, mag=4, reload=1.8, speed=2300, life=0.6,
       pierce=6, knock=280, recoil=90, size=5, lv3="Kills fire a free shot at the next target",
       lv5="Shots explode on every enemy they pierce", color="d8b8ff", sfx="snipe")
weapon("rocket", "Party Starter", "rocket", "Accelerating rockets that explode.",
       "a chunky rocket launcher with a pink rocket", dmg=46, rate=1.1, mag=3, reload=1.9, speed=380, life=1.5,
       blast=78, knock=260, size=6, lv3="+1 rocket per shot", lv5="Explosions leave burning puddles",
       color="ff8f6b", sfx="rocket")
weapon("grenade", "Bouncer", "grenade", "Lobbed grenades bounce off walls, then explode.",
       "a round cartoon grenade launcher", dmg=42, rate=1.4, mag=6, reload=1.6, speed=640, life=0.9, blast=92,
       bounce=3, knock=240, size=7, lv3="Explodes into 4 bomblets", lv5="+2 grenades per throw", color="b5ff6b",
       sfx="thunk")
weapon("laser", "Beam Me", "beam", "Continuous beam. Overheats after 3s of firing.",
       "a futuristic laser cannon glowing purple", dmg=7, rate=14, mag=0, reload=1.2, speed=0, life=0, pierce=1,
       knock=10, lv3="+1 beam", lv5="Never overheats and the beam is twice as wide", color="c58cff", sfx="")
weapon("tesla", "Zapper", "chain", "Lightning arcs between up to 4 enemies and shocks them.",
       "a tesla coil gun crackling with blue lightning", dmg=16, rate=3.0, mag=15, reload=1.4, speed=0, life=0,
       rico=3, knock=40, lv3="+3 chain jumps", lv5="Every arc forks into two", color="8fc8ff", sfx="zap")
weapon("flame", "Hot Take", "flame", "Short range cone of fire. Always burns.",
       "a flamethrower with a fuel tank", dmg=4, rate=30, mag=110, reload=2.0, speed=430, life=0.42, spread=0.38,
       pierce=99, knock=8, size=9, lv3="+40% range", lv5="Burning enemies explode when they die", color="ff9d4d",
       sfx="")
weapon("disc", "Frisbee of Doom", "disc", "Razor discs fly out and come back to you. Pierces everything.",
       "a glowing razor frisbee disc", dmg=22, rate=3.0, mag=2, reload=0, speed=780, life=0.42, pierce=999,
       knock=90, size=11, lv3="+1 disc", lv5="Discs ricochet between enemies", color="7dffb2", sfx="whoosh")
weapon("boomerang", "Boomer", "boomerang", "A heavy boomerang that curves and returns.",
       "a wooden boomerang with neon paint", dmg=28, rate=2.0, mag=1, reload=0, speed=640, life=0.55, pierce=999,
       knock=130, size=14, lv3="+1 boomerang", lv5="Boomerangs double in size on the way back", color="ffcf6b",
       sfx="whoosh")
weapon("rail", "Railgun", "rail", "Charge, then fire a line that pierces everything. Huge recoil.",
       "a sci-fi railgun with blue energy coils", dmg=150, rate=0.7, mag=3, reload=2.2, speed=0, life=0,
       pierce=999, knock=320, recoil=230, lv3="Charges twice as fast", lv5="Leaves a lightning line for 1.5s",
       color="7fd8ff", sfx="rail")
weapon("bees", "Beehive", "bees", "Releases angry homing bees that poison.",
       "a beehive shaped gun with cartoon bees", dmg=8, rate=1.4, mag=8, reload=1.8, speed=330, life=3.5,
       pellets=3, pierce=2, knock=20, size=4, lv3="+2 bees", lv5="Kills release a bee", color="ffd94d", sfx="buzz")
weapon("bowling", "Strike Cannon", "ball", "Bowling balls that send enemies flying into each other.",
       "a cannon that shoots bowling balls", dmg=40, rate=0.9, mag=3, reload=2.0, speed=430, life=1.8, pierce=999,
       knock=650, size=17, bounce=1, lv3="+1 ball", lv5="Balls split into 3 when they hit a wall",
       color="d9b3ff", sfx="thunk")
weapon("nailgun", "Nail Gun", "bullet", "Fast nails that can pin enemies in place.",
       "a yellow construction nail gun", dmg=9, rate=9, mag=40, reload=1.6, speed=1300, life=0.45, size=3,
       knock=20, lv3="Pins 70% of the time", lv5="Pinned enemies take +60% damage", color="e8e8e8", sfx="tick")
weapon("chicken", "Poultry Launcher", "chicken", "Fires rubber chickens that bounce between enemies, then explode.",
       "a launcher stuffed with rubber chickens", dmg=24, rate=1.6, mag=5, reload=1.6, speed=540, life=1.6, rico=4,
       blast=60, knock=120, size=9, lv3="+3 bounces", lv5="Every bounce drops an egg grenade", color="fff27a",
       sfx="honk")
weapon("bubble", "Bubble Blaster", "bubble", "Bubbles trap an enemy, then pop for area damage.",
       "a toy bubble gun with big soap bubbles", dmg=30, rate=1.8, mag=6, reload=1.5, speed=300, life=1.8, blast=55,
       size=14, knock=10, lv3="Bubbles trap up to 3 enemies", lv5="Pops release 6 mini bubbles", color="9fe8ff",
       sfx="bloop")
weapon("pinball", "Pinball", "bullet", "Bounces off walls 6 times, gaining damage with each bounce.",
       "a pinball cannon with a shiny steel ball", dmg=13, rate=5, mag=16, reload=1.2, speed=920, life=1.6,
       bounce=6, rico=1, size=5, knock=60, lv3="+4 wall bounces", lv5="Every wall bounce splits the ball",
       color="ff9df0", sfx="ping")
weapon("splitbow", "Splitbow", "bolt", "Crossbow bolts that split into 3 on the first hit.",
       "a futuristic crossbow with glowing bolts", dmg=30, rate=2.0, mag=6, reload=1.3, speed=1150, life=0.7,
       knock=90, size=4, lv3="Splits into 5", lv5="Fragments split again", color="9dffa8", sfx="twang")
weapon("snow", "Snow Cannon", "snow", "Snowballs grow as they fly and freeze what they hit.",
       "a snow cannon shooting snowballs", dmg=18, rate=2.0, mag=8, reload=1.4, speed=560, life=1.1, pierce=1,
       knock=120, size=7, lv3="Frozen enemies shatter for area damage", lv5="Snowballs grow twice as big",
       color="e6fbff", sfx="thunk")

# --------------------------------------------------------------------------- enemies
E = [
    dict(id="blob", name="Blob", hp=26, speed=95, dmg=10, r=15, xp=1, mass=1.0, color="ff7b93"),
    dict(id="zoomer", name="Zoomer", hp=14, speed=190, dmg=8, r=11, xp=1, mass=0.6, color="ffb36b"),
    dict(id="chonk", name="Chonk", hp=170, speed=55, dmg=22, r=30, xp=5, mass=4.0, color="e86a8a"),
    dict(id="spitter", name="Spitter", hp=34, speed=75, dmg=12, r=15, xp=2, mass=1.0, color="b6ff6b", range=270),
    dict(id="kaboomba", name="Kaboomba", hp=22, speed=150, dmg=30, r=15, xp=2, mass=0.8, color="ff5a4a"),
    dict(id="mitosis", name="Mitosis", hp=60, speed=80, dmg=12, r=22, xp=2, mass=1.6, color="7dffcf"),
    dict(id="mini", name="Mini", hp=20, speed=120, dmg=8, r=11, xp=1, mass=0.6, color="7dffcf"),
    dict(id="riot", name="Riot", hp=90, speed=70, dmg=14, r=20, xp=3, mass=2.5, color="8fb0ff"),
    dict(id="bull", name="Bull", hp=110, speed=70, dmg=20, r=24, xp=4, mass=3.0, color="ff9157"),
    dict(id="nurse", name="Nurse", hp=50, speed=70, dmg=8, r=16, xp=3, mass=1.0, color="ffffff", range=200),
    dict(id="larry", name="Laser Larry", hp=40, speed=60, dmg=22, r=15, xp=3, mass=1.0, color="ff5a8a", range=430),
    dict(id="mama", name="Mama Blob", hp=150, speed=45, dmg=16, r=28, xp=6, mass=3.5, color="ff9ad1"),
    dict(id="mortar", name="Mortar Mike", hp=60, speed=50, dmg=24, r=18, xp=4, mass=1.5, color="c9b27a", range=520),
    dict(id="totem", name="Hype Totem", hp=150, speed=0, dmg=0, r=21, xp=6, mass=60, color="7ad1ff"),
    dict(id="blinky", name="Blinky", hp=45, speed=85, dmg=18, r=14, xp=3, mass=0.8, color="c58cff"),
    dict(id="tick", name="Lil Tick", hp=26, speed=175, dmg=4, r=10, xp=2, mass=0.4, color="9dff6b"),
    dict(id="goblin", name="Gold Goblin", hp=70, speed=165, dmg=0, r=14, xp=3, mass=0.8, color="ffd24d"),
    dict(id="chonkzilla", name="CHONKZILLA", hp=2400, speed=45, dmg=30, r=62, xp=60, mass=40, color="e86a8a", boss=True),
    dict(id="heli", name="HELI-COPTER", hp=2000, speed=110, dmg=14, r=50, xp=60, mass=40, color="ffb36b", boss=True),
    dict(id="necro", name="NECRO-DAD", hp=2200, speed=60, dmg=16, r=48, xp=60, mass=40, color="b48cff", boss=True),
    dict(id="kingblob", name="KING BLOB", hp=1500, speed=70, dmg=20, r=58, xp=40, mass=30, color="ff7b93", boss=True),
]

# --------------------------------------------------------------------------- cards
CATS = {
    "volley": "VOLLEY", "projectile": "BULLETS", "chain": "CHAIN REACTION", "element": "ELEMENTS",
    "auto": "AUTO-WEAPONS", "move": "MOVEMENT", "defense": "DEFENSE", "loot": "LOOT", "chaos": "CHAOS",
    "mastery": "MASTERY",
}
C = []
def card(id, name, cat, rarity, mx, desc, art, mods=None, procs=None, req=None, wmods=None, cursed=False, on_pick=None):
    d = dict(id=id, name=name, cat=cat, rarity=rarity, max=mx, desc=desc, art=art, mods=mods or {}, procs=procs or [])
    if req: d["req"] = req
    if wmods: d["wmods"] = wmods
    if cursed: d["cursed"] = True
    if on_pick: d["on_pick"] = on_pick
    C.append(d)

def P(on, do, **kw):
    d = {"on": on, "do": do}
    d.update(kw)
    return d

# ---- 1. VOLLEY: how many things come out, and where they go
card("double_tap", "Double Tap", "volley", 0, 5, "+1 projectile per shot.", "two bullets flying side by side", {"mult": 1})
card("twin_barrels", "Twin Barrels", "volley", 0, 4, "+1 parallel projectile.", "a gun with two parallel barrels", {"par": 1})
card("eyes_back", "Eyes in the Back", "volley", 0, 3, "Also fire 1 projectile backward.", "a head with eyes on the back", {"rear": 1})
card("sidearms", "Sidearms", "volley", 1, 3, "Also fire 1 projectile out of each side.", "bullets shooting left and right", {"side": 1})
card("burst_mode", "Burst Mode", "volley", 1, 3, "Every shot repeats 0.07s later for free. -10% fire rate.", "three bullets in a quick burst", {"burst": 1, "rate": -0.10})
card("echo_chamber", "Echo Chamber", "volley", 1, 3, "0.35s after you fire, a ghost copy of the volley fires from the same spot (60% damage).", "ghostly echo of a gunshot", {"echo": 1})
card("spray_pray", "Spray and Pray", "volley", 0, 3, "+2 projectiles, -12% damage, +30% spread.", "a gun spraying wildly", {"mult": 2, "dmg": -0.12, "spreadp": 0.3})
card("tight_choke", "Tight Choke", "volley", 0, 3, "-40% spread, +10% damage.", "a narrow gun barrel choke", {"spreadp": -0.4, "dmg": 0.10})
card("twelve_oclock", "Twelve O'Clock", "volley", 2, 2, "Every 6th volley also fires a ring of 12 bullets.", "a clock face exploding with bullets", procs=[P("fire", "nova", nth=6, n=12, dmg=10)])
card("shotgun_wedding", "Shotgun Wedding", "volley", 1, 3, "Each volley has a 20% chance to also blast 5 pellets in a cone.", "a wedding cake with a shotgun", procs=[P("fire", "frags", chance=0.2, n=5, dmg=9, pattern="forward")])
card("hydra", "Hydra", "volley", 2, 2, "+2 projectiles and +1 parallel projectile.", "a three headed hydra breathing bullets", {"mult": 2, "par": 1})
card("bullet_hell", "Bullet Hell Mode", "volley", 3, 1, "+3 projectiles, +2 backward, +1 each side. -25% damage.", "a screen full of colorful bullets", {"mult": 3, "rear": 2, "side": 1, "dmg": -0.25})
card("lead_curtain", "Lead Curtain", "volley", 2, 2, "+2 parallel projectiles, -15% projectile speed.", "a curtain made of bullets", {"par": 2, "pspeed": -0.15})
card("gatling_mood", "Gatling Mood", "volley", 1, 3, "+35% fire rate, +25% spread.", "an excited gatling gun", {"rate": 0.35, "spreadp": 0.25})
card("speed_loader", "Speed Loader", "volley", 0, 4, "+35% reload speed.", "a revolver speed loader", {"reload": 0.35})
card("extended_mag", "Extended Mag", "volley", 0, 4, "+50% magazine size.", "a long extended magazine", {"mag": 0.5})
card("drum_mag", "Drum Magazine", "volley", 1, 2, "+120% magazine size, -15% reload speed.", "a round drum magazine", {"mag": 1.2, "reload": -0.15})
card("trigger_happy", "Trigger Happy", "volley", 0, 5, "+18% fire rate.", "a finger on a trigger with motion lines", {"rate": 0.18})
card("triple_espresso", "Triple Espresso", "volley", 1, 3, "+40% fire rate, +8% move speed, +15% spread. Jittery.", "three shaking espresso cups", {"rate": 0.40, "speed": 0.08, "spreadp": 0.15})
card("fan_hammer", "Fan the Hammer", "volley", 1, 2, "Starting a reload fans out 6 bullets forward.", "a hand fanning a revolver hammer", procs=[P("reload", "frags", n=6, dmg=12, pattern="forward")])
card("ambidextrous", "Ambidextrous", "volley", 1, 2, "With 2+ guns equipped: +20% fire rate and +1 projectile.", "two hands holding two guns", {"ambi": 1})
card("warning_shot", "Warning Shot", "volley", 0, 3, "Every 5th volley is huge: 2.5x size, 3x damage (+1x per extra stack).", "a giant bullet", {"bigshot": 1})
card("spiral_galaxy", "Spiral Galaxy", "volley", 2, 2, "Projectiles spiral outward. +1 projectile.", "a spiral galaxy of bullets", {"curve": 2.2, "mult": 1})
card("wobbly", "Wobbly Bullets", "volley", 0, 3, "Bullets wiggle like noodles. +8% damage.", "wiggly noodle bullets", {"wave": 18, "dmg": 0.08})
card("confetti_cannon", "Confetti Cannon", "volley", 1, 3, "Every 10th volley releases a damaging confetti explosion.", "a party confetti cannon", procs=[P("fire", "confetti", nth=10, dmg=25, r=95)])
card("compass_rose", "Compass Rose", "volley", 2, 2, "+1 projectile forward, backward and to each side.", "a compass rose made of bullets", {"mult": 1, "rear": 1, "side": 1})
card("overpressure", "Overpressure", "volley", 1, 3, "+35% projectile speed, +30% knockback.", "a gun barrel with pressure gauge", {"pspeed": 0.35, "knock": 0.3})
card("lazy_bullets", "Lazy Bullets", "volley", 0, 3, "-35% projectile speed, +40% size, +20% damage, +50% range.", "a sleepy bullet with a nightcap", {"pspeed": -0.35, "size": 0.4, "dmg": 0.2, "range": 0.5})
card("ammo_belt", "Ammo Belt", "volley", 0, 3, "+25% magazine, +15% reload speed.", "an ammo belt", {"mag": 0.25, "reload": 0.15})
card("shell_shock", "Shell Shock", "volley", 1, 2, "Starting a reload releases a knockback shockwave.", "a shockwave ring", procs=[P("reload", "shockwave", r=120, dmg=15, push=300)])

# ---- 2. BULLETS: what each projectile does in flight
card("piercing", "Piercing Rounds", "projectile", 0, 5, "+1 pierce.", "a bullet piercing through apples", {"pierce": 1})
card("drill_bits", "Drill Bits", "projectile", 1, 2, "+3 pierce, -10% projectile speed.", "a drill bit bullet", {"pierce": 3, "pspeed": -0.1})
card("rubber_bullets", "Rubber Bullets", "projectile", 0, 3, "+2 wall bounces, +20% knockback.", "a bouncy rubber bullet", {"bounce": 2, "knock": 0.2})
card("ricochet", "Ricochet", "projectile", 1, 4, "On hit, projectiles redirect to another enemy (+1 ricochet).", "a bullet ricocheting with sparks", {"rico": 1})
card("pinball_wizard", "Pinball Wizard", "projectile", 2, 2, "+2 ricochets and +2 wall bounces.", "a wizard playing pinball", {"rico": 2, "bounce": 2})
card("heat_seekers", "Heat Seekers", "projectile", 1, 3, "Projectiles home in on enemies.", "a heat seeking missile", {"homing": 2.5})
card("smart_rounds", "Smart Rounds", "projectile", 2, 2, "Strong homing, -10% projectile speed.", "a bullet wearing glasses", {"homing": 4.0, "pspeed": -0.1})
card("return_sender", "Return to Sender", "projectile", 2, 1, "Projectiles fly back to you at the end of their flight, hitting again.", "a boomerang shaped bullet", {"boomer": 1})
card("chonky_bullets", "Chonky Bullets", "projectile", 0, 4, "+35% projectile size, +8% damage.", "a fat round bullet", {"size": 0.35, "dmg": 0.08})
card("planet_bullets", "Planet Bullets", "projectile", 2, 2, "+100% size, +25% damage, +50% knockback, -20% speed.", "a bullet shaped like a planet", {"size": 1.0, "dmg": 0.25, "knock": 0.5, "pspeed": -0.2})
card("muzzle_velocity", "Muzzle Velocity", "projectile", 0, 3, "+25% projectile speed, +15% range.", "a bullet with speed lines", {"pspeed": 0.25, "range": 0.15})
card("long_range", "Long Range", "projectile", 0, 3, "+30% range, +20% damage to far enemies.", "a telescope", {"range": 0.3, "fardmg": 0.2})
card("point_blank", "Point Blank", "projectile", 0, 3, "+35% damage to enemies within 160px.", "a gun pressed to a monster nose", {"closedmg": 0.35})
card("hollow_points", "Hollow Points", "projectile", 1, 3, "+8% crit chance, +50% crit damage.", "a hollow point bullet", {"crit": 0.08, "critdmg": 0.5})
card("lucky_bullet", "Lucky Bullet", "projectile", 0, 4, "+6% crit chance.", "a bullet with a four leaf clover", {"crit": 0.06})
card("headhunter", "Headhunter", "projectile", 1, 3, "+100% crit damage.", "a crosshair over a monster head", {"critdmg": 1.0})
card("assassin", "Assassin", "projectile", 2, 2, "Non-boss enemies under 12% HP die instantly.", "a ninja assassin", {"execute": 0.12})
card("overkill", "Overkill", "projectile", 1, 1, "Excess damage from a kill jumps to the nearest enemy.", "a bullet bursting through two monsters", {"overkill": 1})
card("knockback_rounds", "Knockback Rounds", "projectile", 0, 3, "+60% knockback.", "a boxing glove bullet", {"knock": 0.6})
card("scope", "Scope", "projectile", 1, 3, "+40% damage to far enemies, +15% projectile speed.", "a sniper scope", {"fardmg": 0.4, "pspeed": 0.15})
card("sticky_bombs", "Sticky Bombs", "projectile", 2, 2, "20% of hits stick a bomb that explodes 0.6s later.", "a sticky bomb with a fuse", procs=[P("hit", "explode", chance=0.2, r=60, rel=1.0, delay=0.6)])
card("explosive_rounds", "Explosive Rounds", "projectile", 2, 3, "25% of hits explode for 60% of the hit's damage.", "an exploding bullet", procs=[P("hit", "explode", chance=0.25, r=55, rel=0.6)])
card("tracer_rounds", "Tracer Rounds", "projectile", 0, 3, "25% chance to mark enemies. Marked enemies take +25% damage.", "a glowing tracer bullet", {"mark": 0.25})
card("snake_shot", "Snake Shot", "projectile", 1, 2, "Bullets slither (big wiggle) and gain +1 pierce.", "a snake shaped bullet", {"wave": 32, "pierce": 1})
card("satellite_shot", "Satellite Shot", "projectile", 2, 2, "Every 3rd volley spawns an orbiting blade for 3s.", "a satellite orbiting a planet", procs=[P("fire", "orbital", nth=3, n=1, t=3)])
card("home_run", "Home Run", "projectile", 1, 2, "+100% knockback. Crits launch enemies like bowling balls.", "a baseball bat hitting a monster", {"knock": 1.0, "homerun": 1})
card("accelerator", "Accelerator", "projectile", 1, 2, "Projectiles speed up and gain damage as they fly.", "a bullet with rocket boosters", {"accel": 1})
card("dumdum", "Dumdum Rounds", "projectile", 1, 3, "30% bleed chance, +30% bleed damage.", "a blood drop bullet", {"bleed": 0.3, "bleedpow": 0.3})
card("armor_piercing", "Armor Piercing", "projectile", 1, 2, "Ignore Riot shields, +1 pierce, +30% damage to bosses and elites.", "an armor piercing tungsten bullet", {"ap": 1, "pierce": 1, "boss": 0.3})
card("ghost_rounds", "Ghost Rounds", "projectile", 2, 2, "+2 pierce, +10% damage. Bullets glow spooky.", "a ghost shaped bullet", {"pierce": 2, "dmg": 0.10})

# ---- 3. CHAIN REACTION: fragments, explosions, things that cause other things
card("splinter", "Splinter", "chain", 0, 3, "Projectiles burst into 2 fragments on hit (40% damage).", "a bullet splintering into pieces", {"split": 2})
card("shrapnel", "Shrapnel", "chain", 0, 3, "Kills burst into 3 fragments.", "metal shrapnel flying", {"splitkill": 3})
card("cluster_rounds", "Cluster Rounds", "chain", 2, 2, "+3 fragments on hit, +20% fragment damage.", "a cluster of small bullets", {"split": 3, "fragdmg": 0.2})
card("fractal", "Fractal", "chain", 3, 1, "Fragments can split again (one more generation).", "a fractal pattern of bullets", {"fractal": 1})
card("razor_fragments", "Razor Fragments", "chain", 1, 3, "+50% fragment damage.", "razor sharp metal shards", {"fragdmg": 0.5})
card("corpse_explosion", "Corpse Explosion", "chain", 1, 3, "30% of kills explode.", "a monster exploding into goo", procs=[P("kill", "explode", chance=0.3, r=65, dmg=18)])
card("chain_lightning", "Chain Lightning", "chain", 1, 3, "15% of hits arc lightning through 3 enemies.", "chain lightning between monsters", procs=[P("hit", "zap", chance=0.15, n=3, rel=0.7)])
card("domino_effect", "Domino Effect", "chain", 2, 2, "Explosions have a 25% chance to cause another explosion nearby.", "falling dominoes exploding", procs=[P("explosion", "explode", chance=0.25, r=55, dmg=14, offset=60)])
card("popcorn", "Popcorn", "chain", 1, 2, "Kills pop like popcorn: 6 tiny kernels fly everywhere.", "popcorn exploding from a bucket", procs=[P("kill", "frags", n=6, dmg=6, pattern="ring", say="POP")])
card("pinata", "Piñata", "chain", 1, 2, "6% of kills burst into gold coins and confetti.", "a colorful pinata bursting", procs=[P("kill", "confetti", chance=0.06, dmg=10, r=60), P("kill", "drop", chance=0.06, kind="gold", n=2)])
card("cascade", "Cascade", "chain", 2, 2, "Killing an elite fires a 16-bullet nova from its corpse.", "a waterfall of bullets", procs=[P("kill", "frags", n=16, dmg=20, pattern="ring", **{"if": "elite"})])
card("killstreak_rockets", "Killstreak Rockets", "chain", 2, 2, "Every 15 kills, launch 3 homing rockets.", "three homing rockets", procs=[P("kill", "rocket", nth=15, n=3, dmg=30)])
card("thunderclap", "Thunderclap", "chain", 1, 3, "20% of kills call down a lightning strike on a nearby enemy.", "a thundercloud striking", procs=[P("kill", "strike", chance=0.2, n=1, dmg=30)])
card("bouncy_fragments", "Bouncy Fragments", "chain", 1, 2, "Fragments bounce off walls twice and ricochet once.", "bouncy rubber shards", {"fragbounce": 1})
card("seeker_fragments", "Seeker Fragments", "chain", 1, 2, "Fragments home in on enemies.", "homing shards with eyes", {"fraghome": 1})
card("chain_reaction", "Chain Reaction", "chain", 3, 1, "Burning enemies explode when they die.", "a chain of fiery explosions", procs=[P("kill", "explode", r=75, dmg=25, color="ff8a4a", **{"if": "burning"})])
card("meat_grinder", "Meat Grinder", "chain", 2, 2, "25% of kills launch a rolling sawblade.", "a rolling sawblade", procs=[P("kill", "saw", chance=0.25, dmg=18)])
card("wall_splatter", "Wall Splatter", "chain", 1, 2, "Projectiles split into 2 fragments when they bounce off a wall.", "a bullet splattering on a wall", {"wallsplit": 2})
card("mitosis_rounds", "Mitosis Rounds", "chain", 2, 2, "Every 8th hit clones the bullet at full damage.", "a bullet dividing like a cell", procs=[P("hit", "frags", nth=8, n=1, rel=1.0, pattern="forward")])
card("spark_shower", "Spark Shower", "chain", 0, 3, "Crits throw 4 sparks in a ring.", "a shower of sparks", procs=[P("crit", "frags", n=4, rel=0.5, pattern="ring")])
card("aftershock", "Aftershock", "chain", 1, 2, "40% of explosions also release a knockback shockwave.", "an earthquake crack", procs=[P("explosion", "shockwave", chance=0.4, r=85, dmg=8, push=220)])
card("lightning_rod", "Lightning Rod", "chain", 1, 2, "30% of explosions arc lightning to 2 enemies.", "a lightning rod on a bomb", procs=[P("explosion", "zap", chance=0.3, n=2, dmg=15)])
card("volatile_fragments", "Volatile Fragments", "chain", 2, 1, "Fragments explode in a small blast when they hit.", "glowing unstable shards", {"fragboom": 1})
card("grim_echo", "Grim Echo", "chain", 1, 2, "15% of kills fire a free volley at the nearest enemy.", "a grim reaper with a gun", procs=[P("kill", "volley", chance=0.15, aim="nearest")])
card("combo_breaker", "Combo Breaker", "chain", 1, 2, "Every 25 kills unleashes a massive shockwave.", "a giant shockwave ring", procs=[P("kill", "shockwave", nth=25, r=230, dmg=40, push=450, at="hero", say="COMBO BREAKER!")])
card("balloon_animals", "Balloon Animals", "chain", 1, 2, "10% of kills release 3 floating bubbles that pop on enemies.", "a balloon dog", procs=[P("kill", "bubbles", chance=0.1, n=3, dmg=20)])
card("fireworks", "Fireworks", "chain", 2, 2, "12% of kills shoot a firework that bursts into 10 colorful sparks.", "fireworks exploding", procs=[P("kill", "frags", chance=0.12, n=10, dmg=15, pattern="ring", delay=0.35, colorful=1)])
card("bowling_pins", "Bowling Pins", "chain", 2, 1, "Enemies knocked back hard become projectiles that smash other enemies.", "bowling pins flying", {"fling": 1})
card("static_discharge", "Static Discharge", "chain", 1, 3, "Every 10th volley zaps 6 enemies.", "a crackling static ball", procs=[P("fire", "zap", nth=10, n=6, dmg=18)])
card("supernova", "Supernova", "chain", 3, 1, "Every 50 kills, detonate a screen-shaking supernova.", "an exploding star", procs=[P("kill", "explode", nth=50, r=270, dmg=120, at="hero", say="SUPERNOVA!"), P("kill", "slowmo", nth=50, t=0.5)])

# ---- 4. ELEMENTS: statuses and reactions
card("incendiary", "Incendiary", "element", 0, 3, "35% chance to set enemies on fire.", "a flaming bullet", {"burn": 0.35})
card("cryo_rounds", "Cryo Rounds", "element", 0, 3, "30% chance to chill. Fully chilled enemies freeze solid.", "an icy bullet", {"freeze": 0.3})
card("taser_tips", "Taser Tips", "element", 0, 3, "30% chance to shock. Shocked enemies zap their neighbours.", "a taser bullet with sparks", {"shock": 0.3})
card("venom", "Venom", "element", 0, 3, "40% chance to poison. Poison stacks.", "a dripping venom bullet", {"poison": 0.4})
card("serrated", "Serrated", "element", 0, 3, "35% chance to cause bleeding.", "a serrated blade bullet", {"bleed": 0.35})
card("molasses", "Molasses Rounds", "element", 0, 3, "40% chance to slow enemies.", "sticky molasses dripping", {"slow": 0.4})
card("hypnotic", "Hypnotic Rounds", "element", 2, 2, "4% chance to charm. Charmed enemies fight for you.", "a hypnotic spiral eye", {"charm": 0.04})
card("water_balloons", "Water Balloons", "element", 0, 2, "50% chance to soak enemies. Wet enemies take double shock and chill.", "a water balloon splashing", {"wet": 0.5})
card("hot_sauce", "Hot Sauce", "element", 1, 3, "+60% burn damage, +15% burn chance.", "a bottle of hot sauce on fire", {"burnpow": 0.6, "burn": 0.15})
card("deep_freeze", "Deep Freeze", "element", 1, 3, "+60% chill buildup, +10% chill chance.", "a frozen block of ice", {"freezepow": 0.6, "freeze": 0.1})
card("high_voltage", "High Voltage", "element", 1, 3, "+60% shock damage, +10% shock chance.", "a high voltage warning sign", {"shockpow": 0.6, "shock": 0.1})
card("neurotoxin", "Neurotoxin", "element", 1, 3, "+60% poison damage, +10% poison chance.", "a green toxic flask", {"poisonpow": 0.6, "poison": 0.1})
card("hemorrhage", "Hemorrhage", "element", 2, 1, "Bleed bursts for heavy damage at 5 stacks.", "a burst of red", {"hemorrhage": 1})
card("steam_engine", "Steam Engine", "element", 2, 1, "Burning + chilled enemies erupt in a steam explosion.", "a steam engine whistle", {"steam": 1})
card("overload", "Overload", "element", 2, 1, "Burning + shocked enemies explode.", "an overloaded electric fireball", {"overload": 1})
card("conductor", "Conductor", "element", 2, 1, "Shocking a wet enemy arcs to every wet enemy nearby.", "an orchestra conductor with lightning", {"conduct": 1})
card("shatter", "Shatter", "element", 2, 1, "Frozen enemies shatter into ice shards when killed.", "a shattering ice statue", {"shatter": 1})
card("wildfire", "Wildfire", "element", 1, 1, "Burning enemies spread fire to nearby enemies when they die.", "a spreading wildfire", {"wildfire": 1})
card("plague_doctor", "Plague Doctor", "element", 1, 1, "Poisoned enemies leave a poison cloud when they die.", "a plague doctor mask", {"plague": 1})
card("brainwashed", "Brainwashed", "element", 2, 1, "Charm lasts twice as long. Charmed enemies explode when they die.", "a brain in a washing machine", {"brainwash": 1})
card("rainbow_rounds", "Rainbow Rounds", "element", 3, 1, "+15% chance to burn, chill, shock and poison.", "a rainbow colored bullet", {"burn": 0.15, "freeze": 0.15, "shock": 0.15, "poison": 0.15})
card("napalm", "Napalm", "element", 1, 2, "Hitting burning enemies can leave fire on the ground.", "a napalm fire puddle", procs=[P("hit", "puddle", chance=0.1, s="fire", r=55, t=3, **{"if": "burning"})])
card("frost_nova", "Frost Nova", "element", 1, 2, "Getting hit freezes every enemy near you.", "an icy nova blast", procs=[P("hurt", "status_area", s="freeze", r=170, amt=100)])
card("static_field", "Static Field", "element", 1, 3, "Every 2s, zap 2 enemies near you.", "a static electric field", procs=[P("timer", "zap", every=2.0, n=2, dmg=12)])
card("toxic_trail", "Toxic Trail", "element", 1, 2, "Leave poison puddles as you run.", "toxic green footprints", procs=[P("walk", "puddle", every=90, s="poison", r=36, t=3, at="hero")])
card("ice_skates", "Ice Skates", "element", 0, 2, "+5% speed. Leave chilling ice as you run.", "a pair of ice skates", {"speed": 0.05}, procs=[P("walk", "puddle", every=120, s="ice", r=42, t=2.5, at="hero")])
card("thermal_shock", "Thermal Shock", "element", 2, 2, "+40% damage to enemies that are both burning and chilled.", "fire and ice clashing", {"thermal": 0.4})
card("oil_spill", "Oil Spill", "element", 1, 2, "Dashing spills oil. Fire on oil becomes a huge blaze.", "a black oil spill", procs=[P("dash", "puddle", s="oil", r=75, t=6, at="hero")])
card("voodoo", "Voodoo", "element", 1, 3, "+20% mark chance. Marked enemies take +25% more damage.", "a voodoo doll with pins", {"mark": 0.2, "markpow": 0.25})
card("frostbite", "Frostbite", "element", 1, 3, "+15% chill chance, +20% slow chance, +20% damage to chilled enemies.", "a frostbitten monster", {"freeze": 0.15, "slow": 0.2, "chilldmg": 0.2})

# ---- 5. AUTO-WEAPONS: things that fight on their own
card("spinny_blade", "Spinny Blade", "auto", 0, 6, "+1 blade orbiting you. Blades hit everything they touch.", "a spinning saw blade orbiting", {"orbit": 1})
card("blade_storm", "Blade Storm", "auto", 2, 2, "+3 orbiting blades, +20% blade damage.", "a storm of blades", {"orbit": 3, "orbitdmg": 0.2})
card("longer_chains", "Longer Chains", "auto", 0, 3, "+35% orbit radius.", "a long chain with a blade", {"orbitr": 0.35})
card("spin_cycle", "Spin Cycle", "auto", 0, 3, "+40% orbit speed.", "a washing machine spinning", {"orbspeed": 0.4})
card("sharpened_steel", "Sharpened Steel", "auto", 1, 3, "+50% orbit blade damage.", "a whetstone sharpening a blade", {"orbitdmg": 0.5})
card("gun_drone", "Gun Drone", "auto", 1, 4, "+1 drone that shoots enemies with your bullet upgrades.", "a small flying gun drone", {"drone": 1})
card("drone_swarm", "Drone Swarm", "auto", 2, 2, "+2 drones.", "a swarm of drones", {"drone": 2})
card("rocket_drones", "Rocket Drones", "auto", 2, 1, "Drones fire explosive rockets instead of bullets.", "a drone with rockets", {"dronerocket": 1}, req={"stat": "drone"})
card("sentry", "Sentry Turret", "auto", 1, 3, "Deploy a turret every 12s. It lasts 8s.", "a sentry turret", {"turret": 1})
card("mine_layer", "Mine Layer", "auto", 1, 3, "Drop a proximity mine every 150px you travel.", "a proximity mine blinking", {"mine": 1})
card("road_saw", "Road Saw", "auto", 1, 3, "A sawblade bounces around the road shredding enemies.", "a huge bouncing sawblade", {"sawblade": 1})
card("beehive_backpack", "Beehive Backpack", "auto", 1, 3, "Release 2 bees every 3s.", "a backpack beehive", {"beehive": 1})
card("pet_chicken", "Pet Chicken", "auto", 1, 3, "A chicken follows you and lays explosive eggs near enemies.", "a cute chicken with a bomb egg", {"chickenpet": 1})
card("unpaid_intern", "Unpaid Intern", "auto", 1, 3, "An intern follows you and plinks enemies with a pea shooter.", "a nervous intern holding a tiny gun", {"minion": 1})
card("ghost_twin", "Ghost Twin", "auto", 3, 1, "A ghost of you on the other side of the road copies every volley.", "a ghostly twin hero", {"ghost": 1})
card("halo", "Halo", "auto", 1, 3, "+1 orb that circles you and blocks enemy bullets.", "a glowing halo", {"orbshield": 1})
card("good_boy", "Good Boy", "auto", 2, 2, "A dog fetches enemies: dashes in and bites (bleed).", "a heroic dog", {"dog": 1})
card("tesla_coil", "Tesla Coil", "auto", 1, 3, "Every 1.5s, zap 3 nearby enemies.", "a tesla coil backpack", procs=[P("timer", "zap", every=1.5, n=3, dmg=14)])
card("meteor_buddy", "Meteor Buddy", "auto", 1, 3, "Every 5s, a meteor crashes into an enemy.", "a smiling meteor", procs=[P("timer", "meteor", every=5.0, dmg=60, r=85)])
card("airstrike", "Airstrike Beacon", "auto", 2, 2, "Every 12s, an airstrike carpet-bombs the road ahead.", "a fighter jet dropping bombs", procs=[P("timer", "airstrike", every=12.0, n=8, dmg=45)])
card("acme_anvils", "ACME Anvils", "auto", 1, 3, "Every 6s, an anvil falls on an enemy. BONK.", "a falling cartoon anvil", procs=[P("timer", "anvil", every=6.0, dmg=90, r=55, say="BONK!")])
card("boomerang_buddy", "Boomerang Buddy", "auto", 1, 3, "Automatically throw a boomerang every 2.5s.", "a boomerang mid-flight", procs=[P("timer", "boomerang", every=2.5, dmg=22)])
card("shoulder_rockets", "Shoulder Rockets", "auto", 1, 3, "Every 3s, fire 2 homing rockets.", "shoulder mounted rocket pods", procs=[P("timer", "rocket", every=3.0, n=2, dmg=25)])
card("laser_eyes", "Laser Eyes", "auto", 2, 2, "Every 1.2s, shoot a laser from your eyes at the nearest enemy.", "a face with red laser eyes", procs=[P("timer", "laser", every=1.2, dmg=30)])
card("orbit_gunners", "Orbit Gunners", "auto", 2, 1, "Orbiting blades also shoot at enemies every second.", "blades with tiny guns", {"orbitguns": 1}, req={"stat": "orbit"})
card("overclocked_drones", "Overclocked Drones", "auto", 1, 2, "+50% drone fire rate.", "a drone with a turbo", {"dronerate": 0.5}, req={"stat": "drone"})
card("ground_spikes", "Ground Spikes", "auto", 0, 3, "Every 4s, spikes burst from the ground around you.", "spikes bursting from ground", procs=[P("timer", "spikes", every=4.0, n=8, dmg=14)])
card("pocket_singularity", "Pocket Singularity", "auto", 3, 1, "Every 15s, open a black hole that swallows enemies.", "a black hole in a pocket", procs=[P("timer", "blackhole", every=15.0, r=190, t=3)])
card("buzzsaw_halo", "Buzzsaw Halo", "auto", 2, 2, "+2 orbiting blades, +30% blade damage, blades cause bleed.", "a halo of buzzsaws", {"orbit": 2, "orbitdmg": 0.3, "orbitbleed": 1})
card("clone_vat", "Clone Vat", "auto", 2, 1, "+2 interns. Nobody asked if they wanted this.", "a vat of clones", {"minion": 2})

# ---- 6. MOVEMENT: dashing, dodging, positioning
card("fresh_sneakers", "Fresh Sneakers", "move", 0, 4, "+12% move speed.", "a pair of fresh sneakers", {"speed": 0.12})
card("sprinter", "Sprinter", "move", 1, 2, "+25% move speed, +10% dash recharge.", "a sprinter at full speed", {"speed": 0.25, "dashcd": 0.1})
card("double_dash", "Double Dash", "move", 1, 2, "+1 dash charge.", "two dash trails", {"dashes": 1})
card("quick_recovery", "Quick Recovery", "move", 0, 3, "+25% dash recharge speed.", "a stopwatch", {"dashcd": 0.25})
card("long_jump", "Long Jump", "move", 0, 3, "+40% dash distance.", "a long jumper", {"dashdist": 0.4})
card("dash_strike", "Dash Strike", "move", 1, 3, "Dashing through enemies deals 30 damage.", "a hero slashing while dashing", {"dashdmg": 1})
card("burning_rubber", "Burning Rubber", "move", 1, 2, "Dashing leaves a trail of fire.", "burning tire tracks", {"dashtrail": 1})
card("tactical_roll", "Tactical Roll", "move", 1, 1, "Dashing instantly reloads your guns.", "a soldier doing a tactical roll", {"dashreload": 1})
card("gun_kata", "Gun Kata", "move", 2, 2, "Dashing fires a 12-bullet ring.", "a hero spinning with two guns", procs=[P("dash", "nova", n=12, dmg=15)])
card("matrix_dodge", "Matrix Dodge", "move", 1, 2, "Wider perfect-dodge window. Perfect dodges slow time for 1s.", "a hero bending backward dodging bullets", {"perfect": 0.12}, procs=[P("perfect", "slowmo", t=1.0)])
card("counter_strike", "Counter Strike", "move", 2, 2, "Perfect dodges fire 3 free volleys.", "a counter attack slash", procs=[P("perfect", "volley", x=3, aim="nearest")])
card("riposte", "Riposte", "move", 1, 2, "Perfect dodges detonate an explosion around you.", "a fencer riposte with explosion", procs=[P("perfect", "explode", r=130, dmg=50, at="hero")])
card("smoke_bomb", "Smoke Bomb", "move", 0, 2, "Dashing drops smoke that slows nearby enemies.", "a smoke bomb cloud", procs=[P("dash", "status_area", s="slow", r=130, at="hero")])
card("afterimage", "Afterimage", "move", 2, 2, "Dashing leaves a decoy that lures enemies and explodes after 1.5s.", "a glowing afterimage silhouette", procs=[P("dash", "decoy", t=1.5, dmg=45)])
card("blink", "Blink", "move", 2, 1, "Your dash becomes an instant teleport. +30% dash distance.", "a teleport sparkle", {"blink": 1, "dashdist": 0.3})
card("momentum", "Momentum", "move", 1, 3, "+20% damage while moving.", "a rolling boulder", {"movedmg": 0.2})
card("planted_feet", "Planted Feet", "move", 1, 3, "+40% damage while standing still.", "boots planted in concrete", {"stilldmg": 0.4})
card("turret_mode", "Turret Mode", "move", 2, 2, "Standing still fires an 8-bullet ring every second.", "a hero turning into a turret", procs=[P("still", "nova", every=1.0, n=8, dmg=12)])
card("shoulder_check", "Shoulder Check", "move", 1, 1, "Dashing into enemies sends them flying.", "a hockey shoulder check", {"dashpush": 1})
card("speed_demon", "Speed Demon", "move", 1, 2, "Gain damage equal to your bonus move speed.", "a demon with racing stripes", {"speeddmg": 1})
card("bunny_hop", "Bunny Hop", "move", 0, 3, "10% of kills instantly recharge your dash.", "a bunny hopping", procs=[P("kill", "dashreset", chance=0.1)])
card("rollerblades", "Rollerblades", "move", 0, 2, "+18% move speed, but you drift like you're on ice.", "a pair of rollerblades", {"speed": 0.18, "drift": 1})
card("rocket_boots", "Rocket Boots", "move", 1, 2, "Dashing fires 2 rockets at nearby enemies.", "rocket powered boots", procs=[P("dash", "rocket", n=2, dmg=20)])
card("slipstream", "Slipstream", "move", 1, 2, "After dashing, +50% fire rate for 2s.", "a slipstream wind trail", procs=[P("dashend", "buff", stat="rate", amt=0.5, t=2)])
card("evasive", "Evasive", "move", 1, 3, "+10% chance to dodge damage.", "a hero dodging", {"dodge": 0.10})
card("ghost_walk", "Ghost Walk", "move", 2, 1, "+0.4s invulnerability after hits. Getting hit recharges your dash.", "a ghostly footprint", {"iframe": 0.4}, procs=[P("hurt", "dashreset")])
card("ground_pound", "Ground Pound", "move", 2, 2, "The end of each dash slams the ground.", "a superhero ground pound", procs=[P("dashend", "shockwave", r=135, dmg=30, push=320, at="hero")])
card("banana_peels", "Banana Peels", "move", 1, 2, "Dashing drops a banana peel. Enemies slip, spin and get stunned.", "a banana peel", procs=[P("dash", "puddle", s="banana", r=28, t=12, at="hero")])
card("zoomies", "Zoomies", "move", 0, 2, "Every 10 kills, +40% move speed for 3s.", "a dog with the zoomies", procs=[P("kill", "buff", nth=10, stat="speed", amt=0.4, t=3)])
card("magnet_dash", "Magnet Dash", "move", 0, 1, "Dashing pulls in nearby pickups.", "a horseshoe magnet", procs=[P("dash", "magnet")])

# ---- 7. DEFENSE
card("vitamins", "Vitamins", "defense", 0, 5, "+20 max HP.", "a bottle of vitamins", {"maxhp": 20})
card("thick_skin", "Thick Skin", "defense", 0, 4, "+2 armor (reduces each hit).", "a thick leather armor", {"armor": 2})
card("regeneration", "Regeneration", "defense", 1, 3, "Regenerate 1 HP per second.", "a glowing heart", {"regen": 1.0})
card("bubble_shield", "Bubble Shield", "defense", 1, 3, "+1 shield charge. Charges block a hit and recharge every 8s.", "a bubble shield", {"shield": 1})
card("fortress", "Fortress", "defense", 2, 2, "+2 shield charges, +2 armor.", "a castle fortress", {"shield": 2, "armor": 2})
card("vampire_teeth", "Vampire Teeth", "defense", 1, 3, "Kills heal 0.5 HP.", "vampire fangs", {"lifesteal": 0.5})
card("second_wind", "Second Wind", "defense", 2, 1, "Survive death once with 50% HP.", "a second wind gust", {"revive": 1})
card("cactus_suit", "Cactus Suit", "defense", 0, 3, "Enemies that touch you take 12 damage.", "a cactus costume", {"thorns": 12})
card("adrenaline", "Adrenaline", "defense", 1, 2, "Up to +60% damage as your HP drops.", "an adrenaline syringe", {"lowhpdmg": 0.6})
card("big_heart", "Big Heart", "defense", 1, 2, "+45 max HP, -5% move speed.", "a giant heart", {"maxhp": 45, "speed": -0.05})
card("medkit_drop", "Medkit Drop", "defense", 0, 3, "Enemies have a 3% chance to drop a heart.", "a medkit", {"heartdrop": 0.03})
card("last_stand", "Last Stand", "defense", 2, 1, "Below 35% HP, gain a shield charge every 4s.", "a lone hero standing", procs=[P("lowhp", "shield", every=4.0, n=1)])
card("retaliation", "Retaliation", "defense", 1, 2, "Getting hit fires a 16-bullet nova.", "an angry hero firing everywhere", procs=[P("hurt", "nova", n=16, dmg=20)])
card("spite", "Spite", "defense", 1, 2, "Getting hit causes an explosion around you.", "an explosion of rage", procs=[P("hurt", "explode", r=145, dmg=40, at="hero")])
card("soul_siphon", "Soul Siphon", "defense", 1, 2, "Killing an elite heals 15 HP.", "a soul being siphoned", procs=[P("kill", "heal", hp=15, **{"if": "elite"})])
card("kevlar", "Kevlar", "defense", 0, 4, "+1 armor, +10 max HP.", "a kevlar vest", {"armor": 1, "maxhp": 10})
card("growth_spurt", "Growth Spurt", "defense", 0, 3, "+5 max HP. Leveling up heals 25 HP.", "a growing plant", {"maxhp": 5}, procs=[P("level", "heal", hp=25)])
card("panic_button", "Panic Button", "defense", 2, 1, "When hit: slow time and gain 2 shields (every 20s).", "a big red panic button", procs=[P("hurt", "slowmo", icd=20, t=2.0), P("hurt", "shield", icd=20, n=2)])
card("tough_cookie", "Tough Cookie", "defense", 0, 3, "+0.25s invulnerability after being hit.", "a tough cookie with a helmet", {"iframe": 0.25})
card("cat_reflexes", "Cat Reflexes", "defense", 1, 2, "+8% dodge chance, +5% move speed.", "a cat dodging", {"dodge": 0.08, "speed": 0.05})
card("field_medic", "Field Medic", "defense", 0, 3, "Heal 30 HP at the start of each sector.", "a field medic bag", procs=[P("sector", "heal", hp=30)])
card("blood_bank", "Blood Bank", "defense", 1, 1, "Healing above max HP becomes shield charges (up to 3).", "a blood bank", {"overheal": 1})
card("cockroach", "Cockroach", "defense", 3, 1, "Survive death once more. +20 max HP. You simply refuse to die.", "an indestructible cockroach", {"revive": 1, "maxhp": 20})
card("reactive_armor", "Reactive Armor", "defense", 1, 2, "Getting hit fires 10 fragments around you.", "reactive armor plates exploding", procs=[P("hurt", "frags", n=10, dmg=12, pattern="ring", at="hero")])
card("bullet_eater", "Bullet Eater", "defense", 2, 2, "+2 orbs that block enemy bullets.", "a monster eating bullets", {"orbshield": 2})
card("guardian_drone", "Guardian Drone", "defense", 1, 2, "Gain a shield charge every 10s.", "a guardian drone with a shield", procs=[P("timer", "shield", every=10.0, n=1)])
card("rage", "Rage", "defense", 1, 2, "Getting hit gives +50% damage for 4s.", "an angry red face", procs=[P("hurt", "buff", stat="dmg", amt=0.5, t=4)])
card("heart_magnet", "Heart Magnet", "defense", 0, 2, "+2% heart drop chance, +20% pickup range.", "a heart shaped magnet", {"heartdrop": 0.02, "magnet": 0.2})
card("meditation", "Meditation", "defense", 1, 2, "Standing still heals 2 HP per second.", "a meditating monk", procs=[P("still", "heal", every=1.0, hp=2)])
card("glass_cannon", "Glass Cannon", "defense", 3, 1, "+50% TOTAL damage. -50 max HP.", "a cannon made of glass", {"tdmg": 0.5, "maxhp": -50}, cursed=True)

# ---- 8. LOOT
card("magnet", "Magnet", "loot", 0, 4, "+40% pickup range.", "a red horseshoe magnet", {"magnet": 0.4})
card("super_magnet", "Super Magnet", "loot", 1, 2, "+100% pickup range.", "a giant electromagnet", {"magnet": 1.0})
card("four_leaf", "Four-Leaf Clover", "loot", 1, 3, "+1 luck. Slightly better card odds.", "a four leaf clover", {"luck": 1})
card("greed", "Greed", "loot", 0, 4, "+25% gold.", "a pile of gold coins", {"goldp": 0.25})
card("scholar", "Scholar", "loot", 0, 4, "+15% experience.", "a graduation cap", {"xp": 0.15})
card("big_brain", "Big Brain", "loot", 1, 2, "+35% experience.", "a huge glowing brain", {"xp": 0.35})
card("compound_interest", "Compound Interest", "loot", 1, 3, "Earn 10% interest on your gold each sector (max 15).", "a piggy bank with a graph", {"interest": 1})
card("dice_bag", "Dice Bag", "loot", 0, 3, "+2 rerolls.", "a bag of dice", {"rerolls": 2}, on_pick="rerolls")
card("more_options", "More Options", "loot", 2, 1, "See 4 cards per level up.", "four cards fanned out", {"choices": 1})
card("coupon_book", "Coupon Book", "loot", 1, 2, "-20% shop prices.", "a coupon book", {"discount": 0.2})
card("gold_rush", "Gold Rush", "loot", 1, 2, "6% of kills drop extra gold.", "a gold miner", procs=[P("kill", "drop", chance=0.06, kind="gold", n=1)])
card("treasure_sense", "Treasure Sense", "loot", 1, 2, "Elites appear 50% more often. Elites drop treasure.", "a treasure map", {"elitechance": 0.5})
card("goblin_whistle", "Goblin Whistle", "loot", 1, 2, "Gold Goblins appear much more often.", "a whistle and a goblin", {"goblins": 1})
card("shard_splitter", "Shard Splitter", "loot", 0, 3, "15% of kills drop an extra EXP gem.", "a purple crystal splitting", procs=[P("kill", "drop", chance=0.15, kind="exp", n=1)])
card("midas_touch", "Midas Touch", "loot", 2, 1, "1.5% of kills turn into a pile of 8 gold.", "a golden hand", procs=[P("kill", "drop", chance=0.015, kind="gold", n=8, say="MIDAS!")])
card("piggy_bank", "Piggy Bank", "loot", 1, 2, "Gain 10 gold at the start of each sector.", "a smiling piggy bank", procs=[P("sector", "drop", kind="gold", n=10, at="hero")])
card("cashback", "Cashback", "loot", 0, 2, "Leveling up drops 3 gold.", "a credit card with coins", procs=[P("level", "drop", kind="gold", n=3, at="hero")])
card("loaded_dice", "Loaded Dice", "loot", 2, 2, "+2 luck, +1 reroll.", "a pair of loaded dice", {"luck": 2, "rerolls": 1}, on_pick="rerolls")
card("investment_banker", "Investment Banker", "loot", 2, 1, "+1% damage per 10 gold you hold (max +50%).", "a banker in a suit", {"golddmg": 1})
card("coin_toss", "Coin Toss", "loot", 1, 2, "Every 8th volley flicks a coin that ricochets 4 times.", "a flipping gold coin", procs=[P("fire", "coin", nth=8, dmg=40)])
card("jackpot", "Jackpot", "loot", 2, 1, "0.05% of kills drop a treasure chest. JACKPOT!", "a slot machine jackpot", procs=[P("kill", "drop", chance=0.0005, kind="chest", n=1, say="JACKPOT!")])
card("study_buddy", "Study Buddy", "loot", 0, 2, "+20% experience, +20% pickup range.", "two books with faces", {"xp": 0.2, "magnet": 0.2})
card("snack_break", "Snack Break", "loot", 0, 2, "5% of EXP gems also heal 1 HP.", "a sandwich", procs=[P("xp", "heal", chance=0.05, hp=1)])
card("bargain_hunter", "Bargain Hunter", "loot", 0, 2, "-10% shop prices, +10% gold.", "a shopping bag", {"discount": 0.1, "goldp": 0.1})
card("crypto_wallet", "Crypto Wallet", "loot", 1, 2, "Each sector, gain between 0 and 25 gold. Number go up?", "a glowing crypto coin", procs=[P("sector", "drop", kind="gold", n=0, nmax=25, at="hero")])
card("combo_master", "Combo Master", "loot", 1, 2, "+1% damage per combo kill (max +40%).", "a combo counter on fire", {"combodmg": 1})
card("golden_gun", "Golden Gun", "loot", 3, 1, "Each volley spends 1 gold for +60% damage (while you have gold).", "a golden pistol", {"goldshot": 1})
card("devil_deal", "Deal with the Devil", "loot", 3, 1, "+3 luck. -30 max HP.", "a devil handshake", {"luck": 3, "maxhp": -30}, cursed=True)
card("bounty_board", "Bounty Board", "loot", 1, 2, "Killing an elite drops 12 gold.", "a wanted poster", procs=[P("kill", "drop", kind="gold", n=12, **{"if": "elite"})])
card("eureka", "Eureka!", "loot", 1, 2, "Leveling up blasts a 24-bullet ring.", "a lightbulb exploding with ideas", procs=[P("level", "nova", n=24, dmg=30)])

# ---- 9. CHAOS: funny, loud and a bit unhinged
card("rubber_chicken", "Rubber Chicken", "chaos", 1, 3, "10% of kills launch a honking rubber chicken that bounces between enemies and explodes.", "a rubber chicken flying", procs=[P("kill", "chicken", chance=0.1, n=1)])
card("clown_car", "Clown Car", "chaos", 2, 2, "Every 8s a clown car drives across the road, running over everything.", "a tiny clown car honking", procs=[P("timer", "car", every=8.0, dmg=60, say="HONK HONK")])
card("big_head", "Big Head Mode", "chaos", 0, 1, "Enemies have huge heads. +15% crit chance.", "a monster with a huge head", {"bighead": 1, "crit": 0.15})
card("shrunk", "Honey I Shrunk Me", "chaos", 1, 1, "You are tiny: 40% smaller hitbox. -10 max HP.", "a tiny hero next to a huge boot", {"tiny": 1, "maxhp": -10})
card("disco_fever", "Disco Fever", "chaos", 1, 2, "Every 6s a disco ball makes nearby enemies dance (stunned).", "a disco ball with dancing monsters", procs=[P("timer", "status_area", every=6.0, s="stun", r=190, t=1.5, at="hero", say="DANCE!", disco=1)])
card("party_popper", "Party Popper", "chaos", 1, 2, "Dashing pops a damaging confetti blast.", "a party popper", procs=[P("dash", "confetti", dmg=20, r=105, at="hero")])
card("pinata_bosses", "Piñata Bosses", "chaos", 1, 1, "Hitting bosses and elites sometimes knocks gold out of them (up to 2 per second).", "a boss shaped pinata", procs=[P("hit", "drop", chance=0.06, icd=0.5, kind="gold", n=1, **{"if": "elite"})])
card("allergies", "Allergies", "chaos", 0, 2, "Every 4s you might sneeze a ring of 10 bullets. ACHOO!", "a sneezing hero", procs=[P("timer", "nova", every=4.0, chance=0.5, n=10, dmg=12, say="ACHOO!")])
card("bean_burrito", "Bean Burrito", "chaos", 1, 2, "Dashing leaves a poison cloud. Pffft.", "a bean burrito with green gas", procs=[P("dash", "puddle", s="poison", r=85, t=3, at="hero", say="PFFT")])
card("moonwalk", "Moonwalk", "chaos", 1, 2, "+2 projectiles fired backward. +20% damage. Smooth criminal.", "a hero moonwalking", {"rear": 2, "dmg": 0.2})
card("bouncy_castle", "Bouncy Castle", "chaos", 1, 1, "+80% knockback and +3 wall bounces. Everything is bouncy.", "a bouncy castle", {"knock": 0.8, "bounce": 3})
card("banana_rounds", "Banana Rounds", "chaos", 1, 2, "8% of hits drop a banana peel under the enemy.", "a banana shaped bullet", procs=[P("hit", "puddle", chance=0.08, s="banana", r=28, t=10)])
card("hot_potato", "Hot Potato", "chaos", 2, 2, "Every 5s a hot potato bounces between 4 enemies, then explodes.", "a flaming hot potato", procs=[P("timer", "potato", every=5.0, dmg=80)])
card("lottery_ticket", "Lottery Ticket", "chaos", 1, 2, "20% chance on level up to get a treasure chest.", "a lottery ticket", procs=[P("level", "drop", chance=0.2, kind="chest", n=1, at="hero")])
card("mutiny", "Mutiny", "chaos", 2, 2, "3% of hits charm the enemy. They switch sides.", "a pirate mutiny", procs=[P("hit", "status", chance=0.03, s="charm")])
card("shop_vac", "Shop-Vac", "chaos", 1, 2, "Every 10s a vortex pulls enemies together and sucks up pickups.", "a vacuum cleaner", procs=[P("timer", "blackhole", every=10.0, r=170, t=1.5, weak=1), P("timer", "magnet", every=10.0)])
card("kazoo", "Kazoo", "chaos", 0, 1, "Reloading plays a kazoo that stuns nearby enemies.", "a kazoo", procs=[P("reload", "status_area", s="stun", r=110, t=1.0, at="hero", say="BRRRT")])
card("barrel_delivery", "Barrel Delivery", "chaos", 1, 2, "Every 7s an explosive barrel drops on the road ahead.", "a red explosive barrel", procs=[P("timer", "barrel", every=7.0)])
card("kaboom", "KABOOM!", "chaos", 1, 3, "6% of kills cause a big explosion.", "a cartoon bomb with KABOOM cloud", procs=[P("kill", "explode", chance=0.06, r=115, dmg=50, say="KABOOM!")])
card("ghost_pepper", "Ghost Pepper", "chaos", 1, 2, "+20% burn chance. Getting hit spews fire around you.", "a ghost pepper on fire", {"burn": 0.2}, procs=[P("hurt", "puddle", s="fire", r=95, t=2, at="hero", say="SPICY!")])
card("coin_flip", "Coin Flip", "chaos", 2, 1, "Each sector: heads +40% damage, tails -15% damage.", "a coin flipping in the air", procs=[P("sector", "coinflip")])
card("chaos_orb", "Chaos Orb", "chaos", 3, 1, "Every 5th volley does something random. Anything.", "a swirling chaos orb", procs=[P("fire", "random", nth=5)])
card("uno_reverse", "Uno Reverse", "chaos", 2, 2, "15% of enemy bullets that would hit you are reflected back.", "a reverse card", {"reflect": 0.15})
card("not_the_bees", "NOT THE BEES", "chaos", 1, 3, "5% of hits release 2 angry bees.", "a swarm of angry bees", procs=[P("hit", "bees", chance=0.05, n=2)])
card("yeet", "YEET", "chaos", 0, 2, "+80% knockback. Enemies sent flying scream YEET.", "a monster flying through the air", {"knock": 0.8, "yeet": 1})
card("hamster_wheel", "Hamster Wheel", "chaos", 1, 2, "Every 600px you run, fire a 20-bullet ring.", "a hamster in a wheel", procs=[P("walk", "nova", every=600, n=20, dmg=15)])
card("falling_piano", "Falling Piano", "chaos", 2, 1, "Every 10s a piano falls on the biggest enemy.", "a falling grand piano", procs=[P("timer", "anvil", every=10.0, dmg=220, r=95, piano=1, say="PLONK")])
card("pickpocket", "Pickpocket", "chaos", 0, 2, "2% of hits knock out a gold coin (up to 1 per second).", "a sneaky hand stealing a coin", procs=[P("hit", "drop", chance=0.02, icd=1.0, kind="gold", n=1)])
card("cursed_doll", "Cursed Doll", "chaos", 2, 1, "+25% TOTAL damage. Enemies move 15% faster.", "a creepy cursed doll", {"tdmg": 0.25, "enemyspeed": 0.15}, cursed=True)
card("mad", "Mutually Assured Destruction", "chaos", 3, 1, "Survive death once, nuking everything on screen.", "a big red nuke button", {"revive": 1, "mad": 1})

# ---- 10. MASTERY: weapon specific upgrades and legendaries
def wcard(id, name, weapon_ids, rarity, mx, desc, art, wm, mods=None):
    card(id, name, "mastery", rarity, mx, desc, art, mods, req={"weapon": weapon_ids}, wmods=wm)

wcard("shell_collector", "Shell Collector", ["shotgun"], 1, 2, "Boomstick: +3 pellets.", "a pile of shotgun shells", {"pellets": 3})
wcard("recoil_jump", "Recoil Jump", ["shotgun", "rail"], 1, 1, "Boomstick/Railgun: recoil is tripled and blasts fragments behind you.", "a hero flying backward from recoil", {"recoil": 2.0, "recoilblast": 1})
wcard("belt_fed", "Belt Fed", ["smg", "minigun", "nailgun"], 1, 2, "SMG/Lawnmower/Nail Gun: +100% magazine, +15% fire rate.", "an ammo belt feeding a gun", {"mag": 1.0, "rate": 0.15})
wcard("pre_spun", "Pre-Spun", ["minigun"], 1, 1, "Lawnmower: starts at full spin.", "a spinning minigun barrel", {"prespun": 1})
wcard("hawkeye", "Hawkeye", ["sniper", "revolver"], 1, 2, "Long Goodbye/Six Shooter: +4 pierce, +30% damage.", "a hawk eye", {"pierce": 4, "dmg": 0.3})
wcard("wallbanger", "Wallbanger", ["sniper", "revolver", "pistol"], 1, 2, "Peashooter/Six Shooter/Long Goodbye: +3 wall bounces.", "a bullet bouncing off a wall", {"bounce": 3})
wcard("cluster_warheads", "Cluster Warheads", ["rocket"], 2, 1, "Party Starter: rockets split into 4 bomblets.", "a rocket splitting into bomblets", {"cluster": 1})
wcard("nuke_tips", "Nuke Tips", ["rocket", "grenade"], 1, 2, "Party Starter/Bouncer: +60% blast radius, +20% damage.", "a tiny nuke warhead", {"blast": 0.6, "dmg": 0.2})
wcard("sticky_grenades", "Sticky Grenades", ["grenade"], 1, 1, "Bouncer: grenades stick to enemies.", "a sticky grenade covered in goo", {"sticky": 1})
wcard("prism", "Prism", ["laser"], 2, 2, "Beam Me: +2 extra beams.", "a prism splitting a laser beam", {"pellets": 2})
wcard("storm_caller", "Storm Caller", ["tesla"], 1, 2, "Zapper: +4 chain jumps, +20% damage.", "a wizard calling lightning", {"rico": 4, "dmg": 0.2})
wcard("dragon_breath", "Dragon Breath", ["flame"], 2, 1, "Hot Take: +60% range, flames ignite the ground.", "a dragon breathing fire", {"life": 0.6, "dragon": 1})
wcard("extra_discs", "Extra Discs", ["disc"], 1, 2, "Frisbee of Doom: +2 discs.", "a stack of frisbees", {"mag": 2})
wcard("big_boomer", "Big Boomer", ["boomerang"], 1, 2, "Boomer: +80% size, +30% damage.", "a huge boomerang", {"size": 0.8, "dmg": 0.3})
wcard("overcharge", "Overcharge", ["rail"], 2, 2, "Railgun: +60% damage, charges 30% faster.", "an overcharged battery", {"dmg": 0.6, "charge": 0.3})
wcard("killer_bees", "Killer Bees", ["bees"], 1, 2, "Beehive: +3 bees, +25% damage.", "an angry killer bee", {"pellets": 3, "dmg": 0.25})
wcard("strike", "STRIKE!", ["bowling"], 1, 2, "Strike Cannon: +1 ball, +40% size.", "bowling pins exploding in a strike", {"pellets": 1, "size": 0.4})
wcard("staple_gun", "Staple Gun", ["nailgun"], 1, 2, "Nail Gun: +40% pin chance, +20% fire rate.", "a stapler gun", {"pin": 0.4, "rate": 0.2})
wcard("chicken_coop", "Chicken Coop", ["chicken"], 1, 2, "Poultry Launcher: +2 chickens per shot.", "a chicken coop", {"pellets": 2})
wcard("bubble_bath", "Bubble Bath", ["bubble"], 1, 2, "Bubble Blaster: traps +2 enemies, +40% size.", "a bubble bath", {"trap": 2, "size": 0.4})
wcard("multiball", "Multiball", ["pinball"], 2, 1, "Pinball: every wall bounce adds another ball.", "multiple pinballs", {"multiball": 1})
wcard("hydra_bolts", "Hydra Bolts", ["splitbow"], 1, 2, "Splitbow: +2 split bolts, splits home in.", "a hydra headed arrow", {"split": 2, "fraghome": 1})
wcard("avalanche", "Avalanche", ["snow"], 2, 1, "Snow Cannon: snowballs grow twice as big and freeze instantly.", "an avalanche", {"size": 1.0, "instafreeze": 1})
wcard("dead_eye", "Dead Eye", ["revolver", "sniper"], 2, 1, "Six Shooter/Long Goodbye: +25% crit, crits pierce everything.", "a glowing dead eye", {"crit": 0.25, "critpierce": 1})
wcard("akimbo", "Akimbo", ["pistol", "smg"], 1, 2, "Peashooter/SMG: +1 bullet, +50% reload speed.", "two pistols crossed", {"pellets": 1, "reload": 0.5})
card("infinite_ammo", "Infinite Ammo", "mastery", 3, 1, "Your guns never reload. -15% fire rate.", "an infinity symbol made of bullets", {"infammo": 1, "rate": -0.15})
card("arsenal", "Arsenal", "mastery", 3, 1, "+1 weapon slot. Fire three guns at once.", "three guns in a rack", {"slots": 1})
card("overclocked", "Overclocked", "mastery", 3, 1, "+20% TOTAL damage, +50% fire rate, +50% reload speed. You take 25% more damage.", "an overclocked CPU on fire", {"tdmg": 0.2, "rate": 0.5, "reload": 0.5, "dmgtaken": 0.25}, cursed=True)
card("god_gamer", "God Gamer", "mastery", 3, 1, "+25% crit chance, +100% crit damage, wider perfect dodge.", "a gamer with a glowing headset", {"crit": 0.25, "critdmg": 1.0, "perfect": 0.1})
card("weapon_master", "Weapon Master", "mastery", 2, 2, "All your guns gain +1 level.", "a weapon rack with medals", on_pick="levelall")

# Extra projectiles are build-defining; keep those cards out of common and rare offers.
count_stats = {"mult", "par", "rear", "side", "burst", "echo", "pellets", "split", "splitkill", "wallsplit"}
for c in C:
    if count_stats.intersection(c.get("mods", {})) or count_stats.intersection(c.get("wmods", {})):
        c["rarity"] = max(2, c["rarity"])
for c in C:
    if c["id"] in {"bullet_hell", "ghost_twin", "supernova", "infinite_ammo", "god_gamer"}:
        c["rarity"] = 4
    elif c["id"] in {"pocket_singularity", "chaos_orb", "mad"}:
        c["rarity"] = 5

# Display names only (ids, art and saves keep the old id).
RENAMES = {
    "Speed Loader": "Reload Goblin", "Extended Mag": "Big Pockets", "Drum Magazine": "Bottomless Drum",
    "Piercing Rounds": "Shish Kebab", "Smart Rounds": "Bullets With a Degree", "Muzzle Velocity": "Zoom Zoom Bullets",
    "Long Range": "Sniper's Ego", "Explosive Rounds": "Michael Bay Mode", "Tracer Rounds": "Glow Sticks",
    "Armor Piercing": "Can Opener", "Razor Fragments": "Sharp Leftovers", "Seeker Fragments": "Clingy Shrapnel",
    "Volatile Fragments": "Spicy Shrapnel", "Bouncy Fragments": "Superball Shrapnel", "Grim Echo": "Ghost of Bullets Past",
    "Thermal Shock": "Hot & Cold", "Longer Chains": "Extension Cord", "Sharpened Steel": "Whetstone Wednesday",
    "Overclocked Drones": "Caffeinated Drones", "Quick Recovery": "Power Nap", "Tactical Roll": "Dramatic Roll",
    "Evasive": "Slippery", "Vitamins": "Gummy Vitamins", "Thick Skin": "Built Different", "Regeneration": "Band-Aid Subscription",
    "Fortress": "Panic Room", "Kevlar": "Puffer Jacket", "Field Medic": "Mom's Kiss", "Reactive Armor": "Spicy Vest",
    "Guardian Drone": "Helicopter Parent", "Meditation": "Touch Grass", "Magnet": "Fridge Magnet",
    "Super Magnet": "Black Friday Magnet", "Scholar": "Nerd Glasses", "Big Brain": "Galaxy Brain", "More Options": "Indecisive",
    "Treasure Sense": "Loot Goblin Instinct", "Shard Splitter": "Two for One", "Combo Master": "Combo Gremlin",
    "Momentum": "Can't Stop Won't Stop", "Planted Feet": "Couch Potato", "Sprinter": "Late for Work", "Double Dash": "Double Dip",
    "Long Jump": "Olympic Hopeful", "Dash Strike": "Drive-By Dash", "Satellite Shot": "Moon Bullets", "Accelerator": "Road Rage Rounds",
    "Overpressure": "Too Much Gunpowder", "Compass Rose": "Every Direction", "Spiral Galaxy": "Spin to Win", "Ammo Belt": "Bandolier Bob",
    "Static Field": "Bad Hair Day", "Frost Nova": "Brain Freeze", "Deep Freeze": "Freezer Burn", "High Voltage": "Licked a Battery",
    "Neurotoxin": "Expired Milk", "Knockback Rounds": "Leaf Blower", "Heat Seekers": "Stalker Bullets", "Retaliation": "Fight Me",
    "Mine Layer": "Littering", "Gun Drone": "Pew Drone",
}
# Flavor lines that read like filler; the mechanics text stays.
CUT = ["Jittery.", "Nobody asked if they wanted this.", "You simply refuse to die.", "Number go up?", "Smooth criminal.",
       "Bullets glow spooky.", "Anything."]
CATS["chaos"] = "BAD IDEAS"
for c in C:
    c["name"] = RENAMES.get(c["name"], c["name"])
    for cut in CUT:
        c["desc"] = c["desc"].replace(" " + cut, "").replace(cut, "").strip()

if len(C) != 300: raise SystemExit(f"expected 300 cards, got {len(C)}")
ids = [c["id"] for c in C]
if len(set(ids)) != len(ids): raise SystemExit("duplicate card ids")
names = [c["name"] for c in C]
if len(set(names)) != len(names): raise SystemExit("duplicate card names")
for cat in CATS:
    n = sum(1 for c in C if c["cat"] == cat)
    if n != 30: raise SystemExit(f"{cat} has {n} cards")

(ROOT / "data").mkdir(exist_ok=True)
(ROOT / "data/weapons.json").write_text(json.dumps(W, indent=1), encoding="utf8")
(ROOT / "data/enemies.json").write_text(json.dumps(E, indent=1), encoding="utf8")
(ROOT / "data/cards.json").write_text(json.dumps({"categories": CATS, "cards": C}, indent=1, ensure_ascii=False), encoding="utf8")

print(f"{len(W)} weapons, {len(E)} enemies, {len(C)} cards")
