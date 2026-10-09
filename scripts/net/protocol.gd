class_name NetProtocol
extends RefCounted
## Message format between clients and the server. Every message is a Dictionary
## with "t" = Msg type, sent as var_to_bytes (no objects, so decoding is safe).

enum Msg {
	# client -> server
	HELLO, CREATE_ROOM, JOIN_ROOM, PICK_TEAM, SET_READY, START, LEAVE, LOADED,
	PICK_WEAPONS, SWAP_WEAPONS, INPUT,
	# server -> client
	WELCOME, ERROR, ROOM, MATCH_LOADING, MATCH_PLAY, SNAPSHOT, EVENTS,
}


static func encode(message: Dictionary) -> PackedByteArray:
	return var_to_bytes(message)


## Returns an empty Dictionary for anything that is not a valid message.
static func decode(bytes: PackedByteArray) -> Dictionary:
	var value: Variant = bytes_to_var(bytes)
	if value is Dictionary:
		var message: Dictionary = value as Dictionary
		if message.has("t") and message["t"] is int:
			return message
	return {}


static func input_to_dict(input: PlayerInput) -> Dictionary:
	return {"t": Msg.INPUT, "k": input.tick, "m": input.move, "a": input.aim, "b": input.buttons}


static func input_from_dict(message: Dictionary) -> PlayerInput:
	var move: Vector2 = message.get("m", Vector2.ZERO) as Vector2
	var aim: Vector2 = message.get("a", Vector2.ZERO) as Vector2
	return PlayerInput.create(move.limit_length(1.0), aim.limit_length(1.0), message.get("b", 0) as int, message.get("k", 0) as int)
