class_name Icons
extends RefCounted
## Skill and HUD icons: the painted PNGs in assets/icons/ (the skill buttons are
## btn_<skill>.png from tools/art/make_buttons.py).

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


## Draws icon `id` centred at `center`, about `size` px across. A missing image is an
## error (there is no drawn stand-in).
static func draw(canvas: CanvasItem, id: StringName, center: Vector2, size: float) -> void:
	var texture: Texture2D = art(id)
	if texture == null:
		push_error("missing icon art: %s" % id)
		return
	var side: float = size * ART_SCALE
	canvas.draw_texture_rect(texture, Rect2(center - Vector2(side, side) / 2.0, Vector2(side, side)), false)
