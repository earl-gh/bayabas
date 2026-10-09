class_name PracticeMatch
extends Node3D
## Offline practice match: runs a local MatchSim, draws it, and feeds it input.
## Reads sim state only; all rules live in scripts/sim/.

const LOCAL_ID: int = 1
const LOCAL_TEAM: int = 0
const MAX_STEPS_PER_FRAME: int = 8
const PLAYER_HEIGHT: float = 1.8

@export var rules: GameRules
@export var layout: MapLayout

var sim: MatchSim

var _accumulator: float = 0.0
var _stick: Vector2 = Vector2.ZERO
var _player_view: MeshInstance3D

@onready var _camera: FollowCamera = %FollowCamera
@onready var _joystick: VirtualJoystick = %Joystick
@onready var _actors: Node3D = %Actors


func _ready() -> void:
	sim = MatchSim.new(rules, layout, Time.get_ticks_usec())
	sim.add_player(LOCAL_ID, LOCAL_TEAM)
	_player_view = _make_player_view()
	_actors.add_child(_player_view)
	_joystick.changed.connect(set_stick)
	_sync_views()


func _process(delta: float) -> void:
	advance(delta)


func set_stick(value: Vector2) -> void:
	_stick = value


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
	sim.set_input(LOCAL_ID, PlayerInput.create(world_move, Vector2.ZERO, 0, sim.tick))
	sim.step(dt)


func _sync_views() -> void:
	var player: PlayerState = sim.players[LOCAL_ID]
	_player_view.position = Vector3(player.position.x, PLAYER_HEIGHT / 2.0, player.position.y)
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
