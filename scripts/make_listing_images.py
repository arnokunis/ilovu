#!/usr/bin/env python3
"""Compose App Store listing images from raw simulator screenshots.

Layout is deliberate: a short benefit HEADLINE on top, a one-line clarifier under
it, the real screenshot below. Most people never swipe past image two, so image
one carries the promise and the rest earn the scroll. No device frame — frameless
gives the UI more pixels, and the UI is what people are actually judging.
"""
import sys, pathlib
from PIL import Image, ImageDraw, ImageFont, ImageFilter

W, H = 1320, 2868                      # 6.9" — what App Store Connect expects
FONT_DIR = pathlib.Path.home() / "ilovu-content/fonts"
BOLD = str(FONT_DIR / "Montserrat-Bold.ttf")
BODY = str(FONT_DIR / "Montserrat-Regular.ttf")
if not pathlib.Path(BODY).exists():
    BODY = BOLD

DEEP_ROSE = (168, 56, 90)
MUTED     = (150, 104, 110)
BLUSH     = (255, 246, 243)
WARM      = (255, 226, 216)

def gradient(w, h, top, bottom):
    strip = Image.new("RGB", (1, h))
    d = ImageDraw.Draw(strip)
    for y in range(h):
        t = y / max(h - 1, 1)
        d.point((0, y), fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    return strip.resize((w, h), Image.LANCZOS)

def rounded(img, r):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.size[0] - 1, img.size[1] - 1], radius=r, fill=255)
    out = img.convert("RGBA"); out.putalpha(mask)
    return out

def wrap(draw, text, font, max_w):
    lines, cur = [], ""
    for word in text.split():
        trial = (cur + " " + word).strip()
        if draw.textlength(trial, font=font) <= max_w:
            cur = trial
        else:
            if cur: lines.append(cur)
            cur = word
    if cur: lines.append(cur)
    return lines

def compose(src, headline, sub, out):
    canvas = Image.new("RGB", (W, H))
    canvas.paste(gradient(W, H, BLUSH, WARM), (0, 0))
    draw = ImageDraw.Draw(canvas)

    size = 96
    font = ImageFont.truetype(BOLD, size)
    lines = wrap(draw, headline, font, W - 180)
    while len(lines) > 2 and size > 62:
        size -= 6
        font = ImageFont.truetype(BOLD, size)
        lines = wrap(draw, headline, font, W - 180)

    y = 150
    for line in lines:
        draw.text(((W - draw.textlength(line, font=font)) / 2, y), line, font=font, fill=DEEP_ROSE)
        y += int(size * 1.16)

    if sub:
        sfont = ImageFont.truetype(BODY, 46)
        y += 18
        for line in wrap(draw, sub, sfont, W - 220):
            draw.text(((W - draw.textlength(line, font=sfont)) / 2, y), line, font=sfont, fill=MUTED)
            y += 62

    # Screenshot: scaled to FIT the remaining space — never cropped, never squashed,
    # so the tab bar and the bottom of every card survive.
    shot = Image.open(src).convert("RGB")
    top = y + 66
    avail_h, avail_w = H - top - 80, W - 240
    scale = min(avail_w / shot.width, avail_h / shot.height)
    shot = shot.resize((int(shot.width * scale), int(shot.height * scale)), Image.LANCZOS)
    shot = rounded(shot, 50)

    x = (W - shot.width) // 2
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    sd = Image.new("RGBA", shot.size, (0, 0, 0, 0))
    sd.paste((120, 40, 60, 80), (0, 0), shot.split()[-1])
    shadow.paste(sd, (x, top + 20), sd)
    shadow = shadow.filter(ImageFilter.GaussianBlur(30))
    canvas = Image.alpha_composite(canvas.convert("RGBA"), shadow)
    canvas.paste(shot, (x, top), shot)
    canvas.convert("RGB").save(out, "PNG")
    print(f"  {out.name}  <- {src.name[20:28]}  \"{headline}\"")

src_dir, out_dir = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
out_dir.mkdir(parents=True, exist_ok=True)
shots = sorted(src_dir.glob("*.png"))
for n, spec in enumerate(sys.argv[3:], 1):
    idx, headline, sub = spec.split("|")
    compose(shots[int(idx) - 1], headline, sub, out_dir / f"{n:02d}.png")
