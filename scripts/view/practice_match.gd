class_name PracticeMatch
extends Node3D
## The match screen. Offline practice runs a local MatchSim with training dummies;
## online (`online = true`, scenes/match/online.tscn) it draws the GameClient's
## mirror of the server's match and sends inputs instead of stepping a sim.
## It wires the pieces together: MatchInput (devices -> PlayerInput), MatchHud
## (all HUD controls), the 3D views, audio and the camera. Reads sim state only;
## all rules live in scripts/sim/.

const LOCAL_ID: int = 1
const LOCAL_TEAM: int = 0
const ENEMY_STAND_ID: int = 2
const ENEMY_PATROL_ID: int = 3
const ALLY_ID: int = 4
const MAX_STEPS_PER_FRAME: int = 8
const AIRBORNE_LIFT: float = 1.0
const WEAPON_SLOTS: int = 2
const BALL_SLOT: int = 2
const RECONNECT_INTERVAL: float = 2.0
## Practice-only debug button to test the death delay without an enemy that fights back.
const DEBUG_DAMAGE: int = 30
const TITLE_SCENE: String = "res://scenes/ui/title_screen.tscn"

@export var rules: GameRules
@export var layout: MapLayout
## Online match: driven by Net.client (set `client` before adding to the tree to
## use another one, e.g. in tests).
@export var online: bool = false

var sim: MatchSim
var client: GameClient
var local_id: int = LOCAL_ID
var local_team: int = LOCAL_TEAM
var input: MatchInput = MatchInput.new()

var _accumulator: float = 0.0
var _views: Dictionary[int, KidModel] = {}
var _pins: Dictionary[int, MeshInstance3D] = {}
var _last_positions: Dictionary[int, Vector2] = {}
var _characters: Dictionary[StringName, CharacterDef] = {}
## The opening pick pauses the match; the respawn swap does not.
var _opening_pick: bool = false
## Online: our own input counter (the server acks it for reconciliation).
var _input_tick: int = 0
## Online: seconds until the next reconnect attempt after the connection dropped.
var _reconnect_left: float = -1.0

@onready var hud: MatchHud = %Hud
@onready var _camera: FollowCamera = %FollowCamera
@onready var _actors: Node3D = %Actors
@onready var _fx: WeaponFxView = %WeaponFx
@onready var _aim_indicator: AimIndicator = %AimIndicator
@onready var _pick_screen: WeaponPickScreen = %PickScreen
@onready var _map: StreetMap = %Map
@onready var _walls: WallsView = %Walls
@onready var _neutrals: NeutralsView = %Neutrals
@onready var _audio: MatchAudio = %Audio


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
	_audio.watch(sim, local_team, local_id)
	_views[local_id].footstep.connect(func() -> void: _audio.play(&"footstep", 0.15))
	_walls.watch(sim)
	_neutrals.watch(sim)
	_map.set_own_side(own_side())
	_map.show_back_button(false)
	_setup_hud()
	_connect_hud()
	_connect_sim()
	_pick_screen.confirmed.connect(_on_pick_confirmed)
	_pick_screen.swapped.connect(_on_swapped)
	_pick_screen.closed.connect(_set_controls_active.bind(true))
	_open_pick("CHOOSE 2 WEAPONS", [])
	_opening_pick = true
	if online:
		client.stage_changed.connect(_on_stage_changed)
		client.connection_changed.connect(_on_connection_changed)
		client.loaded()
		if client.stage == "play":
			_on_stage_changed("play")
	_sync_views(0.0)


func _process(delta: float) -> void:
	advance(delta)


func _exit_tree() -> void:
	if online and client != null and client.in_match():
		client.leave_room()
		Session.reconnect_token = ""
		Session.save()


# ---- public API (used by tests and the HUD) ---------------------------------------

func set_stick(value: Vector2) -> void:
	input.set_stick(value)


## A skill button was pressed; it is sent with the next sim tick.
func press_skill(button_bit: int) -> void:
	input.press_skill(button_bit)


## A weapon (or guava) button started aiming.
func aim_started(slot: int) -> void:
	input.aim_started(slot)


## A weapon button was let go with a screen-space `aim` (zero = auto-aim).
func aim_released(aim: Vector2, cancelled: bool, slot: int) -> void:
	input.aim_released(_screen_to_world(aim), cancelled, slot)


func hurt_local(amount: int) -> void:
	sim.damage(local_id, amount)
	_sync_views(0.0)


## The base side the local team defends this set (+Z = own/bottom at the start).
func own_side() -> int:
	return sim.side_for_team(local_team)


func show_banner(text: String) -> void:
	hud.show_banner(text)


func banner_text() -> String:
	return hud.banner_text()


func overhead() -> OverheadHud:
	return hud.overhead


func scoreboard() -> Scoreboard:
	return hud.scoreboard


func controls_active() -> bool:
	return hud.controls_active()


## True while the weapon pick is open, or (online) while waiting for the server
## to start play after our pick.
func is_picking() -> bool:
	return _pick_screen.is_open() or _opening_pick


## Ends the open pick now (auto-fills empty slots), e.g. for tests or on respawn.
func finish_pick() -> void:
	_pick_screen.force_finish()


## Opens the respawn swap screen (only while dead; reopen as often as you like).
func open_swap() -> void:
	if sim.players[local_id].alive:
		return
	_open_swap_screen()


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


# ---- setup ---------------------------------------------------------------------------

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


## Overhead display and minimap get the sim; the top HUD clears the notch.
func _setup_hud() -> void:
	input.camera_yaw = _camera.rules.yaw_offset_degrees
	Cinematic.add_film_finish(self)
	Cinematic.add_dust(_camera)
	hud.overhead.setup(sim, _camera, local_id, local_team)
	hud.minimap.setup(sim, local_id, local_team)
	hud.set_top_inset(_safe_top_inset())


func _connect_hud() -> void:
	hud.joystick.changed.connect(set_stick)
	hud.bookmark_button.pressed.connect(press_skill.bind(PlayerInput.BTN_BOOKMARK))
	for slot: int in hud.aim_buttons.size():
		hud.aim_buttons[slot].aim_started.connect(aim_started.bind(slot))
		hud.aim_buttons[slot].aim_released.connect(aim_released.bind(slot))
	hud.hurt_button.pressed.connect(hurt_local.bind(DEBUG_DAMAGE))
	hud.tricycle_button.pressed.connect(sim.tricycle.call_now)
	hud.hurt_button.visible = not online
	hud.tricycle_button.visible = not online
	hud.again_pressed.connect(_on_again_pressed)
	hud.swap_pressed.connect(open_swap)
	hud.exit_pressed.connect(_on_exit_pressed)


func _connect_sim() -> void:
	sim.player_damaged.connect(func(id: int, amount: int) -> void: if id == local_id: _camera.shake(minf(0.1 + amount * 0.01, 0.4)))
	sim.wall_destroyed.connect(func(_index: int) -> void: _camera.shake(0.18))
	sim.weapon_cast.connect(func(id: int, _weapon: StringName) -> void: _views[id].play_cast())
	sim.player_damaged.connect(func(id: int, _amount: int) -> void: _views[id].play_hit())
	sim.point_scored.connect(_on_point_scored)
	sim.set_won.connect(_on_set_won)
	sim.match_won.connect(_on_match_won)
	sim.sides_switched.connect(_on_sides_switched)
	sim.tricycle.warning_started.connect(_on_tricycle_warning)
	sim.ball.knocked_out.connect(_on_ball_knockout)
	sim.ball.caught.connect(_on_ball_caught)
	sim.player_died.connect(_on_player_died)
	sim.player_respawned.connect(_on_player_respawned)


# ---- one tick of input ---------------------------------------------------------------

func _step_once(dt: float) -> void:
	if online:
		_input_tick += 1
		client.send_input(input.build(_flip(), _mouse_aim, _input_tick), dt)
		return
	sim.set_input(local_id, input.build(_flip(), _mouse_aim, sim.tick))
	sim.step(dt)


## The camera and stick are turned around when the local team defends the -Z base.
func _flip() -> bool:
	return own_side() == MapLayout.SIDE_ENEMY


func _screen_to_world(screen_aim: Vector2) -> Vector2:
	return LocalInput.to_world(screen_aim, _flip(), input.camera_yaw)


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


# ---- weapon pick and swap ------------------------------------------------------------

func _open_pick(heading: String, current: Array[StringName]) -> void:
	_pick_screen.open(WeaponPick.new(_weapon_ids(), rules.weapon_pick_time, current), rules.weapons, heading, sim.rng)
	_set_controls_active(false)


func _open_swap_screen() -> void:
	var player: PlayerState = sim.players[local_id]
	_pick_screen.open_swap(WeaponPick.new(_weapon_ids(), 0.0, player.weapons), rules.weapons, "CHANGE WEAPONS")
	_set_controls_active(false)


func _weapon_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for def: WeaponDef in rules.weapons:
		ids.append(def.id)
	return ids


func _on_pick_confirmed(picks: Array[StringName]) -> void:
	_audio.start_music()
	sim.set_loadout(local_id, picks[0], picks[1])
	if online:
		# the server starts play for everyone once all have picked (or time is up)
		client.pick_weapons(picks[0], picks[1])
		if client.stage != "play":
			show_banner("Waiting for the other players...")
			return
	_opening_pick = false
	_set_controls_active(true)
	_sync_views(0.0)


func _on_swapped(picks: Array[StringName]) -> void:
	if online:
		client.swap_weapons(picks[0], picks[1])
		sim.players[local_id].weapons.assign(picks)
	else:
		sim.swap_loadout(local_id, picks[0], picks[1])
	_sync_views(0.0)


## The touch controls read raw touches, so they are switched off under the pick
## screen; otherwise tapping a weapon card could also press the button beneath it.
func _set_controls_active(active: bool) -> void:
	hud.set_controls_active(active)
	if not active:
		input.clear()


## Online: the server ended the weapon pick (loadouts are final) and play starts.
func _on_stage_changed(stage: String) -> void:
	if stage != "play" or not _opening_pick:
		return
	_pick_screen.dismiss()
	_opening_pick = false
	_set_controls_active(true)


# ---- online connection ---------------------------------------------------------------

## The connection dropped (phone locked, network switch...). Keep trying; the
## server holds our slot for 60 s and the token gets it back.
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


# ---- per-frame views -----------------------------------------------------------------

func _sync_views(delta: float) -> void:
	for id: int in sim.players:
		_sync_actor(sim.players[id], delta)
	var player: PlayerState = sim.players[local_id]
	hud.sync_player(sim, rules, player, local_id, _pick_screen.visible)
	if not player.alive:
		_pick_screen.show_time(player.respawn_time_left)
	_sync_aim(player)
	_fx.sync(sim, delta)
	_neutrals.sync(delta)
	hud.overhead.tick(delta)
	hud.minimap.queue_redraw()
	hud.sync_score(sim, rules, local_team, delta)
	_camera.follow(player.position, _flip(), delta)


func _sync_actor(state: PlayerState, delta: float) -> void:
	var view: KidModel = _views[state.id]
	var lift: float = AIRBORNE_LIFT if state.effects.has(StatusEffects.Type.AIRBORNE) else 0.0
	view.position = Vector3(state.position.x, lift, state.position.y)
	view.visible = state.alive
	var last: Vector2 = _last_positions.get(state.id, state.position) as Vector2
	var speed: float = last.distance_to(state.position) / delta if delta > 0.0 else 0.0
	_last_positions[state.id] = state.position
	view.face(state.facing)
	view.animate(delta, minf(speed, 20.0), state)
	var pin: MeshInstance3D = _pins[state.id]
	pin.visible = state.alive and state.mark_active
	pin.position = Vector3(state.mark_position.x, 0.0, state.mark_position.y)


## Aim preview for whichever slot is held (touch or keyboard).
func _sync_aim(player: PlayerState) -> void:
	var any_aiming: bool = false
	for slot: int in MatchInput.SLOTS:
		if not player.alive:
			break
		var stick: Vector2
		var cancelled: bool
		if input.touch_held[slot]:
			stick = _screen_to_world(hud.aim_buttons[slot].aim)
			cancelled = hud.aim_buttons[slot].over_cancel
		elif input.key_held[slot]:
			stick = input.key_aim[slot]
			cancelled = input.key_cancel[slot]
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
	hud.cancel_zone.visible = input.any_touch_held()


# ---- sim events -> banners -----------------------------------------------------------

func _on_player_died(id: int) -> void:
	if id == local_id:
		_open_swap_screen()


func _on_player_respawned(id: int) -> void:
	if id == local_id and _pick_screen.visible:
		_pick_screen.force_finish()


func _on_point_scored(team: int, _by_id: int) -> void:
	show_banner("BASE CAPTURED!" if team == local_team else "YOUR BASE WAS CAPTURED!")


func _on_set_won(team: int) -> void:
	show_banner("SET WON!\nSwitching sides" if team == local_team else "SET LOST\nSwitching sides")


func _on_match_won(team: int) -> void:
	show_banner("VICTORY!" if team == local_team else "DEFEAT")


func _on_sides_switched() -> void:
	_map.set_own_side(own_side())


func _on_tricycle_warning(_direction: int) -> void:
	show_banner("TRICYCLE INCOMING!\nGet off the road!")


func _on_ball_knockout(id: int) -> void:
	if id == local_id:
		show_banner("KNOCKED OUT!")


func _on_ball_caught(id: int) -> void:
	if id == local_id:
		show_banner("NICE CATCH!")


func _on_again_pressed() -> void:
	if online:
		client.leave_room()
		get_tree().change_scene_to_file("res://scenes/ui/lobby.tscn")
		return
	get_tree().reload_current_scene()


# ---- actors --------------------------------------------------------------------------

## The top safe-area inset (notch, status bar) in UI pixels.
func _safe_top_inset() -> float:
	var window: Vector2i = DisplayServer.window_get_size()
	if window.y <= 0:
		return 0.0
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var screen_inset: float = maxf(0.0, float(safe.position.y - DisplayServer.window_get_position().y))
	return screen_inset * get_viewport().get_visible_rect().size.y / float(window.y)


func _make_actor_view(state: PlayerState) -> void:
	var team_color: Color = Palette.TEAM_ENEMY
	if state.id == local_id:
		team_color = Palette.TEAM_OWN
	elif state.team == local_team:
		team_color = Palette.TEAM_ALLY
	var character: CharacterDef = _characters.get(state.character_id) as CharacterDef
	if character == null:
		character = rules.characters[0]
	var view: KidModel = KidModel.new()
	view.setup(character, team_color, rules.player_radius)
	_actors.add_child(view)
	_views[state.id] = view
	# the pin skill's pin, stuck where the kid used it
	var pin: MeshInstance3D = MeshInstance3D.new()
	pin.name = "Pin%d" % state.id
	pin.mesh = Props.push_pin()
	pin.visible = false
	LowPoly.add_outline(pin, 0.02)
	_actors.get_parent().add_child(pin)
	_pins[state.id] = pin


## Settings menu > Exit match: online, give the room slot back first.
func _on_exit_pressed() -> void:
	if online:
		client.leave_room()
	get_tree().change_scene_to_file(TITLE_SCENE)
