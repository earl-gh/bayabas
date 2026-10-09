class_name TitleScreen
extends Control
## Title screen. Practice opens the greybox map for now; room buttons are stubs.

@onready var _version_label: Label = %VersionLabel
@onready var _status_label: Label = %StatusLabel
@onready var _practice_button: Button = %PracticeButton
@onready var _create_button: Button = %CreateRoomButton
@onready var _join_button: Button = %JoinRoomButton


func _ready() -> void:
	_version_label.text = "v%s" % ProjectSettings.get_setting("application/config/version", "0.0.0")
	_practice_button.pressed.connect(_on_practice_pressed)
	_create_button.pressed.connect(_on_stub_pressed.bind("Create Room"))
	_join_button.pressed.connect(_on_stub_pressed.bind("Join Room"))


func _on_practice_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/map/greybox_map.tscn")


func _on_stub_pressed(label: String) -> void:
	_status_label.text = "%s: coming soon" % label
