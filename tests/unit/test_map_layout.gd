extends GutTest

const LAYOUT: MapLayout = preload("res://data/rules/map_layout.tres")
const MAP_SCENE: PackedScene = preload("res://scenes/map/greybox_map.tscn")


func test_layout_matches_gdd_numbers() -> void:
	assert_eq(LAYOUT.lane_length, 60.0)
	assert_eq(LAYOUT.lane_width, 16.0)
	assert_eq(LAYOUT.base_radius, 2.0)
	assert_eq(LAYOUT.wall_layers, 2)
	assert_eq(LAYOUT.wall_columns_per_layer, 3)
	assert_eq(LAYOUT.wall_hp, 300)


func test_wall_column_count() -> void:
	# 2 sides x 2 layers x 3 columns
	assert_eq(LAYOUT.wall_columns().size(), 12)


func test_walls_inside_lane_and_clear_of_each_other() -> void:
	var walls: Array[MapLayout.WallSpec] = LAYOUT.wall_columns()
	var lane: Rect2 = LAYOUT.lane_rect()
	for wall: MapLayout.WallSpec in walls:
		assert_true(lane.encloses(wall.rect), "wall inside the lane")
		assert_eq(wall.hp, 300)
	for i: int in walls.size():
		for j: int in range(i + 1, walls.size()):
			assert_false(walls[i].rect.intersects(walls[j].rect), "walls %d and %d overlap" % [i, j])


func test_map_is_symmetric_between_sides() -> void:
	var own: Array[Rect2] = []
	var enemy: Array[Rect2] = []
	for wall: MapLayout.WallSpec in LAYOUT.wall_columns():
		if wall.side == MapLayout.SIDE_OWN:
			own.append(wall.rect)
		else:
			enemy.append(wall.rect)
	assert_eq(own.size(), enemy.size())
	for rect: Rect2 in own:
		var mirrored: Rect2 = Rect2(rect.position.x, -rect.end.y, rect.size.x, rect.size.y)
		assert_true(enemy.any(func(r: Rect2) -> bool: return r.is_equal_approx(mirrored)))


func test_layer_order_from_base_outward() -> void:
	var base_z: float = LAYOUT.base_center(MapLayout.SIDE_OWN).y
	var layer_z: Array[float] = [0.0, 0.0]
	for wall: MapLayout.WallSpec in LAYOUT.wall_columns():
		if wall.side == MapLayout.SIDE_OWN:
			layer_z[wall.layer] = wall.rect.get_center().y
	assert_gt(base_z, layer_z[0], "layer 1 is in front of the own base")
	assert_gt(layer_z[0], layer_z[1], "layer 2 is further toward mid")
	assert_gt(layer_z[1], 0.0, "own walls stay on the own half")


func test_bases_at_opposite_ends() -> void:
	assert_eq(LAYOUT.base_center(MapLayout.SIDE_OWN).y, 26.0)
	assert_eq(LAYOUT.base_center(MapLayout.SIDE_ENEMY).y, -26.0)


func test_boundary_walls_enclose_lane_without_overlapping_it() -> void:
	var lane: Rect2 = LAYOUT.lane_rect()
	var boundaries: Array[Rect2] = LAYOUT.boundary_rects()
	assert_eq(boundaries.size(), 4)
	for rect: Rect2 in boundaries:
		assert_false(rect.intersects(lane))


func test_greybox_scene_builds_expected_geometry() -> void:
	var map: GreyboxMap = autofree(MAP_SCENE.instantiate()) as GreyboxMap
	add_child(map)
	var geometry: Node3D = map.get_node("%Geometry") as Node3D
	# ground + boundaries + wall columns + (ring + post) per base
	var expected: int = 1 + LAYOUT.boundary_rects().size() + LAYOUT.wall_columns().size() + 4
	assert_eq(geometry.get_child_count(), expected)
