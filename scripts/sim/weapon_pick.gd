class_name WeaponPick
extends RefCounted
## The weapon pick (docs/GDD.md "Weapon pick"): two different weapons within
## `GameRules.weapon_pick_time`. Tapping a third weapon replaces the older pick.
## When time runs out the missing picks are filled at random. Plain data, so the
## server and offline practice share it.

const SLOTS: int = 2

var time_left: float = 0.0
var picks: Array[StringName] = []
var done: bool = false

var _available: Array[StringName] = []


## `current` pre-selects a loadout (the respawn swap keeps your weapons by default).
func _init(available: Array[StringName], time: float, current: Array[StringName] = []) -> void:
	_available = available.duplicate()
	time_left = time
	for id: StringName in current:
		if _available.has(id) and not picks.has(id) and picks.size() < SLOTS:
			picks.append(id)


func toggle(id: StringName) -> void:
	if done or not _available.has(id):
		return
	if picks.has(id):
		picks.erase(id)
		return
	if picks.size() >= SLOTS:
		picks.pop_front()
	picks.append(id)


func can_confirm() -> bool:
	return not done and picks.size() == SLOTS


func confirm() -> bool:
	if not can_confirm():
		return false
	done = true
	return true


## Counts down; on timeout fills the empty slots and finishes. Returns `done`.
func step(dt: float, rng: RandomNumberGenerator) -> bool:
	if done:
		return true
	time_left = maxf(time_left - dt, 0.0)
	if time_left <= 0.0:
		fill(rng)
		done = true
	return done


func fill(rng: RandomNumberGenerator) -> void:
	var left: Array[StringName] = []
	for id: StringName in _available:
		if not picks.has(id):
			left.append(id)
	while picks.size() < SLOTS and not left.is_empty():
		picks.append(left.pop_at(rng.randi_range(0, left.size() - 1)))
