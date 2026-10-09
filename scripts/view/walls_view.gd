class_name WallsView
extends Node3D
## The breakable cardboard wall columns, drawn from MatchSim.walls: darker as they
## take damage, gone at 0 HP, back when the walls are rebuilt for a new set.

const WALL_HEIGHT: float = 2.0
const FRESH_COLOR: Color = Color(0.82, 0.64, 0.38)
const BROKEN_COLOR: Color = Color(0.4, 0.28, 0.16)

var _sim: MatchSim
var _boxes: Array[MeshInstance3D] = []
var _materials: Array[StandardMaterial3D] = []


func watch(sim: MatchSim) -> void:
	_sim = sim
	for child: Node in get_children():
		child.queue_free()
	_boxes.clear()
	_materials.clear()
	for wall: MapLayout.WallSpec in sim.walls:
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = Vector3(wall.rect.size.x, WALL_HEIGHT, wall.rect.size.y)
		var material: StandardMaterial3D = StandardMaterial3D.new()
		mesh.material = material
		var box: MeshInstance3D = MeshInstance3D.new()
		box.mesh = mesh
		var center: Vector2 = wall.rect.get_center()
		box.position = Vector3(center.x, WALL_HEIGHT / 2.0, center.y)
		add_child(box)
		_boxes.append(box)
		_materials.append(material)
	sim.wall_damaged.connect(_refresh)
	sim.walls_rebuilt.connect(refresh_all)
	refresh_all()


func standing_count() -> int:
	var count: int = 0
	for box: MeshInstance3D in _boxes:
		if box.visible:
			count += 1
	return count


func refresh_all() -> void:
	for index: int in _boxes.size():
		_refresh(index)


func _refresh(index: int) -> void:
	var wall: MapLayout.WallSpec = _sim.walls[index]
	_boxes[index].visible = wall.hp > 0
	var health: float = clampf(float(wall.hp) / float(_sim.layout.wall_hp), 0.0, 1.0)
	_materials[index].albedo_color = BROKEN_COLOR.lerp(FRESH_COLOR, health)
