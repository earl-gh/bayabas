class_name MatchInput
extends RefCounted
## Turns the local player's devices into one PlayerInput per sim tick: the
## on-screen stick, skill buttons, the three aimed slots (weapon 1, weapon 2,
## guava) and the keyboard/mouse equivalents. No nodes; the match screen feeds it
## events and asks for `build()` every tick.
##
## An aimed slot is a small state machine so a quick tap is never lost: press
## starts aiming (the sim sees the button held), release sends one tick with the
## aim and, if it was cancelled, BTN_AIM_CANCEL.

const AIM_BITS: Array[int] = [PlayerInput.BTN_WEAPON_1, PlayerInput.BTN_WEAPON_2, PlayerInput.BTN_BALL]
const SLOTS: int = 3

var stick: Vector2 = Vector2.ZERO
var pending_buttons: int = 0
## Per aimed slot: finger down, release waiting to be sent, Q/E/R aiming.
var touch_held: Array[bool] = [false, false, false]
var key_held: Array[bool] = [false, false, false]
var key_aim: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
var key_cancel: Array[bool] = [false, false, false]

var _sent_held: Array[bool] = [false, false, false]
var _release_pending: Array[bool] = [false, false, false]
var _release_aim: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
var _release_cancel: Array[bool] = [false, false, false]


func set_stick(value: Vector2) -> void:
	stick = value


## A skill button was pressed; it is sent with the next tick.
func press_skill(button_bit: int) -> void:
	pending_buttons |= button_bit


## An aimed slot started aiming.
func aim_started(slot: int) -> void:
	touch_held[slot] = true
	_release_pending[slot] = false


## An aimed slot was let go with a WORLD-space aim (zero = auto-aim).
func aim_released(world_aim: Vector2, cancelled: bool, slot: int) -> void:
	touch_held[slot] = false
	_release_pending[slot] = true
	_release_aim[slot] = world_aim
	_release_cancel[slot] = cancelled


func any_touch_held() -> bool:
	return touch_held.has(true)


## Forget everything held or pending (the pick screen opened over the controls).
func clear() -> void:
	stick = Vector2.ZERO
	pending_buttons = 0
	for slot: int in SLOTS:
		touch_held[slot] = false
		_release_pending[slot] = false
		_sent_held[slot] = false


## This tick's input. `flip` turns screen directions around for the team that
## defends the -Z base; `mouse_aim` is called as `mouse_aim.call(slot)` for Q/E/R.
func build(flip: bool, mouse_aim: Callable, tick: int) -> PlayerInput:
	var combined: Vector2 = LocalInput.combine(stick, LocalInput.keyboard_vector())
	var world_move: Vector2 = LocalInput.to_world(combined, flip)
	var buttons: int = pending_buttons | LocalInput.keyboard_buttons()
	pending_buttons = 0
	var aim: Vector2 = Vector2.ZERO
	var cancel: bool = false
	# holding one skill locks the others: no Dash or Bookmark in the middle of an aim
	if touch_held.has(true) or key_held.has(true):
		buttons &= ~(PlayerInput.BTN_DASH | PlayerInput.BTN_BOOKMARK)
	for slot: int in SLOTS:
		var bit: int = AIM_BITS[slot]
		var key: bool = LocalInput.weapon_key_held(slot) and not touch_held[slot] and not _release_pending[slot]
		if key:
			if not key_held[slot]:
				key_cancel[slot] = false
			key_held[slot] = true
			key_cancel[slot] = key_cancel[slot] or LocalInput.cancel_held()
			key_aim[slot] = mouse_aim.call(slot) as Vector2
			buttons |= bit
		elif key_held[slot]:
			key_held[slot] = false
			aim = key_aim[slot]
			cancel = key_cancel[slot]
		elif touch_held[slot]:
			buttons |= bit
			_sent_held[slot] = true
		elif _release_pending[slot]:
			if not _sent_held[slot]:
				# a tap shorter than one tick: send one held tick, then the release
				buttons |= bit
				_sent_held[slot] = true
			else:
				aim = _release_aim[slot]
				cancel = _release_cancel[slot]
				_release_pending[slot] = false
				_sent_held[slot] = false
	if cancel:
		buttons |= PlayerInput.BTN_AIM_CANCEL
	return PlayerInput.create(world_move, aim, buttons, tick)
