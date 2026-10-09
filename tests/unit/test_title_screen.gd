extends GutTest

const TITLE_SCENE: PackedScene = preload("res://scenes/ui/title_screen.tscn")


func test_version_label_matches_project_setting() -> void:
	var screen: TitleScreen = autofree(TITLE_SCENE.instantiate()) as TitleScreen
	add_child(screen)
	var label: Label = screen.get_node("%VersionLabel") as Label
	var version: String = str(ProjectSettings.get_setting("application/config/version"))
	assert_eq(label.text, "v" + version)


func test_a_normal_run_is_not_the_server() -> void:
	assert_false(TitleScreen.is_server_run(), "tests run without --server or the dedicated_server feature")


func test_server_scene_and_lobby_scene_exist() -> void:
	assert_true(ResourceLoader.exists(TitleScreen.SERVER_SCENE))
	assert_true(ResourceLoader.exists(TitleScreen.LOBBY_SCENE))
