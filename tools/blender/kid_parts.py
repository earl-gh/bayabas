"""Geometry helpers for the Kalyeah kids (run inside Blender's Python, see make_kids.py).

Every primitive is built in a scratch bmesh, merged into the kid's single mesh with
a corner colour (a flat Color or a function of the position), smooth normals, a
material slot (0 = body, 1 = team tint) and skin weights (a function of the position
returning {bone: weight}). Units are metres, Z up, the kid faces +Y.
"""
import math

import bpy  # noqa: F401  (bmesh needs bpy imported first)
import bmesh
from mathutils import Vector


class Kit:
    def __init__(self, bones):
        self.bm = bmesh.new()
        self.bones = list(bones)
        self.color_layer = self.bm.loops.layers.float_color.new("Col")
        self.deform = self.bm.verts.layers.deform.verify()

    # -- merging --------------------------------------------------------------------
    def merge(self, tmp, color, weights, mat=0):
        """Copy the scratch bmesh `tmp` in. color: (r,g,b) or f(co)->(r,g,b)."""
        bm = self.bm
        mapping = {}
        for v in tmp.verts:
            nv = bm.verts.new(v.co)
            for bone, w in weights(v.co).items():
                if w > 0.001:
                    nv[self.deform][self.bones.index(bone)] = w
            mapping[v] = nv
        for f in tmp.faces:
            try:
                nf = bm.faces.new([mapping[v] for v in f.verts])
            except ValueError:
                continue
            nf.smooth = True
            nf.material_index = mat
            centre = nf.calc_center_median()
            c = color(centre) if callable(color) else color
            for loop in nf.loops:
                loop[self.color_layer] = (c[0], c[1], c[2], 1.0)
        tmp.free()

    # -- primitives -----------------------------------------------------------------
    def ellipsoid(self, center, radii, color, weights, mat=0, u=16, v=10, keep=None, rot=None):
        tmp = bmesh.new()
        bmesh.ops.create_uvsphere(tmp, u_segments=u, v_segments=v, radius=1.0)
        for vert in tmp.verts:
            co = Vector((vert.co.x * radii[0], vert.co.y * radii[1], vert.co.z * radii[2]))
            if rot is not None:
                co = rot @ co
            vert.co = co + Vector(center)
        if keep is not None:
            doomed = [vert for vert in tmp.verts if not keep(vert.co)]
            bmesh.ops.delete(tmp, geom=doomed, context="VERTS")
        self.merge(tmp, color, weights, mat)

    def box(self, center, size, color, weights, mat=0, bevel=0.03):
        tmp = bmesh.new()
        bmesh.ops.create_cube(tmp, size=1.0)
        for vert in tmp.verts:
            vert.co = Vector((vert.co.x * size[0], vert.co.y * size[1], vert.co.z * size[2])) + Vector(center)
        if bevel > 0.0:
            bmesh.ops.bevel(tmp, geom=list(tmp.edges), offset=bevel, segments=3, profile=0.6, affect="EDGES")
        self.merge(tmp, color, weights, mat)

    def loft(self, points, radii, color, weights, mat=0, sides=12, caps=(True, True)):
        """A soft tube along `points`; radii are (rx, ry) per point (rx across X)."""
        tmp = bmesh.new()
        rings = []
        points, radii = densify(points, radii, 0.03)
        pts = [Vector(p) for p in points]
        for i, p in enumerate(pts):
            a = pts[max(i - 1, 0)]
            b = pts[min(i + 1, len(pts) - 1)]
            tangent = (b - a).normalized()
            side = tangent.cross(Vector((0, 1, 0)))
            if side.length < 0.1:
                side = tangent.cross(Vector((1, 0, 0)))
            side.normalize()
            front = side.cross(tangent).normalized()
            rx, ry = radii[i]
            rings.append([p + side * (math.cos(t) * rx) + front * (math.sin(t) * ry)
                          for t in (math.tau * k / sides for k in range(sides))])

        verts = [[tmp.verts.new(c) for c in ring] for ring in rings]
        for r in range(len(verts) - 1):
            for k in range(sides):
                tmp.faces.new([verts[r][k], verts[r][(k + 1) % sides], verts[r + 1][(k + 1) % sides], verts[r + 1][k]])
        for enabled, index, other in ((caps[0], 0, 1), (caps[1], len(pts) - 1, len(pts) - 2)):
            if not enabled:
                continue
            p = pts[index]
            out = (p - pts[other]).normalized()
            rx, ry = radii[index]
            chain = [verts[index]]
            for ang in (35.0, 70.0):
                k = math.cos(math.radians(ang))
                shift = out * (math.sin(math.radians(ang)) * min(rx, ry))
                chain.append([tmp.verts.new(p + shift + (c - p) * k) for c in rings[index]])
            tip = tmp.verts.new(p + out * min(rx, ry))
            for r in range(len(chain) - 1):
                for k in range(sides):
                    tmp.faces.new([chain[r][k], chain[r][(k + 1) % sides], chain[r + 1][(k + 1) % sides], chain[r + 1][k]])
            for k in range(sides):
                tmp.faces.new([chain[-1][k], chain[-1][(k + 1) % sides], tip])
        bmesh.ops.recalc_face_normals(tmp, faces=list(tmp.faces))
        self.merge(tmp, color, weights, mat)


def densify(points, radii, step):
    """Resample a loft path so painted colour borders stay crisp between rings."""
    out_p, out_r = [tuple(points[0])], [tuple(radii[0])]
    for i in range(len(points) - 1):
        a, b = Vector(points[i]), Vector(points[i + 1])
        n = max(1, int(math.ceil((b - a).length / step)))
        for s in range(1, n + 1):
            t = s / n
            e = t * t * (3.0 - 2.0 * t) * 0.0 + t
            out_p.append(tuple(a.lerp(b, e)))
            out_r.append((radii[i][0] + (radii[i + 1][0] - radii[i][0]) * e, radii[i][1] + (radii[i + 1][1] - radii[i][1]) * e))
    return out_p, out_r


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3.0 - 2.0 * t)


def rigid(bone):
    return lambda co: {bone: 1.0}


def split(z_split, upper, lower, width=0.05):
    """Weights that hand over from `upper` to `lower` around height z_split."""
    def f(co):
        t = smooth((z_split + width - co.z) / (2.0 * width))
        return {upper: 1.0 - t, lower: t}
    return f


def shade(color, factor):
    return (color[0] * factor, color[1] * factor, color[2] * factor)
