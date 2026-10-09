extends Node
## Local player / room state that outlives scenes: the name to show, what the
## lobby should open with, and the reconnect token (saved, so a reloaded page can
## take its slot back within the reconnect window).

const SAVE_PATH: String = "user://session.cfg"

var player_name: String = ""
var room_code: String = ""
## LobbyScreen.Intent (CREATE or JOIN) chosen on the title screen.
var lobby_intent: int = 0
var reconnect_token: String = ""
var reconnect_url: String = ""


func _ready() -> void:
	var file: ConfigFile = ConfigFile.new()
	if file.load(SAVE_PATH) == OK:
		player_name = file.get_value("player", "name", "") as String
		reconnect_token = file.get_value("match", "token", "") as String
		reconnect_url = file.get_value("match", "url", "") as String


func save() -> void:
	var file: ConfigFile = ConfigFile.new()
	file.set_value("player", "name", player_name)
	file.set_value("match", "token", reconnect_token)
	file.set_value("match", "url", reconnect_url)
	file.save(SAVE_PATH)
