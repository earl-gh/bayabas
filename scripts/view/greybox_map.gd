class_name GreyboxMap
extends Node3D
## Placeholder greybox view of the lane (boxes only). Reads MapLayout; holds no
## game rules. Uses a fixed top-down overview camera until the follow camera
## lands (M1 task 4).

const GROUND_COLOR: Color = Color(0.45, 0.47, 0.5)
const OWN_COLOR: Color = Color(0.25, 0.5, 0.95)
const ENEMY_COLOR: Color = Color(0.9, 0.3, 0.3)
const WALL_COLOR: Color = Color(0.75, 0.6, 0.38)
const BOUNDARY_COLOR: Color = Color(0.2, 0.2, 0.25)
const BACKGROUND_COLOR: Color = Color(0.12, 0.13, 0.17)
const WALL_HEIGHT: float = 2.0
const BOUNDARY_HEIGHT: float = 2.5
const POST_HEIGHT: float = 3.0
const POST_RADIUS: float = 0.5
const RING_HEIGHT: float = 0.06
const GROUND_HEIGHT: float = 0.1

@export var layout: MapLayout
## Off when a match scene supplies its own (follow) camera.
@export var show_overview_camera: bool = true
## Off when a match draws the breakable walls from its sim (WallsView).
@export var build_walls: bool = true

var _base_materials: Dictionary[int, Array] = {}

@onready var _geometry: Node3D = %Geometry
@onready var _camera: Camera3D = %Camera
@onready var _sun: DirectionalLight3D = %Sun
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	_build_map()
	if show_overview_camera:
		_setup_camera()
	_sun.rotation_degrees = Vector3(-60.0, 30.0, 0.0)
	_back_button.pressed.connect(_on_back_pressed)


func _build_map() -> void:
	var ground_size: Vector3 = Vector3(layout.lane_width, GROUND_HEIGHT, layout.lane_length)
	_add_box(Vector3(0.0, -GROUND_HEIGHT / 2.0, 0.0), ground_size, GROUND_COLOR)
	for rect: Rect2 in layout.boundary_rects():
		_add_rect(rect, BOUNDARY_HEIGHT, BOUNDARY_COLOR)
	if build_walls:
		for spec: MapLayout.WallSpec in layout.wall_columns():
			_add_rect(spec.rect, WALL_HEIGHT, WALL_COLOR)
	for side: int in [MapLayout.SIDE_OWN, MapLayout.SIDE_ENEMY]:
		var color: Color = OWN_COLOR if side == MapLayout.SIDE_OWN else ENEMY_COLOR
		var center: Vector2 = layout.base_center(side)
		_base_materials[side] = [
			_add_cylinder(Vector3(center.x, RING_HEIGHT / 2.0, center.y), layout.base_radius, RING_HEIGHT, color),
			_add_cylinder(Vector3(center.x, POST_HEIGHT / 2.0, center.y), POST_RADIUS, POST_HEIGHT, color),
		]


## Colors the bases for the viewer: `own_side` is blue, the other red (teams
## switch bases every set).
func set_own_side(own_side: int) -> void:
	for side: int in _base_materials:
		for material: StandardMaterial3D in _base_materials[side]:
			material.albedo_color = OWN_COLOR if side == own_side else ENEMY_COLOR


func base_color(side: int) -> Color:
	var materials: Array = _base_materials[side]
	return (materials[0] as StandardMaterial3D).albedo_color


func _setup_camera() -> void:
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.size = layout.overview_size
	_camera.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_camera.position = Vector3(0.0, layout.overview_height, 0.0)
	_camera.environment = make_environment()


## Shared flat background + ambient light for every camera that views the map.
static func make_environment() -> Environment:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = BACKGROUND_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.5
	return env


func _add_rect(rect: Rect2, height: float, color: Color) -> void:
	var center: Vector2 = rect.get_center()
	_add_box(Vector3(center.x, height / 2.0, center.y), Vector3(rect.size.x, height, rect.size.y), color)


func _add_box(center: Vector3, size: Vector3, color: Color) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	_add_mesh(mesh, center, color)


func _add_cylinder(center: Vector3, radius: float, height: float, color: Color) -> StandardMaterial3D:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	return _add_mesh(mesh, center, color)


func _add_mesh(mesh: PrimitiveMesh, center: Vector3, color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material = material
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = center
	_geometry.add_child(instance)
	return material


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")
