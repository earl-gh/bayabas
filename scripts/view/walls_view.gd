class_name WallsView
extends Node3D
## The breakable cardboard wall columns, drawn from MatchSim.walls. Every hit shows:
## the sheet flashes and wobbles, cardboard chips fly off, and rips, holes and tape
## patches spread over it as it loses HP (it also darkens and sags). At 0 HP it
## bursts into chips and is gone; all come back when the walls are rebuilt.

const WALL_HEIGHT: float = 2.0
const FRESH_COLOR: Color = Color(1.0, 1.0, 1.0)
const BROKEN_COLOR: Color = Color(0.5, 0.42, 0.34)
const FLASH_COLOR: Color = Color(1.6, 1.45, 1.2)
## Squashed a bit as it takes damage.
const BROKEN_SCALE: float = 0.78
const FLASH_TIME: float = 0.12
const WOBBLE_TIME: float = 0.35
const WOBBLE_ANGLE: float = 0.09
const CHIPS_PER_HIT: int = 10
const CHIPS_ON_BREAK: int = 40
const CHIP_COLOR: Color = Color(0.78, 0.58, 0.34)
## Rips and holes appear once a wall is below this much health.
const TEARS_FROM: float = 0.92

var _sim: MatchSim
var _boxes: Array[MeshInstance3D] = []
var _materials: Array[StandardMaterial3D] = []
var _doodles: Array[StandardMaterial3D] = []
var _tears: Array[StandardMaterial3D] = []
var _chips: Array[CPUParticles3D] = []
var _hit_left: Array[float] = []


func watch(sim: MatchSim) -> void:
	_sim = sim
	for child: Node in get_children():
		child.queue_free()
	_boxes.clear()
	_materials.clear()
	_doodles.clear()
	_tears.clear()
	_chips.clear()
	_hit_left.clear()
	for wall: MapLayout.WallSpec in sim.walls:
		# cardboard sheets; damage darkens them through a tint that multiplies the palette
		var material: StandardMaterial3D = LowPoly.material().duplicate() as StandardMaterial3D
		var box: MeshInstance3D = MeshInstance3D.new()
		box.mesh = Props.cardboard_wall(Vector3(wall.rect.size.x, WALL_HEIGHT, wall.rect.size.y))
		box.material_override = material
		var center: Vector2 = wall.rect.get_center()
		box.position = Vector3(center.x, 0.0, center.y)
		add_child(box)
		_boxes.append(box)
		_materials.append(material)
		_doodles.append(StreetArt.add_wall_doodles(box, wall.rect.size.x, WALL_HEIGHT, _boxes.size() - 1))
		_tears.append(StreetArt.add_wall_tears(box, wall.rect.size.x, WALL_HEIGHT))
		var chips: CPUParticles3D = _make_chips(wall.rect.size.x)
		chips.position = box.position + Vector3(0.0, WALL_HEIGHT * 0.6, 0.0)
		add_child(chips)
		_chips.append(chips)
		_hit_left.append(0.0)
	sim.wall_damaged.connect(_on_damaged)
	sim.wall_destroyed.connect(_on_destroyed)
	sim.walls_rebuilt.connect(refresh_all)
	refresh_all()


func standing_count() -> int:
	var count: int = 0
	for box: MeshInstance3D in _boxes:
		if box.visible:
			count += 1
	return count


## Seconds of hit flash left on wall `index` (for tests).
func hit_time_left(index: int) -> float:
	return _hit_left[index]


func refresh_all() -> void:
	for index: int in _boxes.size():
		_hit_left[index] = 0.0
		_refresh(index)


func _on_damaged(index: int) -> void:
	_hit_left[index] = WOBBLE_TIME
	_chips[index].amount = CHIPS_PER_HIT
	_chips[index].restart()
	_refresh(index)


func _on_destroyed(index: int) -> void:
	_chips[index].amount = CHIPS_ON_BREAK
	_chips[index].restart()


func _process(delta: float) -> void:
	for index: int in _hit_left.size():
		if _hit_left[index] <= 0.0:
			continue
		_hit_left[index] = maxf(0.0, _hit_left[index] - delta)
		var t: float = _hit_left[index] / WOBBLE_TIME
		_boxes[index].rotation.z = sin(t * TAU * 2.0) * WOBBLE_ANGLE * t
		_refresh(index)


func _refresh(index: int) -> void:
	var wall: MapLayout.WallSpec = _sim.walls[index]
	_boxes[index].visible = wall.hp > 0
	var health: float = clampf(float(wall.hp) / float(_sim.layout.wall_hp), 0.0, 1.0)
	var tint: Color = BROKEN_COLOR.lerp(FRESH_COLOR, health)
	var since_hit: float = WOBBLE_TIME - _hit_left[index]
	if _hit_left[index] > 0.0 and since_hit < FLASH_TIME:
		tint = FLASH_COLOR
	_materials[index].albedo_color = tint
	_doodles[index].albedo_color = tint
	var torn: float = clampf((TEARS_FROM - health) / TEARS_FROM, 0.0, 1.0)
	_tears[index].albedo_color = Color(1.0, 1.0, 1.0, torn)
	_boxes[index].scale.y = lerpf(BROKEN_SCALE, 1.0, health)


## Brown cardboard chips that burst off a hit wall and tumble to the ground.
func _make_chips(width: float) -> CPUParticles3D:
	var chips: CPUParticles3D = CPUParticles3D.new()
	chips.emitting = false
	chips.one_shot = true
	chips.explosiveness = 0.9
	chips.lifetime = 0.9
	chips.amount = CHIPS_PER_HIT
	chips.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	chips.emission_box_extents = Vector3(width * 0.4, 0.6, 0.15)
	chips.direction = Vector3(0.0, 1.0, 0.0)
	chips.spread = 70.0
	chips.initial_velocity_min = 2.5
	chips.initial_velocity_max = 5.0
	chips.gravity = Vector3(0.0, -14.0, 0.0)
	chips.angular_velocity_min = -360.0
	chips.angular_velocity_max = 360.0
	chips.scale_amount_min = 0.6
	chips.scale_amount_max = 1.3
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.16, 0.12)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = CHIP_COLOR
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = material
	chips.mesh = quad
	return chips
