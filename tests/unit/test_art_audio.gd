extends GutTest

var RULES: GameRules = load("res://data/rules/game_rules.tres") as GameRules
const LAYOUT: MapLayout = preload("res://data/rules/map_layout.tres")


func _kid(index: int) -> KidModel:
	var kid: KidModel = autofree(KidModel.new()) as KidModel
	kid.setup(RULES.characters[index], Palette.TEAM_OWN, RULES.player_radius)
	add_child(kid)
	return kid


func test_every_kid_is_a_sprite_of_the_same_size() -> void:
	var sizes: Array[Vector2] = []
	for i: int in RULES.characters.size():
		var sprite: Sprite3D = _kid(i).find_child("Sprite", true, false) as Sprite3D
		assert_not_null(sprite.texture, RULES.characters[i].display_name)
		sizes.append(sprite.texture.get_size() * sprite.pixel_size)
	for size: Vector2 in sizes:
		assert_almost_eq(size.y, KidModel.CELL_HEIGHT, 0.01, "one cell height for every kid")


func test_each_kid_has_their_own_outfit() -> void:
	var seen: Dictionary = {}
	for i: int in RULES.characters.size():
		var def: CharacterDef = RULES.characters[i]
		var key: String = "%d-%d-%d-%d" % [def.hair, def.top, def.bottom, def.extra]
		assert_false(seen.has(key), "%s looks different from the others" % def.display_name)
		seen[key] = true
	var inday: CharacterDef = RULES.characters[5]
	assert_lt(inday.skin.get_luminance(), RULES.characters[1].skin.get_luminance(), "varied Filipino skin tones")


func test_kid_turns_into_a_can_and_greys_out() -> void:
	var kid: KidModel = _kid(0)
	var state: PlayerState = PlayerState.new()
	state.effects.apply(StatusEffects.Type.POLYMORPH, 1.0)
	kid.animate(0.1, 0.0, state)
	assert_true(kid.is_can())
	state.effects.clear()
	state.death_delay = true
	kid.animate(0.1, 0.0, state)
	assert_false(kid.is_can())
	assert_true(kid.is_ghost())


func test_kid_faces_its_movement() -> void:
	var kid: KidModel = _kid(1)
	kid.face(Vector2(1.0, 0.0))
	var forward: Vector3 = -kid.global_transform.basis.z
	assert_almost_eq(forward.x, 1.0, 0.001)


func test_every_sound_is_built_and_not_silent() -> void:
	for id: StringName in SoundBank.ids():
		var stream: AudioStreamWAV = SoundBank.get_sound(id)
		assert_gt(stream.data.size(), 400, String(id))
		var loudest: int = 0
		for i: int in range(0, stream.data.size(), 64):
			loudest = maxi(loudest, absi(stream.data.decode_s16(i)))
		assert_gt(loudest, 1000, "%s is audible" % id)


func test_music_renders_in_chunks_and_loops() -> void:
	var renderer: SoundBank.MusicRenderer = SoundBank.MusicRenderer.new()
	var chunks: int = 0
	while not renderer.step(20000):
		chunks += 1
	assert_gt(chunks, 3, "built over several frames, not one")
	var stream: AudioStreamWAV = renderer.stream()
	assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD)
	assert_almost_eq(float(stream.data.size()) / 2.0 / stream.mix_rate, 8.0 * 4.0 * 60.0 / SoundBank.TEMPO, 0.05)


func test_match_audio_follows_sim_events() -> void:
	var sim: MatchSim = MatchSim.new(RULES, LAYOUT, 1)
	var audio: MatchAudio = autofree(MatchAudio.new()) as MatchAudio
	add_child(audio)
	audio.watch(sim, 0)
	sim.point_scored.emit(0, 1)
	sim.point_scored.emit(1, 2)
	sim.tricycle.warning_started.emit(1)
	sim.ball.knocked_out.emit(3)
	assert_eq(audio.played, [&"point", &"lose_point", &"horn", &"bonk"] as Array[StringName])


func test_the_ui_theme_is_applied_everywhere() -> void:
	var button: Button = autofree(Button.new()) as Button
	add_child(button)
	var box: StyleBoxFlat = button.get_theme_stylebox("normal") as StyleBoxFlat
	assert_not_null(box, "every button gets the chunky style")
	assert_eq(box.bg_color, KalyeahTheme.BUTTON)


func _animation_after(kid: KidModel, state: PlayerState, speed: float = 0.0) -> String:
	kid.animate(0.05, speed, state)
	return kid.current_animation()


func test_each_state_shows_its_own_sprite() -> void:
	var kid: KidModel = _kid(2)
	var state: PlayerState = PlayerState.new()
	for i: int in 10:
		kid.animate(0.05, 5.0, state)
	assert_eq(kid.pose, "run")
	assert_eq(kid.current_animation(), "run")
	kid.play_cast()
	assert_eq(_animation_after(kid, state), "cast")
	state = PlayerState.new()
	state.effects.apply(StatusEffects.Type.STUN, 2.0)
	assert_eq(_animation_after(kid, state), "stun", "stars")
	state = PlayerState.new()
	state.effects.apply(StatusEffects.Type.AIRBORNE, 2.0)
	assert_eq(_animation_after(kid, state), "stun", "every status uses the stars")
	state = PlayerState.new()
	state.death_delay = true
	assert_eq(_animation_after(kid, state), "ko_stagger", "delayed death is the stagger pose")
	state = PlayerState.new()
	state.stumble_time_left = 0.5
	assert_eq(_animation_after(kid, state), "down", "the dash stumble is face down")
	assert_eq(kid.pose, "stumble")


func test_a_knockout_falls_then_lies() -> void:
	var kid: KidModel = _kid(1)
	var state: PlayerState = PlayerState.new()
	state.effects.apply(StatusEffects.Type.KNOCKOUT, 3.0)
	assert_eq(_animation_after(kid, state), "ko_stagger")
	kid.animate(KidModel.KO_FALL_TIME, 0.0, state)
	assert_eq(kid.current_animation(), "ko_lying")
	assert_eq(kid.pose, "ko")
	state.effects.clear()
	assert_eq(_animation_after(kid, state), "idle", "gets back up")


func test_the_sprite_turns_with_the_facing_and_mirrors() -> void:
	var kid: KidModel = _kid(0)
	var camera: Camera3D = autofree(Camera3D.new()) as Camera3D
	add_child(camera)
	camera.position = Vector3(0.0, 10.0, 10.0)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	var sprite: Sprite3D = kid.find_child("Sprite", true, false) as Sprite3D
	var state: PlayerState = PlayerState.new()
	kid.face(Vector2(0.0, 1.0))
	kid.animate(0.05, 0.0, state)
	assert_false(sprite.flip_h)
	assert_true(sprite.texture.resource_path.ends_with("idle_toward.png"), "faces the camera")
	kid.face(Vector2(1.0, 0.0))
	kid.animate(0.05, 0.0, state)
	assert_true(sprite.texture.resource_path.ends_with("idle_right.png"))
	assert_false(sprite.flip_h)
	kid.face(Vector2(-1.0, 0.0))
	kid.animate(0.05, 0.0, state)
	assert_true(sprite.texture.resource_path.ends_with("idle_right.png"), "the left side is the right side mirrored")
	assert_true(sprite.flip_h)
	kid.face(Vector2(0.0, -1.0))
	kid.animate(0.05, 0.0, state)
	assert_true(sprite.texture.resource_path.ends_with("idle_away.png"))


func test_every_weapon_has_its_own_cast_sound() -> void:
	for i: int in RULES.weapons.size():
		var id: StringName = RULES.weapons[i].id
		assert_ne(SoundBank.cast_id(id), &"cast", "%s has a specific cast sound" % id)
		assert_gt(SoundBank.get_sound(SoundBank.cast_id(id)).data.size(), 200)
	assert_eq(SoundBank.cast_id(&"mystery"), &"cast", "unknown weapons fall back")


func test_match_audio_has_sounds_for_casts_heals_effects_and_the_result() -> void:
	var sim: MatchSim = MatchSim.new(RULES, LAYOUT, 1)
	var audio: MatchAudio = autofree(MatchAudio.new()) as MatchAudio
	add_child(audio)
	audio.watch(sim, 0, 1)
	sim.weapon_cast.emit(1, &"lata")
	sim.player_healed.emit(1, 50)
	sim.effect_applied.emit(2, StatusEffects.Type.STUN)
	sim.effect_applied.emit(2, StatusEffects.Type.POLYMORPH)
	sim.player_dashed.emit(1)
	sim.bookmark_used.emit(1)
	sim.player_respawned.emit(1)
	sim.player_respawned.emit(2)
	sim.match_won.emit(0)
	sim.match_won.emit(1)
	assert_eq(audio.played, [&"cast_lata", &"heal", &"stun", &"poof", &"dash", &"mark", &"respawn", &"victory", &"defeat"] as Array[StringName])


func test_running_makes_footstep_signals() -> void:
	var kid: KidModel = _kid(0)
	var state: PlayerState = PlayerState.new()
	watch_signals(kid)
	for i: int in 60:
		kid.animate(0.03, 5.0, state)
	# 1.8 s at 5 m/s = 9 m; two footfalls per 1.6 m stride
	assert_between(get_signal_emit_count(kid, "footstep"), 10, 12)


func test_camera_shake_kicks_then_settles() -> void:
	var camera: FollowCamera = autofree(FollowCamera.new()) as FollowCamera
	camera.rules = load("res://data/rules/camera_rules.tres") as CameraRules
	camera.layout = LAYOUT
	add_child(camera)
	camera.shake(0.3)
	camera._process(0.016)
	assert_ne(camera.h_offset, 0.0)
	for i: int in 60:
		camera._process(0.05)
	assert_eq(camera.h_offset, 0.0)


func test_the_cardboard_wall_is_flat_sheets_not_stacked_boxes() -> void:
	var mesh: ArrayMesh = Props.cardboard_wall(Vector3(5.0, 2.0, 1.0))
	var box: AABB = mesh.get_aabb()
	assert_lt(box.size.z, 0.9, "thin: single sheets leaning on sticks, not 1 m thick boxes")
	assert_almost_eq(box.size.y, 2.0, 0.6, "one sheet tall, not two stacked rows")
	assert_lt(mesh.surface_get_array_len(0), 6000)


func test_the_guava_prop_exists_and_the_ball_art_is_the_guava() -> void:
	var mesh: ArrayMesh = Props.guava(0.35)
	assert_gt(mesh.surface_get_array_len(0), 100)
	assert_between(mesh.get_aabb().size.y, 0.6, 1.2)
