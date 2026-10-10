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
const SHADOW_DISTANCE: float = 75.0
const BUNTING_HEIGHT: float = 6.4
const POLE_SPACING: float = 11.0
## Painted ground sits just above the coloured road and sidewalk boxes.
const GROUND_LIFT: float = 0.004
const GROUND_TILE: float = 8.0
const PAVER_TILE: float = 2.4
const SIDEWALK_TOP: float = 0.2
const CROSS_STREET_TINT: Color = Color(0.82, 0.82, 0.86)
## Paving around the whole map, so the street never ends in sky.
const OUTER_MARGIN: float = 40.0
const OUTER_DROP: float = -0.12
const OUTER_TINT: Color = Color(0.62, 0.58, 0.54)
const DECAL_LIFT: float = 0.009
const CHALK_PIKO_SIZE: Vector2 = Vector2(2.2, 4.4)
const CHALK_PRESO_SIZE: Vector2 = Vector2(4.2, 2.8)
const ROAD_TEXT_SIZE: Vector2 = Vector2(7.0, 1.75)
const ROAD_TEXT_GAP: float = 3.2
const POSTER_HEIGHT: float = 1.1
const SARI_SIGN_HEIGHT: float = 1.15

@export var layout: MapLayout
## Off when a match scene supplies its own (follow) camera.
@export var show_overview_camera: bool = true
## Off when a match draws the breakable walls from its sim (WallsView).
@export var build_walls: bool = true

var _base_materials: Dictionary[int, Array] = {}
## Road paint and chalk, turned to read the right way up for the viewer's side.
var _readable: Array[MeshInstance3D] = []

@onready var _geometry: Node3D = %Geometry
@onready var _camera: Camera3D = %Camera
@onready var _sun: DirectionalLight3D = %Sun
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	_build_map()
	if show_overview_camera:
		_setup_camera()
	_sun.rotation_degrees = Vector3(-58.0, 32.0, 0.0)
	_sun.light_color = Color(1.0, 0.94, 0.82)
	_sun.light_energy = 0.95
	# real shadows give the toy-town depth; one cheap orthogonal map
	_sun.shadow_enabled = true
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_sun.directional_shadow_max_distance = SHADOW_DISTANCE
	_sun.shadow_opacity = 0.42
	_sun.shadow_blur = 3.0
	_back_button.pressed.connect(_on_back_pressed)


## Shared warm daylight sky + ambient for every camera that views the map.
static func make_environment() -> Environment:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = SKY_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.95, 0.88)
	env.ambient_light_energy = 0.45
	# punchy, saturated toy-town colours
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.22
	env.adjustment_contrast = 1.08
	# light haze into the distance: the far end of the street softens into the sky
	env.fog_enabled = true
	env.fog_light_color = SKY_COLOR.lightened(0.15)
	env.fog_density = 0.001
	env.fog_sky_affect = 0.0
	return env


## Colors the bases for the viewer: `own_side` is blue, the other red (teams
## switch bases every set).
func set_own_side(own_side: int) -> void:
	for side: int in _base_materials:
		for material: StandardMaterial3D in _base_materials[side]:
			material.albedo_color = OWN_COLOR if side == own_side else ENEMY_COLOR
	for decal: MeshInstance3D in _readable:
		decal.rotation.y = 0.0 if own_side == MapLayout.SIDE_OWN else PI


func base_color(side: int) -> Color:
	var materials: Array = _base_materials[side]
	return (materials[0] as StandardMaterial3D).albedo_color


func _build_map() -> void:
	var half_w: float = layout.lane_width / 2.0
	var half_l: float = layout.lane_length / 2.0
	_add(_road(), Vector3.ZERO)
	_add(_sides(), Vector3.ZERO)
	_add_ground_textures()
	if build_walls:
		var variant: int = 0
		for spec: MapLayout.WallSpec in layout.wall_columns():
			var center: Vector2 = spec.rect.get_center()
			var wall: MeshInstance3D = _add(Props.cardboard_wall(Vector3(spec.rect.size.x, 2.0, spec.rect.size.y)), Vector3(center.x, 0.0, center.y))
			StreetArt.add_wall_doodles(wall, spec.rect.size.x, 2.0, variant)
			variant += 1
	for side: int in [MapLayout.SIDE_OWN, MapLayout.SIDE_ENEMY]:
		var center: Vector2 = layout.base_center(side)
		var color: Color = OWN_COLOR if side == MapLayout.SIDE_OWN else ENEMY_COLOR
		_add(Props.base_pad(layout.base_radius), Vector3(center.x, 0.0, center.y))
		var ring: StandardMaterial3D = _add_disc(Vector3(center.x, RING_HEIGHT / 2.0, center.y), layout.base_radius, color)
		var post: MeshInstance3D = _add(Props.electric_post(), Vector3(center.x, 0.0, center.y))
		# a team-coloured band on the post so you can tell bases apart from afar
		var band: StandardMaterial3D = _add_band(post, color)
		_base_materials[side] = [ring, band]
		_add_sign("poster_0" if side == MapLayout.SIDE_OWN else "poster_1", POSTER_HEIGHT, Vector3(center.x + 0.45, 1.3, center.y))
	# street dressing outside the lane
	var store_z: float = -half_l * 0.45
	_add(Props.sari_sari(), Vector3(-half_w - SIDEWALK_WIDTH - 1.8, 0.0, store_z))
	_add_sign("sari_sign", SARI_SIGN_HEIGHT, Vector3(-half_w - SIDEWALK_WIDTH - 0.6, 3.3, store_z))
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
	_add_details()


## Life on the street: bunting overhead, power lines, chalk piko, manholes,
## puddles, the tambayan bench, drums, trees and tarpaulins.
func _add_details() -> void:
	var half_w: float = layout.lane_width / 2.0
	var half_l: float = layout.lane_length / 2.0
	var span: float = layout.lane_width + 2.0 * (layout.boundary_thickness + SIDEWALK_WIDTH)
	var bunting_index: int = 0
	for z: float in [-half_l * 0.62, half_l * 0.62]:
		_add(Props.banderitas(span, bunting_index), Vector3(0.0, BUNTING_HEIGHT, z))
		bunting_index += 1
	# power poles along the right sidewalk with wires between them
	var pole_x: float = half_w + layout.boundary_thickness + SIDEWALK_WIDTH - 0.4
	var previous: Vector3 = Vector3.ZERO
	var z: float = -half_l + 2.0
	var first: bool = true
	var poster: int = 0
	while z <= half_l - 1.0:
		if absf(z) > CROSS_STREET_WIDTH / 2.0 + 0.5:
			_add(Props.power_pole(), Vector3(pole_x, 0.0, z))
			_add_sign("poster_%d" % (poster % 3), POSTER_HEIGHT, Vector3(pole_x - 0.3, 1.4, z))
			poster += 1
			var top: Vector3 = Vector3(pole_x, 6.65, z)
			if not first:
				for dz: float in [-0.6, 0.6]:
					_add(Props.wire(previous + Vector3(0.0, 0.0, dz), top + Vector3(0.0, 0.0, dz)), Vector3.ZERO)
			previous = top
			first = false
		z += POLE_SPACING
	# kids' chalk on the road: piko and tumbang preso marks near both bases,
	# and the barangay's DAHAN-DAHAN (slow down) before the crossing
	for side: float in [1.0, -1.0]:
		_add_decal("chalk_piko", CHALK_PIKO_SIZE, Vector3(-side * (half_w - 2.0), 0.0, side * (half_l - 8.0)))
		_add_decal("chalk_preso", CHALK_PRESO_SIZE, Vector3(side * (half_w - 4.2), 0.0, side * (half_l - 11.5)))
		_add_decal("road_dahan", ROAD_TEXT_SIZE, Vector3(0.0, 0.0, side * (CROSS_STREET_WIDTH / 2.0 + ROAD_TEXT_GAP)))
	for spot: Vector3 in [Vector3(3.5, 0.0, 6.0), Vector3(-4.0, 0.0, -9.5), Vector3(1.5, 0.0, -20.0)]:
		_add(Props.manhole(), spot)
	# tambayan in front of the sari-sari store, drums, trees behind the houses
	var store_z: float = -half_l * 0.45
	_add(Props.bench(), Vector3(-half_w - layout.boundary_thickness - 0.9, 0.0, store_z))
	for spot: Vector3 in [Vector3(half_w + 2.0, 0.0, 9.0), Vector3(-half_w - 2.2, 0.0, 16.0), Vector3(half_w + 2.2, 0.0, -24.0)]:
		_add(Props.drum(), spot)
	var tree_x: float = half_w + layout.boundary_thickness + SIDEWALK_WIDTH + 6.5
	for tz: float in [-24.0, -10.0, 12.0, 25.0]:
		_add(Props.mango_tree(), Vector3(-tree_x - 1.0, 0.0, tz))
		_add(Props.banana_plant(), Vector3(tree_x, 0.0, tz + 4.0))


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


## Painted asphalt over the lane and the cross street, pavers on the sidewalks.
func _add_ground_textures() -> void:
	var half_w: float = layout.lane_width / 2.0
	var half_l: float = layout.lane_length / 2.0
	var lane: MeshInstance3D = StreetArt.ground("asphalt", Vector2(layout.lane_width, layout.lane_length), GROUND_TILE)
	lane.position = Vector3(0.0, GROUND_LIFT, 0.0)
	_geometry.add_child(lane)
	var reach: float = half_w + SIDEWALK_WIDTH + 12.0
	var cross: MeshInstance3D = StreetArt.ground("asphalt", Vector2(reach * 2.0, CROSS_STREET_WIDTH), GROUND_TILE, CROSS_STREET_TINT)
	cross.position = Vector3(0.0, GROUND_LIFT * 0.5, 0.0)
	_geometry.add_child(cross)
	# the neighbourhood goes on past the lane: paving all around, no sky below the horizon
	var yard: MeshInstance3D = StreetArt.ground("pavers", Vector2(reach * 2.0 + OUTER_MARGIN, layout.lane_length + OUTER_MARGIN * 2.0), PAVER_TILE, OUTER_TINT)
	yard.position = Vector3(0.0, OUTER_DROP, 0.0)
	_geometry.add_child(yard)
	var length: float = half_l - CROSS_STREET_WIDTH / 2.0
	for side: float in [-1.0, 1.0]:
		for segment: float in [-1.0, 1.0]:
			var walk: MeshInstance3D = StreetArt.ground("pavers", Vector2(SIDEWALK_WIDTH, length), PAVER_TILE)
			walk.position = Vector3(side * (half_w + layout.boundary_thickness + SIDEWALK_WIDTH / 2.0), SIDEWALK_TOP + GROUND_LIFT, segment * (CROSS_STREET_WIDTH / 2.0 + length / 2.0))
			_geometry.add_child(walk)


func _add_decal(texture_name: String, size: Vector2, at: Vector3) -> void:
	var decal: MeshInstance3D = StreetArt.decal(texture_name, size)
	decal.position = at + Vector3(0.0, DECAL_LIFT, 0.0)
	_geometry.add_child(decal)
	_readable.append(decal)


func _add_sign(texture_name: String, height: float, at: Vector3) -> void:
	var sign: Sprite3D = StreetArt.billboard(texture_name, height)
	sign.position = at
	_geometry.add_child(sign)


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
				var yaw: float = 0.0 if side < 0.0 else PI
				var mesh: ArrayMesh = Props.house_tall(variant) if variant % 3 == 1 else Props.house(variant)
				_add(mesh, Vector3(side * x_offset, 0.0, z), yaw)
				if variant % 4 == 2:
					var front: float = side * (x_offset - 2.1)
					_add(Props.tarpaulin(variant), Vector3(front, 2.6, z + 1.4), yaw)
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


## The map's own Exit button (map preview); a match uses its settings menu instead.
func show_back_button(visible_now: bool) -> void:
	_back_button.visible = visible_now


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")
