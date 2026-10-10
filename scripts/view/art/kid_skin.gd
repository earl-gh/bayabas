class_name KidSkin
extends Node3D
## The Blender-authored body of a kid (assets/models/kids/<id>.glb, built by
## tools/blender/make_kids.py): one skinned mesh with painted vertex colours and
## baked ambient occlusion, plus a second surface (bandana, armband) that is tinted
## with the team colour. KidModel keeps posing "joint" nodes with the procedural
## animation; `pose()` copies those rotations onto the skeleton's bones, so the
## limbs bend smoothly at the knees, elbows and waist.

const MODEL_PATH: String = "res://assets/models/kids/%s.glb"
const OUTLINE_WIDTH: float = 0.016
const JOINTS: Array[StringName] = [
	&"Hips", &"Spine", &"Neck", &"Thigh0", &"Knee0", &"Thigh1", &"Knee1",
	&"Shoulder0", &"Elbow0", &"Shoulder1", &"Elbow1",
]

static var _body_material: StandardMaterial3D

var skeleton: Skeleton3D
var meshes: Array[MeshInstance3D] = []
var _bones: Array[int] = []
var _rest_local: Array[Transform3D] = []
var _rest_global: Array[Basis] = []
var _parent_rest_global: Array[Basis] = []
var _hips_rest_height: float = 0.0


## Painted vertex colours, wrap lighting and a dark inverted-hull outline.
static func body_material() -> StandardMaterial3D:
	if _body_material == null:
		_body_material = LowPoly.material().duplicate() as StandardMaterial3D
		var outline: StandardMaterial3D = LowPoly.outline_material().duplicate() as StandardMaterial3D
		outline.grow = true
		outline.grow_amount = OUTLINE_WIDTH
		_body_material.next_pass = outline
	return _body_material


static func exists(id: StringName) -> bool:
	return ResourceLoader.exists(MODEL_PATH % String(id))


## `hips_height` is where the hips joint rests (KidModel.LEG_LENGTH).
func setup(id: StringName, team_color: Color, hips_height: float) -> void:
	_hips_rest_height = hips_height
	var scene: PackedScene = load(MODEL_PATH % String(id)) as PackedScene
	var root: Node = scene.instantiate()
	add_child(root)
	skeleton = root.find_child("Skeleton3D", true, false) as Skeleton3D
	var team_material: StandardMaterial3D = LowPoly.material().duplicate() as StandardMaterial3D
	team_material.albedo_color = team_color
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		meshes.append(mesh)
		for surface: int in mesh.mesh.get_surface_count():
			var is_team: bool = mesh.mesh.surface_get_material(surface).resource_name == "Team"
			mesh.set_surface_override_material(surface, team_material if is_team else body_material())
	for joint: StringName in JOINTS:
		var bone: int = skeleton.find_bone(String(joint))
		_bones.append(bone)
		var parent: int = skeleton.get_bone_parent(bone)
		_rest_local.append(skeleton.get_bone_rest(bone))
		_rest_global.append(skeleton.get_bone_global_rest(bone).basis)
		_parent_rest_global.append(Basis.IDENTITY if parent < 0 else skeleton.get_bone_global_rest(parent).basis)


## Poses the bones like the joint nodes (same order as JOINTS). A joint's rotation is
## in the world-aligned frame it would have had as a plain node, so the bone's local
## rotation is `parent_rest^-1 * joint * rest`.
func pose(joints: Array[Node3D]) -> void:
	for i: int in joints.size():
		var q: Basis = Basis.from_euler(joints[i].rotation)
		var local: Basis = _parent_rest_global[i].inverse() * q * _rest_global[i]
		var origin: Vector3 = _rest_local[i].origin
		if i == 0:
			origin += joints[i].position - Vector3(0.0, _hips_rest_height, 0.0)
		skeleton.set_bone_pose(_bones[i], Transform3D(local, origin))
