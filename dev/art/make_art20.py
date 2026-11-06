#!/usr/bin/env python3
"""Creed UI's crit backdrops (original), drawn behind a critical hit's number, each a wide burst in
its own colors with a bright heart: Fire (flame tongues and embers), Frost (an ice snowflake with
sparkles), Arcane (a swirling vortex with sparks), Holy (a sunburst), Shadow (tendrils from a void,
a violet rim), Storm (forked lightning). BLP2 + PNG, 256x128. (1.20.4 redrew them; Blood is gone.)

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



def sparks(n, seed, rmin, rmax, size, sx=1.7, sy=0.8):
    """small bright points flung round the heart"""
    g = np.random.default_rng(seed)
    m = np.zeros_like(x)
    for k in range(n):
        a = g.uniform(-np.pi, np.pi)
        d = g.uniform(rmin, rmax)
        cx, cy = np.cos(a) * d * sx, np.sin(a) * d * sy
        s = g.uniform(size * 0.5, size)
        m = np.maximum(m, np.exp(-((x - cx) ** 2 + (y - cy) ** 2) / (s * s)))
    return m


def stretch(sx=1.75, sy=0.85):
    return np.sqrt((x / sx) ** 2 + (y / sy) ** 2)


def fire():
    rr = stretch(1.7, 0.85)
    # sharp tongues: the burst's edge leaps out at many angles, longer upward
    edge = 0.42 + 0.3 * np.abs(np.sin(ang * 9 + 0.3)) ** 3 + 0.18 * np.abs(np.sin(ang * 17 + 1.7)) ** 4 \
        + 0.1 * noise(2.5, 11) + np.clip(-np.sin(ang), 0, 1) * 0.12
    body = np.clip(1 - rr / edge, 0, 1)
    m = np.clip(body * 2.4, 0, 1)
    heat = body ** 0.7
    col = mix([0.55, 0.05, 0.0], [1.0, 0.45, 0.03], heat * 1.6)
    col = mix(col, [1.0, 0.95, 0.70], np.clip(heat * 2.4 - 1.3, 0, 1))
    em = sparks(26, 12, 0.75, 1.15, 0.035)
    col = mix(col, [1.0, 0.75, 0.25], em)
    m = np.clip(np.maximum(m, em), 0, 1)
    finish("NumFlame", np.clip(col, 0, 1), m * 0.95)


def frost():
    m = np.zeros_like(x)
    # six-armed snowflake, stretched wide: each arm a tapering shard with two side barbs
    for k in range(6):
        a = k * np.pi / 3
        ca, sa = np.cos(a), np.sin(a)
        L = 1.0
        X, Y = x / 1.7, y / 0.85
        along = X * ca + Y * sa
        across = -X * sa + Y * ca
        arm = np.where((along > 0) & (along < L), np.abs(across) - 0.05 * (1 - along / L), 1)
        m = np.maximum(m, cover(arm * 0.45, 1.5))
        for t in (0.45, 0.7):
            for side in (-1, 1):
                b = a + side * 0.6
                bx, by = X - ca * t, Y - sa * t
                al = bx * np.cos(b) + by * np.sin(b)
                ac = -bx * np.sin(b) + by * np.cos(b)
                bl = 0.3 * (1.2 - t)
                barb = np.where((al > 0) & (al < bl), np.abs(ac) - 0.03 * (1 - al / bl), 1)
                m = np.maximum(m, cover(barb * 0.45, 1.5))
    glow = np.exp(-(stretch(1.0, 0.5)) ** 2 * 2.0)
    sp = sparks(30, 21, 0.4, 1.1, 0.03)
    a_ = np.clip(m * 0.95 + glow * 0.6 + sp, 0, 1)
    col = mix([0.25, 0.55, 0.95], [0.85, 0.97, 1.0], np.clip(glow * 0.9 + m * 0.35 + sp, 0, 1))
    finish("NumFrost", col, a_ * 0.92)


def arcane():
    # a vortex: spiral arms sweeping round a white-violet heart, sparks flung out on the swirl
    rr = stretch(1.7, 0.85)
    swirl = np.sin(ang * 3 - rr * 9.0)
    arms = np.clip((swirl - 0.15) / 0.85, 0, 1) ** 1.5 * np.clip(1 - rr / 1.0, 0, 1)
    heart = np.exp(-(rr / 0.28) ** 2)
    halo = np.exp(-(rr / 0.6) ** 2) * 0.5
    sp = sparks(28, 31, 0.6, 1.1, 0.032)
    m = np.clip(arms * 1.3 + heart + halo + sp, 0, 1)
    col = mix([0.40, 0.08, 0.80], [0.85, 0.40, 1.0], np.clip(arms + halo, 0, 1))
    col = mix(col, [1.0, 0.92, 1.0], np.clip(heart * 1.4 + sp, 0, 1))
    finish("NumArcane", np.clip(col, 0, 1), m * 0.92)


def holy():
    # a sunburst: golden rays from a bright heart, the long ones to the sides, a soft halo
    rays = np.abs(np.cos(ang * 8)) ** 6 * 0.75 + np.abs(np.cos(ang * 16 + 0.2)) ** 10 * 0.45
    rr = stretch(1.8, 0.9)
    m = np.clip(rays * np.clip(1 - rr, 0, 1) * 2.0, 0, 1)
    heart = np.exp(-(rr / 0.33) ** 2)
    halo = np.exp(-(rr / 0.6) ** 2) * 0.35
    m = np.clip(m + heart + halo, 0, 1)
    col = mix([1.0, 0.72, 0.22], [1.0, 0.98, 0.85], np.clip(heart * 1.3 + rays * 0.35, 0, 1))
    finish("NumHoly", col, m * 0.95)


def shadow():
    # a void: a black heart with dark tendrils curling out of it, lit from behind by a violet glow
    rr = stretch(1.7, 0.8)
    curl = np.sin(ang * 7 + rr * 5 + 1.3 * noise(4, 41))
    tend = np.clip((curl - 0.25) / 0.75, 0, 1) * np.clip(1 - rr / 1.0, 0, 1)
    core = np.clip(1 - rr / 0.5, 0, 1) ** 0.6
    dark = np.clip(core * 1.8 + tend * 1.6, 0, 1)
    glow = np.exp(-(rr / 0.75) ** 2) * 0.95 + sparks(18, 43, 0.6, 1.0, 0.03) * 0.8
    rim = np.clip(blur(dark, 2.0) - blur(dark, 0.6), 0, 1) * 4.0
    col = mix([0.55, 0.20, 0.85], [0.85, 0.55, 1.0], np.clip(glow, 0, 1))   # the light behind
    col = mix(col, [0.03, 0.0, 0.05], dark)                                   # the void over it
    col = mix(col, [0.90, 0.60, 1.0], np.clip(rim * (1 - core), 0, 1))       # its edges lit
    a_ = np.clip(np.maximum(dark, glow) + rim * 0.5, 0, 1)
    finish("NumShadow", np.clip(col, 0, 1), a_ * 0.93)


def storm():
    # forked lightning crackling out from a bright heart, blue-white, with a static haze
    g = np.random.default_rng(51)
    m = np.zeros_like(x)
    for k in range(9):
        a = k * 2 * np.pi / 9 + g.uniform(-0.25, 0.25)
        px0, py0 = 0.0, 0.0
        L = g.uniform(0.75, 1.05)
        steps = 7
        for s_ in range(steps):
            t = (s_ + 1) / steps * L
            jit = g.uniform(-0.35, 0.35)
            nx, ny = np.cos(a + jit) * t * 1.7, np.sin(a + jit) * t * 0.85
            # a segment from (px0,py0) to (nx,ny)
            dx, dy = nx - px0, ny - py0
            ln = np.hypot(dx, dy) + 1e-9
            u = np.clip(((x - px0) * dx + (y - py0) * dy) / (ln * ln), 0, 1)
            d = np.hypot(x - (px0 + u * dx), y - (py0 + u * dy))
            w = 0.022 * (1 - s_ / steps) + 0.006
            m = np.maximum(m, np.exp(-(d / w) ** 2))
            px0, py0 = nx, ny
    glow = blur(m, 3.0) * 2.5
    heart = np.exp(-(stretch(1.0, 0.5) / 0.4) ** 2)
    a_ = np.clip(m + glow * 0.6 + heart, 0, 1)
    col = mix([0.25, 0.45, 1.0], [0.92, 0.97, 1.0], np.clip(m + heart, 0, 1))
    finish("NumStorm", np.clip(col, 0, 1), a_ * 0.95)


fire()
frost()
arcane()
holy()
shadow()
storm()
print("wrote", OUT_BLP)
