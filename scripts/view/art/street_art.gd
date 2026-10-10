class_name StreetArt
extends RefCounted
## The painted textures of the street (assets/textures/, made by
## tools/art/make_assets.py): asphalt and paver ground, kids' marker doodles on the
## cardboard walls, the sari-sari store sign and barangay posters. View only.

const TEXTURE_PATH: String = "res://assets/textures/%s.png"
const DOODLES: Array[String] = ["sun", "house", "star", "crown", "smiley", "heart"]
## Doodle size on a wall face, as a fraction of the wall's width and height.
const DOODLE_FILL: Vector2 = Vector2(0.62, 0.6)
const DOODLE_ASPECT: float = 4.0 / 3.0
## Damage overlay size on a wall face, as a fraction of its width and height.
const TEARS_FILL: Vector2 = Vector2(0.92, 0.88)

static var _textures: Dictionary[String, Texture2D] = {}


static func texture(name: String) -> Texture2D:
	if not _textures.has(name):
		_textures[name] = load(TEXTURE_PATH % name) as Texture2D
	return _textures[name]


## Matte, lit material showing `name`, repeated `repeat` times across the surface.
static func material(name: String, repeat: Vector2 = Vector2.ONE, transparent: bool = false) -> StandardMaterial3D:
	var result: StandardMaterial3D = StandardMaterial3D.new()
	result.albedo_texture = texture(name)
	result.uv1_scale = Vector3(repeat.x, repeat.y, 1.0)
	result.roughness = 1.0
	result.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	result.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	result.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if transparent:
		result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return result


## A flat textured patch of ground, `size` metres (x, z), one texture repeat per `tile` m.
static func ground(name: String, size: Vector2, tile: float, tint: Color = Color.WHITE) -> MeshInstance3D:
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = size
	var mat: StandardMaterial3D = material(name, size / tile)
	mat.albedo_color = tint
	plane.material = mat
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = plane
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


## Paint or chalk on the ground (transparent), `size` metres (x, z); text reads from +Z.
static func decal(name: String, size: Vector2) -> MeshInstance3D:
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = size
	plane.material = material(name, Vector2.ONE, true)
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = plane
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


## A sign or poster that always faces the camera, `height` metres tall, bottom at the origin.
static func billboard(name: String, height: float) -> Sprite3D:
	var sprite: Sprite3D = Sprite3D.new()
	sprite.texture = texture(name)
	sprite.pixel_size = height / sprite.texture.get_size().y
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.offset = Vector2(0.0, sprite.texture.get_size().y / 2.0)
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return sprite


## A kid's marker drawing on both faces of a cardboard wall `width` x `height` m.
## Returns the shared material so the caller can darken it as the wall breaks.
static func add_wall_doodles(parent: Node3D, width: float, height: float, variant: int) -> StandardMaterial3D:
	var mat: StandardMaterial3D = material("doodle_" + DOODLES[variant % DOODLES.size()], Vector2.ONE, true)
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	var quad: QuadMesh = QuadMesh.new()
	var doodle_width: float = minf(width * DOODLE_FILL.x, height * DOODLE_FILL.y * DOODLE_ASPECT)
	quad.size = Vector2(doodle_width, doodle_width / DOODLE_ASPECT)
	quad.material = mat
	# in front of the sheets (and the props sticks on the +Z side), facing out both ways
	for face: Vector2 in [Vector2(0.27, 0.0), Vector2(-0.18, PI)]:
		var instance: MeshInstance3D = MeshInstance3D.new()
		instance.name = "Doodle"
		instance.mesh = quad
		instance.position = Vector3(0.0, height * 0.52, face.x)
		instance.rotation.y = face.y
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(instance)
	return mat


## Rips, holes, scuffs and tape patches over both faces of a wall; the caller fades
## them in (material alpha) as the wall loses health.
static func add_wall_tears(parent: Node3D, width: float, height: float) -> StandardMaterial3D:
	var mat: StandardMaterial3D = material("cardboard_tears", Vector2.ONE, true)
	mat.albedo_color = Color(1.0, 1.0, 1.0, 0.0)
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(width * TEARS_FILL.x, height * TEARS_FILL.y)
	quad.material = mat
	for face: Vector2 in [Vector2(0.285, 0.0), Vector2(-0.195, PI)]:
		var instance: MeshInstance3D = MeshInstance3D.new()
		instance.name = "Tears"
		instance.mesh = quad
		instance.position = Vector3(0.0, height * 0.5, face.x)
		instance.rotation.y = face.y
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(instance)
	return mat
