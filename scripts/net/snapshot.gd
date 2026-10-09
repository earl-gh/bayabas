class_name Snapshot
extends RefCounted
## Turns the server's MatchSim into plain data (SNAPSHOT message) and writes that
## data into a client's mirror MatchSim, which the match views read. The mirror is
## never stepped (except the local player's predicted movement), so the visual
## events that come from stepping are derived here from the differences.


static func capture(sim: MatchSim, acks: Dictionary[int, int]) -> Dictionary:
	var players: Array[Dictionary] = []
	for id: int in sim.players:
		var p: PlayerState = sim.players[id]
		players.append({
			"id": id, "pos": p.position, "face": p.facing, "hp": p.hp, "alive": p.alive,
			"dd": p.death_delay, "ddu": p.death_delay_used, "gray": p.gray_hp, "resp": p.respawn_time_left,
			"dcd": p.dash_cooldown_left, "dt": p.dash_time_left, "st": p.stumble_time_left,
			"bcd": p.bookmark_cooldown_left, "boost": p.boost_time_left, "mark": p.mark_active,
			"mpos": p.mark_position, "push": p.push_time_left, "pv": p.push_velocity,
			"wcd": p.weapon_cooldowns.duplicate(), "w": p.weapons.duplicate(), "fx": p.effects.snapshot(),
		})
	var projectiles: Array[Dictionary] = []
	for projectile: WeaponSystem.Projectile in sim.weapons.projectiles:
		projectiles.append({"id": projectile.id, "w": projectile.def.id, "pos": projectile.position, "team": projectile.team})
	var zones: Array[Dictionary] = []
	for zone: WeaponSystem.Zone in sim.weapons.zones:
		zones.append({"id": zone.id, "w": zone.def.id, "k": zone.kind, "c": zone.center, "r": zone.radius, "team": zone.team})
	var shields: Array[Dictionary] = []
	for shield: WeaponSystem.Shield in sim.weapons.shields:
		shields.append({"id": shield.id, "c": shield.center, "al": shield.along, "hw": shield.half_width, "team": shield.team})
	var walls: Array[int] = []
	for wall: MapLayout.WallSpec in sim.walls:
		walls.append(wall.hp)
	var ball: RubberBall = sim.ball
	var tricycle: Tricycle = sim.tricycle
	return {
		"t": NetProtocol.Msg.SNAPSHOT, "tick": sim.tick, "acks": acks.duplicate(),
		"players": players, "projectiles": projectiles, "zones": zones, "shields": shields,
		"walls": walls, "side0": sim.side_for_team(0), "phase": sim.phase, "freeze": sim.freeze_left,
		"score": {"p": sim.score.points.duplicate(), "s": sim.score.sets.duplicate(), "n": sim.score.set_number, "w": sim.score.winner},
		"ball": {"s": ball.state, "pos": ball.position, "h": ball.holder_id, "th": ball.thrower_id, "team": ball.team, "bl": ball.can_blink, "tm": ball.spawn_timer},
		"tri": {"ph": tricycle.phase, "t": tricycle.time_left, "dir": tricycle.direction, "pos": tricycle.position},
	}


## Writes `data` into `sim`. `local_id`'s position is left to the caller (prediction).
static func apply(sim: MatchSim, data: Dictionary, local_id: int) -> void:
	sim.tick = data.get("tick", sim.tick) as int
	for entry: Dictionary in data.get("players", []) as Array:
		var id: int = entry["id"] as int
		var p: PlayerState = sim.players.get(id) as PlayerState
		if p == null:
			continue
		if id != local_id:
			p.position = entry["pos"] as Vector2
		p.facing = entry["face"] as Vector2
		p.hp = entry["hp"] as int
		p.alive = entry["alive"] as bool
		p.death_delay = entry["dd"] as bool
		p.death_delay_used = entry["ddu"] as bool
		p.gray_hp = entry["gray"] as float
		p.respawn_time_left = entry["resp"] as float
		p.dash_cooldown_left = entry["dcd"] as float
		p.dash_time_left = entry["dt"] as float
		p.stumble_time_left = entry["st"] as float
		p.bookmark_cooldown_left = entry["bcd"] as float
		p.boost_time_left = entry["boost"] as float
		p.mark_active = entry["mark"] as bool
		p.mark_position = entry["mpos"] as Vector2
		p.push_time_left = entry["push"] as float
		p.push_velocity = entry["pv"] as Vector2
		p.weapon_cooldowns.assign(entry["wcd"] as Array)
		p.weapons.assign(entry["w"] as Array)
		p.effects.restore(entry["fx"] as Dictionary)
	_apply_weapons(sim, data)
	_apply_walls(sim, data.get("walls", []) as Array)
	var side0: int = data.get("side0", sim.side_for_team(0)) as int
	if side0 != sim.side_for_team(0):
		sim.set_team0_side(side0)
		sim.sides_switched.emit()
	sim.phase = data.get("phase", sim.phase) as MatchSim.Phase
	sim.freeze_left = data.get("freeze", 0.0) as float
	var score: Dictionary = data.get("score", {}) as Dictionary
	if not score.is_empty():
		sim.score.points.assign(score["p"] as Array)
		sim.score.sets.assign(score["s"] as Array)
		sim.score.set_number = score["n"] as int
		sim.score.winner = score["w"] as int
	var ball: Dictionary = data.get("ball", {}) as Dictionary
	if not ball.is_empty():
		sim.ball.state = ball["s"] as RubberBall.State
		sim.ball.position = ball["pos"] as Vector2
		sim.ball.holder_id = ball["h"] as int
		sim.ball.thrower_id = ball["th"] as int
		sim.ball.team = ball["team"] as int
		sim.ball.can_blink = ball["bl"] as bool
		sim.ball.spawn_timer = ball["tm"] as float
	var tri: Dictionary = data.get("tri", {}) as Dictionary
	if not tri.is_empty():
		sim.tricycle.phase = tri["ph"] as Tricycle.Phase
		sim.tricycle.time_left = tri["t"] as float
		sim.tricycle.direction = tri["dir"] as int
		sim.tricycle.position = tri["pos"] as Vector2


static func _apply_weapons(sim: MatchSim, data: Dictionary) -> void:
	var system: WeaponSystem = sim.weapons
	system.projectiles.clear()
	for entry: Dictionary in data.get("projectiles", []) as Array:
		var projectile: WeaponSystem.Projectile = WeaponSystem.Projectile.new()
		projectile.id = entry["id"] as int
		projectile.def = sim.weapon_defs[entry["w"] as StringName]
		projectile.position = entry["pos"] as Vector2
		projectile.team = entry["team"] as int
		system.projectiles.append(projectile)
	system.zones.clear()
	for entry: Dictionary in data.get("zones", []) as Array:
		var zone: WeaponSystem.Zone = WeaponSystem.Zone.new()
		zone.id = entry["id"] as int
		zone.def = sim.weapon_defs[entry["w"] as StringName]
		zone.kind = entry["k"] as WeaponSystem.ZoneKind
		zone.center = entry["c"] as Vector2
		zone.radius = entry["r"] as float
		zone.team = entry["team"] as int
		system.zones.append(zone)
	system.shields.clear()
	for entry: Dictionary in data.get("shields", []) as Array:
		var shield: WeaponSystem.Shield = WeaponSystem.Shield.new()
		shield.id = entry["id"] as int
		shield.center = entry["c"] as Vector2
		shield.along = entry["al"] as Vector2
		shield.half_width = entry["hw"] as float
		shield.team = entry["team"] as int
		system.shields.append(shield)


## Wall HP from the server; damage, breaks and rebuilds become the usual signals.
static func _apply_walls(sim: MatchSim, hps: Array) -> void:
	var rebuilt: bool = false
	for index: int in mini(hps.size(), sim.walls.size()):
		var wall: MapLayout.WallSpec = sim.walls[index]
		var hp: int = hps[index] as int
		if hp == wall.hp:
			continue
		var went_up: bool = hp > wall.hp
		wall.hp = hp
		if went_up:
			rebuilt = true
		else:
			sim.wall_damaged.emit(index)
			if hp == 0:
				sim.wall_destroyed.emit(index)
	if rebuilt:
		sim.walls_rebuilt.emit()
