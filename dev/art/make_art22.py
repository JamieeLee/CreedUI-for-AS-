#!/usr/bin/env python3
"""Creed UI's class glass (original, 1.21.8, asked for: "a design with the colour of the class instead
of pitch black"): the skill bar's inside, in grey to be tinted in each class's color, as the panel's
fill. Darker toward its rails, a soft light along its middle, a faint flowing filigree of two
interlaced ribbons with little diamonds where they cross, and a brushed sheen. BLP2 + PNG, 512x64
(the bar's own shape, about 9 to 1; 512 wide at most: the game shows nothing for a 1024-wide texture).

    python3 make_art22.py <blp dir> <png dir>
"""
import os
import struct
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

OUT_BLP, OUT_PNG = sys.argv[1], sys.argv[2]
os.makedirs(OUT_BLP, exist_ok=True)
os.makedirs(OUT_PNG, exist_ok=True)
W, H, SS = 512, 64, 4


def write_blp(name, rgba):
    h, w, _ = rgba.shape
    a8 = np.clip(np.round(rgba * 255), 0, 255).astype(np.uint8)
    head = b"BLP2" + struct.pack("<I", 1) + bytes([3, 8, 8, 0]) + struct.pack("<II", w, h)
    head += struct.pack("<16I", *([1172] + [0] * 15)) + struct.pack("<16I", *([w * h * 4] + [0] * 15))
    head += b"\x00" * 1024
    with open(os.path.join(OUT_BLP, name + ".blp"), "wb") as f:
        f.write(head + a8[:, :, [2, 1, 0, 3]].tobytes())
    Image.fromarray(a8, "RGBA").save(os.path.join(OUT_PNG, name + ".png"))


x = (np.arange(W * SS) + 0.5) / (W * SS)          # 0..1 along
y = (np.arange(H * SS) + 0.5) / (H * SS)          # 0..1 down
X, Y = np.meshgrid(x, y)
v = np.abs(Y - 0.5) * 2                           # 0 middle, 1 at the rails
g = 0.34 - 0.20 * v ** 1.6                        # darker toward the rails
g = g + 0.10 * np.exp(-(v / 0.35) ** 2)           # a soft light along the middle
# the brushed sheen: fine streaks along it
rng = np.random.default_rng(22)
streak = ndimage.gaussian_filter(rng.standard_normal((H * SS, W * SS)), (0.6 * SS, 14 * SS))
g = g + 0.035 * streak / (np.abs(streak).max() + 1e-9)
# the filigree: two ribbons weaving along the bar, thin and faint, little diamonds where they cross
px = 1.0 / (H * SS)
period = 0.0625                                    # 16 waves along the bar
phase = X / period * 2 * np.pi
fil = np.zeros_like(X)
for sgn in (1, -1):
    yc = 0.5 + sgn * 0.26 * np.sin(phase)
    d = np.abs(Y - yc) * (H * SS) / SS            # distance in texture pixels
    fil = np.maximum(fil, np.exp(-(d / 0.9) ** 2))
    yc2 = 0.5 + sgn * 0.22 * np.sin(phase)
    d2 = np.abs(Y - yc2) * (H * SS) / SS
    fil = np.maximum(fil, 0.5 * np.exp(-(d2 / 0.6) ** 2))
# diamonds where the ribbons cross (sin = 0), on the middle line
cx = np.round(X / (period / 2)) * (period / 2)
dd = np.abs(X - cx) * W * 4 + np.abs(Y - 0.5) * H * 1.0
fil = np.maximum(fil, np.clip(1 - dd / 3.2, 0, 1))
g = g + 0.09 * fil * (1 - 0.5 * v)
g = np.clip(g, 0, 1)
g = g.reshape(H, SS, W, SS).mean(axis=(1, 3))
write_blp("PanelGlass", np.dstack([g, g, g, np.ones_like(g)]))
print("wrote", OUT_BLP, "mean", round(float(g.mean()), 3))
