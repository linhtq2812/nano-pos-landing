"""Convert a screenshot to WebP for the landing page.

Usage: python3 tools/shots/to_webp.py IN.png OUT.webp [--crop x,y,w,h] [--width N]
"""
import argparse

from PIL import Image


def convert(src: str, dst: str, crop: str | None = None, width: int | None = None) -> None:
    im = Image.open(src).convert('RGB')
    if crop:
        x, y, w, h = (int(v) for v in crop.split(','))
        im = im.crop((x, y, x + w, y + h))
    if width and im.width > width:
        im = im.resize((width, round(im.height * width / im.width)), Image.LANCZOS)
    im.save(dst, 'WEBP', quality=82, method=6)


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('src'); ap.add_argument('dst')
    ap.add_argument('--crop'); ap.add_argument('--width', type=int)
    a = ap.parse_args()
    convert(a.src, a.dst, a.crop, a.width)
