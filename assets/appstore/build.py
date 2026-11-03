#!/usr/bin/env python3
"""Builds the App Store screenshots (#362): each raw capture (capture-ios.sh, capture-mac.sh) becomes a bold, colour-ground slide.

    python3 assets/appstore/build.py <iphone|ipad|mac>

Style: one large Fraunces headline with its accent phrase in italics, a flat brand-colour ground per slide, the real screen shown large
and slightly tilted, and a cut-out of one part of the UI floating over it. Needs Pillow. The fonts are ThreadsKit's (Fraunces, Hanken
Grotesk; SIL Open Font License), found in its Swift package checkout. Raw captures: assets/appstore/raw/<device>/. Output: assets/appstore/<folder>/.
"""
import glob
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))

# Brand colours (docs/design/threadskit-usage.md) and the soft grounds made from them.
PAPER, DEEP, GREEN, MINT, TERRA, TERRA_DARK = (239, 244, 240), (12, 71, 103), (31, 106, 88), (143, 203, 184), (221, 160, 128), (154, 79, 46)
MINT_SOFT, TERRA_SOFT, BLUE_SOFT = (207, 230, 220), (243, 224, 212), (214, 228, 238)

# Per device: the canvas App Store Connect asks for and the folder the finished slides go to. Sizes scale with the canvas width.
DEVICES = {
    # status_bar: the height in capture pixels of the system status bar, which is painted out (see clean_status_bar); none on a Mac window.
    # grip: the side of the square, in capture pixels, painted out in the bottom-right corner (iPadOS draws a window-resize grip there).
    # chrome: how the status bar goes: "paint" it out in the page's colour (one flat colour on an iPhone) or "crop" it off (an iPad's top
    # edge has a sidebar and a pane of different colours). one_line: the headline on one line, for a wide canvas.
    "iphone": dict(size=(1320, 2868), folder="iphone-6.9", status_bar=200, grip=0, chrome="paint", one_line=False, fade=0.60, radius=0.07),
    "ipad": dict(size=(2752, 2064), folder="ipad-13", status_bar=60, grip=140, chrome="paint", one_line=True, fade=0.50, radius=0.022),   # an iPad's own corners are tight: more would clip its toolbar
    "mac": dict(size=(2880, 1800), folder="mac", status_bar=0, grip=0, chrome="crop", one_line=True, fade=0.50, radius=0.012),
}

# Each slide. hero: where the whole capture sits (centre x and top as fractions of the canvas, width as a fraction of the canvas width,
# tilt in degrees). floats: parts of the capture (crop box as fractions of it) cut out and laid over it the same way.
IPHONE_SLIDES = [
    dict(raw="1-today", bg=MINT_SOFT, ink=DEEP, accent=GREEN, lines=[("One list.", False), ("Just today.", True)],
         hero=dict(cx=0.50, top=0.24, width=0.84, rot=-4),
         floats=[dict(crop=(0.0, 0.655, 1.0, 0.905), cx=0.34, cy=0.82, width=0.72, rot=4)]),
    dict(raw="2-night-build", bg=DEEP, ink=PAPER, accent=MINT, lines=[("Plan tomorrow,", False), ("tonight.", True)],
         hero=dict(cx=0.50, top=0.24, width=0.84, rot=4),
         floats=[dict(raw="2-night-load", crop=(0.0, 0.17, 1.0, 0.52), cx=0.64, cy=0.80, width=0.72, rot=-4)]),
    dict(raw="3-habits", bg=TERRA_SOFT, ink=DEEP, accent=TERRA_DARK, lines=[("Habits as a grid", False), ("of days.", True)],
         hero=dict(cx=0.50, top=0.24, width=0.84, rot=-4),
         floats=[dict(crop=(0.0, 0.495, 1.0, 0.745), cx=0.36, cy=0.82, width=0.72, rot=4)]),
    dict(raw="4-anchors", bg=BLUE_SOFT, ink=DEEP, accent=GREEN, lines=[("What your day", False), ("moves around.", True)],
         hero=dict(cx=0.50, top=0.24, width=0.84, rot=4),
         floats=[dict(crop=(0.0, 0.295, 1.0, 0.52), cx=0.64, cy=0.82, width=0.72, rot=-4)]),
    dict(raw="6-focus", bg=GREEN, ink=PAPER, accent=MINT, lines=[("Begin a task.", False), ("Stay with it.", True)],
         hero=dict(cx=0.50, top=0.24, width=0.84, rot=-4),
         floats=[dict(crop=(0.0, 0.87, 1.0, 0.975), cx=0.50, cy=0.86, width=0.80, rot=3)]),
    dict(raw="5-wellbeing", bg=PAPER, ink=DEEP, accent=GREEN, lines=[("A gentle read on", False), ("how it's going.", True)],
         hero=dict(cx=0.50, top=0.24, width=0.84, rot=4),
         floats=[dict(crop=(0.0, 0.535, 1.0, 0.815), cx=0.64, cy=0.82, width=0.72, rot=-4)]),
]


IPAD_SLIDES = [
    dict(raw="1b-today-open", bg=MINT_SOFT, ink=DEEP, accent=GREEN, lines=[("One list.", False), ("Just today.", True)],
         hero=dict(cx=0.50, top=0.26, width=0.76, rot=-3),
         floats=[dict(crop=(0.21, 0.72, 0.52, 0.99), cx=0.27, cy=0.84, width=0.30, rot=3)]),
    dict(raw="2-night-build", bg=DEEP, ink=PAPER, accent=MINT, lines=[("Plan tomorrow,", False), ("tonight.", True)],
         hero=dict(cx=0.50, top=0.27, width=0.78, rot=3),
         floats=[dict(crop=(0.38, 0.25, 0.90, 0.45), cx=0.70, cy=0.84, width=0.40, rot=-3)]),
    dict(raw="3-habits-open", bg=TERRA_SOFT, ink=DEEP, accent=TERRA_DARK, lines=[("Habits as a grid", False), ("of days.", True)],
         hero=dict(cx=0.50, top=0.27, width=0.78, rot=-3),
         floats=[dict(crop=(0.50, 0.08, 0.99, 0.45), cx=0.72, cy=0.84, width=0.40, rot=3)]),
    dict(raw="4-anchors-open", bg=BLUE_SOFT, ink=DEEP, accent=GREEN, lines=[("What your day", False), ("moves around.", True)],
         hero=dict(cx=0.50, top=0.27, width=0.78, rot=3),
         floats=[dict(raw="1b-today-open", crop=(0.21, 0.72, 0.52, 0.99), cx=0.72, cy=0.84, width=0.30, rot=-3)]),
    dict(raw="5-wellbeing", bg=PAPER, ink=DEEP, accent=GREEN, lines=[("A gentle read on", False), ("how it's going.", True)],
         hero=dict(cx=0.50, top=0.27, width=0.78, rot=-3),
         floats=[dict(crop=(0.22, 0.38, 0.99, 0.78), cx=0.34, cy=0.84, width=0.44, rot=3)]),
]


SLIDES = {"iphone": IPHONE_SLIDES, "ipad": IPAD_SLIDES, "mac": []}


def fonts_dir():
    found = glob.glob(os.path.expanduser("~/Library/Developer/Xcode/DerivedData/Jamaal-*/SourcePackages/checkouts/threads-kit/Sources/ThreadsTokens/Resources/Fonts"))
    if not found:
        sys.exit("ThreadsKit's fonts weren't found: build the app in Xcode once so its packages are checked out.")
    return found[0]


def clean_chrome(image, status_bar, grip, chrome="paint"):
    """Takes the system's own furniture out: the status bar (time, signal, battery), painted over in the page's colour or cropped off, and
    iPadOS's resize grip. A store picture shows the app, not a made-up status bar."""
    image = image.copy()
    draw = ImageDraw.Draw(image)
    if status_bar > 0 and chrome == "crop":
        image = image.crop((0, status_bar, image.width, image.height))
        draw = ImageDraw.Draw(image)
    elif status_bar > 0:
        # The colour comes from the strip's own top margin, above the time, which is always the page behind the app (a point just below the
        # strip can land on a dark bar or a card and leave a black band).
        draw.rectangle((0, 0, image.width, status_bar), fill=image.getpixel((image.width // 2, 6)))
    if grip > 0:
        draw.rectangle((image.width - grip, image.height - grip, image.width, image.height),
                       fill=image.getpixel((image.width - grip - 4, image.height - grip // 2)))
    return image


def rounded(image, radius):
    """The image with rounded corners, as RGBA."""
    image = image.convert("RGBA")
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, image.width - 1, image.height - 1), radius=radius, fill=255)
    image.putalpha(mask)
    return image


def place(canvas, piece, cx, y_or_cy, rot, by_top, shadow=True):
    """Tilts a rounded piece, gives it a soft shadow and pastes it centred on cx (at the given top, or the given centre)."""
    turned = piece.rotate(rot, expand=True, resample=Image.BICUBIC)
    x = int(cx - turned.width / 2)
    y = int(y_or_cy if by_top else y_or_cy - turned.height / 2)
    if shadow:
        blur = max(24, canvas.width // 40)
        layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
        glow = Image.new("RGBA", turned.size, (6, 32, 46, 0))
        glow.putalpha(turned.getchannel("A").point(lambda a: int(a * 0.34)))
        layer.paste(glow, (x, y + blur // 2), glow)
        canvas.alpha_composite(layer.filter(ImageFilter.GaussianBlur(blur)))
    canvas.alpha_composite(turned, (x, y)) if (x >= 0 and y >= 0) else canvas.paste(turned, (x, y), turned)


def compose(device, slide, spec, fonts_path):
    size = spec["size"]
    raw = os.path.join(HERE, "raw", device, slide["raw"] + ".png")
    if not os.path.exists(raw):
        return None
    w, h = size
    k = min(w, h) / 1320                                 # the sizes below are written for a 1320-wide canvas (the short side)
    canvas = Image.new("RGBA", size, slide["bg"] + (255,))
    draw = ImageDraw.Draw(canvas)
    display = ImageFont.truetype(os.path.join(fonts_path, "FrauncesDisplay-Regular.ttf"), int(150 * k))
    italic = ImageFont.truetype(os.path.join(fonts_path, "FrauncesDisplay-Italic.ttf"), int(150 * k))

    # The headline: large and centred, the accent phrase in italics. A slide lists its lines; a wide canvas draws them as one row.
    rows = [list(slide["lines"])] if spec["one_line"] else [[line] for line in slide["lines"]]
    y = int(0.075 * h) if spec["one_line"] else int(150 * k)
    size_px = int(150 * k)
    if spec["one_line"]:                                  # one row must fit the canvas: shrink it until it does
        while True:
            display = ImageFont.truetype(os.path.join(fonts_path, "FrauncesDisplay-Regular.ttf"), size_px)
            italic = ImageFont.truetype(os.path.join(fonts_path, "FrauncesDisplay-Italic.ttf"), size_px)
            row_w = sum(draw.textlength(text, font=italic if it else display) for text, it in rows[0]) + draw.textlength(" ", font=display) * (len(rows[0]) - 1)
            if row_w <= 0.90 * w or size_px < 60:
                break
            size_px -= 6
    space = draw.textlength(" ", font=display)
    for row in rows:
        total = sum(draw.textlength(text, font=italic if it else display) for text, it in row) + space * (len(row) - 1)
        x = (w - total) / 2
        for text, it in row:
            font = italic if it else display
            draw.text((x, y), text, font=font, fill=slide["accent"] if it else slide["ink"])
            x += draw.textlength(text, font=font) + space
        y += int(168 * k)

    shot = clean_chrome(Image.open(raw).convert("RGB"), spec["status_bar"], spec["grip"], spec["chrome"])
    if "hero_crop" in slide:                              # keep only the part of a tall screen that has something on it
        x0, y0, x1, y1 = slide["hero_crop"]
        shot = shot.crop((int(x0 * shot.width), int(y0 * shot.height), int(x1 * shot.width), int(y1 * shot.height)))
    hero = slide["hero"]
    hero_w = int(hero["width"] * w)
    hero_img = rounded(shot.resize((hero_w, int(shot.height * hero_w / shot.width)), Image.LANCZOS), int(spec["radius"] * hero_w))
    place(canvas, hero_img, hero["cx"] * w, hero["top"] * h, hero["rot"], by_top=True)

    # The screen fades into the ground toward the bottom, so the cut-out in front of it is the one crisp thing there.
    fade_top = int(spec["fade"] * h)
    fade_h = h - fade_top
    ramp = Image.new("L", (1, fade_h))
    ramp.putdata([int(255 * min(1, (i / fade_h) * 1.6) ** 1.2) for i in range(fade_h)])
    veil = Image.new("RGBA", (w, fade_h), slide["bg"] + (255,))
    veil.putalpha(ramp.resize((w, fade_h)))
    canvas.alpha_composite(veil, (0, fade_top))

    for fl in slide["floats"]:
        x0, y0, x1, y1 = fl["crop"]
        source = Image.open(os.path.join(HERE, "raw", device, fl.get("raw", slide["raw"]) + ".png")).convert("RGB")
        part = source.crop((int(x0 * source.width), int(y0 * source.height), int(x1 * source.width), int(y1 * source.height)))
        part_w = int(fl["width"] * w)
        part = part.resize((part_w, int(part.height * part_w / part.width)), Image.LANCZOS)
        place(canvas, rounded(part, int(0.045 * part_w)), fl["cx"] * w, fl["cy"] * h, fl["rot"], by_top=False)
    return canvas.convert("RGB")                          # no alpha: App Store Connect rejects transparency


def main():
    device = sys.argv[1] if len(sys.argv) > 1 else sys.exit(__doc__)
    spec = DEVICES[device]
    out = os.path.join(HERE, spec["folder"])
    os.makedirs(out, exist_ok=True)
    fonts_path = fonts_dir()
    for number, slide in enumerate(SLIDES[device], start=1):
        image = compose(device, slide, spec, fonts_path)
        if image is None:
            print("missing capture", slide["raw"]); continue
        path = os.path.join(out, f"{number:02d}-{slide['raw'].split('-', 1)[1]}.png")
        image.save(path, optimize=True)
        print(path, image.size)


if __name__ == "__main__":
    main()
