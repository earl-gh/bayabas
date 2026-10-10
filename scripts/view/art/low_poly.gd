class_name LowPoly
extends RefCounted
## Small mesh builder for the soft, chunky toy look (Clash of Clans-like): boxes
## get bevelled edges with a light rim on top, spheres and cylinders are smooth
## shaded, colours are vertex colours, and everything uses ONE shared material.
##
##   var kit := LowPoly.new()
##   kit.box(Vector3(0, 1, 0), Vector3(2, 2, 2), Palette.SARI_YELLOW)
##   mesh_instance.mesh = kit.commit()

static var _shared_material: StandardMaterial3D

## Bevel = this fraction of the box's smallest side, between MIN (else none) and MAX.
const BEVEL_RATIO: float = 0.18
const BEVEL_MIN: float = 0.025
const BEVEL_MAX: float = 0.09

var _tool: SurfaceTool = SurfaceTool.new()
var _transform: Transform3D = Transform3D.IDENTITY
var _triangles: int = 0


## The single material every LowPoly mesh uses (vertex colour, matte).
static func material() -> StandardMaterial3D:
	if _shared_material == null:
		_shared_material = StandardMaterial3D.new()
		_shared_material.vertex_color_use_as_albedo = true
		_shared_material.roughness = 1.0
		# soft matte toy shading: light wraps around, a gentle rim, no hard specular
		_shared_material.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
		_shared_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		_shared_material.rim_enabled = true
		_shared_material.rim = 0.15
		_shared_material.rim_tint = 0.7
	return _shared_material


func _init() -> void:
	_tool.begin(Mesh.PRIMITIVE_TRIANGLES)


## Everything added afterwards is placed with `transform` (e.g. a rotated roof).
func set_transform(transform: Transform3D) -> void:
	_transform = transform


func reset_transform() -> void:
	_transform = Transform3D.IDENTITY


func triangle_count() -> int:
	return _triangles


func commit() -> ArrayMesh:
	var mesh: ArrayMesh = _tool.commit()
	if mesh.get_surface_count() > 0:
		mesh.surface_set_material(0, material())
	return mesh


## One triangle facing away from `inside` (a point inside the solid).
func tri(a: Vector3, b: Vector3, c: Vector3, color: Color, inside: Vector3) -> void:
	var pa: Vector3 = _transform * a
	var pb: Vector3 = _transform * b
	var pc: Vector3 = _transform * c
	var normal: Vector3 = (pb - pa).cross(pc - pa)
	if normal.length_squared() < 1e-12:
		return
	var center: Vector3 = (pa + pb + pc) / 3.0
	if normal.dot(center - _transform * inside) < 0.0:
		var swap: Vector3 = pb
		pb = pc
		pc = swap
		normal = -normal
	normal = normal.normalized()
	# Godot treats clockwise (seen from the front) as the front face.
	for vertex: Vector3 in [pa, pc, pb]:
		_tool.set_color(color)
		_tool.set_normal(normal)
		_tool.add_vertex(vertex)
	_triangles += 1


## A triangle with its own per-vertex normals (smooth shading on round shapes).
func tri_smooth(a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, color: Color) -> void:
	var pa: Vector3 = _transform * a
	var pb: Vector3 = _transform * b
	var pc: Vector3 = _transform * c
	var basis: Basis = _transform.basis
	var face: Vector3 = (pb - pa).cross(pc - pa)
	if face.length_squared() < 1e-12:
		return
	var nsum: Vector3 = basis * (na + nb + nc)
	var verts: Array[Vector3] = [pa, pc, pb]
	var norms: Array[Vector3] = [basis * na, basis * nc, basis * nb]
	if face.dot(nsum) < 0.0:
		verts = [pa, pb, pc]
		norms = [basis * na, basis * nb, basis * nc]
	for i: int in 3:
		_tool.set_color(color)
		_tool.set_normal(norms[i].normalized())
		_tool.add_vertex(verts[i])
	_triangles += 1


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, inside: Vector3) -> void:
	tri(a, b, c, color, inside)
	tri(a, c, d, color, inside)


## Axis-aligned box with bevelled edges (skipped on tiny boxes). `top` colours the
## top face (defaults to `color`); top edges catch a soft highlight.
func box(center: Vector3, size: Vector3, color: Color, top: Color = Color(0, 0, 0, 0)) -> void:
	var h: Vector3 = size / 2.0
	var top_color: Color = color if top.a == 0.0 else top
	var bevel: float = minf(BEVEL_MAX, minf(size.x, minf(size.y, size.z)) * BEVEL_RATIO)
	if bevel < BEVEL_MIN:
		_plain_box(center, h, color, top_color)
		return
	# three points per corner, each pulled in along the other two axes
	var corner: Dictionary = {}
	for sx: int in [-1, 1]:
		for sy: int in [-1, 1]:
			for sz: int in [-1, 1]:
				var s3: Vector3 = Vector3(sx, sy, sz)
				corner[Vector3i(sx, sy, sz)] = [
					center + s3 * Vector3(h.x, h.y - bevel, h.z - bevel),
					center + s3 * Vector3(h.x - bevel, h.y, h.z - bevel),
					center + s3 * Vector3(h.x - bevel, h.y - bevel, h.z),
				]
	var shades: Array[Color] = [color.darkened(0.08), top_color, color]
	var bottom: Color = color.darkened(0.25)
	# the six faces
	for axis: int in 3:
		for sign: int in [-1, 1]:
			var points: Array[Vector3] = []
			for key: Vector3i in [_face_key(axis, sign, -1, -1), _face_key(axis, sign, 1, -1), _face_key(axis, sign, 1, 1), _face_key(axis, sign, -1, 1)]:
				points.append((corner[key] as Array)[axis] as Vector3)
			var face_color: Color = shades[axis]
			if axis == 1 and sign < 0:
				face_color = bottom
			quad(points[0], points[1], points[2], points[3], face_color, center)
	# the twelve bevelled edges
	for axis_a: int in 3:
		for axis_b: int in range(axis_a + 1, 3):
			var free_axis: int = 3 - axis_a - axis_b
			for sa: int in [-1, 1]:
				for sb: int in [-1, 1]:
					var k0: Vector3i = _edge_key(axis_a, sa, axis_b, sb, free_axis, -1)
					var k1: Vector3i = _edge_key(axis_a, sa, axis_b, sb, free_axis, 1)
					var edge_color: Color = color.darkened(0.04)
					if (axis_a == 1 and sa > 0) or (axis_b == 1 and sb > 0):
						edge_color = top_color.lightened(0.18)
					elif (axis_a == 1 and sa < 0) or (axis_b == 1 and sb < 0):
						edge_color = bottom
					quad((corner[k0] as Array)[axis_a] as Vector3, (corner[k1] as Array)[axis_a] as Vector3,
						(corner[k1] as Array)[axis_b] as Vector3, (corner[k0] as Array)[axis_b] as Vector3, edge_color, center)
	# the eight corner caps
	for key: Variant in corner:
		var pts: Array = corner[key] as Array
		var cap: Color = top_color.lightened(0.12) if (key as Vector3i).y > 0 else bottom
		tri(pts[0] as Vector3, pts[1] as Vector3, pts[2] as Vector3, cap, center)


func _plain_box(center: Vector3, h: Vector3, color: Color, top_color: Color) -> void:
	var p: Array[Vector3] = []
	for i: int in 8:
		p.append(center + Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z))
	quad(p[2], p[3], p[7], p[6], top_color, center)
	quad(p[0], p[1], p[5], p[4], color.darkened(0.25), center)
	quad(p[0], p[2], p[6], p[4], color.darkened(0.08), center)
	quad(p[1], p[3], p[7], p[5], color.darkened(0.08), center)
	quad(p[0], p[1], p[3], p[2], color, center)
	quad(p[4], p[5], p[7], p[6], color, center)


## Corner key on the face `axis`/`sign`, walking the other two axes by u/v signs.
static func _face_key(axis: int, sign: int, u: int, v: int) -> Vector3i:
	var key: Array[int] = [0, 0, 0]
	key[axis] = sign
	key[(axis + 1) % 3] = u
	key[(axis + 2) % 3] = v
	return Vector3i(key[0], key[1], key[2])


static func _edge_key(axis_a: int, sa: int, axis_b: int, sb: int, free_axis: int, sf: int) -> Vector3i:
	var key: Array[int] = [0, 0, 0]
	key[axis_a] = sa
	key[axis_b] = sb
	key[free_axis] = sf
	return Vector3i(key[0], key[1], key[2])


## Upright prism / cylinder / cone: `sides` facets from `bottom` up `height`.
func cylinder(bottom: Vector3, radius_bottom: float, radius_top: float, height: float, sides: int, color: Color, cap: Color = Color(0, 0, 0, 0)) -> void:
	var inside: Vector3 = bottom + Vector3(0.0, height / 2.0, 0.0)
	var top_center: Vector3 = bottom + Vector3(0.0, height, 0.0)
	var cap_color: Color = color if cap.a == 0.0 else cap
	for i: int in sides:
		var a0: float = TAU * float(i) / float(sides)
		var a1: float = TAU * float(i + 1) / float(sides)
		var d0: Vector3 = Vector3(cos(a0), 0.0, sin(a0))
		var d1: Vector3 = Vector3(cos(a1), 0.0, sin(a1))
		var b0: Vector3 = bottom + d0 * radius_bottom
		var b1: Vector3 = bottom + d1 * radius_bottom
		var t0: Vector3 = top_center + d0 * radius_top
		var t1: Vector3 = top_center + d1 * radius_top
		var slope: float = (radius_bottom - radius_top) / maxf(height, 0.001)
		var n0: Vector3 = (d0 + Vector3(0.0, slope, 0.0)).normalized()
		var n1: Vector3 = (d1 + Vector3(0.0, slope, 0.0)).normalized()
		if radius_top > 0.001:
			tri_smooth(b0, b1, t1, n0, n1, n1, color)
			tri_smooth(b0, t1, t0, n0, n1, n0, color)
			tri(top_center, t0, t1, cap_color, inside)
		else:
			tri_smooth(b0, b1, top_center, n0, n1, (n0 + n1).normalized(), color)
		if radius_bottom > 0.001:
			tri(bottom, b1, b0, color.darkened(0.3), inside)


## Chunky low-poly ball (`rings` bands of `sides` facets).
func sphere(center: Vector3, radius: float, color: Color, sides: int = 10, rings: int = 6) -> void:
	for r: int in rings:
		var v0: float = PI * float(r) / float(rings)
		var v1: float = PI * float(r + 1) / float(rings)
		for s: int in sides:
			var u0: float = TAU * float(s) / float(sides)
			var u1: float = TAU * float(s + 1) / float(sides)
			var p00: Vector3 = center + _sphere_point(u0, v0) * radius
			var p01: Vector3 = center + _sphere_point(u1, v0) * radius
			var p10: Vector3 = center + _sphere_point(u0, v1) * radius
			var p11: Vector3 = center + _sphere_point(u1, v1) * radius
			var n00: Vector3 = _sphere_point(u0, v0)
			var n01: Vector3 = _sphere_point(u1, v0)
			var n10: Vector3 = _sphere_point(u0, v1)
			var n11: Vector3 = _sphere_point(u1, v1)
			if r == 0:
				tri_smooth(p00, p10, p11, n00, n10, n11, color)
			elif r == rings - 1:
				tri_smooth(p00, p01, p10, n00, n01, n10, color)
			else:
				tri_smooth(p00, p01, p11, n00, n01, n11, color)
				tri_smooth(p00, p11, p10, n00, n11, n10, color)


## A gable roof (triangular prism) over a w x d footprint at height y, ridge along X.
func gable(center: Vector3, width: float, depth: float, rise: float, color: Color, overhang: float = 0.2) -> void:
	var hw: float = width / 2.0 + overhang
	var hd: float = depth / 2.0 + overhang
	var y: float = center.y
	var inside: Vector3 = center + Vector3(0.0, rise * 0.3, 0.0)
	var a: Vector3 = Vector3(center.x - hw, y, center.z - hd)
	var b: Vector3 = Vector3(center.x + hw, y, center.z - hd)
	var c: Vector3 = Vector3(center.x + hw, y, center.z + hd)
	var d: Vector3 = Vector3(center.x - hw, y, center.z + hd)
	var r0: Vector3 = Vector3(center.x - hw, y + rise, center.z)
	var r1: Vector3 = Vector3(center.x + hw, y + rise, center.z)
	quad(a, b, r1, r0, color.darkened(0.12), inside)
	quad(d, c, r1, r0, color, inside)
	tri(a, d, r0, color.darkened(0.2), inside)
	tri(b, c, r1, color.darkened(0.2), inside)


static func _sphere_point(u: float, v: float) -> Vector3:
	return Vector3(sin(v) * cos(u), cos(v), sin(v) * sin(u))


static var _outline_material: StandardMaterial3D


## Dark, front-culled material for cartoon outlines (inverted hull).
static func outline_material() -> StandardMaterial3D:
	if _outline_material == null:
		_outline_material = StandardMaterial3D.new()
		_outline_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_outline_material.cull_mode = BaseMaterial3D.CULL_FRONT
		_outline_material.albedo_color = Color(0.13, 0.08, 0.1)
	return _outline_material


## Gives `node` a cartoon outline: a slightly larger, inside-out copy of its mesh,
## scaled about the mesh's own centre so off-centre parts line up.
static func add_outline(node: MeshInstance3D, thickness: float = 0.035) -> MeshInstance3D:
	var box: AABB = node.mesh.get_aabb()
	var extent: float = maxf(box.size.x, maxf(box.size.y, box.size.z))
	var scale: float = 1.0 + 2.0 * thickness / maxf(extent, 0.05)
	var center: Vector3 = box.get_center()
	var shell: MeshInstance3D = MeshInstance3D.new()
	shell.name = "Outline"
	shell.mesh = node.mesh
	shell.material_override = outline_material()
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shell.scale = Vector3.ONE * scale
	shell.position = center - center * scale
	node.add_child(shell)
	return shell
