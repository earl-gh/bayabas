class_name MapLayout
extends Resource
## Geometry of the single-lane map, in meters. Pure data + math, no nodes.
## Lane axis is Z: +Z is the "own" side (bottom of the portrait screen), -Z the
## enemy side. All numbers come from data/rules/map_layout.tres.

const SIDE_OWN: int = 1
const SIDE_ENEMY: int = -1

@export var lane_length: float = 0.0
@export var lane_width: float = 0.0
@export var base_inset: float = 0.0
@export var base_radius: float = 0.0
@export var wall_layers: int = 0
@export var wall_columns_per_layer: int = 0
@export var wall_first_layer_from_base: float = 0.0
@export var wall_layer_spacing: float = 0.0
@export var wall_thickness: float = 0.0
@export var wall_gap: float = 0.0
@export var wall_hp: int = 0
@export var boundary_thickness: float = 0.0
@export var overview_height: float = 0.0
@export var overview_size: float = 0.0


## One breakable cardboard wall column. `rect` is in the XZ plane (x, z).
class WallSpec extends RefCounted:
	var rect: Rect2
	var side: int
	var layer: int
	var column: int
	var hp: int


## Center of a side's base post in the XZ plane (x, z).
func base_center(side: int) -> Vector2:
	return Vector2(0.0, side * (lane_length / 2.0 - base_inset))


## Z of the inner wall row (the one a side's electric post stands in), measured at its center.
func inner_wall_z(side: int) -> float:
	return side * (lane_length / 2.0 - base_inset - wall_first_layer_from_base)


## Z of the back face of a side's inner wall: a player past this line (toward that
## side's lane end) is behind the wall, in that side's yard.
func yard_line(side: int) -> float:
	return inner_wall_z(side) + side * wall_thickness / 2.0


## True when `position` is behind `side`'s inner wall, in its yard (the enemy scores there).
func in_yard(side: int, position: Vector2) -> bool:
	return position.y * side >= absf(yard_line(side)) and absf(position.x) <= lane_width / 2.0


## Where a side's players start and respawn: the middle of the yard behind the inner wall.
func spawn_center(side: int) -> Vector2:
	return Vector2(0.0, side * (absf(yard_line(side)) + lane_length / 2.0) / 2.0)


func lane_rect() -> Rect2:
	return Rect2(-lane_width / 2.0, -lane_length / 2.0, lane_width, lane_length)


## 2 sides x wall_layers x wall_columns_per_layer columns. Layer 0 is nearest the base.
func wall_columns() -> Array[WallSpec]:
	var result: Array[WallSpec] = []
	var column_width: float = lane_width / wall_columns_per_layer
	for side: int in [SIDE_OWN, SIDE_ENEMY]:
		for layer: int in wall_layers:
			var z_center: float = side * (
				lane_length / 2.0 - base_inset - wall_first_layer_from_base - layer * wall_layer_spacing
			)
			for column: int in wall_columns_per_layer:
				var width: float = column_width - wall_gap
				var x_center: float = -lane_width / 2.0 + column_width * (column + 0.5)
				var spec: WallSpec = WallSpec.new()
				spec.rect = Rect2(x_center - width / 2.0, z_center - wall_thickness / 2.0, width, wall_thickness)
				spec.side = side
				spec.layer = layer
				spec.column = column
				spec.hp = wall_hp
				result.append(spec)
	return result


## Left, right and the two end walls enclosing the lane.
func boundary_rects() -> Array[Rect2]:
	var t: float = boundary_thickness
	var result: Array[Rect2] = []
	result.append(Rect2(-lane_width / 2.0 - t, -lane_length / 2.0, t, lane_length))
	result.append(Rect2(lane_width / 2.0, -lane_length / 2.0, t, lane_length))
	result.append(Rect2(-lane_width / 2.0 - t, -lane_length / 2.0 - t, lane_width + 2.0 * t, t))
	result.append(Rect2(-lane_width / 2.0 - t, lane_length / 2.0, lane_width + 2.0 * t, t))
	return result
