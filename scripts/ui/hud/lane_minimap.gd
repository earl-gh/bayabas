class_name LaneMinimap
extends Control
## Square minimap in the top left corner (docs/GDD.md "HUD"): the lane runs
## slanted from your base (bottom left) to the enemy base (top right), with the
## standing walls, both bases, players as dots (you are white-ringed), the ball
## and the tricycle when they are out.

const PANEL: Color = Color(0.1, 0.08, 0.14, 0.75)
const ROAD: Color = Color(0.36, 0.37, 0.42, 0.9)
const WALL: Color = Color(0.86, 0.66, 0.4)
const OWN: Color = Color(0.3, 0.6, 1.0)
const ENEMY: Color = Color(1.0, 0.35, 0.35)
const BALL: Color = Color(0.62, 0.86, 0.3)
## Gold frame, like the skill buttons.
const FRAME: Color = Color(1.0, 0.8, 0.32)
const SIDEWALK_COLOR: Color = Color(0.62, 0.58, 0.5, 0.9)
## Sidewalk drawn on both sides of the lane, in metres.
const SIDEWALK: float = 2.0
## Walls are thin on the map; grow them a little so they read.
const WALL_GROW: float = 0.4
## How much of the square's diagonal the lane uses.
const LANE_FILL: float = 0.86
const SQRT_TWO: float = 1.41421356
## Screen directions of the slanted lane: toward the enemy (up right) and its right side.
const UP_RIGHT: Vector2 = Vector2(0.70710678, -0.70710678)
const RIGHT_OF_LANE: Vector2 = Vector2(0.70710678, 0.70710678)

var _sim: MatchSim
var _local_id: int = -1
var _local_team: int = 0


func setup(sim: MatchSim, local_id: int, local_team: int) -> void:
	_sim = sim
	_local_id = local_id
	_local_team = local_team
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Lane x/z to minimap pixels. The square map shows the lane slanted from your
## base at the bottom left to the enemy base at the top right.
func to_map(world: Vector2) -> Vector2:
	var layout: MapLayout = _sim.layout
	var own_side: int = _sim.side_for_team(_local_team)
	var across: float = world.x / layout.lane_width
	var along: float = world.y * own_side / layout.lane_length
	if own_side < 0:
		across = -across
	var inner: Rect2 = _inner()
	var length: float = inner.size.x * SQRT_TWO * LANE_FILL
	var width: float = length * layout.lane_width / layout.lane_length
	return inner.get_center() - UP_RIGHT * along * length + RIGHT_OF_LANE * across * width


func _inner() -> Rect2:
	return Rect2(Vector2(9.0, 9.0), size - Vector2(18.0, 18.0))


func _draw() -> void:
	if _sim == null:
		return
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = PANEL
	box.set_corner_radius_all(16)
	box.border_color = FRAME
	box.set_border_width_all(4)
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	box.shadow_size = 4
	box.shadow_offset = Vector2(0, 3)
	draw_style_box(box, Rect2(Vector2.ZERO, size))
	var layout: MapLayout = _sim.layout
	var half: Vector2 = Vector2(layout.lane_width, layout.lane_length) / 2.0
	# sidewalks, then the lane on top
	_draw_quad(Rect2(-half - Vector2(SIDEWALK, 0.0), (half + Vector2(SIDEWALK, 0.0)) * 2.0), SIDEWALK_COLOR)
	_draw_quad(Rect2(-half, half * 2.0), ROAD)
	for wall: MapLayout.WallSpec in _sim.walls:
		if wall.hp > 0:
			_draw_quad(wall.rect.grow(WALL_GROW), WALL)
	for side: int in [MapLayout.SIDE_OWN, MapLayout.SIDE_ENEMY]:
		var mine: bool = side == _sim.side_for_team(_local_team)
		draw_circle(to_map(_sim.layout.base_center(side)), 6.0, OWN if mine else ENEMY)
	if _sim.tricycle.phase == Tricycle.Phase.CROSSING:
		draw_rect(Rect2(to_map(_sim.tricycle.position) - Vector2(5, 3), Vector2(10, 6)), Color(1.0, 0.85, 0.2))
	if _sim.ball.state != RubberBall.State.NONE:
		draw_circle(to_map(_sim.ball.position), 3.5, BALL)
	for id: int in _sim.players:
		var state: PlayerState = _sim.players[id]
		if not state.alive:
			continue
		var at: Vector2 = to_map(state.position)
		if id == _local_id:
			draw_circle(at, 6.0, Color.WHITE)
		draw_circle(at, 4.0, OWN if state.team == _local_team else ENEMY)


## A world rectangle (x, z) drawn as the slanted quad it becomes on the map.
func _draw_quad(rect: Rect2, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		to_map(rect.position), to_map(Vector2(rect.end.x, rect.position.y)),
		to_map(rect.end), to_map(Vector2(rect.position.x, rect.end.y)),
	]), color)
