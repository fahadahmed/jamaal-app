#!/usr/bin/env python3
# Light-theme Instagram carousel builder (1080x1350). Run from the repo root: python3 <dir>/build.py
# FONT_DIR defaults to the ThreadsKit fonts inside a built Jamaal.app.
import os, subprocess, sys, tempfile, pathlib

FONT_DIR = os.environ.get('FONT_DIR', '/Applications/Jamaal.app/Contents/Resources/ThreadsKit_ThreadsTokens.bundle/Contents/Resources')
R, I = f'{FONT_DIR}/FrauncesDisplay-Regular.ttf', f'{FONT_DIR}/FrauncesDisplay-Italic.ttf'
H, M = f'{FONT_DIR}/HankenGrotesk-Regular.ttf', f'{FONT_DIR}/JetBrainsMono-Medium.ttf'
BG, INK, ACCENT, RULE = '#EFF4F0', '#0A3A53', '#1F6A58', '#B9CBC3'
ICON = 'Jamaal/Jamaal/Assets.xcassets/AppIcon.appiconset/AppIcon-default.png'
W, HT = 1080, 1350
OUT = pathlib.Path(__file__).resolve().parent
TMP = pathlib.Path(tempfile.mkdtemp())


def magick(*args):
    subprocess.run(['magick', *map(str, args)], check=True)


def icon(size=200, radius=46):
    path = TMP / f'icon{size}.png'
    if not path.exists():
        s = size - 1
        magick(ICON, '-resize', f'{size}x{size}',
               '(', '+clone', '-alpha', 'extract', '-fill', 'black', '-colorize', '100', '-fill', 'white',
               '-draw', f'roundrectangle 0,0 {s},{s} {radius},{radius}', ')',
               '-alpha', 'off', '-compose', 'CopyOpacity', '-composite', path)
    return path


def phone(src, crop_h=None, width=800):
    """A screenshot as a rounded card with an outline and soft shadow; it bleeds off the bottom."""
    path = TMP / f'phone-{pathlib.Path(src).stem}-{crop_h}.png'
    crop = ['-crop', f'560x{crop_h}+0+0', '+repage'] if crop_h else []
    h = int(subprocess.check_output(['magick', 'identify', '-format', '%h', src]).decode())
    h = int((crop_h or h) * width / 560)
    w1, h1 = width - 1, h - 1
    magick(src, *crop, '-filter', 'Lanczos', '-resize', f'{width}x',
           '(', '+clone', '-alpha', 'extract', '-fill', 'black', '-colorize', '100', '-fill', 'white',
           '-draw', f'roundrectangle 0,0 {w1},{h1} 60,60', ')',
           '-alpha', 'off', '-compose', 'CopyOpacity', '-composite',
           '(', '-size', f'{width}x{h}', 'xc:none', '-fill', 'none', '-stroke', RULE, '-strokewidth', '4',
           '-draw', f'roundrectangle 2,2 {w1 - 2},{h1 - 2} 58,58', ')', '-compose', 'Over', '-composite',
           '(', '+clone', '-background', INK, '-shadow', '30x24+0+0', ')', '+swap',
           '-background', 'none', '-layers', 'merge', '+repage', path)
    return path


class Slide:
    def __init__(self, n, total):
        self.n, self.total = n, total
        self.args = ['-size', f'{W}x{HT}', f'xc:{BG}']

    def label(self, text, y):
        self.args += ['-font', M, '-pointsize', 30, '-kerning', 5, '-fill', ACCENT, '-annotate', f'+88+{y}', text, '-kerning', 0]
        return self

    def head(self, lines, y, size=82, step=None):
        """lines: [(text, 'r'|'i')]; 'i' is the italic accent."""
        step = step or int(size * 1.17)
        for k, (text, style) in enumerate(lines):
            self.args += ['-font', R if style == 'r' else I, '-pointsize', size,
                          '-fill', INK if style == 'r' else ACCENT, '-annotate', f'+80+{y + k * step}', text]
        return self

    def body(self, text, y, size=44, width=880):
        path = TMP / f'body{self.n}-{y}.png'
        magick('-size', f'{width}x', '-background', 'none', '-fill', INK, '-font', H, '-pointsize', size,
               '-interline-spacing', 14, f'caption:{text}', path)
        self.args += [path, '-geometry', f'+88+{y}', '-composite']
        return self

    def icon(self, x, y, size=200):
        self.args += [icon(size), '-geometry', f'+{x}+{y}', '-composite']
        return self

    def phone(self, src, y, crop_h=None):
        self.args += [phone(src, crop_h), '-geometry', f'+{(W - 800) // 2}+{y}', '-composite']
        return self

    def counter(self):
        self.args += ['-font', M, '-pointsize', 26, '-kerning', 3, '-fill', ACCENT, '-gravity', 'SouthEast',
                      '-annotate', '+88+60', f'{self.n} / {self.total}', '-gravity', 'NorthWest', '-kerning', 0]
        return self

    def save(self, name):
        magick(*self.args, OUT / name)


def build(slides):
    """slides: list of (filename, function(Slide))."""
    total = len(slides)
    for n, (name, fn) in enumerate(slides, 1):
        s = Slide(n, total)
        fn(s)
        s.save(name)
        print('built', name)


# ---- slide templates -------------------------------------------------------
def cover(label, lines, sub):
    def f(s):
        size = min(150, int(900 / (0.52 * max(len(t) for t, _ in lines))))  # keep the longest line inside the margins
        step = int(size * 1.08)
        s.icon(88, 150).label(label, 470).head(lines, 650, size=size, step=step)
        s.body(sub, 650 + step * len(lines) + 20)
        s.args += ['-font', M, '-pointsize', 30, '-kerning', 4, '-fill', ACCENT, '-annotate', '+88+1230', 'SWIPE  →', '-kerning', 0]
    return f


def text_slide(label, lines, body):
    def f(s):
        s.label(label, 160).head(lines, 330, size=100, step=118).body(body, 330 + 118 * len(lines) + 60, size=46)
        s.counter()
    return f


def phone_slide(label, lines, src, crop_h=None):
    def f(s):
        s.label(label, 120).head(lines, 235, size=82, step=96).phone(src, 440, crop_h)
    return f


def cta(sub1='On iPhone, iPad and Mac.', sub2='Free while in beta.'):
    def f(s):
        s.icon(88, 150).head([('Join the', 'r'), ('beta.', 'i')], 560, size=120, step=140)
        s.body(f'{sub1} {sub2}', 830)
        s.args += ['-font', H, '-pointsize', 44, '-fill', ACCENT, '-annotate', '+88+1100', 'Join the beta · link in bio']
    return f

# ---- Story 5: reel teaser (1080x1920, light theme) ----
HT = 1920
s = Slide(1, 1)
s.icon(88, 260, 200)
s.label('TOMORROW · A SHORT REEL', 590)
s.head([('Four things,', 'r'), ('gently paced.', 'i')], 750, size=130, step=148)
s.body('A quick look at the Today screen.', 1040)
s.phone('docs/images/app-iphone-today.png', 1150, crop_h=345)
s.save('01-reel-teaser.png')
print('built 01-reel-teaser.png')
