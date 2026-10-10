"""Slices the 5-direction sprite sheets into keyed PNG cells.

usage: python3 tools/sprites/slice_sheets.py <kid> <anim>=<sheet image> [...]
A sheet with several rows names them top to bottom: ko_stagger+ko_lying=sheet.webp
Each row is 5 equal cells: toward, toward-right, right, away-right, away
(left-facing views are mirrored in game). Magenta (#FF00FF) is keyed to transparent
and the pink fringe is despilled. Output: assets/sprites/<kid>/<anim>_<dir>.png
"""
import os
import sys

import numpy as np
from PIL import Image

DIRS = ["toward", "toward_right", "right", "away_right", "away"]
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "sprites")


def key_magenta(img):
    a = np.asarray(img.convert("RGB")).astype(np.float32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    # how magenta a pixel is: red and blue high, green low
    magenta = np.clip((np.minimum(r, b) - g) / 140.0, 0.0, 1.0)
    alpha = 1.0 - np.clip((magenta - 0.35) / 0.45, 0.0, 1.0)
    # despill: pull red/blue down towards green on partly keyed edges
    spill = np.clip(magenta, 0.0, 1.0)
    limit = g + (1.0 - spill) * 255.0
    r = np.minimum(r, limit)
    b = np.minimum(b, limit)
    out = np.dstack([r, g, b, alpha * 255.0]).clip(0, 255).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def main():
    kid = sys.argv[1]
    folder = os.path.join(OUT, kid)
    os.makedirs(folder, exist_ok=True)
    for spec in sys.argv[2:]:
        names, path = spec.split("=", 1)
        sheet = Image.open(path)
        rows = names.split("+")
        cell = sheet.width // len(DIRS)
        height = sheet.height // len(rows)
        for r, anim in enumerate(rows):
            for i, name in enumerate(DIRS):
                part = key_magenta(sheet.crop((i * cell, r * height, (i + 1) * cell, (r + 1) * height)))
                part.save(os.path.join(folder, "%s_%s.png" % (anim, name)))
                print(anim, name, part.size, part.getbbox())


main()
