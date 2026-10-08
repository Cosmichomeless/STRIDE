#!/usr/bin/env python3
"""Rebuilds docs/screenshots/00-showcase.png (1200x560) from versioned files only.

Inputs: the app icon and two of the full screenshots in this folder.
It does not capture the app; see "Recapturing the screenshots" in docs/screenshots/README.md.

    python3 -m pip install Pillow
    python3 docs/screenshots/build-showcase.py
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
SHOTS = ROOT / "docs" / "screenshots"
ICON = ROOT / "STRIDE" / "Assets.xcassets" / "AppIcon.appiconset" / "icon-1024.png"
OUT = SHOTS / "00-showcase.png"

WIDTH, HEIGHT = 1200, 560
ORANGE, CRIMSON = (0xFE, 0x87, 0x26), (0xE8, 0x2A, 0x4D)   # icon corners, see docs/DESIGN.md

# (file, crop box as fractions of the screenshot: left, top, right, bottom)
PANELS = [
    (SHOTS / "02-tracking-active.png", (0.0, 0.07, 1.0, 0.93)),
    (SHOTS / "03-run-details.png", (0.0, 0.05, 1.0, 0.91)),
]
PANEL_HEIGHT = 480
RADIUS = 36


def gradient() -> Image.Image:
    """Diagonal gradient like the icon: orange at the top right, crimson at the bottom left."""
    img = Image.new("RGB", (WIDTH, HEIGHT))
    px = img.load()
    for y in range(HEIGHT):
        for x in range(WIDTH):
            t = ((WIDTH - x) / WIDTH + y / HEIGHT) / 2
            px[x, y] = tuple(round(a + (b - a) * t) for a, b in zip(ORANGE, CRIMSON))
    return img


def rounded(img: Image.Image, radius: int) -> Image.Image:
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, *img.size), radius, fill=255)
    out = img.convert("RGBA")
    out.putalpha(mask)
    return out


def paste_with_shadow(canvas: Image.Image, tile: Image.Image, xy: tuple[int, int]) -> None:
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (xy[0], xy[1] + 10, xy[0] + tile.width, xy[1] + 10 + tile.height), RADIUS, fill=(0, 0, 0, 90)
    )
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(14)))
    canvas.alpha_composite(tile, xy)


def panel(path: Path, box: tuple[float, float, float, float]) -> Image.Image:
    shot = Image.open(path).convert("RGB")
    w, h = shot.size
    crop = shot.crop((round(box[0] * w), round(box[1] * h), round(box[2] * w), round(box[3] * h)))
    scale = PANEL_HEIGHT / crop.height
    crop = crop.resize((round(crop.width * scale), PANEL_HEIGHT), Image.LANCZOS)
    return rounded(crop, RADIUS)


def main() -> None:
    canvas = gradient().convert("RGBA")

    icon = rounded(Image.open(ICON).convert("RGB").resize((340, 340), Image.LANCZOS), 76)
    paste_with_shadow(canvas, icon, (70, (HEIGHT - icon.height) // 2))

    panels = [panel(p, box) for p, box in PANELS]
    gap = 36
    total = sum(p.width for p in panels) + gap * (len(panels) - 1)
    x = WIDTH - 70 - total
    for p in panels:
        paste_with_shadow(canvas, p, (x, (HEIGHT - p.height) // 2))
        x += p.width + gap

    canvas.convert("RGB").save(OUT, optimize=True)
    print(f"wrote {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
