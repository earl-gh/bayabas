extends GutTest

const GATE_SCENE: PackedScene = preload("res://scenes/ui/orientation_gate.tscn")


func test_is_landscape() -> void:
	assert_true(OrientationGate.is_landscape(Vector2(1280, 720)))
	assert_false(OrientationGate.is_landscape(Vector2(720, 1280)))
	assert_false(OrientationGate.is_landscape(Vector2(500, 500)))


func test_panel_follows_size() -> void:
	var gate: OrientationGate = autofree(GATE_SCENE.instantiate()) as OrientationGate
	add_child(gate)
	var panel: Control = gate.get_node("%Panel") as Control
	gate.apply_size(Vector2(1280, 720))
	assert_true(panel.visible)
	gate.apply_size(Vector2(720, 1280))
	assert_false(panel.visible)
