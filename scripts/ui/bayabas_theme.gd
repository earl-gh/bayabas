class_name BayabasTheme
extends RefCounted
## The game's UI theme, built in code: big rounded "toy" buttons with a dark rim
## and a drop shadow, white text with a dark outline, warm Pinoy-street colours.
## Applied once at startup by the Settings autoload: it is merged into the engine
## default theme, so every Control gets it, also under CanvasLayers and 3D scenes.

const BUTTON: Color = Color(1.0, 0.7, 0.18)
const BUTTON_HOVER: Color = Color(1.0, 0.8, 0.32)
const BUTTON_PRESSED: Color = Color(0.9, 0.55, 0.12)
const BUTTON_DISABLED: Color = Color(0.55, 0.52, 0.5)
const RIM: Color = Color(0.32, 0.18, 0.1)
const FIELD: Color = Color(0.98, 0.95, 0.88)
const FIELD_TEXT: Color = Color(0.2, 0.15, 0.12)
const TEXT_OUTLINE: Color = Color(0.12, 0.08, 0.1)
const CORNER: int = 18
const SHADOW_DEPTH: int = 7
const FONT_SIZE: int = 28


static func apply() -> void:
	var default_theme: Theme = ThemeDB.get_default_theme()
	default_theme.merge_with(build())
	default_theme.default_font_size = FONT_SIZE


static func build() -> Theme:
	var theme: Theme = Theme.new()
	theme.default_font_size = FONT_SIZE
	theme.set_stylebox("normal", "Button", button_box(BUTTON))
	theme.set_stylebox("hover", "Button", button_box(BUTTON_HOVER))
	theme.set_stylebox("pressed", "Button", button_box(BUTTON_PRESSED, true))
	theme.set_stylebox("hover_pressed", "Button", button_box(BUTTON_PRESSED, true))
	theme.set_stylebox("disabled", "Button", button_box(BUTTON_DISABLED))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		theme.set_color(state, "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", Color(1.0, 1.0, 1.0, 0.6))
	theme.set_color("font_outline_color", "Button", TEXT_OUTLINE)
	theme.set_constant("outline_size", "Button", 8)
	theme.set_color("font_outline_color", "Label", TEXT_OUTLINE)
	theme.set_constant("outline_size", "Label", 6)
	var field: StyleBoxFlat = StyleBoxFlat.new()
	field.bg_color = FIELD
	field.set_corner_radius_all(14)
	field.set_border_width_all(3)
	field.border_color = RIM
	field.set_content_margin_all(14)
	theme.set_stylebox("normal", "LineEdit", field)
	theme.set_stylebox("focus", "LineEdit", field)
	theme.set_color("font_color", "LineEdit", FIELD_TEXT)
	theme.set_color("font_placeholder_color", "LineEdit", Color(FIELD_TEXT, 0.4))
	theme.set_color("caret_color", "LineEdit", FIELD_TEXT)
	return theme


## A chunky button face: rounded, dark rim, thicker bottom edge as a shadow.
## Pressed buttons lose most of the shadow so they look pushed in.
static func button_box(color: Color, pressed: bool = false) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(CORNER)
	box.set_border_width_all(3)
	box.border_width_bottom = 3 if pressed else SHADOW_DEPTH
	box.border_color = RIM
	box.set_content_margin_all(12)
	box.content_margin_top = 12.0 + (SHADOW_DEPTH - 3 if pressed else 0)
	return box
