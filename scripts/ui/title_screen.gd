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


const BACKDROP_KIDS: Array[StringName] = [&"toni", &"popoy", &"ligaya"]
const CAMERA_START: Vector3 = Vector3(0.0, 3.4, 6.2)
const CAMERA_TARGET_Y: float = 5.0
const CAMERA_TARGET_Z: float = -3.0

var _backdrop_camera: Camera3D
var _backdrop_kids: Array[KidModel] = []
var _backdrop_time: float = 0.0


func _ready() -> void:
	if is_server_run():
		get_tree().change_scene_to_file.call_deferred(SERVER_SCENE)
		return
	_build_backdrop()
	_animate_in()
	_version_label.text = "v%s" % ProjectSettings.get_setting("application/config/version", "0.0.0")
	_practice_button.pressed.connect(_on_practice_pressed)
	_create_button.pressed.connect(_open_lobby.bind(LobbyScreen.Intent.CREATE))
	_join_button.pressed.connect(_open_lobby.bind(LobbyScreen.Intent.JOIN))


func _on_practice_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/match/practice.tscn")


func _open_lobby(intent: LobbyScreen.Intent) -> void:
	Session.lobby_intent = intent
	get_tree().change_scene_to_file(LOBBY_SCENE)


## Buttons slide up and fade in one after another; the guava sways and pulses.
func _animate_in() -> void:
	var guava: Control = %Guava
	guava.pivot_offset = guava.size / 2.0
	var sway: Tween = create_tween().set_loops()
	sway.tween_property(guava, "rotation_degrees", 7.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sway.tween_property(guava, "rotation_degrees", -7.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var pulse: Tween = create_tween().set_loops()
	pulse.tween_property(guava, "scale", Vector2.ONE * 1.08, 0.6).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(guava, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SINE)
	var buttons: Array[Button] = [_practice_button, _create_button, _join_button]
	for i: int in buttons.size():
		var button: Button = buttons[i]
		button.modulate.a = 0.0
		button.pivot_offset = button.custom_minimum_size / 2.0
		button.scale = Vector2.ONE * 0.85
		var tween: Tween = create_tween().set_parallel(true)
		tween.tween_property(button, "modulate:a", 1.0, 0.25).set_delay(0.15 + 0.12 * i)
		tween.tween_property(button, "scale", Vector2.ONE, 0.35).set_delay(0.15 + 0.12 * i).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A live 3D street behind the title: the camera drifts across the street and
## three kids idle in front of it. The nodes render in the main 3D world, under
## the 2D menu.
func _build_backdrop() -> void:
	var rules: GameRules = load("res://data/rules/game_rules.tres") as GameRules
	var map: StreetMap = (load("res://scenes/map/street_map.tscn") as PackedScene).instantiate() as StreetMap
	map.show_overview_camera = false
	map.get_node("Hud").queue_free()
	add_child(map)
	_backdrop_camera = Camera3D.new()
	_backdrop_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_backdrop_camera.fov = 58.0
	_backdrop_camera.environment = StreetMap.make_environment()
	_backdrop_camera.position = CAMERA_START
	add_child(_backdrop_camera)
	_backdrop_camera.current = true
	_backdrop_camera.look_at(Vector3(0.0, CAMERA_TARGET_Y, CAMERA_TARGET_Z), Vector3.UP)
	var by_id: Dictionary[StringName, CharacterDef] = {}
	for i: int in rules.characters.size():
		by_id[rules.characters[i].id] = rules.characters[i]
	var spots: Array[Vector3] = [Vector3(-1.9, 0.0, 0.9), Vector3(0.0, 0.0, 0.3), Vector3(1.9, 0.0, 0.9)]
	for i: int in BACKDROP_KIDS.size():
		var kid: KidModel = KidModel.new()
		kid.setup(by_id[BACKDROP_KIDS[i]], Palette.TEAM_OWN if i != 1 else Palette.TEAM_ALLY, rules.player_radius)
		kid.position = spots[i]
		kid.rotation.y = PI + (-0.4 if i == 0 else (0.0 if i == 1 else 0.4))
		add_child(kid)
		_backdrop_kids.append(kid)


func _process(delta: float) -> void:
	if _backdrop_camera == null:
		return
	_backdrop_time += delta
	var sway: float = sin(_backdrop_time * 0.4)
	_backdrop_camera.position = CAMERA_START + Vector3(sway * 1.4, sin(_backdrop_time * 0.5) * 0.25, 0.0)
	_backdrop_camera.look_at(Vector3(sway * 0.5, CAMERA_TARGET_Y, CAMERA_TARGET_Z), Vector3.UP)
	var idle: PlayerState = PlayerState.new()
	for kid: KidModel in _backdrop_kids:
		kid.animate(delta, 0.0, idle)
