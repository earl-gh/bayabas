class_name OverheadHud
extends Control
## MOBA-style overhead bars drawn in screen space over each player (like Mobile
## Legends / LoL): name, a segmented HP bar (green = you, blue = ally, red =
## enemy, grey = gray HP in the death delay), active status effects, and
## floating damage numbers. Reads the sim; projects through the match camera.

const BAR_SIZE: Vector2 = Vector2(92.0, 13.0)
const HEAD_HEIGHT: float = 2.55
const SEGMENT_HP: int = 20
const POPUP_TIME: float = 0.9
const POPUP_RISE: float = 56.0
const NAME_FONT: int = 17
const TAG_FONT: int = 15
const POPUP_FONT: int = 30
const BACK: Color = Color(0.08, 0.06, 0.1, 0.85)
const SELF_COLOR: Color = Color(0.35, 0.95, 0.35)
const ALLY_COLOR: Color = Color(0.35, 0.65, 1.0)
const ENEMY_COLOR: Color = Color(1.0, 0.3, 0.3)
const GRAY_COLOR: Color = Color(0.78, 0.78, 0.8)
const EFFECT_COLOR: Color = Color(1.0, 0.86, 0.3)
const DAMAGE_COLOR: Color = Color(1.0, 0.95, 0.85)

var _sim: MatchSim
var _camera: Camera3D
var _local_id: int = -1
var _local_team: int = 0
var _names: Dictionary[int, String] = {}
## {id, amount, age}
var _popups: Array[Dictionary] = []


func setup(sim: MatchSim, camera: Camera3D, local_id: int, local_team: int, names: Dictionary[int, String]) -> void:
	_sim = sim
	_camera = camera
	_local_id = local_id
	_local_team = local_team
	_names = names
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	sim.player_damaged.connect(_on_damaged)


## The words drawn over a player (name and effects), e.g. for tests.
func text_for(id: int) -> String:
	var state: PlayerState = _sim.players[id]
	var lines: PackedStringArray = PackedStringArray([_names.get(id, "?") as String])
	if state.death_delay:
		lines.append("GRAY %d" % ceili(state.gray_hp))
	var effects: PackedStringArray = state.effects.active_names()
	if not effects.is_empty():
		lines.append(" ".join(effects))
	return "\n".join(lines)


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


func _on_damaged(id: int, amount: int) -> void:
	_popups.append({"id": id, "amount": amount, "age": 0.0, "jitter": float((id * 37 + _popups.size() * 13) % 40) - 20.0})


func _head(state: PlayerState) -> Variant:
	var world: Vector3 = Vector3(state.position.x, HEAD_HEIGHT, state.position.y)
	if _camera == null or _camera.is_position_behind(world):
		return null
	return _camera.unproject_position(world)


func _draw() -> void:
	if _sim == null:
		return
	var font: Font = ThemeDB.fallback_font
	for id: int in _sim.players:
		var state: PlayerState = _sim.players[id]
		if not state.alive:
			continue
		var at: Variant = _head(state)
		if at == null:
			continue
		_draw_bar(font, state, at as Vector2)
	for popup: Dictionary in _popups:
		var state: PlayerState = _sim.players.get(popup["id"] as int) as PlayerState
		if state == null:
			continue
		var at: Variant = _head(state)
		if at == null:
			continue
		var age: float = (popup["age"] as float) / POPUP_TIME
		var pos: Vector2 = (at as Vector2) + Vector2(popup["jitter"] as float, -30.0 - POPUP_RISE * age)
		var color: Color = DAMAGE_COLOR if state.team == _local_team else Color(1.0, 0.85, 0.3)
		color.a = 1.0 - age * age
		var size: int = int(POPUP_FONT * (1.25 - 0.25 * age))
		_text(font, "-%d" % (popup["amount"] as int), pos, size, color, 6)


func _draw_bar(font: Font, state: PlayerState, head: Vector2) -> void:
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
	var name_color: Color = bar_color(state).lightened(0.4)
	_text(font, _names.get(state.id, "") as String, head + Vector2(0.0, -10.0), NAME_FONT, name_color, 5)
	var effects: PackedStringArray = state.effects.active_names()
	if state.death_delay:
		effects.insert(0, "DOWN")
	if not effects.is_empty():
		_text(font, " ".join(effects), head + Vector2(0.0, BAR_SIZE.y + 17.0), TAG_FONT, EFFECT_COLOR, 5)


func _text(font: Font, text: String, center: Vector2, font_size: int, color: Color, outline: int) -> void:
	if text.is_empty():
		return
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var origin: Vector2 = center - Vector2(width / 2.0, 0.0)
	var dark: Color = Icons.OUTLINE
	dark.a = color.a
	draw_string_outline(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, outline, dark)
	draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
