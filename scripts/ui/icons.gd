class_name Icons
extends RefCounted
## Skill and HUD icons. The painted PNGs in assets/icons/ (tools/art/make_assets.py)
## are used when they exist; the little vector drawings below are the fallback.

const OUTLINE: Color = Color(0.1, 0.08, 0.12, 0.9)
const ICON_PATH: String = "res://assets/icons/%s.png"
## The painted art has a margin and a drop shadow, so it is drawn a bit larger.
const ART_SCALE: float = 1.3

static var _art: Dictionary[StringName, Texture2D] = {}


## The painted image for `id`, or null if there is none.
static func art(id: StringName) -> Texture2D:
	if not _art.has(id):
		var path: String = ICON_PATH % String(id)
		_art[id] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _art[id]


## Draws icon `id` centred at `center`, about `size` px across.
static func draw(canvas: CanvasItem, id: StringName, center: Vector2, size: float) -> void:
	var texture: Texture2D = art(id)
	if texture != null:
		var side: float = size * ART_SCALE
		canvas.draw_texture_rect(texture, Rect2(center - Vector2(side, side) / 2.0, Vector2(side, side)), false)
		return
	var s: float = size / 2.0
	match id:
		&"bato_light":
			_rock(canvas, center, s * 0.6, Palette.CONCRETE)
		&"bato_heavy":
			_rock(canvas, center + Vector2(0.0, s * 0.15), s * 0.8, Palette.CONCRETE.darkened(0.15))
			for i: int in 3:
				var x: float = -s * 0.5 + float(i) * s * 0.5
				canvas.draw_line(center + Vector2(x, -s * 0.95), center + Vector2(x * 0.6, -s * 0.6), Palette.SARI_YELLOW, 3.0)
		&"gunting_light", &"gunting_heavy":
			var heavy: bool = id == &"gunting_heavy"
			var width: float = 5.0 if heavy else 3.5
			canvas.draw_line(center + Vector2(-s * 0.7, -s * 0.8), center + Vector2(s * 0.5, s * 0.4), Palette.JEEP_CHROME, width)
			canvas.draw_line(center + Vector2(s * 0.7, -s * 0.8), center + Vector2(-s * 0.5, s * 0.4), Palette.JEEP_CHROME, width)
			for side: float in [-1.0, 1.0]:
				canvas.draw_arc(center + Vector2(side * s * 0.55, s * 0.6), s * 0.28, 0.0, TAU, 16, Palette.SARI_RED, 4.0)
		&"papel_trap":
			canvas.draw_circle(center, s * 0.6, Palette.WHITE)
			canvas.draw_polyline(PackedVector2Array([center + Vector2(-s * 0.4, -s * 0.1), center + Vector2(0.0, s * 0.2), center + Vector2(s * 0.35, -s * 0.25)]), OUTLINE, 2.0)
			canvas.draw_arc(center, s * 0.95, 0.0, TAU, 24, Palette.WALL_SKY, 3.0)
		&"papel_shield":
			var rect: Rect2 = Rect2(center - Vector2(s * 0.75, s * 0.85), Vector2(s * 1.5, s * 1.7))
			canvas.draw_rect(rect, Palette.WHITE)
			canvas.draw_rect(rect, OUTLINE, false, 2.0)
			for i: int in 3:
				var y: float = rect.position.y + rect.size.y * (0.3 + float(i) * 0.2)
				canvas.draw_line(Vector2(rect.position.x + 6.0, y), Vector2(rect.end.x - 6.0, y), Palette.WALL_SKY, 2.0)
		&"tsinelas_light", &"tsinelas_heavy":
			var count: int = 3 if id == &"tsinelas_light" else 1
			for i: int in count:
				var offset: Vector2 = Vector2((float(i) - float(count - 1) / 2.0) * s * 0.55, 0.0)
				var scale: float = 0.55 if count > 1 else 0.9
				_slipper(canvas, center + offset, s * scale)
		&"lata":
			var can: Rect2 = Rect2(center - Vector2(s * 0.45, s * 0.75), Vector2(s * 0.9, s * 1.5))
			canvas.draw_rect(can, Palette.JEEP_CHROME)
			canvas.draw_rect(Rect2(can.position + Vector2(0.0, can.size.y * 0.3), Vector2(can.size.x, can.size.y * 0.4)), Palette.SARI_RED)
			canvas.draw_rect(can, OUTLINE, false, 2.0)
		&"jacks":
			for i: int in 3:
				var angle: float = PI * float(i) / 3.0
				var d: Vector2 = Vector2.from_angle(angle) * s * 0.75
				canvas.draw_line(center - d, center + d, Palette.JEEP_CHROME, 4.0)
				canvas.draw_circle(center + d, 3.5, Palette.JEEP_CHROME)
				canvas.draw_circle(center - d, 3.5, Palette.JEEP_CHROME)
		&"bola":
			canvas.draw_circle(center + Vector2(0.0, -s * 0.15), s * 0.55, Palette.SARI_RED)
			canvas.draw_arc(center + Vector2(-s * 0.2, s * 0.6), s * 0.35, PI, TAU, 10, Palette.WHITE, 2.0)
			canvas.draw_arc(center + Vector2(s * 0.35, s * 0.6), s * 0.2, PI, TAU, 10, Palette.WHITE, 2.0)
		&"trumpo":
			var top: PackedVector2Array = PackedVector2Array([center + Vector2(-s * 0.7, -s * 0.3), center + Vector2(s * 0.7, -s * 0.3), center + Vector2(0.0, s * 0.9)])
			canvas.draw_colored_polygon(top, Palette.WOOD)
			canvas.draw_rect(Rect2(center + Vector2(-s * 0.7, -s * 0.55), Vector2(s * 1.4, s * 0.28)), Palette.SARI_RED)
			canvas.draw_line(center + Vector2(0.0, -s * 0.55), center + Vector2(0.0, -s * 0.9), Palette.WOOD.darkened(0.3), 3.0)
		&"dash":
			for i: int in 3:
				var y: float = -s * 0.4 + float(i) * s * 0.4
				canvas.draw_line(center + Vector2(-s * 0.8 + float(i % 2) * s * 0.2, y), center + Vector2(s * 0.1, y), Palette.WHITE, 3.0)
			canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(s * 0.2, -s * 0.5), center + Vector2(s * 0.85, 0.0), center + Vector2(s * 0.2, s * 0.5)]), Palette.SARI_YELLOW)
		&"bookmark":
			canvas.draw_colored_polygon(PackedVector2Array([
				center + Vector2(-s * 0.45, -s * 0.85), center + Vector2(s * 0.45, -s * 0.85),
				center + Vector2(s * 0.45, s * 0.85), center + Vector2(0.0, s * 0.45), center + Vector2(-s * 0.45, s * 0.85),
			]), Palette.SARI_RED)
		&"guava":
			# the guava (bayabas): a round green guava with a leaf and a little crown
			canvas.draw_circle(center + Vector2(0.0, s * 0.1), s * 0.75, Color(0.45, 0.78, 0.3))
			canvas.draw_circle(center + Vector2(-s * 0.25, -s * 0.15), s * 0.22, Color(0.62, 0.9, 0.45))
			canvas.draw_arc(center + Vector2(0.0, s * 0.1), s * 0.75, 0.0, TAU, 32, OUTLINE, 4.0)
			canvas.draw_colored_polygon(PackedVector2Array([
				center + Vector2(s * 0.05, -s * 0.62), center + Vector2(s * 0.6, -s * 1.0), center + Vector2(s * 0.3, -s * 0.55),
			]), Palette.LEAF_DARK)
			canvas.draw_line(center + Vector2(0.0, -s * 0.62), center + Vector2(-s * 0.08, -s * 0.85), Palette.WOOD, 4.0)
		&"tricycle":
			canvas.draw_rect(Rect2(center + Vector2(-s * 0.8, -s * 0.5), Vector2(s * 1.0, s * 0.7)), Palette.JEEP_RED)
			canvas.draw_rect(Rect2(center + Vector2(-s * 0.85, -s * 0.62), Vector2(s * 1.1, s * 0.14)), Palette.JEEP_BLUE)
			canvas.draw_line(center + Vector2(s * 0.2, -s * 0.1), center + Vector2(s * 0.75, -s * 0.3), Palette.JEEP_CHROME, 3.0)
			for x: float in [-0.55, 0.0, 0.6]:
				canvas.draw_circle(center + Vector2(s * x, s * 0.4), s * 0.2, Palette.BLACK)
		&"ball":
			draw(canvas, &"guava", center, size)
		_:
			canvas.draw_circle(center, s * 0.5, Palette.WHITE)


static func _rock(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	var bumps: Array[float] = [1.0, 0.85, 1.05, 0.9, 1.0, 0.8, 0.95]
	for i: int in bumps.size():
		points.append(center + Vector2.from_angle(TAU * float(i) / float(bumps.size())) * radius * bumps[i])
	canvas.draw_colored_polygon(points, color)
	points.append(points[0])
	canvas.draw_polyline(points, OUTLINE, 2.0)


static func _slipper(canvas: CanvasItem, center: Vector2, half: float) -> void:
	var sole: Rect2 = Rect2(center - Vector2(half * 0.45, half * 0.95), Vector2(half * 0.9, half * 1.9))
	canvas.draw_rect(sole, Palette.JEEP_BLUE)
	canvas.draw_rect(sole, OUTLINE, false, 2.0)
	canvas.draw_line(center + Vector2(-half * 0.45, -half * 0.1), center + Vector2(0.0, -half * 0.6), Palette.SARI_YELLOW, 3.0)
	canvas.draw_line(center + Vector2(half * 0.45, -half * 0.1), center + Vector2(0.0, -half * 0.6), Palette.SARI_YELLOW, 3.0)
