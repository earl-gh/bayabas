"""Builds the six Kalyeah kids as skinned .glb files from data/characters/*.tres.

Run:  /tmp/bpyenv/bin/python tools/blender/make_kids.py [id ...]
(needs `pip install bpy`). Output: assets/models/kids/<id>.glb. See docs/ART.md.

One body, six outfits: the skeleton, proportions and height are identical for
everyone (the hitbox never changes); only colours, clothes and hair differ. Colours
are painted into vertex colours with baked ambient occlusion; the bandana and
armband are a second material slot that the game tints with the team colour.
"""
import math
import os
import re
import sys

import bpy  # noqa: F401  (must come before bmesh)
import bmesh  # noqa: F401
from mathutils import Euler, Vector
from mathutils.bvhtree import BVHTree

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kid_parts import Kit, rigid, shade, smooth, split  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "models", "kids")

HIP_Z = 0.55
SPINE_Z = 0.63
NECK_Z = 1.09
HEAD_C = 1.43
HEAD_R = 0.33
KNEE_Z = 0.27
SHOULDER_Z = 1.03
ELBOW_Z = 0.83
WRIST_Z = 0.63

BONES = ["Hips", "Spine", "Neck", "Thigh0", "Knee0", "Thigh1", "Knee1",
         "Shoulder0", "Elbow0", "Shoulder1", "Elbow1"]

# enums mirror scripts/sim/character_def.gd
HAIR = ["SHORT", "PONYTAIL", "PIGTAILS", "CAP_BACKWARD", "BUZZ", "SPIKY", "CURLY", "LONG_WAVY"]
TOP = ["SANDO", "TEE_KNOTTED", "BESTIDA", "JERSEY", "POLO_STRIPED", "PE_SHIRT"]
BOTTOM = ["SHORTS", "CARGO_SHORTS", "JOGGING_PANTS", "NONE"]
EXTRA = ["NONE", "BIMPO", "HAIR_CLIP", "HEADBAND_BELT_BAG", "ICE_CANDY", "PONY_BANDS"]


def parse_def(path):
    out = {}
    for line in open(path):
        m = re.match(r"^(\w+) = (.+)$", line.strip())
        if not m:
            continue
        key, raw = m.groups()
        if raw.startswith("ExtResource"):
            continue
        if raw.startswith("Color("):
            out[key] = tuple(float(x) for x in raw[6:-1].split(","))[:3]
        elif raw in ("true", "false"):
            out[key] = raw == "true"
        elif raw.startswith('"') or raw.startswith("&"):
            out[key] = raw.strip('&"')
        else:
            out[key] = float(raw) if "." in raw else int(raw)
    out["hair"] = HAIR[out["hair"]]
    out["top"] = TOP[out["top"]]
    out["bottom"] = BOTTOM[out["bottom"]]
    out["extra"] = EXTRA[out["extra"]]
    return out


def build_kit(d):
    kit = Kit(BONES)
    w = d["body_width"]
    skin, tint = d["skin"], d["tint"]
    white = (0.97, 0.97, 0.95)
    top_acc = d["top_accent"]
    bottom_c = d["bottom_color"]
    hair_c = d["hair_color"]
    extra_c = d["extra_color"]
    shoe_c = d["shoe_color"]
    sleeves = d["top"] not in ("SANDO", "JERSEY")
    pants_covering = d["bottom"] != "NONE"

    # ---- legs ----
    for i, side in enumerate((-1.0, 1.0)):
        x = side * 0.1 * w
        thigh, knee = "Thigh%d" % i, "Knee%d" % i
        weights = split(KNEE_Z, thigh, knee, 0.05)

        def leg_color(co, side=side):
            if d["bottom"] == "JOGGING_PANTS":
                return shade(bottom_c, 1.0 - 0.1 * (co.z < 0.2))
            if d["bottom"] == "SHORTS" and co.z > 0.40:
                return bottom_c
            if d["bottom"] == "CARGO_SHORTS" and co.z > 0.31:
                return bottom_c
            if d["top"] == "BESTIDA" and co.z > 0.5:
                return tint
            return skin
        pts = [(x, 0, 0.6), (x, 0, 0.46), (x, 0, KNEE_Z), (x, 0, 0.12)]
        rad = [(0.13 * w, 0.125), (0.125 * w, 0.12), (0.105, 0.105), (0.1, 0.1)]
        if d["bottom"] in ("SHORTS", "CARGO_SHORTS"):
            rad[0] = (0.15 * w, 0.14)
            rad[1] = (0.14 * w, 0.13)
        kit.loft(pts, rad, leg_color, weights, sides=12, caps=(False, False))
        # shoe
        if d["shoes"]:
            kit.ellipsoid((x, 0.06, 0.08), (0.14, 0.23, 0.095), shoe_c, rigid(knee), u=14, v=9)
            kit.ellipsoid((x, 0.06, 0.03), (0.145, 0.24, 0.045), white, rigid(knee), u=14, v=6, keep=lambda co: co.z < 0.05)
        else:
            kit.ellipsoid((x, 0.07, 0.025), (0.13, 0.25, 0.03), shoe_c, rigid(knee), u=14, v=6)
            kit.ellipsoid((x, 0.07, 0.075), (0.11, 0.21, 0.06), skin, rigid(knee), u=14, v=8)
            for toe in (-1.0, -0.5, 0.0, 0.5, 1.0):
                kit.ellipsoid((x + toe * 0.045, 0.27, 0.07), (0.032, 0.04, 0.032), skin, rigid(knee), u=6, v=5)
            for strap in (-1.0, 1.0):
                kit.loft([(x + strap * 0.1, 0.0, 0.05), (x + strap * 0.03, 0.2, 0.1)], [(0.022, 0.022), (0.022, 0.022)], shade(shoe_c, 0.85), rigid(knee), sides=6)
        if d["bottom"] == "CARGO_SHORTS":
            kit.box((x + side * 0.12, 0.0, 0.41), (0.05, 0.12, 0.13), shade(bottom_c, 0.8), rigid(thigh), bevel=0.015)

    # ---- pelvis, torso, neck ----
    pelvis_c = tint if d["bottom"] == "NONE" else bottom_c
    kit.ellipsoid((0, 0, 0.58), (0.2 * w, 0.14, 0.11), pelvis_c, split(0.62, "Spine", "Hips", 0.06), u=14, v=8)

    def torso_color(co):
        t = d["top"]
        if t == "SANDO" and co.z > 0.97 and co.y > 0.03 and abs(co.x) < 0.14:
            return skin
        if t == "POLO_STRIPED" and int((co.z - 0.55) / 0.085) % 2 == 1:
            return top_acc
        if t == "PE_SHIRT" and co.z > 1.0:
            return top_acc
        if t == "TEE_KNOTTED" and math.sin(co.x * 28.0 + co.y * 9.0) * math.sin(co.z * 24.0) > 0.35:
            return top_acc
        if t == "JERSEY" and co.y > 0.12 and 0.78 < co.z < 0.97 and abs(co.x) < 0.09:
            return top_acc
        return tint
    torso_pts = [(0, 0, 0.6), (0, 0, 0.75), (0, 0, 0.93), (0, 0, 1.06)]
    torso_rad = [(0.23 * w, 0.18 * w), (0.28 * w, 0.2 * w), (0.27 * w, 0.195 * w), (0.18 * w, 0.14 * w)]
    if d["top"] == "JERSEY":
        torso_rad = [(0.27 * w, 0.2 * w), (0.31 * w, 0.215 * w), (0.31 * w, 0.21 * w), (0.2 * w, 0.15 * w)]
    kit.loft(torso_pts, torso_rad, torso_color, split(0.66, "Spine", "Hips", 0.07) if False else rigid("Spine"), caps=(False, False), sides=14)
    if d["top"] == "BESTIDA":
        kit.loft([(0, 0, 0.7), (0, 0, 0.5), (0, 0, 0.36)], [(0.24, 0.18), (0.3, 0.24), (0.36, 0.3)],
                 lambda co: top_acc if co.z < 0.4 else tint, rigid("Hips"), sides=16, caps=(False, False))
        for k in range(8):
            ang = math.tau * k / 8.0
            kit.ellipsoid((math.cos(ang) * 0.3, math.sin(ang) * 0.26, 0.5 - (k % 2) * 0.07), (0.035, 0.035, 0.035),
                          top_acc, rigid("Hips"), u=6, v=4)
    if d["top"] == "TEE_KNOTTED":
        kit.ellipsoid((0.17, 0.1, 0.62), (0.07, 0.07, 0.07), shade(tint, 0.85), rigid("Hips"), u=8, v=6)
    kit.loft([(0, 0, NECK_Z - 0.04), (0, 0, NECK_Z + 0.06)], [(0.11, 0.11), (0.105, 0.105)], skin, rigid("Neck"), sides=10, caps=(False, False))

    # team bandana (white, tinted in game)
    kit.loft([(0, 0, NECK_Z - 0.05), (0, 0, NECK_Z + 0.03)], [(0.2 * w, 0.16 * w), (0.18 * w, 0.15 * w)],
             (1, 1, 1), rigid("Spine"), mat=1, sides=14, caps=(False, False))
    kit.ellipsoid((0, 0.1, NECK_Z - 0.1), (0.07, 0.025, 0.09), (1, 1, 1), rigid("Spine"), mat=1, u=8, v=6)

    if d["extra"] == "BIMPO":
        kit.box((0, -0.19, 0.85), (0.2, 0.05, 0.34), extra_c, rigid("Spine"), bevel=0.02)
    if d["extra"] == "HEADBAND_BELT_BAG":
        kit.box((0.12, 0.15, 0.68), (0.2, 0.1, 0.11), extra_c, rigid("Spine"), bevel=0.03)

    # ---- arms ----
    for i, side in enumerate((-1.0, 1.0)):
        x = side * (0.3 * w + 0.03)
        sh, el = "Shoulder%d" % i, "Elbow%d" % i
        weights = split(ELBOW_Z, sh, el, 0.05)

        def arm_color(co):
            if sleeves and co.z > 0.92:
                return tint
            if d["top"] == "JERSEY" and co.z > 0.97:
                return tint
            return skin
        kit.loft([(x, 0, 1.04), (x, 0, 0.93), (x, 0, ELBOW_Z), (x, 0, 0.68)],
                 [(0.125, 0.125), (0.12, 0.12), (0.105, 0.105), (0.095, 0.095)], arm_color, weights, sides=10, caps=(True, False))
        kit.ellipsoid((x, 0, 0.6), (0.115, 0.115, 0.115), skin, rigid(el), u=10, v=6)
        if i == 0:   # armband
            kit.loft([(x, 0, 0.97), (x, 0, 0.9)], [(0.112, 0.112), (0.112, 0.112)], (1, 1, 1), rigid(sh), mat=1, sides=10, caps=(False, False))
        if i == 1 and d["extra"] == "ICE_CANDY":
            kit.box((x, 0.08, 0.5), (0.07, 0.07, 0.2), extra_c, rigid(el), bevel=0.025)

    # ---- head ----
    c = (0, 0, HEAD_C)
    head_w = rigid("Neck")
    kit.ellipsoid(c, (HEAD_R * 1.06, HEAD_R, HEAD_R * 0.98), skin, head_w, u=20, v=14)
    for side in (-1.0, 1.0):
        kit.ellipsoid((side * HEAD_R * 1.04, 0.0, HEAD_C - 0.01), (0.04, 0.05, 0.06), shade(skin, 0.95), head_w, u=8, v=6)
        # big glossy eyes
        kit.ellipsoid((side * 0.125, HEAD_R * 0.9, HEAD_C + 0.02), (0.07, 0.045, 0.09), (0.06, 0.04, 0.05), head_w, u=12, v=8)
        kit.ellipsoid((side * 0.113, HEAD_R * 0.9 + 0.035, HEAD_C + 0.055), (0.026, 0.018, 0.03), (1, 1, 1), head_w, u=8, v=6)
        kit.ellipsoid((side * 0.2, HEAD_R * 0.8, HEAD_C - 0.08), (0.055, 0.025, 0.035), (1.0, 0.55, 0.52), head_w, u=8, v=6)
        kit.ellipsoid((side * 0.115, HEAD_R * 0.86, HEAD_C + 0.125), (0.075, 0.03, 0.022), shade(hair_c, 0.8), head_w, u=8, v=6, rot=Euler((0, side * -0.35, 0)).to_matrix())
    kit.ellipsoid((0, HEAD_R * 0.98, HEAD_C - 0.03), (0.022, 0.025, 0.02), shade(skin, 0.88), head_w, u=8, v=6)
    kit.ellipsoid((0, HEAD_R * 0.9, HEAD_C - 0.12), (0.085, 0.03, 0.055), (0.32, 0.08, 0.08), head_w, u=12, v=8)
    kit.ellipsoid((0, HEAD_R * 0.93, HEAD_C - 0.085), (0.065, 0.015, 0.016), (1, 1, 1), head_w, u=10, v=5)
    kit.ellipsoid((0, HEAD_R * 0.93, HEAD_C - 0.15), (0.045, 0.012, 0.02), (0.9, 0.3, 0.35), head_w, u=8, v=5)

    # hair
    def cap_keep(co):
        back = smooth((0.05 - co.y) / 0.35)
        side = smooth((abs(co.x) - 0.15) / 0.15)
        return co.z > HEAD_C + 0.17 - 0.3 * back - 0.12 * side

    hair_r = (HEAD_R * 1.1, HEAD_R * 1.08, HEAD_R * 1.07)
    h = d["hair"]
    if h == "BUZZ":
        kit.ellipsoid((0, -0.01, HEAD_C + 0.02), (HEAD_R * 1.05, HEAD_R * 1.02, HEAD_R * 1.02),
                      tuple(min(1.0, x + 0.15) for x in hair_c), head_w, u=20, v=14, keep=cap_keep)
    else:
        kit.ellipsoid((0, -0.02, HEAD_C + 0.03), hair_r, hair_c, head_w, u=20, v=14, keep=cap_keep)
    if h == "SPIKY":
        for k, (sx, sy, tilt) in enumerate(((0, 0.12, 0.5), (-0.14, 0.08, 0.2), (0.14, 0.08, -0.2), (-0.22, -0.04, -0.5),
                                            (0.22, -0.04, 0.5), (0, -0.12, 0.1), (-0.08, 0.0, 0.0), (0.08, 0.0, 0.0))):
            base = (sx, sy, HEAD_C + 0.22)
            tip = (sx + tilt * 0.22, sy + 0.1, HEAD_C + 0.38)
            kit.loft([base, tip], [(0.09, 0.09), (0.02, 0.02)], hair_c, head_w, sides=7)
    if h == "CURLY":
        for k in range(16):
            ang = math.tau * k / 16.0
            ring = 0.2 if k % 2 else 0.29
            kit.ellipsoid((math.cos(ang) * ring, math.sin(ang) * ring - 0.02, HEAD_C + 0.15 + (0.06 if k % 2 else 0.0)),
                          (0.115, 0.115, 0.115), hair_c, head_w, u=8, v=6)
        for k in range(5):
            kit.ellipsoid((math.cos(k * 1.3) * 0.1, math.sin(k * 1.3) * 0.1, HEAD_C + 0.26), (0.12, 0.12, 0.12), hair_c, head_w, u=8, v=6)
    if h == "LONG_WAVY":
        kit.loft([(0, -0.2, HEAD_C + 0.2), (0.0, -0.3, HEAD_C - 0.1), (0.04, -0.26, HEAD_C - 0.4), (-0.03, -0.24, HEAD_C - 0.62)],
                 [(0.3, 0.1), (0.31, 0.11), (0.3, 0.1), (0.25, 0.09)], hair_c, head_w, sides=14)
        for side in (-1.0, 1.0):
            kit.loft([(side * 0.3, -0.05, HEAD_C + 0.05), (side * 0.34, -0.08, HEAD_C - 0.25), (side * 0.3, -0.12, HEAD_C - 0.5)],
                     [(0.07, 0.1), (0.09, 0.1), (0.07, 0.08)], hair_c, head_w, sides=10)
    if h == "PONYTAIL":
        kit.loft([(0, -0.27, HEAD_C + 0.12), (0, -0.4, HEAD_C - 0.02), (0, -0.42, HEAD_C - 0.22)],
                 [(0.09, 0.09), (0.095, 0.095), (0.05, 0.05)], hair_c, head_w, sides=10)
    if h == "PIGTAILS":
        for side in (-1.0, 1.0):
            for k in range(5):
                kit.ellipsoid((side * (0.38 + 0.03 * (k % 2)), -0.04, HEAD_C + 0.12 - k * 0.1), (0.1, 0.1, 0.1), hair_c, head_w, u=8, v=6)
    if h == "CAP_BACKWARD":
        kit.ellipsoid((0, -0.01, HEAD_C + 0.07), (HEAD_R * 1.13, HEAD_R * 1.1, HEAD_R * 1.0), extra_c, head_w, u=20, v=14,
                      keep=lambda co: co.z > HEAD_C + 0.1)
        kit.box((0, -HEAD_R * 1.2, HEAD_C + 0.14), (0.3, 0.2, 0.04), extra_c, head_w, bevel=0.015)
    if d["extra"] == "HAIR_CLIP":
        kit.box((0.2, 0.12, HEAD_C + 0.2), (0.1, 0.04, 0.05), extra_c, head_w, bevel=0.012)
    if d["extra"] == "HEADBAND_BELT_BAG":
        kit.loft([(0, 0, HEAD_C + 0.12), (0, 0, HEAD_C + 0.19)], [(HEAD_R * 1.12, HEAD_R * 1.1), (HEAD_R * 1.12, HEAD_R * 1.1)],
                 extra_c, head_w, sides=18, caps=(False, False))
    if d["extra"] == "PONY_BANDS":
        for side in (-1.0, 1.0):
            kit.ellipsoid((side * 0.37, -0.04, HEAD_C + 0.16), (0.055, 0.055, 0.055), extra_c, head_w, u=8, v=6)
    return kit


def bake_ao(kit):
    """Darken tight spots (armpits, under the chin, between legs) in the vertex colours."""
    bm = kit.bm
    bm.normal_update()
    tree = BVHTree.FromBMesh(bm)
    dirs = []
    n = 24
    for k in range(n):
        z = 1.0 - (k + 0.5) / n
        r = math.sqrt(1 - z * z)
        a = k * 2.399963
        dirs.append(Vector((r * math.cos(a), r * math.sin(a), z)))
    ao = {}
    for v in bm.verts:
        normal = v.normal
        tangent = normal.cross(Vector((0, 0, 1)) if abs(normal.z) < 0.9 else Vector((1, 0, 0))).normalized()
        bitangent = normal.cross(tangent)
        hits = 0
        for dvec in dirs:
            world = tangent * dvec.x + bitangent * dvec.y + normal * dvec.z
            if tree.ray_cast(v.co + normal * 0.012, world, 0.3)[0] is not None:
                hits += 1
        occlusion = hits / n
        low = smooth(v.co.z / 0.25)
        ao[v.index] = (1.0 - 0.55 * occlusion) * (0.84 + 0.16 * low)
    layer = kit.color_layer
    for f in bm.faces:
        for loop in f.loops:
            c = loop[layer]
            k = ao[loop.vert.index]
            loop[layer] = (c[0] * k, c[1] * k, c[2] * k, 1.0)


def make_armature():
    arm = bpy.data.armatures.new("Rig")
    obj = bpy.data.objects.new("Rig", arm)
    bpy.context.scene.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.edit_bones

    def bone(name, head, tail, parent=None):
        b = eb.new(name)
        b.head, b.tail = head, tail
        if parent:
            b.parent = eb[parent]
        return b
    bone("Hips", (0, 0, HIP_Z), (0, 0, SPINE_Z))
    bone("Spine", (0, 0, SPINE_Z), (0, 0, NECK_Z), "Hips")
    bone("Neck", (0, 0, NECK_Z), (0, 0, NECK_Z + 0.7), "Spine")
    for i, side in enumerate((-1.0, 1.0)):
        x = side * 0.1
        bone("Thigh%d" % i, (x, 0, HIP_Z), (x, 0, KNEE_Z), "Hips")
        bone("Knee%d" % i, (x, 0, KNEE_Z), (x, 0, 0.0), "Thigh%d" % i)
    # the shoulder bones sit at the kid's own width in game; the rest pose is
    # shared, so the narrower default is fine (skinning follows the vertices)
    for i, side in enumerate((-1.0, 1.0)):
        x = side * 0.33
        bone("Shoulder%d" % i, (x, 0, SHOULDER_Z), (x, 0, ELBOW_Z), "Spine")
        bone("Elbow%d" % i, (x, 0, ELBOW_Z), (x, 0, WRIST_Z), "Shoulder%d" % i)
    bpy.ops.object.mode_set(mode="OBJECT")
    return obj


def build_kid(path):
    d = parse_def(path)
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o)
    for m in list(bpy.data.meshes):
        bpy.data.meshes.remove(m)
    kit = build_kit(d)
    bake_ao(kit)
    mesh = bpy.data.meshes.new("KidMesh")
    kit.bm.to_mesh(mesh)
    kit.bm.free()
    for name, colour in (("Body", (1, 1, 1, 1)), ("Team", (1, 1, 1, 1))):
        mat = bpy.data.materials.new(name)
        mat.diffuse_color = colour
        mesh.materials.append(mat)
    obj = bpy.data.objects.new("Kid", mesh)
    bpy.context.scene.collection.objects.link(obj)
    for name in BONES:
        obj.vertex_groups.new(name=name)
    rig = make_armature()
    obj.parent = rig
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = rig
    mesh.color_attributes.active_color = mesh.color_attributes["Col"]
    mesh.color_attributes.render_color_index = 0
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    os.makedirs(OUT, exist_ok=True)
    target = os.path.join(OUT, "%s.glb" % d["id"])
    bpy.ops.export_scene.gltf(filepath=target, export_format="GLB", use_selection=True, export_yup=True,
                              export_apply=False, export_animations=False, export_skins=True,
                              export_vertex_color="ACTIVE", export_normals=True, export_materials="EXPORT",
                              export_image_format="NONE")
    print("wrote", target, os.path.getsize(target), "bytes,", len(mesh.polygons), "faces")


def main():
    wanted = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    folder = os.path.join(ROOT, "data", "characters")
    for fname in sorted(os.listdir(folder)):
        if fname.endswith(".tres") and (not wanted or fname[:-5] in wanted):
            build_kid(os.path.join(folder, fname))


main()
