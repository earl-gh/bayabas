"""Paints Kalyeah's 2D assets with Pillow: skill icons, HUD buttons and map textures.

Run: python3 tools/art/make_assets.py   (needs Pillow and numpy)
Output: assets/icons/*.png (skill and HUD art) and assets/textures/*.png (street).
Everything is drawn at 4x and downsampled, with a chunky dark outline, a soft
gradient and a highlight, in the Clash of Clans-like painted style of the HUD.
"""
import math
import os
import random

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ICONS = os.path.join(ROOT, "assets", "icons")
TEXTURES = os.path.join(ROOT, "assets", "textures")
FONT_BOLD = "/usr/share/fonts/opentype/inter/InterDisplay-Bold.otf"
SS = 4  # supersampling
INK = (44, 26, 22, 255)
ICON = 256


# ---- painting helpers ------------------------------------------------------------

class Painter:
    """An RGBA canvas at SS x resolution with shape helpers in final-pixel units."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.img = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))

    def mask(self):
        return Image.new("L", self.img.size, 0)

    @staticmethod
    def pts(points):
        return [(x * SS, y * SS) for x, y in points]

    def poly_mask(self, points):
        m = self.mask()
        ImageDraw.Draw(m).polygon(self.pts(points), fill=255)
        return m

    def ellipse_mask(self, box, angle=0.0):
        m = self.mask()
        x0, y0, x1, y1 = box
        if angle == 0.0:
            ImageDraw.Draw(m).ellipse([x0 * SS, y0 * SS, x1 * SS, y1 * SS], fill=255)
            return m
        cx, cy, rx, ry = (x0 + x1) / 2, (y0 + y1) / 2, (x1 - x0) / 2, (y1 - y0) / 2
        a = math.radians(angle)
        pts = []
        for k in range(72):
            t = math.tau * k / 72
            x, y = rx * math.cos(t), ry * math.sin(t)
            pts.append((cx + x * math.cos(a) - y * math.sin(a), cy + x * math.sin(a) + y * math.cos(a)))
        return self.poly_mask(pts)

    def line_mask(self, points, width):
        m = self.mask()
        d = ImageDraw.Draw(m)
        p = self.pts(points)
        d.line(p, fill=255, width=int(width * SS), joint="curve")
        r = width * SS / 2
        for x, y in (p[0], p[-1]):
            d.ellipse([x - r, y - r, x + r, y + r], fill=255)
        return m

    def round_rect_mask(self, box, radius):
        m = self.mask()
        ImageDraw.Draw(m).rounded_rectangle([v * SS for v in box], radius=radius * SS, fill=255)
        return m

    def gradient(self, mask, top, bottom, angle=90.0):
        """Linear gradient across the mask's bounding box (angle 90 = top to bottom)."""
        box = mask.getbbox()
        if box is None:
            return Image.new("RGBA", self.img.size, (0, 0, 0, 0))
        h, w = self.img.size[1], self.img.size[0]
        yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
        a = math.radians(angle)
        dx, dy = math.cos(a), math.sin(a)
        proj = xx * dx + yy * dy
        corners = [box[0] * dx + box[1] * dy, box[2] * dx + box[1] * dy, box[0] * dx + box[3] * dy, box[2] * dx + box[3] * dy]
        lo, hi = min(corners), max(corners)
        t = np.clip((proj - lo) / max(hi - lo, 1.0), 0.0, 1.0)[..., None]
        c0 = np.array(top + (255,) if len(top) == 3 else top, np.float32)
        c1 = np.array(bottom + (255,) if len(bottom) == 3 else bottom, np.float32)
        arr = (c0 * (1 - t) + c1 * t).astype(np.uint8)
        return Image.fromarray(arr, "RGBA")

    def fill(self, mask, top, bottom=None, angle=90.0, outline=4.0, ink=INK):
        """Outline (dilated mask in ink), then the gradient fill."""
        if outline > 0:
            size = int(outline * SS) * 2 + 1
            grown = mask.filter(ImageFilter.MaxFilter(min(size, 61))) if size <= 61 else _dilate(mask, int(outline * SS))
            self.img.paste(Image.new("RGBA", self.img.size, ink), (0, 0), grown)
        layer = self.gradient(mask, top, bottom or top, angle)
        self.img.paste(layer, (0, 0), mask)

    def paint(self, mask, color):
        self.img.paste(Image.new("RGBA", self.img.size, color), (0, 0), mask)

    def shine(self, clip, box, alpha=110, angle=0.0):
        """A soft white highlight clipped to `clip`."""
        m = self.ellipse_mask(box, angle).filter(ImageFilter.GaussianBlur(2 * SS))
        m = ImageChops.multiply(m, clip)
        m = m.point(lambda v: v * alpha // 255)
        self.paint(m, (255, 255, 255, 255))

    def shade(self, clip, box, alpha=70, angle=0.0, color=(0, 0, 0)):
        m = self.ellipse_mask(box, angle).filter(ImageFilter.GaussianBlur(4 * SS))
        m = ImageChops.multiply(m, clip)
        m = m.point(lambda v: v * alpha // 255)
        self.paint(m, color + (255,))

    def stroke(self, points, width, color):
        self.paint(self.line_mask(points, width), color)

    def result(self, shadow=True):
        img = self.img
        if shadow:
            a = img.split()[3]
            sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
            sh.paste(Image.new("RGBA", img.size, (20, 10, 10, 120)), (int(3 * SS), int(5 * SS)), a)
            sh = sh.filter(ImageFilter.GaussianBlur(3 * SS))
            img = Image.alpha_composite(sh, img)
        return img.resize((self.w, self.h), Image.LANCZOS)


def _dilate(mask, radius):
    out = mask
    step = 30
    while radius > 0:
        r = min(radius, step)
        out = out.filter(ImageFilter.MaxFilter(r * 2 + 1))
        radius -= r
    return out


def union(*masks):
    out = masks[0]
    for m in masks[1:]:
        out = ImageChops.lighter(out, m)
    return out


def rotated(points, cx, cy, deg):
    a = math.radians(deg)
    return [(cx + (x - cx) * math.cos(a) - (y - cy) * math.sin(a), cy + (x - cx) * math.sin(a) + (y - cy) * math.cos(a)) for x, y in points]


def ellipse_pts(cx, cy, rx, ry, n=48, deg=0.0):
    pts = [(cx + rx * math.cos(math.tau * k / n), cy + ry * math.sin(math.tau * k / n)) for k in range(n)]
    return rotated(pts, cx, cy, deg) if deg else pts


def save(img, folder, name):
    os.makedirs(folder, exist_ok=True)
    img.save(os.path.join(folder, name + ".png"), optimize=True)
    print("wrote", name)


# ---- icons ---------------------------------------------------------------------------

def icon_guava():
    p = Painter(ICON, ICON)
    body = union(p.ellipse_mask((52, 70, 204, 222)), p.ellipse_mask((70, 50, 186, 170)))
    p.fill(body, (176, 228, 96), (60, 140, 40), angle=70, outline=6)
    p.shade(body, (120, 150, 230, 250), alpha=90)
    p.shade(body, (60, 150, 140, 240), alpha=40, color=(230, 200, 60))
    rnd = random.Random(3)
    for _ in range(26):
        x, y = rnd.uniform(70, 190), rnd.uniform(80, 210)
        m = ImageChops.multiply(p.ellipse_mask((x - 2.4, y - 1.8, x + 2.4, y + 1.8)), body)
        p.paint(m, (70, 120, 40, 140))
    p.shine(body, (78, 76, 128, 128), alpha=150, angle=-30)
    p.shine(body, (92, 140, 108, 166), alpha=90)
    crown = p.poly_mask([(118, 58), (128, 40), (138, 58), (150, 50), (142, 66), (114, 66), (106, 50)])
    p.fill(crown, (120, 80, 40), (70, 45, 25), outline=3)
    leaf = p.ellipse_mask((132, 18, 214, 58), angle=-28)
    p.fill(leaf, (120, 210, 80), (40, 120, 40), angle=120, outline=5)
    p.stroke([(140, 52), (170, 40), (204, 22)], 2.6, (30, 90, 30, 220))
    p.stroke([(128, 64), (138, 52)], 6, (90, 60, 30, 255))
    return p.result()


def _slipper(p, cx, cy, scale, deg, sole=(255, 120, 170), strap=(60, 110, 230)):
    s = scale
    outline = ellipse_pts(cx, cy - 38 * s, 34 * s, 42 * s, deg=deg)[:]
    toe = p.poly_mask(ellipse_pts(cx, cy - 30 * s, 34 * s, 46 * s, deg=deg))
    heel = p.poly_mask(ellipse_pts(*rotated([(cx, cy + 34 * s)], cx, cy, deg)[0], 28 * s, 36 * s, deg=deg))
    neck = p.poly_mask(rotated([(cx - 24 * s, cy - 20 * s), (cx + 26 * s, cy - 20 * s), (cx + 24 * s, cy + 34 * s), (cx - 22 * s, cy + 34 * s)], cx, cy, deg))
    shape = union(toe, heel, neck)
    edge = shape.transform(shape.size, Image.AFFINE, (1, 0, 0, 0, 1, -6 * SS * s))
    p.fill(union(shape, edge), tuple(int(c * 0.62) for c in sole), outline=5 * s)
    p.fill(shape, tuple(min(255, int(c * 1.08)) for c in sole), sole, outline=0)
    p.shine(shape, (cx - 26 * s, cy - 70 * s, cx + 6 * s, cy - 20 * s), alpha=120, angle=deg)
    post = rotated([(cx, cy - 46 * s)], cx, cy, deg)[0]
    left = rotated([(cx - 30 * s, cy + 6 * s)], cx, cy, deg)[0]
    right = rotated([(cx + 30 * s, cy + 6 * s)], cx, cy, deg)[0]
    for end in (left, right):
        p.paint(p.line_mask([post, end], 15 * s), INK)
    for end in (left, right):
        p.paint(p.line_mask([post, end], 10 * s), strap + (255,))
        p.paint(p.line_mask([(post[0] - 2 * s, post[1] - 2 * s), ((post[0] + end[0]) / 2, (post[1] + end[1]) / 2 - 3 * s)], 3 * s), (255, 255, 255, 120))
    p.paint(p.ellipse_mask((post[0] - 8 * s, post[1] - 8 * s, post[0] + 8 * s, post[1] + 8 * s)), strap + (255,))
    return outline


def icon_tsinelas(heavy):
    p = Painter(ICON, ICON)
    if heavy:
        for k, y in enumerate((70, 112, 154)):
            p.stroke([(18, y + 10), (66 - k * 6, y)], 7, (255, 255, 255, 170))
        _slipper(p, 140, 132, 1.45, 28)
    else:
        _slipper(p, 90, 132, 0.95, -18)
        _slipper(p, 170, 128, 0.95, 18)
    return p.result()


def icon_lata():
    p = Painter(ICON, ICON)
    cx, top, bottom, rx = 128, 62, 206, 62
    body = union(p.round_rect_mask((cx - rx, top, cx + rx, bottom), 6), p.ellipse_mask((cx - rx, bottom - 18, cx + rx, bottom + 18)))
    p.fill(body, (235, 238, 245), (150, 156, 170), angle=0, outline=6)
    p.shade(body, (cx + 20, top, cx + rx + 30, bottom + 20), alpha=90)
    label = ImageChops.multiply(body, p.round_rect_mask((cx - rx - 2, top + 30, cx + rx + 2, bottom - 18), 1))
    p.paint(label, (250, 205, 40, 255))
    band = ImageChops.multiply(body, p.round_rect_mask((cx - rx - 2, top + 70, cx + rx + 2, bottom - 30), 1))
    p.paint(band, (215, 40, 40, 255))
    sun = ImageChops.multiply(body, p.ellipse_mask((cx - 24, top + 38, cx + 24, top + 86)))
    p.paint(sun, (255, 150, 40, 255))
    for k in range(5):
        x = cx - 34 + k * 17
        cube = ImageChops.multiply(body, p.round_rect_mask((x, top + 96, x + 12, top + 108), 2))
        p.paint(cube, (130, 20, 30, 255))
    rim = p.ellipse_mask((cx - rx, top - 18, cx + rx, top + 18))
    p.fill(rim, (250, 250, 255), (160, 165, 180), outline=6)
    inner = p.ellipse_mask((cx - rx + 10, top - 11, cx + rx - 10, top + 11))
    p.fill(inner, (190, 195, 205), (230, 232, 240), outline=0)
    p.shine(body, (cx - rx + 8, top + 10, cx - rx + 30, bottom - 10), alpha=150)
    return p.result()


def _rock(p, cx, cy, r, seed, color=(176, 172, 165), dark=(96, 92, 88)):
    rnd = random.Random(seed)
    pts = []
    for k in range(11):
        a = math.tau * k / 11
        rr = r * rnd.uniform(0.78, 1.05)
        pts.append((cx + rr * math.cos(a) * 1.12, cy + rr * math.sin(a) * 0.88))
    m = p.poly_mask(pts)
    p.fill(m, color, dark, angle=60, outline=6)
    p.shade(m, (cx - r * 0.2, cy, cx + r * 1.4, cy + r * 1.3), alpha=80)
    p.shine(m, (cx - r * 0.8, cy - r * 0.8, cx - r * 0.1, cy - r * 0.25), alpha=140)
    for _ in range(2):
        x = cx + rnd.uniform(-r * 0.4, r * 0.3)
        y = cy + rnd.uniform(-r * 0.2, r * 0.3)
        p.paint(ImageChops.multiply(p.line_mask([(x, y), (x + r * 0.25, y + r * 0.15), (x + r * 0.3, y + r * 0.4)], 3), m), (70, 66, 62, 200))
    return m


def _burst(p, cx, cy, r, n=10, color=(255, 214, 70)):
    pts = []
    for k in range(n * 2):
        a = math.tau * k / (n * 2)
        rr = r if k % 2 == 0 else r * 0.55
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    m = p.poly_mask(pts)
    p.fill(m, (255, 245, 170), color, outline=4)


def icon_bato(heavy):
    p = Painter(ICON, ICON)
    if heavy:
        _burst(p, 150, 100, 96, 11)
        _rock(p, 124, 140, 74, 7)
    else:
        _rock(p, 98, 150, 44, 3)
        _rock(p, 162, 112, 34, 4)
        for k in range(3):
            p.stroke([(40 + k * 14, 84 - k * 22), (70 + k * 10, 104 - k * 18)], 6, (255, 255, 255, 170))
    return p.result()


def icon_gunting(heavy):
    p = Painter(ICON, ICON)
    blade = (236, 240, 248) if not heavy else (255, 226, 120)
    blade_dark = (140, 150, 168) if not heavy else (205, 140, 40)
    handle = (225, 50, 60) if not heavy else (60, 110, 230)
    for side in (-1, 1):
        a = rotated([(128, 128), (128 + 14, 128), (128 + 6, 30), (128 - 4, 34)], 128, 128, side * 24)
        m = p.poly_mask(a)
        p.fill(m, blade, blade_dark, angle=0, outline=5)
        p.shine(m, (110, 40, 140, 120), alpha=90, angle=side * 24)
    for side in (-1, 1):
        cx, cy = rotated([(128, 188)], 128, 128, -side * 34)[0]
        ring = p.ellipse_mask((cx - 34, cy - 26, cx + 34, cy + 26), angle=side * 30)
        hole = p.ellipse_mask((cx - 18, cy - 11, cx + 18, cy + 11), angle=side * 30)
        p.fill(ring, tuple(min(255, c + 40) for c in handle), tuple(int(c * 0.7) for c in handle), outline=5)
        p.img.paste(Image.new("RGBA", p.img.size, (0, 0, 0, 0)), (0, 0), hole.filter(ImageFilter.MinFilter(9)))
        p.paint(ImageChops.subtract(hole.filter(ImageFilter.MaxFilter(17)), hole.filter(ImageFilter.MinFilter(9))), INK)
        stem = p.line_mask([(128, 140), (cx, cy - 10)], 18)
        p.fill(stem, handle, tuple(int(c * 0.7) for c in handle), outline=4)
    screw = p.ellipse_mask((116, 116, 140, 140))
    p.fill(screw, (255, 230, 120), (180, 130, 40), outline=4)
    if heavy:
        for x, y, s in ((60, 60, 14), (198, 70, 10), (200, 180, 8)):
            p.paint(p.poly_mask([(x, y - s), (x + s * 0.3, y - s * 0.3), (x + s, y), (x + s * 0.3, y + s * 0.3), (x, y + s), (x - s * 0.3, y + s * 0.3), (x - s, y), (x - s * 0.3, y - s * 0.3)]), (255, 250, 200, 255))
    return p.result()


def icon_papel_trap():
    p = Painter(ICON, ICON)
    ring = p.ellipse_mask((30, 150, 226, 226))
    hole = p.ellipse_mask((48, 162, 208, 214))
    p.paint(ImageChops.subtract(ring, hole), (90, 170, 255, 200))
    rnd = random.Random(5)
    pts = []
    for k in range(18):
        a = math.tau * k / 18
        rr = 70 * rnd.uniform(0.8, 1.06)
        pts.append((128 + rr * math.cos(a), 120 + rr * math.sin(a) * 0.92))
    ball = p.poly_mask(pts)
    p.fill(ball, (255, 255, 252), (200, 205, 215), angle=60, outline=6)
    for _ in range(9):
        x, y = rnd.uniform(80, 170), rnd.uniform(70, 165)
        p.paint(ImageChops.multiply(p.line_mask([(x, y), (x + rnd.uniform(-30, 30), y + rnd.uniform(-20, 25))], 2.5), ball), (150, 155, 170, 220))
    for y in (96, 120, 144):
        p.paint(ImageChops.multiply(p.line_mask([(70, y + rnd.uniform(-6, 6)), (190, y + rnd.uniform(-6, 6))], 2), ball), (110, 160, 230, 160))
    p.shine(ball, (82, 64, 130, 110), alpha=130)
    return p.result()


def icon_papel_shield():
    p = Painter(ICON, ICON)
    shield = [(128, 28), (210, 56), (204, 140), (128, 228), (52, 140), (46, 56)]
    m = p.poly_mask(shield)
    p.fill(m, (255, 255, 252), (215, 220, 230), angle=60, outline=7)
    for k in range(7):
        y = 70 + k * 20
        p.paint(ImageChops.multiply(p.line_mask([(40, y), (216, y)], 2.4), m), (120, 170, 235, 255))
    p.paint(ImageChops.multiply(p.line_mask([(84, 30), (84, 230)], 2.6), m), (235, 80, 90, 255))
    fold = p.poly_mask([(170, 44), (210, 56), (206, 92)])
    p.fill(fold, (230, 232, 240), (180, 185, 200), outline=4)
    p.shine(m, (60, 40, 120, 120), alpha=120, angle=-20)
    return p.result()


def icon_jacks():
    p = Painter(ICON, ICON)
    ball = p.ellipse_mask((158, 150, 222, 214))
    p.fill(ball, (255, 90, 90), (190, 20, 40), outline=5)
    p.shine(ball, (168, 158, 196, 184), alpha=170)
    cx, cy = 112, 120
    for deg in (0, 60, 120):
        a = math.radians(deg)
        dx, dy = 72 * math.cos(a), 72 * math.sin(a) * 0.8
        arm = p.line_mask([(cx - dx, cy - dy), (cx + dx, cy + dy)], 14)
        p.fill(arm, (250, 222, 120), (190, 130, 40), angle=deg + 90, outline=5)
    for deg in (0, 60, 120, 180, 240, 300):
        a = math.radians(deg)
        x, y = cx + 72 * math.cos(a), cy + 72 * math.sin(a) * 0.8
        knob = p.ellipse_mask((x - 13, y - 13, x + 13, y + 13))
        p.fill(knob, (255, 236, 150), (200, 140, 40), outline=4)
        p.shine(knob, (x - 9, y - 10, x + 1, y - 1), alpha=200)
    hub = p.ellipse_mask((cx - 15, cy - 15, cx + 15, cy + 15))
    p.fill(hub, (255, 240, 170), (200, 150, 50), outline=4)
    return p.result()


def icon_bola():
    p = Painter(ICON, ICON)
    for k, r in enumerate((96, 80)):
        p.stroke([(36 + k * 10, 60 + k * 24), (60 + k * 10, 46 + k * 24)], 6, (255, 255, 255, 160))
    ball = p.ellipse_mask((52, 52, 212, 212))
    p.fill(ball, (255, 96, 86), (176, 22, 40), angle=60, outline=7)
    stripe = ImageChops.multiply(ball, p.ellipse_mask((40, 112, 224, 152), angle=-24))
    p.paint(stripe, (255, 236, 120, 255))
    p.shade(ball, (130, 130, 240, 240), alpha=80)
    p.shine(ball, (80, 72, 140, 120), alpha=170, angle=-30)
    return p.result()


def icon_trumpo():
    p = Painter(ICON, ICON)
    for k in range(3):
        p.stroke([(40 + k * 8, 200 - k * 4), (90, 214 - k * 2)], 4, (255, 255, 255, 140))
    body = p.poly_mask([(56, 92), (200, 92), (196, 124), (140, 196), (128, 214), (116, 196), (60, 124)])
    cap = p.ellipse_mask((52, 64, 204, 120))
    shape = union(body, cap)
    p.fill(shape, (232, 168, 96), (150, 86, 40), angle=0, outline=6)
    for y0, col in ((96, (220, 40, 50)), (118, (40, 110, 220))):
        band = ImageChops.multiply(shape, p.ellipse_mask((40, y0 - 10, 216, y0 + 12)))
        p.paint(band, col + (255,))
    p.shade(shape, (140, 70, 240, 220), alpha=80)
    p.shine(shape, (70, 70, 120, 110), alpha=130)
    tip = p.poly_mask([(120, 204), (136, 204), (128, 232)])
    p.fill(tip, (220, 225, 235), (120, 125, 140), outline=4)
    knob = p.round_rect_mask((116, 34, 140, 72), 8)
    p.fill(knob, (210, 150, 90), (130, 80, 40), outline=5)
    p.stroke([(140, 50), (180, 40), (206, 58), (196, 84), (220, 98)], 4, INK)
    p.stroke([(140, 50), (180, 40), (206, 58), (196, 84), (220, 98)], 2, (250, 245, 220, 255))
    return p.result()


def icon_dash():
    p = Painter(ICON, ICON)
    for k, y in enumerate((86, 128, 170)):
        p.stroke([(26 + (k % 2) * 16, y), (100, y)], 9, (255, 255, 255, 200))
    arrow = p.poly_mask([(84, 104), (146, 104), (146, 58), (232, 128), (146, 198), (146, 152), (84, 152)])
    p.fill(arrow, (130, 220, 255), (30, 120, 230), angle=90, outline=7)
    p.shine(arrow, (96, 96, 200, 132), alpha=120)
    return p.result()


def icon_bookmark():
    p = Painter(ICON, ICON)
    pole = p.round_rect_mask((70, 34, 86, 226), 6)
    p.fill(pole, (240, 220, 180), (150, 110, 70), angle=0, outline=5)
    flag = p.poly_mask([(86, 40), (150, 30), (210, 54), (170, 80), (214, 118), (150, 108), (86, 122)])
    p.fill(flag, (255, 90, 80), (190, 20, 40), angle=60, outline=6)
    p.shine(flag, (96, 40, 170, 84), alpha=110)
    knob = p.ellipse_mask((66, 22, 90, 46))
    p.fill(knob, (255, 230, 120), (200, 150, 40), outline=4)
    base = p.ellipse_mask((44, 214, 112, 234))
    p.fill(base, (120, 110, 100), (70, 64, 60), outline=4)
    return p.result()


def icon_gear():
    """Settings: a white cog on a gold-rimmed navy button."""
    p = Painter(ICON, ICON)
    rim = p.ellipse_mask((12, 12, 244, 244))
    p.fill(rim, (255, 226, 120), (200, 130, 30), outline=6)
    face = p.ellipse_mask((30, 30, 226, 226))
    p.fill(face, (40, 70, 140), (20, 30, 70), outline=0)
    teeth = []
    for k in range(16):
        a = math.tau * k / 16
        r = 82 if k % 2 == 0 else 62
        for da in (-0.13, 0.13):
            teeth.append((128 + r * math.cos(a + da), 128 + r * math.sin(a + da)))
    cog = p.poly_mask(teeth)
    p.fill(cog, (255, 255, 255), (190, 200, 220), outline=5)
    hole = p.ellipse_mask((104, 104, 152, 152))
    p.fill(hole, (30, 50, 100), (20, 30, 70), outline=4)
    p.shine(face, (50, 36, 160, 110), alpha=60)
    return p.result()


def button_face():
    """The round skill button: gold rim, deep navy face (art goes on top in game)."""
    p = Painter(ICON, ICON)
    rim = p.ellipse_mask((6, 6, 250, 250))
    p.fill(rim, (255, 232, 130), (190, 120, 30), angle=70, outline=5)
    inner_rim = p.ellipse_mask((20, 20, 236, 236))
    p.fill(inner_rim, (120, 80, 30), (230, 170, 60), angle=70, outline=0)
    face = p.ellipse_mask((28, 28, 228, 228))
    p.fill(face, (52, 78, 150), (18, 26, 64), outline=0)
    p.shine(face, (50, 34, 206, 120), alpha=70)
    p.shine(rim, (40, 10, 216, 60), alpha=120)
    return p.result(shadow=False)


# ---- textures ------------------------------------------------------------------------

def _noise(size, scale, seed):
    rng = np.random.default_rng(seed)
    small = rng.random((max(2, size // scale), max(2, size // scale))).astype(np.float32)
    img = Image.fromarray((small * 255).astype(np.uint8), "L").resize((size, size), Image.BICUBIC)
    return np.asarray(img).astype(np.float32) / 255.0


def _tile_paste(base, layer, x, y):
    w, h = base.size
    for dx in (-w, 0, w):
        for dy in (-h, 0, h):
            base.alpha_composite(layer, (int(x + dx), int(y + dy)))


def tex_asphalt():
    n = 512
    rng = np.random.default_rng(1)
    grain = rng.random((n, n)).astype(np.float32)
    mottled = _noise(n, 32, 2) * 0.6 + _noise(n, 8, 3) * 0.4
    v = 92 + mottled * 18 + grain * 16
    rgb = np.stack([v * 1.06, v * 1.0, v * 0.93], -1)
    img = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    rnd = random.Random(4)
    for _ in range(5):  # tar patches
        layer = Image.new("RGBA", (220, 160), (0, 0, 0, 0))
        ImageDraw.Draw(layer).rounded_rectangle([10, 10, rnd.randint(90, 210), rnd.randint(60, 150)], 18, fill=(40, 40, 46, 30))
        _tile_paste(img, layer.filter(ImageFilter.GaussianBlur(3)), rnd.randint(0, n), rnd.randint(0, n))
    for _ in range(2):  # oil stains
        layer = Image.new("RGBA", (140, 140), (0, 0, 0, 0))
        ImageDraw.Draw(layer).ellipse([20, 30, 120, 100], fill=(40, 34, 30, 50))
        _tile_paste(img, layer.filter(ImageFilter.GaussianBlur(12)), rnd.randint(0, n), rnd.randint(0, n))
    for _ in range(3):  # cracks
        layer = Image.new("RGBA", (n, n), (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        x, y = rnd.uniform(0, n), rnd.uniform(0, n)
        a = rnd.uniform(0, math.tau)
        pts = [(x, y)]
        for _ in range(rnd.randint(6, 12)):
            a += rnd.uniform(-0.8, 0.8)
            x += math.cos(a) * rnd.uniform(10, 26)
            y += math.sin(a) * rnd.uniform(10, 26)
            pts.append((x, y))
        d.line(pts, fill=(52, 46, 42, 130), width=2)
        d.line([(px + 1, py + 1) for px, py in pts], fill=(120, 120, 128, 70), width=1)
        _tile_paste(img, layer, 0, 0) if False else img.alpha_composite(layer)
    for _ in range(140):  # light pebbles
        x, y = rnd.uniform(0, n), rnd.uniform(0, n)
        r = rnd.uniform(0.8, 2.0)
        ImageDraw.Draw(img).ellipse([x - r, y - r, x + r, y + r], fill=(150, 148, 150, 140))
    return img.convert("RGB")


def tex_pavers():
    """Concrete pavers (sidewalks), stretcher bond, worn and mossy."""
    n = 512
    img = Image.new("RGB", (n, n), (70, 64, 58))
    d = ImageDraw.Draw(img)
    rnd = random.Random(9)
    bw, bh = 64, 32
    for row in range(n // bh):
        off = (bw // 2) * (row % 2)
        for col in range(-1, n // bw + 1):
            x0, y0 = col * bw + off + 2, row * bh + 2
            tone = rnd.randint(-16, 14)
            warm = rnd.random() < 0.25
            base = (196 + tone, 182 + tone, 160 + tone) if warm else (178 + tone, 174 + tone, 168 + tone)
            d.rounded_rectangle([x0, y0, x0 + bw - 4, y0 + bh - 4], 5, fill=base)
            d.line([(x0 + 3, y0 + 2), (x0 + bw - 8, y0 + 2)], fill=tuple(min(255, c + 22) for c in base), width=2)
            d.line([(x0 + 3, y0 + bh - 6), (x0 + bw - 8, y0 + bh - 6)], fill=tuple(c - 30 for c in base), width=2)
    arr = np.asarray(img).astype(np.float32)
    arr *= (0.9 + _noise(n, 16, 11) * 0.2)[..., None]
    img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")
    d = ImageDraw.Draw(img)
    for _ in range(60):  # moss in the joints
        row = rnd.randint(0, n // bh - 1)
        x, y = rnd.uniform(0, n), row * bh + 1
        d.ellipse([x - 4, y - 2, x + 4, y + 2], fill=(90, 120, 50))
    return img


DOODLE_INK = [(30, 60, 160), (200, 40, 50), (30, 30, 36), (250, 250, 245)]


def _marker(d, pts, color, width=11, closed=False):
    if closed:
        pts = pts + [pts[0]]
    d.line(pts, fill=color + (235,), width=width, joint="curve")
    r = width / 2
    for x, y in (pts[0], pts[-1]):
        d.ellipse([x - r, y - r, x + r, y + r], fill=color + (235,))


def tex_doodle(kind):
    """A kid's marker drawing for a cardboard wall face (transparent PNG, 512x384)."""
    img = Image.new("RGBA", (512 * 2, 384 * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    S2 = 2
    rnd = random.Random(kind)

    def J(x, y):
        return (x * S2 + rnd.uniform(-3, 3), y * S2 + rnd.uniform(-3, 3))

    def circle(cx, cy, r, n=28):
        return [J(cx + r * math.cos(math.tau * k / n), cy + r * math.sin(math.tau * k / n)) for k in range(n)]
    blue, red, black, white = DOODLE_INK
    w = 13 * S2 // 2 * 2
    if kind == "sun":
        _marker(d, circle(256, 192, 80), (240, 150, 30), w, True)
        for k in range(12):
            a = math.tau * k / 12
            _marker(d, [J(256 + 100 * math.cos(a), 192 + 100 * math.sin(a)), J(256 + 140 * math.cos(a), 192 + 140 * math.sin(a))], (240, 150, 30), w)
        for x in (226, 286):
            _marker(d, circle(x, 178, 8, 10), black, w, True)
        _marker(d, [J(216, 210), J(256, 236), J(296, 210)], black, w)
    elif kind == "house":
        _marker(d, [J(150, 330), J(150, 190), J(362, 190), J(362, 330)], blue, w, True)
        _marker(d, [J(126, 196), J(256, 70), J(386, 196)], red, w)
        _marker(d, [J(232, 330), J(232, 260), J(282, 260), J(282, 330)], black, w)
        _marker(d, [J(176, 214), J(216, 214), J(216, 246), J(176, 246)], blue, w, True)
        _marker(d, [J(300, 214), J(340, 214), J(340, 246), J(300, 246)], blue, w, True)
    elif kind == "star":
        pts = []
        for k in range(10):
            a = -math.pi / 2 + math.tau * k / 10
            r = 140 if k % 2 == 0 else 60
            pts.append(J(256 + r * math.cos(a), 200 + r * math.sin(a)))
        _marker(d, pts, blue, w, True)
        _marker(d, [J(150, 340), J(362, 340)], red, w)
    elif kind == "crown":
        _marker(d, [J(140, 300), J(130, 140), J(200, 220), J(256, 110), J(312, 220), J(382, 140), J(372, 300)], (220, 160, 30), w, True)
        for x in (190, 256, 322):
            _marker(d, circle(x, 262, 12, 12), red, w, True)
    elif kind == "smiley":
        _marker(d, circle(256, 192, 130), black, w, True)
        for x in (210, 302):
            _marker(d, [J(x, 150), J(x, 190)], black, w)
        _marker(d, [J(180, 230), J(220, 270), J(292, 270), J(332, 230)], red, w)
    elif kind == "heart":
        pts = []
        for k in range(40):
            t = math.tau * k / 40
            x = 16 * math.sin(t) ** 3
            y = -(13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))
            pts.append(J(256 + x * 8, 180 + y * 8))
        _marker(d, pts, red, w, True)
        try:
            font = ImageFont.truetype(FONT_BOLD, 64 * S2)
            d.text((256 * S2, 340 * S2), "PINAS", font=font, fill=blue + (235,), anchor="mm")
        except OSError:
            pass
    return img.resize((512, 384), Image.LANCZOS)


def tex_sari_sign():
    w, h = 1024, 280
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([6, 10, w - 6, h - 6], 26, fill=(40, 24, 20, 255))
    d.rounded_rectangle([14, 16, w - 14, h - 14], 22, fill=(255, 214, 60, 255))
    d.rounded_rectangle([30, 32, w - 30, h - 30], 16, outline=(214, 50, 50, 255), width=10)
    font = ImageFont.truetype(FONT_BOLD, 132)
    small = ImageFont.truetype(FONT_BOLD, 40)
    d.text((w // 2 + 4, 128 + 6), "SARI-SARI STORE", font=font, fill=(40, 24, 20, 255), anchor="mm")
    d.text((w // 2, 128), "SARI-SARI STORE", font=font, fill=(30, 60, 160, 255), anchor="mm")
    d.text((w // 2, 214), "kay Aling Nena  ·  LOAD NA DITO", font=small, fill=(200, 40, 40, 255), anchor="mm")
    return img


def tex_poster(variant):
    w, h = 256, 360
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    bg = [(255, 240, 200), (210, 235, 255), (255, 220, 230)][variant]
    d.rectangle([6, 6, w - 6, h - 6], fill=(40, 24, 20, 255))
    d.rectangle([12, 12, w - 12, h - 12], fill=bg + (255,))
    title = ImageFont.truetype(FONT_BOLD, 40)
    body = ImageFont.truetype(FONT_BOLD, 26)
    if variant == 0:
        d.text((w // 2, 52), "BARANGAY", font=title, fill=(30, 60, 160), anchor="mm")
        d.ellipse([78, 92, 178, 192], fill=(255, 190, 40), outline=(40, 24, 20), width=5)
        d.arc([102, 120, 154, 170], 20, 160, fill=(40, 24, 20), width=5)
        d.text((w // 2, 236), "LIGA NG", font=body, fill=(200, 40, 40), anchor="mm")
        d.text((w // 2, 272), "KALYE 2026", font=body, fill=(200, 40, 40), anchor="mm")
    elif variant == 1:
        d.text((w // 2, 52), "TUMBANG", font=title, fill=(200, 40, 40), anchor="mm")
        d.text((w // 2, 96), "PRESO", font=title, fill=(200, 40, 40), anchor="mm")
        d.rounded_rectangle([96, 140, 160, 240], 8, fill=(200, 205, 215), outline=(40, 24, 20), width=5)
        d.text((w // 2, 290), "SABADO 4PM", font=body, fill=(30, 60, 160), anchor="mm")
    else:
        d.text((w // 2, 52), "BAWAL", font=title, fill=(200, 40, 40), anchor="mm")
        d.text((w // 2, 96), "TUMAMBAY", font=body, fill=(40, 24, 20), anchor="mm")
        d.text((w // 2, 128), "DITO", font=body, fill=(40, 24, 20), anchor="mm")
        d.ellipse([88, 164, 168, 244], outline=(200, 40, 40), width=10)
        d.line([(100, 232), (156, 176)], fill=(200, 40, 40), width=10)
        d.text((w // 2, 290), "- Brgy. Captain", font=body, fill=(30, 60, 160), anchor="mm")
    return img


def _chalk(d, pts, color, width, rnd, closed=False):
    """A dusty chalk line: several thin, jittered passes."""
    if closed:
        pts = pts + [pts[0]]
    for k in range(4):
        j = [(x + rnd.uniform(-2.5, 2.5), y + rnd.uniform(-2.5, 2.5)) for x, y in pts]
        d.line(j, fill=color + (rnd.randint(110, 170),), width=max(2, width - k * 2), joint="curve")


def tex_road_text(text, color):
    """Road paint, like the barangay's 'DAHAN-DAHAN' (slow down) before a crossing."""
    img = Image.new("RGBA", (1024, 256), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    font = ImageFont.truetype(FONT_BOLD, 132)
    d.text((512, 128), text, font=font, fill=color + (215,), anchor="mm")
    rng = np.random.default_rng(5)
    a = np.asarray(img).astype(np.float32)
    wear = rng.random(a.shape[:2]) * 0.55 + _noise_rect(a.shape[1], a.shape[0], 24, 6) * 0.45
    a[..., 3] *= np.clip(wear * 1.5, 0.0, 1.0)
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def _noise_rect(w, h, scale, seed):
    rng = np.random.default_rng(seed)
    small = rng.random((max(2, h // scale), max(2, w // scale))).astype(np.float32)
    img = Image.fromarray((small * 255).astype(np.uint8), "L").resize((w, h), Image.BICUBIC)
    return np.asarray(img).astype(np.float32) / 255.0


def tex_chalk_piko():
    """Chalk hopscotch (piko) with numbers, drawn by kids on the road."""
    img = Image.new("RGBA", (512, 1024), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rnd = random.Random(12)
    white, pink, yellow = (250, 250, 245), (255, 150, 190), (255, 230, 120)
    font = ImageFont.truetype(FONT_BOLD, 64)
    rows = [(1, 0), (2, 1), (1, 0), (2, 1), (1, 0)]
    y = 900
    n = 1
    for single, _ in rows:
        if single == 1:
            _chalk(d, [(196, y), (316, y), (316, y - 120), (196, y - 120)], white, 9, rnd, True)
            d.text((256, y - 60), str(n), font=font, fill=pink + (200,), anchor="mm")
            n += 1
        else:
            for x0 in (136, 256):
                _chalk(d, [(x0, y), (x0 + 120, y), (x0 + 120, y - 120), (x0, y - 120)], white, 9, rnd, True)
                d.text((x0 + 60, y - 60), str(n), font=font, fill=pink + (200,), anchor="mm")
                n += 1
        y -= 120
    _chalk(d, [(256 + 90 * math.cos(math.pi + math.pi * k / 16), y - 80 + 80 * math.sin(math.pi + math.pi * k / 16)) for k in range(17)], white, 9, rnd)
    d.text((256, y - 40), "LANGIT", font=ImageFont.truetype(FONT_BOLD, 40), fill=yellow + (210,), anchor="mm")
    return img


def tex_chalk_preso():
    """Tumbang preso marks: the can's circle and the throwing line, with a chalk can."""
    img = Image.new("RGBA", (768, 512), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rnd = random.Random(21)
    white, yellow = (250, 250, 245), (255, 230, 120)
    _chalk(d, [(384 + 110 * math.cos(math.tau * k / 30), 150 + 70 * math.sin(math.tau * k / 30)) for k in range(30)], white, 9, rnd, True)
    _chalk(d, [(296, 128), (296, 176), (330, 190), (330, 142)], yellow, 7, rnd, True)
    _chalk(d, [(80, 430), (688, 430)], white, 10, rnd)
    font = ImageFont.truetype(FONT_BOLD, 46)
    d.text((384, 476), "TUMBANG PRESO", font=font, fill=yellow + (200,), anchor="mm")
    return img


def main(only=None):
    random.seed(1)
    icons = {
        "guava": icon_guava, "tsinelas_light": lambda: icon_tsinelas(False), "tsinelas_heavy": lambda: icon_tsinelas(True),
        "lata": icon_lata, "bato_light": lambda: icon_bato(False), "bato_heavy": lambda: icon_bato(True),
        "gunting_light": lambda: icon_gunting(False), "gunting_heavy": lambda: icon_gunting(True),
        "papel_trap": icon_papel_trap, "papel_shield": icon_papel_shield, "jacks": icon_jacks, "bola": icon_bola,
        "trumpo": icon_trumpo, "dash": icon_dash, "bookmark": icon_bookmark, "gear": icon_gear, "button_face": button_face,
    }
    for name, make in icons.items():
        if only is None or name in only:
            save(make(), ICONS, name)
    if only is not None:
        return
    save(tex_asphalt(), TEXTURES, "asphalt")
    save(tex_pavers(), TEXTURES, "pavers")
    for kind in ("sun", "house", "star", "crown", "smiley", "heart"):
        save(tex_doodle(kind), TEXTURES, "doodle_" + kind)
    save(tex_sari_sign(), TEXTURES, "sari_sign")
    save(tex_road_text("DAHAN-DAHAN", (255, 214, 60)), TEXTURES, "road_dahan")
    save(tex_chalk_piko(), TEXTURES, "chalk_piko")
    save(tex_chalk_preso(), TEXTURES, "chalk_preso")
    for k in range(3):
        save(tex_poster(k), TEXTURES, "poster_%d" % k)


if __name__ == "__main__":
    import sys
    main(sys.argv[1:] or None)
