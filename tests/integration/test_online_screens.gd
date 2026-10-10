extends GutTest
## The lobby and the online match screen against a real in-process server.

var RULES: GameRules = load("res://data/rules/game_rules.tres") as GameRules
const LAYOUT: MapLayout = preload("res://data/rules/map_layout.tres")
const NET: NetRules = preload("res://data/rules/net_rules.tres")
const LOBBY: PackedScene = preload("res://scenes/ui/lobby.tscn")
const ONLINE: PackedScene = preload("res://scenes/match/online.tscn")
const PORT: int = 18932
const URL: String = "ws://127.0.0.1:18932"
const FRAME: float = 1.0 / 60.0

var server: GameServer
var clients: Array[GameClient] = []
var screens: Array[Node] = []


func before_each() -> void:
	server = GameServer.new(RULES, LAYOUT, NET, 9)
	assert_eq(server.listen(PORT), OK)
	clients.clear()
	screens.clear()


func after_each() -> void:
	for client: GameClient in clients:
		client.close()
	server.stop()


func _pump(seconds: float) -> void:
	for i: int in ceili(seconds / FRAME):
		server.poll(FRAME)
		for client: GameClient in clients:
			client.poll(FRAME)
		for screen: Node in screens:
			if screen is PracticeMatch and is_instance_valid(screen):
				(screen as PracticeMatch).advance(FRAME)
		OS.delay_usec(1000)


func _until(condition: Callable, limit: float = 5.0) -> bool:
	var waited: float = 0.0
	while waited < limit and not condition.call():
		_pump(0.05)
		waited += 0.05
	return condition.call()


func _lobby(intent: LobbyScreen.Intent) -> LobbyScreen:
	var client: GameClient = GameClient.new(RULES, LAYOUT, NET)
	clients.append(client)
	var lobby: LobbyScreen = autofree(LOBBY.instantiate()) as LobbyScreen
	lobby.client = client
	lobby.enter_match_on_start = false
	lobby.set_intent(intent)
	add_child(lobby)
	return lobby


func _two_lobbies_ready() -> Array[LobbyScreen]:
	var host: LobbyScreen = _lobby(LobbyScreen.Intent.CREATE)
	host.set_fields(URL, "Ana")
	host.submit()
	assert_true(_until(func() -> bool: return host.in_room()), "host is in a room")
	var code: String = host.client.room["code"] as String
	assert_string_starts_with(host.code_text(), code)
	var guest: LobbyScreen = _lobby(LobbyScreen.Intent.JOIN)
	guest.set_fields(URL, "Ben", code.to_lower())
	guest.submit()
	assert_true(_until(func() -> bool: return guest.in_room()), "guest joined")
	host.press_ready()
	guest.press_ready()
	assert_true(_until(func() -> bool: return host.start_enabled()), "host can start")
	return [host, guest]


func test_lobby_create_join_ready_start() -> void:
	var pair: Array[LobbyScreen] = _two_lobbies_ready()
	assert_false(pair[1].start_enabled(), "only the host has Start")
	pair[0].press_start()
	assert_true(_until(func() -> bool: return pair[0].client.in_match() and pair[1].client.in_match()))
	assert_eq(pair[1].status_text(), "Loading the match...")


func test_join_with_a_bad_code_shows_why() -> void:
	var guest: LobbyScreen = _lobby(LobbyScreen.Intent.JOIN)
	guest.set_fields(URL, "Ben", "ABC")
	guest.submit()
	assert_eq(guest.status_text(), "Room codes have 6 letters.")
	guest.set_fields(URL, "Ben", "ZZZZZZ")
	guest.submit()
	assert_true(_until(func() -> bool: return guest.status_text() == "No room with that code."))


func test_online_match_screen_picks_then_plays_against_the_server() -> void:
	var pair: Array[LobbyScreen] = _two_lobbies_ready()
	pair[0].press_start()
	assert_true(_until(func() -> bool: return pair[0].client.in_match() and pair[1].client.in_match()))
	var views: Array[PracticeMatch] = []
	for lobby: LobbyScreen in pair:
		var view: PracticeMatch = autofree(ONLINE.instantiate()) as PracticeMatch
		view.client = lobby.client
		add_child(view)
		views.append(view)
		screens.append(view)
		assert_true(view.is_picking(), "weapon pick first")
	var pick: WeaponPickScreen = views[0].get_node("%PickScreen") as WeaponPickScreen
	pick.tap(&"bato_light")
	pick.tap(&"lata")
	pick.press_ready()
	(views[1].get_node("%PickScreen") as WeaponPickScreen).tap(&"jacks")
	(views[1].get_node("%PickScreen") as WeaponPickScreen).tap(&"bola")
	(views[1].get_node("%PickScreen") as WeaponPickScreen).press_ready()
	assert_true(_until(func() -> bool: return not views[0].is_picking() and not views[1].is_picking()), "both playing")
	assert_false(views[0].hud.hurt_button.visible, "no practice buttons online")
	var server_sim: MatchSim = server.matches.values()[0].sim
	var me: int = views[0].local_id
	assert_eq(server_sim.players[me].weapons, [&"bato_light", &"lata"] as Array[StringName])
	var start: Vector2 = server_sim.players[me].position
	views[0].set_stick(Vector2(0.0, -1.0))
	_pump(1.0)
	views[0].set_stick(Vector2.ZERO)
	_pump(0.5)
	var walked: float = start.distance_to(server_sim.players[me].position)
	assert_gt(walked, 3.0, "the server moved us")
	assert_almost_eq(views[0].sim.players[me].position.distance_to(server_sim.players[me].position), 0.0, 0.3, "our screen agrees")
	assert_almost_eq(views[1].sim.players[me].position.distance_to(server_sim.players[me].position), 0.0, 0.3, "and theirs")


func test_the_match_screen_reconnects_by_itself_after_a_drop() -> void:
	var pair: Array[LobbyScreen] = _two_lobbies_ready()
	pair[0].press_start()
	assert_true(_until(func() -> bool: return pair[0].client.in_match() and pair[1].client.in_match()))
	var guest: GameClient = pair[1].client
	Session.reconnect_url = URL
	var view: PracticeMatch = autofree(ONLINE.instantiate()) as PracticeMatch
	view.client = guest
	add_child(view)
	screens.append(view)
	var mirror: MatchSim = guest.mirror
	guest.close()
	assert_true(_until(func() -> bool: return guest.is_online() and guest.stage != "", 8.0), "back online")
	assert_eq(guest.mirror, mirror, "same mirror, so the screen keeps working")
	var member: RoomService.Member = server.rooms.rooms.values()[0].member(guest.player_id)
	assert_true(_until(func() -> bool: return member.connected, 3.0), "the server gave the slot back")
	Session.reconnect_url = ""
