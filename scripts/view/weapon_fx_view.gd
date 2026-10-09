class_name WeaponFxView
extends Node3D
## Draws the sim's live weapon objects: projectiles, zones (landing warnings,
## traps, slow zones, jacks fields), paper shields, plus a short flash for cones.
## Read-only: rebuilt from WeaponSystem state every frame, keyed by object id.

const PROJECTILE_HEIGHT: float = 0.7
const ZONE_HEIGHT: float = 0.04
const SHIELD_HEIGHT: float = 1.6
const SHIELD_THICKNESS: float = 0.15
const TRAP_BALL_RADIUS: float = 0.3
const CONE_FLASH_TIME: float = 0.18
const CONE_POINTS: int = 12
const KIND_COLORS: Dictionary[WeaponDef.Kind, Color] = {
	WeaponDef.Kind.ATTACK: Color(1.0, 0.55, 0.25),
	WeaponDef.Kind.CROWD_CONTROL: Color(0.7, 0.45, 1.0),
	WeaponDef.Kind.BLOCK: Color(0.92, 0.92, 0.85),
}
const ZONE_COLORS: Dictionary[WeaponSystem.ZoneKind, Color] = {
	WeaponSystem.ZoneKind.EXPLOSION: Color(1.0, 0.2, 0.15, 0.35),
	WeaponSystem.ZoneKind.TRAP: Color(0.95, 0.95, 0.9, 1.0),
	WeaponSystem.ZoneKind.SLOW_ZONE: Color(0.35, 0.65, 1.0, 0.35),
	WeaponSystem.ZoneKind.FIELD: Color(1.0, 0.85, 0.3, 0.35),
}

var _nodes: Dictionary[int, MeshInstance3D] = {}
var _zone_kinds: Dictionary[int, WeaponSystem.ZoneKind] = {}
var _flashes: Array[MeshInstance3D] = []
var _flash_time: Dictionary[MeshInstance3D, float] = {}


## Starts listening for cone flashes from `sim`.
func watch(sim: MatchSim) -> void:
	sim.weapons.cone_struck.connect(_on_cone_struck)


func live_count() -> int:
	return _nodes.size()


func sync(sim: MatchSim, delta: float) -> void:
	var seen: Dictionary[int, bool] = {}
	for projectile: WeaponSystem.Projectile in sim.weapons.projectiles:
		seen[projectile.id] = true
		var node: MeshInstance3D = _nodes.get(projectile.id) as MeshInstance3D
		if node == null:
			node = _add(projectile.id, _projectile_mesh(projectile.def))
		node.position = Vector3(projectile.position.x, PROJECTILE_HEIGHT, projectile.position.y)
		node.rotation.y += delta * TAU * 2.0
	for zone: WeaponSystem.Zone in sim.weapons.zones:
		seen[zone.id] = true
		var node: MeshInstance3D = _nodes.get(zone.id) as MeshInstance3D
		if node != null and _zone_kinds[zone.id] != zone.kind:
			_remove(zone.id)
			node = null
		if node == null:
			node = _add(zone.id, _zone_mesh(zone))
			_zone_kinds[zone.id] = zone.kind
		node.position = Vector3(zone.center.x, ZONE_HEIGHT, zone.center.y)
	for shield: WeaponSystem.Shield in sim.weapons.shields:
		seen[shield.id] = true
		var node: MeshInstance3D = _nodes.get(shield.id) as MeshInstance3D
		if node == null:
			var box: BoxMesh = BoxMesh.new()
			box.size = Vector3(shield.half_width * 2.0, SHIELD_HEIGHT, SHIELD_THICKNESS)
			box.material = _material(KIND_COLORS[WeaponDef.Kind.BLOCK])
			node = _add(shield.id, box)
		node.position = Vector3(shield.center.x, SHIELD_HEIGHT / 2.0, shield.center.y)
		node.rotation.y = -shield.along.angle()
	for id: int in _nodes.keys():
		if not seen.has(id):
			_remove(id)
	_step_flashes(delta)


func _add(id: int, mesh: Mesh) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = mesh
	add_child(node)
	_nodes[id] = node
	return node


func _remove(id: int) -> void:
	_nodes[id].queue_free()
	_nodes.erase(id)
	_zone_kinds.erase(id)


func _projectile_mesh(def: WeaponDef) -> Mesh:
	var color: Color = KIND_COLORS[def.kind]
	if def.shape == WeaponDef.Shape.SPINNER:
		var top: CylinderMesh = CylinderMesh.new()
		top.top_radius = def.radius
		top.bottom_radius = 0.05
		top.height = def.radius
		top.material = _material(color)
		return top
	if def.shape == WeaponDef.Shape.BOOMERANG:
		var slipper: BoxMesh = BoxMesh.new()
		slipper.size = Vector3(def.projectile_radius * 1.2, 0.08, def.projectile_radius * 2.4)
		slipper.material = _material(color)
		return slipper
	var ball: SphereMesh = SphereMesh.new()
	var radius: float = def.projectile_radius if def.projectile_radius > 0.0 else 0.3
	ball.radius = radius
	ball.height = radius * 2.0
	ball.material = _material(color)
	return ball


func _zone_mesh(zone: WeaponSystem.Zone) -> Mesh:
	var color: Color = ZONE_COLORS[zone.kind]
	if zone.kind == WeaponSystem.ZoneKind.TRAP:
		var ball: SphereMesh = SphereMesh.new()
		ball.radius = TRAP_BALL_RADIUS
		ball.height = TRAP_BALL_RADIUS * 2.0
		ball.material = _material(color)
		return ball
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = zone.radius
	disc.bottom_radius = zone.radius
	disc.height = ZONE_HEIGHT
	disc.material = _material(color)
	return disc


func _material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _on_cone_struck(_owner_id: int, def: WeaponDef, origin: Vector2, direction: Vector2) -> void:
	var wedge: ImmediateMesh = ImmediateMesh.new()
	var half: float = deg_to_rad(def.angle_degrees / 2.0)
	wedge.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _material(Color(KIND_COLORS[def.kind], 0.5)))
	for i: int in CONE_POINTS:
		var a: Vector2 = origin + direction.rotated(-half + 2.0 * half * float(i) / float(CONE_POINTS)) * def.max_range
		var b: Vector2 = origin + direction.rotated(-half + 2.0 * half * float(i + 1) / float(CONE_POINTS)) * def.max_range
		wedge.surface_add_vertex(Vector3(origin.x, ZONE_HEIGHT * 2.0, origin.y))
		wedge.surface_add_vertex(Vector3(b.x, ZONE_HEIGHT * 2.0, b.y))
		wedge.surface_add_vertex(Vector3(a.x, ZONE_HEIGHT * 2.0, a.y))
	wedge.surface_end()
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = wedge
	add_child(node)
	_flashes.append(node)
	_flash_time[node] = CONE_FLASH_TIME


func _step_flashes(delta: float) -> void:
	var still: Array[MeshInstance3D] = []
	for node: MeshInstance3D in _flashes:
		_flash_time[node] -= delta
		if _flash_time[node] > 0.0:
			still.append(node)
		else:
			_flash_time.erase(node)
			node.queue_free()
	_flashes = still
