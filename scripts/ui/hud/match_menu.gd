class_name MatchMenu
extends Control
## The in-match settings modal: a see-through navy card with a gold frame and a
## title plate, a close button, the handedness switch (controls on the right or the
## left), the practice test buttons and Resume / Exit. Built in code.

signal closed
signal exit_pressed
signal hurt_pressed
signal tricycle_pressed

const BACKDROP: Color = Color(0.02, 0.02, 0.06, 0.32)
const CARD: Color = Color(0.09, 0.12, 0.28, 0.78)
const GOLD: Color = Color(1.0, 0.8, 0.32)
const GOLD_DARK: Color = Color(0.62, 0.4, 0.1)
const INK: Color = Color(0.1, 0.06, 0.06)
const SEGMENT_OFF: Color = Color(0.16, 0.2, 0.4, 0.9)
const SEGMENT_ON: Color = Color(1.0, 0.72, 0.18)
const RESUME_COLOR: Color = Color(0.3, 0.72, 0.32)
const EXIT_COLOR: Color = Color(0.86, 0.26, 0.24)
const CARD_SIZE: Vector2 = Vector2(440.0, 560.0)
const BUTTON_HEIGHT: float = 62.0

var hurt_button: Button
var tricycle_button: Button
var left_button: Button
var right_button: Button

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
	card.add_theme_stylebox_override("panel", _card_style())
	add_child(card)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	card.add_child(column)
	_section(column, "CONTROLS")
	var segments: HBoxContainer = HBoxContainer.new()
	segments.add_theme_constant_override("separation", 0)
	column.add_child(segments)
	left_button = _segment("Left hand", segments, true)
	right_button = _segment("Right hand", segments, false)
	left_button.pressed.connect(_set_left.bind(true))
	right_button.pressed.connect(_set_left.bind(false))
	_test_title = _section(column, "PRACTICE")
	hurt_button = _button("-30 HP (test)", SEGMENT_OFF, column)
	hurt_button.pressed.connect(hurt_pressed.emit)
	tricycle_button = _button("Call the tricycle (test)", SEGMENT_OFF, column)
	tricycle_button.pressed.connect(tricycle_pressed.emit)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	var resume: Button = _button("Resume", RESUME_COLOR, column)
	resume.pressed.connect(close)
	var leave: Button = _button("Exit match", EXIT_COLOR, column)
	leave.pressed.connect(exit_pressed.emit)
	# siblings of the card (a container would lay them out inside it)
	_title_plate()
	_close_button()
	_show_handedness(Settings.left_handed)


func open() -> void:
	_show_handedness(Settings.left_handed)
	_test_title.visible = hurt_button.visible or tricycle_button.visible
	visible = true


func close() -> void:
	if visible:
		visible = false
		closed.emit()


func _set_left(on: bool) -> void:
	Settings.set_left_handed(on)
	_show_handedness(on)


func _show_handedness(left: bool) -> void:
	left_button.button_pressed = left
	right_button.button_pressed = not left


func _on_backdrop_input(event: InputEvent) -> void:
	var tap: InputEventMouseButton = event as InputEventMouseButton
	if tap != null and tap.pressed:
		close()


func _card_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = CARD
	style.border_color = GOLD
	style.set_border_width_all(5)
	style.set_corner_radius_all(28)
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 58
	style.content_margin_bottom = 28
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	style.shadow_size = 16
	style.shadow_offset = Vector2(0, 8)
	return style


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
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = SEGMENT_ON
	style.border_color = INK
	style.set_border_width_all(4)
	style.set_corner_radius_all(22)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.4)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 4)
	plate.add_theme_stylebox_override("normal", style)
	_centered(plate, Rect2(-110.0, -CARD_SIZE.y / 2.0 - 30.0, 220.0, 60.0))
	add_child(plate)


func _close_button() -> void:
	var close_button: Button = Button.new()
	close_button.text = "X"
	close_button.add_theme_font_size_override("font_size", 26)
	close_button.add_theme_stylebox_override("normal", _round_style(EXIT_COLOR))
	close_button.add_theme_stylebox_override("hover", _round_style(EXIT_COLOR.lightened(0.1)))
	close_button.add_theme_stylebox_override("pressed", _round_style(EXIT_COLOR.darkened(0.15)))
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


func _segment(text: String, parent: Control, first: bool) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.toggle_mode = true
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_stylebox_override("normal", _segment_style(SEGMENT_OFF, first))
	button.add_theme_stylebox_override("hover", _segment_style(SEGMENT_OFF.lightened(0.08), first))
	button.add_theme_stylebox_override("pressed", _segment_style(SEGMENT_ON, first))
	button.add_theme_stylebox_override("hover_pressed", _segment_style(SEGMENT_ON, first))
	parent.add_child(button)
	return button


func _segment_style(color: Color, first: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = INK
	style.set_border_width_all(3)
	var round: int = 18
	style.corner_radius_top_left = round if first else 0
	style.corner_radius_bottom_left = round if first else 0
	style.corner_radius_top_right = 0 if first else round
	style.corner_radius_bottom_right = 0 if first else round
	return style


func _button(text: String, color: Color, parent: Control) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_stylebox_override("normal", _chunky(color))
	button.add_theme_stylebox_override("hover", _chunky(color.lightened(0.08)))
	button.add_theme_stylebox_override("pressed", _chunky(color.darkened(0.12)))
	parent.add_child(button)
	return button


## A chunky pill with a darker bottom lip, like the rest of the HUD.
func _chunky(color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = INK
	style.set_border_width_all(3)
	style.border_width_bottom = 7
	style.set_corner_radius_all(18)
	return style


func _round_style(color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = INK
	style.set_border_width_all(4)
	style.set_corner_radius_all(28)
	return style
