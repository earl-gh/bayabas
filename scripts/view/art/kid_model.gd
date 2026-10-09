class_name KidModel
extends Node3D
## One of the six kids (docs/PROJECT.md 3.2) on a shared body: same height and
## proportions for everyone (the hitbox never changes), outfit from CharacterDef.
## Simple code animation: walk swing, idle breathing, lean on dash, spin when
## airborne, wobble when stunned, a can when polymorphed, grey in the death delay.
## Origin at the feet; faces -Z before `face()` turns it.

## Shared silhouette (meters).
const HEIGHT: float = 1.6
const LEG_LENGTH: float = 0.55
const TORSO_HEIGHT: float = 0.5
const HEAD_RADIUS: float = 0.27
const WALK_SWING: float = 0.7
const STEP_RATE: float = 2.6
const GHOST_COLOR: Color = Color(0.7, 0.7, 0.74)
## Chunky, toy-like proportions on screen. Visual only: the hitbox is GameRules.
const VISUAL_SCALE: float = 1.3

var character: CharacterDef
var team_color: Color = Color.WHITE

var _body: Node3D
var _hips: Node3D
var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _can: MeshInstance3D
var _ring: MeshInstance3D
var _meshes: Array[MeshInstance3D] = []
var _ghost_material: StandardMaterial3D
var _phase: float = 0.0
var _clock: float = 0.0
var _ghost: bool = false


## Height of the drawn kid (the same for all six).
static func total_height() -> float:
	return (LEG_LENGTH + TORSO_HEIGHT + HEAD_RADIUS * 2.0 + 0.06) * VISUAL_SCALE


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


## Per frame: `speed` is the ground speed in m/s.
func animate(delta: float, speed: float, state: PlayerState) -> void:
	_clock += delta
	var polymorphed: bool = state.effects.has(StatusEffects.Type.POLYMORPH)
	_body.visible = not polymorphed
	_can.visible = polymorphed
	set_ghost(state.death_delay)
	var swing: float = 0.0
	if speed > 0.2:
		_phase += delta * STEP_RATE * speed / 2.0
		swing = sin(_phase * TAU) * WALK_SWING * clampf(speed / 5.0, 0.3, 1.0)
	else:
		_phase = 0.0
	_legs[0].rotation.x = swing
	_legs[1].rotation.x = -swing
	_arms[0].rotation.x = -swing * 0.8
	_arms[1].rotation.x = swing * 0.8
	var bob: float = absf(sin(_phase * TAU)) * 0.06 if speed > 0.2 else sin(_clock * 2.0) * 0.015
	_hips.position.y = LEG_LENGTH + bob
	_body.rotation = Vector3.ZERO
	if state.dash_time_left > 0.0:
		_body.rotation.x = -0.45
	elif state.stumble_time_left > 0.0:
		_body.rotation.x = 0.35
	if state.effects.has(StatusEffects.Type.AIRBORNE) or state.effects.has(StatusEffects.Type.BOUNCE):
		_body.rotation.y = _clock * 9.0
	elif state.effects.has(StatusEffects.Type.STUN) or state.effects.has(StatusEffects.Type.KNOCKOUT):
		_body.rotation.z = sin(_clock * 6.0) * 0.25
	if polymorphed:
		_can.rotation.z = sin(_clock * 8.0) * 0.08 * clampf(speed, 0.0, 1.0)


func set_ghost(on: bool) -> void:
	if on == _ghost:
		return
	_ghost = on
	for mesh: MeshInstance3D in _meshes:
		mesh.material_override = _ghost_material if on else null


func is_can() -> bool:
	return _can.visible


func is_ghost() -> bool:
	return _ghost


func _build(ring_radius: float) -> void:
	var def: CharacterDef = character
	var width: float = def.body_width
	_body = Node3D.new()
	_body.scale = Vector3.ONE * VISUAL_SCALE
	add_child(_body)
	_hips = Node3D.new()
	_hips.position.y = LEG_LENGTH
	_body.add_child(_hips)
	# legs (pivot at the hip)
	for side: float in [-1.0, 1.0]:
		var pivot: Node3D = Node3D.new()
		pivot.position = Vector3(side * 0.12 * width, 0.0, 0.0)
		_hips.add_child(pivot)
		var leg: LowPoly = LowPoly.new()
		var leg_color: Color = def.skin
		var covered: float = 0.0
		match def.bottom:
			CharacterDef.Bottom.JOGGING_PANTS:
				covered = LEG_LENGTH - 0.08
			CharacterDef.Bottom.SHORTS, CharacterDef.Bottom.CARGO_SHORTS:
				covered = 0.22
		leg.box(Vector3(0.0, -LEG_LENGTH / 2.0, 0.0), Vector3(0.14, LEG_LENGTH, 0.14), leg_color)
		if covered > 0.0:
			leg.box(Vector3(0.0, -covered / 2.0, 0.0), Vector3(0.18 * width, covered, 0.18), def.bottom_color)
		if def.bottom == CharacterDef.Bottom.CARGO_SHORTS:
			leg.box(Vector3(side * 0.1, -0.15, 0.0), Vector3(0.04, 0.1, 0.1), def.bottom_color.darkened(0.2))
		if def.shoes:
			leg.box(Vector3(0.0, -LEG_LENGTH + 0.05, -0.04), Vector3(0.17, 0.11, 0.26), def.shoe_color, Palette.WHITE)
		else:
			leg.box(Vector3(0.0, -LEG_LENGTH + 0.015, -0.04), Vector3(0.16, 0.03, 0.26), def.shoe_color)
		_add_mesh(pivot, leg)
		_legs.append(pivot)
	# torso
	var torso: LowPoly = LowPoly.new()
	var top_height: float = TORSO_HEIGHT
	torso.box(Vector3(0.0, TORSO_HEIGHT / 2.0, 0.0), Vector3(0.42 * width, TORSO_HEIGHT, 0.26 * width), def.tint)
	match def.top:
		CharacterDef.Top.SANDO:
			torso.box(Vector3(0.0, TORSO_HEIGHT - 0.06, 0.0), Vector3(0.3, 0.12, 0.27), def.skin)
		CharacterDef.Top.TEE_KNOTTED:
			torso.box(Vector3(0.0, 0.25, -0.135), Vector3(0.16, 0.14, 0.02), def.top_accent)
			torso.box(Vector3(0.18, 0.05, -0.1), Vector3(0.1, 0.1, 0.1), def.tint.darkened(0.15))
		CharacterDef.Top.BESTIDA:
			torso.cylinder(Vector3(0.0, -0.32, 0.0), 0.34, 0.22, 0.42, 8, def.tint)
			for i: int in 6:
				var angle: float = TAU * float(i) / 6.0
				torso.box(Vector3(cos(angle) * 0.29, -0.15 + float(i % 2) * 0.12, sin(angle) * 0.29), Vector3(0.06, 0.06, 0.06), def.top_accent)
		CharacterDef.Top.JERSEY:
			torso.box(Vector3(0.0, TORSO_HEIGHT / 2.0 - 0.04, 0.0), Vector3(0.5, TORSO_HEIGHT + 0.08, 0.3), def.tint)
			torso.box(Vector3(0.0, 0.25, -0.16), Vector3(0.14, 0.18, 0.02), def.top_accent)
		CharacterDef.Top.POLO_STRIPED:
			for i: int in 3:
				torso.box(Vector3(0.0, 0.1 + float(i) * 0.14, 0.0), Vector3(0.43 * width, 0.05, 0.27 * width), def.top_accent)
			torso.box(Vector3(0.0, TORSO_HEIGHT - 0.02, -0.1), Vector3(0.2, 0.05, 0.08), def.top_accent)
		CharacterDef.Top.PE_SHIRT:
			torso.box(Vector3(0.0, 0.3, -0.135), Vector3(0.12, 0.1, 0.02), def.top_accent)
			torso.box(Vector3(0.0, TORSO_HEIGHT - 0.03, 0.0), Vector3(0.43, 0.06, 0.27), def.top_accent)
	if def.bottom != CharacterDef.Bottom.NONE:
		torso.box(Vector3(0.0, 0.06, 0.0), Vector3(0.43 * width, 0.12, 0.27 * width), def.bottom_color)
	# team bandana around the neck
	torso.box(Vector3(0.0, top_height + 0.02, 0.0), Vector3(0.3, 0.07, 0.24), team_color)
	torso.tri(Vector3(-0.1, top_height + 0.01, -0.12), Vector3(0.1, top_height + 0.01, -0.12), Vector3(0.0, top_height - 0.14, -0.15), team_color, Vector3(0.0, top_height, 0.0))
	match def.extra:
		CharacterDef.Extra.BIMPO:
			torso.box(Vector3(0.0, 0.2, 0.16), Vector3(0.18, 0.3, 0.04), def.extra_color)
		CharacterDef.Extra.HEADBAND_BELT_BAG:
			torso.box(Vector3(0.12, 0.12, -0.15), Vector3(0.2, 0.1, 0.07), def.extra_color)
	var torso_node: MeshInstance3D = _add_mesh(_hips, torso)
	torso_node.name = "Torso"
	# arms (pivot at the shoulder); the left one wears the team armband
	for side: float in [-1.0, 1.0]:
		var pivot: Node3D = Node3D.new()
		pivot.position = Vector3(side * (0.25 * width + 0.02), TORSO_HEIGHT - 0.05, 0.0)
		_hips.add_child(pivot)
		var arm: LowPoly = LowPoly.new()
		var sleeve: bool = def.top != CharacterDef.Top.SANDO and def.top != CharacterDef.Top.JERSEY
		arm.box(Vector3(0.0, -0.21, 0.0), Vector3(0.1, 0.42, 0.1), def.skin)
		if sleeve:
			arm.box(Vector3(0.0, -0.06, 0.0), Vector3(0.13, 0.14, 0.13), def.tint)
		if side < 0.0:
			arm.box(Vector3(0.0, -0.17, 0.0), Vector3(0.125, 0.06, 0.125), team_color)
		if side > 0.0 and def.extra == CharacterDef.Extra.ICE_CANDY:
			arm.box(Vector3(0.0, -0.46, -0.06), Vector3(0.06, 0.16, 0.06), def.extra_color)
		_add_mesh(pivot, arm)
		_arms.append(pivot)
	# head and hair
	var head: LowPoly = LowPoly.new()
	var head_center: Vector3 = Vector3(0.0, TORSO_HEIGHT + HEAD_RADIUS + 0.04, 0.0)
	head.sphere(head_center, HEAD_RADIUS, def.skin, 8, 5)
	for side: float in [-1.0, 1.0]:
		head.box(head_center + Vector3(side * 0.09, 0.02, -HEAD_RADIUS + 0.02), Vector3(0.06, 0.08, 0.04), Palette.BLACK)
	head.box(head_center + Vector3(0.0, -0.1, -HEAD_RADIUS + 0.03), Vector3(0.1, 0.025, 0.03), def.skin.darkened(0.35))
	var hair_top: Vector3 = head_center + Vector3(0.0, 0.07, 0.03)
	match def.hair:
		CharacterDef.Hair.SHORT:
			head.sphere(hair_top, HEAD_RADIUS * 1.04, def.hair_color, 8, 3)
		CharacterDef.Hair.BUZZ:
			head.sphere(hair_top + Vector3(0.0, 0.03, 0.0), HEAD_RADIUS * 0.98, def.hair_color.lightened(0.15), 8, 2)
		CharacterDef.Hair.PONYTAIL:
			head.sphere(hair_top, HEAD_RADIUS * 1.05, def.hair_color, 8, 3)
			head.box(head_center + Vector3(0.0, 0.0, HEAD_RADIUS + 0.1), Vector3(0.12, 0.34, 0.12), def.hair_color)
		CharacterDef.Hair.PIGTAILS:
			head.sphere(hair_top, HEAD_RADIUS * 1.05, def.hair_color, 8, 3)
			for side: float in [-1.0, 1.0]:
				head.box(head_center + Vector3(side * (HEAD_RADIUS + 0.06), -0.08, 0.05), Vector3(0.11, 0.3, 0.11), def.hair_color)
		CharacterDef.Hair.CAP_BACKWARD:
			head.sphere(hair_top + Vector3(0.0, -0.02, 0.0), HEAD_RADIUS * 1.02, def.hair_color, 8, 3)
			head.cylinder(head_center + Vector3(0.0, 0.12, 0.0), HEAD_RADIUS * 1.05, HEAD_RADIUS * 0.9, 0.14, 8, def.extra_color)
			head.box(head_center + Vector3(0.0, 0.14, HEAD_RADIUS + 0.08), Vector3(0.28, 0.04, 0.2), def.extra_color)
	match def.extra:
		CharacterDef.Extra.HAIR_CLIP:
			head.box(head_center + Vector3(0.18, 0.18, -0.05), Vector3(0.1, 0.05, 0.05), def.extra_color)
		CharacterDef.Extra.HEADBAND_BELT_BAG:
			head.cylinder(head_center + Vector3(0.0, 0.08, 0.0), HEAD_RADIUS * 1.08, HEAD_RADIUS * 1.08, 0.07, 8, def.extra_color)
		CharacterDef.Extra.PONY_BANDS:
			for side: float in [-1.0, 1.0]:
				head.box(head_center + Vector3(side * (HEAD_RADIUS + 0.06), 0.06, 0.05), Vector3(0.13, 0.05, 0.13), def.extra_color)
	_add_mesh(_hips, head)
	# polymorph can and the team ring on the ground
	_can = MeshInstance3D.new()
	_can.mesh = Props.can_body()
	_can.scale = Vector3.ONE * VISUAL_SCALE
	_can.visible = false
	add_child(_can)
	_meshes.append(_can)
	var ring_mesh: TorusMesh = TorusMesh.new()
	ring_mesh.inner_radius = ring_radius
	ring_mesh.outer_radius = ring_radius + 0.14
	ring_mesh.rings = 16
	ring_mesh.ring_segments = 4
	var ring_material: StandardMaterial3D = StandardMaterial3D.new()
	ring_material.albedo_color = team_color
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mesh.material = ring_material
	_ring = MeshInstance3D.new()
	_ring.name = "TeamRing"
	_ring.mesh = ring_mesh
	_ring.position.y = 0.05
	add_child(_ring)


func _add_mesh(parent: Node3D, kit: LowPoly) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = kit.commit()
	parent.add_child(node)
	_meshes.append(node)
	return node
