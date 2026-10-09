class_name Collision
extends RefCounted
## Circle-vs-axis-aligned-rectangle collision in the XZ plane (Vector2 = x, z).
## Plain math; no physics engine dependency.

const DEFAULT_PASSES: int = 3


## Returns `center`, moved the shortest way out of `rect` if the circle overlaps it.
static func push_out(center: Vector2, radius: float, rect: Rect2) -> Vector2:
	var closest: Vector2 = Vector2(
		clampf(center.x, rect.position.x, rect.end.x),
		clampf(center.y, rect.position.y, rect.end.y)
	)
	var delta: Vector2 = center - closest
	var distance_squared: float = delta.length_squared()
	if distance_squared > 0.0:
		if distance_squared >= radius * radius:
			return center
		return closest + delta / sqrt(distance_squared) * radius
	# Center is inside (or exactly on the edge of) the rect: leave through the nearest face.
	var to_left: float = center.x - rect.position.x
	var to_right: float = rect.end.x - center.x
	var to_top: float = center.y - rect.position.y
	var to_bottom: float = rect.end.y - center.y
	var nearest: float = minf(minf(to_left, to_right), minf(to_top, to_bottom))
	if nearest == to_left:
		return Vector2(rect.position.x - radius, center.y)
	if nearest == to_right:
		return Vector2(rect.end.x + radius, center.y)
	if nearest == to_top:
		return Vector2(center.x, rect.position.y - radius)
	return Vector2(center.x, rect.end.y + radius)


## Pushes the circle out of every rect; a few passes settle corners and gaps.
static func resolve(center: Vector2, radius: float, rects: Array[Rect2]) -> Vector2:
	var result: Vector2 = center
	for pass_index: int in DEFAULT_PASSES:
		for rect: Rect2 in rects:
			result = push_out(result, radius, rect)
	return result
