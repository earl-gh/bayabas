"""Composes the round skill buttons from the painted icons (run make_assets.py first).

Run: python3 tools/art/make_buttons.py
Run slice_skill_art.py first. Output: assets/icons/btn_<id>.png (256 px). Each button
is the cardboard disc with the whole painted skill icon on its flat face. The icon's own
glow shows the type (attack red, crowd control violet, block blue, heal green). The weapon
types are read from data/weapons/*.tres.
"""
import os
import re

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ICONS = os.path.join(ROOT, "assets", "icons")
WEAPONS = os.path.join(ROOT, "data", "weapons")
SIZE = 256
SS = 4
N = SIZE * SS
FACE_RADIUS = 104  # in final pixels
RIM_RADIUS = 125

# WeaponDef.Kind order: ATTACK, CROWD_CONTROL, BLOCK
KIND_FACES = {
    0: ((255, 104, 84), (150, 20, 34)),     # attack: red
    1: ((196, 130, 255), (78, 30, 150)),    # crowd control: violet
    2: ((110, 180, 255), (20, 56, 160)),    # block: blue
}
HEAL_FACE = ((150, 236, 110), (30, 120, 50))
MOVE_FACE = ((70, 104, 190), (20, 30, 84))


def weapon_kinds():
    kinds = {}
    for name in sorted(os.listdir(WEAPONS)):
        if not name.endswith(".tres"):
            continue
        text = open(os.path.join(WEAPONS, name)).read()
        wid = re.search(r'^id = &"(\w+)"', text, re.M).group(1)
        kind = re.search(r"^kind = (\d+)", text, re.M)
        kinds[wid] = int(kind.group(1)) if kind else 0
    return kinds


def disc(radius, blur=0.0):
    m = Image.new("L", (N, N), 0)
    c = N / 2
    r = radius * SS
    ImageDraw.Draw(m).ellipse([c - r, c - r, c + r, c + r], fill=255)
    return m.filter(ImageFilter.GaussianBlur(blur * SS)) if blur else m


def radial(top, bottom):
    """Face gradient: light upper left to dark lower right."""
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float32) / N
    t = np.clip((xx * 0.35 + yy * 0.65 - 0.15) / 0.8, 0.0, 1.0)[..., None]
    c0 = np.array(top + (255,), np.float32)
    c1 = np.array(bottom + (255,), np.float32)
    return Image.fromarray((c0 * (1 - t) + c1 * t).astype(np.uint8), "RGBA")


ART = os.path.join(ICONS, "art")
DISC = os.path.join(ROOT, "assets", "ui", "skill_disc.png")
FACE_RATIO = 0.44  # radius of the flat cardboard face, as a fraction of the disc width


def centroid(alpha):
    """Alpha-weighted centre of an image, in pixels."""
    a = np.asarray(alpha, dtype=np.float32)
    total = a.sum() or 1.0
    ys, xs = np.mgrid[0:a.shape[0], 0:a.shape[1]]
    return float((a * xs).sum() / total), float((a * ys).sum() / total)


def compose(icon_path, scale=0.98, nudge=(0, 0)):
    """The cardboard disc with the whole painted icon sitting inside its flat face (not cropped)."""
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    disc = Image.open(DISC).convert("RGBA")
    side = int(N * 0.97)
    disc = disc.resize((side, int(side * disc.height / disc.width)), Image.LANCZOS)
    ox, oy = (N - disc.width) // 2, (N - disc.height) // 2
    shadow = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    shadow.paste(Image.new("RGBA", disc.size, (10, 6, 12, 255)), (ox, oy + 5 * SS), disc.split()[3].filter(ImageFilter.GaussianBlur(3 * SS)).point(lambda v: v * 120 // 255))
    img.alpha_composite(shadow)
    img.alpha_composite(disc, (ox, oy))
    # the centre of the flat face: the disc's own weight centre (its rim is uneven)
    dx, dy = centroid(disc.split()[3])
    cx, cy = ox + dx, oy + dy
    icon = Image.open(icon_path).convert("RGBA")
    isz = int(disc.width * FACE_RATIO * 2 * scale)
    icon = icon.resize((isz, isz), Image.LANCZOS)
    # optical centring: put the visual weight of the icon (not its box) on the face centre
    mx, my = centroid(icon.split()[3])
    limit = isz * 0.07
    shift_x = max(-limit, min(limit, isz / 2 - mx))
    shift_y = max(-limit, min(limit, isz / 2 - my))
    img.alpha_composite(icon, (int(cx - isz / 2 + shift_x + nudge[0] * SS), int(cy - isz / 2 + shift_y + nudge[1] * SS)))
    return img.resize((SIZE, SIZE), Image.LANCZOS)


def main():
    for wid, kind in weapon_kinds().items():
        compose(os.path.join(ART, wid + ".png")).save(os.path.join(ICONS, "btn_%s.png" % wid), optimize=True)
        print("btn_" + wid, ["ATK", "CC", "BLK", "HEAL"][kind])
    for name in ("heal", "guava", "guava_bitten", "dash", "pin_return"):
        compose(os.path.join(ART, name + ".png")).save(os.path.join(ICONS, "btn_%s.png" % name), optimize=True)
    compose(os.path.join(ICONS, "pin.png"), scale=0.84, nudge=(0, 2)).save(os.path.join(ICONS, "btn_pin.png"), optimize=True)
    print("buttons done")


if __name__ == "__main__":
    main()
