class_name PlayerInput
extends RefCounted
## The one input format: touch, keyboard and network all produce this.
## Only move/aim/buttons/tick, never any gameplay decision.

const BTN_WEAPON_1: int = 1 << 0
const BTN_WEAPON_2: int = 1 << 1
const BTN_DASH: int = 1 << 2
const BTN_BOOKMARK: int = 1 << 3
const BTN_BALL: int = 1 << 4
## Sent on the tick a weapon button is released over the cancel zone: no cast.
const BTN_AIM_CANCEL: int = 1 << 5

## Movement stick, x = left/right, y = along the lane (screen up = -1). Length <= 1.
var move: Vector2 = Vector2.ZERO
## Aim direction in the same XZ plane (zero if not aiming).
var aim: Vector2 = Vector2.ZERO
var buttons: int = 0
var tick: int = 0


static func create(p_move: Vector2, p_aim: Vector2, p_buttons: int, p_tick: int) -> PlayerInput:
	var input: PlayerInput = PlayerInput.new()
	input.move = p_move
	input.aim = p_aim
	input.buttons = p_buttons
	input.tick = p_tick
	return input


func is_pressed(button: int) -> bool:
	return (buttons & button) != 0
