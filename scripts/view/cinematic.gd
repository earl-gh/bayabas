class_name Cinematic
extends RefCounted
## The cinematic layer of the match view (docs/ART.md "Daylight and depth"): the
## film finish over the picture (vignette and grain, no blur:
## shaders/cinematic.gdshader) and dust motes drifting in the sunlight in front of
## the camera. View only.

const SHADER: Shader = preload("res://shaders/cinematic.gdshader")
## Under the HUD (which uses layer 1) and over the 3D view.
const FINISH_LAYER: int = 0
const DUST_AMOUNT: int = 16
const DUST_BOX: Vector3 = Vector3(9.0, 6.0, 9.0)
## Metres in front of the camera where the dust floats (around the hero).
const DUST_DISTANCE: float = 30.0
const DUST_COLOR: Color = Color(1.0, 0.92, 0.74, 0.4)


## Adds the film finish over everything `parent` shows; returns its layer.
static func add_film_finish(parent: Node) -> CanvasLayer:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "FilmFinish"
	layer.layer = FINISH_LAYER
	var rect: ColorRect = ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = SHADER
	rect.material = material
	layer.add_child(rect)
	parent.add_child(layer)
	return layer


## Sunlit dust motes floating around the hero, carried along with `camera`.
static func add_dust(camera: Camera3D) -> CPUParticles3D:
	var dust: CPUParticles3D = CPUParticles3D.new()
	dust.name = "SunDust"
	dust.amount = DUST_AMOUNT
	dust.lifetime = 6.0
	dust.preprocess = 6.0
	dust.local_coords = true
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = DUST_BOX
	dust.direction = Vector3(0.3, 1.0, 0.0)
	dust.spread = 60.0
	dust.initial_velocity_min = 0.05
	dust.initial_velocity_max = 0.25
	dust.gravity = Vector3.ZERO
	dust.scale_amount_min = 0.4
	dust.scale_amount_max = 1.0
	var curve: Curve = Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(0.7, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	dust.scale_amount_curve = curve
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.12, 0.12)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.albedo_color = DUST_COLOR
	material.albedo_texture = _soft_dot()
	quad.material = material
	dust.mesh = quad
	dust.position = Vector3(0.0, 0.0, -DUST_DISTANCE)
	camera.add_child(dust)
	return dust


## A round, soft-edged white dot for each mote.
static func _soft_dot() -> GradientTexture2D:
	var gradient: Gradient = Gradient.new()
	gradient.colors = PackedColorArray([Color(1.0, 1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0, 0.0)])
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	var dot: GradientTexture2D = GradientTexture2D.new()
	dot.gradient = gradient
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	dot.width = 32
	dot.height = 32
	return dot
