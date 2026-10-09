class_name PlayerCard
extends Control
## Top-left card for the local player: round portrait in the character's colour
## with their initial, name, and a big HP bar (gray HP in the death delay).

const PANEL: Color = Color(0.1, 0.08, 0.14, 0.85)
const HP_COLOR: Color = Color(0.35, 0.95, 0.35)
const GRAY_COLOR: Color = Color(0.78, 0.78, 0.8)

var display_name: String = ""
var portrait: Color = Color.WHITE
var team_color: Color = Color(0.2, 0.5, 1.0)
var fraction: float = 1.0
var gray: bool = false


func show_player(name_text: String, tint: Color, team: Color) -> void:
	display_name = name_text
	portrait = tint
	team_color = team
	queue_redraw()


func set_hp(value: float, is_gray: bool) -> void:
	if not is_equal_approx(value, fraction) or is_gray != gray:
		fraction = clampf(value, 0.0, 1.0)
		gray = is_gray
		queue_redraw()


func _draw() -> void:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = PANEL
	box.set_corner_radius_all(18)
	draw_style_box(box, Rect2(Vector2(0.0, 4.0), size).grow(0.0))
	box.bg_color = Color(0, 0, 0, 0)
	box.border_color = team_color
	box.set_border_width_all(3)
	draw_style_box(box, Rect2(Vector2.ZERO, size))
	var radius: float = size.y * 0.36
	var center: Vector2 = Vector2(radius + 10.0, size.y / 2.0)
	draw_circle(center, radius + 4.0, team_color)
	draw_circle(center, radius, portrait)
	var font: Font = ThemeDB.fallback_font
	var initial: String = display_name.left(1).to_upper()
	var initial_size: Vector2 = font.get_string_size(initial, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 34)
	var origin: Vector2 = center + Vector2(-initial_size.x / 2.0, 12.0)
	draw_string_outline(font, origin, initial, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 34, 6, Icons.OUTLINE)
	draw_string(font, origin, initial, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 34, Color.WHITE)
	var left: float = center.x + radius + 14.0
	draw_string_outline(font, Vector2(left, 30.0), display_name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, 5, Icons.OUTLINE)
	draw_string(font, Vector2(left, 30.0), display_name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, Color.WHITE)
	var bar: Rect2 = Rect2(left, size.y - 34.0, size.x - left - 14.0, 18.0)
	draw_rect(bar.grow(2.0), Icons.OUTLINE)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * fraction, bar.size.y)), GRAY_COLOR if gray else HP_COLOR)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * fraction, bar.size.y * 0.35)), Color(1, 1, 1, 0.35))
