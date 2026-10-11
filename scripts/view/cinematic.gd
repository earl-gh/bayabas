class_name Cinematic
extends RefCounted
## The cinematic layer of the match view (docs/ART.md "Daylight and depth"): the
## film finish over the picture (vignette and grain, no blur:
## shaders/cinematic.gdshader). View only. (The floating dust motes were removed.)

const SHADER: Shader = preload("res://shaders/cinematic.gdshader")
## Under the HUD (which uses layer 1) and over the 3D view.
const FINISH_LAYER: int = 0


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
