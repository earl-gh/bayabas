class_name WeaponPickScreen
extends Control
## Full-screen weapon pick (portrait). A gold title plate with a countdown ring,
## your two loadout sockets, then the arsenal as cards grouped by street game
## (painted button art, name, type tag, damage / cooldown / range), and a big Ready
## button. Tap two cards, then Ready, or wait for the timer to auto-fill. Reads and
## drives a WeaponPick. In swap mode (waiting to respawn) every full pair is applied
## at once and the ring shows the respawn countdown.

signal confirmed(picks: Array[StringName])
## Swap mode: a new pair of weapons was picked (applied at once).
signal swapped(picks: Array[StringName])
signal closed

const COLUMNS: int = 3
const CELL_SIZE: Vector2 = Vector2(218.0, 92.0)
const CARD_ICON: float = 64.0
const TITLE_FONT: int = 30
const HEADER_FONT: int = 17
const NAME_FONT: int = 17
const STAT_FONT: int = 13
const SOCKET_SIZE: float = 112.0
const BACKDROP: Color = Color(0.05, 0.06, 0.14, 0.92)
const PICKED_COLOR: Color = Color(1.0, 0.82, 0.25)
const CARD_COLOR: Color = Color(0.13, 0.16, 0.32, 0.95)
const INK: Color = Color(0.1, 0.06, 0.06)
const GOLD: Color = Color(1.0, 0.8, 0.32)
const READY_COLOR: Color = Color(0.3, 0.72, 0.32)
const WAIT_COLOR: Color = Color(0.32, 0.34, 0.42)
const KIND_COLORS: Dictionary[WeaponDef.Kind, Color] = {
	WeaponDef.Kind.ATTACK: Color(1.0, 0.42, 0.34),
	WeaponDef.Kind.CROWD_CONTROL: Color(0.74, 0.52, 1.0),
	WeaponDef.Kind.BLOCK: Color(0.42, 0.72, 1.0),
}

var pick: WeaponPick
## Respawn swap mode: no pick timer, every full pair is applied, Done closes.
var swap_mode: bool = false

var _buttons: Dictionary[StringName, Button] = {}
var _badges: Dictionary[StringName, Label] = {}
var _defs: Dictionary[StringName, WeaponDef] = {}
var _title: Label
var _timer: Label
var _ring: CountdownRing
var _sockets: Array[LoadoutSocket] = []
var _ready_button: Button
var _rng: RandomNumberGenerator
var _swap_total: float = 0.0


static func kind_color(kind: WeaponDef.Kind) -> Color:
	return KIND_COLORS[kind]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


## Shows the screen for `p_pick`. `rng` fills empty slots on timeout.
func open(p_pick: WeaponPick, defs: Array[WeaponDef], heading: String, rng: RandomNumberGenerator) -> void:
	pick = p_pick
	_rng = rng
	swap_mode = false
	_show(defs, heading)


## Opens the respawn swap: change weapons as often as you like until `close()`.
func open_swap(p_pick: WeaponPick, defs: Array[WeaponDef], heading: String) -> void:
	pick = p_pick
	swap_mode = true
	_swap_total = 0.0
	_show(defs, heading)


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


## Swap mode shows the respawn countdown instead of a pick timer.
func show_time(seconds: float) -> void:
	if visible:
		_swap_total = maxf(_swap_total, seconds)
		_timer.text = "Back in %d" % ceili(seconds)
		_ring.show_time(seconds, _swap_total)


func _show(defs: Array[WeaponDef], heading: String) -> void:
	if _buttons.is_empty():
		_build(defs)
	_title.text = heading
	visible = true
	_refresh()


func is_open() -> bool:
	return visible and pick != null and not pick.done


func tap(id: StringName) -> void:
	if not is_open():
		return
	pick.toggle(id)
	_refresh()
	if swap_mode and pick.picks.size() == WeaponPick.SLOTS:
		swapped.emit(pick.picks.duplicate())


func press_ready() -> void:
	if swap_mode:
		close()
	elif is_open() and pick.confirm():
		_finish()


## Counts the pick timer down (call every frame while open).
func tick(delta: float) -> void:
	if not is_open() or swap_mode:
		return
	if pick.step(delta, _rng):
		_finish()
	else:
		_refresh()


func _finish() -> void:
	visible = false
	confirmed.emit(pick.picks.duplicate())


func _refresh() -> void:
	if not swap_mode:
		_timer.text = "%d" % ceili(pick.time_left)
		_ring.show_time(pick.time_left, pick.time_total)
	for id: StringName in _buttons:
		var slot: int = pick.picks.find(id)
		_buttons[id].set_pressed_no_signal(slot >= 0)
		_badges[id].visible = slot >= 0
		_badges[id].text = "%d" % (slot + 1)
	for slot: int in _sockets.size():
		var id: StringName = pick.picks[slot] if slot < pick.picks.size() else &""
		_sockets[slot].show_weapon(_defs.get(id) as WeaponDef)
	var can_go: bool = swap_mode or pick.can_confirm()
	_ready_button.disabled = not can_go
	_style_ready(can_go)
	if swap_mode:
		_ready_button.text = "DONE"
	else:
		_ready_button.text = "READY!" if pick.can_confirm() else "Pick %d more" % (WeaponPick.SLOTS - pick.picks.size())


# ---- building -----------------------------------------------------------------------

## Builds the screen once; later opens reuse it.
func _build(defs: Array[WeaponDef]) -> void:
	for def: WeaponDef in defs:
		_defs[def.id] = def
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = BACKDROP
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	margin.add_theme_constant_override("margin_top", 56)
	margin.add_theme_constant_override("margin_bottom", 36)
	add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	column.add_child(_header())
	column.add_child(_loadout())
	var groups: Array[String] = []
	for def: WeaponDef in defs:
		if not groups.has(def.street_game):
			groups.append(def.street_game)
	for group: String in groups:
		column.add_child(_group_header(group))
		var grid: GridContainer = GridContainer.new()
		grid.columns = COLUMNS
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(grid)
		for def: WeaponDef in defs:
			if def.street_game == group:
				grid.add_child(_weapon_card(def))
	_ready_button = Button.new()
	_ready_button.custom_minimum_size = Vector2(360.0, 84.0)
	_ready_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_ready_button.add_theme_font_size_override("font_size", 32)
	_ready_button.pressed.connect(press_ready)
	column.add_child(_ready_button)


## Gold title plate with the countdown ring beside it.
func _header() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.custom_minimum_size = Vector2(440.0, 70.0)
	_title.add_theme_font_size_override("font_size", TITLE_FONT)
	_title.add_theme_color_override("font_color", Color.WHITE)
	_title.add_theme_color_override("font_outline_color", INK)
	_title.add_theme_constant_override("outline_size", 10)
	_title.add_theme_stylebox_override("normal", _plate(PICKED_COLOR.darkened(0.05)))
	row.add_child(_title)
	_ring = CountdownRing.new()
	_ring.custom_minimum_size = Vector2(84.0, 84.0)
	row.add_child(_ring)
	_timer = Label.new()
	_timer.visible = false
	row.add_child(_timer)
	return row


## Your two loadout sockets.
func _loadout() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 40)
	for slot: int in WeaponPick.SLOTS:
		var socket: LoadoutSocket = LoadoutSocket.new()
		socket.number = slot + 1
		socket.custom_minimum_size = Vector2(200.0, SOCKET_SIZE + 36.0)
		row.add_child(socket)
		_sockets.append(socket)
	return row


func _group_header(text: String) -> Control:
	var label: Label = Label.new()
	label.text = text.to_upper()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", HEADER_FONT)
	label.add_theme_color_override("font_color", GOLD)
	label.add_theme_color_override("font_outline_color", INK)
	label.add_theme_constant_override("outline_size", 6)
	return label


func _weapon_card(def: WeaponDef) -> Button:
	var button: Button = Button.new()
	button.toggle_mode = true
	button.custom_minimum_size = CELL_SIZE
	button.clip_contents = false
	button.add_theme_stylebox_override("normal", _card(CARD_COLOR, kind_color(def.kind).darkened(0.3), 3))
	button.add_theme_stylebox_override("hover", _card(CARD_COLOR.lightened(0.06), kind_color(def.kind).darkened(0.2), 3))
	var picked: StyleBoxFlat = _card(CARD_COLOR.lightened(0.12), PICKED_COLOR, 5)
	picked.shadow_color = Color(1.0, 0.8, 0.3, 0.55)
	picked.shadow_size = 8
	button.add_theme_stylebox_override("pressed", picked)
	button.add_theme_stylebox_override("hover_pressed", picked)
	var art: TextureRect = TextureRect.new()
	art.texture = Icons.art(StringName("btn_" + String(def.id)))
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.position = Vector2(6.0, (CELL_SIZE.y - CARD_ICON) / 2.0)
	art.size = Vector2(CARD_ICON, CARD_ICON)
	button.add_child(art)
	var name_label: Label = _text(def.short_name if not def.short_name.is_empty() else def.display_name, NAME_FONT, Color.WHITE)
	name_label.position = Vector2(CARD_ICON + 12.0, 8.0)
	name_label.size = Vector2(CELL_SIZE.x - CARD_ICON - 16.0, 24.0)
	button.add_child(name_label)
	var tag: Label = _text(def.kind_label(), STAT_FONT, Color.WHITE)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var pill: StyleBoxFlat = StyleBoxFlat.new()
	pill.bg_color = kind_color(def.kind).darkened(0.15)
	pill.border_color = INK
	pill.set_border_width_all(2)
	pill.set_corner_radius_all(9)
	tag.add_theme_stylebox_override("normal", pill)
	tag.position = Vector2(CARD_ICON + 12.0, 36.0)
	tag.size = Vector2(46.0, 20.0)
	button.add_child(tag)
	var stats: Label = _text(_stat_line(def), STAT_FONT, Color(0.82, 0.86, 1.0))
	stats.position = Vector2(CARD_ICON + 12.0, 62.0)
	stats.size = Vector2(CELL_SIZE.x - CARD_ICON - 16.0, 20.0)
	button.add_child(stats)
	var badge: Label = _text("1", 18, INK)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var round_badge: StyleBoxFlat = StyleBoxFlat.new()
	round_badge.bg_color = PICKED_COLOR
	round_badge.border_color = INK
	round_badge.set_border_width_all(3)
	round_badge.set_corner_radius_all(16)
	badge.add_theme_stylebox_override("normal", round_badge)
	badge.position = Vector2(CELL_SIZE.x - 26.0, -8.0)
	badge.size = Vector2(32.0, 32.0)
	badge.visible = false
	button.add_child(badge)
	button.pressed.connect(tap.bind(def.id))
	_buttons[def.id] = button
	_badges[def.id] = badge
	return button


## "14 dmg · 4s · 7m": what the weapon does at a glance.
static func _stat_line(def: WeaponDef) -> String:
	var parts: PackedStringArray = []
	if def.damage > 0:
		parts.append("%d dmg" % (def.damage * maxi(def.count, 1)))
	parts.append("%ss" % String.num(def.cooldown, 0 if is_equal_approx(def.cooldown, roundf(def.cooldown)) else 1))
	if def.max_range > 0.0:
		parts.append("%dm" % roundi(def.max_range))
	return " · ".join(parts)


func _text(text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", INK)
	label.add_theme_constant_override("outline_size", 4)
	label.clip_text = true
	return label


func _card(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(16)
	return style


func _plate(fill: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = INK
	style.set_border_width_all(4)
	style.border_width_bottom = 8
	style.set_corner_radius_all(24)
	return style


func _style_ready(on: bool) -> void:
	var fill: Color = READY_COLOR if on else WAIT_COLOR
	_ready_button.add_theme_stylebox_override("normal", _plate(fill))
	_ready_button.add_theme_stylebox_override("hover", _plate(fill.lightened(0.08)))
	_ready_button.add_theme_stylebox_override("pressed", _plate(fill.darkened(0.12)))
	_ready_button.add_theme_stylebox_override("disabled", _plate(fill))


## Closes the pick now, filling any empty slot at random.
func force_finish() -> void:
	if swap_mode:
		close()
		return
	if not is_open():
		return
	pick.fill(_rng)
	pick.done = true
	_finish()


## Hides the screen without confirming anything (online: the server decided).
func dismiss() -> void:
	if pick != null:
		pick.done = true
	visible = false
