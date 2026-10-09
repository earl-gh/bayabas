extends GutTest

const NET: NetRules = preload("res://data/rules/net_rules.tres")
const R := RoomService.Result


func _service() -> RoomService:
	return RoomService.new(NET, 7)


func test_passcode_is_six_unambiguous_characters() -> void:
	var service: RoomService = _service()
	for peer: int in range(1, 60):
		var room: RoomService.Room = service.create_room(peer, "p", 1)
		assert_eq(room.code.length(), 6)
		for c: String in room.code:
			assert_true(NET.passcode_alphabet.contains(c), c)
			assert_false("ILO01".contains(c), "no ambiguous %s" % c)
	assert_eq(service.rooms.size(), 59, "codes are unique")


func test_create_and_join_fill_the_smaller_team() -> void:
	var service: RoomService = _service()
	var room: RoomService.Room = service.create_room(10, "Host", 2)
	assert_eq(room.members[0].team, 0)
	assert_eq(service.join(room.code.to_lower(), 11, "B"), R.OK, "codes are case-insensitive")
	assert_eq(service.join(room.code, 12, "C"), R.OK)
	assert_eq(service.join(room.code, 13, "D"), R.OK)
	assert_eq(room.team_count(0), 2)
	assert_eq(room.team_count(1), 2)
	assert_eq(service.join(room.code, 14, "E"), R.FULL)
	assert_eq(service.join("ZZZZZZ", 15, "F"), R.NOT_FOUND)


func test_names_are_trimmed_and_never_empty() -> void:
	var service: RoomService = _service()
	var room: RoomService.Room = service.create_room(1, "   ", 1)
	assert_eq(room.members[0].name, "Player")
	service.join(room.code, 2, "A very long name indeed")
	assert_eq(room.members[1].name.length(), NET.max_name_length)


func test_team_slots_and_ready() -> void:
	var service: RoomService = _service()
	var room: RoomService.Room = service.create_room(1, "A", 1)
	service.join(room.code, 2, "B")
	assert_false(service.pick_team(2, 0), "team 0 is full in 1v1")
	assert_true(service.set_ready(2, true))
	assert_true(service.pick_team(1, 1) == false, "and team 1 too")
	assert_true(room.member(room.members[1].player_id).ready)


func test_1v1_needs_both_players_ready() -> void:
	var service: RoomService = _service()
	var room: RoomService.Room = service.create_room(1, "A", 1)
	service.set_ready(1, true)
	assert_false(service.can_start(room), "alone")
	service.join(room.code, 2, "B")
	assert_false(service.can_start(room), "B not ready")
	service.set_ready(2, true)
	assert_true(service.can_start(room))
	assert_false(service.start(2), "only the host starts")
	assert_true(service.start(1))
	assert_eq(room.state, RoomService.State.LOADING)
	assert_eq(service.join(room.code, 3, "C"), R.IN_PROGRESS)


func test_3v3_starts_with_one_team_full_and_the_other_one_short() -> void:
	var service: RoomService = _service()
	var room: RoomService.Room = service.create_room(1, "A", 3)
	for peer: int in range(2, 6):
		service.join(room.code, peer, "p%d" % peer)
	# 5 players: 3 v 2
	for peer: int in range(1, 6):
		service.set_ready(peer, true)
	assert_eq(room.team_count(0), 3)
	assert_eq(room.team_count(1), 2)
	assert_true(service.can_start(room), "3 v 2 is allowed")
	service.join(room.code, 6, "p6")
	assert_false(service.can_start(room), "the new player is not ready")
	service.leave(6)
	service.leave(5)
	assert_false(service.can_start(room), "3 v 1 is too uneven")


func test_host_leaving_the_lobby_hands_over_and_an_empty_room_closes() -> void:
	var service: RoomService = _service()
	var room: RoomService.Room = service.create_room(1, "A", 2)
	service.join(room.code, 2, "B")
	var b_id: int = room.members[1].player_id
	service.disconnected(1)
	assert_eq(room.host_player_id, b_id)
	assert_eq(room.members.size(), 1)
	service.leave(2)
	assert_false(service.rooms.has(room.code))


func test_a_dropped_player_can_reconnect_within_60_s_with_their_token() -> void:
	var service: RoomService = _service()
	var room: RoomService.Room = service.create_room(1, "A", 1)
	service.join(room.code, 2, "B")
	service.set_ready(1, true)
	service.set_ready(2, true)
	service.start(1)
	var b: RoomService.Member = room.members[1]
	var token: String = b.token
	service.disconnected(2)
	assert_false(b.connected)
	assert_eq(room.members.size(), 2, "the slot stays")
	service.step(59.0)
	assert_null(service.reconnect("wrong", 9))
	var back: RoomService.Member = service.reconnect(token, 9)
	assert_eq(back, b)
	assert_eq(b.peer_id, 9)
	assert_eq(service.member_of_peer(9), b)


func test_the_token_expires_after_60_s() -> void:
	var service: RoomService = _service()
	var room: RoomService.Room = service.create_room(1, "A", 1)
	service.join(room.code, 2, "B")
	service.set_ready(1, true)
	service.set_ready(2, true)
	service.start(1)
	var token: String = room.members[1].token
	service.disconnected(2)
	service.step(61.0)
	assert_null(service.reconnect(token, 9))
	assert_true(service.rooms.has(room.code), "the match goes on")
