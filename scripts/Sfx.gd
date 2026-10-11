extends Node
## Multi-theme original synthwave soundtrack, reactive danger percussion, and arcade SFX.

const RATE = 22050
var streams: Dictionary = {}
var players: Array = []
var last_play: Dictionary = {}
## Per-event throttles are separate from per-clip throttles: loud fights stay intelligible.
var last_projectile_event: Dictionary = {}
var music_player: AudioStreamPlayer
var music_alt: AudioStreamPlayer
var pressure_player: AudioStreamPlayer
var music_cache: Dictionary = {}
var current_song = "neon"
var pending_song = ""
var fade = 0.0
var pressure = 0.0
var target_pressure = 0.0
var last_warning = -100.0
var music_active = false
var route_mix_target = 1.0
var route_mix_level = 1.0
var sfx_volume = 0.7
var music_volume = 0.45

const MIN_GAP = {"hit": 0.07, "crit": 0.08, "pop": 0.06, "tick": 0.05, "gem": 0.05, "coin": 0.06, "pew": 0.06,
	"boom_small": 0.09, "boom": 0.12, "zap": 0.08, "reload": 0.1, "honk": 0.15, "bloop": 0.06, "buzz": 0.2, "ping": 0.05,
	"thunk": 0.07, "whoosh": 0.08, "bonk": 0.08, "slip": 0.1}

func _ready() -> void:
	# Hard limiter on the master bus stops clipping when a lot happens at once.
	if AudioServer.get_bus_effect_count(0) == 0:
		var lim = AudioEffectHardLimiter.new()
		lim.ceiling_db = -1.0
		AudioServer.add_bus_effect(0, lim)
	for i in range(16):
		var p = AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	music_player = AudioStreamPlayer.new()
	music_alt = AudioStreamPlayer.new()
	pressure_player = AudioStreamPlayer.new()
	add_child(music_player)
	add_child(music_alt)
	add_child(pressure_player)
	build_all()

func set_volumes(s: float, m: float) -> void:
	sfx_volume = s
	music_volume = m
	update_music_volumes()

## Each gun has its own firing voice: a clip plus a base pitch, so guns that
## share a projectile style still sound different.
const GUN_VOICE = {
	"pistol": ["vfx_pea", 1.0], "revolver": ["vfx_sniper", 0.7], "shotgun": ["vfx_shotgun", 1.0],
	"smg": ["vfx_rapid", 1.28], "minigun": ["vfx_rapid", 0.78], "sniper": ["vfx_sniper", 1.05],
	"nailgun": ["vfx_heavy_fire", 1.5], "pinball": ["vfx_pinball", 1.0], "bowling": ["vfx_heavy_fire", 0.62],
	"splitbow": ["vfx_pierce_hit", 1.2], "chicken": ["vfx_rocket", 1.35], "grenade": ["vfx_rocket", 0.85],
	"snow": ["vfx_ice_fire", 1.0], "bubble": ["vfx_water", 1.0], "bees": ["vfx_toxic_fire", 1.3],
}

func play_gun(gun: String, style: String, pattern: String = "") -> void:
	if not GUN_VOICE.has(gun) or pattern != "":
		play_projectile("fire", style, pattern)
		return
	if sfx_volume <= 0.01:
		return
	var now = Time.get_ticks_msec() * 0.001
	if now - float(last_projectile_event.get("fire", -100.0)) < float(PROJECTILE_EVENT_GAP.get("fire", 0.09)):
		return
	last_projectile_event["fire"] = now
	var voice: Array = GUN_VOICE[gun]
	play(str(voice[0]), 0.05, 0.72, float(voice[1]))

func play(name: String, pitch_jitter = 0.08, vol = 1.0, pitch = 1.0) -> void:
	if sfx_volume <= 0.01 or not streams.has(name):
		return
	var now = Time.get_ticks_msec() / 1000.0
	if now - float(last_play.get(name, -1.0)) < float(MIN_GAP.get(name, 0.03)):
		return
	# Big fights: never more than 3 copies of one sound, and the mix gets quieter as voices pile up.
	var same = 0
	var active = 0
	var free = null
	for p in players:
		if p.playing:
			active += 1
			if p.stream == streams[name]:
				same += 1
		elif free == null:
			free = p
	if free == null or same >= 3:
		return
	last_play[name] = now
	free.stream = streams[name]
	free.pitch_scale = float(pitch) * randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
	free.volume_db = linear_to_db(maxf(0.0001, sfx_volume * vol * 0.6 / sqrt(1.0 + active * 0.35)))
	free.play()

## Each visual event has a matching synthesised audio signature.
## One sound per volley, NOT one per pellet. These methods never alter combat logic.
const PROJECTILE_EVENT_GAP = {
	"fire": 0.045, "impact": 0.062, "status": 0.12, "crit": 0.11,
	"bounce": 0.12, "pierce": 0.12, "split": 0.18,
	"boss_fire": 0.20, "boss_warn": 0.50, "boss_impact": 0.19,
	"barrel_warn": 0.2, "barrel_boom": 0.19, "rail_charge": 0.30
}

static func projectile_clip(event: String, style: String = "kinetic", pattern: String = "") -> String:
	if event == "fire":
		if pattern == "double_tap":
			return "vfx_double"
		if pattern == "parallel":
			return "vfx_parallel"
		if pattern == "burst":
			return "vfx_burst"
		match style:
			"rapid": return "vfx_rapid"
			"laser": return "vfx_laser"
			"rail": return "vfx_rail_fire"
			"shotgun": return "vfx_shotgun"
			"heavy": return "vfx_heavy_fire"
			"pierce": return "vfx_sniper"
			"fire": return "vfx_flame"
			"toxic": return "vfx_toxic_fire"
			"frost": return "vfx_ice_fire"
			"shock": return "vfx_tesla"
			"blast", "boss_ember": return "vfx_rocket"
			"water": return "vfx_water"
			"ricochet": return "vfx_pinball"
			"boss_void", "magic": return "vfx_void"
			_: return "vfx_pea"
	match event:
		"impact":
			match style:
				"fire", "blast", "boss_ember": return "vfx_ember_hit"
				"toxic": return "vfx_goo_hit"
				"frost", "boss_frost": return "vfx_ice_hit"
				"shock", "boss_storm": return "vfx_zap_hit"
				"pierce": return "vfx_pierce_hit"
				"heavy": return "vfx_heavy_hit"
				"water": return "vfx_water_hit"
				"boss_void", "magic": return "vfx_void_hit"
				_: return "vfx_bullet_hit"
		"status":
			match style:
				"fire": return "vfx_ignite"
				"toxic": return "vfx_poison_proc"
				"frost": return "vfx_freeze_proc"
				"shock": return "vfx_shock_proc"
				_: return ""
		"crit": return "vfx_crit"
		"bounce": return "vfx_ricochet"
		"pierce": return "vfx_pierce_hit"
		"split": return "vfx_fragment"
		"boss_fire":
			match style:
				"boss_void": return "vfx_void"
				"boss_storm": return "vfx_tesla"
				"boss_frost": return "vfx_ice_fire"
				_: return "vfx_rocket"
		"boss_warn": return "vfx_boss_warn"
		"boss_impact": return "vfx_boss_impact"
		"rail_charge": return "vfx_rail_charge"
		"barrel_warn": return "vfx_barrel_warn"
		"barrel_boom": return "vfx_barrel_boom"
	return ""

func play_projectile(event: String, style: String = "kinetic", pattern: String = "", volume: float = 1.0) -> void:
	if sfx_volume <= 0.01:
		return
	var clip = projectile_clip(event, style, pattern)
	if clip == "":
		return
	# Cross-style throttle protects against hundreds of hits in one physics tick.
	var gap = float(PROJECTILE_EVENT_GAP.get(event, 0.09))
	if event == "fire" and style == "laser":
		gap = 0.17
	var now = Time.get_ticks_msec() * 0.001
	if now - float(last_projectile_event.get(event, -100.0)) < gap:
		return
	last_projectile_event[event] = now
	var gain = clampf(volume, 0.05, 1.0)
	match event:
		"fire": gain *= 0.72
		"impact": gain *= 0.42
		"status": gain *= 0.56
		"crit": gain *= 0.80
		"bounce": gain *= 0.55
		"pierce": gain *= 0.50
		"split": gain *= 0.60
		"boss_fire": gain *= 0.67
		"boss_warn": gain *= 0.78
		"boss_impact": gain *= 0.98
		"barrel_warn": gain *= 0.67
		"barrel_boom": gain *= 0.74
		"rail_charge": gain *= 0.62
	play(clip, 0.035 if event in ["crit", "boss_warn"] else 0.075, gain)

## World-driven music selection, called at low frequency by Main.
## Biome tracks progress with world, bosses get distinct fight/climax tracks.
## Pressure rises as surrounding enemies crowd the player; corner traps
## trigger a short warning stinger and intensified percussion.
const MUSIC_THEMES = ["neon", "frost", "ash", "candy", "void"]

func music_context(biome: int, boss: bool, boss_fury: bool, threat: float, cornered: bool) -> void:
	var wanted = ("boss_fury" if boss_fury else "boss") if boss else str(MUSIC_THEMES[posmod(biome, MUSIC_THEMES.size())])
	target_pressure = clampf(threat + (0.42 if cornered else 0.0), 0.0, 1.0)
	if cornered and target_pressure > 0.75 and Time.get_ticks_msec() / 1000.0 - last_warning > 9.0:
		last_warning = Time.get_ticks_msec() / 1000.0
		play("danger_warn", 0.0, 0.78)
	if wanted == current_song or wanted == pending_song:
		return
	if not music_active:
		current_song = wanted
		return
	# A smooth crossfade, not a hard restart or rapid re-trigger.
	pending_song = wanted
	music_alt.stream = song_stream(wanted)
	music_alt.play()
	fade = 0.0

func set_route_mix(is_route: bool) -> void:
	route_mix_target = 0.32 if is_route else 1.0
	if is_route:
		target_pressure = 0.0

func music_on(on: bool) -> void:
	music_active = on and music_volume > 0.01
	if music_active:
		if not music_player.playing:
			music_player.stream = song_stream(current_song)
			music_player.play()
		if not pressure_player.playing:
			pressure_player.stream = song_stream("pressure")
			pressure_player.play()
	else:
		if music_player.playing:
			music_player.stop()
		if music_alt.playing:
			music_alt.stop()
		if pressure_player.playing:
			pressure_player.stop()
		pending_song = ""
		fade = 0.0
	update_music_volumes()

func _process(dt: float) -> void:
	pressure = move_toward(pressure, target_pressure, dt * (0.9 if target_pressure > pressure else 0.38))
	route_mix_level = move_toward(route_mix_level, route_mix_target, dt * 0.55)
	if music_active and pending_song != "":
		fade = minf(1.0, fade + dt / 1.5)
		if fade >= 1.0:
			var previous = music_player
			music_player = music_alt
			music_alt = previous
			music_alt.stop()
			current_song = pending_song
			pending_song = ""
			fade = 0.0
	update_music_volumes()

func update_music_volumes() -> void:
	if music_player == null:
		return
	var level = music_volume * 0.43 * route_mix_level if music_active else 0.0
	music_player.volume_db = linear_to_db(maxf(0.0001, level * (1.0 - fade if pending_song != "" else 1.0)))
	music_alt.volume_db = linear_to_db(maxf(0.0001, level * fade if pending_song != "" else 0.0001))
	pressure_player.volume_db = linear_to_db(maxf(0.0001, level * 0.53 * pressure))

func song_stream(name: String) -> AudioStreamWAV:
	if not music_cache.has(name):
		music_cache[name] = build_music(name)
	return music_cache[name]

# ---------------------------------------------------------------- synthesis
func to_stream(samples: PackedFloat32Array, loop = false) -> AudioStreamWAV:
	var bytes = PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in range(samples.size()):
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var s = AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = samples.size()
	return s

func synth(dur: float, f0: float, f1: float, wave: String, noise: float, decay: float, vol = 0.8, lowpass = 1.0) -> PackedFloat32Array:
	var n = int(dur * RATE)
	var out = PackedFloat32Array()
	out.resize(n)
	var phase = 0.0
	var lp = 0.0
	for i in range(n):
		var t = float(i) / RATE
		var k = float(i) / n
		var f = lerpf(f0, f1, k)
		phase += f / RATE
		var v = 0.0
		match wave:
			"sine":
				v = sin(phase * TAU)
			"square":
				v = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
			"saw":
				v = fmod(phase, 1.0) * 2.0 - 1.0
			"tri":
				v = absf(fmod(phase, 1.0) * 4.0 - 2.0) - 1.0
		v = v * (1.0 - noise) + randf_range(-1.0, 1.0) * noise
		lp = lp + (v - lp) * lowpass
		var env = exp(-t * decay) * minf(1.0, t * 400.0)
		out[i] = lp * env * vol
	return out

func mix(a: PackedFloat32Array, b: PackedFloat32Array, offset = 0) -> PackedFloat32Array:
	var n = maxi(a.size(), b.size() + offset)
	var out = PackedFloat32Array()
	out.resize(n)
	for i in range(n):
		var v = 0.0
		if i < a.size():
			v += a[i]
		if i - offset >= 0 and i - offset < b.size():
			v += b[i - offset]
		out[i] = v
	return out

func build_all() -> void:
	streams["pew"] = to_stream(synth(0.09, 980, 320, "square", 0.05, 30, 0.35))
	streams["bang"] = to_stream(mix(synth(0.2, 220, 70, "sine", 0.6, 18, 0.7, 0.4), synth(0.05, 1200, 400, "square", 0.3, 60, 0.3)))
	streams["boom"] = to_stream(mix(synth(0.32, 140, 50, "sine", 0.75, 9, 0.9, 0.25), synth(0.06, 900, 200, "saw", 0.5, 50, 0.3)))
	streams["boom_small"] = to_stream(synth(0.18, 180, 60, "sine", 0.7, 16, 0.6, 0.3))
	streams["tick"] = to_stream(synth(0.035, 1500, 900, "square", 0.2, 80, 0.22))
	streams["snipe"] = to_stream(mix(synth(0.3, 2200, 150, "saw", 0.3, 10, 0.4, 0.5), synth(0.25, 120, 50, "sine", 0.6, 12, 0.6, 0.3)))
	streams["rocket"] = to_stream(synth(0.3, 200, 600, "saw", 0.7, 8, 0.4, 0.3))
	streams["thunk"] = to_stream(synth(0.13, 190, 70, "sine", 0.15, 22, 0.7))
	streams["zap"] = to_stream(synth(0.14, 1800, 600, "square", 0.55, 20, 0.3, 0.7))
	streams["whoosh"] = to_stream(synth(0.22, 400, 900, "sine", 0.9, 10, 0.35, 0.12))
	streams["rail"] = to_stream(mix(synth(0.12, 300, 2600, "saw", 0.2, 6, 0.35), synth(0.28, 120, 40, "sine", 0.7, 10, 0.6, 0.3), int(0.1 * RATE)))
	streams["buzz"] = to_stream(synth(0.22, 210, 240, "saw", 0.1, 8, 0.25, 0.4))
	streams["honk"] = to_stream(mix(synth(0.2, 330, 300, "square", 0.05, 6, 0.3, 0.5), synth(0.2, 415, 380, "square", 0.05, 6, 0.25, 0.5)))
	streams["bloop"] = to_stream(synth(0.12, 280, 760, "sine", 0.0, 18, 0.5))
	streams["ping"] = to_stream(synth(0.18, 1650, 1600, "sine", 0.0, 22, 0.4))
	streams["twang"] = to_stream(synth(0.2, 520, 480, "tri", 0.1, 14, 0.5))
	streams["hit"] = to_stream(synth(0.045, 700, 300, "square", 0.6, 70, 0.18, 0.6))
	streams["crit"] = to_stream(mix(synth(0.08, 1400, 2200, "square", 0.2, 30, 0.25), synth(0.05, 300, 100, "sine", 0.5, 50, 0.3)))
	streams["pop"] = to_stream(synth(0.08, 620, 180, "sine", 0.25, 30, 0.45))
	streams["gem"] = to_stream(synth(0.06, 1300, 1900, "sine", 0.0, 40, 0.22))
	streams["coin"] = to_stream(mix(synth(0.06, 1320, 1320, "square", 0.0, 30, 0.16), synth(0.1, 1980, 1980, "square", 0.0, 25, 0.16), int(0.05 * RATE)))
	streams["level"] = to_stream(arpeggio([523.0, 659.0, 784.0, 1046.0], 0.08, "square", 0.25))
	streams["chest"] = to_stream(arpeggio([392.0, 523.0, 659.0, 784.0, 1046.0], 0.06, "tri", 0.4))
	streams["hurt"] = to_stream(mix(synth(0.22, 240, 90, "square", 0.3, 12, 0.4, 0.5), synth(0.1, 100, 60, "sine", 0.8, 20, 0.5, 0.3)))
	streams["dash"] = to_stream(synth(0.16, 600, 1400, "sine", 0.85, 14, 0.3, 0.2))
	streams["reload"] = to_stream(mix(synth(0.04, 2000, 1500, "square", 0.6, 90, 0.2), synth(0.04, 1600, 1100, "square", 0.6, 90, 0.2), int(0.09 * RATE)))
	streams["perfect"] = to_stream(arpeggio([1046.0, 1568.0, 2093.0], 0.05, "sine", 0.3))
	streams["pick"] = to_stream(synth(0.07, 700, 1100, "tri", 0.0, 25, 0.3))
	streams["buy"] = to_stream(mix(arpeggio([880.0, 1320.0], 0.06, "square", 0.18), synth(0.2, 3000, 3000, "sine", 0.9, 25, 0.15, 0.5)))
	streams["deny"] = to_stream(synth(0.18, 180, 160, "square", 0.1, 8, 0.3, 0.4))
	streams["bonk"] = to_stream(mix(synth(0.08, 820, 700, "sine", 0.1, 40, 0.5), synth(0.3, 180, 420, "sine", 0.0, 9, 0.25), int(0.03 * RATE)))
	streams["slip"] = to_stream(synth(0.3, 900, 200, "sine", 0.0, 6, 0.35))
	streams["confetti"] = to_stream(synth(0.25, 3000, 2000, "square", 0.95, 14, 0.25, 0.8))
	streams["horn"] = to_stream(mix(synth(0.7, 110, 105, "saw", 0.05, 2.5, 0.4, 0.2), synth(0.7, 165, 160, "saw", 0.05, 2.5, 0.3, 0.2)))
	streams["gate"] = to_stream(arpeggio([660.0, 990.0], 0.07, "sine", 0.35))
	streams["clear"] = to_stream(arpeggio([523.0, 659.0, 784.0, 659.0, 1046.0], 0.09, "square", 0.25))
	streams["lose"] = to_stream(arpeggio([392.0, 330.0, 262.0, 196.0], 0.16, "tri", 0.35))
	streams["block"] = to_stream(synth(0.12, 1200, 600, "tri", 0.3, 20, 0.35))
	streams["heal"] = to_stream(arpeggio([660.0, 880.0], 0.06, "sine", 0.3))
	streams["boss_warn"] = to_stream(mix(synth(0.32, 660, 350, "saw", 0.05, 4.8, 0.28),
		synth(0.24, 90, 60, "sine", 0.05, 9.0, 0.38), int(0.05 * RATE)))
	streams["fuse"] = to_stream(mix(synth(0.20, 1100, 750, "square", 0.05, 12.0, 0.28),
		synth(0.12, 1650, 950, "tri", 0.0, 17.0, 0.25), int(0.07 * RATE)))
	streams["danger_warn"] = to_stream(mix(synth(0.42, 780, 260, "tri", 0.1, 6.5, 0.4),
		synth(0.40, 120, 65, "sine", 0.03, 6.0, 0.42), int(0.08 * RATE)))
		# Unique projectile voices. All synthesized once at startup; never built per shot.
	# Pattern samples already contain their second shot / side-by-side layer.
	var pea = mix(synth(0.075, 1200, 420, "square", 0.19, 34.0, 0.35, 0.7),
		synth(0.034, 2100, 980, "tri", 0.27, 65.0, 0.13, 0.68))
	streams["vfx_pea"] = to_stream(pea)
	streams["vfx_double"] = to_stream(mix(pea, pea, int(0.072 * RATE)))
	streams["vfx_parallel"] = to_stream(mix(pea, synth(0.083, 1070, 350, "square", 0.20, 30.0, 0.30, 0.60)))
	streams["vfx_burst"] = to_stream(mix(pea, pea, int(0.045 * RATE)))
	streams["vfx_laser"] = to_stream(mix(synth(0.19, 290, 350, "saw", 0.14, 7.5, 0.25, 0.25),
		synth(0.19, 940, 1000, "sine", 0.03, 7.0, 0.23, 0.82)))
	streams["vfx_rail_charge"] = to_stream(mix(synth(0.42, 240, 2400, "saw", 0.12, 2.2, 0.32, 0.27),
		synth(0.38, 450, 1650, "sine", 0.05, 2.0, 0.21, 0.72)))
	streams["vfx_rail_fire"] = to_stream(mix(synth(0.24, 3100, 190, "saw", 0.30, 11.0, 0.50, 0.40),
		synth(0.39, 230, 45, "sine", 0.58, 9.0, 0.85, 0.31), int(0.035 * RATE)))
	streams["vfx_shotgun"] = to_stream(mix(synth(0.18, 260, 70, "sine", 0.78, 21.0, 0.73, 0.29),
		synth(0.08, 1480, 250, "square", 0.75, 36.0, 0.41, 0.45)))
	streams["vfx_rapid"] = to_stream(mix(synth(0.05, 1560, 700, "square", 0.3, 60.0, 0.28, 0.55),
		synth(0.03, 2450, 1150, "tri", 0.15, 85.0, 0.10)))
	streams["vfx_heavy_fire"] = to_stream(mix(synth(0.16, 430, 82, "sine", 0.54, 22.0, 0.70, 0.3),
		synth(0.08, 1150, 230, "square", 0.38, 38.0, 0.25, 0.5)))
	streams["vfx_sniper"] = to_stream(mix(synth(0.22, 2700, 260, "saw", 0.35, 23.0, 0.43, 0.40),
		synth(0.26, 200, 62, "sine", 0.35, 10.0, 0.52, 0.31)))
	streams["vfx_flame"] = to_stream(mix(synth(0.17, 360, 120, "saw", 0.78, 13.0, 0.37, 0.25),
		synth(0.10, 1700, 430, "sine", 0.5, 28.0, 0.2, 0.36)))
	streams["vfx_toxic_fire"] = to_stream(mix(synth(0.16, 270, 500, "sine", 0.25, 20.0, 0.45, 0.70),
		synth(0.08, 1100, 340, "tri", 0.60, 28.0, 0.22, 0.5)))
	streams["vfx_ice_fire"] = to_stream(mix(synth(0.15, 1700, 2800, "tri", 0.12, 26.0, 0.32, 0.75),
		synth(0.09, 2600, 1900, "sine", 0.13, 32.0, 0.18)))
	streams["vfx_tesla"] = to_stream(mix(synth(0.13, 2300, 480, "square", 0.68, 22.0, 0.39, 0.63),
		synth(0.10, 3300, 1300, "tri", 0.26, 40.0, 0.16, 0.70)))
	streams["vfx_rocket"] = to_stream(mix(synth(0.26, 140, 450, "saw", 0.65, 9.0, 0.42, 0.3),
		synth(0.13, 800, 230, "sine", 0.55, 15.0, 0.29, 0.35)))
	streams["vfx_water"] = to_stream(mix(synth(0.12, 480, 760, "sine", 0.1, 15.0, 0.34),
		synth(0.08, 940, 580, "tri", 0.35, 30.0, 0.19, 0.65)))
	streams["vfx_pinball"] = to_stream(mix(synth(0.14, 1300, 860, "tri", 0.08, 28.0, 0.30),
		synth(0.06, 1800, 2200, "sine", 0.01, 30.0, 0.17)))
	streams["vfx_void"] = to_stream(mix(synth(0.22, 300, 90, "saw", 0.2, 10.0, 0.33, 0.25),
		synth(0.18, 620, 1700, "sine", 0.05, 14.0, 0.26)))
	streams["vfx_bullet_hit"] = to_stream(synth(0.07, 1150, 520, "tri", 0.45, 45.0, 0.20, 0.68))
	streams["vfx_heavy_hit"] = to_stream(mix(synth(0.14, 240, 70, "sine", 0.6, 29.0, 0.62, 0.3),
		synth(0.04, 1800, 500, "square", 0.53, 80.0, 0.19, 0.56)))
	streams["vfx_pierce_hit"] = to_stream(mix(synth(0.12, 1800, 3600, "tri", 0.28, 30.0, 0.32),
		synth(0.06, 1050, 520, "square", 0.46, 55.0, 0.17, 0.65)))
	streams["vfx_ember_hit"] = to_stream(mix(synth(0.13, 430, 110, "saw", 0.7, 22.0, 0.34, 0.24),
		synth(0.06, 1800, 800, "square", 0.65, 65.0, 0.16, 0.55)))
	streams["vfx_goo_hit"] = to_stream(mix(synth(0.16, 230, 440, "sine", 0.13, 19.0, 0.39),
		synth(0.07, 780, 250, "tri", 0.55, 40.0, 0.15)))
	streams["vfx_ice_hit"] = to_stream(mix(synth(0.12, 2400, 1100, "tri", 0.19, 38.0, 0.33),
		synth(0.08, 3700, 1800, "sine", 0.12, 45.0, 0.24)))
	streams["vfx_zap_hit"] = to_stream(mix(synth(0.09, 3400, 630, "square", 0.6, 37.0, 0.32, 0.67),
		synth(0.06, 1650, 900, "tri", 0.20, 55.0, 0.15)))
	streams["vfx_water_hit"] = to_stream(synth(0.12, 750, 220, "sine", 0.25, 23.0, 0.37, 0.63))
	streams["vfx_void_hit"] = to_stream(mix(synth(0.18, 530, 110, "saw", 0.38, 20.0, 0.35, 0.35),
		synth(0.13, 1900, 700, "sine", 0.25, 29.0, 0.2)))
	streams["vfx_ignite"] = to_stream(mix(synth(0.17, 860, 280, "saw", 0.78, 24.0, 0.30, 0.3),
		synth(0.04, 3200, 1900, "square", 0.8, 85.0, 0.12, 0.7)))
	streams["vfx_poison_proc"] = to_stream(mix(synth(0.17, 200, 620, "sine", 0.16, 21.0, 0.48),
		synth(0.09, 570, 260, "tri", 0.6, 28.0, 0.15)))
	streams["vfx_freeze_proc"] = to_stream(mix(synth(0.19, 1400, 2900, "tri", 0.17, 23.0, 0.40),
		synth(0.11, 3900, 1800, "sine", 0.1, 37.0, 0.27)))
	streams["vfx_shock_proc"] = to_stream(mix(synth(0.17, 3600, 700, "square", 0.75, 28.0, 0.45, 0.64),
		synth(0.07, 2500, 1100, "saw", 0.47, 53.0, 0.18, 0.55)))
	streams["vfx_crit"] = to_stream(mix(synth(0.16, 1750, 2800, "sine", 0.05, 26.0, 0.43),
		synth(0.11, 460, 150, "tri", 0.38, 30.0, 0.48, 0.68)))
	streams["vfx_ricochet"] = to_stream(mix(synth(0.16, 1600, 2600, "sine", 0.04, 28.0, 0.32),
		synth(0.06, 3300, 2450, "tri", 0.18, 45.0, 0.2)))
	streams["vfx_fragment"] = to_stream(mix(synth(0.16, 900, 2100, "tri", 0.26, 20.0, 0.30),
		synth(0.05, 1350, 600, "square", 0.23, 50.0, 0.13)))
	streams["vfx_boss_warn"] = to_stream(mix(synth(0.28, 720, 310, "saw", 0.06, 7.5, 0.29, 0.32),
		synth(0.32, 130, 75, "sine", 0.04, 8.0, 0.46, 0.37), int(0.065 * RATE)))
	streams["vfx_boss_impact"] = to_stream(mix(synth(0.33, 130, 42, "sine", 0.72, 7.0, 0.82, 0.28),
		synth(0.09, 2000, 290, "saw", 0.80, 28.0, 0.32, 0.42)))
	streams["vfx_barrel_warn"] = to_stream(mix(synth(0.09, 1400, 1850, "square", 0.05, 20.0, 0.34, 0.68),
		synth(0.07, 880, 1220, "sine", 0.03, 24.0, 0.27)))
	streams["vfx_barrel_boom"] = to_stream(mix(synth(0.23, 120, 35, "sine", 0.60, 12.0, 0.65, 0.29),
		synth(0.14, 1700, 220, "saw", 0.70, 25.0, 0.32, 0.40)))
	streams["boom2"] = streams["boom"]
	streams["shot"] = streams["pew"]

func arpeggio(notes: Array, step: float, wave: String, vol: float) -> PackedFloat32Array:
	var out = PackedFloat32Array()
	for i in range(notes.size()):
		out = mix(out, synth(step * 2.2, notes[i], notes[i], wave, 0.0, 9, vol), int(i * step * RATE))
	return out

## Seven original 8-bar compositions plus a synchronized reactive danger layer.
## All themes share tempo and bar length for musical, seamless scene transitions.
const LEADS = {
	"neon":  [67, -1, 70, 72, -1, 74, 72, -1, 67, 70, -1, 65, 67, -1, 62, -1],
	"frost": [74, -1, -1, 77, 79, -1, 77, -1, 72, -1, 70, -1, 69, -1, -1, 72],
	"ash":   [62, -1, 65, -1, 67, 68, -1, 65, 62, -1, 60, 62, 65, -1, 60, -1],
	"candy": [76, 79, -1, 83, 81, -1, 79, 76, 74, 76, 79, -1, 81, 79, 76, -1],
	"void":  [63, -1, 66, -1, 68, -1, 63, 61, -1, 66, -1, 68, 70, -1, 66, -1],
	"boss":  [62, 62, -1, 65, 68, -1, 65, 62, 70, -1, 68, 65, 62, 65, -1, 60],
	"boss_fury": [74, 77, 75, 74, 70, 74, 68, 65, 74, 77, 80, 77, 74, 70, 68, 65],
}
const ROOTS = {
	"neon": [43, 39, 41, 38], "frost": [50, 46, 48, 43],
	"ash": [38, 36, 41, 34], "candy": [48, 53, 55, 43],
	"void": [39, 36, 32, 34], "boss": [38, 34, 36, 33],
	"boss_fury": [38, 39, 34, 36],
}

static func hz(midi: int) -> float:
	return 440.0 * pow(2.0, (float(midi) - 69.0) / 12.0)

func build_music(name: String = "neon") -> AudioStreamWAV:
	var bpm = 128.0
	var beat = 60.0 / bpm
	var bars = 8
	var count = int(beat * 4.0 * bars * RATE)
	var out = PackedFloat32Array()
	out.resize(count)
	var is_boss = name.begins_with("boss")
	var is_pressure = name == "pressure"
	var root: Array = ROOTS.get(name, ROOTS["neon"])
	var lead: Array = LEADS.get(name, LEADS["neon"])
	var wave = "tri" if name in ["frost", "candy"] else "saw"
	var kick = synth(0.23, 115, 38, "sine", 0.05, 16, 0.47)
	var snare = synth(0.15, 195, 135, "tri", 0.73, 20, 0.28, 0.6)
	var hat = synth(0.035, 7500, 7000, "square", 0.9, 95, 0.1, 0.7)
	for bar in range(bars):
		var base = bar * 16
		var base_root = int(root[bar % root.size()])
		for step in range(16):
			var pos = int((base + step) * beat * 0.25 * RATE)
			if is_pressure:
				if step % 2 == 1:
					paste(out, hat, pos)
				if step in [2, 6, 10, 14]:
					paste(out, snare, pos)
				if bar >= 4 and step % 4 == 0:
					paste(out, synth(0.14, 115, 55, "sine", 0.0, 22, 0.32), pos)
				continue
			if step in [0, 8] or is_boss and step in [4, 12]:
				paste(out, kick, pos)
			if step in [4, 12]:
				paste(out, snare, pos)
			if step % 2 == 0 or name in ["ash", "boss_fury"] and step % 2 == 1:
				paste(out, hat, pos)
			if step % 4 == 0 or is_boss and step % 4 == 2:
				var note = base_root + (12 if step == 12 else 0)
				paste(out, synth(0.22, hz(note), hz(note) * 0.96, "saw", 0.0, 8.0, 0.21, 0.25), pos)
			var pitch = int(lead[step])
			if pitch > 0 and (bar % 4 != 0 or step % 2 == 0):
				var accent = 1.15 if bar >= 4 else 0.82
				paste(out, synth(0.20 if is_boss else 0.32, hz(pitch), hz(pitch), wave, 0.01,
					8.5 if is_boss else 6.0, 0.105 * accent, 0.47 if wave == "saw" else 0.9), pos)
			if step == 0:
				for chord_offset in [0, 3 if name != "candy" else 4, 7]:
					paste(out, synth(beat * 1.55, hz(base_root + 12 + chord_offset),
						hz(base_root + 12 + chord_offset), "tri", 0.0, 1.7, 0.065, 0.65), pos)
	# Soft master level leaves headroom for intense SFX and adaptive percussion.
	for i in range(out.size()):
		out[i] = tanh(out[i] * 0.80)
	return to_stream(out, true)

func paste(out: PackedFloat32Array, src: PackedFloat32Array, pos: int) -> void:
	for i in range(src.size()):
		var j = pos + i
		if j >= out.size():
			return
		out[j] += src[i]
