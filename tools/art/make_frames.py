"""Paints the 9-slice UI frames with Pillow: panels, buttons and pills with real depth.

Run: python3 tools/art/make_frames.py
Output: assets/ui/*.png. Each is drawn at 4x and downsampled. A panel is a navy card
inside a bevelled gold frame (light top-left edge, dark bottom-right edge, a dark
outline), with an inner shadow under the frame and a soft gloss across the top.
A button is a glossy, bevelled slab with a darker lip underneath (pressed = no lip).
Godot draws them with StyleBoxTexture (KalyeahTheme.frame_box / button_box).
"""
import os

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "ui")
SS = 4
INK = (34, 20, 18, 255)


def rounded(size, box, radius, blur=0):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle([v * SS for v in box], radius=radius * SS, fill=255)
    return m.filter(ImageFilter.GaussianBlur(blur * SS)) if blur else m


def vertical(size, top, bottom, y0, y1):
    h = size[1]
    t = np.clip((np.arange(h, dtype=np.float32) - y0 * SS) / max((y1 - y0) * SS, 1), 0, 1)[:, None, None]
    c0 = np.array(top + (255,), np.float32)
    c1 = np.array(bottom + (255,), np.float32)
    row = c0 * (1 - t) + c1 * t
    return Image.fromarray(np.repeat(row, size[0], axis=1).astype(np.uint8), "RGBA")


def paint(img, mask, color_or_img):
    layer = color_or_img if isinstance(color_or_img, Image.Image) else Image.new("RGBA", img.size, color_or_img)
    img.paste(layer, (0, 0), mask)


def bevel_ring(img, outer, inner, light, dark, w, h, radius):
    """A frame between two rounded rects, lit from the top left."""
    ring = ImageChops.subtract(outer, inner)
    paint(img, ring, vertical(img.size, light, dark, 0, h))
    # a thin bright edge on the inside top and a dark edge on the inside bottom
    hi = ImageChops.subtract(inner.filter(ImageFilter.MaxFilter(5)), inner)
    hi = ImageChops.multiply(hi, vertical(img.size, (255, 255, 255), (0, 0, 0), 0, h).convert("L"))
    paint(img, hi.point(lambda v: v * 160 // 255), (255, 250, 220, 255))


def panel(w=192, h=192, radius=34, rim=12, face_top=(40, 58, 120), face_bottom=(16, 22, 58), gold=((255, 232, 140), (170, 104, 24)), alpha=232):
    size = (w * SS, h * SS)
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    shadow = rounded(size, (4, 8, w - 4, h - 2), radius, 4).point(lambda v: v * 110 // 255)
    paint(img, shadow, (6, 4, 12, 255))
    outer = rounded(size, (2, 2, w - 2, h - 6), radius)
    paint(img, outer, INK)
    frame = rounded(size, (5, 5, w - 5, h - 9), radius - 3)
    face = rounded(size, (5 + rim, 5 + rim, w - 5 - rim, h - 9 - rim), radius - rim)
    bevel_ring(img, frame, face, gold[0], gold[1], w, h, radius)
    face_img = vertical(size, face_top, face_bottom, 5 + rim, h - 9 - rim)
    face_img.putalpha(alpha)
    paint(img, face, face_img)
    # inner shadow under the frame: the face sits below the rim
    inner_shadow = ImageChops.subtract(face, rounded(size, (5 + rim + 6, 5 + rim + 10, w - 5 - rim - 6, h - 9 - rim - 4), radius - rim, 5))
    inner_shadow = ImageChops.multiply(inner_shadow, face).point(lambda v: v * 150 // 255)
    paint(img, inner_shadow, (4, 4, 14, 255))
    # gloss across the top of the face
    gloss = rounded(size, (5 + rim + 6, 5 + rim + 4, w - 5 - rim - 6, 5 + rim + 26), 14, 3)
    gloss = ImageChops.multiply(gloss, face).point(lambda v: v * 42 // 255)
    paint(img, gloss, (255, 255, 255, 255))
    # specular glints on the gold
    glint = Image.new("L", size, 0)
    ImageDraw.Draw(glint).line([(radius * SS, 8 * SS), ((w // 2) * SS, 8 * SS)], fill=255, width=2 * SS)
    paint(img, glint.filter(ImageFilter.GaussianBlur(SS)), (255, 255, 240, 220))
    return img.resize((w, h), Image.LANCZOS)


def button(color, w=192, h=96, radius=30, pressed=False):
    size = (w * SS, h * SS)
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    lip = 0 if pressed else 9
    top = 2 + (7 if pressed else 0)
    shadow = rounded(size, (4, top + 6, w - 4, h - 1), radius, 3).point(lambda v: v * 100 // 255)
    paint(img, shadow, (6, 4, 10, 255))
    outer = rounded(size, (2, top, w - 2, h - 3), radius)
    paint(img, outer, INK)
    dark = tuple(int(c * 0.58) for c in color)
    lip_mask = rounded(size, (5, top + 3, w - 5, h - 6), radius - 3)
    paint(img, lip_mask, dark)
    face = rounded(size, (5, top + 3, w - 5, h - 6 - lip), radius - 3)
    light = tuple(min(255, int(c * 1.18 + 20)) for c in color)
    paint(img, face, vertical(size, light, color, top + 3, h - 6 - lip))
    # inner bevel: bright top edge, darker bottom edge of the face
    rim_light = ImageChops.subtract(face, rounded(size, (8, top + 7, w - 8, h - 6 - lip), radius - 6))
    rim_light = ImageChops.multiply(rim_light, vertical(size, (255, 255, 255), (0, 0, 0), top, (top + h) // 2).convert("L"))
    paint(img, rim_light.point(lambda v: v * 150 // 255), (255, 255, 240, 255))
    gloss = rounded(size, (14, top + 7, w - 14, top + 3 + (h - lip - top) * 0.42), 16, 2)
    gloss = ImageChops.multiply(gloss, face).point(lambda v: v * 95 // 255)
    paint(img, gloss, (255, 255, 255, 255))
    return img.resize((w, h), Image.LANCZOS)


def pill(w=128, h=64):
    size = (w * SS, h * SS)
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    shadow = rounded(size, (3, 6, w - 3, h - 1), (h - 8) // 2, 3).point(lambda v: v * 90 // 255)
    paint(img, shadow, (0, 0, 0, 255))
    outer = rounded(size, (2, 2, w - 2, h - 5), (h - 7) // 2)
    paint(img, outer, (12, 10, 22, 225))
    face = rounded(size, (5, 5, w - 5, h - 8), (h - 13) // 2)
    paint(img, face, vertical(size, (52, 58, 96), (18, 20, 40), 5, h - 8))
    hi = ImageChops.subtract(face, rounded(size, (7, 8, w - 7, h - 8), (h - 16) // 2))
    paint(img, hi.point(lambda v: v * 120 // 255), (255, 255, 255, 255))
    alpha = img.split()[3].point(lambda v: min(v, 222))
    img.putalpha(alpha)
    return img.resize((w, h), Image.LANCZOS)


def main():
    os.makedirs(OUT, exist_ok=True)
    panel().save(os.path.join(OUT, "panel.png"), optimize=True)
    for name, color in (("orange", (255, 160, 30)), ("green", (70, 180, 70)), ("red", (220, 60, 54)),
                        ("blue", (54, 110, 220)), ("grey", (96, 100, 116)), ("gold", (250, 196, 50))):
        button(color).save(os.path.join(OUT, "button_%s.png" % name), optimize=True)
        button(color, pressed=True).save(os.path.join(OUT, "button_%s_pressed.png" % name), optimize=True)
    pill().save(os.path.join(OUT, "pill.png"), optimize=True)
    print("frames done")


if __name__ == "__main__":
    main()
