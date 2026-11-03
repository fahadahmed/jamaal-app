#!/usr/bin/env python3
"""Prepares the pictures for Design (#362): the raw captures with the system's own furniture taken out (the status bar, iPadOS's window grip).

    python3 assets/appstore/prepare-handoff.py

Reads assets/appstore/raw/<device>/ (capture-ios.sh, capture-ipad.sh, capture-mac.sh, capture-duo.sh) and writes assets/appstore/design-handoff/.
Needs Pillow. Composing the final slides is Design's job: see docs/design/app-store-screenshots-brief.md. (build.py is an earlier attempt at the
composing, kept as a reference for the sizes and the idea; it is not part of the handoff.)
"""
import os
import shutil

from PIL import Image

from build import DEVICES, clean_chrome

HERE = os.path.dirname(os.path.abspath(__file__))

# device: (raw folder, handoff folder, [(raw name, handoff name)])
SETS = {
    "iphone": ("iphone", "iphone-6.9", [
        ("1-today", "01-today"), ("2-night-build", "02-night-planning-build"), ("2-night-load", "02b-night-planning-load"),
        ("2-night-review", "02c-night-planning-review"), ("3-habits", "03-habits"), ("4-anchors", "04-anchors"),
        ("5-wellbeing", "05-wellbeing"), ("6-focus", "06-focus")]),
    "ipad": ("ipad", "ipad-13-landscape", [
        ("1b-today-open", "01-today-task-open"), ("1-today", "01b-today"), ("2-night-build", "02-night-planning-build"),
        ("2-night-load", "02b-night-planning-load"), ("3-habits-open", "03-habits-open"), ("4-anchors-open", "04-anchors-open"),
        ("5-wellbeing", "05-wellbeing"), ("6-focus", "06-focus")]),
    "mac": ("mac", "mac", [
        ("1-today-open", "01-today-task-open"), ("2-night-build", "02-night-planning-build"), ("3-habits-open", "03-habits-open"),
        ("4-anchors-open", "04-anchors-open"), ("5-wellbeing", "05-wellbeing"), ("6-focus", "06-focus"), ("7-settings-day", "07-settings-window")]),
}


# The Duo's own status pill (the time and the battery ring) sits at the top of its side column, per pose: the rectangle to paint out in
# capture pixels, and where to take the colour to paint it with (a point of the page beside it).
DUO_STATUS = {
    "outer": ((1150, 215, 1340, 490), (1100, 350)),
    "inner-landscape": ((2610, 40, 2853, 380), (2580, 235)),
    "half-open": ((2610, 40, 2853, 380), (2580, 235)),
    "tabletop": ((1600, 40, 2007, 240), (1500, 140)),
    "inner-portrait": ((1600, 40, 2007, 240), (1500, 140)),
}


def prepare_duo(out_root):
    """The Duo pictures are the displays as the system draws them; only the status pill is taken out."""
    from PIL import ImageDraw
    duo_raw = os.path.join(HERE, "raw", "duo")
    if not os.path.isdir(duo_raw):
        return
    for pose in sorted(os.listdir(duo_raw)):
        folder = os.path.join(duo_raw, pose)
        if not os.path.isdir(folder) or pose not in DUO_STATUS:
            continue
        rect, sample = DUO_STATUS[pose]
        out = os.path.join(out_root, "iphone-duo", pose)
        os.makedirs(out, exist_ok=True)
        for name in sorted(os.listdir(folder)):
            if not name.endswith(".png"):
                continue
            image = Image.open(os.path.join(folder, name)).convert("RGB")
            ImageDraw.Draw(image).rectangle(rect, fill=image.getpixel(sample))
            image.save(os.path.join(out, name), optimize=True)
            print("iphone-duo", pose, name, image.size)


def main():
    out_root = os.path.join(HERE, "design-handoff")
    for device, (raw_dir, folder, names) in SETS.items():
        spec = DEVICES[device]
        out = os.path.join(out_root, folder)
        os.makedirs(out, exist_ok=True)
        for raw_name, name in names:
            src = os.path.join(HERE, "raw", raw_dir, raw_name + ".png")
            if not os.path.exists(src):
                print("missing", src); continue
            image = Image.open(src).convert("RGB")
            if device != "mac":
                image = clean_chrome(image, spec["status_bar"], spec["grip"], "paint")      # painted out, never a made-up one drawn in
            image.save(os.path.join(out, name + ".png"), optimize=True)
            print(folder, name, image.size)
    prepare_duo(out_root)



# The README of the handoff folder: every file and its size, written from what is there.
NOTES = {
    "iphone-6.9": ("iPhone 6.9\"", "1320 × 2868", "App Store Connect, iPhone (the required set). The first three are what show in search."),
    "ipad-13-landscape": ("iPad 13\", landscape", "2752 × 2064", "App Store Connect, iPad 13\"."),
    "mac": ("Mac window", "2880 × 1800 (the pictures are the window, 2048 × 1250; the Settings window is smaller)", "App Store Connect, Mac."),
    "iphone-duo": ("iPhone Duo, by pose", "your choice", "Website, social and product-page art. There is no Duo slot in App Store Connect."),
}
DUO_POSES = {
    "outer": "closed: the outer display (466 × 678 pt)",
    "inner-landscape": "fully open, landscape: the inner display (951 × 669 pt)",
    "half-open": "half open, vertical crease: the inner display, the two panes meeting at the crease",
    "tabletop": "tabletop: the inner display, portrait, the timer split at the crease",
    "inner-portrait": "fully open, portrait: the inner display, one column",
}


def write_readme():
    root = os.path.join(HERE, "design-handoff")
    lines = [
        "# Design handoff: App Store pictures", "",
        "The real app, captured with a curated dataset (`-JamaalStoreShots`), in Light appearance. **The system status bar, the iPadOS window grip and "
        "the Duo's status pill have been taken out**; please do not draw one back in. Nothing here is composed: turning these into the store slides "
        "is the job in [the brief](../../../docs/design/app-store-screenshots-brief).", "",
        "Regenerate with `capture-ios.sh`, `capture-ipad.sh`, `capture-mac.sh` and `capture-duo.sh` (the Duo poses are set by hand in Device Hub), "
        "then `prepare-handoff.py`.", "",
    ]
    total = 0
    for folder in ["iphone-6.9", "ipad-13-landscape", "mac", "iphone-duo"]:
        path = os.path.join(root, folder)
        if not os.path.isdir(path):
            continue
        title, canvas, where = NOTES[folder]
        lines += [f"## {title}", f"Canvas to make: {canvas}. {where}", ""]
        for dirpath, _dirs, files in sorted(os.walk(path)):
            files = sorted(f for f in files if f.endswith(".png"))
            if not files:
                continue
            if folder == "iphone-duo":
                pose = os.path.basename(dirpath)
                lines += [f"### {pose}: {DUO_POSES.get(pose, '')}", ""]
            lines += ["| File | Pixels |", "|---|---|"]
            for name in files:
                file_path = os.path.join(dirpath, name)
                image = Image.open(file_path)
                total += os.path.getsize(file_path)
                lines.append(f"| `{os.path.relpath(file_path, root)}` | {image.width} × {image.height} |")
            lines.append("")
    lines.append(f"Total: {total / 1e6:.1f} MB.")
    with open(os.path.join(root, "README.md"), "w") as out:
        out.write("\n".join(lines) + "\n")
    print("wrote design-handoff/README.md")


if __name__ == "__main__":
    main()
    write_readme()
