extends Node
## Network connection for the whole app: owns the GameClient and polls it every
## frame so it survives scene changes (lobby -> loading -> match).

signal connected
signal disconnected

const RULES: GameRules = preload("res://data/rules/game_rules.tres")
const LAYOUT: MapLayout = preload("res://data/rules/map_layout.tres")
const NET_RULES: NetRules = preload("res://data/rules/net_rules.tres")

var client: GameClient = GameClient.new(RULES, LAYOUT, NET_RULES)
var is_online: bool = false


func _ready() -> void:
	client.connection_changed.connect(_on_connection_changed)


func _process(delta: float) -> void:
	client.poll(delta)


func _on_connection_changed(online: bool) -> void:
	is_online = online
	if online:
		connected.emit()
	else:
		disconnected.emit()
