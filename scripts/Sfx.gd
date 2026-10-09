extends Node
## Procedurally synthesized sound effects and a looping beat. No audio files needed.

const RATE = 22050
var streams: Dictionary = {}
var players: Array = []
var last_play: Dictionary = {}
var music_player: AudioStreamPlayer
var sfx_volume = 0.7
var music_volume = 0.45
var music_ready = false

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
	add_child(music_player)
	build_all()

func set_volumes(s: float, m: float) -> void:
	sfx_volume = s
	music_volume = m
	if music_player != null:
		music_player.volume_db = linear_to_db(maxf(0.0001, m * 0.55))

func play(name: String, pitch_jitter = 0.08, vol = 1.0) -> void:
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
	free.pitch_scale = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
	free.volume_db = linear_to_db(maxf(0.0001, sfx_volume * vol * 0.6 / sqrt(1.0 + active * 0.35)))
	free.play()

func music_on(on: bool) -> void:
	if on and music_volume > 0.01:
		if not music_ready:
			music_ready = true
			music_player.stream = build_music()
		if not music_player.playing:
			music_player.play()
	elif music_player.playing and not on:
		music_player.stop()

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
	streams["boom2"] = streams["boom"]
	streams["shot"] = streams["pew"]

func arpeggio(notes: Array, step: float, wave: String, vol: float) -> PackedFloat32Array:
	var out = PackedFloat32Array()
	for i in range(notes.size()):
		out = mix(out, synth(step * 2.2, notes[i], notes[i], wave, 0.0, 9, vol), int(i * step * RATE))
	return out

func build_music() -> AudioStreamWAV:
	# 8 bars of a bouncy 128bpm beat: kick, snare, hats and a minor-pentatonic bass.
	var bpm = 128.0
	var beat = 60.0 / bpm
	var bars = 4
	var n = int(beat * 4 * bars * RATE)
	var out = PackedFloat32Array()
	out.resize(n)
	var bass_notes = [55.0, 55.0, 65.4, 49.0, 55.0, 73.4, 65.4, 49.0]
	var kick = synth(0.25, 120, 40, "sine", 0.0, 14, 0.8)
	var snare = synth(0.18, 220, 180, "tri", 0.75, 18, 0.4, 0.6)
	var hat = synth(0.04, 8000, 8000, "square", 0.95, 80, 0.12, 0.9)
	var steps = bars * 16
	for s in range(steps):
		var pos = int(s * beat / 4.0 * RATE)
		var in_bar = s % 16
		if in_bar % 4 == 0 or in_bar == 10:
			paste(out, kick, pos)
		if in_bar == 4 or in_bar == 12:
			paste(out, snare, pos)
		if in_bar % 2 == 0:
			paste(out, hat, pos)
		if in_bar % 2 == 0:
			var note = bass_notes[(s / 4) % bass_notes.size()] * (2.0 if in_bar % 8 == 6 else 1.0)
			paste(out, synth(beat / 2.0 * 0.9, note, note, "saw", 0.0, 6, 0.22, 0.12), pos)
	return to_stream(out, true)

func paste(out: PackedFloat32Array, src: PackedFloat32Array, pos: int) -> void:
	for i in range(src.size()):
		var j = pos + i
		if j >= out.size():
			return
		out[j] += src[i]
