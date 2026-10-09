class_name TitleScreen
extends Control
## Title screen. Practice opens the offline practice match; Create / Join Room
## open the online lobby. A dedicated server build goes straight to the server.

const SERVER_SCENE: String = "res://server/main.tscn"
const LOBBY_SCENE: String = "res://scenes/ui/lobby.tscn"

@onready var _version_label: Label = %VersionLabel
@onready var _status_label: Label = %StatusLabel
@onready var _practice_button: Button = %PracticeButton
@onready var _create_button: Button = %CreateRoomButton
@onready var _join_button: Button = %JoinRoomButton


## True for the dedicated server export or `godot --headless -- --server`.
static func is_server_run() -> bool:
	return OS.has_feature("dedicated_server") or OS.get_cmdline_user_args().has("--server")


func _ready() -> void:
	if is_server_run():
		get_tree().change_scene_to_file.call_deferred(SERVER_SCENE)
		return
	_version_label.text = "v%s" % ProjectSettings.get_setting("application/config/version", "0.0.0")
	_practice_button.pressed.connect(_on_practice_pressed)
	_create_button.pressed.connect(_open_lobby.bind(LobbyScreen.Intent.CREATE))
	_join_button.pressed.connect(_open_lobby.bind(LobbyScreen.Intent.JOIN))


func _on_practice_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/match/practice.tscn")


func _open_lobby(intent: LobbyScreen.Intent) -> void:
	Session.lobby_intent = intent
	get_tree().change_scene_to_file(LOBBY_SCENE)
