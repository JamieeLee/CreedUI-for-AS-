#!/usr/bin/env python3
"""Creed UI's icon (original), for the addon's page and listings: a bronze-gold ring beveled like
the minimap button's bezel around a disc of dark glass, four small gold diamonds on the ring (the
panels' corners), and the C (from the addon's own serif, Letters.ttf from Lora) raised in gold with
a red gem held in its bowl, as the boss timer's. Writes icon.png at 512, 256 and 128 px.

    python3 make_icon.py <out dir>
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = sys.argv[1] if len(sys.argv) > 1 else "."
os.makedirs(OUT, exist_ok=True)
N, SS = 512, 3
BIG = N * SS
HERE = os.path.dirname(os.path.abspath(__file__))
FONT = os.path.join(HERE, "..", "..", "CreedUI", "Fonts", "Letters.ttf")

# the golds of the user's bar picture (CLAUDE.md): panel metal, titles, rims
METAL = np.array([0.95, 0.79, 0.44])
TITLE = np.array([0.98, 0.85, 0.52])
RIM = np.array([0.91, 0.70, 0.30])
DARK_BRONZE = np.array([0.36, 0.24, 0.10])
GEM = np.array([0.95, 0.27, 0.20])

xs = (np.arange(BIG) + 0.5) / BIG * 2 - 1
x, y = np.meshgrid(xs, xs)
r = np.sqrt(x * x + y * y)
px = 2.0 / BIG


def cover(sdf, soft=1.0):
    return np.clip(0.5 - sdf / (px * soft), 0, 1)


def blur(m, k):
    im = Image.fromarray(np.clip(m * 255, 0, 255).astype(np.uint8), "L")
    return np.asarray(im.filter(ImageFilter.GaussianBlur(k * SS)), dtype=np.float64) / 255.0


def shade(height, light=(-0.45, -0.7, 0.55), strength=60.0, spec_pow=24):
    """diffuse and specular light on a height field, lit from the top left"""
    gy, gx = np.gradient(height)
    nx, ny, nz = -gx * strength * SS, -gy * strength * SS, np.ones_like(height)
    n = np.sqrt(nx * nx + ny * ny + nz * nz)
    nx, ny, nz = nx / n, ny / n, nz / n
    L = np.array(light) / np.linalg.norm(light)
    diff = np.clip(nx * L[0] + ny * L[1] + nz * L[2], 0, 1)
    hx, hy, hz = L[0], L[1], L[2] + 1
    hn = np.sqrt(hx * hx + hy * hy + hz * hz)
    spec = np.clip((nx * hx + ny * hy + nz * hz) / hn, 0, 1) ** spec_pow
    return diff, spec


def metal(diff, spec, base=METAL):
    """gold: dark bronze in the shadow, the bar's metal in the light, a pale glint on top"""
    t = np.clip(diff, 0, 1)[..., None]
    col = DARK_BRONZE * (1 - t) + base * t
    return np.clip(col + spec[..., None] * np.array([1.0, 0.95, 0.80]) * 0.65, 0, 1)


def over(dst_c, dst_a, src_c, src_a):
    a = src_a[..., None]
    out_a = src_a + dst_a * (1 - src_a)
    c = (src_c * a + dst_c * dst_a[..., None] * (1 - a)) / np.maximum(out_a[..., None], 1e-6)
    return c, out_a


col = np.zeros((BIG, BIG, 3))
alpha = np.zeros((BIG, BIG))

# a soft shadow under the whole medallion
col, alpha = over(col, alpha, np.zeros((BIG, BIG, 3)), blur(cover(r - 0.95), 6) * 0.55)

# the ring: a rounded band, beveled, its outer and inner lips catching the light
R_OUT, R_IN = 0.93, 0.74
band = cover(r - R_OUT) * cover(R_IN - r)
mid, half = (R_OUT + R_IN) / 2, (R_OUT - R_IN) / 2
h_ring = np.sqrt(np.clip(1 - ((r - mid) / half) ** 2, 0, 1)) * band
d, s = shade(blur(h_ring, 1.2) * 0.06)
ring = metal(d * 0.85 + 0.12, s)
# fine engraved grooves near both lips
groove = np.exp(-((r - (R_OUT - 0.035)) / 0.006) ** 2) + np.exp(-((r - (R_IN + 0.035)) / 0.006) ** 2)
ring = ring * (1 - 0.45 * np.clip(groove, 0, 1))[..., None]
col, alpha = over(col, alpha, ring, band)

# the face: dark glass, a little lighter toward the top left, with a faint gold rim glow inside
face = cover(r - R_IN + 0.004)
glass = np.array([0.045, 0.045, 0.06]) + np.array([0.06, 0.055, 0.05]) * np.clip(0.5 - (x + y) * 0.45, 0, 1)[..., None]
inner = np.exp(-((R_IN - r) / 0.06) ** 2) * face
glass = glass + RIM * 0.35 * inner[..., None]
col, alpha = over(col, alpha, glass, face)
# a curved sheen across the upper glass
fade = np.clip((-y - 0.0) / 0.55, 0, 1) ** 1.5  # strongest at the top, gone by the middle
sheen = cover(np.sqrt((x + 0.15) ** 2 + (y + 0.95) ** 2) - 1.15, 30) * face * fade
col, alpha = over(col, alpha, np.ones((BIG, BIG, 3)), sheen * 0.07)

# four diamonds on the ring, at the corners of a square (the panels' corner gems)
for ang in (45, 135, 225, 315):
    a = np.radians(ang)
    cx, cy = np.cos(a) * mid, np.sin(a) * mid
    dx, dy = x - cx, y - cy
    sdf = (np.abs(dx) + np.abs(dy)) / 0.075 - 1
    dm = cover(sdf * 0.075)
    facet = np.where(dy < 0, np.where(dx < 0, 1.0, 0.8), np.where(dx < 0, 0.6, 0.42))
    edge = np.clip(np.exp(-(sdf / 0.08) ** 2), 0, 1)
    dc = TITLE[None, None, :] * (facet * (1 - 0.35 * edge))[..., None]
    col, alpha = over(col, alpha, np.zeros((BIG, BIG, 3)), blur(dm, 1.5) * 0.6)
    col, alpha = over(col, alpha, dc, dm)

# the C, raised in gold, with its shadow under it
im = Image.new("L", (BIG, BIG), 0)
dr = ImageDraw.Draw(im)
font = ImageFont.truetype(FONT, int(BIG * 0.70))
l, t, rr, b = dr.textbbox((0, 0), "C", font=font)
dr.text((BIG * 0.5 - (l + rr) * 0.5 - BIG * 0.02, BIG * 0.5 - (t + b) * 0.5 - BIG * 0.01), "C", fill=255, font=font)
letter = np.asarray(im, dtype=np.float64) / 255.0
shadow = blur(np.roll(np.roll(letter, int(0.012 * BIG), axis=0), int(0.008 * BIG), axis=1), 4)
col, alpha = over(col, alpha, np.zeros((BIG, BIG, 3)), np.clip(shadow * 1.2, 0, 0.8))
h_letter = blur(letter, 2.2) * letter
d, s = shade(h_letter * 0.05)
gold = metal(d * 0.9 + 0.1, s, TITLE)
col, alpha = over(col, alpha, gold, letter)

# the red gem in the C's bowl: a cut diamond with its own glow
gx0, gy0 = 0.10, 0.0
dx, dy = x - gx0, y - gy0
gsdf = np.abs(dx) / 0.10 + np.abs(dy) / 0.145 - 1
gm = cover(gsdf * 0.1)
glow = np.exp(-((dx / 0.22) ** 2 + (dy / 0.26) ** 2)) * face
col, alpha = over(col, alpha, GEM[None, None, :] * np.ones((BIG, BIG, 3)), glow * 0.28)
facet = np.where(dy < 0, np.where(dx < 0, 1.0, 0.78), np.where(dx < 0, 0.58, 0.40))
gcol = GEM[None, None, :] * facet[..., None] + np.array([1.0, 0.85, 0.75]) * (np.exp(-((dx + 0.03) ** 2 + (dy + 0.05) ** 2) / 0.0006))[..., None] * 0.8
rim = np.clip(np.exp(-(gsdf / 0.07) ** 2), 0, 1)
gcol = gcol * (1 - rim[..., None]) + RIM * rim[..., None]
col, alpha = over(col, alpha, np.clip(gcol, 0, 1), gm)

# down to size, alpha kept clean
rgba = np.dstack([col * alpha[..., None], alpha])
img = Image.fromarray(np.clip(rgba * 255, 0, 255).astype(np.uint8), "RGBA")
img = img.resize((N, N), Image.LANCZOS)
arr = np.asarray(img).astype(np.float64) / 255.0
a = arr[..., 3:4]
with np.errstate(invalid="ignore", divide="ignore"):
    c = np.where(a > 1e-4, arr[..., :3] / a, 0)
img = Image.fromarray(np.clip(np.dstack([c, a]) * 255, 0, 255).astype(np.uint8), "RGBA")
for size in (512, 256, 128):
    img.resize((size, size), Image.LANCZOS).save(os.path.join(OUT, "icon-%d.png" % size))
print("wrote", OUT)
