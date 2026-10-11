class_name OverheadHud
extends Control
## MOBA-style overhead display drawn in screen space over each hero, like League
## of Legends: a segmented health bar (green you, blue ally, red enemy, grey gray
## HP in the death delay), a status in *italic* above it ("Stunned"), and one thin
## bar under it: the pin's cooldown. No names and no damage numbers (heals still
## pop a green "+N"). Over every damaged cardboard wall, a cardboard-coloured
## health bar. Reads the sim and projects through the match camera.

const BAR_SIZE: Vector2 = Vector2(92.0, 13.0)
const COOLDOWN_HEIGHT: float = 5.0
const HEAD_HEIGHT: float = 3.9
const SEGMENT_HP: int = 20
const POPUP_TIME: float = 0.9
const POPUP_RISE: float = 56.0
const STATUS_FONT: int = 19
const POPUP_FONT: int = 30
## Italic = the regular font slanted (the bundled font has no italic face).
const ITALIC_SLANT: float = -0.22
const BACK: Color = Color(0.08, 0.06, 0.1, 0.85)
const SELF_COLOR: Color = Color(0.35, 0.95, 0.35)
const ALLY_COLOR: Color = Color(0.35, 0.65, 1.0)
const ENEMY_COLOR: Color = Color(1.0, 0.3, 0.3)
const GRAY_COLOR: Color = Color(0.78, 0.78, 0.8)
const STATUS_COLOR: Color = Color(1.0, 0.86, 0.3)
const COOLDOWN_COLOR: Color = Color(0.3, 0.68, 1.0)
const COOLDOWN_ACTIVE_COLOR: Color = Color(1.0, 0.82, 0.25)
const DAMAGE_COLOR: Color = Color(1.0, 0.95, 0.85)
const HEAL_COLOR: Color = Color(0.55, 1.0, 0.45)
const WALL_BAR_SIZE: Vector2 = Vector2(78.0, 10.0)
const WALL_TOP: float = 2.7
const WALL_COLOR: Color = Color(1.0, 0.68, 0.3)
const WALL_LOW_COLOR: Color = Color(1.0, 0.36, 0.22)
## The spinner above a hero standing in the enemy's scoring area.
const SPINNER_RADIUS: float = 15.0
const SPINNER_LIFT: float = 36.0
const SPINNER_COLOR: Color = Color(1.0, 0.86, 0.3)
const SPINNER_BACK: Color = Color(0.08, 0.06, 0.1, 0.7)
const SPINNER_SPEED: float = 5.0

var _sim: MatchSim
var _camera: Camera3D
var _local_id: int = -1
var _local_team: int = 0
var _italic: FontVariation
## {id, amount, age, heal, jitter}
var _popups: Array[Dictionary] = []


func setup(sim: MatchSim, camera: Camera3D, local_id: int, local_team: int) -> void:
	_sim = sim
	_camera = camera
	_local_id = local_id
	_local_team = local_team
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_italic = FontVariation.new()
	_italic.base_font = ThemeDB.fallback_font
	_italic.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(ITALIC_SLANT, 1.0), Vector2.ZERO)
	sim.player_healed.connect(_on_healed)


## Screen point above wall `index`, or null when it is off camera.
func _wall_top(index: int) -> Variant:
	var center: Vector2 = _sim.walls[index].rect.get_center()
	var world: Vector3 = Vector3(center.x, WALL_TOP, center.y)
	if _camera == null or _camera.is_position_behind(world):
		return null
	return _camera.unproject_position(world)


## The status words shown (in italic) above a hero's bar: "Stunned", "Down", ...
## Empty when nothing is wrong. Heroes have no name text.
func text_for(id: int) -> String:
	return _status_text(_sim.players[id])


func _status_text(state: PlayerState) -> String:
	var words: PackedStringArray = state.effects.display_names()
	if state.death_delay:
		words.insert(0, "Down")
	return " · ".join(words)


## Mark: while you are out on the mark, the bonus time left (1 -> 0, gold);
## afterwards the recharge as 0..1 (1 = ready, blue).
func mark_fraction(state: PlayerState) -> float:
	if state.mark_active:
		return clampf(state.boost_time_left / _sim.rules.bookmark_boost_duration, 0.0, 1.0)
	return _ready_fraction(state.bookmark_cooldown_left, _sim.rules.bookmark_cooldown)


func _ready_fraction(left: float, total: float) -> float:
	if total <= 0.0 or left <= 0.0:
		return 1.0
	return clampf(1.0 - left / total, 0.0, 1.0)


func popup_count() -> int:
	return _popups.size()


func tick(delta: float) -> void:
	for popup: Dictionary in _popups:
		popup["age"] = (popup["age"] as float) + delta
	_popups = _popups.filter(func(p: Dictionary) -> bool: return (p["age"] as float) < POPUP_TIME)
	queue_redraw()


func bar_color(state: PlayerState) -> Color:
	if state.id == _local_id:
		return SELF_COLOR
	return ALLY_COLOR if state.team == _local_team else ENEMY_COLOR


func _on_healed(id: int, amount: int) -> void:
	_popups.append({"id": id, "amount": amount, "age": 0.0, "heal": true, "jitter": 0.0})


func _head(state: PlayerState) -> Variant:
	var world: Vector3 = Vector3(state.position.x, HEAD_HEIGHT, state.position.y)
	if _camera == null or _camera.is_position_behind(world):
		return null
	return _camera.unproject_position(world)


func _draw() -> void:
	if _sim == null:
		return
	for id: int in _sim.players:
		var state: PlayerState = _sim.players[id]
		if not state.alive:
			continue
		var at: Variant = _head(state)
		if at != null:
			_draw_hero(state, at as Vector2)
	for index: int in _sim.walls.size():
		var wall: MapLayout.WallSpec = _sim.walls[index]
		if wall.hp > 0 and wall.hp < _sim.layout.wall_hp:
			var top: Variant = _wall_top(index)
			if top != null:
				_draw_wall_bar(top as Vector2, float(wall.hp) / float(_sim.layout.wall_hp))
	for popup: Dictionary in _popups:
		_draw_popup(popup)


## A cardboard-coloured bar over a damaged wall (turns red when it is about to break).
func _draw_wall_bar(top: Vector2, health: float) -> void:
	var rect: Rect2 = Rect2(top - Vector2(WALL_BAR_SIZE.x / 2.0, 0.0), WALL_BAR_SIZE)
	draw_rect(rect.grow(2.0), BACK)
	var color: Color = WALL_COLOR if health > 0.3 else WALL_LOW_COLOR
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * health, rect.size.y)), color)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * health, rect.size.y * 0.35)), color.lightened(0.35))


func spinner_visible(state: PlayerState) -> bool:
	return state.alive and state.base_time > 0.0


func _draw_hero(state: PlayerState, head: Vector2) -> void:
	var rect: Rect2 = Rect2(head - Vector2(BAR_SIZE.x / 2.0, 0.0), BAR_SIZE)
	draw_rect(rect.grow(2.0), BACK)
	var max_hp: float = float(_sim.rules.player_max_hp)
	if state.death_delay:
		var gray: float = clampf(state.gray_hp / _sim.rules.death_delay_gray_hp, 0.0, 1.0)
		draw_rect(Rect2(rect.position, Vector2(rect.size.x * gray, rect.size.y)), GRAY_COLOR)
	else:
		var fill: float = clampf(float(state.hp) / max_hp, 0.0, 1.0)
		var color: Color = bar_color(state)
		draw_rect(Rect2(rect.position, Vector2(rect.size.x * fill, rect.size.y)), color)
		draw_rect(Rect2(rect.position, Vector2(rect.size.x * fill, rect.size.y * 0.35)), color.lightened(0.35))
	var segments: int = int(max_hp) / SEGMENT_HP
	for i: int in range(1, segments):
		var x: float = rect.position.x + rect.size.x * float(i) / float(segments)
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), BACK, 1.5)
	_draw_cooldowns(state, rect)
	var status: String = _status_text(state)
	var lift: float = 0.0
	if not status.is_empty():
		_text(_italic, status, head + Vector2(0.0, -8.0), STATUS_FONT, STATUS_COLOR, 6)
		lift = 22.0
	if state.base_time > 0.0:
		_draw_spinner(head + Vector2(0.0, -SPINNER_LIFT - lift), state.base_time / _sim.rules.base_capture_time)


## A spinning ring over a hero who is behind the enemy's inner wall: the ring fills as
## the point gets closer (it scores when it is full).
func _draw_spinner(center: Vector2, progress: float) -> void:
	draw_circle(center, SPINNER_RADIUS + 4.0, SPINNER_BACK)
	draw_arc(center, SPINNER_RADIUS, 0.0, TAU, 28, Color(1.0, 1.0, 1.0, 0.25), 4.0)
	var spin: float = float(Time.get_ticks_msec()) / 1000.0 * SPINNER_SPEED
	draw_arc(center, SPINNER_RADIUS, spin, spin + TAU * 0.28, 12, Color(1.0, 1.0, 1.0, 0.9), 4.0)
	draw_arc(center, SPINNER_RADIUS - 6.0, -PI / 2.0, -PI / 2.0 + TAU * clampf(progress, 0.0, 1.0), 24, SPINNER_COLOR, 4.0)


## One thin bar under the health: the pin (gold while you are out on it).
func _draw_cooldowns(state: PlayerState, health: Rect2) -> void:
	var top: float = health.end.y + 4.0
	var color: Color = COOLDOWN_ACTIVE_COLOR if state.mark_active else COOLDOWN_COLOR
	_cooldown_bar(Rect2(health.position.x, top, health.size.x, COOLDOWN_HEIGHT), mark_fraction(state), color)


func _cooldown_bar(rect: Rect2, fraction: float, color: Color) -> void:
	draw_rect(rect.grow(1.5), BACK)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * fraction, rect.size.y)), color if fraction < 1.0 else color.lightened(0.25))


func _draw_popup(popup: Dictionary) -> void:
	var state: PlayerState = _sim.players.get(popup["id"] as int) as PlayerState
	if state == null:
		return
	var at: Variant = _head(state)
	if at == null:
		return
	var age: float = (popup["age"] as float) / POPUP_TIME
	var pos: Vector2 = (at as Vector2) + Vector2(popup["jitter"] as float, -30.0 - POPUP_RISE * age)
	var healed: bool = popup["heal"] as bool
	var color: Color = HEAL_COLOR if healed else (DAMAGE_COLOR if state.team == _local_team else Color(1.0, 0.85, 0.3))
	color.a = 1.0 - age * age
	var size: int = int(POPUP_FONT * (1.25 - 0.25 * age) * (1.2 if healed else 1.0))
	_text(ThemeDB.fallback_font, ("+%d" if healed else "-%d") % (popup["amount"] as int), pos, size, color, 6)


func _text(font: Font, text: String, center: Vector2, font_size: int, color: Color, outline: int) -> void:
	if text.is_empty():
		return
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var origin: Vector2 = center - Vector2(width / 2.0, 0.0)
	var dark: Color = Icons.OUTLINE
	dark.a = color.a
	draw_string_outline(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, outline, dark)
	draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
