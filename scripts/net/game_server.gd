class_name GameServer
extends RefCounted
## Headless authoritative server: a WebSocketMultiplayerPeer used as a plain packet
## pipe (no RPC), the room service, and one ServerMatch per started room.
## Drive it with poll(delta); the server scene does that every frame.

signal log_message(text: String)

var rooms: RoomService
var matches: Dictionary[String, ServerMatch] = {}

var _rules: GameRules
var _layout: MapLayout
var _net: NetRules
var _peer: WebSocketMultiplayerPeer
var _names: Dictionary[int, String] = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(rules: GameRules, layout: MapLayout, net: NetRules, seed_value: int) -> void:
	_rules = rules
	_layout = layout
	_net = net
	_rng.seed = seed_value
	rooms = RoomService.new(net, seed_value)


func listen(port: int) -> Error:
	_peer = WebSocketMultiplayerPeer.new()
	var error: Error = _peer.create_server(port)
	if error != OK:
		return error
	_peer.peer_connected.connect(_on_peer_connected)
	_peer.peer_disconnected.connect(_on_peer_disconnected)
	log_message.emit("listening on %d" % port)
	return OK


func stop() -> void:
	if _peer != null:
		_peer.close()
		_peer = null
	for code: String in matches:
		matches[code].dispose()
	matches.clear()


func poll(delta: float) -> void:
	if _peer == null:
		return
	_peer.poll()
	while _peer != null and _peer.get_available_packet_count() > 0:
		var from: int = _peer.get_packet_peer()
		var message: Dictionary = NetProtocol.decode(_peer.get_packet())
		if not message.is_empty():
			_handle(from, message)
	rooms.step(delta)
	for code: String in matches.keys():
		if not rooms.rooms.has(code):
			matches[code].dispose()
			matches.erase(code)
			continue
		matches[code].poll(delta)


func send(peer_id: int, message: Dictionary) -> void:
	if _peer == null:
		return
	_peer.set_target_peer(peer_id)
	_peer.put_packet(NetProtocol.encode(message))


func _handle(from: int, message: Dictionary) -> void:
	var M := NetProtocol.Msg
	match message["t"] as int:
		M.HELLO:
			_names[from] = rooms.clean_name(message.get("name", "") as String)
			var member: RoomService.Member = rooms.reconnect(message.get("token", "") as String, from)
			send(from, {"t": M.WELCOME, "reconnected": member != null})
			if member != null:
				var room: RoomService.Room = rooms.room_of_peer(from)
				_send_room(room)
				var running: ServerMatch = matches.get(room.code) as ServerMatch
				if running != null:
					send(from, running.info())
					send(from, running.stage_message())
		M.CREATE_ROOM:
			var room: RoomService.Room = rooms.create_room(from, _names.get(from, "") as String, message.get("size", 1) as int)
			if room == null:
				_error(from, "Can't create a room right now.")
			else:
				_send_room(room)
		M.JOIN_ROOM:
			var result: RoomService.Result = rooms.join(message.get("code", "") as String, from, _names.get(from, "") as String)
			match result:
				RoomService.Result.OK:
					_send_room(rooms.room_of_peer(from))
				RoomService.Result.NOT_FOUND:
					_error(from, "No room with that code.")
				RoomService.Result.FULL:
					_error(from, "That room is full.")
				RoomService.Result.IN_PROGRESS:
					_error(from, "That match has already started.")
				_:
					_error(from, "Leave your room first.")
		M.PICK_TEAM:
			if rooms.pick_team(from, message.get("team", 0) as int):
				_send_room(rooms.room_of_peer(from))
		M.SET_READY:
			if rooms.set_ready(from, message.get("ready", false) as bool):
				_send_room(rooms.room_of_peer(from))
		M.START:
			if rooms.start(from):
				var room: RoomService.Room = rooms.room_of_peer(from)
				var started: ServerMatch = ServerMatch.new(self, room, _rules, _layout, _net, _rng.randi())
				matches[room.code] = started
				_send_room(room)
				for m: RoomService.Member in room.members:
					send(m.peer_id, started.info())
			else:
				_error(from, "Not everyone is ready yet.")
		M.LEAVE:
			var left: RoomService.Room = rooms.disconnected(from)
			if left != null:
				_send_room(left)
		M.LOADED, M.PICK_WEAPONS, M.SWAP_WEAPONS, M.INPUT:
			_handle_match(from, message)


func _handle_match(from: int, message: Dictionary) -> void:
	var member: RoomService.Member = rooms.member_of_peer(from)
	var room: RoomService.Room = rooms.room_of_peer(from)
	if member == null or room == null or not matches.has(room.code):
		return
	var running: ServerMatch = matches[room.code]
	var M := NetProtocol.Msg
	match message["t"] as int:
		M.LOADED:
			running.loaded(member.player_id)
		M.PICK_WEAPONS:
			running.pick(member.player_id, message.get("a", &"") as StringName, message.get("b", &"") as StringName)
		M.SWAP_WEAPONS:
			running.swap(member.player_id, message.get("a", &"") as StringName, message.get("b", &"") as StringName)
		M.INPUT:
			running.queue_input(member.player_id, NetProtocol.input_from_dict(message))


## ROOM goes to every connected member, each with their own id and reconnect token.
func _send_room(room: RoomService.Room) -> void:
	if room == null:
		return
	var description: Dictionary = rooms.describe(room)
	for m: RoomService.Member in room.members:
		if m.connected:
			var message: Dictionary = description.duplicate()
			message["t"] = NetProtocol.Msg.ROOM
			message["you"] = m.player_id
			message["token"] = m.token
			send(m.peer_id, message)


func _error(peer_id: int, text: String) -> void:
	send(peer_id, {"t": NetProtocol.Msg.ERROR, "text": text})


func _on_peer_connected(id: int) -> void:
	log_message.emit("peer %d connected" % id)


func _on_peer_disconnected(id: int) -> void:
	log_message.emit("peer %d disconnected" % id)
	_names.erase(id)
	var room: RoomService.Room = rooms.disconnected(id)
	if room != null:
		_send_room(room)
