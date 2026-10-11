extends Node
## User and build settings. The game server address comes from, in order:
## the web page's `?server=wss://...` query, the address saved in the lobby, or
## the project setting `kalyeah/network/server_url` (empty until a server is
## deployed, see server/README.md).

const SAVE_PATH: String = "user://settings.cfg"
const PROJECT_KEY: String = "kalyeah/network/server_url"

var server_url: String = ""

var _ui_voice: AudioStreamPlayer


func _ready() -> void:
	KalyeahTheme.apply()
	# every Button in the game clicks (menus, lobby, pick screen)
	_ui_voice = AudioStreamPlayer.new()
	_ui_voice.volume_db = -8.0
	add_child(_ui_voice)
	get_tree().node_added.connect(_on_node_added)
	server_url = ProjectSettings.get_setting(PROJECT_KEY, "") as String
	var file: ConfigFile = ConfigFile.new()
	if file.load(SAVE_PATH) == OK:
		var saved: String = file.get_value("network", "server_url", "") as String
		if not saved.is_empty():
			server_url = saved
	if OS.has_feature("web"):
		var search: Variant = JavaScriptBridge.eval("window.location.search", true)
		var from_query: String = url_from_query(search as String if search is String else "")
		if not from_query.is_empty():
			server_url = from_query


## `?server=wss%3A%2F%2Fexample.com&x=1` -> "wss://example.com".
static func url_from_query(search: String) -> String:
	var query: String = search.trim_prefix("?")
	for part: String in query.split("&", false):
		var pair: PackedStringArray = part.split("=", true, 1)
		if pair.size() == 2 and pair[0] == "server":
			return pair[1].uri_decode().strip_edges()
	return ""


## A bare host becomes wss://host (ws:// for localhost).
static func normalize_url(raw: String) -> String:
	var url: String = raw.strip_edges()
	if url.is_empty() or url.begins_with("ws://") or url.begins_with("wss://"):
		return url
	url = url.trim_prefix("https://").trim_prefix("http://")
	if url.begins_with("localhost") or url.begins_with("127.0.0.1"):
		return "ws://" + url
	return "wss://" + url


func save_server_url(url: String) -> void:
	server_url = normalize_url(url)
	var file: ConfigFile = ConfigFile.new()
	file.load(SAVE_PATH)
	file.set_value("network", "server_url", server_url)
	file.save(SAVE_PATH)


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		(node as BaseButton).pressed.connect(play_ui, CONNECT_DEFERRED)


func play_ui(id: StringName = &"ui_click") -> void:
	_ui_voice.stream = SoundBank.get_sound(id)
	_ui_voice.play()
