class_name NeutralsView
extends Node3D
## The rubber ball and the tricycle (plus its warning stripe on the midline).
## Read-only view of MatchSim.ball and MatchSim.tricycle.

const BALL_HEIGHT: float = 0.4
const HELD_HEIGHT: float = 2.1
const WARNING_COLOR: Color = Color(1.0, 0.85, 0.1, 0.45)
const WARNING_BLINK_HZ: float = 4.0

var _sim: MatchSim
var _ball: MeshInstance3D
var _tricycle: MeshInstance3D
var _warning: MeshInstance3D
var _clock: float = 0.0


func watch(sim: MatchSim) -> void:
	_sim = sim
	_ball = _add(Props.rubber_ball(sim.rules.ball_radius))
	_tricycle = _add(Props.tricycle(sim.rules.tricycle_length, sim.rules.tricycle_width))
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
	if ball.state == RubberBall.State.GROUND:
		height += absf(sin(_clock * 3.0)) * 0.25
	_ball.position = Vector3(ball.position.x, height, ball.position.y)
	_ball.rotation.y += delta * 3.0
	var tricycle: Tricycle = _sim.tricycle
	_tricycle.visible = tricycle.phase == Tricycle.Phase.CROSSING
	_tricycle.position = Vector3(tricycle.position.x, 0.0, tricycle.position.y)
	_tricycle.rotation.y = 0.0 if tricycle.direction > 0 else PI
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
