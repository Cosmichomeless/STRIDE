#!/usr/bin/env python3
"""Builds the App Store product page header: make_header.py  (writes into docs/app-store/header/)."""
import os
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = Path(__file__).resolve().parent
ICON = HERE.parents[1] / "STRIDE/Assets.xcassets/AppIcon.appiconset/icon-1024.png"
FONT = "/System/Library/Fonts/SFNSRounded.ttf"
TEXT = {
    "es": ("STRIDE", "Registra tus carreras.", "Sin cuentas. Sin rastreo."),
    "en": ("STRIDE", "Track your runs.", "No accounts. No tracking."),
}
SIZES = [(3840, 1646), (5244, 2950)]


def font(size, weight="Bold"):
    f = ImageFont.truetype(FONT, size)
    try:
        f.set_variation_by_name(weight)
    except Exception:
        pass
    return f


def gradient(w, h):
    # Same direction as the icon: orange at the top right, red-pink at the bottom left.
    top, bottom = (255, 140, 36), (232, 41, 79)
    small = Image.new("RGB", (256, 256))
    px = small.load()
    for y in range(256):
        for x in range(256):
            t = ((255 - x) + y) / 510
            px[x, y] = tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
    return small.resize((w, h), Image.BICUBIC)


def rounded(im, radius):
    mask = Image.new("L", im.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, *im.size), radius, fill=255)
    out = im.convert("RGBA")
    out.putalpha(mask)
    return out


def shadow(canvas, im, pos, blur, offset):
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    mask = Image.new("RGBA", im.size, (0, 0, 0, 120))
    mask.putalpha(im.getchannel("A").point(lambda a: a * 120 // 255))
    layer.paste(mask, (pos[0], pos[1] + offset), mask)
    canvas.alpha_composite(layer.filter(ImageFilter.GaussianBlur(blur)))


def build(lang, w, h):
    canvas = gradient(w, h).convert("RGBA")
    u = h / 1646  # every measure scales with the height
    icon = rounded(Image.open(ICON).resize((round(300 * u),) * 2, Image.LANCZOS), round(300 * u * 0.2237))
    left = round(w * 0.075)
    top = round(h * 0.2)
    shadow(canvas, icon, (left, top), round(24 * u), round(14 * u))
    canvas.alpha_composite(icon, (left, top))
    draw = ImageDraw.Draw(canvas)
    name, line1, line2 = TEXT[lang]
    y = top + round(300 * u) + round(70 * u)
    draw.text((left, y), name, font=font(round(210 * u), "Heavy"), fill="white")
    draw.text((left, y + round(250 * u)), line1, font=font(round(92 * u), "Semibold"), fill="white")
    draw.text((left, y + round(370 * u)), line2, font=font(round(92 * u), "Regular"), fill=(255, 255, 255, 215))

    # Two phones on the right, running off the bottom edge.
    phone_w = round(w * 0.215)
    for i, (name_png, dx, dy) in enumerate([("02-tracking-active.png", 0.50, 0.17), ("03-run-details.png", 0.735, 0.30)]):
        shot = Image.open(f"{HERE}/screenshots/{lang}/{name_png}").convert("RGB")
        shot = shot.resize((phone_w, round(phone_w * shot.height / shot.width)), Image.LANCZOS)
        shot = rounded(shot, round(phone_w * 0.085))
        pos = (round(w * dx), round(h * dy))
        shadow(canvas, shot, pos, round(30 * u), round(20 * u))
        canvas.alpha_composite(shot, pos)
    return canvas.convert("RGB")


os.makedirs(f"{HERE}/header", exist_ok=True)
for lang in TEXT:
    for w, h in SIZES:
        path = f"{HERE}/header/header-{lang}-{w}x{h}.png"
        build(lang, w, h).save(path)
        print(path)
