class_name SoundBank
extends RefCounted
## Every sound is synthesised in code (no audio files, nothing to license):
## short chunky SFX and a looping, upbeat street-game music track.
## Streams are 16-bit mono AudioStreamWAV, cached after the first build.

const RATE: int = 22050
## The music is lo-fi on purpose: a lower rate keeps generation fast on phones.
const MUSIC_RATE: int = 11025
const TEMPO: float = 124.0

static var _cache: Dictionary[StringName, AudioStreamWAV] = {}


static func get_sound(id: StringName) -> AudioStreamWAV:
	if not _cache.has(id):
		_cache[id] = _build(id)
	return _cache[id]


static func ids() -> Array[StringName]:
	return [&"cast", &"hit", &"snip", &"boing", &"bonk", &"crunch", &"thud", &"point", &"lose_point",
		&"set", &"horn", &"down", &"revive", &"click", &"dash", &"heal", &"stun", &"poof", &"footstep",
		&"ko", &"respawn", &"victory", &"defeat", &"ui_click", &"ui_back", &"mark", &"tick",
		&"cast_bato_light", &"cast_bato_heavy", &"cast_gunting_light", &"cast_gunting_heavy",
		&"cast_papel_trap", &"cast_papel_shield", &"cast_tsinelas_light", &"cast_tsinelas_heavy",
		&"cast_lata", &"cast_jacks", &"cast_bola", &"cast_trumpo"]


## The cast sound for a weapon id (falls back to the generic cast).
static func cast_id(weapon_id: StringName) -> StringName:
	var id: StringName = StringName("cast_" + String(weapon_id))
	return id if ids().has(id) else &"cast"


static func _build(id: StringName) -> AudioStreamWAV:
	match id:
		&"cast":
			return _render(0.18, func(t: float, d: float) -> float:
				return _noise(t) * 0.5 * _env(t, d, 0.01) * (1.0 - t / d) + _square(600.0 - 1400.0 * t, t) * 0.12 * _env(t, d, 0.005))
		&"dash":
			return _render(0.22, func(t: float, d: float) -> float:
				return _noise(t * 0.6) * 0.45 * _env(t, d, 0.02))
		&"hit":
			return _render(0.2, func(t: float, d: float) -> float:
				return (sin(TAU * (160.0 - 300.0 * t) * t) * 0.8 + _noise(t) * 0.3) * _env(t, d, 0.002))
		&"snip":
			return _render(0.09, func(t: float, d: float) -> float:
				return (_square(2400.0, t) * 0.25 + _noise(t) * 0.4) * _env(t, d, 0.001))
		&"boing":
			return _render(0.35, func(t: float, d: float) -> float:
				return sin(TAU * (220.0 + 380.0 * sin(t * 18.0) * exp(-t * 6.0)) * t) * 0.6 * _env(t, d, 0.005))
		&"bonk":
			return _render(0.3, func(t: float, d: float) -> float:
				return (sin(TAU * 330.0 * t) * 0.5 + sin(TAU * 495.0 * t) * 0.3) * exp(-t * 14.0))
		&"crunch":
			return _render(0.4, func(t: float, d: float) -> float:
				return _noise(t * (1.0 + 3.0 * t)) * 0.7 * _env(t, d, 0.004) * (0.6 + 0.4 * _square(23.0, t)))
		&"thud":
			return _render(0.14, func(t: float, d: float) -> float:
				return sin(TAU * 110.0 * t) * 0.6 * exp(-t * 30.0) + _noise(t) * 0.15 * exp(-t * 40.0))
		&"point":
			return _arpeggio([523.25, 659.25, 783.99, 1046.5], 0.09, 0.5)
		&"lose_point":
			return _arpeggio([392.0, 329.63, 261.63], 0.12, 0.45)
		&"set":
			return _arpeggio([523.25, 659.25, 783.99, 1046.5, 783.99, 1046.5, 1318.5], 0.08, 0.5)
		&"horn":
			return _render(0.7, func(t: float, d: float) -> float:
				var on: float = 1.0 if t < 0.24 or (t > 0.36 and t < 0.6) else 0.0
				return (_square(415.0, t) + _square(523.0, t)) * 0.18 * on)
		&"down":
			return _render(0.5, func(t: float, d: float) -> float:
				return _square(330.0 - 220.0 * t / d, t) * 0.2 * _env(t, d, 0.01))
		&"revive":
			return _arpeggio([392.0, 523.25, 659.25], 0.07, 0.4)
		&"heal":
			return _arpeggio([523.25, 659.25, 783.99, 1046.5, 1318.5], 0.07, 0.45)
		&"stun":
			return _render(0.35, func(t: float, d: float) -> float:
				return (sin(TAU * 880.0 * t) * 0.35 + sin(TAU * 1320.0 * t) * 0.2) * exp(-t * 9.0) + sin(TAU * 140.0 * t) * 0.4 * exp(-t * 28.0))
		&"poof":
			return _render(0.4, func(t: float, d: float) -> float:
				return _noise(t * 0.4) * 0.5 * exp(-t * 9.0) + sin(TAU * (500.0 - 900.0 * t) * t) * 0.35 * exp(-t * 12.0))
		&"footstep":
			return _render(0.07, func(t: float, d: float) -> float:
				return (_noise(t) * 0.25 + sin(TAU * 90.0 * t) * 0.35) * exp(-t * 55.0))
		&"ko":
			return _render(0.7, func(t: float, d: float) -> float:
				return _square(260.0 - 200.0 * t / d, t) * 0.22 * _env(t, d, 0.01) + sin(TAU * 70.0 * t) * 0.35 * exp(-t * 6.0))
		&"respawn":
			return _arpeggio([392.0, 587.33, 783.99], 0.09, 0.4)
		&"victory":
			return _arpeggio([523.25, 659.25, 783.99, 659.25, 783.99, 1046.5, 1318.5, 1568.0], 0.11, 0.55)
		&"defeat":
			return _arpeggio([392.0, 349.23, 311.13, 261.63], 0.2, 0.45)
		&"ui_click":
			return _render(0.07, func(t: float, d: float) -> float:
				return (sin(TAU * 740.0 * t) * 0.5 + sin(TAU * 1480.0 * t) * 0.2) * exp(-t * 55.0))
		&"ui_back":
			return _render(0.08, func(t: float, d: float) -> float:
				return sin(TAU * 520.0 * t) * 0.5 * exp(-t * 45.0))
		&"mark":
			return _render(0.3, func(t: float, d: float) -> float:
				return sin(TAU * (300.0 + 1500.0 * t) * t) * 0.4 * _env(t, d, 0.005) + _noise(t) * 0.1 * exp(-t * 14.0))
		&"tick":
			return _render(0.05, func(t: float, d: float) -> float:
				return _square(1000.0, t) * 0.18 * exp(-t * 70.0))
		&"cast_bato_light":
			return _render(0.16, func(t: float, d: float) -> float:
				return _noise(t * 0.5) * 0.4 * _env(t, d, 0.01) * (1.0 - t / d) + sin(TAU * (520.0 - 1500.0 * t) * t) * 0.2 * _env(t, d, 0.004))
		&"cast_bato_heavy":
			return _render(0.3, func(t: float, d: float) -> float:
				return _noise(t * 0.3) * 0.5 * _env(t, d, 0.02) + sin(TAU * (260.0 - 500.0 * t) * t) * 0.35 * _env(t, d, 0.01))
		&"cast_gunting_light":
			return _render(0.18, func(t: float, d: float) -> float:
				var burst: float = 1.0 if fmod(t, 0.09) < 0.04 else 0.3
				return (_square(2600.0, t) * 0.18 + _noise(t) * 0.35) * burst * exp(-fmod(t, 0.09) * 40.0))
		&"cast_gunting_heavy":
			return _render(0.25, func(t: float, d: float) -> float:
				return (_square(1800.0 - 600.0 * t, t) * 0.2 + _noise(t) * 0.4) * exp(-t * 12.0))
		&"cast_papel_trap":
			return _render(0.3, func(t: float, d: float) -> float:
				return _noise(floor(t * 90.0) / 90.0) * 0.45 * _env(t, d, 0.01) * (0.5 + 0.5 * _square(17.0, t)))
		&"cast_papel_shield":
			return _render(0.28, func(t: float, d: float) -> float:
				return _noise(floor(t * 60.0) / 60.0) * 0.4 * _env(t, d, 0.03) + sin(TAU * 300.0 * t) * 0.08)
		&"cast_tsinelas_light":
			return _render(0.22, func(t: float, d: float) -> float:
				return (_noise(t) * 0.35 + sin(TAU * 180.0 * t) * 0.3) * exp(-fmod(t, 0.07) * 50.0) * _env(t, d, 0.003))
		&"cast_tsinelas_heavy":
			return _render(0.3, func(t: float, d: float) -> float:
				return (_noise(t * 0.6) * 0.45 + sin(TAU * 110.0 * t) * 0.4) * exp(-t * 8.0))
		&"cast_lata":
			return _render(0.45, func(t: float, d: float) -> float:
				return (sin(TAU * 1250.0 * t) * 0.3 + sin(TAU * 1830.0 * t) * 0.22 + sin(TAU * 2700.0 * t) * 0.12) * exp(-t * 11.0))
		&"cast_jacks":
			return _render(0.4, func(t: float, d: float) -> float:
				var ping: float = fmod(t, 0.1)
				return sin(TAU * (1900.0 + 400.0 * floor(t / 0.1)) * t) * 0.3 * exp(-ping * 40.0) * (1.0 - t / d))
		&"cast_bola":
			return _render(0.35, func(t: float, d: float) -> float:
				return sin(TAU * (180.0 + 260.0 * sin(t * 14.0)) * t) * 0.55 * exp(-t * 5.0))
		&"cast_trumpo":
			return _render(0.45, func(t: float, d: float) -> float:
				return (_square(300.0 + 900.0 * t, t) * 0.14 + _noise(t) * 0.12) * (0.6 + 0.4 * _square(28.0, t)) * _env(t, d, 0.02))
		&"click":
			return _render(0.05, func(t: float, d: float) -> float:
				return _square(1200.0, t) * 0.2 * exp(-t * 80.0))
	return _render(0.05, func(_t: float, _d: float) -> float: return 0.0)


## Builds the match music a chunk at a time (so phones don't freeze for a second):
## 8 bars of a pentatonic tune over a bouncing bass, hats and a soft kick. Loops.
class MusicRenderer extends RefCounted:
	# C major pentatonic, one note per eighth (-1 = rest): a simple hand-written tune
	const MELODY: Array[int] = [
		0, 2, 4, 7, 9, 7, 4, 2, 0, 2, 4, 2, 0, -1, 0, -1,
		4, 7, 9, 12, 9, 7, 4, 7, 9, 7, 4, 2, 4, -1, 4, -1,
		0, 2, 4, 7, 9, 7, 4, 2, 0, 2, 4, 7, 9, 12, 9, 7,
		12, 9, 7, 4, 7, 4, 2, 0, 2, 4, 2, -1, 0, -1, 0, -1,
	]
	const BASS_ROOTS: Array[int] = [0, 0, -3, -3, -7, -7, -5, -5]
	const BARS: int = 8

	var _beat: float = 60.0 / TEMPO
	var _count: int = 0
	var _next: int = 0
	var _data: PackedByteArray = PackedByteArray()

	func _init() -> void:
		_count = int(_beat * 4.0 * BARS * MUSIC_RATE)
		_data.resize(_count * 2)

	func progress() -> float:
		return float(_next) / float(_count)

	## Renders up to `samples` more samples; true when the whole loop is done.
	func step(samples: int) -> bool:
		var stop: int = mini(_count, _next + samples)
		for i: int in range(_next, stop):
			_data.encode_s16(i * 2, int(clampf(_sample(float(i) / MUSIC_RATE), -1.0, 1.0) * 32767.0))
		_next = stop
		return _next >= _count

	func stream() -> AudioStreamWAV:
		var wav: AudioStreamWAV = AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = MUSIC_RATE
		wav.data = _data
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = _count
		return wav

	func _sample(t: float) -> float:
		var half: float = _beat / 2.0
		var in_eighth: float = fmod(t, half)
		var note: int = MELODY[int(t / half) % MELODY.size()]
		var value: float = 0.0
		if note >= 0:
			value += SoundBank._square(SoundBank._midi(72 + note), t) * 0.09 * exp(-in_eighth * 5.0)
		var root: int = BASS_ROOTS[int(t / (_beat * 4.0)) % BASS_ROOTS.size()]
		var octave: int = 12 if int(t / _beat) % 2 == 1 else 0
		value += SoundBank._triangle(SoundBank._midi(48 + root + octave), t) * 0.22 * exp(-fmod(t, _beat) * 3.0)
		if in_eighth < 0.03:
			value += SoundBank._noise(t) * 0.08 * (1.0 - in_eighth / 0.03)
		var in_kick: float = fmod(t, _beat * 2.0)
		if in_kick < 0.06:
			value += sin(TAU * 70.0 * in_kick) * 0.3 * (1.0 - in_kick / 0.06)
		return value


static func _render(duration: float, wave: Callable) -> AudioStreamWAV:
	var count: int = int(duration * RATE)
	var data: PackedByteArray = PackedByteArray()
	data.resize(count * 2)
	for i: int in count:
		var t: float = float(i) / RATE
		var value: float = wave.call(t, duration) as float
		data.encode_s16(i * 2, int(clampf(value, -1.0, 1.0) * 32767.0))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	return stream


static func _arpeggio(notes: Array[float], step: float, volume: float) -> AudioStreamWAV:
	var duration: float = step * notes.size() + 0.25
	return _render(duration, func(t: float, _d: float) -> float:
		var index: int = mini(int(t / step), notes.size() - 1)
		var local: float = t - step * index
		return (_square(notes[index], t) * 0.5 + sin(TAU * notes[index] * 2.0 * t) * 0.2) * volume * exp(-local * 6.0))


static func _env(t: float, duration: float, attack: float) -> float:
	var rise: float = clampf(t / attack, 0.0, 1.0)
	return rise * clampf((duration - t) / (duration * 0.6), 0.0, 1.0)


static func _square(frequency: float, t: float) -> float:
	return 1.0 if fmod(t * frequency, 1.0) < 0.5 else -1.0


static func _triangle(frequency: float, t: float) -> float:
	return 4.0 * absf(fmod(t * frequency, 1.0) - 0.5) - 1.0


## Deterministic white-ish noise from the time value (no RNG state needed).
static func _noise(t: float) -> float:
	return fposmod(sin(t * 12989.8) * 43758.5453, 1.0) * 2.0 - 1.0


static func _midi(note: int) -> float:
	return 440.0 * pow(2.0, float(note - 69) / 12.0)
