extends GutTest

const TITLE_SCENE: PackedScene = preload("res://scenes/ui/title_screen.tscn")


func test_version_label_matches_project_setting() -> void:
	var screen: TitleScreen = autofree(TITLE_SCENE.instantiate()) as TitleScreen
	add_child(screen)
	var label: Label = screen.get_node("%VersionLabel") as Label
	var version: String = str(ProjectSettings.get_setting("application/config/version"))
	assert_eq(label.text, "v" + version)


func test_stub_button_sets_status() -> void:
	var screen: TitleScreen = autofree(TITLE_SCENE.instantiate()) as TitleScreen
	add_child(screen)
	(screen.get_node("%PracticeButton") as Button).pressed.emit()
	assert_eq((screen.get_node("%StatusLabel") as Label).text, "Practice: coming soon")
