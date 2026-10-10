"""Cuts the painted skill icons out of the generated sheets in tools/art/src.

Run: python3 tools/art/slice_skill_art.py
Output: assets/icons/art/<id>.png (512 px square, transparent) and
assets/ui/skill_disc.png (the cardboard button base). make_buttons.py composes
them into assets/icons/btn_<id>.png.
"""
import os

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "tools", "art", "src")
OUT = os.path.join(ROOT, "assets", "icons", "art")
SIZE = 512


def sheet(n):
    return Image.open(os.path.join(SRC, "skill_art_%d.webp" % n)).convert("RGBA")


def save_cell(img, box, name):
    cell = img.crop(box)
    cell = cell.crop(cell.getbbox())
    side = max(cell.size)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.paste(cell, ((side - cell.width) // 2, (side - cell.height) // 2))
    square.resize((SIZE, SIZE), Image.LANCZOS).save(os.path.join(OUT, name + ".png"), optimize=True)
    print(name)


def thirds(n, names):
    img = sheet(n)
    w = img.width / 3
    for i, name in enumerate(names):
        save_cell(img, (int(i * w), 0, int((i + 1) * w), img.height), name)


def main():
    os.makedirs(OUT, exist_ok=True)
    thirds(18, ["jacks", "bola", "trumpo"])
    thirds(21, ["tsinelas_light", "tsinelas_heavy", "lata"])
    img = sheet(19)
    rows = [(0, 503), (503, 982), (982, 1536)]
    names = [("bato_light", "bato_heavy"), ("gunting_light", "gunting_heavy"), ("papel_trap", "papel_shield")]
    for (y0, y1), (left, right) in zip(rows, names):
        save_cell(img, (0, y0, 512, y1), left)
        save_cell(img, (512, y0, 1024, y1), right)
    img = sheet(20)
    save_cell(img, (0, 0, 920, img.height), "heal")
    save_cell(img, (920, 0, img.width, img.height), "langit_lupa")
    disc = sheet(17)
    disc = disc.crop(disc.getbbox())
    disc.resize((256, int(256 * disc.height / disc.width)), Image.LANCZOS).save(os.path.join(ROOT, "assets", "ui", "skill_disc.png"), optimize=True)


if __name__ == "__main__":
    main()
