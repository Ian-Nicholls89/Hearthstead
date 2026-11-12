#!/usr/bin/env python3
"""Composes the launcher icons from build/icon_fg.png (rendered by make_icon.gd):
icon.png (512), icons/icon_192.png, and the adaptive foreground and background."""
from PIL import Image, ImageDraw

fg = Image.open("build/icon_fg.png").convert("RGBA")
bbox = fg.getbbox()
fg = fg.crop(bbox)


def sky(size):
    im = Image.new("RGBA", (size, size))
    d = ImageDraw.Draw(im)
    for y in range(size):
        t = y / size
        top, bottom = (58, 92, 128), (236, 178, 112)    # evening blue down to a warm glow
        c = tuple(int(top[k] + (bottom[k] - top[k]) * t ** 1.4) for k in range(3))
        d.line([(0, y), (size, y)], fill=c + (255,))
    return im


def fit(im, box):
    s = min(box / im.width, box / im.height)
    return im.resize((max(1, int(im.width * s)), max(1, int(im.height * s))), Image.LANCZOS)


def compose(size, scale):
    out = sky(size)
    f = fit(fg, int(size * scale))
    out.alpha_composite(f, ((size - f.width) // 2, int(size * 0.53 - f.height / 2)))
    return out


compose(512, 0.9).save("icon.png")
compose(192, 0.9).save("icons/icon_192.png")
f = fit(fg, int(432 * 0.62))                  # adaptive icons are cropped to a circle
a = Image.new("RGBA", (432, 432))
a.alpha_composite(f, ((432 - f.width) // 2, (432 - f.height) // 2 + 8))
a.save("icons/adaptive_fg.png")
sky(432).save("icons/adaptive_bg.png")
print("icons written")
