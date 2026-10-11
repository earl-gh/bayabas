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


## A two-storey house with a balcony, grilled windows and a water tank on the roof.
static func house_tall(variant: int) -> ArrayMesh:
	return cached("house_tall%d" % variant, func() -> ArrayMesh:
		var walls: Array[Color] = [Palette.WALL_PEACH, Palette.WALL_SKY, Palette.WALL_MINT, Palette.WALL_PINK]
		var wall: Color = walls[variant % walls.size()]
		var upper: Color = wall.lightened(0.12)
		var width: float = 5.6
		var depth: float = 4.4
		var kit: LowPoly = LowPoly.new()
		# concrete ground floor, painted wooden upper floor
		kit.box(Vector3(0.0, 1.5, 0.0), Vector3(depth, 3.0, width), Palette.CONCRETE, Palette.CONCRETE)
		kit.box(Vector3(0.1, 4.3, 0.0), Vector3(depth + 0.2, 2.6, width + 0.2), upper)
		kit.box(Vector3(depth / 2.0 + 0.02, 1.0, -1.2), Vector3(0.08, 2.0, 1.0), Palette.DOOR)
		kit.box(Vector3(depth / 2.0 + 0.02, 1.7, 1.2), Vector3(0.08, 1.0, 1.6), Palette.WINDOW)
		for i: int in 5:
			kit.box(Vector3(depth / 2.0 + 0.07, 1.7, 0.5 + float(i) * 0.35), Vector3(0.04, 1.0, 0.04), Palette.WHITE)
		# balcony with railing and plants
		kit.box(Vector3(depth / 2.0 + 0.7, 3.05, 0.0), Vector3(1.4, 0.15, width * 0.8), Palette.CONCRETE)
		for i: int in 9:
			kit.box(Vector3(depth / 2.0 + 1.35, 3.45, -width * 0.38 + float(i) * width * 0.095), Vector3(0.05, 0.7, 0.05), Palette.WIRE)
		kit.box(Vector3(depth / 2.0 + 1.35, 3.8, 0.0), Vector3(0.08, 0.06, width * 0.8), Palette.WIRE)
		for z: float in [-1.6, 1.6]:
			kit.cylinder(Vector3(depth / 2.0 + 0.9, 3.12, z), 0.18, 0.14, 0.3, 6, Palette.POT)
			kit.sphere(Vector3(depth / 2.0 + 0.9, 3.6, z), 0.28, Palette.LEAF)
		kit.box(Vector3(depth / 2.0 + 0.14, 4.4, 0.0), Vector3(0.08, 1.2, 2.4), Palette.WINDOW)
		kit.box(Vector3(depth / 2.0 + 0.19, 4.4, 0.0), Vector3(0.04, 1.3, 0.08), Palette.WHITE)
		kit.set_transform(Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3.ZERO))
		kit.gable(Vector3(0.0, 5.6, 0.0), width + 0.2, depth + 0.2, 1.4, Palette.ROOF_TIN if variant % 2 == 0 else Palette.ROOF_RED, 0.4)
		kit.reset_transform()
		# blue water tank on a stand at the back
		for x: float in [-0.5, 0.5]:
			for z: float in [-0.5, 0.5]:
				kit.box(Vector3(-depth / 2.0 + 0.6 + x, 6.6, 1.5 + z), Vector3(0.08, 1.2, 0.08), Palette.WIRE)
		kit.cylinder(Vector3(-depth / 2.0 + 0.6, 7.2, 1.5), 0.65, 0.65, 1.1, 8, Palette.JEEP_BLUE, Palette.JEEP_BLUE.lightened(0.2))
		return kit.commit())


## A fiesta tarpaulin banner (fictional, no real names), facing +X.
static func tarpaulin(variant: int) -> ArrayMesh:
	return cached("tarp%d" % variant, func() -> ArrayMesh:
		var kit: LowPoly = LowPoly.new()
		var colors: Array[Color] = [Palette.SARI_YELLOW, Palette.WALL_SKY, Palette.WALL_PINK]
		var base: Color = colors[variant % colors.size()]
		kit.box(Vector3.ZERO, Vector3(0.04, 1.0, 2.2), Palette.WHITE)
		kit.box(Vector3(0.03, 0.25, 0.0), Vector3(0.02, 0.4, 2.0), base)
		kit.box(Vector3(0.03, -0.22, -0.55), Vector3(0.02, 0.35, 0.7), Palette.JEEP_RED)
		kit.box(Vector3(0.03, -0.22, 0.45), Vector3(0.02, 0.12, 0.9), Palette.BLACK)
		kit.box(Vector3(0.03, -0.36, 0.45), Vector3(0.02, 0.08, 0.7), Palette.BLACK)
		return kit.commit())


## Banderitas: fiesta bunting strung across the street (x from -span/2 to span/2).
static func banderitas(span: float, seed_value: int) -> ArrayMesh:
	return cached("bunting%.1f_%d" % [span, seed_value], func() -> ArrayMesh:
		var kit: LowPoly = LowPoly.new()
		var colors: Array[Color] = [Palette.JEEP_RED, Palette.SARI_YELLOW, Palette.JEEP_BLUE, Palette.WHITE, Palette.LEAF, Palette.WALL_PINK]
		var count: int = int(span / 0.55)
		var sag: float = 0.6
		for i: int in count:
			var u: float = (float(i) + 0.5) / float(count)
			var x: float = -span / 2.0 + span * u
			var y: float = -sag * 4.0 * u * (1.0 - u)
			var color: Color = colors[(i + seed_value) % colors.size()]
			var center: Vector3 = Vector3(x, y, 0.0)
			kit.tri(center + Vector3(-0.2, 0.0, 0.0), center + Vector3(0.2, 0.0, 0.0), center + Vector3(0.0, -0.42, 0.0), color, center + Vector3(0.0, -0.15, 0.08))
			kit.tri(center + Vector3(-0.2, 0.0, 0.0), center + Vector3(0.2, 0.0, 0.0), center + Vector3(0.0, -0.42, 0.0), color.darkened(0.15), center + Vector3(0.0, -0.15, -0.08))
			kit.box(center + Vector3(0.0, 0.01, 0.0), Vector3(0.55, 0.025, 0.025), Palette.WIRE)
		return kit.commit())


## Wooden utility pole with a crossarm (wires are drawn between poles).
static func power_pole() -> ArrayMesh:
	return cached("pole", func() -> ArrayMesh:
		var kit: LowPoly = LowPoly.new()
		kit.cylinder(Vector3.ZERO, 0.17, 0.13, 7.0, 6, Palette.WOOD)
		kit.box(Vector3(0.0, 6.6, 0.0), Vector3(0.12, 0.12, 1.6), Palette.WOOD.darkened(0.15))
		kit.cylinder(Vector3(0.0, 5.6, 0.25), 0.22, 0.22, 0.6, 6, Palette.POST_GREY)
		return kit.commit())


## A straight wire segment between two points (thin box along the segment).
static func wire(from: Vector3, to: Vector3) -> ArrayMesh:
	var kit: LowPoly = LowPoly.new()
	var mid: Vector3 = (from + to) / 2.0
	var length: float = from.distance_to(to)
	var forward: Vector3 = (to - from).normalized()
	var side: Vector3 = forward.cross(Vector3.UP).normalized()
	var up: Vector3 = side.cross(forward)
	kit.set_transform(Transform3D(Basis(side, up, forward), mid))
	kit.box(Vector3.ZERO, Vector3(0.04, 0.04, length), Palette.WIRE)
	return kit.commit()


## Chalk piko (hopscotch) drawn on the asphalt, long axis along Z.
static func hopscotch() -> ArrayMesh:
	return cached("piko", func() -> ArrayMesh:
		var kit: LowPoly = LowPoly.new()
		var chalk: Color = Color(0.97, 0.97, 0.92)
		var squares: Array[Vector2] = [Vector2(0, 0), Vector2(0, 1), Vector2(-0.5, 2), Vector2(0.5, 2), Vector2(0, 3), Vector2(-0.5, 4), Vector2(0.5, 4), Vector2(0, 5)]
		for cell: Vector2 in squares:
			var c: Vector3 = Vector3(cell.x * 1.0, 0.012, -cell.y * 0.9)
			for edge: int in 4:
				var horizontal: bool = edge < 2
				var offset: Vector3 = Vector3(0.0, 0.0, 0.42 if edge == 0 else -0.42) if horizontal else Vector3(0.47 if edge == 2 else -0.47, 0.0, 0.0)
				var size: Vector3 = Vector3(0.94, 0.01, 0.06) if horizontal else Vector3(0.06, 0.01, 0.84)
				kit.box(c + offset, size, chalk)
		kit.box(Vector3(0.0, 0.012, -5.35), Vector3(0.3, 0.01, 0.3), Palette.SARI_YELLOW)
		return kit.commit())


## The pin a kid leaves where they used the pin skill: a big red round head on a
## silver needle stuck slanted into the ground, with a small red ring around it.
static func push_pin() -> ArrayMesh:
	return cached("push_pin", func() -> ArrayMesh:
		var kit: LowPoly = LowPoly.new()
		kit.cylinder(Vector3(0.0, 0.0, 0.0), 0.62, 0.62, 0.02, 16, Palette.SARI_RED.darkened(0.15), Palette.SARI_RED)
		kit.cylinder(Vector3(0.0, 0.0, 0.0), 0.46, 0.46, 0.03, 16, Palette.ASPHALT, Palette.ASPHALT)
		kit.set_transform(Transform3D(Basis(Vector3.BACK, 0.25), Vector3.ZERO))
		kit.cylinder(Vector3(0.0, 0.0, 0.0), 0.04, 0.05, 0.9, 6, Palette.JEEP_CHROME)
		kit.cylinder(Vector3(0.0, 0.86, 0.0), 0.16, 0.2, 0.12, 10, Palette.SARI_RED.darkened(0.2))
		kit.sphere(Vector3(0.0, 1.12, 0.0), 0.3, Palette.SARI_RED, 12, 8)
		kit.sphere(Vector3(-0.1, 1.24, -0.12), 0.08, Palette.WHITE, 6, 4)
		kit.reset_transform()
		return kit.commit())


static func manhole() -> ArrayMesh:
	return cached("manhole", func() -> ArrayMesh:
		var kit: LowPoly = LowPoly.new()
		kit.cylinder(Vector3(0.0, 0.0, 0.0), 0.55, 0.55, 0.02, 10, Palette.ASPHALT_DARK.darkened(0.3), Palette.ASPHALT_DARK.darkened(0.25))
		for i: int in 3:
			kit.box(Vector3(0.0, 0.025, -0.25 + float(i) * 0.25), Vector3(0.7, 0.01, 0.05), Palette.ASPHALT_DARK.darkened(0.45))
		return kit.commit())


## A bench + stools in front of the store (tambayan).
static func bench() -> ArrayMesh:
	return cached("bench", func() -> ArrayMesh:
		var kit: LowPoly = LowPoly.new()
		kit.box(Vector3(0.0, 0.45, 0.0), Vector3(0.45, 0.08, 2.0), Palette.WOOD)
		for z: float in [-0.85, 0.85]:
			kit.box(Vector3(0.0, 0.22, z), Vector3(0.38, 0.44, 0.08), Palette.WOOD.darkened(0.2))
		for z: float in [-1.6, 1.5]:
			kit.cylinder(Vector3(0.4, 0.0, z), 0.18, 0.15, 0.4, 6, Palette.JEEP_RED)
		return kit.commit())


## A blue plastic drum (water / trash).
static func drum() -> ArrayMesh:
	return cached("drum", func() -> ArrayMesh:
		var kit: LowPoly = LowPoly.new()
		kit.cylinder(Vector3.ZERO, 0.38, 0.38, 0.9, 8, Palette.JEEP_BLUE, Palette.JEEP_BLUE.lightened(0.15))
		kit.cylinder(Vector3(0.0, 0.35, 0.0), 0.4, 0.4, 0.08, 8, Palette.JEEP_BLUE.darkened(0.2))
		return kit.commit())


static func banana_plant() -> ArrayMesh:
	return cached("banana", func() -> ArrayMesh:
		var kit: LowPoly = LowPoly.new()
		kit.cylinder(Vector3.ZERO, 0.2, 0.15, 2.2, 6, Color(0.55, 0.62, 0.3))
		for i: int in 6:
			var angle: float = TAU * float(i) / 6.0
			var dir: Vector3 = Vector3(cos(angle), 0.0, sin(angle))
			var root: Vector3 = Vector3(0.0, 2.2, 0.0)
			var tip: Vector3 = root + dir * 1.5 + Vector3(0.0, 0.2 - float(i % 2) * 0.5, 0.0)
			var side: Vector3 = dir.cross(Vector3.UP) * 0.35
			kit.quad(root, root + side + dir * 0.5, tip, root - side + dir * 0.5, Palette.LEAF if i % 2 == 0 else Palette.LEAF_DARK, root + Vector3(0.0, -0.5, 0.0))
		return kit.commit())


static func mango_tree() -> ArrayMesh:
	return cached("mango", func() -> ArrayMesh:
		var kit: LowPoly = LowPoly.new()
		kit.cylinder(Vector3.ZERO, 0.3, 0.22, 2.4, 6, Palette.WOOD)
		kit.sphere(Vector3(0.0, 3.4, 0.0), 1.6, Palette.LEAF_DARK, 7, 4)
		kit.sphere(Vector3(0.8, 3.0, 0.5), 1.1, Palette.LEAF, 6, 3)
		kit.sphere(Vector3(-0.7, 3.2, -0.4), 1.0, Palette.LEAF, 6, 3)
		for i: int in 5:
			var angle: float = TAU * float(i) / 5.0
			kit.sphere(Vector3(cos(angle) * 1.3, 2.7, sin(angle) * 1.3), 0.13, Palette.SARI_YELLOW, 5, 3)
		return kit.commit())


## The concrete base pad around a post: painted rings, team colour applied separately.
static func base_pad(radius: float) -> ArrayMesh:
	return cached("pad%.1f" % radius, func() -> ArrayMesh:
		var kit: LowPoly = LowPoly.new()
		kit.cylinder(Vector3(0.0, -0.02, 0.0), radius + 0.35, radius + 0.25, 0.1, 16, Palette.CURB, Palette.CONCRETE)
		for i: int in 8:
			var angle: float = TAU * float(i) / 8.0
			kit.box(Vector3(cos(angle), 0.0, sin(angle)) * (radius + 0.05) + Vector3(0.0, 0.1, 0.0), Vector3(0.35, 0.06, 0.35), Palette.SARI_YELLOW)
		return kit.commit())


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


## A cardboard wall column (bahay-bahayan): DISASSEMBLED boxes, one flat sheet
## thick, standing like play-house walls. Two big flattened sheets lean on thin
## wooden sticks, with fold creases, a taped seam, folded-over top flaps, a
## torn corner and some printed marks. Single side only: nothing stacked.
static func cardboard_wall(size: Vector3) -> ArrayMesh:
	return cached("cardboard%.2f_%.2f_%.2f" % [size.x, size.y, size.z], func() -> ArrayMesh:
		var kit: LowPoly = LowPoly.new()
		var sheets: int = 2
		var sheet_w: float = size.x / sheets
		var thick: float = 0.07
		for i: int in sheets:
			var cx: float = -size.x / 2.0 + sheet_w * (float(i) + 0.5)
			var lean: float = 0.035 if i % 2 == 0 else -0.03
			var z_off: float = 0.06 if i % 2 == 0 else -0.05
			kit.set_transform(Transform3D(Basis(Vector3.BACK, lean), Vector3(cx, size.y / 2.0, z_off)))
			var face: Color = Palette.CARDBOARD if i % 2 == 0 else Palette.CARDBOARD.darkened(0.07)
			# the flat sheet
			kit.box(Vector3.ZERO, Vector3(sheet_w - 0.06, size.y, thick), face)
			# creases, flap line and printing on BOTH faces (the lane sees both sides)
			for zs: float in [-1.0, 1.0]:
				var zf: float = zs * (thick / 2.0 + 0.004)
				for fx: float in [-0.32, 0.31]:
					kit.box(Vector3(fx * sheet_w, 0.0, zf), Vector3(0.05, size.y - 0.08, 0.014), face.darkened(0.28))
				kit.box(Vector3(0.0, size.y * 0.12, zf), Vector3(sheet_w - 0.12, 0.05, 0.014), face.darkened(0.25))
				kit.box(Vector3(0.0, -size.y / 2.0 + 0.04, zf), Vector3(sheet_w - 0.08, 0.06, 0.014), face.darkened(0.18))
				if i == 0:
					kit.box(Vector3(0.0, size.y * 0.3, zf * 1.2), Vector3(sheet_w * 0.6, 0.14, 0.014), Palette.JEEP_RED)
					kit.box(Vector3(-0.22, -size.y * 0.12, zf * 1.2), Vector3(0.1, 0.5, 0.014), Palette.JEEP_BLUE)
					kit.tri(Vector3(0.0, -size.y * 0.12 - 0.5, zf * 1.2), Vector3(-0.22, -size.y * 0.12 - 0.2, zf * 1.2), Vector3(0.22, -size.y * 0.12 - 0.2, zf * 1.2), Palette.JEEP_BLUE, Vector3(0.0, -size.y * 0.12, 0.0))
				else:
					kit.box(Vector3(0.1, size.y * 0.1, zf * 1.2), Vector3(sheet_w * 0.45, 0.4, 0.014), Palette.WHITE.darkened(0.1))
					kit.box(Vector3(0.1, size.y * 0.1, zf * 1.5), Vector3(sheet_w * 0.35, 0.05, 0.014), Palette.BLACK)
			# top flaps folded outward, one bent down
			kit.set_transform(kit._transform * Transform3D(Basis(Vector3.RIGHT, -0.5 if i % 2 == 0 else 0.25), Vector3(0.0, size.y / 2.0 + 0.02, -0.05)))
			kit.box(Vector3.ZERO, Vector3(sheet_w * 0.42, 0.04, 0.34), face.lightened(0.05))
			kit.box(Vector3(sheet_w * 0.45, 0.0, 0.0), Vector3(sheet_w * 0.42, 0.04, 0.3), face.lightened(0.03))
			kit.reset_transform()
		# tape across the seam and along the bottom
		kit.box(Vector3(0.0, size.y * 0.55, -0.02), Vector3(0.2, size.y * 0.6, 0.12), Palette.TAPE)
		kit.box(Vector3(0.0, size.y * 0.06, 0.0), Vector3(size.x - 0.1, 0.1, 0.14), Palette.TAPE)
		# the sticks holding it up
		for x: float in [-size.x / 2.0 + 0.08, 0.0, size.x / 2.0 - 0.08]:
			kit.box(Vector3(x, size.y * 0.45, 0.2), Vector3(0.09, size.y * 0.9, 0.09), Palette.WOOD)
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


## The guava (bayabas): the neutral at the centre of the lane. Round, lime-green,
## with a pale rim, a little crown, a stem and a leaf. Heals half HP when eaten.
static func guava(radius: float) -> ArrayMesh:
	return cached("guava%.2f" % radius, func() -> ArrayMesh:
		var kit: LowPoly = LowPoly.new()
		kit.sphere(Vector3.ZERO, radius, Palette.GUAVA, 12, 8)
		kit.sphere(Vector3(-radius * 0.3, radius * 0.35, -radius * 0.55), radius * 0.38, Palette.GUAVA.lightened(0.25), 8, 5)
		# a pale, blushing underside
		kit.sphere(Vector3(0.0, -radius * 0.55, 0.0), radius * 0.62, Palette.GUAVA_BLUSH, 10, 4)
		kit.cylinder(Vector3(0.0, radius * 0.92, 0.0), 0.05, 0.035, radius * 0.4, 6, Palette.WOOD)
		kit.box(Vector3(radius * 0.38, radius * 1.18, 0.0), Vector3(radius * 0.7, 0.04, radius * 0.4), Palette.LEAF_DARK)
		kit.box(Vector3(radius * 0.6, radius * 1.24, 0.0), Vector3(radius * 0.4, 0.04, radius * 0.3), Palette.LEAF)
		kit.box(Vector3(0.0, -radius * 0.98, 0.0), Vector3(radius * 0.4, 0.04, radius * 0.4), Palette.WOOD.darkened(0.3))
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
