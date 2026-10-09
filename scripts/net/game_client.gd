class_name GameClient
extends RefCounted
## Client side of the network game. Talks to the server over WebSocket, keeps the
## room state, and during a match keeps a mirror MatchSim for the views:
## the local player's movement is predicted and reconciled with the server, other
## players are drawn `interpolation_delay` in the past between two snapshots.
## Drive it with poll(delta); the Net autoload does that every frame.

signal connection_changed(online: bool)
## The server answered HELLO; `reconnected` = we got our match slot back.
signal welcomed(reconnected: bool)
signal error_received(text: String)
signal room_changed(room: Dictionary)
## The host started: build the match scene from `info`, then call loaded().
signal match_loading(info: Dictionary)
## "pick" (10 s weapon pick) or "play" (loadouts are final).
signal stage_changed(stage: String)
signal snapshot_applied

var player_name: String = ""
## Stable id in the room and the match (-1 before joining a room).
var player_id: int = -1
## Secret to take the slot back after a dropped connection (kept by Session).
var token: String = ""
var room: Dictionary = {}
var match_info: Dictionary = {}
var stage: String = ""
var stage_time: float = 0.0
## The client's copy of the match, read by the views.
var mirror: MatchSim

var _rules: GameRules
var _layout: MapLayout
var _net: NetRules
var _peer: WebSocketMultiplayerPeer
var _was_online: bool = false
var _pending: Array[PlayerInput] = []
var _clock: float = 0.0
## Snapshots of other players' positions: {"time": float, "pos": {id: Vector2}}.
var _buffer: Array[Dictionary] = []


func _init(rules: GameRules, layout: MapLayout, net: NetRules) -> void:
	_rules = rules
	_layout = layout
	_net = net


func connect_to(url: String) -> Error:
	close()
	_peer = WebSocketMultiplayerPeer.new()
	return _peer.create_client(url)


func close() -> void:
	if _peer != null:
		_peer.close()
		_peer = null
	if _was_online:
		_was_online = false
		connection_changed.emit(false)


func is_online() -> bool:
	return _peer != null and _peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func is_connecting() -> bool:
	return _peer != null and _peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING


func in_match() -> bool:
	return mirror != null


func poll(delta: float) -> void:
	_clock += delta
	if stage_time > 0.0:
		stage_time = maxf(0.0, stage_time - delta)
	if _peer == null:
		return
	_peer.poll()
	var online: bool = is_online()
	if online != _was_online:
		_was_online = online
		connection_changed.emit(online)
		if online:
			send({"t": NetProtocol.Msg.HELLO, "name": player_name, "token": token})
	if _peer == null:
		return
	if _peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		close()
		return
	while _peer != null and _peer.get_available_packet_count() > 0:
		var message: Dictionary = NetProtocol.decode(_peer.get_packet())
		if not message.is_empty():
			_handle(message)


func send(message: Dictionary) -> void:
	if not is_online():
		return
	_peer.set_target_peer(MultiplayerPeer.TARGET_PEER_SERVER)
	_peer.put_packet(NetProtocol.encode(message))


# ---- lobby -----------------------------------------------------------------------

func create_room(team_size: int) -> void:
	send({"t": NetProtocol.Msg.CREATE_ROOM, "size": team_size})


func join_room(code: String) -> void:
	send({"t": NetProtocol.Msg.JOIN_ROOM, "code": code})


func pick_team(team: int) -> void:
	send({"t": NetProtocol.Msg.PICK_TEAM, "team": team})


func set_ready(ready: bool) -> void:
	send({"t": NetProtocol.Msg.SET_READY, "ready": ready})


func start_match() -> void:
	send({"t": NetProtocol.Msg.START})


func leave_room() -> void:
	send({"t": NetProtocol.Msg.LEAVE})
	room = {}
	player_id = -1
	token = ""
	mirror = null
	stage = ""


func is_host() -> bool:
	return not room.is_empty() and room.get("host", -1) == player_id


func my_team() -> int:
	for member: Dictionary in room.get("members", []) as Array:
		if member["player_id"] == player_id:
			return member["team"] as int
	return -1


# ---- match -------------------------------------------------------------------------

func loaded() -> void:
	send({"t": NetProtocol.Msg.LOADED})


func pick_weapons(first: StringName, second: StringName) -> void:
	send({"t": NetProtocol.Msg.PICK_WEAPONS, "a": first, "b": second})


func swap_weapons(first: StringName, second: StringName) -> void:
	send({"t": NetProtocol.Msg.SWAP_WEAPONS, "a": first, "b": second})


## Sends this tick's input and moves the local player right away (prediction).
func send_input(input: PlayerInput, dt: float) -> void:
	if mirror == null:
		return
	send(NetProtocol.input_to_dict(input))
	if stage != "play":
		return
	_pending.append(input)
	mirror.predict_move(player_id, input, dt)


## Places the other players between the two snapshots around (now - delay).
func interpolate() -> void:
	if mirror == null or _buffer.is_empty():
		return
	var render_time: float = _clock - _net.interpolation_delay
	var older: Dictionary = _buffer[0]
	var newer: Dictionary = _buffer[0]
	for entry: Dictionary in _buffer:
		if (entry["time"] as float) <= render_time:
			older = entry
			newer = entry
		else:
			newer = entry
			break
	var span: float = (newer["time"] as float) - (older["time"] as float)
	var weight: float = 0.0 if span <= 0.0 else clampf((render_time - (older["time"] as float)) / span, 0.0, 1.0)
	var from: Dictionary = older["pos"] as Dictionary
	var to: Dictionary = newer["pos"] as Dictionary
	for id: int in mirror.players:
		if id == player_id or not from.has(id) or not to.has(id):
			continue
		mirror.players[id].position = (from[id] as Vector2).lerp(to[id] as Vector2, weight)


func _handle(message: Dictionary) -> void:
	var M := NetProtocol.Msg
	match message["t"] as int:
		M.WELCOME:
			welcomed.emit(message.get("reconnected", false) as bool)
		M.ERROR:
			error_received.emit(message.get("text", "") as String)
		M.ROOM:
			room = message
			player_id = message.get("you", -1) as int
			token = message.get("token", "") as String
			room_changed.emit(room)
		M.MATCH_LOADING:
			_build_mirror(message)
			match_loading.emit(message)
		M.MATCH_PLAY:
			_on_stage(message)
		M.SNAPSHOT:
			_on_snapshot(message)
		M.EVENTS:
			_on_events(message.get("list", []) as Array)


func _build_mirror(info: Dictionary) -> void:
	if mirror != null and match_info.get("seed", -1) == info.get("seed", -2):
		# reconnected into the same match: keep the mirror the views already use
		_pending.clear()
		_buffer.clear()
		return
	match_info = info
	mirror = MatchSim.new(_rules, _layout, info.get("seed", 0) as int)
	for entry: Dictionary in info.get("players", []) as Array:
		var state: PlayerState = mirror.add_player(entry["id"] as int, entry["team"] as int)
		state.character_id = entry.get("char", &"") as StringName
	_pending.clear()
	_buffer.clear()
	stage = "loading"


func _on_stage(message: Dictionary) -> void:
	stage = message.get("stage", "") as String
	stage_time = message.get("time", 0.0) as float
	if mirror != null:
		var loadouts: Dictionary = message.get("loadouts", {}) as Dictionary
		for id: Variant in loadouts:
			var pair: Array = loadouts[id] as Array
			if pair.size() == 2 and mirror.players.has(id as int):
				mirror.set_loadout(id as int, pair[0] as StringName, pair[1] as StringName)
	stage_changed.emit(stage)


func _on_snapshot(data: Dictionary) -> void:
	if mirror == null:
		return
	Snapshot.apply(mirror, data, player_id)
	var positions: Dictionary = {}
	var server_position: Vector2 = Vector2.ZERO
	var have_local: bool = false
	for entry: Dictionary in data.get("players", []) as Array:
		var id: int = entry["id"] as int
		positions[id] = entry["pos"] as Vector2
		if id == player_id:
			server_position = entry["pos"] as Vector2
			have_local = true
	_buffer.append({"time": _clock, "pos": positions})
	while _buffer.size() > 4:
		_buffer.pop_front()
	if have_local:
		_reconcile(server_position, (data.get("acks", {}) as Dictionary).get(player_id, -1) as int)
	snapshot_applied.emit()


## Server position as of the last input it used, then the newer inputs replayed.
func _reconcile(server_position: Vector2, ack: int) -> void:
	var local: PlayerState = mirror.players.get(player_id) as PlayerState
	if local == null:
		return
	while not _pending.is_empty() and _pending[0].tick <= ack:
		_pending.pop_front()
	local.position = server_position
	var dt: float = _rules.tick_dt()
	for input: PlayerInput in _pending:
		mirror.predict_move(player_id, input, dt)


func _on_events(list: Array) -> void:
	if mirror == null:
		return
	var targets: Dictionary[String, Object] = {
		"sim": mirror, "weapons": mirror.weapons, "ball": mirror.ball, "tricycle": mirror.tricycle,
	}
	for event: Array in list:
		if event.size() != 3 or not targets.has(event[0] as String):
			continue
		var args: Array = (event[2] as Array).duplicate()
		if event[1] == "cone_struck" and args.size() == 4:
			args[1] = mirror.weapon_defs.get(args[1] as StringName)
			if args[1] == null:
				continue
		var call_args: Array = [event[1] as StringName]
		call_args.append_array(args)
		targets[event[0] as String].callv("emit_signal", call_args)
