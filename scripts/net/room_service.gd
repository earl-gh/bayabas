class_name RoomService
extends RefCounted
## Private passcode rooms (docs/GDD.md "Lobby rules"). Pure logic, no sockets:
## the GameServer feeds it peer ids and sends out whatever changed.
##
## A member keeps one stable `player_id` for the whole match (it is their id in
## the MatchSim); `peer_id` is their current connection and changes on reconnect.

enum Result { OK, NOT_FOUND, FULL, IN_PROGRESS, NOT_ALLOWED }
enum State { LOBBY, LOADING, PLAYING, ENDED }


class Member extends RefCounted:
	var player_id: int
	var peer_id: int
	var name: String
	## -1 = no team slot picked yet.
	var team: int = -1
	var ready: bool = false
	var connected: bool = true
	## Seconds left to reconnect after dropping out of a running match.
	var reconnect_left: float = 0.0
	## Secret handed to the client so it can take its slot back after a drop.
	var token: String = ""


class Room extends RefCounted:
	var code: String
	var team_size: int
	var host_player_id: int
	var state: State = State.LOBBY
	var members: Array[Member] = []

	func member(player_id: int) -> Member:
		for m: Member in members:
			if m.player_id == player_id:
				return m
		return null

	func team_count(team: int) -> int:
		var count: int = 0
		for m: Member in members:
			if m.team == team:
				count += 1
		return count


var rooms: Dictionary[String, Room] = {}

var _rules: NetRules
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _next_player_id: int = 1
## peer id -> room code, for connected members.
var _peer_rooms: Dictionary[int, String] = {}


func _init(rules: NetRules, seed_value: int) -> void:
	_rules = rules
	_rng.seed = seed_value


func clean_name(raw: String) -> String:
	var text: String = raw.strip_edges().left(_rules.max_name_length)
	return text if not text.is_empty() else "Player"


func room_of_peer(peer_id: int) -> Room:
	var code: String = _peer_rooms.get(peer_id, "") as String
	return rooms.get(code) as Room


func member_of_peer(peer_id: int) -> Member:
	var room: Room = room_of_peer(peer_id)
	if room == null:
		return null
	for m: Member in room.members:
		if m.peer_id == peer_id and m.connected:
			return m
	return null


## Creates a room for 1v1 (team_size 1), 2v2 or 3v3; the creator joins as host.
func create_room(peer_id: int, player_name: String, team_size: int) -> Room:
	if room_of_peer(peer_id) != null or team_size < 1 or team_size > 3:
		return null
	var room: Room = Room.new()
	room.code = _new_code()
	room.team_size = team_size
	rooms[room.code] = room
	var host: Member = _add_member(room, peer_id, player_name)
	room.host_player_id = host.player_id
	return room


func join(code: String, peer_id: int, player_name: String) -> Result:
	var room: Room = rooms.get(code.strip_edges().to_upper()) as Room
	if room == null:
		return Result.NOT_FOUND
	if room.state != State.LOBBY:
		return Result.IN_PROGRESS
	if room.members.size() >= room.team_size * 2:
		return Result.FULL
	if room_of_peer(peer_id) != null:
		return Result.NOT_ALLOWED
	_add_member(room, peer_id, player_name)
	return Result.OK


## Moves a member to a team slot (0 or 1) if it has room. Un-readies them.
func pick_team(peer_id: int, team: int) -> bool:
	var room: Room = room_of_peer(peer_id)
	var m: Member = member_of_peer(peer_id)
	if m == null or room.state != State.LOBBY or team < 0 or team > 1 or m.team == team:
		return false
	if room.team_count(team) >= room.team_size:
		return false
	m.team = team
	m.ready = false
	return true


func set_ready(peer_id: int, ready: bool) -> bool:
	var room: Room = room_of_peer(peer_id)
	var m: Member = member_of_peer(peer_id)
	if m == null or room.state != State.LOBBY or (ready and m.team < 0):
		return false
	m.ready = ready
	return true


## GDD: every present player is Ready and has a team; one team has N players and
## the other at least N-1 (1v1 needs both players).
func can_start(room: Room) -> bool:
	if room.state != State.LOBBY:
		return false
	for m: Member in room.members:
		if not m.ready or m.team < 0:
			return false
	var a: int = room.team_count(0)
	var b: int = room.team_count(1)
	var n: int = room.team_size
	if n == 1:
		return a == 1 and b == 1
	return (a == n and b >= n - 1) or (b == n and a >= n - 1)


## Host only. The room moves to LOADING.
func start(peer_id: int) -> bool:
	var room: Room = room_of_peer(peer_id)
	var m: Member = member_of_peer(peer_id)
	if m == null or m.player_id != room.host_player_id or not can_start(room):
		return false
	room.state = State.LOADING
	return true


## Leaving the lobby (or a lost connection there). The next member becomes host;
## an empty room is closed. Returns the room (or null if it closed).
func leave(peer_id: int) -> Room:
	var room: Room = room_of_peer(peer_id)
	var m: Member = member_of_peer(peer_id)
	_peer_rooms.erase(peer_id)
	if room == null or m == null:
		return null
	room.members.erase(m)
	if room.members.is_empty():
		rooms.erase(room.code)
		return null
	if room.host_player_id == m.player_id:
		room.host_player_id = room.members[0].player_id
	return room


## A connection dropped. In the lobby that is a leave; in a running match the slot
## is kept and the player has `reconnect_window` seconds to come back.
func disconnected(peer_id: int) -> Room:
	var room: Room = room_of_peer(peer_id)
	if room == null:
		return null
	if room.state == State.LOBBY:
		return leave(peer_id)
	var m: Member = member_of_peer(peer_id)
	_peer_rooms.erase(peer_id)
	if m != null:
		m.connected = false
		m.reconnect_left = _rules.reconnect_window
	return room


## Takes a dropped slot back with its token. Returns the member, or null.
func reconnect(token: String, peer_id: int) -> Member:
	if token.is_empty() or room_of_peer(peer_id) != null:
		return null
	for code: String in rooms:
		for m: Member in rooms[code].members:
			if m.token == token and not m.connected and m.reconnect_left > 0.0:
				m.connected = true
				m.peer_id = peer_id
				m.reconnect_left = 0.0
				_peer_rooms[peer_id] = code
				return m
	return null


## Counts reconnect windows down. A slot whose window ran out stays in the match
## (the player just stands still); its token stops working.
func step(dt: float) -> void:
	for code: String in rooms.keys():
		var room: Room = rooms[code]
		var anyone: bool = false
		for m: Member in room.members:
			if not m.connected and m.reconnect_left > 0.0:
				m.reconnect_left = maxf(0.0, m.reconnect_left - dt)
			if m.connected or m.reconnect_left > 0.0:
				anyone = true
		if not anyone:
			rooms.erase(code)


## Plain data for the ROOM message.
func describe(room: Room) -> Dictionary:
	var members: Array[Dictionary] = []
	for m: Member in room.members:
		members.append({
			"player_id": m.player_id, "name": m.name, "team": m.team,
			"ready": m.ready, "connected": m.connected,
		})
	return {
		"code": room.code, "team_size": room.team_size, "host": room.host_player_id,
		"state": room.state, "members": members, "can_start": can_start(room),
	}


func _add_member(room: Room, peer_id: int, player_name: String) -> Member:
	var m: Member = Member.new()
	m.player_id = _next_player_id
	_next_player_id += 1
	m.peer_id = peer_id
	m.name = clean_name(player_name)
	m.token = "%08x%08x" % [_rng.randi(), _rng.randi()]
	# drop into the smaller team (ties go to team 0)
	var team: int = 0 if room.team_count(0) <= room.team_count(1) else 1
	if room.team_count(team) < room.team_size:
		m.team = team
	room.members.append(m)
	_peer_rooms[peer_id] = room.code
	return m


func _new_code() -> String:
	while true:
		var code: String = ""
		for i: int in _rules.passcode_length:
			code += _rules.passcode_alphabet[_rng.randi_range(0, _rules.passcode_alphabet.length() - 1)]
		if not rooms.has(code):
			return code
	return ""
