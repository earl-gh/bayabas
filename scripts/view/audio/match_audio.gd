class_name MatchAudio
extends Node
## Plays the synthesised SFX for match events and the looping music. Listens to
## MatchSim signals only (works offline and online, where events are replayed).

const VOICES: int = 8
const MUSIC_DB: float = -12.0
const SFX_DB: float = -4.0
## Music samples rendered per frame while it is being built (keeps frames smooth).
const MUSIC_CHUNK: int = 4000
## Wall hits are frequent: at most one thud per this many seconds.
const THUD_GAP: float = 0.12

var _sim: MatchSim
var _local_team: int = 0
var _local_id: int = -1
var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _music: AudioStreamPlayer
var _renderer: SoundBank.MusicRenderer
var _last_thud: float = -1.0
var _clock: float = 0.0
## Ids of every sound played, newest last (for tests and debugging).
var played: Array[StringName] = []


func watch(sim: MatchSim, local_team: int, local_id: int = -1) -> void:
	_sim = sim
	_local_team = local_team
	_local_id = local_id
	for i: int in VOICES:
		var voice: AudioStreamPlayer = AudioStreamPlayer.new()
		voice.volume_db = SFX_DB
		add_child(voice)
		_voices.append(voice)
	_music = AudioStreamPlayer.new()
	_music.volume_db = MUSIC_DB
	add_child(_music)
	sim.weapon_cast.connect(func(_id: int, weapon: StringName) -> void: play(SoundBank.cast_id(weapon), 0.06))
	sim.player_dashed.connect(func(_id: int) -> void: play(&"dash", 0.05))
	sim.bookmark_used.connect(func(_id: int) -> void: play(&"mark"))
	sim.player_healed.connect(func(_id: int, _amount: int) -> void: play(&"heal"))
	sim.effect_applied.connect(_on_effect)
	sim.player_died.connect(func(_id: int) -> void: play(&"ko"))
	sim.player_respawned.connect(func(id: int) -> void: if id == _local_id: play(&"respawn"))
	sim.match_won.connect(func(team: int) -> void: play(&"victory" if team == _local_team else &"defeat"))
	sim.player_damaged.connect(func(_id: int, _amount: int) -> void: play(&"hit", 0.08))
	sim.weapons.cone_struck.connect(func(_owner: int, _def: WeaponDef, _origin: Vector2, _dir: Vector2) -> void: play(&"snip"))
	sim.wall_damaged.connect(_on_wall_damaged)
	sim.wall_destroyed.connect(func(_index: int) -> void: play(&"crunch"))
	sim.point_scored.connect(func(team: int, _by: int) -> void: play(&"point" if team == _local_team else &"lose_point"))
	sim.set_won.connect(func(_team: int) -> void: play(&"set"))
	sim.player_death_delay_started.connect(func(_id: int) -> void: play(&"down"))
	sim.player_revived.connect(func(_id: int, _by: int) -> void: play(&"revive"))
	sim.ball.thrown.connect(func(_id: int) -> void: play(&"boing"))
	sim.ball.caught.connect(func(_id: int) -> void: play(&"boing"))
	sim.ball.picked_up.connect(func(_id: int) -> void: play(&"crunch"))
	sim.ball.knocked_out.connect(func(_id: int) -> void: play(&"bonk"))
	sim.ball.wall_hit.connect(func(_index: int) -> void: play(&"crunch"))
	sim.ball.blinked.connect(func(_id: int) -> void: play(&"dash"))
	sim.tricycle.warning_started.connect(func(_direction: int) -> void: play(&"horn"))


## Starts building (then playing) the music loop.
func start_music() -> void:
	if _renderer == null and _music.stream == null:
		_renderer = SoundBank.MusicRenderer.new()


func music_playing() -> bool:
	return _music != null and _music.playing


## `pitch_variation` (0.06 = +-6%) keeps repeated sounds from sounding identical.
func play(id: StringName, pitch_variation: float = 0.0) -> void:
	played.append(id)
	if played.size() > 64:
		played.pop_front()
	var voice: AudioStreamPlayer = _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stream = SoundBank.get_sound(id)
	voice.pitch_scale = 1.0 + (randf() * 2.0 - 1.0) * pitch_variation
	voice.volume_db = SFX_DB - (11.0 if id == &"footstep" else 0.0)
	voice.play()


func _on_effect(_id: int, type: int) -> void:
	match type:
		StatusEffects.Type.POLYMORPH:
			play(&"poof")
		StatusEffects.Type.STUN, StatusEffects.Type.AIRBORNE, StatusEffects.Type.BOUNCE, StatusEffects.Type.KNOCKOUT:
			play(&"stun")


func _process(delta: float) -> void:
	_clock += delta
	if _renderer != null and _renderer.step(MUSIC_CHUNK):
		_music.stream = _renderer.stream()
		_renderer = null
		_music.play()


func _on_wall_damaged(_index: int) -> void:
	if _clock - _last_thud >= THUD_GAP:
		_last_thud = _clock
		play(&"thud")
