class_name OrientationGate
extends CanvasLayer
## Covers the screen with a "rotate your phone" prompt when the window is wider
## than tall. Bayabas is portrait-only; this matters on the web build, where the
## browser cannot lock orientation.

@onready var _panel: Control = %Panel


static func is_landscape(size: Vector2) -> bool:
	return size.x > size.y


func _ready() -> void:
	get_viewport().size_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	apply_size(get_viewport().get_visible_rect().size)


func apply_size(size: Vector2) -> void:
	_panel.visible = is_landscape(size)
