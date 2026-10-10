extends GutTest

const BOOT_SCENE: PackedScene = preload("res://scenes/ui/boot_screen.tscn")


func test_the_fill_runs_from_the_left_end_to_the_right_end() -> void:
	assert_almost_eq(BootScreen.fill_width(0.0, 1000.0), 1000.0 * BootScreen.BAR_INSET, 0.01)
	assert_almost_eq(BootScreen.fill_width(1.0, 1000.0), 1000.0 * (1.0 - BootScreen.BAR_INSET), 0.01)
	assert_gt(BootScreen.fill_width(0.6, 1000.0), BootScreen.fill_width(0.3, 1000.0))


func test_the_icon_rides_the_end_of_the_filled_part() -> void:
	var root: Control = autofree(Control.new()) as Control
	root.size = Vector2(720.0, 1280.0)
	add_child(root)
	var boot: BootScreen = BOOT_SCENE.instantiate() as BootScreen
	root.add_child(boot)
	boot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	boot.set_process(false)
	boot.progress = 0.5
	boot._layout()
	var icon: TextureRect = boot._icon_rect
	var track: TextureRect = boot._track_rect
	var centre_x: float = icon.position.x + icon.size.x * 0.5
	assert_almost_eq(centre_x, track.position.x + BootScreen.fill_width(0.5, track.size.x), 0.5)
	assert_gt(track.position.y, 900.0, "the bar sits in the bottom part")
	assert_lt(track.position.y + track.size.y, 1280.0)
	boot.queue_free()


func test_every_scene_it_warms_up_exists() -> void:
	for path: String in BootScreen.WARM_SCENES:
		assert_true(ResourceLoader.exists(path), path)
