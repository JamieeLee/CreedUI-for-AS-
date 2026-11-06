#!/usr/bin/env python3
"""Creed UI's crit backdrops (original), drawn behind a critical hit's number, each a wide shape
in its own colors: Blood (a splatter with droplets), Fire (a burst of flames), Frost (an ice star),
Arcane (a ring of runes), Holy (a sunburst), Shadow (a curl of smoke). BLP2 + PNG, 256x128.

    python3 make_art20.py <blp dir> <png dir>
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
W, H, SS = 256, 128, 3
rng = np.random.default_rng(7)


def write_blp(name, rgba):
    h, w, _ = rgba.shape
    a8 = np.clip(np.round(rgba * 255), 0, 255).astype(np.uint8)
    head = b"BLP2" + struct.pack("<I", 1) + bytes([3, 8, 8, 0]) + struct.pack("<II", w, h)
    head += struct.pack("<16I", *([1172] + [0] * 15)) + struct.pack("<16I", *([w * h * 4] + [0] * 15))
    head += b"\x00" * 1024
    with open(os.path.join(OUT_BLP, name + ".blp"), "wb") as f:
        f.write(head + a8[:, :, [2, 1, 0, 3]].tobytes())
    Image.fromarray(a8, "RGBA").save(os.path.join(OUT_PNG, name + ".png"))


# a grid in the picture's own units: x from -2 to 2, y from -1 to 1 (so a unit is square)
xs = (np.arange(W * SS) + 0.5) / (W * SS) * 4 - 2
ys = (np.arange(H * SS) + 0.5) / (H * SS) * 2 - 1
x, y = np.meshgrid(xs, ys)
r = np.sqrt(x * x + y * y)
ang = np.arctan2(y, x)
px = 4.0 / (W * SS)


def cover(sdf, soft=1.0):
    return np.clip(0.5 - sdf / (px * soft), 0, 1)


def noise(scale, seed):
    g = np.random.default_rng(seed).standard_normal((H * SS, W * SS))
    n = ndimage.gaussian_filter(g, scale * SS)
    return n / (np.abs(n).max() + 1e-9)


def blur(m, k):
    return ndimage.gaussian_filter(m, k * SS)


def finish(name, col, alpha):
    """down to size with premultiplied averaging, so edges stay clean"""
    pc = col * alpha[..., None]
    pc = pc.reshape(H, SS, W, SS, 3).mean(axis=(1, 3))
    a = alpha.reshape(H, SS, W, SS).mean(axis=(1, 3))
    with np.errstate(invalid="ignore", divide="ignore"):
        c = np.where(a[..., None] > 1e-5, pc / a[..., None], 0)
    write_blp(name, np.dstack([np.clip(c, 0, 1), np.clip(a, 0, 1)]))


def mix(a, b, t):
    t = np.clip(t, 0, 1)[..., None]
    return np.array(a) * (1 - t) + np.array(b) * t


def blood():
    # a wide splatter: a lumpy body, longer streaks to the sides, and droplets flung round it
    rr = np.sqrt((x / 1.55) ** 2 + (y / 0.62) ** 2)
    body = rr - 0.82 - 0.16 * noise(5, 1) - 0.07 * noise(2, 2)
    m = cover(body * 0.4, 3)
    for k in range(9):
        a = rng.uniform(-np.pi, np.pi)
        L = rng.uniform(0.2, 0.55)
        cx, cy = np.cos(a) * 1.25, np.sin(a) * 0.5
        dx, dy = x - cx, y - cy
        along = dx * np.cos(a) + dy * np.sin(a)
        across = -dx * np.sin(a) + dy * np.cos(a)
        streak = np.sqrt((along / L) ** 2 + (across / 0.05) ** 2) - 1
        m = np.maximum(m, cover(streak * 0.05, 2))
    for k in range(26):
        a = rng.uniform(-np.pi, np.pi)
        d = rng.uniform(1.0, 1.45)
        cx, cy = np.cos(a) * d * 1.55, np.sin(a) * d * 0.62
        s = rng.uniform(0.025, 0.07)
        m = np.maximum(m, cover(np.sqrt((x - cx) ** 2 + (y - cy) ** 2) - s))
    shade = blur(m, 2.5)
    col = mix([0.30, 0.0, 0.02], [0.78, 0.04, 0.06], shade)
    # a wet sheen toward the top
    col = col + np.clip(blur(m, 1) - blur(m, 4), 0, 1)[..., None] * np.array([0.6, 0.15, 0.15]) * np.clip(-y + 0.2, 0, 1)[..., None]
    finish("NumBlood", np.clip(col, 0, 1), m * 0.92)


def fire():
    # tongues of flame licking out from a hot heart, wider than tall, leaning upward
    flick = 0.35 + 0.25 * np.abs(np.sin(ang * 7 + 0.4)) + 0.2 * np.abs(np.sin(ang * 13 + 1.1)) + 0.15 * noise(3, 3)
    up = np.clip(-y, 0, 1) * 0.18
    rr = np.sqrt((x / 1.6) ** 2 + (y / 0.9) ** 2)
    m = cover((rr - (0.48 + flick * 0.36 + up)) * 0.3, 6)
    heat = np.clip(1 - rr / (0.52 + flick * 0.36 + up), 0, 1)
    col = mix([0.65, 0.08, 0.0], [1.0, 0.55, 0.05], heat * 1.3)
    col = mix(col, [1.0, 0.92, 0.55], np.clip(heat * 2 - 1, 0, 1))
    finish("NumFlame", col, m * np.clip(0.35 + heat, 0, 1) * 0.95)


def frost():
    # a star of ice shards: long points left and right, shorter ones between, a cold glow inside
    m = np.zeros_like(x)
    for k in range(12):
        a = k * np.pi / 6 + rng.uniform(-0.08, 0.08)
        L = (1.85 if k in (0, 6) else rng.uniform(0.6, 1.05))
        if k in (3, 9):
            L = 0.9
        along = x * np.cos(a) + y * np.sin(a)
        across = -x * np.sin(a) + y * np.cos(a)
        shard = np.where(along > 0, np.abs(across) - 0.11 * (1 - along / L), 1)
        m = np.maximum(m, cover(shard * 1.0, 1.5) * (along < L))
    glow = np.exp(-(x / 1.0) ** 2 - (y / 0.5) ** 2)
    m = np.clip(m * 0.9 + glow * 0.55, 0, 1)
    facet = 0.6 + 0.4 * np.sign(np.sin(ang * 12))
    col = mix([0.20, 0.45, 0.85], [0.80, 0.95, 1.0], np.clip(glow * 0.8 + facet * 0.25, 0, 1))
    finish("NumFrost", col, m * 0.85)


def arcane():
    # a ring of violet light with rune ticks round it and a soft heart
    rr = np.sqrt((x / 1.75) ** 2 + (y / 0.86) ** 2)
    ring = np.exp(-((rr - 0.86) / 0.035) ** 2) + 0.5 * np.exp(-((rr - 0.72) / 0.02) ** 2)
    ticks = (np.abs(np.sin(ang * 18)) > 0.82) * np.exp(-((rr - 0.79) / 0.045) ** 2)
    runes = (np.abs(np.sin(ang * 6 + 0.5)) > 0.94) * cover((np.abs(rr - 0.79) - 0.06) * 0.2, 2)
    heart = np.exp(-(rr / 0.55) ** 2) * 0.55
    m = np.clip(ring + ticks + runes + heart, 0, 1)
    col = mix([0.45, 0.15, 0.85], [0.95, 0.75, 1.0], np.clip(ring + ticks, 0, 1))
    finish("NumArcane", col, m * 0.9)


def holy():
    # a sunburst: golden rays from a bright heart, the long ones to the sides
    rays = np.abs(np.cos(ang * 8)) ** 6 * 0.7 + np.abs(np.cos(ang * 16 + 0.2)) ** 10 * 0.4
    stretch = np.sqrt((x / 1.8) ** 2 + (y / 0.9) ** 2)
    m = np.clip(rays * np.clip(1 - stretch, 0, 1) * 1.8, 0, 1)
    heart = np.exp(-(stretch / 0.35) ** 2)
    m = np.clip(m + heart, 0, 1)
    col = mix([1.0, 0.70, 0.20], [1.0, 0.97, 0.80], np.clip(heart * 1.2 + rays * 0.3, 0, 1))
    finish("NumHoly", col, m * 0.9)


def shadow():
    # a curl of smoke: dark, soft, wider than tall, wisps rising off its top
    rr = np.sqrt((x / 1.7) ** 2 + (y / 0.75) ** 2)
    smoke = 1 - rr + 0.25 * noise(6, 5) + 0.12 * noise(2.5, 6) + np.clip(-y, 0, 1) * 0.15 * noise(3, 7)
    m = np.clip(smoke * 2.2, 0, 1)
    m = blur(m, 1.5)
    col = mix([0.04, 0.0, 0.08], [0.32, 0.12, 0.45], np.clip(0.5 + 0.8 * noise(4, 8), 0, 1) * np.clip(m, 0, 1))
    finish("NumShadow", col, np.clip(m, 0, 1) * 0.88)


blood()
fire()
frost()
arcane()
holy()
shadow()
print("wrote", OUT_BLP)
