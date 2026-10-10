class_name LowPoly
extends RefCounted
## Tiny flat-shaded mesh builder for the low-poly look: boxes, prisms, cones and
## chunky spheres with one colour per face (vertex colours), all drawn with ONE
## shared material. Every face gets its own normal, so lighting is faceted.
##
##   var kit := LowPoly.new()
##   kit.box(Vector3(0, 1, 0), Vector3(2, 2, 2), Palette.SARI_YELLOW)
##   mesh_instance.mesh = kit.commit()

static var _shared_material: StandardMaterial3D

var _tool: SurfaceTool = SurfaceTool.new()
var _transform: Transform3D = Transform3D.IDENTITY
var _triangles: int = 0


## The single material every LowPoly mesh uses (vertex colour, matte).
static func material() -> StandardMaterial3D:
	if _shared_material == null:
		_shared_material = StandardMaterial3D.new()
		_shared_material.vertex_color_use_as_albedo = true
		_shared_material.roughness = 1.0
		_shared_material.metallic_specular = 0.2
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


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, inside: Vector3) -> void:
	tri(a, b, c, color, inside)
	tri(a, c, d, color, inside)


## Axis-aligned box. `top` colours the top face (defaults to `color`).
func box(center: Vector3, size: Vector3, color: Color, top: Color = Color(0, 0, 0, 0)) -> void:
	var h: Vector3 = size / 2.0
	var p: Array[Vector3] = []
	for i: int in 8:
		p.append(center + Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z))
	var top_color: Color = color if top.a == 0.0 else top
	quad(p[2], p[3], p[7], p[6], top_color, center)
	quad(p[0], p[1], p[5], p[4], color.darkened(0.25), center)
	quad(p[0], p[2], p[6], p[4], color.darkened(0.08), center)
	quad(p[1], p[3], p[7], p[5], color.darkened(0.08), center)
	quad(p[0], p[1], p[3], p[2], color, center)
	quad(p[4], p[5], p[7], p[6], color, center)


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
		var shade: Color = color.darkened(0.12 * (0.5 + 0.5 * sin(a0)))
		if radius_top > 0.001:
			quad(b0, b1, t1, t0, shade, inside)
			tri(top_center, t0, t1, cap_color, inside)
		else:
			tri(b0, b1, top_center, shade, inside)
		if radius_bottom > 0.001:
			tri(bottom, b1, b0, color.darkened(0.3), inside)


## Chunky low-poly ball (`rings` bands of `sides` facets).
func sphere(center: Vector3, radius: float, color: Color, sides: int = 7, rings: int = 4) -> void:
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
			var shade: Color = color.darkened(0.18 * float(r) / float(rings))
			if r == 0:
				tri(p00, p10, p11, shade, center)
			elif r == rings - 1:
				tri(p00, p01, p10, shade, center)
			else:
				quad(p00, p01, p11, p10, shade, center)


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
