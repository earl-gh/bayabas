"""Composes the round skill buttons from the painted icons (run make_assets.py first).

Run: python3 tools/art/make_buttons.py
Output: assets/icons/btn_<id>.png (256 px). Each button is a gold rim around a face
coloured by the skill's type (attack red, block blue, crowd control violet, heal
green, movement skills navy), with the icon enlarged and cropped inside the face,
an inner shadow so the face sits deep in the rim, and a glossy highlight on top.
The weapon types are read from data/weapons/*.tres.
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


def compose(icon_name, face_colors, scale=1.18, nudge=(0, 6)):
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    # drop shadow under the whole button
    shadow = disc(RIM_RADIUS, 4).point(lambda v: v * 120 // 255)
    img.paste(Image.new("RGBA", (N, N), (10, 6, 12, 255)), (0, 6 * SS), shadow)
    # gold rim: outer ink, bevelled gold, darker inner lip
    img.paste(Image.new("RGBA", (N, N), (40, 24, 18, 255)), (0, 0), disc(RIM_RADIUS + 3))
    img.paste(radial((255, 238, 150), (176, 110, 26)), (0, 0), disc(RIM_RADIUS))
    img.paste(radial((150, 96, 30), (255, 214, 110)), (0, 0), disc(FACE_RADIUS + 9))
    face = disc(FACE_RADIUS)
    img.paste(radial(*face_colors), (0, 0), face)
    # the icon, enlarged and cropped to the face
    icon = Image.open(os.path.join(ICONS, icon_name + ".png")).convert("RGBA")
    side = int(FACE_RADIUS * 2 * scale * SS)
    icon = icon.resize((side, side), Image.LANCZOS)
    layer = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    layer.alpha_composite(icon, ((N - side) // 2 + nudge[0] * SS, (N - side) // 2 + nudge[1] * SS))
    alpha = ImageChops.multiply(layer.split()[3], face)
    layer.putalpha(alpha)
    img.alpha_composite(layer)
    # inner shadow: the face sits deep inside the rim
    ring = ImageChops.subtract(face, disc(FACE_RADIUS - 16, 6))
    ring = ImageChops.multiply(ring, face).point(lambda v: v * 150 // 255)
    img.paste(Image.new("RGBA", (N, N), (8, 4, 16, 255)), (0, 0), ring)
    # glossy highlight across the top of the face
    gloss = Image.new("L", (N, N), 0)
    c = N / 2
    ImageDraw.Draw(gloss).ellipse([c - 82 * SS, c - 98 * SS, c + 82 * SS, c - 10 * SS], fill=255)
    gloss = ImageChops.multiply(gloss.filter(ImageFilter.GaussianBlur(5 * SS)), face).point(lambda v: v * 70 // 255)
    img.paste(Image.new("RGBA", (N, N), (255, 255, 255, 255)), (0, 0), gloss)
    # specular glint on the rim
    glint = Image.new("L", (N, N), 0)
    ImageDraw.Draw(glint).arc([c - 118 * SS, c - 118 * SS, c + 118 * SS, c + 118 * SS], 200, 260, fill=255, width=5 * SS)
    img.paste(Image.new("RGBA", (N, N), (255, 255, 240, 255)), (0, 0), glint.filter(ImageFilter.GaussianBlur(SS)))
    return img.resize((SIZE, SIZE), Image.LANCZOS)


def main():
    for wid, kind in weapon_kinds().items():
        compose(wid, KIND_FACES[kind]).save(os.path.join(ICONS, "btn_%s.png" % wid), optimize=True)
        print("btn_" + wid, ["ATK", "CC", "BLK"][kind])
    for name, icon in (("ball", "guava"), ("guava", "guava")):
        compose(icon, HEAL_FACE).save(os.path.join(ICONS, "btn_%s.png" % name), optimize=True)
    for name in ("dash", "bookmark"):
        compose(name, MOVE_FACE, scale=1.05, nudge=(0, 2)).save(os.path.join(ICONS, "btn_%s.png" % name), optimize=True)
    print("buttons done")


if __name__ == "__main__":
    main()
