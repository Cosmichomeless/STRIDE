#!/usr/bin/env python3
"""Builds the App Store search-results image: make_search.py  (writes into docs/app-store/header/)."""
import os
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = Path(__file__).resolve().parent
ICON = HERE.parents[1] / "STRIDE/Assets.xcassets/AppIcon.appiconset/icon-1024.png"
FONT = "/System/Library/Fonts/SFNSRounded.ttf"
TEXT = {
    "es": ("STRIDE", "Registra tus carreras.", "Sin cuentas. Sin rastreo."),
    "en": ("STRIDE", "Track your runs.", "No accounts. No tracking."),
    "fr": ("STRIDE", "Enregistrez vos courses.", "Sans compte. Sans suivi."),
    "de": ("STRIDE", "Zeichne deine Läufe auf.", "Ohne Konto. Ohne Tracking."),
    "it": ("STRIDE", "Registra le tue corse.", "Zero account. Zero tracking."),
    "pt-BR": ("STRIDE", "Registre suas corridas.", "Sem conta. Sem rastreio."),
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



SEARCH_SIZES = [(5244, 2950), (3840, 2560), (1920, 1280)]


def build_search(lang, w, h):
    canvas = gradient(w, h).convert("RGBA")
    u = h / 1280  # every measure scales with the height
    icon_px = round(300 * u)
    icon = rounded(Image.open(ICON).resize((icon_px,) * 2, Image.LANCZOS), round(icon_px * 0.2237))
    left = round(w * 0.08)
    top = round(h * 0.17)
    shadow(canvas, icon, (left, top), round(20 * u), round(12 * u))
    canvas.alpha_composite(icon, (left, top))
    draw = ImageDraw.Draw(canvas)
    name, line1, line2 = TEXT[lang]
    y = top + icon_px + round(60 * u)
    draw.text((left, y), name, font=font(round(190 * u), "Heavy"), fill="white")
    draw.text((left, y + round(225 * u)), line1, font=font(round(78 * u), "Semibold"), fill="white")
    draw.text((left, y + round(325 * u)), line2, font=font(round(78 * u), "Regular"), fill=(255, 255, 255, 215))
    phone_w = round(min(w * 0.30, h * 0.50))
    shot = Image.open(f"{HERE}/screenshots/{lang}/02-tracking-active.png").convert("RGB")
    shot = shot.resize((phone_w, round(phone_w * shot.height / shot.width)), Image.LANCZOS)
    shot = rounded(shot, round(phone_w * 0.085))
    pos = (round(w * 0.62), round(h * 0.16))
    shadow(canvas, shot, pos, round(28 * u), round(18 * u))
    canvas.alpha_composite(shot, pos)
    return canvas.convert("RGB")


os.makedirs(f"{HERE}/search", exist_ok=True)
for lang in TEXT:
    for w, h in SEARCH_SIZES:
        path = f"{HERE}/search/search-{lang}-{w}x{h}.png"
        build_search(lang, w, h).save(path)
        print(path)
