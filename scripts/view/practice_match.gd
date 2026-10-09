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
const TAG_FONT_SIZE: int = 56
## Practice-only: the debug button stands in for enemy damage until weapons exist.
const DEBUG_DAMAGE: int = 30
const ALLY_COLOR: Color = Color(0.5, 0.75, 1.0)
const DELAY_COLOR: Color = Color(0.62, 0.62, 0.66)
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

@onready var _camera: FollowCamera = %FollowCamera
@onready var _joystick: VirtualJoystick = %Joystick
@onready var _actors: Node3D = %Actors
@onready var _hp_label: Label = %HpLabel
@onready var _respawn_label: Label = %RespawnLabel
@onready var _delay_label: Label = %DelayLabel
@onready var _dash_button: TouchButton = %DashButton
@onready var _bookmark_button: TouchButton = %BookmarkButton
@onready var _hurt_button: Button = %HurtButton


func _ready() -> void:
	sim = MatchSim.new(rules, layout, Time.get_ticks_usec())
	sim.add_player(LOCAL_ID, LOCAL_TEAM)
	sim.add_dummy(ENEMY_STAND_ID, 1, Vector2(rules.dummy_stand_x, rules.dummy_z), DummyBrain.standing())
	var patrol: DummyBrain = DummyBrain.patrolling(
		rules.dummy_patrol_x, rules.dummy_patrol_range, rules.dummy_patrol_speed_scale
	)
	sim.add_dummy(ENEMY_PATROL_ID, 1, Vector2(rules.dummy_patrol_x, rules.dummy_z), patrol)
	sim.add_dummy(ALLY_ID, LOCAL_TEAM, Vector2(rules.dummy_ally_x, rules.dummy_ally_z), DummyBrain.standing())
	for id: int in sim.players:
		_make_actor_view(sim.players[id])
	_joystick.changed.connect(set_stick)
	_dash_button.pressed.connect(press_skill.bind(PlayerInput.BTN_DASH))
	_bookmark_button.pressed.connect(press_skill.bind(PlayerInput.BTN_BOOKMARK))
	_hurt_button.pressed.connect(hurt_local.bind(DEBUG_DAMAGE))
	_sync_views()


func _process(delta: float) -> void:
	advance(delta)


func set_stick(value: Vector2) -> void:
	_stick = value


## A skill button was pressed; it is sent with the next sim tick.
func press_skill(button_bit: int) -> void:
	_pending_buttons |= button_bit


func hurt_local(amount: int) -> void:
	sim.damage(LOCAL_ID, amount)
	_sync_views()


## Runs as many fixed sim ticks as `delta` allows, then updates the visuals.
func advance(delta: float) -> void:
	_accumulator += delta
	var dt: float = rules.tick_dt()
	var steps: int = 0
	while _accumulator >= dt and steps < MAX_STEPS_PER_FRAME:
		_step_once(dt)
		_accumulator -= dt
		steps += 1
	if steps == MAX_STEPS_PER_FRAME:
		_accumulator = 0.0
	_sync_views()


func _step_once(dt: float) -> void:
	var flip: bool = sim.players[LOCAL_ID].team != 0
	var stick: Vector2 = LocalInput.combine(_stick, LocalInput.keyboard_vector())
	var world_move: Vector2 = LocalInput.to_world(stick, flip)
	var buttons: int = _pending_buttons | LocalInput.keyboard_buttons()
	_pending_buttons = 0
	sim.set_input(LOCAL_ID, PlayerInput.create(world_move, Vector2.ZERO, buttons, sim.tick))
	sim.step(dt)


func _sync_views() -> void:
	for id: int in sim.players:
		_sync_actor(sim.players[id])
	var player: PlayerState = sim.players[LOCAL_ID]
	_sync_hud(player)
	_camera.follow(player.position, player.team != 0)


func _sync_actor(state: PlayerState) -> void:
	var view: MeshInstance3D = _views[state.id]
	view.position = Vector3(state.position.x, PLAYER_HEIGHT / 2.0, state.position.y)
	view.visible = state.alive
	_materials[state.id].albedo_color = DELAY_COLOR if state.death_delay else _base_colors[state.id]
	if state.id != LOCAL_ID:
		var tag: Label3D = _tags[state.id]
		tag.text = "GRAY %d" % ceili(state.gray_hp) if state.death_delay else "HP %d" % state.hp


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
	_dash_button.set_locked(player.death_delay)
	_bookmark_button.set_locked(player.death_delay)
	_dash_button.set_cooldown(player.dash_cooldown_left, rules.dash_cooldown)
	_bookmark_button.set_cooldown(player.bookmark_cooldown_left, rules.bookmark_cooldown)


func _make_actor_view(state: PlayerState) -> void:
	var color: Color = GreyboxMap.ENEMY_COLOR
	if state.id == LOCAL_ID:
		color = GreyboxMap.OWN_COLOR
	elif state.team == LOCAL_TEAM:
		color = ALLY_COLOR
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
	if state.id != LOCAL_ID:
		var tag: Label3D = Label3D.new()
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.pixel_size = TAG_PIXEL_SIZE
		tag.font_size = TAG_FONT_SIZE
		tag.position = Vector3(0.0, TAG_HEIGHT - PLAYER_HEIGHT / 2.0, 0.0)
		view.add_child(tag)
		_tags[state.id] = tag
