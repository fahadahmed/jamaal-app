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

# ---- post 7: Four things, gently paced (reel, 1080x1920, 9.5 s, no audio) ----
from concurrent.futures import ThreadPoolExecutor
RW, RH, FPS, DUR = 1080, 1920, 30, 9.5
SRC = 'docs/images/app-iphone-today.png'
FR = TMP / 'frames'; FR.mkdir()


def text_layer(name, text, font, size, color, kerning=0):
    path = TMP / f'{name}.png'
    magick('-size', f'{RW}x{int(size * 1.4)}', 'xc:none', '-font', font, '-pointsize', size, '-kerning', kerning,
           '-fill', color, '-annotate', f'+88+{int(size * 1.05)}', text, path)
    return path


clamp = lambda x: max(0.0, min(1.0, x))
ease_out = lambda x: 1 - (1 - clamp(x)) ** 3
ease_in = lambda x: clamp(x) ** 3
ramp = lambda t, a, b: clamp((t - a) / (b - a))

label = text_layer('label', 'THE TODAY SCREEN', M, 32, ACCENT, 5)
line1 = text_layer('l1', 'Four things,', R, 120, INK)
line2 = text_layer('l2', 'gently paced.', I, 120, ACCENT)
card = phone(SRC)
ic = icon(240, 54)
end1 = text_layer('e1', 'One list.', R, 110, INK)
end2 = text_layer('e2', 'Just today.', I, 110, ACCENT)
end3 = text_layer('e3', 'Beautifully ordered.', H, 52, INK)
end4 = text_layer('e4', 'The beta is open · link in bio', H, 46, ACCENT)


def frame(i):
    t = i / FPS
    layers = []  # (path, x, y, alpha)
    head_out = 1 - ramp(t, 7.0, 7.6)
    layers.append((label, 0, 250, ramp(t, 0.2, 0.7) * head_out))
    layers.append((line1, 0, 300 + 40 * (1 - ease_out(ramp(t, 0.3, 0.9))), ramp(t, 0.3, 0.9) * head_out))
    layers.append((line2, 0, 440 + 40 * (1 - ease_out(ramp(t, 0.9, 1.5))), ramp(t, 0.9, 1.5) * head_out))
    py = 1920 - 1300 * ease_out(ramp(t, 2.0, 3.2)) + 1300 * ease_in(ramp(t, 6.8, 7.8))
    layers.append((card, 140 - 0, 0 + py, 1.0 if py < 1900 else 0))
    e = ramp(t, 7.6, 8.6)
    layers.append((ic, 88, 470 + 30 * (1 - ease_out(e)), e))
    layers.append((end1, 0, 800 + 30 * (1 - ease_out(e)), e))
    layers.append((end2, 0, 930 + 30 * (1 - ease_out(e)), e))
    layers.append((end3, 0, 1090 + 30 * (1 - ease_out(e)), e))
    layers.append((end4, 0, 1240, ramp(t, 8.1, 9.0)))
    args = ['-size', f'{RW}x{RH}', f'xc:{BG}']
    for path, x, y, a in layers:
        if a <= 0.002:
            continue
        geo = f'{int(x):+d}{int(y):+d}'
        if a < 0.998:
            args += ['(', path, '-alpha', 'set', '-channel', 'A', '-evaluate', 'multiply', f'{a:.3f}', '+channel', ')']
        else:
            args += [path]
        args += ['-geometry', geo, '-composite']
    magick(*args, '-depth', '8', '-alpha', 'off', FR / f'frame_{i:04d}.png')


n = int(DUR * FPS)
with ThreadPoolExecutor(8) as ex:
    list(ex.map(frame, range(n)))
print('frames', n)
subprocess.run(['swift', str(OUT / 'encode.swift'), str(FR), str(OUT / '01-four-things.mp4'), str(FPS)], check=True)
magick(FR / f'frame_{int(4.2 * FPS):04d}.png', OUT / 'poster.png')
