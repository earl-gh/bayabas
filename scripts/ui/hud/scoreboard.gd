class_name Scoreboard
extends Control
## Top-centre scoreboard pill: your team's points (blue) and theirs (red), the set
## number and set pips underneath. Team-relative: you are always on the left.

const OWN: Color = Color(0.2, 0.5, 1.0)
const ENEMY: Color = Color(1.0, 0.3, 0.3)
const PANEL: Color = Color(0.1, 0.08, 0.14, 0.88)
const RIM: Color = Color(1.0, 0.82, 0.35)
const BIG_FONT: int = 40
const SMALL_FONT: int = 17

var mine: int = 0
var theirs: int = 0
var set_number: int = 1
var sets_mine: int = 0
var sets_theirs: int = 0
var sets_to_win: int = 2


func show_score(score: MatchScore, my_team: int, sets_needed: int) -> void:
	var values: Array[int] = [score.points[my_team], score.points[1 - my_team], score.set_number, score.sets[my_team], score.sets[1 - my_team]]
	if values != [mine, theirs, set_number, sets_mine, sets_theirs]:
		mine = values[0]
		theirs = values[1]
		set_number = values[2]
		sets_mine = values[3]
		sets_theirs = values[4]
		queue_redraw()
	sets_to_win = sets_needed


## Plain-text version (tests, accessibility).
func summary() -> String:
	return "YOU %d - %d THEM   Set %d (%d-%d)" % [mine, theirs, set_number, sets_mine, sets_theirs]


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	var w: float = size.x
	var h: float = size.y - 22.0
	_round_rect(Rect2(0.0, 4.0, w, h), Color(0, 0, 0, 0.35), 18.0)
	_round_rect(Rect2(0.0, 0.0, w, h), PANEL, 18.0)
	var box: float = h - 12.0
	_round_rect(Rect2(6.0, 6.0, box * 1.25, box), OWN, 12.0)
	_round_rect(Rect2(w - 6.0 - box * 1.25, 6.0, box * 1.25, box), ENEMY, 12.0)
	_center_text(font, str(mine), Vector2(6.0 + box * 0.625, h / 2.0), BIG_FONT, Color.WHITE)
	_center_text(font, str(theirs), Vector2(w - 6.0 - box * 0.625, h / 2.0), BIG_FONT, Color.WHITE)
	_center_text(font, "SET %d" % set_number, Vector2(w / 2.0, h / 2.0), SMALL_FONT + 4, RIM)
	# set pips under the pill
	for i: int in sets_to_win:
		_pip(Vector2(w / 2.0 - 22.0 - float(i) * 18.0, h + 12.0), i < sets_mine, OWN)
		_pip(Vector2(w / 2.0 + 22.0 + float(i) * 18.0, h + 12.0), i < sets_theirs, ENEMY)


func _pip(at: Vector2, won: bool, color: Color) -> void:
	draw_circle(at, 7.0, Icons.OUTLINE)
	draw_circle(at, 5.0, color if won else Color(1, 1, 1, 0.25))


func _round_rect(rect: Rect2, color: Color, radius: float) -> void:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(int(radius))
	draw_style_box(box, rect)


func _center_text(font: Font, text: String, center: Vector2, font_size: int, color: Color) -> void:
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var origin: Vector2 = center + Vector2(-text_size.x / 2.0, font_size * 0.35)
	draw_string_outline(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 6, Icons.OUTLINE)
	draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
