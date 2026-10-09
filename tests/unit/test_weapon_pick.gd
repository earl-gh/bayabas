extends GutTest

const IDS: Array[StringName] = [&"bato_light", &"bato_heavy", &"lata", &"jacks"]


func _rng(seed_value: int = 1) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_pick_two_and_confirm() -> void:
	var pick: WeaponPick = WeaponPick.new(IDS, 10.0)
	pick.toggle(&"lata")
	assert_false(pick.can_confirm(), "one is not enough")
	pick.toggle(&"jacks")
	assert_true(pick.confirm())
	assert_eq(pick.picks, [&"lata", &"jacks"] as Array[StringName])
	pick.toggle(&"bato_light")
	assert_eq(pick.picks, [&"lata", &"jacks"] as Array[StringName], "locked after confirming")


func test_tapping_again_unpicks_and_a_third_replaces_the_oldest() -> void:
	var pick: WeaponPick = WeaponPick.new(IDS, 10.0)
	pick.toggle(&"lata")
	pick.toggle(&"lata")
	assert_true(pick.picks.is_empty())
	pick.toggle(&"lata")
	pick.toggle(&"jacks")
	pick.toggle(&"bato_heavy")
	assert_eq(pick.picks, [&"jacks", &"bato_heavy"] as Array[StringName])
	pick.toggle(&"nope")
	assert_eq(pick.picks.size(), 2)


func test_timeout_fills_with_different_weapons() -> void:
	for seed_value: int in 20:
		var pick: WeaponPick = WeaponPick.new(IDS, 10.0)
		pick.toggle(&"lata")
		assert_false(pick.step(9.9, _rng(seed_value)))
		assert_true(pick.step(0.2, _rng(seed_value)))
		assert_eq(pick.picks.size(), 2)
		assert_eq(pick.picks[0], &"lata", "keeps what you chose")
		assert_ne(pick.picks[1], &"lata")


func test_timeout_with_nothing_picked_fills_both() -> void:
	var pick: WeaponPick = WeaponPick.new(IDS, 1.0)
	pick.step(2.0, _rng())
	assert_true(pick.done)
	assert_eq(pick.picks.size(), 2)
	assert_ne(pick.picks[0], pick.picks[1])


func test_respawn_swap_starts_with_the_current_loadout() -> void:
	var pick: WeaponPick = WeaponPick.new(IDS, 10.0, [&"jacks", &"lata"] as Array[StringName])
	assert_true(pick.can_confirm())
	pick.step(10.0, _rng())
	assert_eq(pick.picks, [&"jacks", &"lata"] as Array[StringName], "timeout keeps your weapons")
