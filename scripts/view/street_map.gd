class_name StreetMap
extends Node3D
## The Filipino street the lane runs down (view only; reads MapLayout, holds no
## rules). Asphalt with lane paint and a cross street at the midline (the
## tricycle's path), sidewalks and house fronts behind the boundary curbs, a
## sari-sari store, laundry lines, a basketball ring, a parked jeepney, and an
## electric post covered in flyers on each base.

const OWN_COLOR: Color = Palette.TEAM_OWN
const ENEMY_COLOR: Color = Palette.TEAM_ENEMY
const SKY_COLOR: Color = Color(0.56, 0.8, 0.98)
const RING_HEIGHT: float = 0.03
const CURB_HEIGHT: float = 0.35
const CROSS_STREET_WIDTH: float = 6.0
const SIDEWALK_WIDTH: float = 2.4
const HOUSE_SPACING: float = 6.5
const END_WALL_HEIGHT: float = 2.4
const DASH_LENGTH: float = 2.0
const DASH_GAP: float = 2.0

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
	_sun.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
	_sun.light_color = Color(1.0, 0.95, 0.85)
	_sun.light_energy = 1.1
	_back_button.pressed.connect(_on_back_pressed)


## Shared warm daylight sky + ambient for every camera that views the map.
static func make_environment() -> Environment:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = SKY_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.95, 0.88)
	env.ambient_light_energy = 0.65
	return env


## Colors the bases for the viewer: `own_side` is blue, the other red (teams
## switch bases every set).
func set_own_side(own_side: int) -> void:
	for side: int in _base_materials:
		for material: StandardMaterial3D in _base_materials[side]:
			material.albedo_color = OWN_COLOR if side == own_side else ENEMY_COLOR


func base_color(side: int) -> Color:
	var materials: Array = _base_materials[side]
	return (materials[0] as StandardMaterial3D).albedo_color


func _build_map() -> void:
	var half_w: float = layout.lane_width / 2.0
	var half_l: float = layout.lane_length / 2.0
	_add(_road(), Vector3.ZERO)
	_add(_sides(), Vector3.ZERO)
	if build_walls:
		for spec: MapLayout.WallSpec in layout.wall_columns():
			var center: Vector2 = spec.rect.get_center()
			_add(Props.cardboard_wall(Vector3(spec.rect.size.x, 2.0, spec.rect.size.y)), Vector3(center.x, 0.0, center.y))
	for side: int in [MapLayout.SIDE_OWN, MapLayout.SIDE_ENEMY]:
		var center: Vector2 = layout.base_center(side)
		var color: Color = OWN_COLOR if side == MapLayout.SIDE_OWN else ENEMY_COLOR
		var ring: StandardMaterial3D = _add_disc(Vector3(center.x, RING_HEIGHT / 2.0, center.y), layout.base_radius, color)
		var post: MeshInstance3D = _add(Props.electric_post(), Vector3(center.x, 0.0, center.y))
		# a team-coloured band on the post so you can tell bases apart from afar
		var band: StandardMaterial3D = _add_band(post, color)
		_base_materials[side] = [ring, band]
	# street dressing outside the lane
	var store_z: float = -half_l * 0.45
	_add(Props.sari_sari(), Vector3(-half_w - SIDEWALK_WIDTH - 1.8, 0.0, store_z))
	_add(Props.basketball_ring(), Vector3(half_w + 0.9, 0.0, half_l * 0.35), PI)
	_add(Props.jeepney(), Vector3(half_w + CROSS_STREET_WIDTH * 0.25 + 1.2, 0.0, -CROSS_STREET_WIDTH * 1.2))
	_add(Props.stop_sign(), Vector3(-half_w - 0.8, 0.0, CROSS_STREET_WIDTH * 0.7))
	for z: float in [-half_l * 0.7, half_l * 0.15, half_l * 0.6]:
		_add(Props.laundry_line(4.0), Vector3(-half_w - 1.2, 0.0, z))
	for z: float in [-half_l * 0.2, half_l * 0.75]:
		_add(Props.laundry_line(3.0), Vector3(half_w + 1.2, 0.0, z))
	for z: float in [-half_l * 0.85, -4.5, 4.5, half_l * 0.5]:
		_add(Props.potted_plant(), Vector3(half_w + 0.75, 0.0, z))
		_add(Props.potted_plant(), Vector3(-half_w - 0.75, 0.0, -z))


## Asphalt lane + cross street, lane paint, crosswalks.
func _road() -> ArrayMesh:
	var kit: LowPoly = LowPoly.new()
	var half_w: float = layout.lane_width / 2.0
	var half_l: float = layout.lane_length / 2.0
	kit.box(Vector3(0.0, -0.05, 0.0), Vector3(layout.lane_width, 0.1, layout.lane_length), Palette.ASPHALT)
	var reach: float = half_w + SIDEWALK_WIDTH + 12.0
	kit.box(Vector3(0.0, -0.06, 0.0), Vector3(reach * 2.0, 0.1, CROSS_STREET_WIDTH), Palette.ASPHALT_DARK)
	# dashed centre line along the lane, skipping the crossing
	var z: float = -half_l + 1.0
	while z < half_l - 1.0:
		if absf(z + DASH_LENGTH / 2.0) > CROSS_STREET_WIDTH / 2.0 + 1.0:
			kit.box(Vector3(0.0, 0.005, z + DASH_LENGTH / 2.0), Vector3(0.18, 0.02, DASH_LENGTH), Palette.LANE_PAINT)
		z += DASH_LENGTH + DASH_GAP
	# side lines
	for x: float in [-half_w + 0.35, half_w - 0.35]:
		kit.box(Vector3(x, 0.004, 0.0), Vector3(0.12, 0.02, layout.lane_length - 2.0), Palette.WHITE)
	# zebra crossings on both sides of the cross street
	for side: float in [-1.0, 1.0]:
		var stripes: int = int(layout.lane_width / 1.2)
		for i: int in stripes:
			var x: float = -half_w + 0.6 + float(i) * 1.2
			kit.box(Vector3(x, 0.006, side * (CROSS_STREET_WIDTH / 2.0 + 0.9)), Vector3(0.6, 0.02, 1.4), Palette.WHITE)
	return kit.commit()


## Curbs on the boundaries, sidewalks, house fronts on both sides, end walls.
func _sides() -> ArrayMesh:
	var kit: LowPoly = LowPoly.new()
	var half_w: float = layout.lane_width / 2.0
	var half_l: float = layout.lane_length / 2.0
	var t: float = layout.boundary_thickness
	for side: float in [-1.0, 1.0]:
		for segment: float in [-1.0, 1.0]:
			# curb + sidewalk, interrupted by the cross street
			var length: float = half_l - CROSS_STREET_WIDTH / 2.0
			var center_z: float = segment * (CROSS_STREET_WIDTH / 2.0 + length / 2.0)
			kit.box(Vector3(side * (half_w + t / 2.0), CURB_HEIGHT / 2.0, center_z), Vector3(t, CURB_HEIGHT, length), Palette.CURB, Palette.CURB)
			kit.box(Vector3(side * (half_w + t + SIDEWALK_WIDTH / 2.0), 0.1, center_z), Vector3(SIDEWALK_WIDTH, 0.2, length), Palette.SIDEWALK)
		# low fence pieces along the crossing so the lane edge still reads
		for z: float in [-CROSS_STREET_WIDTH / 2.0 + 0.3, CROSS_STREET_WIDTH / 2.0 - 0.3]:
			kit.box(Vector3(side * (half_w + t / 2.0), 0.5, z), Vector3(t, 1.0, 0.3), Palette.SARI_YELLOW)
		kit.box(Vector3(side * (half_w + t / 2.0), CURB_HEIGHT / 2.0, 0.0), Vector3(t, CURB_HEIGHT, CROSS_STREET_WIDTH), Palette.SARI_YELLOW.darkened(0.2))
	for end: float in [-1.0, 1.0]:
		kit.box(Vector3(0.0, END_WALL_HEIGHT / 2.0, end * (half_l + t / 2.0)), Vector3(layout.lane_width + 2.0 * t, END_WALL_HEIGHT, t), Palette.WALL_PEACH, Palette.ROOF_RUST)
	var mesh: ArrayMesh = kit.commit()
	_add_houses()
	return mesh


func _add_houses() -> void:
	var half_w: float = layout.lane_width / 2.0
	var half_l: float = layout.lane_length / 2.0
	var x_offset: float = half_w + layout.boundary_thickness + SIDEWALK_WIDTH + 2.0
	var variant: int = 0
	for side: float in [-1.0, 1.0]:
		var z: float = -half_l + HOUSE_SPACING / 2.0
		while z < half_l:
			var near_cross: bool = absf(z) < CROSS_STREET_WIDTH / 2.0 + 2.6
			var near_store: bool = side < 0.0 and absf(z - (-half_l * 0.45)) < 3.0
			if not near_cross and not near_store:
				_add(Props.house(variant), Vector3(side * x_offset, 0.0, z), 0.0 if side < 0.0 else PI)
			variant += 1
			z += HOUSE_SPACING


func _add(mesh: Mesh, at: Vector3, yaw: float = 0.0) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	instance.rotation.y = yaw
	_geometry.add_child(instance)
	return instance


func _add_disc(center: Vector3, radius: float, color: Color) -> StandardMaterial3D:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = RING_HEIGHT
	mesh.radial_segments = 20
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material = material
	_add(mesh, center)
	return material


func _add_band(post: MeshInstance3D, color: Color) -> StandardMaterial3D:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 0.27
	mesh.bottom_radius = 0.28
	mesh.height = 0.35
	mesh.radial_segments = 8
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material = material
	var band: MeshInstance3D = MeshInstance3D.new()
	band.mesh = mesh
	band.position.y = 3.2
	post.add_child(band)
	return material


func _setup_camera() -> void:
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.size = layout.overview_size
	_camera.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_camera.position = Vector3(0.0, layout.overview_height, 0.0)
	_camera.environment = make_environment()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")
