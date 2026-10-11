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











def icon_pin():
    """The pin skill: a red round-headed push pin stuck slanted in the ground, with
    a small red ring where it went in and a dashed hop arc back to it."""
    p = Painter(ICON, ICON)
    ring = p.ellipse_mask((40, 176, 176, 226))
    hole = p.ellipse_mask((62, 186, 154, 216))
    p.paint(ImageChops.subtract(ring, hole), (230, 60, 60, 230))
    for k in range(5):
        a = math.pi * (0.15 + k * 0.14)
        x, y = 160 + 70 * math.cos(a), 150 - 80 * math.sin(a)
        p.stroke([(x, y), (x + 8, y - 4)], 6, (255, 255, 255, 200))
    needle = p.line_mask([(108, 200), (138, 104)], 9)
    p.fill(needle, (240, 244, 250), (130, 136, 150), angle=0, outline=4)
    collar = p.ellipse_mask((116, 82, 170, 112), angle=-18)
    p.fill(collar, (200, 40, 50), (120, 16, 30), outline=5)
    head = p.ellipse_mask((96, 22, 196, 104), angle=-18)
    p.fill(head, (255, 110, 100), (176, 20, 36), angle=60, outline=7)
    p.shade(head, (140, 50, 220, 120), alpha=70)
    p.shine(head, (112, 34, 150, 62), alpha=190, angle=-18)
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


def tex_alley():
    """Worn concrete alley floor: big slabs with joints, stains, wet patches and cracks."""
    n = 512
    rng = np.random.default_rng(21)
    grain = rng.random((n, n)).astype(np.float32)
    mottled = _noise(n, 48, 5) * 0.55 + _noise(n, 12, 6) * 0.45
    v = 150 + mottled * 26 + grain * 12
    rgb = np.stack([v * 1.0, v * 0.98, v * 0.93], -1)
    img = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    d = ImageDraw.Draw(img)
    rnd = random.Random(31)
    slab = n // 2  # 2 x 2 slabs per tile, joints on the wrap so it tiles
    for k in range(2):
        for off in (0, n):
            d.line([(k * slab, 0), (k * slab, n)], fill=(88, 84, 78, 255), width=4)
            d.line([(0, k * slab), (n, k * slab)], fill=(88, 84, 78, 255), width=4)
    for k in range(2):
        d.line([(k * slab + 3, 0), (k * slab + 3, n)], fill=(196, 192, 184, 140), width=1)
        d.line([(0, k * slab + 3), (n, k * slab + 3)], fill=(196, 192, 184, 140), width=1)
    for _ in range(7):  # damp stains and wet patches
        layer = Image.new("RGBA", (160, 120), (0, 0, 0, 0))
        ImageDraw.Draw(layer).ellipse([14, 18, rnd.randint(70, 150), rnd.randint(50, 110)], fill=(70, 64, 58, rnd.randint(30, 60)))
        _tile_paste(img, layer.filter(ImageFilter.GaussianBlur(10)), rnd.randint(0, n), rnd.randint(0, n))
    for _ in range(3):  # moss in the joints
        layer = Image.new("RGBA", (90, 40), (0, 0, 0, 0))
        ImageDraw.Draw(layer).ellipse([8, 8, 82, 30], fill=(86, 118, 58, 70))
        _tile_paste(img, layer.filter(ImageFilter.GaussianBlur(4)), rnd.randint(0, n), (rnd.choice((0, 1)) * slab) % n)
    for _ in range(5):  # cracks
        layer = Image.new("RGBA", (n, n), (0, 0, 0, 0))
        dd = ImageDraw.Draw(layer)
        x, y = rnd.uniform(0, n), rnd.uniform(0, n)
        a = rnd.uniform(0, math.tau)
        pts = [(x, y)]
        for _ in range(rnd.randint(6, 12)):
            a += rnd.uniform(-0.8, 0.8)
            x += math.cos(a) * rnd.uniform(8, 22)
            y += math.sin(a) * rnd.uniform(8, 22)
            pts.append((x, y))
        dd.line(pts, fill=(70, 66, 62, 150), width=2)
        img.alpha_composite(layer)
    for _ in range(120):  # pebbles
        x, y = rnd.uniform(0, n), rnd.uniform(0, n)
        r = rnd.uniform(0.8, 2.0)
        ImageDraw.Draw(img).ellipse([x - r, y - r, x + r, y + r], fill=(205, 200, 192, 150))
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


def tex_cardboard_tears():
    """Damage on a cardboard sheet: dark ragged holes with torn light edges, scuffs,
    a crease and two strips of brown packing tape. Transparent elsewhere."""
    w, h = 1024, 512
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rnd = random.Random(31)
    for _ in range(14):  # scuffs and dirt
        x, y = rnd.uniform(40, w - 40), rnd.uniform(40, h - 40)
        r = rnd.uniform(18, 60)
        layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        ImageDraw.Draw(layer).ellipse([x - r, y - r * 0.6, x + r, y + r * 0.6], fill=(70, 46, 26, 90))
        img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(10)))
    for cx, cy, size in ((260, 300, 70), (700, 190, 54), (520, 380, 36), (860, 360, 44)):
        pts = []
        for k in range(14):
            a = math.tau * k / 14
            rr = size * rnd.uniform(0.55, 1.15)
            pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a) * 0.8))
        d.polygon(pts, fill=(205, 160, 104, 255))  # torn light fibre edge
        inner = [(cx + (x - cx) * 0.78, cy + (y - cy) * 0.78) for x, y in pts]
        d.polygon(inner, fill=(28, 18, 12, 255))  # the hole
        for x, y in pts[::2]:
            d.line([(x, y), (x + rnd.uniform(-14, 14), y + rnd.uniform(-14, 14))], fill=(205, 160, 104, 255), width=4)
    crease = [(80, 120)]
    for k in range(8):
        crease.append((crease[-1][0] + rnd.uniform(90, 130), crease[-1][1] + rnd.uniform(-25, 30)))
    d.line(crease, fill=(96, 64, 34, 200), width=6, joint="curve")
    for x0, y0, x1, y1 in ((150, 80, 420, 140), (600, 420, 900, 330)):
        tape = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        td = ImageDraw.Draw(tape)
        nx, ny = -(y1 - y0), x1 - x0
        n = math.hypot(nx, ny)
        nx, ny = nx / n * 26, ny / n * 26
        td.polygon([(x0 + nx, y0 + ny), (x1 + nx, y1 + ny), (x1 - nx, y1 - ny), (x0 - nx, y0 - ny)], fill=(176, 120, 52, 215))
        td.line([(x0 + nx * 0.6, y0 + ny * 0.6), (x1 + nx * 0.6, y1 + ny * 0.6)], fill=(230, 190, 120, 160), width=4)
        img.alpha_composite(tape)
    return img


def main(only=None):
    random.seed(1)
    icons = {"guava": icon_guava, "pin": icon_pin, "gear": icon_gear}
    for name, make in icons.items():
        if only is None or name in only:
            save(make(), ICONS, name)
    if only is not None:
        return
    save(tex_asphalt(), TEXTURES, "asphalt")
    save(tex_pavers(), TEXTURES, "pavers")
    save(tex_alley(), TEXTURES, "alley")
    for kind in ("sun", "house", "star", "crown", "smiley", "heart"):
        save(tex_doodle(kind), TEXTURES, "doodle_" + kind)
    save(tex_sari_sign(), TEXTURES, "sari_sign")
    save(tex_cardboard_tears(), TEXTURES, "cardboard_tears")
    save(tex_road_text("DAHAN-DAHAN", (255, 214, 60)), TEXTURES, "road_dahan")
    save(tex_chalk_piko(), TEXTURES, "chalk_piko")
    save(tex_chalk_preso(), TEXTURES, "chalk_preso")
    for k in range(3):
        save(tex_poster(k), TEXTURES, "poster_%d" % k)


if __name__ == "__main__":
    import sys
    main(sys.argv[1:] or None)
