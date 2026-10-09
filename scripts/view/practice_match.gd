class_name PracticeMatch
extends Node3D
## The match screen. Offline practice runs a local MatchSim with training dummies;
## online (`online = true`, scenes/match/online.tscn) it draws the GameClient's
## mirror of the server's match and sends inputs instead of stepping a sim.
## Reads sim state only; all rules live in scripts/sim/.

const LOCAL_ID: int = 1
const LOCAL_TEAM: int = 0
const ENEMY_STAND_ID: int = 2
const ENEMY_PATROL_ID: int = 3
const ALLY_ID: int = 4
const MAX_STEPS_PER_FRAME: int = 8
const PLAYER_HEIGHT: float = 1.8
const TAG_HEIGHT: float = 2.4
const TAG_PIXEL_SIZE: float = 0.012
const TAG_FONT_SIZE: int = 48
const RING_THICKNESS: float = 0.12
const AIRBORNE_LIFT: float = 1.0
const POLYMORPH_SCALE: Vector3 = Vector3(0.7, 0.4, 0.7)
## Aimed buttons: the two weapons and the ball (press, drag to aim, release).
const AIM_BITS: Array[int] = [PlayerInput.BTN_WEAPON_1, PlayerInput.BTN_WEAPON_2, PlayerInput.BTN_BALL]
const WEAPON_SLOTS: int = 2
const BALL_SLOT: int = 2
const BANNER_TIME: float = 2.0
const RECONNECT_INTERVAL: float = 2.0
## Practice-only debug button to test the death delay without an enemy that fights back.
const DEBUG_DAMAGE: int = 30
const ALLY_COLOR: Color = Color(0.5, 0.75, 1.0)
const DELAY_COLOR: Color = Color(0.62, 0.62, 0.66)
const POLYMORPH_COLOR: Color = Color(0.75, 0.75, 0.8)
const HP_TEXT_COLOR: Color = Color(1.0, 1.0, 1.0)

@export var rules: GameRules
@export var layout: MapLayout
## Online match: driven by Net.client (set `client` before adding to the tree to
## use another one, e.g. in tests).
@export var online: bool = false

var sim: MatchSim
var client: GameClient
var local_id: int = LOCAL_ID
var local_team: int = LOCAL_TEAM

var _accumulator: float = 0.0
var _stick: Vector2 = Vector2.ZERO
var _pending_buttons: int = 0
var _views: Dictionary[int, MeshInstance3D] = {}
var _materials: Dictionary[int, StandardMaterial3D] = {}
var _base_colors: Dictionary[int, Color] = {}
var _tags: Dictionary[int, Label3D] = {}
var _characters: Dictionary[StringName, CharacterDef] = {}
## The opening pick pauses the match; the respawn swap does not.
var _opening_pick: bool = false

# Per aimed slot (weapon 1, weapon 2, ball): touch aiming, a release waiting to
# be sent, and Q/E/R aiming.
var _touch_held: Array[bool] = [false, false, false]
var _sent_held: Array[bool] = [false, false, false]
var _release_pending: Array[bool] = [false, false, false]
var _release_aim: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
var _release_cancel: Array[bool] = [false, false, false]
var _key_held: Array[bool] = [false, false, false]
var _key_aim: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
var _key_cancel: Array[bool] = [false, false, false]
var _banner_left: float = 0.0
## Online: our own input counter (the server acks it for reconciliation).
var _input_tick: int = 0
## Online: seconds until the next reconnect attempt after the connection dropped.
var _reconnect_left: float = -1.0

@onready var _camera: FollowCamera = %FollowCamera
@onready var _joystick: VirtualJoystick = %Joystick
@onready var _actors: Node3D = %Actors
@onready var _fx: WeaponFxView = %WeaponFx
@onready var _aim_indicator: AimIndicator = %AimIndicator
@onready var _hp_label: Label = %HpLabel
@onready var _respawn_label: Label = %RespawnLabel
@onready var _delay_label: Label = %DelayLabel
@onready var _dash_button: TouchButton = %DashButton
@onready var _bookmark_button: TouchButton = %BookmarkButton
@onready var _aim_buttons: Array[AimButton] = [
	%WeaponButton1 as AimButton, %WeaponButton2 as AimButton, %BallButton as AimButton
]
@onready var _cancel_zone: Control = %CancelZone
@onready var _pick_screen: WeaponPickScreen = %PickScreen
@onready var _hurt_button: Button = %HurtButton
@onready var _swap_button: Button = %SwapButton
@onready var _map: GreyboxMap = %Map
@onready var _walls: WallsView = %Walls
@onready var _neutrals: NeutralsView = %Neutrals
@onready var _score_label: Label = %ScoreLabel
@onready var _info_label: Label = %InfoLabel
@onready var _banner: Label = %Banner
@onready var _again_button: Button = %AgainButton
@onready var _tricycle_button: Button = %TricycleButton


func _ready() -> void:
	if online:
		_setup_online()
	else:
		_setup_practice()
	for character: CharacterDef in rules.characters:
		_characters[character.id] = character
	for id: int in sim.players:
		_make_actor_view(sim.players[id])
	_fx.watch(sim)
	_walls.watch(sim)
	_neutrals.watch(sim)
	_map.set_own_side(own_side())
	_joystick.changed.connect(set_stick)
	_dash_button.pressed.connect(press_skill.bind(PlayerInput.BTN_DASH))
	_bookmark_button.pressed.connect(press_skill.bind(PlayerInput.BTN_BOOKMARK))
	for slot: int in _aim_buttons.size():
		_aim_buttons[slot].cancel_zone = _cancel_zone
		_aim_buttons[slot].aim_started.connect(aim_started.bind(slot))
		_aim_buttons[slot].aim_released.connect(aim_released.bind(slot))
	_hurt_button.pressed.connect(hurt_local.bind(DEBUG_DAMAGE))
	_tricycle_button.pressed.connect(sim.tricycle.call_now)
	_hurt_button.visible = not online
	_tricycle_button.visible = not online
	_again_button.pressed.connect(_on_again_pressed)
	sim.point_scored.connect(_on_point_scored)
	sim.set_won.connect(_on_set_won)
	sim.match_won.connect(_on_match_won)
	sim.sides_switched.connect(_on_sides_switched)
	sim.tricycle.warning_started.connect(_on_tricycle_warning)
	sim.ball.knocked_out.connect(_on_ball_knockout)
	sim.ball.caught.connect(_on_ball_caught)
	_pick_screen.confirmed.connect(_on_pick_confirmed)
	_pick_screen.swapped.connect(_on_swapped)
	_pick_screen.closed.connect(_set_controls_active.bind(true))
	_swap_button.pressed.connect(open_swap)
	sim.player_died.connect(_on_player_died)
	sim.player_respawned.connect(_on_player_respawned)
	_open_pick("Pick 2 weapons", [])
	_opening_pick = true
	if online:
		client.stage_changed.connect(_on_stage_changed)
		client.connection_changed.connect(_on_connection_changed)
		client.loaded()
		if client.stage == "play":
			_on_stage_changed("play")
	_sync_views(0.0)


func _setup_practice() -> void:
	sim = MatchSim.new(rules, layout, Time.get_ticks_usec())
	sim.add_player(local_id, local_team)
	sim.add_dummy(ENEMY_STAND_ID, 1, Vector2(rules.dummy_stand_x, rules.dummy_z), DummyBrain.standing())
	var patrol: DummyBrain = DummyBrain.patrolling(
		rules.dummy_patrol_x, rules.dummy_patrol_range, rules.dummy_patrol_speed_scale
	)
	sim.add_dummy(ENEMY_PATROL_ID, 1, Vector2(rules.dummy_patrol_x, rules.dummy_z), patrol)
	sim.add_dummy(ALLY_ID, local_team, Vector2(rules.dummy_ally_x, rules.dummy_ally_z), DummyBrain.standing())
	sim.assign_characters()
	var loadout: Array[StringName] = sim.random_loadout()
	sim.set_loadout(local_id, loadout[0], loadout[1])


func _setup_online() -> void:
	if client == null:
		client = Net.client
	sim = client.mirror
	local_id = client.player_id
	local_team = sim.players[local_id].team


## Online: the server ended the weapon pick (loadouts are final) and play starts.
func _on_stage_changed(stage: String) -> void:
	if stage != "play" or not _opening_pick:
		return
	_pick_screen.dismiss()
	_opening_pick = false
	_set_controls_active(true)


func _exit_tree() -> void:
	if online and client != null and client.in_match():
		client.leave_room()
		Session.reconnect_token = ""
		Session.save()


## Online: the connection dropped (phone locked, network switch...). Keep trying;
## the server holds our slot for 60 s and the token gets it back.
func _on_connection_changed(is_up: bool) -> void:
	if is_up:
		_reconnect_left = -1.0
		show_banner("Back online!")
		return
	show_banner("Connection lost\nReconnecting...")
	_reconnect_left = 0.0


func _try_reconnect(delta: float) -> void:
	if _reconnect_left < 0.0 or client.is_online() or client.is_connecting():
		return
	_reconnect_left -= delta
	if _reconnect_left <= 0.0:
		_reconnect_left = RECONNECT_INTERVAL
		var url: String = Session.reconnect_url if not Session.reconnect_url.is_empty() else Settings.server_url
		client.connect_to(url)


func _process(delta: float) -> void:
	advance(delta)


func set_stick(value: Vector2) -> void:
	_stick = value


## A skill button was pressed; it is sent with the next sim tick.
func press_skill(button_bit: int) -> void:
	_pending_buttons |= button_bit


## A weapon button started aiming (screen aim is read from the button while held).
func aim_started(slot: int) -> void:
	_touch_held[slot] = true
	_release_pending[slot] = false


## A weapon button was let go with a screen-space `aim` (zero = auto-aim).
func aim_released(aim: Vector2, cancelled: bool, slot: int) -> void:
	_touch_held[slot] = false
	_release_pending[slot] = true
	_release_aim[slot] = _screen_to_world(aim)
	_release_cancel[slot] = cancelled


func hurt_local(amount: int) -> void:
	sim.damage(local_id, amount)
	_sync_views(0.0)


## The base side the local team defends this set (+Z = own/bottom at the start).
func own_side() -> int:
	return sim.side_for_team(local_team)


## The camera and stick are turned around when the local team defends the -Z base.
func _flip() -> bool:
	return own_side() == MapLayout.SIDE_ENEMY


func show_banner(text: String) -> void:
	_banner.text = text
	_banner.visible = true
	_banner_left = BANNER_TIME


func banner_text() -> String:
	return _banner.text if _banner.visible else ""


## True while the weapon pick is open, or (online) while waiting for the server
## to start play after our pick.
func is_picking() -> bool:
	return _pick_screen.is_open() or _opening_pick


## Ends the open pick now (auto-fills empty slots), e.g. for tests or on respawn.
func finish_pick() -> void:
	_pick_screen.force_finish()


## Runs as many fixed sim ticks as `delta` allows, then updates the visuals.
func advance(delta: float) -> void:
	_pick_screen.tick(delta)
	if online:
		client.interpolate()
		_try_reconnect(delta)
	if _opening_pick:
		_sync_views(delta)
		return
	_accumulator += delta
	var dt: float = rules.tick_dt()
	var steps: int = 0
	while _accumulator >= dt and steps < MAX_STEPS_PER_FRAME:
		_step_once(dt)
		_accumulator -= dt
		steps += 1
	if steps == MAX_STEPS_PER_FRAME:
		_accumulator = 0.0
	_sync_views(delta)


func _step_once(dt: float) -> void:
	var flip: bool = _flip()
	var stick: Vector2 = LocalInput.combine(_stick, LocalInput.keyboard_vector())
	var world_move: Vector2 = LocalInput.to_world(stick, flip)
	var buttons: int = _pending_buttons | LocalInput.keyboard_buttons()
	_pending_buttons = 0
	var aim: Vector2 = Vector2.ZERO
	var cancel: bool = false
	for slot: int in AIM_BITS.size():
		var bit: int = AIM_BITS[slot]
		var key: bool = LocalInput.weapon_key_held(slot) and not _touch_held[slot] and not _release_pending[slot]
		if key:
			if not _key_held[slot]:
				_key_cancel[slot] = false
			_key_held[slot] = true
			_key_cancel[slot] = _key_cancel[slot] or LocalInput.cancel_held()
			_key_aim[slot] = _mouse_aim(slot)
			buttons |= bit
		elif _key_held[slot]:
			_key_held[slot] = false
			aim = _key_aim[slot]
			cancel = _key_cancel[slot]
		elif _touch_held[slot]:
			buttons |= bit
			_sent_held[slot] = true
		elif _release_pending[slot]:
			if not _sent_held[slot]:
				# a tap shorter than one tick: send one held tick, then the release
				buttons |= bit
				_sent_held[slot] = true
			else:
				aim = _release_aim[slot]
				cancel = _release_cancel[slot]
				_release_pending[slot] = false
				_sent_held[slot] = false
	if cancel:
		buttons |= PlayerInput.BTN_AIM_CANCEL
	if online:
		_input_tick += 1
		client.send_input(PlayerInput.create(world_move, aim, buttons, _input_tick), dt)
		return
	sim.set_input(local_id, PlayerInput.create(world_move, aim, buttons, sim.tick))
	sim.step(dt)


func _screen_to_world(screen_aim: Vector2) -> Vector2:
	return LocalInput.to_world(screen_aim, _flip())


## Mouse position on the ground, relative to the player, scaled by the weapon range.
func _mouse_aim(slot: int) -> Vector2:
	var player: PlayerState = sim.players[local_id]
	var viewport: Viewport = get_viewport()
	if viewport == null or (slot != BALL_SLOT and slot >= player.weapons.size()):
		return Vector2.ZERO
	var mouse: Vector2 = viewport.get_mouse_position()
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(_camera.project_ray_origin(mouse), _camera.project_ray_normal(mouse))
	if hit == null:
		return Vector2.ZERO
	var point: Vector3 = hit as Vector3
	var offset: Vector2 = Vector2(point.x, point.z) - player.position
	var reach: float = rules.ball_range
	if slot != BALL_SLOT:
		var def: WeaponDef = sim.weapon_defs[player.weapons[slot]]
		reach = def.max_range if def.max_range > 0.0 else 1.0
	return (offset / reach).limit_length(1.0)


func _open_pick(heading: String, current: Array[StringName]) -> void:
	var ids: Array[StringName] = []
	for def: WeaponDef in rules.weapons:
		ids.append(def.id)
	_pick_screen.open(WeaponPick.new(ids, rules.weapon_pick_time, current), rules.weapons, heading, sim.rng)
	_set_controls_active(false)


func _on_pick_confirmed(picks: Array[StringName]) -> void:
	sim.set_loadout(local_id, picks[0], picks[1])
	if online:
		# the server starts play for everyone once all have picked (or time is up)
		client.pick_weapons(picks[0], picks[1])
		if client.stage != "play":
			show_banner("Waiting for the others...")
			return
	_opening_pick = false
	_set_controls_active(true)
	_sync_views(0.0)


## The touch controls read raw touches, so they are switched off under the pick
## screen; otherwise tapping a weapon card could also press the button beneath it.
func _set_controls_active(active: bool) -> void:
	var controls: Array[Control] = [_joystick, _dash_button, _bookmark_button]
	controls.append_array(_aim_buttons)
	for control: Control in controls:
		control.set_process_input(active)
	if not active:
		_stick = Vector2.ZERO
		_pending_buttons = 0
		for slot: int in _aim_buttons.size():
			_touch_held[slot] = false
			_release_pending[slot] = false
			_sent_held[slot] = false


func controls_active() -> bool:
	return _dash_button.is_processing_input()


## Opens the respawn swap screen (only while dead; reopen as often as you like).
func open_swap() -> void:
	if sim.players[local_id].alive:
		return
	_open_swap_screen()


func _open_swap_screen() -> void:
	var player: PlayerState = sim.players[local_id]
	var ids: Array[StringName] = []
	for def: WeaponDef in rules.weapons:
		ids.append(def.id)
	_pick_screen.open_swap(WeaponPick.new(ids, 0.0, player.weapons), rules.weapons, "Swap weapons")
	_set_controls_active(false)


func _on_swapped(picks: Array[StringName]) -> void:
	if online:
		client.swap_weapons(picks[0], picks[1])
		sim.players[local_id].weapons.assign(picks)
	else:
		sim.swap_loadout(local_id, picks[0], picks[1])
	_sync_views(0.0)


func _on_player_died(id: int) -> void:
	if id == local_id:
		_open_swap_screen()


func _on_player_respawned(id: int) -> void:
	if id == local_id and _pick_screen.visible:
		_pick_screen.force_finish()


func _sync_views(delta: float) -> void:
	for id: int in sim.players:
		_sync_actor(sim.players[id])
	var player: PlayerState = sim.players[local_id]
	_sync_hud(player)
	_sync_aim(player)
	_fx.sync(sim, delta)
	_neutrals.sync(delta)
	_sync_score(delta)
	_camera.follow(player.position, _flip())


func _sync_actor(state: PlayerState) -> void:
	var view: MeshInstance3D = _views[state.id]
	var lift: float = AIRBORNE_LIFT if state.effects.has(StatusEffects.Type.AIRBORNE) else 0.0
	view.position = Vector3(state.position.x, PLAYER_HEIGHT / 2.0 + lift, state.position.y)
	view.visible = state.alive
	var polymorphed: bool = state.effects.has(StatusEffects.Type.POLYMORPH)
	view.scale = POLYMORPH_SCALE if polymorphed else Vector3.ONE
	var color: Color = _base_colors[state.id]
	if state.death_delay:
		color = DELAY_COLOR
	elif polymorphed:
		color = POLYMORPH_COLOR
	_materials[state.id].albedo_color = color
	var tag: Label3D = _tags[state.id]
	var lines: PackedStringArray = PackedStringArray([_character_name(state)])
	if state.id != local_id:
		lines.append("GRAY %d" % ceili(state.gray_hp) if state.death_delay else "HP %d" % state.hp)
	var effects: PackedStringArray = state.effects.active_names()
	if not effects.is_empty():
		lines.append(" ".join(effects))
	tag.text = "\n".join(lines)


func _sync_hud(player: PlayerState) -> void:
	if player.death_delay:
		_hp_label.text = "HP 0   GRAY %d" % ceili(player.gray_hp)
		_hp_label.add_theme_color_override("font_color", DELAY_COLOR)
	else:
		_hp_label.text = "HP %d / %d" % [player.hp, rules.player_max_hp]
		_hp_label.add_theme_color_override("font_color", HP_TEXT_COLOR)
	_delay_label.visible = player.death_delay
	_respawn_label.visible = not player.alive
	_respawn_label.text = "Respawning in %d" % ceili(player.respawn_time_left)
	_swap_button.visible = not player.alive and not _pick_screen.visible
	if not player.alive:
		_pick_screen.show_time(player.respawn_time_left)
	# Disabled while on cooldown too: no pressing or precasting until ready.
	_dash_button.set_locked(player.death_delay or player.dash_cooldown_left > 0.0)
	_bookmark_button.set_locked(player.death_delay or not player.bookmark_ready())
	_dash_button.set_cooldown(player.dash_cooldown_left, rules.dash_cooldown)
	_bookmark_button.set_cooldown(player.bookmark_cooldown_left, rules.bookmark_cooldown)
	var weapons_off: bool = not player.alive or player.death_delay or not player.effects.can_cast()
	_sync_ball_button(player)
	for slot: int in WEAPON_SLOTS:
		var button: AimButton = _aim_buttons[slot]
		if slot >= player.weapons.size():
			button.set_locked(true)
			continue
		var def: WeaponDef = sim.weapon_defs[player.weapons[slot]]
		if button.label_text != def.short_name or button.sub_text != def.kind_label():
			button.label_text = def.short_name
			button.sub_text = def.kind_label()
			button.sub_color = WeaponPickScreen.kind_color(def.kind)
			button.queue_redraw()
		button.set_locked(weapons_off or player.weapon_cooldowns[slot] > 0.0)
		button.set_cooldown(player.weapon_cooldowns[slot], def.cooldown)


## The ball button says what a press does now: throw it, blink to your throw,
## or try to catch an incoming ball.
func _sync_ball_button(player: PlayerState) -> void:
	var button: AimButton = _aim_buttons[BALL_SLOT]
	var text: String = "Catch"
	if sim.ball.is_holder(local_id):
		text = "Throw"
	elif sim.ball.state == RubberBall.State.FLYING and sim.ball.thrower_id == local_id and sim.ball.can_blink:
		text = "Blink"
	if button.label_text != text:
		button.label_text = text
		button.sub_text = "BALL"
		button.queue_redraw()
	button.set_locked(not player.alive or player.death_delay)


func _sync_aim(player: PlayerState) -> void:
	var any_aiming: bool = false
	for slot: int in _aim_buttons.size():
		if not player.alive:
			break
		var stick: Vector2
		var cancelled: bool
		if _touch_held[slot]:
			stick = _screen_to_world(_aim_buttons[slot].aim)
			cancelled = _aim_buttons[slot].over_cancel
		elif _key_held[slot]:
			stick = _key_aim[slot]
			cancelled = _key_cancel[slot]
		else:
			continue
		if slot == BALL_SLOT:
			if not sim.ball.is_holder(local_id):
				continue
			var direction: Vector2 = sim.resolved_ball_aim(player, stick)
			_aim_indicator.show_lines(AimIndicator.ball_outline(player.position, direction, rules.ball_range), cancelled)
			any_aiming = true
			break
		if slot >= player.weapons.size():
			continue
		if player.aim_hold[slot] < 0.0 and not sim.weapon_ready(player, slot):
			continue
		var def: WeaponDef = sim.weapon_defs[player.weapons[slot]]
		var aim: Vector2 = sim.resolved_aim(player, slot, stick)
		_aim_indicator.show_aim(sim, player, def, aim, sim.resolved_target(player, slot), cancelled)
		any_aiming = true
		break
	if not any_aiming:
		_aim_indicator.clear()
	_cancel_zone.visible = _touch_held.has(true)


## Top bar: team-relative score, set, ball and tricycle timers; banners fade.
func _sync_score(delta: float) -> void:
	var mine: int = local_team
	var theirs: int = 1 - local_team
	var score: MatchScore = sim.score
	_score_label.text = "YOU %d - %d THEM   Set %d (%d-%d)" % [
		score.points[mine], score.points[theirs], score.set_number, score.sets[mine], score.sets[theirs]
	]
	var info: PackedStringArray = PackedStringArray()
	if sim.ball.state == RubberBall.State.NONE:
		info.append("Ball in %d" % ceili(sim.ball.spawn_timer))
	else:
		info.append("Ball is out!")
	var arrival: float = sim.tricycle.time_to_arrival(rules)
	if sim.tricycle.phase == Tricycle.Phase.CROSSING:
		info.append("Tricycle crossing!")
	else:
		info.append("Tricycle in %d:%02d" % [floori(arrival) / 60, floori(arrival) % 60])
	if sim.phase == MatchSim.Phase.POINT_FREEZE:
		info.append("Next point in %d" % ceili(sim.freeze_left))
	_info_label.text = "   ".join(info)
	_again_button.visible = sim.phase == MatchSim.Phase.MATCH_OVER
	if sim.phase != MatchSim.Phase.MATCH_OVER and _banner_left > 0.0:
		_banner_left -= delta
		if _banner_left <= 0.0:
			_banner.visible = false


func _on_point_scored(team: int, _by_id: int) -> void:
	show_banner("POINT - YOU!" if team == local_team else "POINT - THEM")


func _on_set_won(team: int) -> void:
	show_banner("SET TO YOU!\nSwitching bases" if team == local_team else "SET TO THEM\nSwitching bases")


func _on_match_won(team: int) -> void:
	show_banner("YOU WIN THE MATCH!" if team == local_team else "THEY WIN THE MATCH")


func _on_sides_switched() -> void:
	_map.set_own_side(own_side())


func _on_tricycle_warning(_direction: int) -> void:
	show_banner("BEEP BEEP! Tricycle!")


func _on_ball_knockout(id: int) -> void:
	if id == local_id:
		show_banner("Knocked out!")


func _on_ball_caught(id: int) -> void:
	if id == local_id:
		show_banner("Nice catch!")


func _on_again_pressed() -> void:
	if online:
		client.leave_room()
		get_tree().change_scene_to_file("res://scenes/ui/lobby.tscn")
		return
	get_tree().reload_current_scene()


func _character_name(state: PlayerState) -> String:
	var character: CharacterDef = _characters.get(state.character_id) as CharacterDef
	var name_text: String = character.display_name if character != null else "?"
	return "You (%s)" % name_text if state.id == local_id else name_text


func _make_actor_view(state: PlayerState) -> void:
	var team_color: Color = GreyboxMap.ENEMY_COLOR
	if state.id == local_id:
		team_color = GreyboxMap.OWN_COLOR
	elif state.team == local_team:
		team_color = ALLY_COLOR
	var character: CharacterDef = _characters.get(state.character_id) as CharacterDef
	var color: Color = character.tint if character != null else team_color
	var mesh: CapsuleMesh = CapsuleMesh.new()
	mesh.radius = rules.player_radius
	mesh.height = PLAYER_HEIGHT
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material = material
	var view: MeshInstance3D = MeshInstance3D.new()
	view.mesh = mesh
	_actors.add_child(view)
	_views[state.id] = view
	_materials[state.id] = material
	_base_colors[state.id] = color
	var ring_mesh: TorusMesh = TorusMesh.new()
	ring_mesh.inner_radius = rules.player_radius
	ring_mesh.outer_radius = rules.player_radius + RING_THICKNESS * 2.0
	var ring_material: StandardMaterial3D = StandardMaterial3D.new()
	ring_material.albedo_color = team_color
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mesh.material = ring_material
	var ring: MeshInstance3D = MeshInstance3D.new()
	ring.name = "TeamRing"
	ring.mesh = ring_mesh
	ring.position = Vector3(0.0, -PLAYER_HEIGHT / 2.0 + RING_THICKNESS, 0.0)
	view.add_child(ring)
	var tag: Label3D = Label3D.new()
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.pixel_size = TAG_PIXEL_SIZE
	tag.font_size = TAG_FONT_SIZE
	tag.outline_size = 8
	tag.modulate = team_color.lightened(0.5)
	tag.position = Vector3(0.0, TAG_HEIGHT - PLAYER_HEIGHT / 2.0, 0.0)
	view.add_child(tag)
	_tags[state.id] = tag
