class_name AimIndicator
extends MeshInstance3D
## Ground lines showing where a weapon will go while its button is held: the range
## circle plus a shape-specific marker (line, cone, landing circle, wall).
## Uses the sim's own aim helpers so the preview matches the real cast.

const HEIGHT: float = 0.06
const CIRCLE_POINTS: int = 40
const READY_COLOR: Color = Color(1.0, 1.0, 1.0, 0.9)
const CANCEL_COLOR: Color = Color(1.0, 0.3, 0.3, 0.9)
const RANGE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.45)
const BOUNCE_MARK_RADIUS: float = 0.3

var _mesh: ImmediateMesh = ImmediateMesh.new()
var _material: StandardMaterial3D = StandardMaterial3D.new()


## Polylines (world x/z as Vector2) for one aimed weapon. The first is the range
## circle. `aim` is the resolved aim and `target_id` the locked target (TARGETED),
## both from MatchSim, so the preview never drifts after a moving enemy.
static func outline(sim: MatchSim, caster: PlayerState, def: WeaponDef, aim: Vector2, target_id: int = -1) -> Array[PackedVector2Array]:
	var lines: Array[PackedVector2Array] = []
	var origin: Vector2 = caster.position
	if def.max_range > 0.0:
		lines.append(circle(origin, def.max_range))
	match def.shape:
		WeaponDef.Shape.TARGETED:
			var target: PlayerState = sim.players.get(target_id) as PlayerState
			if target != null and sim.is_targetable(target):
				lines.append(PackedVector2Array([origin, target.position]))
				lines.append(circle(target.position, target.radius + 0.2))
		WeaponDef.Shape.CONE:
			var direction: Vector2 = sim.weapons.aim_direction(caster, aim)
			var half: float = deg_to_rad(def.angle_degrees / 2.0)
			var wedge: PackedVector2Array = PackedVector2Array([origin])
			for i: int in CIRCLE_POINTS / 4 + 1:
				var angle: float = -half + 2.0 * half * float(i) / float(CIRCLE_POINTS / 4)
				wedge.append(origin + direction.rotated(angle) * def.max_range)
			wedge.append(origin)
			lines.append(wedge)
		WeaponDef.Shape.GROUND_AOE, WeaponDef.Shape.FIELD, WeaponDef.Shape.TRAP:
			var point: Vector2 = sim.weapons.aim_point(caster, def, aim)
			lines.append(PackedVector2Array([origin, point]))
			lines.append(circle(point, def.radius if def.radius > 0.0 else def.trigger_radius))
		WeaponDef.Shape.BOOMERANG, WeaponDef.Shape.BOUNCER, WeaponDef.Shape.SPINNER:
			var direction: Vector2 = sim.weapons.aim_direction(caster, aim)
			var half_width: float = maxf(def.projectile_radius, def.radius if def.shape == WeaponDef.Shape.SPINNER else 0.0)
			var side: Vector2 = direction.orthogonal() * maxf(half_width, 0.15)
			var end: Vector2 = origin + direction * def.max_range
			lines.append(PackedVector2Array([origin + side, end + side, end - side, origin - side, origin + side]))
			if def.shape == WeaponDef.Shape.BOUNCER:
				for i: int in def.count:
					var at: Vector2 = origin + direction * def.max_range * float(i + 1) / float(maxi(def.count, 1))
					lines.append(circle(at, def.radius))
		WeaponDef.Shape.SHIELD:
			var facing: Vector2 = sim.weapons.aim_direction(caster, aim)
			var center: Vector2 = origin + facing * def.offset
			var along: Vector2 = facing.orthogonal() * def.width / 2.0
			lines.append(PackedVector2Array([center - along, center + along]))
	return lines


## Ball throw preview: range circle plus the throw line.
static func ball_outline(origin: Vector2, direction: Vector2, reach: float) -> Array[PackedVector2Array]:
	var lines: Array[PackedVector2Array] = [circle(origin, reach)]
	lines.append(PackedVector2Array([origin, origin + direction.normalized() * reach]))
	return lines


static func circle(center: Vector2, radius: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in CIRCLE_POINTS + 1:
		points.append(center + Vector2.from_angle(TAU * float(i) / float(CIRCLE_POINTS)) * radius)
	return points


func _ready() -> void:
	mesh = _mesh
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.vertex_color_use_as_albedo = true
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.no_depth_test = true
	material_override = _material


func clear() -> void:
	_mesh.clear_surfaces()


func show_aim(sim: MatchSim, caster: PlayerState, def: WeaponDef, aim: Vector2, target_id: int, cancelled: bool) -> void:
	show_lines(outline(sim, caster, def, aim, target_id), cancelled, def.max_range > 0.0)


## Draws polylines; the first is drawn faint as the range circle when `has_range`.
func show_lines(lines: Array[PackedVector2Array], cancelled: bool, has_range: bool = true) -> void:
	_mesh.clear_surfaces()
	var color: Color = CANCEL_COLOR if cancelled else READY_COLOR
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for index: int in lines.size():
		var line: PackedVector2Array = lines[index]
		var line_color: Color = RANGE_COLOR if index == 0 and has_range and not cancelled else color
		for i: int in line.size() - 1:
			_mesh.surface_set_color(line_color)
			_mesh.surface_add_vertex(Vector3(line[i].x, HEIGHT, line[i].y))
			_mesh.surface_set_color(line_color)
			_mesh.surface_add_vertex(Vector3(line[i + 1].x, HEIGHT, line[i + 1].y))
	_mesh.surface_end()
