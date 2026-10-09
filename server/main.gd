extends Node
## Headless dedicated server entry (HANDOFF M4). Started by the title screen when
## the build has the `dedicated_server` feature or is run with `-- --server`.
## Listens for WebSocket clients on $PORT (default from data/rules/net_rules.tres).

const RULES: GameRules = preload("res://data/rules/game_rules.tres")
const LAYOUT: MapLayout = preload("res://data/rules/map_layout.tres")
const NET_RULES: NetRules = preload("res://data/rules/net_rules.tres")

var server: GameServer


func _ready() -> void:
	var port: int = NET_RULES.default_port
	var from_env: String = OS.get_environment("PORT")
	if from_env.is_valid_int():
		port = from_env.to_int()
	server = GameServer.new(RULES, LAYOUT, NET_RULES, Time.get_ticks_usec())
	server.log_message.connect(func(text: String) -> void: print("[server] ", text))
	var error: Error = server.listen(port)
	if error != OK:
		push_error("could not listen on port %d (%s)" % [port, error_string(error)])
		get_tree().quit(1)


func _process(delta: float) -> void:
	server.poll(delta)


func _exit_tree() -> void:
	if server != null:
		server.stop()
