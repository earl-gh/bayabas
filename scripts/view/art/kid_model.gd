class_name KidModel
extends Node3D
## One of the six kids (docs/PROJECT.md 3.2) on a shared, jointed body ("rig"):
## hips -> thighs -> knees -> feet, hips -> spine -> neck -> head, spine ->
## shoulders -> elbows -> hands. Same proportions for everyone (the hitbox never
## changes); the outfit comes from CharacterDef. All motion is procedural:
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
	var def: CharacterDef = character
	var width: float = def.body_width
	_body = _joint(self, Vector3.ZERO, "Body")
	_body.scale = Vector3.ONE * VISUAL_SCALE
	_hips = _joint(_body, Vector3(0.0, LEG_LENGTH, 0.0), "Hips")
	var pelvis: LowPoly = LowPoly.new()
	var pelvis_color: Color = def.tint if def.bottom == CharacterDef.Bottom.NONE else def.bottom_color
	pelvis.box(Vector3(0.0, 0.03, 0.0), Vector3(0.36 * width, 0.16, 0.24 * width), pelvis_color)
	_add_mesh(_hips, pelvis)
	_build_legs(def, width)
	_spine = _joint(_hips, Vector3(0.0, 0.08, 0.0), "Spine")
	_build_torso(def, width)
	_neck = _joint(_spine, Vector3(0.0, TORSO_HEIGHT, 0.0), "Neck")
	_build_head(def)
	_build_arms(def, width)
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


func _build_legs(def: CharacterDef, width: float) -> void:
	for i: int in 2:
		var side: float = -1.0 if i == 0 else 1.0
		var thigh: Node3D = _joint(_hips, Vector3(side * 0.1 * width, 0.0, 0.0), "Thigh%d" % i)
		var covered_thigh: bool = def.bottom != CharacterDef.Bottom.NONE
		var upper: LowPoly = LowPoly.new()
		upper.box(Vector3(0.0, -THIGH / 2.0, 0.0), Vector3(0.15, THIGH, 0.15), def.skin)
		if covered_thigh:
			upper.box(Vector3(0.0, -THIGH * 0.4, 0.0), Vector3(0.18 * width, THIGH * 0.85, 0.18), def.bottom_color)
			if def.bottom == CharacterDef.Bottom.CARGO_SHORTS:
				upper.box(Vector3(side * 0.09, -THIGH * 0.55, 0.0), Vector3(0.04, 0.09, 0.1), def.bottom_color.darkened(0.2))
		elif def.top == CharacterDef.Top.BESTIDA:
			upper.box(Vector3(0.0, -0.04, 0.0), Vector3(0.17, 0.08, 0.17), def.tint)
		_add_mesh(thigh, upper)
		var knee: Node3D = _joint(thigh, Vector3(0.0, -THIGH, 0.0), "Knee%d" % i)
		var lower: LowPoly = LowPoly.new()
		var shin_color: Color = def.bottom_color if def.bottom == CharacterDef.Bottom.JOGGING_PANTS else def.skin
		lower.box(Vector3(0.0, -SHIN / 2.0, 0.0), Vector3(0.14, SHIN, 0.14), shin_color)
		if def.shoes:
			lower.box(Vector3(0.0, -SHIN + 0.05, -0.04), Vector3(0.17, 0.11, 0.27), def.shoe_color, Palette.WHITE)
		else:
			lower.box(Vector3(0.0, -SHIN + 0.015, -0.04), Vector3(0.16, 0.035, 0.27), def.shoe_color)
			lower.box(Vector3(0.0, -SHIN + 0.04, -0.09), Vector3(0.1, 0.02, 0.03), def.shoe_color.darkened(0.3))
		_add_mesh(knee, lower)
		_thighs.append(thigh)
		_knees.append(knee)


func _build_torso(def: CharacterDef, width: float) -> void:
	var torso: LowPoly = LowPoly.new()
	torso.box(Vector3(0.0, TORSO_HEIGHT / 2.0, 0.0), Vector3(0.42 * width, TORSO_HEIGHT, 0.26 * width), def.tint)
	match def.top:
		CharacterDef.Top.SANDO:
			torso.box(Vector3(0.0, TORSO_HEIGHT - 0.06, 0.0), Vector3(0.28, 0.12, 0.27), def.skin)
		CharacterDef.Top.TEE_KNOTTED:
			torso.box(Vector3(0.0, 0.26, -0.135), Vector3(0.16, 0.14, 0.02), def.top_accent)
			torso.box(Vector3(0.17, 0.04, -0.1), Vector3(0.1, 0.1, 0.1), def.tint.darkened(0.15))
		CharacterDef.Top.BESTIDA:
			torso.cylinder(Vector3(0.0, -0.36, 0.0), 0.34, 0.22, 0.42, 10, def.tint)
			for i: int in 8:
				var angle: float = TAU * float(i) / 8.0
				torso.box(Vector3(cos(angle) * 0.29, -0.2 + float(i % 2) * 0.12, sin(angle) * 0.29), Vector3(0.06, 0.06, 0.06), def.top_accent)
		CharacterDef.Top.JERSEY:
			torso.box(Vector3(0.0, TORSO_HEIGHT / 2.0 - 0.04, 0.0), Vector3(0.5, TORSO_HEIGHT + 0.08, 0.3), def.tint)
			torso.box(Vector3(0.0, 0.25, -0.16), Vector3(0.14, 0.18, 0.02), def.top_accent)
		CharacterDef.Top.POLO_STRIPED:
			for i: int in 3:
				torso.box(Vector3(0.0, 0.09 + float(i) * 0.13, 0.0), Vector3(0.43 * width, 0.05, 0.27 * width), def.top_accent)
			torso.box(Vector3(0.0, TORSO_HEIGHT - 0.02, -0.1), Vector3(0.2, 0.05, 0.08), def.top_accent)
		CharacterDef.Top.PE_SHIRT:
			torso.box(Vector3(0.0, 0.3, -0.135), Vector3(0.12, 0.1, 0.02), def.top_accent)
			torso.box(Vector3(0.0, TORSO_HEIGHT - 0.03, 0.0), Vector3(0.43, 0.06, 0.27), def.top_accent)
	# team bandana around the neck
	torso.box(Vector3(0.0, TORSO_HEIGHT + 0.01, 0.0), Vector3(0.3, 0.07, 0.24), team_color)
	torso.tri(Vector3(-0.1, TORSO_HEIGHT, -0.12), Vector3(0.1, TORSO_HEIGHT, -0.12), Vector3(0.0, TORSO_HEIGHT - 0.15, -0.15), team_color, Vector3(0.0, TORSO_HEIGHT, 0.0))
	match def.extra:
		CharacterDef.Extra.BIMPO:
			torso.box(Vector3(0.0, 0.18, 0.16), Vector3(0.18, 0.3, 0.04), def.extra_color)
		CharacterDef.Extra.HEADBAND_BELT_BAG:
			torso.box(Vector3(0.12, 0.08, -0.15), Vector3(0.2, 0.1, 0.07), def.extra_color)
	var node: MeshInstance3D = _add_mesh(_spine, torso)
	node.name = "Torso"


func _build_head(def: CharacterDef) -> void:
	var head: LowPoly = LowPoly.new()
	var c: Vector3 = Vector3(0.0, HEAD_RADIUS + 0.05, 0.0)
	head.box(Vector3(0.0, 0.03, 0.0), Vector3(0.12, 0.08, 0.12), def.skin)
	head.sphere(c, HEAD_RADIUS, def.skin, 12, 8)
	for side: float in [-1.0, 1.0]:
		head.sphere(c + Vector3(side * 0.09, 0.02, -HEAD_RADIUS + 0.03), 0.045, Palette.BLACK, 6, 4)
		head.sphere(c + Vector3(side * 0.08, 0.035, -HEAD_RADIUS + 0.005), 0.014, Palette.WHITE, 4, 3)
		head.sphere(c + Vector3(side * 0.16, -0.06, -HEAD_RADIUS + 0.08), 0.035, Color(1.0, 0.55, 0.55), 5, 3)
	head.box(c + Vector3(0.0, -0.1, -HEAD_RADIUS + 0.035), Vector3(0.09, 0.022, 0.03), def.skin.darkened(0.4))
	var hair_top: Vector3 = c + Vector3(0.0, 0.07, 0.03)
	match def.hair:
		CharacterDef.Hair.SHORT:
			head.sphere(hair_top, HEAD_RADIUS * 1.04, def.hair_color, 12, 5)
		CharacterDef.Hair.BUZZ:
			head.sphere(hair_top + Vector3(0.0, 0.03, 0.0), HEAD_RADIUS * 0.98, def.hair_color.lightened(0.15), 12, 4)
		CharacterDef.Hair.PONYTAIL:
			head.sphere(hair_top, HEAD_RADIUS * 1.05, def.hair_color, 12, 5)
			head.sphere(c + Vector3(0.0, 0.02, HEAD_RADIUS + 0.12), 0.11, def.hair_color, 8, 5)
			head.sphere(c + Vector3(0.0, -0.12, HEAD_RADIUS + 0.12), 0.08, def.hair_color, 8, 5)
		CharacterDef.Hair.PIGTAILS:
			head.sphere(hair_top, HEAD_RADIUS * 1.05, def.hair_color, 12, 5)
			for side: float in [-1.0, 1.0]:
				head.sphere(c + Vector3(side * (HEAD_RADIUS + 0.06), -0.06, 0.05), 0.1, def.hair_color, 8, 5)
				head.sphere(c + Vector3(side * (HEAD_RADIUS + 0.08), -0.2, 0.06), 0.07, def.hair_color, 8, 5)
		CharacterDef.Hair.CAP_BACKWARD:
			head.sphere(hair_top + Vector3(0.0, -0.02, 0.0), HEAD_RADIUS * 1.02, def.hair_color, 12, 5)
			head.cylinder(c + Vector3(0.0, 0.12, 0.0), HEAD_RADIUS * 1.06, HEAD_RADIUS * 0.85, 0.16, 12, def.extra_color)
			head.box(c + Vector3(0.0, 0.14, HEAD_RADIUS + 0.08), Vector3(0.28, 0.04, 0.2), def.extra_color)
	match def.extra:
		CharacterDef.Extra.HAIR_CLIP:
			head.box(c + Vector3(0.18, 0.18, -0.05), Vector3(0.1, 0.05, 0.05), def.extra_color)
		CharacterDef.Extra.HEADBAND_BELT_BAG:
			head.cylinder(c + Vector3(0.0, 0.08, 0.0), HEAD_RADIUS * 1.08, HEAD_RADIUS * 1.08, 0.07, 12, def.extra_color)
		CharacterDef.Extra.PONY_BANDS:
			for side: float in [-1.0, 1.0]:
				head.sphere(c + Vector3(side * (HEAD_RADIUS + 0.06), 0.05, 0.05), 0.05, def.extra_color, 6, 4)
	_add_mesh(_neck, head)


func _build_arms(def: CharacterDef, width: float) -> void:
	var sleeve: bool = def.top != CharacterDef.Top.SANDO and def.top != CharacterDef.Top.JERSEY
	for i: int in 2:
		var side: float = -1.0 if i == 0 else 1.0
		var shoulder: Node3D = _joint(_spine, Vector3(side * (0.24 * width + 0.03), TORSO_HEIGHT - 0.06, 0.0), "Shoulder%d" % i)
		var upper: LowPoly = LowPoly.new()
		upper.box(Vector3(0.0, -UPPER_ARM / 2.0, 0.0), Vector3(0.11, UPPER_ARM + 0.02, 0.11), def.skin)
		if sleeve:
			upper.box(Vector3(0.0, -0.05, 0.0), Vector3(0.14, 0.12, 0.14), def.tint)
		if i == 0:
			upper.box(Vector3(0.0, -0.13, 0.0), Vector3(0.13, 0.06, 0.13), team_color)
		_add_mesh(shoulder, upper)
		var elbow: Node3D = _joint(shoulder, Vector3(0.0, -UPPER_ARM, 0.0), "Elbow%d" % i)
		var lower: LowPoly = LowPoly.new()
		lower.box(Vector3(0.0, -FOREARM / 2.0, 0.0), Vector3(0.1, FOREARM, 0.1), def.skin)
		lower.sphere(Vector3(0.0, -FOREARM - 0.03, 0.0), 0.065, def.skin, 6, 4)
		if i == 1 and def.extra == CharacterDef.Extra.ICE_CANDY:
			lower.box(Vector3(0.0, -FOREARM - 0.12, -0.04), Vector3(0.06, 0.16, 0.06), def.extra_color)
		_add_mesh(elbow, lower)
		_shoulders.append(shoulder)
		_elbows.append(elbow)


func _add_mesh(parent: Node3D, kit: LowPoly) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = kit.commit()
	parent.add_child(node)
	_meshes.append(node)
	LowPoly.add_outline(node, OUTLINE)
	return node
