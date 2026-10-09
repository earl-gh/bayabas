class_name NeutralsView
extends Node3D
## The rubber ball and the tricycle (plus its warning stripe on the midline).
## Read-only view of MatchSim.ball and MatchSim.tricycle.

const BALL_COLOR: Color = Color(1.0, 0.25, 0.45)
const BALL_HEIGHT: float = 0.4
const HELD_HEIGHT: float = 2.1
const TRICYCLE_COLOR: Color = Color(0.15, 0.55, 0.95)
const TRICYCLE_HEIGHT: float = 1.4
const WARNING_COLOR: Color = Color(1.0, 0.85, 0.1, 0.45)
const WARNING_BLINK_HZ: float = 4.0

var _sim: MatchSim
var _ball: MeshInstance3D
var _tricycle: MeshInstance3D
var _warning: MeshInstance3D
var _clock: float = 0.0


func watch(sim: MatchSim) -> void:
	_sim = sim
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = sim.rules.ball_radius
	sphere.height = sim.rules.ball_radius * 2.0
	sphere.material = _material(BALL_COLOR)
	_ball = _add(sphere)
	var body: BoxMesh = BoxMesh.new()
	body.size = Vector3(sim.rules.tricycle_length, TRICYCLE_HEIGHT, sim.rules.tricycle_width)
	body.material = _material(TRICYCLE_COLOR)
	_tricycle = _add(body)
	var stripe: BoxMesh = BoxMesh.new()
	stripe.size = Vector3(sim.layout.lane_width, 0.05, sim.rules.tricycle_width)
	stripe.material = _material(WARNING_COLOR)
	_warning = _add(stripe)
	sync(0.0)


func sync(delta: float) -> void:
	_clock += delta
	var ball: RubberBall = _sim.ball
	_ball.visible = ball.state != RubberBall.State.NONE
	var height: float = HELD_HEIGHT if ball.state == RubberBall.State.HELD else BALL_HEIGHT
	_ball.position = Vector3(ball.position.x, height, ball.position.y)
	var tricycle: Tricycle = _sim.tricycle
	_tricycle.visible = tricycle.phase == Tricycle.Phase.CROSSING
	_tricycle.position = Vector3(tricycle.position.x, TRICYCLE_HEIGHT / 2.0, tricycle.position.y)
	var warning: bool = tricycle.phase == Tricycle.Phase.WARNING
	_warning.visible = warning and fmod(_clock * WARNING_BLINK_HZ, 1.0) < 0.6


func ball_visible() -> bool:
	return _ball.visible


func tricycle_visible() -> bool:
	return _tricycle.visible


func _add(mesh: Mesh) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = mesh
	add_child(node)
	return node


func _material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material
