class_name KalyeahTheme
extends RefCounted
## The game's UI theme, built in code: painted 9-slice frames from assets/ui
## (tools/art/make_frames.py): glossy bevelled "toy" buttons with a dark lip, navy
## panels in a bevelled gold frame, dark pills; white text with a dark outline.
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
const UI_PATH: String = "res://assets/ui/%s.png"
## 9-slice borders (px of the source image) and content padding.
const BUTTON_SLICE: Vector4 = Vector4(32, 30, 32, 38)
const BUTTON_PADDING: Vector4 = Vector4(20, 10, 20, 18)
const PANEL_SLICE: float = 46.0
const PANEL_PADDING: float = 30.0
const PILL_SLICE: float = 28.0


static func apply() -> void:
	var default_theme: Theme = ThemeDB.get_default_theme()
	default_theme.merge_with(build())
	default_theme.default_font_size = FONT_SIZE


static func build() -> Theme:
	var theme: Theme = Theme.new()
	theme.default_font_size = FONT_SIZE
	set_button_styles(theme, "Button", "orange")
	theme.set_stylebox("disabled", "Button", painted_button("grey"))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		theme.set_color(state, "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", Color(1.0, 1.0, 1.0, 0.6))
	theme.set_color("font_outline_color", "Button", TEXT_OUTLINE)
	theme.set_constant("outline_size", "Button", 8)
	theme.set_color("font_outline_color", "Label", TEXT_OUTLINE)
	theme.set_constant("outline_size", "Label", 6)
	# HudPill: a dark rounded pill behind small HUD labels
	theme.set_type_variation("HudPill", "Label")
	theme.set_stylebox("normal", "HudPill", painted_pill())
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


## A glossy painted button (`color`: orange, green, red, blue, grey or gold).
static func painted_button(color: String, pressed: bool = false, tint: Color = Color.WHITE) -> StyleBoxTexture:
	var box: StyleBoxTexture = StyleBoxTexture.new()
	box.texture = load(UI_PATH % ("button_%s%s" % [color, "_pressed" if pressed else ""])) as Texture2D
	box.texture_margin_left = BUTTON_SLICE.x
	box.texture_margin_top = BUTTON_SLICE.y
	box.texture_margin_right = BUTTON_SLICE.z
	box.texture_margin_bottom = BUTTON_SLICE.w
	box.content_margin_left = BUTTON_PADDING.x
	box.content_margin_top = BUTTON_PADDING.y + (6.0 if pressed else 0.0)
	box.content_margin_right = BUTTON_PADDING.z
	box.content_margin_bottom = BUTTON_PADDING.w - (6.0 if pressed else 0.0)
	box.modulate_color = tint
	return box


## normal / hover / pressed / hover_pressed of one painted colour on `type` (a Button
## or a node via add_theme_stylebox_override when `theme` is null).
static func set_button_styles(theme: Theme, type: String, color: String) -> void:
	theme.set_stylebox("normal", type, painted_button(color))
	theme.set_stylebox("hover", type, painted_button(color, false, Color(1.08, 1.08, 1.08)))
	theme.set_stylebox("pressed", type, painted_button(color, true))
	theme.set_stylebox("hover_pressed", type, painted_button(color, true))


## Gives one Button the painted look of `color`.
static func style_button(button: Button, color: String) -> void:
	button.add_theme_stylebox_override("normal", painted_button(color))
	button.add_theme_stylebox_override("hover", painted_button(color, false, Color(1.08, 1.08, 1.08)))
	button.add_theme_stylebox_override("pressed", painted_button(color, true))
	button.add_theme_stylebox_override("hover_pressed", painted_button(color, true))
	button.add_theme_stylebox_override("disabled", painted_button("grey"))


## The navy card in a bevelled gold frame, for menus and cards.
static func painted_panel(padding: float = PANEL_PADDING) -> StyleBoxTexture:
	var box: StyleBoxTexture = StyleBoxTexture.new()
	box.texture = load(UI_PATH % "panel") as Texture2D
	box.set_texture_margin_all(PANEL_SLICE)
	box.set_content_margin_all(padding)
	return box


## A dark rounded pill with a light rim, for small HUD labels.
static func painted_pill() -> StyleBoxTexture:
	var box: StyleBoxTexture = StyleBoxTexture.new()
	box.texture = load(UI_PATH % "pill") as Texture2D
	box.set_texture_margin_all(PILL_SLICE)
	box.content_margin_left = 16.0
	box.content_margin_right = 16.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 10.0
	return box
