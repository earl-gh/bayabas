class_name PracticeMatch
extends Node3D
## Offline practice match: runs a local MatchSim, draws it, and feeds it input.
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
const WEAPON_BITS: Array[int] = [PlayerInput.BTN_WEAPON_1, PlayerInput.BTN_WEAPON_2]
## Practice-only debug button to test the death delay without an enemy that fights back.
const DEBUG_DAMAGE: int = 30
const ALLY_COLOR: Color = Color(0.5, 0.75, 1.0)
const DELAY_COLOR: Color = Color(0.62, 0.62, 0.66)
const POLYMORPH_COLOR: Color = Color(0.75, 0.75, 0.8)
const HP_TEXT_COLOR: Color = Color(1.0, 1.0, 1.0)

@export var rules: GameRules
@export var layout: MapLayout

var sim: MatchSim

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

# Per weapon slot: touch aiming, a release waiting to be sent, and Q/E aiming.
var _touch_held: Array[bool] = [false, false]
var _sent_held: Array[bool] = [false, false]
var _release_pending: Array[bool] = [false, false]
var _release_aim: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var _release_cancel: Array[bool] = [false, false]
var _key_held: Array[bool] = [false, false]
var _key_aim: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var _key_cancel: Array[bool] = [false, false]

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
@onready var _weapon_buttons: Array[AimButton] = [%WeaponButton1 as AimButton, %WeaponButton2 as AimButton]
@onready var _cancel_zone: Control = %CancelZone
@onready var _pick_screen: WeaponPickScreen = %PickScreen
@onready var _hurt_button: Button = %HurtButton
@onready var _swap_button: Button = %SwapButton


func _ready() -> void:
	sim = MatchSim.new(rules, layout, Time.get_ticks_usec())
	sim.add_player(LOCAL_ID, LOCAL_TEAM)
	sim.add_dummy(ENEMY_STAND_ID, 1, Vector2(rules.dummy_stand_x, rules.dummy_z), DummyBrain.standing())
	var patrol: DummyBrain = DummyBrain.patrolling(
		rules.dummy_patrol_x, rules.dummy_patrol_range, rules.dummy_patrol_speed_scale
	)
	sim.add_dummy(ENEMY_PATROL_ID, 1, Vector2(rules.dummy_patrol_x, rules.dummy_z), patrol)
	sim.add_dummy(ALLY_ID, LOCAL_TEAM, Vector2(rules.dummy_ally_x, rules.dummy_ally_z), DummyBrain.standing())
	sim.assign_characters()
	var loadout: Array[StringName] = sim.random_loadout()
	sim.set_loadout(LOCAL_ID, loadout[0], loadout[1])
	for character: CharacterDef in rules.characters:
		_characters[character.id] = character
	for id: int in sim.players:
		_make_actor_view(sim.players[id])
	_fx.watch(sim)
	_joystick.changed.connect(set_stick)
	_dash_button.pressed.connect(press_skill.bind(PlayerInput.BTN_DASH))
	_bookmark_button.pressed.connect(press_skill.bind(PlayerInput.BTN_BOOKMARK))
	for slot: int in _weapon_buttons.size():
		_weapon_buttons[slot].cancel_zone = _cancel_zone
		_weapon_buttons[slot].aim_started.connect(aim_started.bind(slot))
		_weapon_buttons[slot].aim_released.connect(aim_released.bind(slot))
	_hurt_button.pressed.connect(hurt_local.bind(DEBUG_DAMAGE))
	_pick_screen.confirmed.connect(_on_pick_confirmed)
	_pick_screen.swapped.connect(_on_swapped)
	_pick_screen.closed.connect(_set_controls_active.bind(true))
	_swap_button.pressed.connect(open_swap)
	sim.player_died.connect(_on_player_died)
	sim.player_respawned.connect(_on_player_respawned)
	_open_pick("Pick 2 weapons", [])
	_opening_pick = true
	_sync_views(0.0)


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
	sim.damage(LOCAL_ID, amount)
	_sync_views(0.0)


func is_picking() -> bool:
	return _pick_screen.is_open()


## Ends the open pick now (auto-fills empty slots), e.g. for tests or on respawn.
func finish_pick() -> void:
	_pick_screen.force_finish()


## Runs as many fixed sim ticks as `delta` allows, then updates the visuals.
func advance(delta: float) -> void:
	_pick_screen.tick(delta)
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
	var flip: bool = sim.players[LOCAL_ID].team != 0
	var stick: Vector2 = LocalInput.combine(_stick, LocalInput.keyboard_vector())
	var world_move: Vector2 = LocalInput.to_world(stick, flip)
	var buttons: int = _pending_buttons | LocalInput.keyboard_buttons()
	_pending_buttons = 0
	var aim: Vector2 = Vector2.ZERO
	var cancel: bool = false
	for slot: int in WEAPON_BITS.size():
		var bit: int = WEAPON_BITS[slot]
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
	sim.set_input(LOCAL_ID, PlayerInput.create(world_move, aim, buttons, sim.tick))
	sim.step(dt)


func _screen_to_world(screen_aim: Vector2) -> Vector2:
	return LocalInput.to_world(screen_aim, sim.players[LOCAL_ID].team != 0)


## Mouse position on the ground, relative to the player, scaled by the weapon range.
func _mouse_aim(slot: int) -> Vector2:
	var player: PlayerState = sim.players[LOCAL_ID]
	var viewport: Viewport = get_viewport()
	if viewport == null or slot >= player.weapons.size():
		return Vector2.ZERO
	var mouse: Vector2 = viewport.get_mouse_position()
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(_camera.project_ray_origin(mouse), _camera.project_ray_normal(mouse))
	if hit == null:
		return Vector2.ZERO
	var point: Vector3 = hit as Vector3
	var offset: Vector2 = Vector2(point.x, point.z) - player.position
	var def: WeaponDef = sim.weapon_defs[player.weapons[slot]]
	var reach: float = def.max_range if def.max_range > 0.0 else 1.0
	return (offset / reach).limit_length(1.0)


func _open_pick(heading: String, current: Array[StringName]) -> void:
	var ids: Array[StringName] = []
	for def: WeaponDef in rules.weapons:
		ids.append(def.id)
	_pick_screen.open(WeaponPick.new(ids, rules.weapon_pick_time, current), rules.weapons, heading, sim.rng)
	_set_controls_active(false)


func _on_pick_confirmed(picks: Array[StringName]) -> void:
	sim.set_loadout(LOCAL_ID, picks[0], picks[1])
	_opening_pick = false
	_set_controls_active(true)
	_sync_views(0.0)


## The touch controls read raw touches, so they are switched off under the pick
## screen; otherwise tapping a weapon card could also press the button beneath it.
func _set_controls_active(active: bool) -> void:
	var controls: Array[Control] = [_joystick, _dash_button, _bookmark_button]
	controls.append_array(_weapon_buttons)
	for control: Control in controls:
		control.set_process_input(active)
	if not active:
		_stick = Vector2.ZERO
		_pending_buttons = 0
		for slot: int in _weapon_buttons.size():
			_touch_held[slot] = false
			_release_pending[slot] = false
			_sent_held[slot] = false


func controls_active() -> bool:
	return _dash_button.is_processing_input()


## Opens the respawn swap screen (only while dead; reopen as often as you like).
func open_swap() -> void:
	var player: PlayerState = sim.players[LOCAL_ID]
	if player.alive:
		return
	var ids: Array[StringName] = []
	for def: WeaponDef in rules.weapons:
		ids.append(def.id)
	_pick_screen.open_swap(WeaponPick.new(ids, 0.0, player.weapons), rules.weapons, "Swap weapons")
	_set_controls_active(false)


func _on_swapped(picks: Array[StringName]) -> void:
	sim.swap_loadout(LOCAL_ID, picks[0], picks[1])
	_sync_views(0.0)


func _on_player_died(id: int) -> void:
	if id == LOCAL_ID:
		open_swap()


func _on_player_respawned(id: int) -> void:
	if id == LOCAL_ID and _pick_screen.visible:
		_pick_screen.force_finish()


func _sync_views(delta: float) -> void:
	for id: int in sim.players:
		_sync_actor(sim.players[id])
	var player: PlayerState = sim.players[LOCAL_ID]
	_sync_hud(player)
	_sync_aim(player)
	_fx.sync(sim, delta)
	_camera.follow(player.position, player.team != 0)


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
	if state.id != LOCAL_ID:
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
	for slot: int in _weapon_buttons.size():
		var button: AimButton = _weapon_buttons[slot]
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


func _sync_aim(player: PlayerState) -> void:
	var any_aiming: bool = false
	for slot: int in _weapon_buttons.size():
		if slot >= player.weapons.size() or not player.alive:
			continue
		var stick: Vector2
		var cancelled: bool
		if _touch_held[slot]:
			stick = _screen_to_world(_weapon_buttons[slot].aim)
			cancelled = _weapon_buttons[slot].over_cancel
		elif _key_held[slot]:
			stick = _key_aim[slot]
			cancelled = _key_cancel[slot]
		else:
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
	_cancel_zone.visible = _touch_held[0] or _touch_held[1]


func _character_name(state: PlayerState) -> String:
	var character: CharacterDef = _characters.get(state.character_id) as CharacterDef
	var name_text: String = character.display_name if character != null else "?"
	return "You (%s)" % name_text if state.id == LOCAL_ID else name_text


func _make_actor_view(state: PlayerState) -> void:
	var team_color: Color = GreyboxMap.ENEMY_COLOR
	if state.id == LOCAL_ID:
		team_color = GreyboxMap.OWN_COLOR
	elif state.team == LOCAL_TEAM:
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
