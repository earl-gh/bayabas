class_name OverheadHud
extends Control
## MOBA-style overhead display drawn in screen space over each hero, like League
## of Legends: a segmented health bar (green you, blue ally, red enemy, grey gray
## HP in the death delay), a status in *italic* above it ("Stunned"), and one row
## of two thin bars under it: Dash cooldown on the left, Mark cooldown on the
## right. No names. Also floating damage and heal numbers. Reads the sim and
## projects through the match camera.

const BAR_SIZE: Vector2 = Vector2(92.0, 13.0)
const COOLDOWN_HEIGHT: float = 5.0
const COOLDOWN_GAP: float = 4.0
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
	sim.player_damaged.connect(_on_damaged)
	sim.player_healed.connect(_on_healed)


## The status words shown (in italic) above a hero's bar: "Stunned", "Down", ...
## Empty when nothing is wrong. Heroes have no name text.
func text_for(id: int) -> String:
	return _status_text(_sim.players[id])


func _status_text(state: PlayerState) -> String:
	var words: PackedStringArray = state.effects.display_names()
	if state.death_delay:
		words.insert(0, "Down")
	return " · ".join(words)


## Dash recharge as 0..1 (1 = ready).
func dash_fraction(state: PlayerState) -> float:
	return _ready_fraction(state.dash_cooldown_left, _sim.rules.dash_cooldown)


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


func _on_damaged(id: int, amount: int) -> void:
	_popups.append({"id": id, "amount": amount, "age": 0.0, "heal": false, "jitter": float((id * 37 + _popups.size() * 13) % 40) - 20.0})


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
	for popup: Dictionary in _popups:
		_draw_popup(popup)


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
	if not status.is_empty():
		_text(_italic, status, head + Vector2(0.0, -8.0), STATUS_FONT, STATUS_COLOR, 6)


## One row, two thin bars: Dash (left) and Mark (right).
func _draw_cooldowns(state: PlayerState, health: Rect2) -> void:
	var width: float = (health.size.x - COOLDOWN_GAP) / 2.0
	var top: float = health.end.y + 4.0
	_cooldown_bar(Rect2(health.position.x, top, width, COOLDOWN_HEIGHT), dash_fraction(state), COOLDOWN_COLOR)
	var mark_color: Color = COOLDOWN_ACTIVE_COLOR if state.mark_active else COOLDOWN_COLOR
	_cooldown_bar(Rect2(health.position.x + width + COOLDOWN_GAP, top, width, COOLDOWN_HEIGHT), mark_fraction(state), mark_color)


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
