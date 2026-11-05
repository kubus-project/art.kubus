"""Shrinks ../social-preview.png to fit the ~400 KB budget without changing its size or palette type.

Drops the two lowest bits of each RGB channel (rounded to the bin centre). A 256-colour palette was tried first and
banded the photo in the artwork card; this stays full colour (mean error about 1.2 of 255) and lands near 360 KB.
"""
from PIL import Image
import os
p = os.path.join(os.path.dirname(__file__), '..', 'social-preview.png')
im = Image.open(p).convert('RGB')
bits = 2
mask = 0xFF ^ ((1 << bits) - 1)
lut = [min(255, (v & mask) + (1 << (bits - 1))) for v in range(256)]
out = im.point(lut * 3)
out.save(p, optimize=True)
print(os.path.getsize(p), 'bytes', Image.open(p).size)
