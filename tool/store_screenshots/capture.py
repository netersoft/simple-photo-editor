"""Captures the raw screens for the Play Store screenshots, in one language.

Starts from a fresh install on the shared `test-phone` emulator (1080x2400)
with SystemUI demo mode on, and the demo photo in the device gallery (see
README.md). Tool labels move with the language, so they are found by their
text (macOS Vision), matched against assets/i18n/<lang>.i18n.json.

    python3 tool/store_screenshots/capture.py <out_dir> <lang>

Writes <out_dir>/<lang>/<screen>.png for the screens listed in config.json.
"""

import math
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from adb_ui import adb, find, labels, screen, tap, wait_until  # noqa: E402

PACKAGE = 'com.neteru.simplephotoeditor.dev'
LOCALES = {'en': 'en-US', 'fr': 'fr-FR'}
# The text added on the photo, typed with adb (ASCII only).
CAPTION = {'en': 'Golden hour', 'fr': 'Coucher de soleil'}


def type_text(text):
    for c in text:
        adb('input', 'text', '%s' if c == ' ' else c)
        time.sleep(0.08)


def drag(x1, y1, x2, y2, ms=900):
    adb('input', 'swipe', x1, y1, x2, y2, ms)
    time.sleep(1)


def draw_heart(cx, cy, r):
    """One continuous stroke, like a finger (adb's motionevent)."""
    pts = []
    for i in range(61):
        a = 2 * math.pi * i / 60
        x = 16 * math.sin(a) ** 3
        y = 13 * math.cos(a) - 5 * math.cos(2 * a) - 2 * math.cos(3 * a) - math.cos(4 * a)
        pts.append((round(cx + r * x), round(cy - r * y)))
    adb('input', 'motionevent', 'DOWN', *pts[0])
    for p in pts[1:]:
        adb('input', 'motionevent', 'MOVE', *p)
    adb('input', 'motionevent', 'UP', *pts[-1])
    time.sleep(1)


def black_bar(img):
    """The editor: black above the photo and around its tool bar."""
    return sum(img.getpixel((540, 260))) < 30 and sum(img.getpixel((300, 2300))) < 30


def capture(out, lang):
    out = Path(out) / lang
    out.mkdir(parents=True, exist_ok=True)
    t = labels(lang)
    e = t['editor']

    adb('pm', 'clear', PACKAGE)
    adb('pm', 'grant', PACKAGE, 'android.permission.READ_MEDIA_IMAGES')
    adb('cmd', 'locale', 'set-app-locales', PACKAGE, '--locales', LOCALES[lang])
    adb('monkey', '-p', PACKAGE, '-c', 'android.intent.category.LAUNCHER', '1')

    # 1. Home: six round buttons around the lens.
    gallery = find(t['gallery'], 30)
    time.sleep(1)
    screen().save(out / 'home.png')

    # Open the demo photo from the system photo picker (the only photo).
    tap(*gallery, 3)
    tap(178, 1404, 5)
    wait_until(black_bar, 'the editor')

    # 2. Filters: the "Dual tone" look, next to the untouched thumbnails.
    tap(*find(e['adjust']), 4)
    adb('input', 'swipe', 900, 1990, 200, 1990, 600)
    time.sleep(1.5)
    tap(*find(t['filters']['dualTone']), 2.5)
    screen().save(out / 'filters.png')
    tap(72, 206, 2)                                   # close without applying

    # 3. The brush: a white heart drawn in the sky.
    tap(*find(e['brush']), 2)
    tap(90, 1780, 0.5)                                # white
    adb('input', 'swipe', 284, 1990, 520, 1990, 400)  # a thicker line
    time.sleep(0.8)
    tap(540, 300, 1.5)                                # close the panel
    draw_heart(860, 760, 7)
    screen().save(out / 'brush.png')
    tap(*find(e['brush']), 1)                         # put the brush away

    # 4. Stickers: the panel.
    adb('input', 'swipe', 1000, 2220, 100, 2220, 600)  # scroll the tool bar
    time.sleep(1.2)
    tap(*find(e['sticker']), 2)
    screen().save(out / 'stickers.png')
    tap(406, 1926, 2)                                 # the sunglasses
    drag(540, 1272, 820, 1680)

    # A caption and an emoji.
    tap(*find(e['text']), 2)
    type_text(CAPTION[lang])
    tap(692, 1568, 0.8)                               # yellow
    tap(*find(t['done']), 2)
    drag(540, 1272, 540, 900)
    tap(*find(e['emoji']), 2)
    tap(864, 1472, 2)                                 # heart eyes
    drag(540, 1272, 220, 1580)
    drag(900, 1150, 980, 1230, 400)                   # a drag on the bare photo deselects
    wait_until(lambda img: img.getpixel((540, 2030))[0] < 200, 'the layers deselected')

    # 5. The edited photo.
    screen().save(out / 'editor.png')

    # 6. Saving opens the sharing screen.
    tap(1016, 206, 3)
    find(t['share'], 60)
    time.sleep(1)
    screen().save(out / 'share.png')

    # Leave the gallery as it was: the next language must open the demo
    # photo, not this edited copy (the picker lists the newest first).
    rows = subprocess.run(['adb', 'shell', 'content', 'query', '--uri', 'content://media/external/images/media',
                           '--projection', '_id:relative_path'], check=True, capture_output=True, text=True).stdout
    for row in rows.splitlines():
        if 'Simple Photo Editor' in row:
            adb('content', 'delete', '--uri', 'content://media/external/images/media/' + row.split('_id=')[1].split(',')[0])


if __name__ == '__main__':
    capture(sys.argv[1], sys.argv[2])
