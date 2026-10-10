class_name ServerMatch
extends RefCounted
## One running match on the server: loading sync, the 10 s weapon pick, then the
## authoritative MatchSim stepped at 30 Hz from queued client inputs, with
## snapshots at `snapshot_rate` and the sim's signals relayed as EVENTS.

enum Stage { LOADING, PICKING, PLAYING }

## Sim signals relayed to clients ("weapons", "ball", "tricycle" or "sim" + name).
## Wall and side-switch signals are not relayed: clients derive them from snapshots.
const RELAYED: Dictionary[String, Array] = {
	"sim": [
		"player_died", "player_respawned", "player_death_delay_started", "player_revived",
		"point_scored", "set_won", "match_won", "point_reset", "weapon_cast", "player_damaged", "player_healed", "player_dashed", "bookmark_used", "effect_applied",
	],
	"weapons": ["cone_struck"],
	"ball": ["spawned", "picked_up", "thrown", "knocked_out", "caught", "passed", "dropped", "wall_hit", "blinked"],
	"tricycle": ["warning_started", "crossing_started", "crossing_ended", "pushed"],
}

var room: RoomService.Room
var sim: MatchSim
var stage: Stage = Stage.LOADING
var stage_left: float = 0.0
var seed_value: int = 0

var _server: GameServer
var _net: NetRules
var _loaded: Dictionary[int, bool] = {}
var _picked: Dictionary[int, bool] = {}
var _queues: Dictionary[int, Array] = {}
var _last_input: Dictionary[int, PlayerInput] = {}
var _acks: Dictionary[int, int] = {}
var _events: Array[Array] = []
var _accumulator: float = 0.0
var _snapshot_accumulator: float = 0.0


func _init(server: GameServer, p_room: RoomService.Room, rules: GameRules, layout: MapLayout, net: NetRules, p_seed: int) -> void:
	_server = server
	room = p_room
	_net = net
	seed_value = p_seed
	sim = MatchSim.new(rules, layout, p_seed)
	for m: RoomService.Member in room.members:
		sim.add_player(m.player_id, m.team)
		_queues[m.player_id] = []
		_acks[m.player_id] = -1
	sim.assign_characters()
	for id: int in sim.players:
		var loadout: Array[StringName] = sim.random_loadout()
		sim.set_loadout(id, loadout[0], loadout[1])
	stage_left = net.load_timeout
	_relay_signals()


## Breaks the sim -> match signal links and the server back-reference so the
## match can be freed (RefCounted cycles would leak).
func dispose() -> void:
	var sources: Array[Object] = [sim, sim.weapons, sim.ball, sim.tricycle]
	for source: Object in sources:
		for info: Dictionary in source.get_signal_list():
			for connection: Dictionary in source.get_signal_connection_list(info["name"] as StringName):
				var callable: Callable = connection["callable"] as Callable
				if callable.get_object() == self:
					source.disconnect(info["name"] as StringName, callable)
	_server = null


## MATCH_LOADING: everything a client needs to build its mirror sim.
func info() -> Dictionary:
	var players: Array[Dictionary] = []
	for m: RoomService.Member in room.members:
		players.append({
			"id": m.player_id, "team": m.team, "name": m.name,
			"char": sim.players[m.player_id].character_id,
		})
	return {"t": NetProtocol.Msg.MATCH_LOADING, "seed": seed_value, "team_size": room.team_size, "players": players}


## MATCH_PLAY: the current stage (pick or play) for a client joining or catching up.
func stage_message() -> Dictionary:
	var loadouts: Dictionary = {}
	for id: int in sim.players:
		loadouts[id] = sim.players[id].weapons.duplicate()
	var name: String = "play" if stage == Stage.PLAYING else "pick"
	return {"t": NetProtocol.Msg.MATCH_PLAY, "stage": name, "time": stage_left, "loadouts": loadouts}


func loaded(player_id: int) -> void:
	_loaded[player_id] = true


## Picks are taken during loading too (a fast client may pick before a slow one loads).
func pick(player_id: int, first: StringName, second: StringName) -> void:
	if stage != Stage.PLAYING and sim.set_loadout(player_id, first, second):
		_picked[player_id] = true


func swap(player_id: int, first: StringName, second: StringName) -> void:
	if stage == Stage.PLAYING:
		sim.swap_loadout(player_id, first, second)


func queue_input(player_id: int, input: PlayerInput) -> void:
	if not _queues.has(player_id) or input.tick <= _acks[player_id]:
		return
	var queue: Array = _queues[player_id]
	queue.append(input)
	while queue.size() > _net.max_queued_inputs:
		queue.pop_front()


func poll(delta: float) -> void:
	match stage:
		Stage.LOADING:
			stage_left -= delta
			if stage_left <= 0.0 or _everyone_in(_loaded):
				stage = Stage.PICKING
				stage_left = sim.rules.weapon_pick_time + _net.pick_grace
				_broadcast(stage_message())
		Stage.PICKING:
			stage_left -= delta
			if stage_left <= 0.0 or _everyone_in(_picked):
				stage = Stage.PLAYING
				room.state = RoomService.State.PLAYING
				_broadcast(stage_message())
		Stage.PLAYING:
			_play(delta)


func _play(delta: float) -> void:
	var dt: float = sim.rules.tick_dt()
	_accumulator += delta
	while _accumulator >= dt:
		_accumulator -= dt
		for m: RoomService.Member in room.members:
			sim.set_input(m.player_id, _next_input(m))
		sim.step(dt)
	_snapshot_accumulator += delta
	if not _events.is_empty():
		_broadcast({"t": NetProtocol.Msg.EVENTS, "list": _events.duplicate()})
		_events.clear()
	if _snapshot_accumulator >= 1.0 / _net.snapshot_rate:
		_snapshot_accumulator = 0.0
		_broadcast(Snapshot.capture(sim, _acks))


## One input per tick per player, oldest first, so taps are never lost. With none
## queued the last one repeats (held buttons stay held); a dropped player idles.
func _next_input(m: RoomService.Member) -> PlayerInput:
	if not m.connected:
		return PlayerInput.create(Vector2.ZERO, Vector2.ZERO, 0, sim.tick)
	var queue: Array = _queues[m.player_id]
	if not queue.is_empty():
		var input: PlayerInput = queue.pop_front() as PlayerInput
		_last_input[m.player_id] = input
		_acks[m.player_id] = input.tick
		return input
	if _last_input.has(m.player_id):
		return _last_input[m.player_id]
	return PlayerInput.create(Vector2.ZERO, Vector2.ZERO, 0, sim.tick)


func _everyone_in(flags: Dictionary[int, bool]) -> bool:
	for m: RoomService.Member in room.members:
		if m.connected and not flags.has(m.player_id):
			return false
	return true


func _broadcast(message: Dictionary) -> void:
	if _server == null:
		return
	for m: RoomService.Member in room.members:
		if m.connected:
			_server.send(m.peer_id, message)


func _relay_signals() -> void:
	var sources: Dictionary[String, Object] = {"sim": sim, "weapons": sim.weapons, "ball": sim.ball, "tricycle": sim.tricycle}
	for target: String in RELAYED:
		var source: Object = sources[target]
		for signal_name: String in RELAYED[target]:
			var arity: int = 0
			for info: Dictionary in source.get_signal_list():
				if info["name"] == signal_name:
					arity = (info["args"] as Array).size()
			var handlers: Array[Callable] = [_relay0, _relay1, _relay2, _relay3, _relay4]
			source.connect(signal_name, handlers[arity].bind(target, signal_name))


func _push_event(target: String, signal_name: String, args: Array) -> void:
	var clean: Array = []
	for arg: Variant in args:
		clean.append((arg as WeaponDef).id if arg is WeaponDef else arg)
	_events.append([target, signal_name, clean])


func _relay0(target: String, signal_name: String) -> void:
	_push_event(target, signal_name, [])


func _relay1(a: Variant, target: String, signal_name: String) -> void:
	_push_event(target, signal_name, [a])


func _relay2(a: Variant, b: Variant, target: String, signal_name: String) -> void:
	_push_event(target, signal_name, [a, b])


func _relay3(a: Variant, b: Variant, c: Variant, target: String, signal_name: String) -> void:
	_push_event(target, signal_name, [a, b, c])


func _relay4(a: Variant, b: Variant, c: Variant, d: Variant, target: String, signal_name: String) -> void:
	_push_event(target, signal_name, [a, b, c, d])
