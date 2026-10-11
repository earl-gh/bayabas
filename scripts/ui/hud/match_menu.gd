class_name MatchMenu
extends Control
## The in-match settings modal: a see-through navy card with a gold frame and a
## title plate, a close button, the practice test buttons and Resume / Exit. Built in code.

signal closed
signal exit_pressed
signal hurt_pressed
signal tricycle_pressed
signal enemy_walls_toggled(removed: bool)

const BACKDROP: Color = Color(0.02, 0.02, 0.06, 0.32)
const GOLD: Color = Color(1.0, 0.8, 0.32)
const GOLD_DARK: Color = Color(0.62, 0.4, 0.1)
const INK: Color = Color(0.1, 0.06, 0.06)
const CARD_SIZE: Vector2 = Vector2(440.0, 480.0)
## The card is a little see-through, so the street shows behind it.
const CARD_ALPHA: float = 0.9
const BUTTON_HEIGHT: float = 62.0

var hurt_button: Button
var tricycle_button: Button
var walls_button: Button

var _test_title: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = BACKDROP
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.gui_input.connect(_on_backdrop_input)
	add_child(backdrop)
	var card: PanelContainer = PanelContainer.new()
	_centered(card, Rect2(-CARD_SIZE / 2.0, CARD_SIZE))
	var card_style: StyleBoxTexture = KalyeahTheme.painted_panel()
	card_style.content_margin_top = 64.0
	card_style.modulate_color = Color(1.0, 1.0, 1.0, CARD_ALPHA)
	card.add_theme_stylebox_override("panel", card_style)
	add_child(card)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	card.add_child(column)
	_test_title = _section(column, "PRACTICE")
	hurt_button = _button("-30 HP (test)", "blue", column)
	hurt_button.pressed.connect(hurt_pressed.emit)
	tricycle_button = _button("Call the tricycle (test)", "blue", column)
	tricycle_button.pressed.connect(tricycle_pressed.emit)
	walls_button = _button("Enemy walls: ON", "grey", column)
	walls_button.toggle_mode = true
	walls_button.toggled.connect(_on_walls_toggled)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	var resume: Button = _button("Resume", "green", column)
	resume.pressed.connect(close)
	var leave: Button = _button("Exit match", "red", column)
	leave.pressed.connect(exit_pressed.emit)
	# siblings of the card (a container would lay them out inside it)
	_title_plate()
	_close_button()


func open() -> void:
	_test_title.visible = hurt_button.visible or tricycle_button.visible or walls_button.visible
	visible = true


func close() -> void:
	if visible:
		visible = false
		closed.emit()


func _on_walls_toggled(removed: bool) -> void:
	walls_button.text = "Enemy walls: OFF" if removed else "Enemy walls: ON"
	enemy_walls_toggled.emit(removed)


func _on_backdrop_input(event: InputEvent) -> void:
	var tap: InputEventMouseButton = event as InputEventMouseButton
	if tap != null and tap.pressed:
		close()


## The gold "MENU" plate riding on the card's top edge.
func _title_plate() -> void:
	var plate: Label = Label.new()
	plate.text = "MENU"
	plate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plate.add_theme_font_size_override("font_size", 34)
	plate.add_theme_color_override("font_color", Color.WHITE)
	plate.add_theme_color_override("font_outline_color", INK)
	plate.add_theme_constant_override("outline_size", 10)
	plate.add_theme_stylebox_override("normal", KalyeahTheme.painted_button("gold"))
	_centered(plate, Rect2(-110.0, -CARD_SIZE.y / 2.0 - 30.0, 220.0, 60.0))
	add_child(plate)


func _close_button() -> void:
	var close_button: Button = Button.new()
	close_button.text = "X"
	close_button.add_theme_font_size_override("font_size", 26)
	KalyeahTheme.style_button(close_button, "red")
	close_button.custom_minimum_size = Vector2(56, 56)
	close_button.pressed.connect(close)
	_centered(close_button, Rect2(CARD_SIZE.x / 2.0 - 40.0, -CARD_SIZE.y / 2.0 - 16.0, 56.0, 56.0))
	add_child(close_button)


## Places `control` at `rect`, measured from the screen centre.
func _centered(control: Control, rect: Rect2) -> void:
	control.anchor_left = 0.5
	control.anchor_right = 0.5
	control.anchor_top = 0.5
	control.anchor_bottom = 0.5
	control.offset_left = rect.position.x
	control.offset_top = rect.position.y
	control.offset_right = rect.end.x
	control.offset_bottom = rect.end.y


func _section(parent: Control, text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", GOLD)
	parent.add_child(label)
	return label


func _button(text: String, paint: String, parent: Control) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	button.add_theme_font_size_override("font_size", 24)
	KalyeahTheme.style_button(button, paint)
	parent.add_child(button)
	return button
