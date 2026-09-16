"""Generate platform app icons from the source artwork.

Source: assets/branding/app_icon.png (a rounded-square icon on a near-white
background). The outer white is made transparent (flood-filled from the four
corners) so the rounded corners stay clean on any background, then the image is
downscaled into the Windows / Android / web icon slots.

Run from the repo root:  python tool/gen_icons.py
"""

import os
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "branding", "app_icon.png")
MAGIC = (255, 0, 254)


def load_source() -> Image.Image:
    im = Image.open(SRC).convert("RGBA")
    w, h = im.size
    for corner in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]:
        ImageDraw.floodfill(im, corner, MAGIC, thresh=60)
    arr = np.array(im)
    mask = (arr[:, :, 0] == MAGIC[0]) & (arr[:, :, 1] == MAGIC[1]) & (arr[:, :, 2] == MAGIC[2])
    arr[mask, 3] = 0
    return Image.fromarray(arr, "RGBA")


def resized(im: Image.Image, size: int) -> Image.Image:
    return im.resize((size, size), Image.LANCZOS)


def main() -> int:
    if not os.path.exists(SRC):
        print(f"missing source: {SRC}", file=sys.stderr)
        return 1
    im = load_source()

    ico = os.path.join(ROOT, "windows", "runner", "resources", "app_icon.ico")
    im.save(ico, format="ICO", sizes=[(s, s) for s in (16, 24, 32, 48, 64, 128, 256)])
    print("wrote", ico)

    mips = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    for name, size in mips.items():
        path = os.path.join(
            ROOT, "android", "app", "src", "main", "res", f"mipmap-{name}", "ic_launcher.png"
        )
        resized(im, size).save(path)
        print("wrote", path)

    web = {
        "Icon-192.png": 192,
        "Icon-512.png": 512,
        "Icon-maskable-192.png": 192,
        "Icon-maskable-512.png": 512,
    }
    for name, size in web.items():
        path = os.path.join(ROOT, "web", "icons", name)
        resized(im, size).save(path)
        print("wrote", path)
    favicon = os.path.join(ROOT, "web", "favicon.png")
    resized(im, 32).save(favicon)
    print("wrote", favicon)

    launch = os.path.join(
        ROOT, "android", "app", "src", "main", "res", "drawable-nodpi", "launch_image.png"
    )
    os.makedirs(os.path.dirname(launch), exist_ok=True)
    resized(im, 192).save(launch)
    print("wrote", launch)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
