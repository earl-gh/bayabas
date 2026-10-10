class_name WeaponPickScreen
extends Control
## Full-screen weapon pick (portrait). Weapons are grouped by street game; tap two,
## then Ready, or wait for the timer to auto-fill. Reads and drives a WeaponPick.

signal confirmed(picks: Array[StringName])
## Swap mode: a new pair of weapons was picked (applied at once).
signal swapped(picks: Array[StringName])
signal closed

const COLUMNS: int = 3
const CELL_SIZE: Vector2 = Vector2(212.0, 96.0)
const TITLE_FONT: int = 40
const HEADER_FONT: int = 26
const CELL_FONT: int = 18
const ICON_WIDTH: float = 54.0
const BACKDROP: Color = Color(0.08, 0.06, 0.12, 0.88)
const PICKED_COLOR: Color = Color(1.0, 0.82, 0.25)
const CARD_COLOR: Color = Color(0.22, 0.2, 0.3)
const KIND_COLORS: Dictionary[WeaponDef.Kind, Color] = {
	WeaponDef.Kind.ATTACK: Color(1.0, 0.55, 0.35),
	WeaponDef.Kind.CROWD_CONTROL: Color(0.75, 0.6, 1.0),
	WeaponDef.Kind.BLOCK: Color(0.45, 0.9, 1.0),
}

var pick: WeaponPick
## Respawn swap mode: no pick timer, every full pair is applied, Done closes.
var swap_mode: bool = false

var _buttons: Dictionary[StringName, Button] = {}
var _title: Label
var _timer: Label
var _ready_button: Button
var _rng: RandomNumberGenerator


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
	_show(defs, heading)


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


## Swap mode shows the respawn countdown instead of a pick timer.
func show_time(seconds: float) -> void:
	if visible:
		_timer.text = "Respawn in %d" % ceili(seconds)


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
	for id: StringName in _buttons:
		var button: Button = _buttons[id]
		var slot: int = pick.picks.find(id)
		button.set_pressed_no_signal(slot >= 0)
	if swap_mode:
		_ready_button.disabled = false
		_ready_button.text = "Done"
		return
	_ready_button.disabled = not pick.can_confirm()
	_ready_button.text = "Ready!" if pick.can_confirm() else "Pick %d more" % (WeaponPick.SLOTS - pick.picks.size())


## Builds the grid once; later opens reuse it.
func _build(defs: Array[WeaponDef]) -> void:
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = BACKDROP
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	margin.add_theme_constant_override("margin_top", 72)
	margin.add_theme_constant_override("margin_bottom", 48)
	add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	_title = _label("", TITLE_FONT)
	column.add_child(_title)
	_timer = _label("", TITLE_FONT)
	column.add_child(_timer)
	var groups: Array[String] = []
	for def: WeaponDef in defs:
		if not groups.has(def.street_game):
			groups.append(def.street_game)
	for group: String in groups:
		column.add_child(_label(group, HEADER_FONT))
		var grid: GridContainer = GridContainer.new()
		grid.columns = COLUMNS
		grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(grid)
		for def: WeaponDef in defs:
			if def.street_game == group:
				grid.add_child(_weapon_button(def))
	_ready_button = Button.new()
	_ready_button.custom_minimum_size = Vector2(320.0, 88.0)
	_ready_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_ready_button.add_theme_font_size_override("font_size", 32)
	_ready_button.pressed.connect(press_ready)
	column.add_child(_ready_button)


func _weapon_button(def: WeaponDef) -> Button:
	var button: Button = Button.new()
	button.toggle_mode = true
	button.custom_minimum_size = CELL_SIZE
	button.text = "%s\n%s" % [def.display_name, def.kind_label()]
	button.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	button.add_theme_constant_override("h_separation", 0)
	var icon: IconView = IconView.new()
	icon.icon_id = def.id
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	icon.offset_right = ICON_WIDTH
	button.add_child(icon)
	button.add_theme_font_size_override("font_size", CELL_FONT)
	button.add_theme_color_override("font_color", kind_color(def.kind))
	# dark cards; picked ones light up yellow
	var card: StyleBoxFlat = BayabasTheme.button_box(CARD_COLOR)
	button.add_theme_stylebox_override("normal", card)
	button.add_theme_stylebox_override("hover", BayabasTheme.button_box(CARD_COLOR.lightened(0.1)))
	var picked: StyleBoxFlat = BayabasTheme.button_box(PICKED_COLOR, true)
	button.add_theme_stylebox_override("pressed", picked)
	button.add_theme_stylebox_override("hover_pressed", picked)
	for state: String in ["font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, Color.BLACK)
	button.add_theme_constant_override("outline_size", 4)
	button.pressed.connect(tap.bind(def.id))
	_buttons[def.id] = button
	return button


func _label(text: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	return label


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
