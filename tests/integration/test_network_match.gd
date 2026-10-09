extends GutTest
## Two real WebSocket clients against a real server, all in this process.

var RULES: GameRules = load("res://data/rules/game_rules.tres") as GameRules
const LAYOUT: MapLayout = preload("res://data/rules/map_layout.tres")
const NET: NetRules = preload("res://data/rules/net_rules.tres")
const PORT: int = 18931
const FRAME: float = 1.0 / 60.0

var server: GameServer
var a: GameClient
var b: GameClient


func before_each() -> void:
	server = GameServer.new(RULES, LAYOUT, NET, 5)
	assert_eq(server.listen(PORT), OK)
	a = GameClient.new(RULES, LAYOUT, NET)
	b = GameClient.new(RULES, LAYOUT, NET)
	a.player_name = "Ana"
	b.player_name = "Ben"


func after_each() -> void:
	a.close()
	b.close()
	server.stop()


## Runs everything for `seconds` of simulated time (real sockets, so it also waits).
func _pump(seconds: float, clients: Array[GameClient] = []) -> void:
	var all: Array[GameClient] = clients.duplicate()
	if all.is_empty():
		all = [a, b]
	for i: int in ceili(seconds / FRAME):
		server.poll(FRAME)
		for client: GameClient in all:
			client.poll(FRAME)
		OS.delay_usec(1000)


func _until(condition: Callable, limit: float = 5.0) -> bool:
	var waited: float = 0.0
	while waited < limit:
		if condition.call():
			return true
		_pump(0.05)
		waited += 0.05
	return condition.call()


func _connect_both() -> void:
	assert_eq(a.connect_to("ws://127.0.0.1:%d" % PORT), OK)
	assert_eq(b.connect_to("ws://127.0.0.1:%d" % PORT), OK)
	assert_true(_until(func() -> bool: return a.is_online() and b.is_online()), "both connected")


## Lobby -> loading -> pick -> play for a 1v1.
func _start_1v1() -> void:
	_connect_both()
	a.create_room(1)
	assert_true(_until(func() -> bool: return not a.room.is_empty()), "room created")
	b.join_room(a.room["code"] as String)
	assert_true(_until(func() -> bool: return (b.room.get("members", []) as Array).size() == 2), "joined")
	a.set_ready(true)
	b.set_ready(true)
	assert_true(_until(func() -> bool: return a.room.get("can_start", false) as bool), "can start")
	a.start_match()
	assert_true(_until(func() -> bool: return a.in_match() and b.in_match()), "loading")
	a.loaded()
	b.loaded()
	assert_true(_until(func() -> bool: return a.stage == "pick" and b.stage == "pick"), "picking")
	a.pick_weapons(&"bato_light", &"lata")
	b.pick_weapons(&"jacks", &"bola")
	assert_true(_until(func() -> bool: return a.stage == "play" and b.stage == "play"), "playing")


func test_two_clients_create_join_ready_and_start() -> void:
	_start_1v1()
	assert_eq(a.room["host"], a.player_id)
	assert_true(a.is_host())
	assert_false(b.is_host())
	assert_ne(a.my_team(), b.my_team())
	assert_eq(a.mirror.players.size(), 2)
	assert_eq(a.mirror.players[a.player_id].weapons, [&"bato_light", &"lata"] as Array[StringName])
	assert_eq(b.mirror.players[a.player_id].weapons, [&"bato_light", &"lata"] as Array[StringName], "everyone sees the loadouts")
	var chars: Dictionary = {}
	for id: int in a.mirror.players:
		chars[a.mirror.players[id].character_id] = true
	assert_eq(chars.size(), 2, "different characters")


func test_wrong_code_is_an_error() -> void:
	_connect_both()
	var errors: Array[String] = []
	b.error_received.connect(func(text: String) -> void: errors.append(text))
	b.join_room("ZZZZZZ")
	assert_true(_until(func() -> bool: return not errors.is_empty()))
	assert_eq(errors[0], "No room with that code.")


func test_inputs_move_the_player_on_the_server_and_everyone_sees_it() -> void:
	_start_1v1()
	var match_sim: MatchSim = server.matches.values()[0].sim
	var start: Vector2 = match_sim.players[a.player_id].position
	var dt: float = RULES.tick_dt()
	for i: int in 30:
		a.send_input(PlayerInput.create(Vector2(1.0, 0.0), Vector2.ZERO, 0, i + 1), dt)
		_pump(dt, [a, b])
	a.send_input(PlayerInput.create(Vector2.ZERO, Vector2.ZERO, 0, 31), dt)
	_pump(0.5)
	var moved: float = match_sim.players[a.player_id].position.x - start.x
	assert_almost_eq(moved, 5.0, 0.4, "about 1 s of walking at 5 m/s on the server")
	assert_almost_eq(a.mirror.players[a.player_id].position.x, match_sim.players[a.player_id].position.x, 0.3, "prediction agrees")
	b.interpolate()
	assert_almost_eq(b.mirror.players[a.player_id].position.x, match_sim.players[a.player_id].position.x, 0.3, "the other client sees it")


func test_a_cast_on_the_server_reaches_the_other_client() -> void:
	_start_1v1()
	var server_match: ServerMatch = server.matches.values()[0]
	var me: PlayerState = server_match.sim.players[a.player_id]
	var them: PlayerState = server_match.sim.players[b.player_id]
	me.position = Vector2(0.0, 2.0)
	them.position = Vector2(0.0, -3.0)
	var dt: float = RULES.tick_dt()
	a.send_input(PlayerInput.create(Vector2.ZERO, Vector2.ZERO, PlayerInput.BTN_WEAPON_1, 1), dt)
	a.send_input(PlayerInput.create(Vector2.ZERO, Vector2.ZERO, 0, 2), dt)
	_pump(1.2)
	assert_eq(them.hp, 86, "bato light hit on the server")
	assert_eq(b.mirror.players[b.player_id].hp, 86, "and the target's client knows")


func test_events_are_replayed_as_signals_on_the_mirror() -> void:
	_start_1v1()
	var server_match: ServerMatch = server.matches.values()[0]
	watch_signals(b.mirror)
	server_match.sim.kill(b.player_id)
	_pump(0.3)
	assert_signal_emitted_with_parameters(b.mirror, "player_died", [b.player_id])
	assert_false(b.mirror.players[b.player_id].alive)


func test_a_dropped_client_reconnects_into_its_slot() -> void:
	_start_1v1()
	var token: String = b.token
	var id: int = b.player_id
	b.close()
	_pump(0.5, [a])
	var member: RoomService.Member = server.rooms.rooms.values()[0].member(id)
	assert_false(member.connected, "the server noticed the drop")
	var c: GameClient = GameClient.new(RULES, LAYOUT, NET)
	c.player_name = "Ben"
	c.token = token
	b = c
	assert_eq(c.connect_to("ws://127.0.0.1:%d" % PORT), OK)
	assert_true(_until(func() -> bool: return c.in_match() and c.stage == "play", 5.0), "back in the match")
	assert_eq(c.player_id, id, "same slot")
	assert_true(member.connected)
