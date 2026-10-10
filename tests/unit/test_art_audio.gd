extends GutTest

var RULES: GameRules = load("res://data/rules/game_rules.tres") as GameRules
const LAYOUT: MapLayout = preload("res://data/rules/map_layout.tres")


func _kid(index: int) -> KidModel:
	var kid: KidModel = autofree(KidModel.new()) as KidModel
	kid.setup(RULES.characters[index], Palette.TEAM_OWN, RULES.player_radius)
	add_child(kid)
	return kid


func _height(node: Node3D) -> float:
	var top: float = 0.0
	for child: Node in node.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = child as MeshInstance3D
		if not mesh.visible or not mesh.is_visible_in_tree() or mesh.name == "TeamRing":
			continue
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		top = maxf(top, box.end.y)
	return top


func test_all_six_kids_share_one_silhouette_height() -> void:
	var heights: Array[float] = []
	for i: int in RULES.characters.size():
		heights.append(_height(_kid(i)))
	for height: float in heights:
		assert_almost_eq(height, heights[0], 0.2, "same body, hair and caps only add a little")
		assert_between(height, 1.8, 2.5)


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
	assert_eq(box.bg_color, BayabasTheme.BUTTON)
