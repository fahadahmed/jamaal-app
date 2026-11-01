#!/usr/bin/env python3
"""App Store banners: a headline, a line of context and a real screenshot in a card that bleeds off the bottom.
Run from the repo root: RAW=<dir with raw/iphone and raw/ipad captures> python3 assets/appstore/build.py
Captures come from the simulator (see README.md). FONT_DIR defaults to the ThreadsKit fonts inside a built Jamaal.app."""
import os, subprocess, tempfile, pathlib
from concurrent.futures import ThreadPoolExecutor

FONT_DIR = os.environ.get('FONT_DIR', '/Applications/Jamaal.app/Contents/Resources/ThreadsKit_ThreadsTokens.bundle/Contents/Resources')
R, I = f'{FONT_DIR}/FrauncesDisplay-Regular.ttf', f'{FONT_DIR}/FrauncesDisplay-Italic.ttf'
H, M = f'{FONT_DIR}/HankenGrotesk-Regular.ttf', f'{FONT_DIR}/JetBrainsMono-Medium.ttf'
BG, INK, ACCENT, RULE = '#EFF4F0', '#0A3A53', '#1F6A58', '#B9CBC3'
HERE = pathlib.Path(__file__).resolve().parent
RAW = pathlib.Path(os.environ['RAW'])
TMP = pathlib.Path(tempfile.mkdtemp())


def magick(*a):
    subprocess.run(['magick', *map(str, a)], check=True)


def card(src, width, radius, tag):
    """The screenshot as a rounded card with an outline and a soft shadow."""
    path = TMP / f'card-{tag}.png'
    h = int(subprocess.check_output(['magick', 'identify', '-format', '%h', src]).decode() or 0)
    w0 = int(subprocess.check_output(['magick', 'identify', '-format', '%w', src]).decode())
    h = int(h * width / w0)
    w1, h1, b = width - 1, h - 1, max(4, width // 260)
    magick(src, '-filter', 'Lanczos', '-resize', f'{width}x',
           '(', '+clone', '-alpha', 'extract', '-fill', 'black', '-colorize', '100', '-fill', 'white',
           '-draw', f'roundrectangle 0,0 {w1},{h1} {radius},{radius}', ')',
           '-alpha', 'off', '-compose', 'CopyOpacity', '-composite',
           '(', '-size', f'{width}x{h}', 'xc:none', '-fill', 'none', '-stroke', RULE, '-strokewidth', b,
           '-draw', f'roundrectangle {b//2},{b//2} {w1-b//2},{h1-b//2} {radius},{radius}', ')', '-compose', 'Over', '-composite',
           '(', '+clone', '-background', INK, '-shadow', '30x30+0+0', ')', '+swap',
           '-background', 'none', '-layers', 'merge', '+repage', path)
    return path


def banner(spec, W, H_, k, out):
    """k scales the type: 1.0 is the iPhone 6.9" canvas."""
    name, label, lines, sub, src, shot_w, shot_y = spec
    s = lambda v: int(v * k)
    a = ['-size', f'{W}x{H_}', f'xc:{BG}']
    m = s(100)
    a += ['-font', M, '-pointsize', s(40), '-kerning', s(7), '-fill', ACCENT, '-annotate', f'+{m}+{s(210)}', label, '-kerning', 0]
    y, size = s(400), s(150)
    for text, style in lines:
        a += ['-font', R if style == 'r' else I, '-pointsize', size, '-fill', INK if style == 'r' else ACCENT,
              '-annotate', f'+{m - s(4)}+{y}', text]
        y += int(size * 1.1)
    sub_png = TMP / f'sub-{name}.png'
    magick('-size', f'{W - 2*m}x', '-background', 'none', '-fill', INK, '-font', H, '-pointsize', s(54),
           '-interline-spacing', s(14), f'caption:{sub}', sub_png)
    a += [sub_png, '-geometry', f'+{m}+{y + s(10)}', '-composite']
    c = card(src, s(shot_w), s(120), f'{name}-{W}')
    a += [c, '-geometry', f'+{(W - s(shot_w)) // 2}+{s(shot_y)}', '-composite']
    magick(*a, '-alpha', 'off', out)
    print('built', out.relative_to(HERE))


IPHONE = [  # name, label, headline lines, context, capture, card width, card y   (1320x2868)
    ('01-today', 'TODAY', [('Four things,', 'r'), ('gently paced.', 'i')], 'One list for the whole day, sized to the energy you have.', 'today', 1060, 900),
    ('02-night-planning', 'NIGHT PLANNING', [('Tomorrow,', 'r'), ('sorted tonight.', 'i')], 'Five calm steps close today and set up tomorrow.', 'plan-review', 1060, 900),
    ('03-focus', 'FOCUS', [('One task,', 'r'), ('full attention.', 'i')], 'A timer and a checklist. Nothing else on screen.', 'focus', 1060, 900),
    ('04-habits', 'HABITS', [('Measured in weeks,', 'r'), ('not streaks.', 'i')], 'A missed day is just a lighter square, never a failure.', 'habits', 1060, 900),
    ('05-wellbeing', 'WELLBEING', [('A gentle read', 'r'), ('on your week.', 'i')], 'Notices when something slips and suggests a smaller step.', 'wellbeing', 1060, 900),
    ('06-add', 'CAPTURE', [('Add it in', 'r'), ('seconds.', 'i')], 'Effort, how much it matters, and when. That is all.', 'add', 1060, 900),
]
IPAD = [  # 2064x2752
    ('01-today', 'TODAY', [('One list.', 'r'), ('Just today.', 'i')], 'Pick a task and see its details beside the list.', 'today-task', 1360, 880),
    ('02-night-planning', 'NIGHT PLANNING', [('Plan tomorrow', 'r'), ('before you sleep.', 'i')], 'Review the day, carry things forward, check the load.', 'plan-review', 1360, 880),
    ('03-wellbeing', 'WELLBEING', [('A calm read', 'r'), ('on your week.', 'i')], 'No scores to chase. Just what is worth a second look.', 'wellbeing', 1360, 880),
    ('04-habits', 'HABITS', [('Measured in weeks,', 'r'), ('not streaks.', 'i')], 'See the shape of a habit, not whether you broke a chain.', 'habits', 1360, 880),
    ('05-add', 'CAPTURE', [('Add it in', 'r'), ('seconds.', 'i')], 'Effort, how much it matters, and when. That is all.', 'add', 1360, 880),
]

jobs = []
for dev, specs, (W, Ht), k in (('iphone-6.9', IPHONE, (1320, 2868), 1.0), ('ipad-13', IPAD, (2064, 2752), 1.25)):
    (HERE / dev).mkdir(exist_ok=True)
    folder = 'iphone' if dev.startswith('iphone') else 'ipad'
    for sp in specs:
        sp = (*sp[:4], RAW / 'raw' / folder / f'{sp[4]}.png', *sp[5:])
        jobs.append((sp, W, Ht, k, HERE / dev / f'{sp[0]}.png'))
with ThreadPoolExecutor(4) as ex:
    list(ex.map(lambda j: banner(*j), jobs))
