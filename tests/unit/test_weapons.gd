extends GutTest

var RULES: GameRules = load("res://data/rules/game_rules.tres") as GameRules
const LAYOUT: MapLayout = preload("res://data/rules/map_layout.tres")
const DT: float = 1.0 / 30.0
const T := StatusEffects.Type
const CASTER: int = 1


func _sim() -> MatchSim:
	return MatchSim.new(RULES, LAYOUT, 11)


## Team-0 caster at `at` holding `first` (slot 0) and `second` (slot 1).
func _caster(sim: MatchSim, first: StringName, second: StringName = &"papel_shield", at: Vector2 = Vector2.ZERO) -> PlayerState:
	var caster: PlayerState = sim.add_player(CASTER, 0)
	caster.position = at
	assert_true(sim.set_loadout(CASTER, first, second))
	return caster


func _target(sim: MatchSim, id: int, at: Vector2) -> PlayerState:
	return sim.add_dummy(id, 1, at, DummyBrain.standing())


## Hold the slot's button for `hold_ticks`, then release with `aim` (or cancel).
func _cast(sim: MatchSim, slot: int, aim: Vector2 = Vector2.ZERO, hold_ticks: int = 1, cancel: bool = false, id: int = CASTER) -> void:
	var bit: int = PlayerInput.BTN_WEAPON_1 if slot == 0 else PlayerInput.BTN_WEAPON_2
	for i: int in hold_ticks:
		sim.set_input(id, PlayerInput.create(Vector2.ZERO, aim, bit, sim.tick))
		sim.step(DT)
	var release: int = PlayerInput.BTN_AIM_CANCEL if cancel else 0
	sim.set_input(id, PlayerInput.create(Vector2.ZERO, aim, release, sim.tick))
	sim.step(DT)


func _wait(sim: MatchSim, seconds: float) -> void:
	for i: int in ceili(seconds / DT):
		sim.step(DT)


func _def(id: StringName) -> WeaponDef:
	for i: int in RULES.weapons.size():
		var def: WeaponDef = RULES.weapons[i]
		if def.id == id:
			return def
	return null


# ---- data ------------------------------------------------------------------

func test_twelve_weapons_match_the_gdd_table() -> void:
	assert_eq(RULES.weapons.size(), 12)
	var expected: Dictionary = {
		# id: [kind, cooldown, range, damage]
		&"bato_light": [WeaponDef.Kind.ATTACK, 4.0, 7.0, 14],
		&"bato_heavy": [WeaponDef.Kind.ATTACK, 12.0, 8.0, 22],
		&"gunting_light": [WeaponDef.Kind.ATTACK, 5.0, 3.0, 4],
		&"gunting_heavy": [WeaponDef.Kind.ATTACK, 9.0, 3.5, 24],
		&"papel_trap": [WeaponDef.Kind.CROWD_CONTROL, 12.0, 6.0, 0],
		&"papel_shield": [WeaponDef.Kind.BLOCK, 14.0, 0.0, 0],
		&"tsinelas_light": [WeaponDef.Kind.ATTACK, 6.0, 7.0, 8],
		&"tsinelas_heavy": [WeaponDef.Kind.ATTACK, 10.0, 8.0, 18],
		&"lata": [WeaponDef.Kind.CROWD_CONTROL, 14.0, 7.0, 5],
		&"jacks": [WeaponDef.Kind.CROWD_CONTROL, 11.0, 6.0, 3],
		&"bola": [WeaponDef.Kind.CROWD_CONTROL, 12.0, 9.0, 6],
		&"trumpo": [WeaponDef.Kind.CROWD_CONTROL, 15.0, 8.0, 10],
	}
	for id: StringName in expected:
		var def: WeaponDef = _def(id)
		assert_not_null(def, String(id))
		var row: Array = expected[id]
		assert_eq(def.kind, row[0], "%s kind" % id)
		assert_eq(def.cooldown, row[1], "%s cooldown" % id)
		assert_eq(def.max_range, row[2], "%s range" % id)
		assert_eq(def.damage, row[3], "%s damage" % id)
		assert_ne(def.street_game, "", "%s has a street game" % id)
	assert_eq(_def(&"bato_heavy").effect, T.STUN)
	assert_eq(_def(&"papel_trap").effect, T.SLOW)
	assert_eq(_def(&"lata").effect, T.POLYMORPH)
	assert_eq(_def(&"bola").effect, T.BOUNCE)
	assert_eq(_def(&"trumpo").effect, T.AIRBORNE)


# ---- loadout -----------------------------------------------------------------

func test_loadout_rejects_duplicates_and_unknown_weapons() -> void:
	var sim: MatchSim = _sim()
	sim.add_player(CASTER, 0)
	assert_false(sim.set_loadout(CASTER, &"bato_light", &"bato_light"), "two copies of one weapon")
	assert_false(sim.set_loadout(CASTER, &"bato_light", &"nope"))
	assert_true(sim.set_loadout(CASTER, &"bato_light", &"bato_heavy"), "two of the same type is fine")
	assert_eq(sim.players[CASTER].weapons, [&"bato_light", &"bato_heavy"] as Array[StringName])


func test_random_loadout_is_two_different_weapons_and_seeded() -> void:
	var a: MatchSim = MatchSim.new(RULES, LAYOUT, 5)
	var b: MatchSim = MatchSim.new(RULES, LAYOUT, 5)
	for i: int in 50:
		var pick: Array[StringName] = a.random_loadout()
		assert_ne(pick[0], pick[1])
		assert_eq(pick, b.random_loadout())


# ---- casting rules -------------------------------------------------------------

func test_weapons_cast_on_release_and_go_on_cooldown() -> void:
	var sim: MatchSim = _sim()
	var caster: PlayerState = _caster(sim, &"bato_light")
	var enemy: PlayerState = _target(sim, 2, Vector2(0.0, -5.0))
	sim.set_input(CASTER, PlayerInput.create(Vector2.ZERO, Vector2.ZERO, PlayerInput.BTN_WEAPON_1, 0))
	sim.step(DT)
	assert_eq(caster.weapon_cooldowns[0], 0.0, "holding does not cast yet")
	sim.set_input(CASTER, PlayerInput.create(Vector2.ZERO, Vector2.ZERO, 0, 1))
	sim.step(DT)
	assert_almost_eq(caster.weapon_cooldowns[0], 4.0, 0.001)
	_wait(sim, 1.0)
	assert_eq(enemy.hp, 86)


func test_release_over_the_cancel_zone_does_not_cast() -> void:
	var sim: MatchSim = _sim()
	var caster: PlayerState = _caster(sim, &"bato_light")
	var enemy: PlayerState = _target(sim, 2, Vector2(0.0, -5.0))
	_cast(sim, 0, Vector2.ZERO, 1, true)
	_wait(sim, 1.0)
	assert_eq(caster.weapon_cooldowns[0], 0.0)
	assert_eq(enemy.hp, 100)


func test_cooldown_blocks_recasting() -> void:
	var sim: MatchSim = _sim()
	_caster(sim, &"bato_light")
	var enemy: PlayerState = _target(sim, 2, Vector2(0.0, -5.0))
	_cast(sim, 0)
	_wait(sim, 1.0)
	_cast(sim, 0)
	_wait(sim, 1.0)
	assert_eq(enemy.hp, 86, "second cast inside 4 s does nothing")
	_wait(sim, 2.5)
	_cast(sim, 0)
	_wait(sim, 1.0)
	assert_eq(enemy.hp, 72)


func test_cannot_cast_while_stunned_polymorphed_or_in_the_death_delay() -> void:
	var sim: MatchSim = _sim()
	var caster: PlayerState = _caster(sim, &"bato_light")
	var enemy: PlayerState = _target(sim, 2, Vector2(0.0, -5.0))
	sim.apply_effect(CASTER, T.STUN, 1.0, 0.0)
	_cast(sim, 0)
	assert_eq(caster.weapon_cooldowns[0], 0.0)
	_wait(sim, 1.0)
	sim.apply_effect(CASTER, T.POLYMORPH, 1.0, 0.0)
	_cast(sim, 0)
	assert_eq(caster.weapon_cooldowns[0], 0.0)
	_wait(sim, 1.0)
	sim.damage(CASTER, 100)
	assert_true(caster.death_delay)
	_cast(sim, 0)
	_wait(sim, 1.0)
	assert_eq(enemy.hp, 100)


func test_stun_stops_movement_and_cancels_a_dash() -> void:
	var sim: MatchSim = _sim()
	var caster: PlayerState = _caster(sim, &"bato_light")
	sim.set_input(CASTER, PlayerInput.create(Vector2(0.0, -1.0), Vector2.ZERO, PlayerInput.BTN_DASH, 0))
	sim.step(DT)
	assert_gt(caster.dash_time_left, 0.0)
	sim.apply_effect(CASTER, T.STUN, 1.0, 0.0)
	assert_eq(caster.dash_time_left, 0.0)
	var at: Vector2 = caster.position
	for i: int in 20:
		sim.set_input(CASTER, PlayerInput.create(Vector2(0.0, -1.0), Vector2.ZERO, 0, sim.tick))
		sim.step(DT)
	assert_eq(caster.position, at)


func test_slow_and_polymorph_reduce_walking_speed() -> void:
	var sim: MatchSim = _sim()
	var caster: PlayerState = _caster(sim, &"bato_light")
	sim.apply_effect(CASTER, T.SLOW, 5.0, 0.4)
	var start: Vector2 = caster.position
	for i: int in 30:
		sim.set_input(CASTER, PlayerInput.create(Vector2(1.0, 0.0), Vector2.ZERO, 0, sim.tick))
		sim.step(DT)
	assert_almost_eq(caster.position.x - start.x, 3.0, 0.05)


func test_players_in_the_death_delay_are_not_hit() -> void:
	var sim: MatchSim = _sim()
	_caster(sim, &"gunting_heavy")
	var enemy: PlayerState = sim.add_player(2, 1)
	enemy.position = Vector2(0.0, -2.0)
	sim.damage(2, 100)
	assert_true(enemy.death_delay)
	_cast(sim, 0, Vector2(0.0, -1.0))
	_wait(sim, 1.0)
	assert_true(enemy.death_delay)
	assert_eq(enemy.gray_hp, 50.0)


# ---- shapes --------------------------------------------------------------------

func test_targeted_bato_hits_the_nearest_enemy_only_in_range() -> void:
	var sim: MatchSim = _sim()
	var caster: PlayerState = _caster(sim, &"bato_light")
	var far: PlayerState = _target(sim, 2, Vector2(0.0, -7.5))
	_cast(sim, 0)
	assert_eq(caster.weapon_cooldowns[0], 0.0, "nobody in range: nothing thrown, no cooldown")
	var near: PlayerState = _target(sim, 3, Vector2(3.0, -3.0))
	_cast(sim, 0)
	_wait(sim, 1.0)
	assert_eq(near.hp, 86)
	assert_eq(far.hp, 100)


func test_ground_aoe_lands_after_the_delay_with_stun() -> void:
	var sim: MatchSim = _sim()
	_caster(sim, &"bato_heavy")
	var hit: PlayerState = _target(sim, 2, Vector2(0.0, -6.0))
	var near_miss: PlayerState = _target(sim, 3, Vector2(3.0, -6.0))
	_cast(sim, 0, Vector2(0.0, -6.0) / 8.0)
	_wait(sim, 0.3)
	assert_eq(hit.hp, 100, "still in the air")
	_wait(sim, 0.4)
	assert_eq(hit.hp, 78)
	assert_true(hit.effects.has(T.STUN))
	assert_eq(near_miss.hp, 100, "3 m from the impact is outside r = 2")


func test_ground_aoe_auto_aims_at_the_nearest_enemy() -> void:
	var sim: MatchSim = _sim()
	_caster(sim, &"bato_heavy")
	var enemy: PlayerState = _target(sim, 2, Vector2(4.0, -5.0))
	_cast(sim, 0)
	_wait(sim, 1.0)
	assert_eq(enemy.hp, 78)


func test_gunting_light_snips_by_hold_time_in_a_cone() -> void:
	var sim: MatchSim = _sim()
	_caster(sim, &"gunting_light")
	var front: PlayerState = _target(sim, 2, Vector2(0.0, -2.0))
	var behind: PlayerState = _target(sim, 3, Vector2(0.0, 2.0))
	var too_far: PlayerState = _target(sim, 4, Vector2(0.5, -3.8))
	_cast(sim, 0, Vector2(0.0, -1.0), 1)
	assert_eq(front.hp, 92, "a tap is 2 snips of 4")
	assert_eq(behind.hp, 100)
	assert_eq(too_far.hp, 100)
	_wait(sim, 5.0)
	_cast(sim, 0, Vector2(0.0, -1.0), 40)
	assert_eq(front.hp, 68, "a long hold is 6 snips")


func test_snip_count_from_hold_time() -> void:
	var def: WeaponDef = _def(&"gunting_light")
	assert_eq(def.snip_count(0.0), 2)
	assert_eq(def.snip_count(0.26), 3)
	assert_eq(def.snip_count(0.51), 4)
	assert_eq(def.snip_count(5.0), 6)


func test_gunting_heavy_is_one_delayed_snip() -> void:
	var sim: MatchSim = _sim()
	_caster(sim, &"gunting_heavy")
	var enemy: PlayerState = _target(sim, 2, Vector2(1.0, -2.5))
	_cast(sim, 0, Vector2(0.0, -1.0))
	assert_eq(enemy.hp, 100, "wind-up")
	_wait(sim, 0.6)
	assert_eq(enemy.hp, 76)


func test_papel_trap_arms_then_becomes_a_slow_zone() -> void:
	var sim: MatchSim = _sim()
	_caster(sim, &"papel_trap")
	var enemy: PlayerState = _target(sim, 2, Vector2(0.0, -4.0))
	_cast(sim, 0, Vector2(0.0, -4.0) / 6.0)
	_wait(sim, 0.4)
	assert_false(enemy.effects.has(T.SLOW), "not armed yet")
	_wait(sim, 0.6)
	assert_true(enemy.effects.has(T.SLOW))
	assert_eq(enemy.hp, 100, "no damage")
	_wait(sim, 3.5)
	assert_false(enemy.effects.has(T.SLOW), "zone gone after 3 s")
	assert_true(sim.weapons.zones.is_empty())


func test_papel_trap_waits_for_an_enemy() -> void:
	var sim: MatchSim = _sim()
	_caster(sim, &"papel_trap")
	_cast(sim, 0, Vector2(0.0, -1.0))
	_wait(sim, 3.0)
	assert_eq(sim.weapons.zones.size(), 1)
	assert_eq(sim.weapons.zones[0].kind, WeaponSystem.ZoneKind.TRAP)


func test_papel_shield_blocks_enemy_projectiles_not_own() -> void:
	var sim: MatchSim = _sim()
	var me: PlayerState = _caster(sim, &"papel_shield", &"bato_light")
	var enemy: PlayerState = sim.add_player(2, 1)
	enemy.position = Vector2(0.0, -5.0)
	assert_true(sim.set_loadout(2, &"bato_light", &"bato_heavy"))
	_cast(sim, 0, Vector2(0.0, -1.0))
	assert_eq(sim.weapons.shields.size(), 1)
	_cast(sim, 0, Vector2.ZERO, 1, false, 2)
	_wait(sim, 1.0)
	assert_eq(me.hp, 100, "enemy rock stopped by the paper wall")
	_cast(sim, 1)
	_wait(sim, 1.0)
	assert_eq(enemy.hp, 86, "own rock passes own shield")
	_wait(sim, 3.0)
	assert_true(sim.weapons.shields.is_empty(), "gone after 2.5 s")


func test_tsinelas_light_three_boomerangs_hit_out_and_back() -> void:
	var sim: MatchSim = _sim()
	_caster(sim, &"tsinelas_light")
	var enemy: PlayerState = _target(sim, 2, Vector2(0.0, -4.0))
	_cast(sim, 0, Vector2(0.0, -1.0))
	_wait(sim, 2.5)
	assert_eq(enemy.hp, 100 - 3 * 2 * 8)
	assert_true(sim.weapons.projectiles.is_empty(), "all caught again")


func test_tsinelas_heavy_one_big_boomerang() -> void:
	var sim: MatchSim = _sim()
	_caster(sim, &"tsinelas_heavy")
	var enemy: PlayerState = _target(sim, 2, Vector2(0.0, -4.0))
	_cast(sim, 0, Vector2(0.0, -1.0))
	_wait(sim, 3.0)
	assert_eq(enemy.hp, 100 - 2 * 18)


func test_lata_polymorphs_after_its_flight() -> void:
	var sim: MatchSim = _sim()
	_caster(sim, &"lata")
	var enemy: PlayerState = _target(sim, 2, Vector2(0.0, -5.0))
	_cast(sim, 0, Vector2(0.0, -5.0) / 7.0)
	assert_eq(enemy.hp, 100, "still flying")
	_wait(sim, 0.5)
	assert_eq(enemy.hp, 95)
	assert_true(enemy.effects.has(T.POLYMORPH))
	assert_false(enemy.can_act())


func test_jacks_field_ticks_damage_and_slow() -> void:
	var sim: MatchSim = _sim()
	_caster(sim, &"jacks")
	var enemy: PlayerState = _target(sim, 2, Vector2(0.0, -3.0))
	_cast(sim, 0, Vector2(0.0, -3.0) / 6.0)
	_wait(sim, 0.2)
	assert_true(enemy.effects.has(T.SLOW))
	_wait(sim, 4.2)
	assert_between(enemy.hp, 73, 79, "about 8 ticks of 3 over 4 s")
	assert_true(sim.weapons.zones.is_empty())


func test_bola_bounces_twice_bouncing_enemies() -> void:
	var sim: MatchSim = _sim()
	_caster(sim, &"bola")
	var first: PlayerState = _target(sim, 2, Vector2(0.0, -4.5))
	var second: PlayerState = _target(sim, 3, Vector2(0.5, -9.0))
	var between: PlayerState = _target(sim, 4, Vector2(0.0, -6.8))
	_cast(sim, 0, Vector2(0.0, -1.0))
	_wait(sim, 0.45)
	assert_eq(first.hp, 94)
	assert_true(first.effects.has(T.BOUNCE))
	_wait(sim, 0.5)
	assert_eq(second.hp, 94)
	assert_eq(between.hp, 100, "only the bounce points hit")
	assert_true(sim.weapons.projectiles.is_empty())


func test_trumpo_passes_through_and_launches_once_each() -> void:
	var sim: MatchSim = _sim()
	_caster(sim, &"trumpo")
	var a: PlayerState = _target(sim, 2, Vector2(0.0, -3.0))
	var b: PlayerState = _target(sim, 3, Vector2(0.3, -6.0))
	var beyond: PlayerState = _target(sim, 4, Vector2(0.0, -10.0))
	_cast(sim, 0, Vector2(0.0, -1.0))
	_wait(sim, 0.6)
	assert_true(a.effects.has(T.AIRBORNE))
	assert_false(a.can_act())
	_wait(sim, 1.4)
	assert_eq(a.hp, 90, "hit once, not every tick")
	assert_eq(b.hp, 90)
	assert_true(b.effects.has(T.AIRBORNE))
	assert_eq(beyond.hp, 100, "stops at 8 m")


func test_enemy_walls_stop_projectiles_own_walls_do_not() -> void:
	var sim: MatchSim = _sim()
	_caster(sim, &"bato_light", &"papel_shield", Vector2(0.0, -8.5))
	var behind_enemy_wall: PlayerState = _target(sim, 2, Vector2(0.0, -15.2))
	_cast(sim, 0)
	_wait(sim, 1.0)
	assert_eq(behind_enemy_wall.hp, 100, "the enemy's cardboard wall at z = -14 blocks the rock")
	var other: MatchSim = _sim()
	_caster(other, &"bato_light", &"papel_shield", Vector2(0.0, 17.0))
	var past_own_wall: PlayerState = _target(other, 2, Vector2(0.0, 11.5))
	_cast(other, 0)
	_wait(other, 1.0)
	assert_eq(past_own_wall.hp, 86, "the rock flies through our own wall at z = 14")


# ---- respawn swap ----------------------------------------------------------------

func test_swap_only_while_dead_and_kept_weapons_keep_their_cooldown() -> void:
	var sim: MatchSim = _sim()
	var caster: PlayerState = _caster(sim, &"bato_heavy", &"lata")
	assert_false(sim.swap_loadout(CASTER, &"jacks", &"bola"), "not while alive")
	caster.weapon_cooldowns = [5.0, 3.0] as Array[float]
	sim.kill(CASTER)
	assert_true(sim.swap_loadout(CASTER, &"jacks", &"bato_heavy"))
	assert_eq(caster.weapons, [&"jacks", &"bato_heavy"] as Array[StringName])
	assert_eq(caster.weapon_cooldowns, [0.0, 5.0] as Array[float])
	assert_true(sim.swap_loadout(CASTER, &"bato_heavy", &"lata"), "again, no limit")
	assert_eq(caster.weapon_cooldowns, [5.0, 0.0] as Array[float], "swapping away and back clears nothing")
	assert_false(sim.swap_loadout(CASTER, &"lata", &"lata"))



# ---- no precast, no following -------------------------------------------------

func test_holding_a_weapon_through_its_cooldown_does_not_precast() -> void:
	var sim: MatchSim = _sim()
	var caster: PlayerState = _caster(sim, &"bato_light")
	var enemy: PlayerState = _target(sim, 2, Vector2(0.0, -5.0))
	_cast(sim, 0)
	_wait(sim, 1.0)
	assert_eq(enemy.hp, 86)
	# press during the cooldown and keep holding until it is over, then let go
	_cast(sim, 0, Vector2.ZERO, 150)
	_wait(sim, 1.0)
	assert_eq(enemy.hp, 86, "a press during the cooldown never starts an aim")
	assert_eq(caster.weapon_cooldowns[0], 0.0)


func test_auto_aim_is_taken_at_the_press_and_does_not_follow_the_enemy() -> void:
	var sim: MatchSim = _sim()
	_caster(sim, &"bato_heavy")
	var enemy: PlayerState = _target(sim, 2, Vector2(0.0, -6.0))
	sim.set_input(CASTER, PlayerInput.create(Vector2.ZERO, Vector2.ZERO, PlayerInput.BTN_WEAPON_1, sim.tick))
	sim.step(DT)
	enemy.position = Vector2(4.0, -6.0)
	for i: int in 10:
		sim.set_input(CASTER, PlayerInput.create(Vector2.ZERO, Vector2.ZERO, PlayerInput.BTN_WEAPON_1, sim.tick))
		sim.step(DT)
	sim.set_input(CASTER, PlayerInput.create(Vector2.ZERO, Vector2.ZERO, 0, sim.tick))
	sim.step(DT)
	_wait(sim, 1.0)
	assert_eq(enemy.hp, 100, "the rock lands where the enemy was at the press")
	assert_eq(sim.weapons.zones.size(), 0)


func test_targeted_bato_throws_at_the_enemy_locked_at_the_press() -> void:
	var sim: MatchSim = _sim()
	var caster: PlayerState = _caster(sim, &"bato_light")
	var first: PlayerState = _target(sim, 2, Vector2(0.0, -3.0))
	var second: PlayerState = _target(sim, 3, Vector2(0.0, -5.0))
	sim.set_input(CASTER, PlayerInput.create(Vector2.ZERO, Vector2.ZERO, PlayerInput.BTN_WEAPON_1, sim.tick))
	sim.step(DT)
	first.position = Vector2(0.0, -6.5)
	_cast(sim, 0, Vector2.ZERO, 0)
	_wait(sim, 1.0)
	assert_eq(first.hp, 86, "still the locked enemy, not the now-nearer one")
	assert_eq(second.hp, 100)
	assert_gt(caster.weapon_cooldowns[0], 0.0)


func test_targeted_bato_does_nothing_if_the_locked_enemy_left_range() -> void:
	var sim: MatchSim = _sim()
	var caster: PlayerState = _caster(sim, &"bato_light")
	var enemy: PlayerState = _target(sim, 2, Vector2(0.0, -5.0))
	sim.set_input(CASTER, PlayerInput.create(Vector2.ZERO, Vector2.ZERO, PlayerInput.BTN_WEAPON_1, sim.tick))
	sim.step(DT)
	enemy.position = Vector2(0.0, -9.0)
	_cast(sim, 0, Vector2.ZERO, 0)
	assert_eq(caster.weapon_cooldowns[0], 0.0, "nothing thrown, no cooldown spent")


func test_a_stun_while_aiming_drops_the_aim() -> void:
	var sim: MatchSim = _sim()
	var caster: PlayerState = _caster(sim, &"bato_heavy")
	sim.set_input(CASTER, PlayerInput.create(Vector2.ZERO, Vector2.ZERO, PlayerInput.BTN_WEAPON_1, sim.tick))
	sim.step(DT)
	sim.apply_effect(CASTER, T.STUN, 0.2, 0.0)
	for i: int in 15:
		sim.set_input(CASTER, PlayerInput.create(Vector2.ZERO, Vector2.ZERO, PlayerInput.BTN_WEAPON_1, sim.tick))
		sim.step(DT)
	sim.set_input(CASTER, PlayerInput.create(Vector2.ZERO, Vector2.ZERO, 0, sim.tick))
	sim.step(DT)
	assert_eq(caster.weapon_cooldowns[0], 0.0, "press again after the stun")
