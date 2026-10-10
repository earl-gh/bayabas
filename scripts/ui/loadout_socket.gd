class_name LoadoutSocket
extends Control
## One loadout slot on the weapon pick: a sunken round socket with its number,
## showing the picked weapon's painted button and name, or "empty".

const SOCKET: Color = Color(0.04, 0.05, 0.12, 0.9)
const RIM: Color = Color(1.0, 0.8, 0.32, 0.7)
const EMPTY_TEXT: Color = Color(1.0, 1.0, 1.0, 0.45)
const INK: Color = Color(0.1, 0.06, 0.06)
const POINTS: int = 40

var number: int = 1
var weapon: WeaponDef


func show_weapon(def: WeaponDef) -> void:
	weapon = def
	queue_redraw()


func _draw() -> void:
	var radius: float = minf(size.x, size.y - 36.0) / 2.0
	var center: Vector2 = Vector2(size.x / 2.0, radius)
	var font: Font = ThemeDB.fallback_font
	draw_circle(center, radius, SOCKET)
	draw_arc(center, radius - 2.0, 0.0, TAU, POINTS, RIM, 4.0, true)
	var caption: String = "Slot %d: empty" % number
	if weapon != null:
		var art: Texture2D = Icons.art(StringName("btn_" + String(weapon.id)))
		if art != null:
			draw_texture_rect(art, Rect2(center - Vector2(radius, radius) * 1.04, Vector2(radius, radius) * 2.08), false)
		caption = weapon.display_name
	else:
		_centered(font, "%d" % number, center + Vector2(0.0, radius * 0.25), int(radius * 0.8), EMPTY_TEXT)
	_centered(font, caption, Vector2(size.x / 2.0, size.y - 6.0), 18, Color.WHITE if weapon != null else EMPTY_TEXT)


func _centered(font: Font, text: String, baseline: Vector2, font_size: int, color: Color) -> void:
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var origin: Vector2 = baseline - Vector2(width / 2.0, 0.0)
	draw_string_outline(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 5, INK)
	draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
