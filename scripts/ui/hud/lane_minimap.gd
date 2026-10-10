class_name LaneMinimap
extends Control
## Slim vertical minimap of the lane on the left edge (docs/GDD.md "Vertical
## layout"): your base at the bottom, standing walls, both bases, players as
## dots (you are white-ringed), the ball and the tricycle when they are out.

const PANEL: Color = Color(0.1, 0.08, 0.14, 0.75)
const ROAD: Color = Color(0.36, 0.37, 0.42, 0.9)
const WALL: Color = Color(0.86, 0.66, 0.4)
const OWN: Color = Color(0.3, 0.6, 1.0)
const ENEMY: Color = Color(1.0, 0.35, 0.35)
const BALL: Color = Color(0.62, 0.86, 0.3)
## Gold frame, like the skill buttons.
const FRAME: Color = Color(1.0, 0.8, 0.32)

var _sim: MatchSim
var _local_id: int = -1
var _local_team: int = 0


func setup(sim: MatchSim, local_id: int, local_team: int) -> void:
	_sim = sim
	_local_id = local_id
	_local_team = local_team
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Lane x/z to minimap pixels; your base is always at the bottom.
func to_map(world: Vector2) -> Vector2:
	var layout: MapLayout = _sim.layout
	var own_side: int = _sim.side_for_team(_local_team)
	var u: float = (world.x / layout.lane_width + 0.5)
	var v: float = (world.y * own_side / layout.lane_length + 0.5)
	if own_side < 0:
		u = 1.0 - u
	var inner: Rect2 = _inner()
	return inner.position + Vector2(u * inner.size.x, v * inner.size.y)


func _inner() -> Rect2:
	return Rect2(Vector2(9.0, 9.0), size - Vector2(18.0, 18.0))


func _draw() -> void:
	if _sim == null:
		return
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = PANEL
	box.set_corner_radius_all(14)
	box.border_color = FRAME
	box.set_border_width_all(4)
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	box.shadow_size = 4
	box.shadow_offset = Vector2(0, 3)
	draw_style_box(box, Rect2(Vector2.ZERO, size))
	draw_rect(_inner(), ROAD)
	for wall: MapLayout.WallSpec in _sim.walls:
		if wall.hp <= 0:
			continue
		var a: Vector2 = to_map(wall.rect.position)
		var b: Vector2 = to_map(wall.rect.end)
		draw_rect(Rect2(a, b - a).abs().grow(0.5), WALL)
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
