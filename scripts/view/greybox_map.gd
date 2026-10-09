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

@onready var _geometry: Node3D = %Geometry
@onready var _camera: Camera3D = %Camera
@onready var _sun: DirectionalLight3D = %Sun
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	_build_map()
	_setup_camera()
	_sun.rotation_degrees = Vector3(-60.0, 30.0, 0.0)
	_back_button.pressed.connect(_on_back_pressed)


func _build_map() -> void:
	var ground_size: Vector3 = Vector3(layout.lane_width, GROUND_HEIGHT, layout.lane_length)
	_add_box(Vector3(0.0, -GROUND_HEIGHT / 2.0, 0.0), ground_size, GROUND_COLOR)
	for rect: Rect2 in layout.boundary_rects():
		_add_rect(rect, BOUNDARY_HEIGHT, BOUNDARY_COLOR)
	for spec: MapLayout.WallSpec in layout.wall_columns():
		_add_rect(spec.rect, WALL_HEIGHT, WALL_COLOR)
	for side: int in [MapLayout.SIDE_OWN, MapLayout.SIDE_ENEMY]:
		var color: Color = OWN_COLOR if side == MapLayout.SIDE_OWN else ENEMY_COLOR
		var center: Vector2 = layout.base_center(side)
		_add_cylinder(Vector3(center.x, RING_HEIGHT / 2.0, center.y), layout.base_radius, RING_HEIGHT, color)
		_add_cylinder(Vector3(center.x, POST_HEIGHT / 2.0, center.y), POST_RADIUS, POST_HEIGHT, color)


func _setup_camera() -> void:
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.size = layout.overview_size
	_camera.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_camera.position = Vector3(0.0, layout.overview_height, 0.0)
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = BACKGROUND_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.5
	_camera.environment = env


func _add_rect(rect: Rect2, height: float, color: Color) -> void:
	var center: Vector2 = rect.get_center()
	_add_box(Vector3(center.x, height / 2.0, center.y), Vector3(rect.size.x, height, rect.size.y), color)


func _add_box(center: Vector3, size: Vector3, color: Color) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	_add_mesh(mesh, center, color)


func _add_cylinder(center: Vector3, radius: float, height: float, color: Color) -> void:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	_add_mesh(mesh, center, color)


func _add_mesh(mesh: PrimitiveMesh, center: Vector3, color: Color) -> void:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material = material
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = center
	_geometry.add_child(instance)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")
