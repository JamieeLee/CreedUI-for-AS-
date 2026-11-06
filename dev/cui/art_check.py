#!/usr/bin/env python3
"""Every texture Creed UI ships is one the game can show: a BLP2, both sides a power of two and at
most 512 (1.21.8: a 1024-wide texture showed as a flat color in game).

    python3 art_check.py <addon dir>
"""
import glob
import os
import struct
import sys

bad = 0
for f in sorted(glob.glob(os.path.join(sys.argv[1], "Art", "*.blp"))):
    d = open(f, "rb").read(20)
    w, h = struct.unpack("<II", d[12:20])
    if d[:4] != b"BLP2" or w > 512 or h > 512 or w & (w - 1) or h & (h - 1):
        print("bad texture:", os.path.basename(f), w, "x", h)
        bad += 1
print("ART OK" if bad == 0 else "ART: %d bad" % bad)
sys.exit(1 if bad else 0)
