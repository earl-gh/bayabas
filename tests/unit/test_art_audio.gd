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
	sim.ball.hit_enemy.emit(3)
	assert_eq(audio.played, [&"point", &"lose_point", &"horn", &"bonk"] as Array[StringName])


func test_the_ui_theme_is_applied_everywhere() -> void:
	var button: Button = autofree(Button.new()) as Button
	add_child(button)
	var box: StyleBoxTexture = button.get_theme_stylebox("normal") as StyleBoxTexture
	assert_not_null(box, "every button gets the painted, bevelled style")
	assert_not_null(box.texture)
	assert_eq(box.texture.resource_path, "res://assets/ui/button_orange.png")


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
	assert_eq(_animation_after(kid, state), "ko_stagger", "a tumble starts with the slightly falling pose")
	assert_eq(kid.pose, "stumble")
	for i: int in 6:
		kid.animate(0.05, 0.0, state)
	assert_eq(kid.current_animation(), "down", "then the face-down pose")


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


func test_every_skill_has_painted_art() -> void:
	for i: int in RULES.weapons.size():
		var def: WeaponDef = RULES.weapons[i]
		assert_not_null(Icons.art(StringName("btn_" + String(def.id))), String(def.id))
	for id: StringName in [&"guava", &"pin", &"btn_pin", &"btn_dash", &"btn_pin_return", &"btn_guava", &"btn_guava_bitten", &"gear"]:
		assert_not_null(Icons.art(id), String(id))


func test_cardboard_walls_carry_kids_doodles() -> void:
	var holder: Node3D = autofree(Node3D.new()) as Node3D
	var material: StandardMaterial3D = StreetArt.add_wall_doodles(holder, 5.0, 2.0, 1)
	assert_eq(holder.get_child_count(), 2, "both faces")
	assert_not_null(material.albedo_texture)
	assert_eq(material.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA)



func test_a_hit_wall_flashes_sheds_chips_and_tears_as_it_weakens() -> void:
	var sim: MatchSim = MatchSim.new(RULES, LAYOUT, 1)
	var view: WallsView = autofree(WallsView.new()) as WallsView
	add_child(view)
	view.watch(sim)
	sim.damage_wall(0, 30)
	assert_gt(view.hit_time_left(0), 0.0, "flashes and wobbles")
	var tears: StandardMaterial3D = (view.get_child(0).find_child("Tears", true, false) as MeshInstance3D).mesh.surface_get_material(0) as StandardMaterial3D
	var light: float = tears.albedo_color.a
	sim.damage_wall(0, 200)
	assert_gt(tears.albedo_color.a, light, "more rips and holes as it weakens")
	sim.damage_wall(0, 500)
	assert_eq(view.standing_count(), sim.walls.size() - 1, "broken walls disappear")


func test_a_moving_kid_keeps_running_between_the_30_hz_sim_steps() -> void:
	var kid: KidModel = _kid(0)
	var position: Vector2 = Vector2.ZERO
	var state: PlayerState = PlayerState.new()
	var run_frames: int = 0
	# 60 fps drawing, the sim moves the kid 5 m/s in 1/30 s steps (every other frame)
	for frame: int in 60:
		if frame % 2 == 0:
			position += Vector2(0.0, -5.0 / 30.0)
		var speed: float = kid.ground_speed(position, 1.0 / 60.0)
		kid.animate(1.0 / 60.0, speed, state)
		if frame > 12 and kid.current_animation() == "run":
			run_frames += 1
	assert_eq(run_frames, 47, "run on every drawn frame, never back to idle")
	for frame: int in 20:
		kid.animate(1.0 / 60.0, kid.ground_speed(position, 1.0 / 60.0), state)
	assert_eq(kid.current_animation(), "idle", "standing still again once the movement stops")


func test_the_mirror_does_not_flicker_while_the_facing_jitters() -> void:
	var kid: KidModel = _kid(1)
	var camera: Camera3D = autofree(Camera3D.new()) as Camera3D
	add_child(camera)
	camera.position = Vector3(0.0, 10.0, 10.0)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	var sprite: Sprite3D = kid.find_child("Sprite", true, false) as Sprite3D
	var state: PlayerState = PlayerState.new()
	# standing straight toward the camera with a hair of noise either side
	var flips: int = 0
	var last: bool = sprite.flip_h
	for i: int in 30:
		kid.face(Vector2(0.03 if i % 2 == 0 else -0.03, 1.0))
		kid.animate(0.02, 0.0, state)
		if sprite.flip_h != last:
			flips += 1
			last = sprite.flip_h
	assert_eq(flips, 0, "no left-right flipping")
	# and near a 45 degree boundary the direction does not chatter
	var changes: int = 0
	var previous: String = ""
	for i: int in 30:
		kid.face(Vector2.from_angle(deg_to_rad(112.0 + (3.0 if i % 2 == 0 else -3.0))))
		kid.animate(0.02, 5.0, state)
		var name: String = sprite.texture.resource_path
		if previous != "" and name != previous:
			changes += 1
		previous = name
	assert_lte(changes, 1, "settles on one direction")


func test_the_run_frame_mirrors_every_step_to_swap_the_forward_foot() -> void:
	var kid: KidModel = _kid(1)
	var sprite: Sprite3D = kid.find_child("Sprite", true, false) as Sprite3D
	var state: PlayerState = PlayerState.new()
	var flips: int = 0
	var last: bool = sprite.flip_h
	for i: int in 60:
		kid.animate(0.02, 5.0, state)
		if sprite.flip_h != last:
			flips += 1
			last = sprite.flip_h
	assert_gte(flips, 2, "mirrors while running")
	for i: int in 30:
		kid.animate(0.02, 0.0, state)
	assert_false(sprite.flip_h, "upright again when standing")


func test_the_run_frame_is_not_mirrored_on_side_and_diagonal_views() -> void:
	var kid: KidModel = _kid(1)
	var camera: Camera3D = autofree(Camera3D.new()) as Camera3D
	add_child(camera)
	camera.position = Vector3(0.0, 10.0, 10.0)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	var sprite: Sprite3D = kid.find_child("Sprite", true, false) as Sprite3D
	var state: PlayerState = PlayerState.new()
	for degrees: float in [45.0, 90.0, 135.0]:
		kid.face(Vector2(sin(deg_to_rad(degrees)), cos(deg_to_rad(degrees))))
		var flips: int = 0
		kid.animate(0.02, 5.0, state)
		var last: bool = sprite.flip_h
		for i: int in 60:
			kid.animate(0.02, 5.0, state)
			if sprite.flip_h != last:
				flips += 1
				last = sprite.flip_h
		assert_eq(flips, 0, "no stride mirroring at %d degrees" % int(degrees))
