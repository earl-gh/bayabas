class_name RespawnPanel
extends Control
## What you see while waiting to respawn: the street dims, and a card at the bottom
## shows "KNOCKED OUT", a countdown ring, your two weapons and a big Change weapons
## button. Built in code; MatchHud feeds it with `sync()`.

signal swap_pressed

const DIM: Color = Color(0.03, 0.02, 0.08, 0.38)
const CARD: Color = Color(0.09, 0.11, 0.26, 0.86)
const GOLD: Color = Color(1.0, 0.8, 0.32)
const INK: Color = Color(0.1, 0.06, 0.06)
const TITLE_COLOR: Color = Color(1.0, 0.4, 0.34)
const SWAP_COLOR: Color = Color(1.0, 0.66, 0.16)
const CARD_SIZE: Vector2 = Vector2(460.0, 330.0)
const BOTTOM_GAP: float = 40.0
const WEAPON_ICON: float = 64.0

## "RESPAWN IN 8" (kept as a label for screen readers and tests).
var respawn_label: Label
var swap_button: Button
var ring: CountdownRing

var _icons: Array[TextureRect] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var dim: ColorRect = ColorRect.new()
	dim.color = DIM
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var card: PanelContainer = PanelContainer.new()
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 1.0
	card.anchor_bottom = 1.0
	card.offset_left = -CARD_SIZE.x / 2.0
	card.offset_right = CARD_SIZE.x / 2.0
	card.offset_top = -CARD_SIZE.y - BOTTOM_GAP
	card.offset_bottom = -BOTTOM_GAP
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", _card_style())
	add_child(card)
	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 10)
	card.add_child(column)
	var title: Label = _label("KNOCKED OUT!", 30, TITLE_COLOR)
	column.add_child(title)
	var middle: HBoxContainer = HBoxContainer.new()
	middle.alignment = BoxContainer.ALIGNMENT_CENTER
	middle.add_theme_constant_override("separation", 22)
	column.add_child(middle)
	ring = CountdownRing.new()
	ring.custom_minimum_size = Vector2(108.0, 108.0)
	middle.add_child(ring)
	var right: VBoxContainer = VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	middle.add_child(right)
	respawn_label = _label("", 24, Color.WHITE)
	right.add_child(respawn_label)
	var loadout: HBoxContainer = HBoxContainer.new()
	loadout.alignment = BoxContainer.ALIGNMENT_CENTER
	loadout.add_theme_constant_override("separation", 10)
	right.add_child(loadout)
	for i: int in 2:
		var icon: TextureRect = TextureRect.new()
		icon.custom_minimum_size = Vector2(WEAPON_ICON, WEAPON_ICON)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		loadout.add_child(icon)
		_icons.append(icon)
	swap_button = Button.new()
	swap_button.text = "CHANGE WEAPONS"
	swap_button.custom_minimum_size = Vector2(0.0, 72.0)
	swap_button.add_theme_font_size_override("font_size", 28)
	for state: String in ["normal", "hover", "pressed"]:
		var shade: float = 0.0 if state == "normal" else (0.08 if state == "hover" else -0.12)
		var fill: Color = SWAP_COLOR.lightened(shade) if shade >= 0.0 else SWAP_COLOR.darkened(-shade)
		swap_button.add_theme_stylebox_override(state, _chunky(fill))
	swap_button.pressed.connect(swap_pressed.emit)
	column.add_child(swap_button)


## Shown while `player` is dead; the swap button hides while the swap screen is open.
func sync(player: PlayerState, respawn_time: float, pick_open: bool) -> void:
	visible = not player.alive
	respawn_label.visible = visible
	swap_button.visible = visible and not pick_open
	if not visible:
		return
	respawn_label.text = "RESPAWN IN %d" % ceili(player.respawn_time_left)
	ring.show_time(player.respawn_time_left, respawn_time)
	for i: int in _icons.size():
		var id: StringName = player.weapons[i] if i < player.weapons.size() else &""
		_icons[i].texture = Icons.art(StringName("btn_" + String(id))) if id != &"" else null


func _label(text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", INK)
	label.add_theme_constant_override("outline_size", 8)
	return label


func _card_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = CARD
	style.border_color = GOLD
	style.set_border_width_all(5)
	style.set_corner_radius_all(28)
	style.set_content_margin_all(22)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	style.shadow_size = 14
	style.shadow_offset = Vector2(0, 6)
	return style


func _chunky(color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = INK
	style.set_border_width_all(3)
	style.border_width_bottom = 8
	style.set_corner_radius_all(20)
	return style
