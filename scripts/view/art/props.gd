class_name Props
extends RefCounted
## Low-poly street props built from LowPoly pieces (one material, palette colours).
## Inspired by Filipino streets: sari-sari store, houses with tin roofs, laundry
## lines, an electric post covered in flyers, cardboard walls, a tricycle.
## Meshes are cached per key, so the same prop is built once.

static var _cache: Dictionary[String, ArrayMesh] = {}


static func cached(key: String, build: Callable) -> ArrayMesh:
	if not _cache.has(key):
		_cache[key] = build.call() as ArrayMesh
	return _cache[key]


## A house front, facing +X (the lane is on its +X side). Footprint w (along Z) x d.
static func house(variant: int) -> ArrayMesh:
	return cached("house%d" % variant, func() -> ArrayMesh:
		var walls: Array[Color] = [Palette.WALL_MINT, Palette.WALL_PINK, Palette.WALL_SKY, Palette.WALL_LEMON, Palette.WALL_PEACH]
		var roofs: Array[Color] = [Palette.ROOF_TIN, Palette.ROOF_RUST, Palette.ROOF_RED]
		var wall: Color = walls[variant % walls.size()]
		var roof: Color = roofs[variant % roofs.size()]
		var width: float = 5.0 + float(variant % 3) * 0.8
		var depth: float = 4.0
		var height: float = 3.0 + float(variant % 2) * 0.6
		var kit: LowPoly = LowPoly.new()
		kit.box(Vector3(0.0, height / 2.0, 0.0), Vector3(depth, height, width), wall)
		kit.box(Vector3(depth / 2.0 + 0.02, 0.95, -width * 0.22), Vector3(0.08, 1.9, 0.9), Palette.DOOR)
		kit.box(Vector3(depth / 2.0 + 0.02, 1.6, width * 0.2), Vector3(0.08, 0.9, 1.2), Palette.WINDOW)
		kit.box(Vector3(depth / 2.0 + 0.06, 1.12, width * 0.2), Vector3(0.12, 0.08, 1.4), Palette.WHITE)
		# awning over the door
		kit.box(Vector3(depth / 2.0 + 0.45, 2.15, -width * 0.22), Vector3(0.9, 0.08, 1.3), roof.lightened(0.15))
		kit.set_transform(Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3.ZERO))
		kit.gable(Vector3(0.0, height, 0.0), width, depth, 1.3, roof, 0.35)
		kit.reset_transform()
		if variant % 2 == 0:
			kit.cylinder(Vector3(depth / 2.0 + 0.5, 0.0, width * 0.42), 0.28, 0.22, 0.45, 6, Palette.POT)
			kit.sphere(Vector3(depth / 2.0 + 0.5, 0.75, width * 0.42), 0.38, Palette.LEAF)
		return kit.commit())


## Sari-sari store front, facing +X: wide grilled window, yellow-red sign, tin roof.
static func sari_sari() -> ArrayMesh:
	return cached("sari", func() -> ArrayMesh:
		var kit: LowPoly = LowPoly.new()
		kit.box(Vector3(0.0, 1.5, 0.0), Vector3(3.5, 3.0, 5.0), Palette.WALL_LEMON)
		kit.box(Vector3(1.77, 1.45, 0.0), Vector3(0.06, 1.2, 3.6), Palette.WINDOW)
		for i: int in 9:
			kit.box(Vector3(1.82, 1.45, -1.6 + float(i) * 0.4), Vector3(0.05, 1.2, 0.05), Palette.WHITE)
		kit.box(Vector3(2.0, 0.85, 0.0), Vector3(0.5, 0.1, 3.8), Palette.WOOD)
		# little goods on the counter
		for i: int in 6:
			kit.box(Vector3(2.05, 0.98, -1.5 + float(i) * 0.6), Vector3(0.18, 0.18, 0.18), Palette.FLYERS[i % Palette.FLYERS.size()])
		kit.box(Vector3(1.95, 2.55, 0.0), Vector3(0.12, 0.7, 4.4), Palette.SARI_RED)
		kit.box(Vector3(2.02, 2.55, 0.0), Vector3(0.04, 0.45, 3.8), Palette.SARI_YELLOW)
		kit.set_transform(Transform3D(Basis(Vector3.FORWARD, -0.18), Vector3(0.3, 3.0, 0.0)))
		kit.box(Vector3.ZERO, Vector3(4.6, 0.1, 5.6), Palette.ROOF_TIN)
		kit.reset_transform()
		return kit.commit())


## Two poles and a sagging line of clothes, spanning `length` along Z.
static func laundry_line(length: float) -> ArrayMesh:
	return cached("laundry%.1f" % length, func() -> ArrayMesh:
		var kit: LowPoly = LowPoly.new()
		var half: float = length / 2.0
		for z: float in [-half, half]:
			kit.box(Vector3(0.0, 1.4, z), Vector3(0.12, 2.8, 0.12), Palette.WOOD)
		kit.box(Vector3(0.0, 2.6, 0.0), Vector3(0.03, 0.03, length), Palette.WIRE)
		var count: int = maxi(3, int(length / 0.9))
		for i: int in count:
			var z: float = -half + 0.5 + (length - 1.0) * float(i) / float(count - 1)
			var tall: float = 0.5 + float(i % 3) * 0.15
			kit.box(Vector3(0.0, 2.6 - tall / 2.0, z), Vector3(0.05, tall, 0.55), Palette.LAUNDRY[i % Palette.LAUNDRY.size()])
		return kit.commit())


## The concrete electric post with flyers stuck on it (septic, hiring, notices).
static func electric_post() -> ArrayMesh:
	return cached("post", func() -> ArrayMesh:
		var kit: LowPoly = LowPoly.new()
		kit.cylinder(Vector3.ZERO, 0.32, 0.2, 6.0, 8, Palette.POST_GREY)
		kit.box(Vector3(0.0, 5.6, 0.0), Vector3(2.2, 0.16, 0.16), Palette.POST_GREY.darkened(0.2))
		for x: float in [-0.9, 0.0, 0.9]:
			kit.cylinder(Vector3(x, 5.68, 0.0), 0.06, 0.06, 0.18, 5, Palette.WHITE)
		kit.box(Vector3(0.0, 4.7, -0.32), Vector3(0.5, 0.6, 0.3), Palette.POST_GREY.darkened(0.35))
		# flyers wrapped around the lower post
		for i: int in 10:
			var angle: float = TAU * float(i) / 7.0
			var height: float = 0.9 + float(i % 4) * 0.42
			var dir: Vector3 = Vector3(cos(angle), 0.0, sin(angle))
			var radius: float = 0.3 - height * 0.015
			kit.set_transform(Transform3D(Basis(Vector3.UP, -angle), dir * (radius + 0.015) + Vector3(0.0, height, 0.0)))
			kit.box(Vector3.ZERO, Vector3(0.03, 0.42, 0.3), Palette.FLYERS[i % Palette.FLYERS.size()])
		kit.reset_transform()
		return kit.commit())


## A cardboard wall column (bahay-bahayan): stacked boxes with tape, size w x h x d.
static func cardboard_wall(size: Vector3) -> ArrayMesh:
	return cached("cardboard%.2f_%.2f_%.2f" % [size.x, size.y, size.z], func() -> ArrayMesh:
		var kit: LowPoly = LowPoly.new()
		var rows: int = 2
		var columns: int = maxi(2, roundi(size.x / 1.6))
		var cell: Vector3 = Vector3(size.x / columns, size.y / rows, size.z)
		for r: int in rows:
			for c: int in columns:
				var shift: float = 0.06 if (r + c) % 2 == 0 else -0.06
				var center: Vector3 = Vector3(-size.x / 2.0 + cell.x * (float(c) + 0.5), cell.y * (float(r) + 0.5), shift)
				var tone: Color = Palette.CARDBOARD if (r + c) % 2 == 0 else Palette.CARDBOARD.darkened(0.08)
				kit.box(center, cell - Vector3(0.05, 0.04, 0.0), tone, tone.lightened(0.08))
				kit.box(center + Vector3(0.0, cell.y * 0.18, 0.0), Vector3(cell.x * 0.98, 0.1, cell.z + 0.02), Palette.TAPE)
		return kit.commit())


static func basketball_ring() -> ArrayMesh:
	return cached("hoop", func() -> ArrayMesh:
		var kit: LowPoly = LowPoly.new()
		kit.box(Vector3(0.0, 1.5, 0.0), Vector3(0.14, 3.0, 0.14), Palette.JEEP_BLUE)
		kit.box(Vector3(0.35, 3.0, 0.0), Vector3(0.7, 0.1, 0.1), Palette.JEEP_BLUE)
		kit.box(Vector3(0.72, 3.25, 0.0), Vector3(0.06, 0.8, 1.1), Palette.WHITE)
		kit.box(Vector3(0.74, 3.15, 0.0), Vector3(0.04, 0.3, 0.4), Palette.SARI_RED)
		for i: int in 8:
			var angle: float = TAU * float(i) / 8.0
			kit.box(Vector3(1.0 + cos(angle) * 0.24, 2.95, sin(angle) * 0.24), Vector3(0.09, 0.04, 0.09), Palette.RING_ORANGE)
		return kit.commit())


static func potted_plant() -> ArrayMesh:
	return cached("plant", func() -> ArrayMesh:
		var kit: LowPoly = LowPoly.new()
		kit.cylinder(Vector3.ZERO, 0.32, 0.25, 0.5, 6, Palette.POT)
		kit.sphere(Vector3(0.0, 0.85, 0.0), 0.45, Palette.LEAF)
		kit.sphere(Vector3(0.18, 1.2, 0.05), 0.28, Palette.LEAF_DARK)
		return kit.commit())


## Jeepney stop sign on a pole.
static func stop_sign() -> ArrayMesh:
	return cached("stop", func() -> ArrayMesh:
		var kit: LowPoly = LowPoly.new()
		kit.box(Vector3(0.0, 1.2, 0.0), Vector3(0.1, 2.4, 0.1), Palette.POST_GREY)
		kit.box(Vector3(0.0, 2.45, 0.0), Vector3(0.08, 0.6, 1.0), Palette.JEEP_BLUE)
		kit.box(Vector3(0.05, 2.45, 0.0), Vector3(0.02, 0.2, 0.7), Palette.WHITE)
		return kit.commit())


## A parked jeepney, long axis along Z.
static func jeepney() -> ArrayMesh:
	return cached("jeep", func() -> ArrayMesh:
		var kit: LowPoly = LowPoly.new()
		kit.box(Vector3(0.0, 1.1, 0.0), Vector3(2.0, 1.4, 5.5), Palette.WHITE, Palette.JEEP_BLUE)
		kit.box(Vector3(0.0, 1.1, 0.0), Vector3(2.04, 0.35, 5.54), Palette.JEEP_RED)
		kit.box(Vector3(0.0, 1.45, 0.4), Vector3(2.05, 0.55, 3.8), Palette.WINDOW)
		kit.box(Vector3(0.0, 1.0, -3.0), Vector3(1.8, 1.0, 0.8), Palette.JEEP_CHROME)
		kit.box(Vector3(0.0, 1.9, 0.0), Vector3(2.1, 0.12, 5.7), Palette.JEEP_CHROME)
		kit.box(Vector3(0.0, 2.1, -2.6), Vector3(0.3, 0.3, 0.3), Palette.SARI_YELLOW)
		for z: float in [-2.0, 1.9]:
			for x: float in [-1.0, 1.0]:
				kit.set_transform(Transform3D(Basis(Vector3.BACK, PI / 2.0), Vector3(x, 0.4, z)))
				kit.cylinder(Vector3(0.0, -0.15, 0.0), 0.4, 0.4, 0.3, 8, Palette.BLACK)
		kit.reset_transform()
		return kit.commit())


## The tricycle: motorcycle plus sidecar with a roof, long axis along X (it drives along X).
static func tricycle(length: float, width: float) -> ArrayMesh:
	return cached("tricycle%.1f_%.1f" % [length, width], func() -> ArrayMesh:
		var kit: LowPoly = LowPoly.new()
		var hw: float = width / 2.0
		kit.box(Vector3(0.0, 0.85, -hw * 0.25), Vector3(length * 0.8, 0.9, width * 0.6), Palette.JEEP_RED, Palette.SARI_YELLOW)
		kit.box(Vector3(0.0, 1.75, -hw * 0.25), Vector3(length * 0.85, 0.1, width * 0.7), Palette.JEEP_BLUE)
		for x: float in [-length * 0.38, length * 0.38]:
			kit.box(Vector3(x, 1.3, -hw * 0.25), Vector3(0.07, 0.9, 0.07), Palette.JEEP_CHROME)
		kit.box(Vector3(0.0, 1.05, -hw * 0.25 + width * 0.31), Vector3(length * 0.6, 0.5, 0.05), Palette.WINDOW)
		# motorcycle on the +Z side
		kit.box(Vector3(0.0, 0.75, hw * 0.65), Vector3(length * 0.75, 0.35, 0.3), Palette.BLACK)
		kit.box(Vector3(length * 0.3, 1.15, hw * 0.65), Vector3(0.1, 0.5, 0.6), Palette.JEEP_CHROME)
		for wheel: Vector3 in [Vector3(-length * 0.35, 0.32, hw * 0.65), Vector3(length * 0.35, 0.32, hw * 0.65), Vector3(-length * 0.1, 0.32, -hw * 0.75)]:
			kit.set_transform(Transform3D(Basis(Vector3.RIGHT, PI / 2.0), wheel))
			kit.cylinder(Vector3(0.0, -0.1, 0.0), 0.32, 0.32, 0.2, 8, Palette.BLACK)
		kit.reset_transform()
		return kit.commit())


static func rubber_ball(radius: float) -> ArrayMesh:
	return cached("rubber%.2f" % radius, func() -> ArrayMesh:
		var kit: LowPoly = LowPoly.new()
		kit.sphere(Vector3.ZERO, radius, Palette.RUBBER_BALL, 8, 5)
		kit.box(Vector3.ZERO, Vector3(radius * 2.05, radius * 0.35, radius * 0.35), Palette.WHITE)
		return kit.commit())


## The thrown object for a weapon (by WeaponDef id); sized by its radius.
static func weapon_object(id: StringName, radius: float) -> ArrayMesh:
	return cached("weapon_%s_%.2f" % [id, radius], func() -> ArrayMesh:
		var kit: LowPoly = LowPoly.new()
		var r: float = maxf(radius, 0.15)
		match id:
			&"bato_light", &"bato_heavy":
				kit.sphere(Vector3.ZERO, r, Palette.CONCRETE.darkened(0.15), 5, 3)
			&"papel_trap":
				kit.sphere(Vector3.ZERO, r, Palette.WHITE, 5, 3)
			&"tsinelas_light", &"tsinelas_heavy":
				kit.box(Vector3.ZERO, Vector3(r * 1.1, r * 0.3, r * 2.4), Palette.JEEP_BLUE, Palette.SARI_YELLOW)
				kit.box(Vector3(0.0, r * 0.3, -r * 0.5), Vector3(r * 1.0, r * 0.2, r * 0.2), Palette.SARI_RED)
			&"lata":
				kit.cylinder(Vector3(0.0, -r, 0.0), r * 0.7, r * 0.7, r * 2.0, 8, Palette.JEEP_CHROME)
				kit.cylinder(Vector3(0.0, -r * 0.4, 0.0), r * 0.72, r * 0.72, r * 0.8, 8, Palette.SARI_RED)
			&"jacks":
				for axis: Vector3 in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
					kit.box(Vector3.ZERO, Vector3.ONE * r * 0.25 + axis * r * 1.6, Palette.JEEP_CHROME)
			&"bola":
				kit.sphere(Vector3.ZERO, r, Palette.SARI_RED, 7, 4)
			&"trumpo":
				kit.cylinder(Vector3(0.0, -r * 0.7, 0.0), 0.02, r, r * 0.9, 8, Palette.WOOD)
				kit.cylinder(Vector3(0.0, r * 0.2, 0.0), r, r * 0.3, r * 0.4, 8, Palette.SARI_RED)
			_:
				kit.sphere(Vector3.ZERO, r, Palette.WHITE)
		return kit.commit())


## The polymorphed player: a big can (tumbang preso lata).
static func can_body() -> ArrayMesh:
	return cached("can", func() -> ArrayMesh:
		var kit: LowPoly = LowPoly.new()
		kit.cylinder(Vector3.ZERO, 0.42, 0.42, 0.95, 10, Palette.JEEP_CHROME, Palette.CONCRETE)
		kit.cylinder(Vector3(0.0, 0.25, 0.0), 0.44, 0.44, 0.45, 10, Palette.SARI_RED)
		return kit.commit())
