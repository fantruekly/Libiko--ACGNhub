"""Generate platform app icons from the source artwork.

Source: assets/branding/app_icon.png (full-bleed square artwork). It is
downscaled into the Windows / Android / web icon slots as-is; the launcher or
shell applies its own corner masking, so no transparency is added here.

Run from the repo root:  python tool/gen_icons.py
"""

import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "branding", "app_icon.png")


def load_source() -> Image.Image:
    return Image.open(SRC).convert("RGBA")


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
