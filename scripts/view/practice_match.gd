class_name PracticeMatch
extends Node3D
## Offline practice match: runs a local MatchSim, draws it, and feeds it input.
## Reads sim state only; all rules live in scripts/sim/.

const LOCAL_ID: int = 1
const LOCAL_TEAM: int = 0
const MAX_STEPS_PER_FRAME: int = 8
const PLAYER_HEIGHT: float = 1.8
## Practice-only: the debug button stands in for enemy damage until weapons exist.
const DEBUG_DAMAGE: int = 30

@export var rules: GameRules
@export var layout: MapLayout

var sim: MatchSim

var _accumulator: float = 0.0
var _stick: Vector2 = Vector2.ZERO
var _pending_buttons: int = 0
var _player_view: MeshInstance3D

@onready var _camera: FollowCamera = %FollowCamera
@onready var _joystick: VirtualJoystick = %Joystick
@onready var _actors: Node3D = %Actors
@onready var _hp_label: Label = %HpLabel
@onready var _respawn_label: Label = %RespawnLabel
@onready var _dash_button: TouchButton = %DashButton
@onready var _bookmark_button: TouchButton = %BookmarkButton
@onready var _hurt_button: Button = %HurtButton


func _ready() -> void:
	sim = MatchSim.new(rules, layout, Time.get_ticks_usec())
	sim.add_player(LOCAL_ID, LOCAL_TEAM)
	_player_view = _make_player_view()
	_actors.add_child(_player_view)
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
	var player: PlayerState = sim.players[LOCAL_ID]
	_player_view.position = Vector3(player.position.x, PLAYER_HEIGHT / 2.0, player.position.y)
	_player_view.visible = player.alive
	_hp_label.text = "HP %d / %d" % [player.hp, rules.player_max_hp]
	_respawn_label.visible = not player.alive
	_respawn_label.text = "Respawning in %d" % ceili(player.respawn_time_left)
	_dash_button.set_cooldown(player.dash_cooldown_left, rules.dash_cooldown)
	_bookmark_button.set_cooldown(player.bookmark_cooldown_left, rules.bookmark_cooldown)
	_camera.follow(player.position, player.team != 0)


func _make_player_view() -> MeshInstance3D:
	var mesh: CapsuleMesh = CapsuleMesh.new()
	mesh.radius = rules.player_radius
	mesh.height = PLAYER_HEIGHT
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = GreyboxMap.OWN_COLOR
	mesh.material = material
	var view: MeshInstance3D = MeshInstance3D.new()
	view.mesh = mesh
	return view
