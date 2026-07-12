#!/usr/bin/env python3
"""Convert harness .ppm screenshots to .png (2x scaled for readability)."""
import sys
from PIL import Image

for path in sys.argv[1:]:
    img = Image.open(path)
    img = img.resize((img.width * 2, img.height * 2), Image.NEAREST)
    out = path.rsplit(".", 1)[0] + ".png"
    img.save(out)
    print(out)
