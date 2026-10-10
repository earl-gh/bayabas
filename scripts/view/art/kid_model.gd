class_name KidModel
extends Node3D
## One of the six kids (docs/PROJECT.md 3.2) on a shared, jointed body ("rig"):
## hips -> thighs -> knees -> feet, hips -> spine -> neck -> head, spine ->
## shoulders -> elbows -> hands. Same proportions for everyone (the hitbox never
## changes); the look is the Blender-authored skinned mesh of that kid (KidSkin).
## The joint nodes here only carry the pose; KidSkin copies them onto the bones.
## All motion is procedural:
## run cycle with knee and elbow bend, counter-twist and head bob, idle breathing,
## a throw, a hit flinch, dash lean, stumble, stun wobble, airborne tumble,
## knockout lie-down, a limp when down (grey), and a can when polymorphed.
## Origin at the feet; faces -Z before `face()` turns it.

const THIGH: float = 0.28
const SHIN: float = 0.27
const LEG_LENGTH: float = THIGH + SHIN
const TORSO_HEIGHT: float = 0.46
const UPPER_ARM: float = 0.2
const FOREARM: float = 0.2
const HEAD_RADIUS: float = 0.27
const GHOST_COLOR: Color = Color(0.45, 0.45, 0.5)
## Chunky, toy-like proportions on screen. Visual only: the hitbox is GameRules.
const VISUAL_SCALE: float = 1.3
## Cartoon outline thickness (m, before VISUAL_SCALE).
const OUTLINE: float = 0.02
const STRIDE: float = 1.6
const CAST_TIME: float = 0.38
const HIT_TIME: float = 0.28

var character: CharacterDef
var team_color: Color = Color.WHITE

var _body: Node3D
var _skin: KidSkin
var _joints: Array[Node3D] = []
var _hips: Node3D
var _spine: Node3D
var _neck: Node3D
var _thighs: Array[Node3D] = []
var _knees: Array[Node3D] = []
var _shoulders: Array[Node3D] = []
var _elbows: Array[Node3D] = []
## A foot hit the ground (run cycle), for footstep sounds.
signal footstep

var _can: MeshInstance3D
var _ring: MeshInstance3D
var _meshes: Array[MeshInstance3D] = []
var _ghost_material: StandardMaterial3D
var _phase: float = 0.0
var _clock: float = 0.0
var _ghost: bool = false
var _cast_left: float = 0.0
var _hit_left: float = 0.0
var _move_blend: float = 0.0
## Last pose name, for tests and debugging ("idle", "run", "cast", "ko", ...).
var pose: String = "idle"
var _last_step: int = 0


## Height of the drawn kid (the same for all six).
static func total_height() -> float:
	return (LEG_LENGTH + TORSO_HEIGHT + HEAD_RADIUS * 2.0 + 0.1) * VISUAL_SCALE


func setup(def: CharacterDef, team: Color, ring_radius: float) -> void:
	character = def
	team_color = team
	_ghost_material = StandardMaterial3D.new()
	_ghost_material.albedo_color = GHOST_COLOR
	_build(ring_radius)


## Turns the kid to look along `facing` (world x/z).
func face(facing: Vector2) -> void:
	if facing.length_squared() > 0.0001:
		rotation.y = atan2(-facing.x, -facing.y)


## Throwing arm swing (a weapon was cast).
func play_cast() -> void:
	_cast_left = CAST_TIME


## Flinch (took damage).
func play_hit() -> void:
	_hit_left = HIT_TIME


func is_can() -> bool:
	return _can.visible


func is_ghost() -> bool:
	return _ghost


func set_ghost(on: bool) -> void:
	if on == _ghost:
		return
	_ghost = on
	for mesh: MeshInstance3D in _meshes:
		mesh.material_override = _ghost_material if on else null


## Per frame: `speed` is the ground speed in m/s.
func animate(delta: float, speed: float, state: PlayerState) -> void:
	_clock += delta
	_cast_left = maxf(0.0, _cast_left - delta)
	_hit_left = maxf(0.0, _hit_left - delta)
	var polymorphed: bool = state.effects.has(StatusEffects.Type.POLYMORPH)
	_body.visible = not polymorphed
	_can.visible = polymorphed
	set_ghost(state.death_delay)
	if polymorphed:
		pose = "can"
		_can.rotation.z = sin(_clock * 10.0) * 0.1 * clampf(speed, 0.0, 1.0)
		_can.position.y = absf(sin(_clock * 10.0)) * 0.08 * clampf(speed, 0.0, 1.0)
		return
	_move_blend = move_toward(_move_blend, 1.0 if speed > 0.3 else 0.0, delta * 6.0)
	if speed > 0.3:
		_phase += delta * speed / STRIDE
		var step_index: int = int(floor(_phase * 2.0))
		if step_index != _last_step:
			_last_step = step_index
			footstep.emit()
	_reset_pose()
	_locomotion(speed)
	if state.effects.has(StatusEffects.Type.KNOCKOUT):
		_pose_knockout()
	elif state.effects.has(StatusEffects.Type.AIRBORNE) or state.effects.has(StatusEffects.Type.BOUNCE):
		_pose_airborne()
	elif state.effects.has(StatusEffects.Type.STUN):
		_pose_stunned()
	elif state.dash_time_left > 0.0:
		_pose_dash()
	elif state.stumble_time_left > 0.0:
		_pose_stumble()
	elif state.death_delay:
		_pose_down()
	if _cast_left > 0.0 and not state.death_delay:
		_pose_cast()
	if _hit_left > 0.0:
		_pose_hit()
	_skin.pose(_joints)


func _reset_pose() -> void:
	_body.rotation = Vector3.ZERO
	_body.position = Vector3.ZERO
	_hips.position = Vector3(0.0, LEG_LENGTH, 0.0)
	_hips.rotation = Vector3.ZERO
	_spine.rotation = Vector3.ZERO
	_neck.rotation = Vector3.ZERO
	for i: int in 2:
		_thighs[i].rotation = Vector3.ZERO
		_knees[i].rotation = Vector3.ZERO
		_shoulders[i].rotation = Vector3(0.0, 0.0, (-1.0 if i == 0 else 1.0) * 0.12)
		_elbows[i].rotation = Vector3(0.35, 0.0, 0.0)


## Run cycle blended with idle breathing.
func _locomotion(speed: float) -> void:
	var run: float = _move_blend
	var t: float = _phase * TAU
	var amount: float = clampf(speed / 5.0, 0.4, 1.0) * run
	pose = "run" if run > 0.5 else "idle"
	for i: int in 2:
		var side: float = 1.0 if i == 0 else -1.0
		var swing: float = sin(t) * side
		_thighs[i].rotation.x = swing * 0.8 * amount
		# the knee bends most while the leg swings back and lifts
		_knees[i].rotation.x = -maxf(0.0, -cos(t) * side + 0.3) * 1.0 * amount
		_shoulders[i].rotation.x = -swing * 0.9 * amount
		_elbows[i].rotation.x = 0.35 + 0.9 * amount
	_hips.position.y = LEG_LENGTH - 0.03 * amount + absf(cos(t)) * 0.05 * amount
	_hips.rotation.y = sin(t) * 0.12 * amount
	_spine.rotation.y = -sin(t) * 0.2 * amount
	_spine.rotation.x = -0.18 * amount
	_neck.rotation.x = 0.12 * amount
	# idle: breathe and sway a little
	var idle: float = 1.0 - run
	_spine.rotation.x += sin(_clock * 2.2) * 0.03 * idle
	_spine.rotation.z = sin(_clock * 1.1) * 0.02 * idle
	_neck.rotation.y = sin(_clock * 0.7) * 0.15 * idle


func _pose_cast() -> void:
	pose = "cast"
	var u: float = 1.0 - _cast_left / CAST_TIME
	# wind up (arm back and up), then whip forward and follow through
	var arm: float = lerpf(-2.4, 1.3, smoothstep(0.25, 0.6, u)) if u > 0.25 else lerpf(0.0, -2.4, u / 0.25)
	_shoulders[1].rotation.x = arm
	_elbows[1].rotation.x = 0.2 if u > 0.4 else 1.2
	_shoulders[0].rotation.x = 0.6
	_spine.rotation.y = lerpf(0.5, -0.4, smoothstep(0.2, 0.7, u))
	_spine.rotation.x = -0.1


func _pose_hit() -> void:
	var u: float = _hit_left / HIT_TIME
	_spine.rotation.x += 0.45 * u
	_neck.rotation.x += 0.3 * u
	_body.position.z += 0.12 * u
	for i: int in 2:
		_shoulders[i].rotation.z += (-1.0 if i == 0 else 1.0) * 0.5 * u


func _pose_dash() -> void:
	pose = "dash"
	_spine.rotation.x = -0.6
	_neck.rotation.x = 0.4
	for i: int in 2:
		_shoulders[i].rotation.x = -1.1
		_elbows[i].rotation.x = 0.4
	_thighs[0].rotation.x = 0.9
	_knees[0].rotation.x = -0.4
	_thighs[1].rotation.x = -0.7
	_knees[1].rotation.x = -1.3


func _pose_stumble() -> void:
	pose = "stumble"
	_spine.rotation.x = -0.7
	_hips.position.y = LEG_LENGTH - 0.12
	for i: int in 2:
		_knees[i].rotation.x = -0.7
		_thighs[i].rotation.x = 0.4
		_shoulders[i].rotation.x = 0.9
		_shoulders[i].rotation.z = (-1.0 if i == 0 else 1.0) * 0.6


func _pose_stunned() -> void:
	pose = "stunned"
	_spine.rotation.z = sin(_clock * 5.0) * 0.18
	_spine.rotation.x = 0.12
	_neck.rotation.z = sin(_clock * 5.0 + 1.0) * 0.3
	for i: int in 2:
		_shoulders[i].rotation.x = 0.1
		_shoulders[i].rotation.z = (-1.0 if i == 0 else 1.0) * 0.2
		_elbows[i].rotation.x = 0.1


func _pose_airborne() -> void:
	pose = "airborne"
	_body.rotation.x = _clock * 7.0
	_body.position.y = 0.4
	for i: int in 2:
		_shoulders[i].rotation.z = (-1.0 if i == 0 else 1.0) * 1.4
		_thighs[i].rotation.x = 0.6
		_knees[i].rotation.x = -1.2


func _pose_knockout() -> void:
	pose = "ko"
	_body.rotation.x = PI / 2.0 - 0.1
	_body.position.y = 0.2
	_body.position.z = 0.4
	for i: int in 2:
		_shoulders[i].rotation.z = (-1.0 if i == 0 else 1.0) * 1.2
		_knees[i].rotation.x = -0.2


func _pose_down() -> void:
	pose = "down"
	_spine.rotation.x = -0.5
	_neck.rotation.x = 0.35
	_hips.position.y -= 0.06
	for i: int in 2:
		_shoulders[i].rotation.x = 0.25
		_elbows[i].rotation.x = 0.1
		_knees[i].rotation.x -= 0.25


# ---- building the rig ----------------------------------------------------------

func _joint(parent: Node3D, at: Vector3, joint_name: String) -> Node3D:
	var node: Node3D = Node3D.new()
	node.name = joint_name
	node.position = at
	parent.add_child(node)
	return node


func _build(ring_radius: float) -> void:
	_body = _joint(self, Vector3.ZERO, "Body")
	_body.scale = Vector3.ONE * VISUAL_SCALE
	_hips = _joint(_body, Vector3(0.0, LEG_LENGTH, 0.0), "Hips")
	_spine = _joint(_hips, Vector3(0.0, 0.08, 0.0), "Spine")
	_neck = _joint(_spine, Vector3(0.0, TORSO_HEIGHT, 0.0), "Neck")
	for i: int in 2:
		var side: float = -1.0 if i == 0 else 1.0
		_thighs.append(_joint(_hips, Vector3(side * 0.1, 0.0, 0.0), "Thigh%d" % i))
		_knees.append(_joint(_thighs[i], Vector3(0.0, -THIGH, 0.0), "Knee%d" % i))
		_shoulders.append(_joint(_spine, Vector3(side * 0.27, TORSO_HEIGHT - 0.06, 0.0), "Shoulder%d" % i))
		_elbows.append(_joint(_shoulders[i], Vector3(0.0, -UPPER_ARM, 0.0), "Elbow%d" % i))
	# same order as KidSkin.JOINTS
	_joints = [_hips, _spine, _neck, _thighs[0], _knees[0], _thighs[1], _knees[1],
			_shoulders[0], _elbows[0], _shoulders[1], _elbows[1]]
	_skin = KidSkin.new()
	_body.add_child(_skin)
	_skin.setup(character.id, team_color, LEG_LENGTH)
	_meshes.append_array(_skin.meshes)
	_can = MeshInstance3D.new()
	_can.mesh = Props.can_body()
	_can.scale = Vector3.ONE * VISUAL_SCALE
	_can.visible = false
	add_child(_can)
	_meshes.append(_can)
	LowPoly.add_outline(_can, OUTLINE)
	var ring_mesh: TorusMesh = TorusMesh.new()
	ring_mesh.inner_radius = ring_radius
	ring_mesh.outer_radius = ring_radius + 0.14
	ring_mesh.rings = 24
	ring_mesh.ring_segments = 6
	var ring_material: StandardMaterial3D = StandardMaterial3D.new()
	ring_material.albedo_color = team_color
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mesh.material = ring_material
	_ring = MeshInstance3D.new()
	_ring.name = "TeamRing"
	_ring.mesh = ring_mesh
	_ring.position.y = 0.05
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
