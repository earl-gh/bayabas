class_name LocalInput
extends RefCounted
## Turns local devices (keyboard, on-screen stick) into movement for PlayerInput.


## WASD / arrow keys. Up is -1 on Y (screen up = toward the enemy base).
static func keyboard_vector() -> Vector2:
	var x: float = 0.0
	var y: float = 0.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		y += 1.0
	return Vector2(x, y).limit_length(1.0)


## Q = weapon 1, E = weapon 2, R = ball, Space or F = the pin (held to aim with the
## mouse, released to cast; a tap dashes the way you face).
static func weapon_key_held(slot: int) -> bool:
	if slot == 3:
		return Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_F)
	var keys: Array[Key] = [KEY_Q, KEY_E, KEY_R]
	return slot < keys.size() and Input.is_physical_key_pressed(keys[slot])


## Escape or right mouse button while aiming with Q/E cancels the cast.
static func cancel_held() -> bool:
	return Input.is_physical_key_pressed(KEY_ESCAPE) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)


## Keys that are plain buttons. None now: the weapons, the guava and the pin are
## aimed slots (see weapon_key_held).
static func keyboard_buttons() -> int:
	return 0


static func combine(a: Vector2, b: Vector2) -> Vector2:
	return (a + b).limit_length(1.0)


## Screen-relative stick to world movement: screen up is where the camera looks.
## The camera is turned `yaw_degrees` (behind-right view), and the other team's view
## is turned another 180 degrees, so the stick is turned the same way.
static func to_world(stick: Vector2, flip: bool, yaw_degrees: float = 0.0) -> Vector2:
	var yaw: float = deg_to_rad(yaw_degrees + (180.0 if flip else 0.0))
	return Vector2(stick.x * cos(yaw) + stick.y * sin(yaw), -stick.x * sin(yaw) + stick.y * cos(yaw))


## The inverse of `to_world`: the screen direction that moves along `world`.
static func to_screen(world: Vector2, flip: bool, yaw_degrees: float = 0.0) -> Vector2:
	var yaw: float = deg_to_rad(yaw_degrees + (180.0 if flip else 0.0))
	return Vector2(world.x * cos(yaw) - world.y * sin(yaw), world.x * sin(yaw) + world.y * cos(yaw))
