class_name IconView
extends Control
## Draws one Icons icon centred in this control (e.g. on weapon pick cards).

@export var icon_id: StringName = &""


func _draw() -> void:
	Icons.draw(self, icon_id, size / 2.0, minf(size.x, size.y) * 0.75)
