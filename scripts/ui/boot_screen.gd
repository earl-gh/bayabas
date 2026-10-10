class_name BootScreen
extends Control
## Boot screen: the key art with a cardboard loading bar at the bottom. The K!
## icon rides the end of the filled part. It loads the scenes the player is about
## to open, then hands over to the title screen. A dedicated server skips it.

const TITLE_SCENE: String = "res://scenes/ui/title_screen.tscn"
const WARM_SCENES: Array[String] = [
	"res://scenes/ui/title_screen.tscn",
	"res://scenes/ui/lobby.tscn",
	"res://scenes/match/practice.tscn",
]
const BACKGROUND: Texture2D = preload("res://assets/ui/boot/boot_bg.webp")
const TRACK: Texture2D = preload("res://assets/ui/boot/boot_bar_track.png")
const FILL: Texture2D = preload("res://assets/ui/boot/boot_bar_fill.png")
const ICON: Texture2D = preload("res://assets/ui/boot/boot_icon.png")

const BAR_WIDTH_FRACTION: float = 0.84
const BAR_BOTTOM_MARGIN: float = 84.0
## Where the rounded ends of the bar start, as a fraction of its width.
const BAR_INSET: float = 0.075
const ICON_HEIGHT_RATIO: float = 1.15
## The bar never fills faster than this, so the screen is seen even when loading is instant.
const MAX_FILL_PER_SECOND: float = 0.7

signal finished

var progress: float = 0.0
var _loaded: float = 0.0
var _done: bool = false
var _fill_clip: Control
var _fill_rect: TextureRect
var _track_rect: TextureRect
var _icon_rect: TextureRect


## Width of the filled part of a bar `width` wide at `progress` (0..1): it starts
## at the left rounded end and finishes at the right one.
static func fill_width(fraction: float, width: float, inset: float = BAR_INSET) -> float:
	var edge: float = width * inset
	return edge + (width - 2.0 * edge) * clampf(fraction, 0.0, 1.0)


func _ready() -> void:
	if TitleScreen.is_server_run():
		get_tree().change_scene_to_file.call_deferred(TitleScreen.SERVER_SCENE)
		set_process(false)
		return
	_build()
	resized.connect(_layout)
	_layout()
	for path: String in WARM_SCENES:
		ResourceLoader.load_threaded_request(path)


func _build() -> void:
	var background: TextureRect = TextureRect.new()
	background.texture = BACKGROUND
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_track_rect = _bar_layer(TRACK)
	_fill_clip = Control.new()
	_fill_clip.clip_contents = true
	_fill_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fill_clip)
	_fill_rect = _bar_layer(FILL, _fill_clip)
	_icon_rect = TextureRect.new()
	_icon_rect.texture = ICON
	_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon_rect)


func _bar_layer(texture: Texture2D, parent: Control = self) -> TextureRect:
	var rect: TextureRect = TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect


func _layout() -> void:
	if _track_rect == null:
		return
	var bar_size: Vector2 = Vector2(size.x * BAR_WIDTH_FRACTION, 0.0)
	bar_size.y = bar_size.x * float(TRACK.get_height()) / float(TRACK.get_width())
	var origin: Vector2 = Vector2((size.x - bar_size.x) * 0.5, size.y - BAR_BOTTOM_MARGIN - bar_size.y)
	_track_rect.position = origin
	_track_rect.size = bar_size
	_fill_clip.position = origin
	_fill_rect.position = Vector2.ZERO
	_fill_rect.size = bar_size
	var icon_size: float = bar_size.y * ICON_HEIGHT_RATIO
	_icon_rect.size = Vector2(icon_size, icon_size)
	_icon_rect.pivot_offset = _icon_rect.size * 0.5
	_apply_progress()


func _apply_progress() -> void:
	if _track_rect == null:
		return
	var width: float = fill_width(progress, _track_rect.size.x)
	_fill_clip.size = Vector2(width, _track_rect.size.y)
	_icon_rect.position = _track_rect.position + Vector2(width, _track_rect.size.y * 0.5) - _icon_rect.size * 0.5


func _process(delta: float) -> void:
	if _done or _track_rect == null:
		return
	_loaded = _loading_fraction()
	progress = minf(_loaded, progress + MAX_FILL_PER_SECOND * delta)
	_apply_progress()
	_icon_rect.rotation_degrees = sin(Time.get_ticks_msec() / 1000.0 * 7.0) * 4.0
	if progress >= 1.0:
		_done = true
		finished.emit()
		var packed: PackedScene = ResourceLoader.load_threaded_get(TITLE_SCENE) as PackedScene
		get_tree().change_scene_to_packed(packed)


## Average load progress of the scenes being warmed up (0..1).
func _loading_fraction() -> float:
	var total: float = 0.0
	for path: String in WARM_SCENES:
		var info: Array = []
		var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(path, info)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			total += 1.0
		elif status == ResourceLoader.THREAD_LOAD_IN_PROGRESS and not info.is_empty():
			total += float(info[0])
	return total / float(WARM_SCENES.size())
