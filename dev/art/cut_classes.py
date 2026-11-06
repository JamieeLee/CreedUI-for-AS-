#!/usr/bin/env python3
"""Creed UI's class looks for the skill bar, from the user's own picture of nine class bars
(source/class_bars.webp, 1740x606, made for them with an image generator; 1.21.5): for each class,

  PanelEmblem<Class>L  the emblem on the bar's left end, 512x256
  PanelEmblem<Class>R  the crest on its right end, 512x256
  PanelRail<Class>T/B  the bar's top and bottom rail lines, 64x16, stretched along it

and each bar's inside color (printed, for Core's theme table, as the panel glass's tint).

The emblems blend into the bar as in the picture: everything above and below the bar is kept whole
(daggers, wings, capes), and inside the bar's band the picture's own bar runs on past the emblem and
fades slowly out, over Creed UI's own bar, whose rails and glass are this picture's, so no seam shows.

Each bar is scaled so its rails are RAIL texture pixels apart; the anchor (the emblem's or crest's
middle across, on the line midway between the rails) is at ANCHOR_L / ANCHOR_R (texture pixels).

usage: cut_classes.py <source picture> <blp folder> <png folder> [art folder holding PanelFill.blp]"""
import os
import struct
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

SRC, OUT_BLP, OUT_PNG = sys.argv[1], sys.argv[2], sys.argv[3]
ART = sys.argv[4] if len(sys.argv) > 4 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "CreedUI", "Art")
os.makedirs(OUT_BLP, exist_ok=True)
os.makedirs(OUT_PNG, exist_ok=True)

TW, TH = 512, 256
RAIL = 110.0                        # texture pixels between the two rails' lines
ANCHOR_L, ANCHOR_R = 220, 292       # the emblem's and the crest's middle across (texture pixels)
# each bar: its class, its emblem's and crest's middles across (their rings fitted, about 42 px round),
# its top and bottom rails (picture px)
# and how far the bar runs clear from each middle before its first slot / after its last (picture px)
BARS = [
    ("Warrior", 145, 734, 50, 123, 95, 125), ("Hunter", 147, 720, 188, 260, 93, 111),
    ("Paladin", 980, 1558, 50, 123, 118, 97), ("Rogue", 985, 1560, 188, 260, 110, 100),
    ("Mage", 148, 721, 327, 399, 85, 111), ("Druid", 987, 1562, 327, 399, 113, 100),
    ("Shaman", 90, 517, 465, 536, 85, 69), ("Priest", 703, 1062, 465, 535, 72, 57),
    ("Warlock", 1232, 1626, 465, 536, 72, 65),
]
OUTER = {"ShamanR": 122, "PriestL": 122}
# emblems whose round reaches past the usual ring (picture px): the mage's rune circle (1.23.3, asked for)
RINGS = {"MageL": 60}   # how far out each piece reaches (texture px; else 140)
RING = 43                           # the emblems' and crests' rings' outer edge (picture px round them)
HALF_GAP = 68                       # half the space between rows (picture px): the neighbours cut away
BG = np.array([0.02, 0.02, 0.02])   # the picture's black


def write_blp(name, rgba):
    h, w, _ = rgba.shape
    a8 = np.clip(np.round(rgba * 255), 0, 255).astype(np.uint8)
    head = b"BLP2" + struct.pack("<I", 1) + bytes([3, 8, 8, 0]) + struct.pack("<II", w, h)
    head += struct.pack("<16I", *([1172] + [0] * 15)) + struct.pack("<16I", *([w * h * 4] + [0] * 15))
    head += b"\x00" * 1024
    with open(os.path.join(OUT_BLP, name + ".blp"), "wb") as f:
        f.write(head + a8[:, :, [2, 1, 0, 3]].tobytes())
    Image.fromarray(a8, "RGBA").save(os.path.join(OUT_PNG, name + ".png"))


def read_blp(path):
    data = open(path, "rb").read()
    w, h = struct.unpack("<II", data[12:20])
    px = np.frombuffer(data[1172:1172 + w * h * 4], dtype=np.uint8).reshape(h, w, 4)
    return px[:, :, [2, 1, 0, 3]].astype(np.float64) / 255


def load(path):
    """a picture, or its 4x super-resolution copy (<name>_x4.png beside it, made by upscale.py) when
    there is one: K is how many of its pixels make one of the picture's (every measure is multiplied)"""
    up = os.path.splitext(path)[0] + "_x4.png"
    if os.path.exists(up):
        return np.asarray(Image.open(up).convert("RGB")).astype(np.float64) / 255, 4
    return np.asarray(Image.open(path).convert("RGB")).astype(np.float64) / 255, 1


im, K = load(SRC)
PH, PW, _ = im.shape
lift = np.clip(im - BG, 0, 1)
# alpha off the black: light and glow by how far they rise above it, solid shapes (dark shields, the
# bar's tinted glass) whole, their holes filled
glow_a = np.clip(lift.max(axis=2) / 0.20, 0, 1)   # (1.23.3: 0.25 left the mage's runes faint)
# (dark cloaks and shadows count as solid too: anything above the black, its gaps closed first, then
# only single stray pixels opened away, at any size of picture; 1.23.1, asked for: no holes in the flags)
solid = ndimage.binary_opening(ndimage.binary_fill_holes(ndimage.binary_closing(lift.max(axis=2) > 0.035, iterations=K)), iterations=1)
solid_a = np.clip(ndimage.gaussian_filter(solid.astype(np.float64), 0.7 * K) * 1.2, 0, 1)
alpha_all = np.maximum(glow_a, solid_a)
bright = np.clip((lift.max(axis=2) - 0.14) / 0.16, 0, 1)   # clearly brighter than the bars' dark glass
yy, xx = np.mgrid[0:PH, 0:PW].astype(np.float64)


def RailLines(lift, top, bot, K):
    """1 where the picture shows its bar's own rail: a thin bright horizontal line at a rail's row,
    darker a few pixels above and below; an antler or a blade crossing that row is no such line
    (1.23.3: erasing the whole row left a notch in the druid's antler)"""
    L = lift.max(axis=2)
    d, h = int(7 * K), int(10 * K)
    # bright along the row (left and right of it), dimmer above and below: a horizontal line, glowing
    # or not; a diagonal antler or blade is dark to its left or right
    along = np.minimum(np.roll(L, h, axis=1), np.roll(L, -h, axis=1))
    around = np.maximum(np.roll(L, d, axis=0), np.roll(L, -d, axis=0))
    thin = np.clip((np.minimum(L, along) - around - 0.02) / 0.06, 0, 1)
    rows = np.maximum(ramp(np.abs(yy - top), 8 * K, 5 * K), ramp(np.abs(yy - bot), 8 * K, 5 * K))
    return ndimage.gaussian_filter(np.clip(thin * rows * 1.5, 0, 1), 1.0 * K)


fill_mean = read_blp(os.path.join(ART, "PanelFill.blp"))[..., :3].mean()


def ramp(v, a, b):
    """0 at a, 1 at b (either way round)"""
    return np.clip((v - a) / (b - a), 0, 1)


def cut(name, cx, mid, s, keep, anchor_x, stray=0.02, face=None, bar_side=0):
    """the picture round (cx, mid), its rails RAIL apart, onto a TW x TH texture; face: the radius of its
    round face (picture px), always solid so nothing shows through it; bar_side: -1 or 1, the side
    facing the bar, the only side small loose pieces are dropped from"""
    a = alpha_all * keep
    if face:
        a = np.maximum(a, ramp(np.hypot(xx - cx, yy - mid), face, face - 2 * K))
    with np.errstate(invalid="ignore", divide="ignore"):
        col = np.clip(np.where(a[..., None] > 1e-3, lift / np.maximum(a, 1e-3)[..., None], 0), 0, 1)
    u = (np.arange(TW) + 0.5 - anchor_x) * s + cx
    v = (np.arange(TH) + 0.5 - TH / 2) * s + mid
    V, U_ = np.meshgrid(v, u, indexing="ij")
    coords = np.array([V - 0.5, U_ - 0.5])
    # shrinking a big (super-resolution) picture: smoothed first to the texture's pixel, no jagged edges
    k = 0.42 * s if s > 1.2 else 0
    pre = (lambda m: ndimage.gaussian_filter(m, k)) if k else (lambda m: m)
    pa = ndimage.map_coordinates(pre(a), coords, order=1, mode="constant", cval=0)
    pc = np.dstack([ndimage.map_coordinates(pre(col[..., i] * a), coords, order=1, mode="constant", cval=0) for i in range(3)])
    with np.errstate(invalid="ignore", divide="ignore"):
        c = np.where(pa[..., None] > 1e-4, pc / np.maximum(pa, 1e-4)[..., None], 0)
    # no stray bits: little pieces left on their own by the cut (an antler's tip, a dagger's) go
    lab, n = ndimage.label(pa > 0.12)
    if n > 1:
        sizes = ndimage.sum(np.ones_like(pa), lab, index=np.arange(1, n + 1))
        big = np.zeros(n + 1, dtype=bool)
        big[1:] = sizes >= max(120, stray * sizes.max())
        if bar_side:
            # only on the bar's side: on the outer side, a flag's or a cape's own pieces are the design
            cols = ndimage.center_of_mass(np.ones_like(pa), lab, index=np.arange(1, n + 1))
            for j, (crow, ccol) in enumerate(cols):
                # kept: the outer side's pieces, and anything above or below the bar (a horn, a tip):
                # only pieces sitting on the bar itself go (1.23.3: the warlock's horn went)
                if (ccol - anchor_x) * bar_side < 0 or (abs(crow - TH / 2) > RAIL * 0.45 and sizes[j] >= 300):
                    big[j + 1] = True
        keepm = ndimage.binary_dilation(big[lab], iterations=2) | (pa <= 0.12) & ndimage.binary_dilation(big[lab], iterations=4)
        pa = pa * ndimage.gaussian_filter(keepm.astype(np.float64), 0.6)
    write_blp(name, np.dstack([np.clip(c, 0, 1), np.clip(pa, 0, 1)]))


def Fade(gap, s):
    """where the picture's bar fades out past an emblem's middle (picture px): slowly, before its first
    slot and within Creed UI's room (118 texture px); where there's no room for that (a short bar), at
    the emblem's ring itself (None: the caller cuts round the ring), so Creed UI's own bar meets it"""
    return None, None  # 1.21.7: always at the ring (the emblems drawn smaller and further in)


RAIL_H, RAIL_W = 16, 64
for cls, lx, rx, top, bot, gap_l, gap_r in BARS:
    lx, rx, top, bot, gap_l, gap_r = lx * K, rx * K, top * K, bot * K, gap_l * K, gap_r * K
    hg, rg = HALF_GAP * K, RING * K
    mid = (top + bot) / 2
    s = (bot - top) / RAIL               # picture pixels per texture pixel
    near = ramp(np.abs(yy - mid), hg, hg - 4 * K)                                    # this row only
    band = ramp(np.abs(yy - mid), (bot - top) / 2 + 7 * K, (bot - top) / 2 + 3 * K)  # 1 within the bar's body
    # left: all of the emblem; within the bar's band, the picture's bar runs on past it and fades out
    # slowly, before the first slot (Creed UI's own bar, painted as this one, carries on under it)
    out_l = OUTER.get(cls + "L", 140) * s
    keep_l = near * ramp(xx, lx - out_l, lx - out_l + 8 * K) * ramp(xx, lx + 150 * s, lx + 140 * s)
    # (faded out by the picture's first slot, and within Creed UI's room at the bar's end: 118 texture px)
    end_l, start_l = Fade(gap_l, s)
    rl = RINGS.get(cls + "L", RING) * K
    ring = ramp(np.hypot(xx - lx, yy - mid), rl + 3 * K, rl)
    # (the picture's own rail lines left out there: they'd double Creed UI's)
    norail = 1 - RailLines(lift, top, bot, K)
    near_ring = ramp(np.hypot(xx - lx, yy - mid), rg + 20 * K, rg + 4 * K) * norail
    # and what of the emblem reaches over the bar (a dagger, an antler, the bow): everything clearly
    # brighter than the bar's dark glass, up to where Creed UI's slots begin (1.21.8, asked for)
    reach = min(gap_l - 12 * K, 72 * K)
    over_l = bright * norail * ramp(xx, lx + reach, lx + reach - 8 * K)
    # (no margin of the picture's own dark glass round the ring: Creed UI's bar has its class's glass)
    inner_l = np.maximum(np.maximum(ramp(xx, lx + 2 * K, lx - 2 * K), ring * norail), over_l)
    keep_l = keep_l * np.maximum(1 - band, inner_l)
    cut("PanelEmblem" + cls + "L", lx, mid, s, keep_l, ANCHOR_L, 0.06, rg - 4 * K, 1)
    out_r = OUTER.get(cls + "R", 140) * s
    keep_r = near * ramp(xx, rx + out_r, rx + out_r - 8 * K) * ramp(xx, rx - 150 * s, rx - 140 * s)
    end_r, start_r = Fade(gap_r, s)
    ring = ramp(np.hypot(xx - rx, yy - mid), rg + 3 * K, rg)
    # (the crest: cut at its ring on the bar's side, no margin: its flag's bits there flew loose)
    inner_r = np.maximum(ramp(xx, rx - 2 * K, rx + 2 * K), ring)
    keep_r = keep_r * np.maximum(1 - band, inner_r)
    cut("PanelEmblem" + cls + "R", rx, mid, s, keep_r, ANCHOR_R, 0.06, rg - 4 * K, -1)
    # the rails: each one's line and glow, taken across the bar's clear middle, averaged into one
    # smooth line (only the line: the glass on either side of it is Creed UI's)
    x0, x1 = int(lx + (rx - lx) * 0.35), int(lx + (rx - lx) * 0.65)
    n = x1 - x0
    for side, line in (("T", top), ("B", bot)):
        ys = line + (np.arange(RAIL_H) + 0.5 - RAIL_H / 2) * s
        band_l = np.array([ndimage.map_coordinates(lift[..., c], [np.repeat(ys, n), np.tile(np.arange(x0, x1), RAIL_H)], order=1).reshape(RAIL_H, n) for c in range(3)])
        prof = np.median(band_l, axis=2).T
        a = np.clip(prof.max(axis=1) / 0.25, 0, 1) * np.exp(-((np.arange(RAIL_H) + 0.5 - RAIL_H / 2) / 4.0) ** 2)
        with np.errstate(invalid="ignore", divide="ignore"):
            c = np.where(a[:, None] > 1e-3, prof / np.maximum(a, 1e-3)[:, None], 0)
        rgba = np.dstack([np.repeat(np.clip(c, 0, 1)[:, None, :], RAIL_W, axis=1), np.repeat(a[:, None], RAIL_W, axis=1)])
        write_blp("PanelRail" + cls + side, rgba)
    # the inside of the bar: its glass color
    # as a tint for Creed UI's glass texture (whose mean is fill_mean)
    # (the clear strips under the top rail and over the bottom one, past the XP bar's end)
    xe = int(rx - gap_r + 10 * K)
    region = np.concatenate([im[int(top + 3 * K):int(top + 7 * K), xe:int(rx - 50 * K)].reshape(-1, 3),
        im[int(bot - 6 * K):int(bot - 2 * K), x0:x1].reshape(-1, 3)])
    tint = np.clip(np.median(region, axis=0) / fill_mean, 0, 1)
    print("%-8s fill = { %.2f, %.2f, %.2f }," % (cls, tint[0], tint[1], tint[2]))

# the shaman's left emblem is the carved totem of the user's first picture (asked for: "I like this totem
# face more"), source/class_bars_first.webp: its bar's rails at 975 and 1069, the totem's ring (about
# 70 px round) at 257 across; everything outside the bar kept whole, inside it cut at the ring
FIRST = os.path.join(os.path.dirname(os.path.abspath(SRC)), "class_bars_first.webp")
if os.path.exists(FIRST):
    im, K = load(FIRST)
    PH, PW, _ = im.shape
    lift = np.clip(im - np.array([0.035, 0.035, 0.04]), 0, 1)
    glow_a = np.clip(lift.max(axis=2) / 0.32, 0, 1)
    solid = ndimage.binary_opening(ndimage.binary_fill_holes(ndimage.binary_closing(lift.max(axis=2) > 0.05, iterations=K)), iterations=1)
    solid_a = np.clip(ndimage.gaussian_filter(solid.astype(np.float64), 0.7 * K) * 1.2, 0, 1)
    alpha_all = np.maximum(glow_a, solid_a)
    yy, xx = np.mgrid[0:PH, 0:PW].astype(np.float64)
    top, bot, lx = 975 * K, 1069 * K, 257 * K
    mid, s = (top + bot) / 2, (bot - top) / RAIL
    near = ramp(yy - mid, -76 * K, -72 * K) * ramp(yy - mid, 64 * K, 60 * K)
    band = ramp(np.abs(yy - mid), (bot - top) / 2 + 7 * K, (bot - top) / 2 + 3 * K)
    keep = near * ramp(xx, lx - 150 * K, lx - 142 * K) * ramp(xx, lx + 150 * K, lx + 140 * K)
    keep = keep * np.maximum(1 - band, np.maximum(ramp(xx, lx + 2 * K, lx - 2 * K), ramp(np.hypot(xx - lx, yy - mid), 73 * K, 70 * K)))
    keep = keep * np.maximum(1 - RailLines(lift, top, bot, K), ramp(xx, lx + 40 * K, lx + 34 * K))   # its bar's rail line
    # and that bar's glowing line just over its top rail (at 965), past the totem's round
    keep = keep * np.maximum(ramp(np.abs(yy - 965 * K), 10 * K, 14 * K), ramp(xx, lx + 50 * K, lx + 44 * K))
    # its ring is bigger than the others' (70 to their 43, at its rails' scale): drawn to their size
    # (10% bigger than the others' size, to hide the bar's ends behind it: asked for)
    cut("PanelEmblemShamanL", lx, mid, s * (70 / (bot - top) * K) / (RING / 72.0) / 1.1, keep, ANCHOR_L, 0.06, 66 * K, 1)
    # the priest's crest is the first picture's too (asked for): the gold winged light in its ring (about
    # 38 px round, at 957, 1160), its feathers flying out; inside the bar's band cut at the ring, the
    # first picture's bar bracket left behind; drawn to the other crests' size, its ring on the bar's middle
    cx, cy, r = 957 * K, 1160 * K, 38 * K
    near = ramp(yy - cy, -66 * K, -62 * K) * ramp(yy - cy, 52 * K, 48 * K)
    band = ramp(np.abs(yy - cy), 44 * K, 40 * K)
    keep = near * ramp(xx, cx + 140 * K, cx + 132 * K)
    # (left of the ring only the ring itself: the first picture's bracket and its diamonds stay behind)
    keep = keep * np.maximum(ramp(xx, cx - 14 * K, cx - 10 * K), ramp(np.hypot(xx - cx, yy - cy), r + 3 * K, r))
    keep = keep * np.maximum(1 - band, np.maximum(ramp(xx, cx - 2 * K, cx + 2 * K), ramp(np.hypot(xx - cx, yy - cy), r + 3 * K, r)))
    # (and the stub of that bar's top rail and spike over the ring, 1104 to 1122: asked for)
    keep = keep * np.maximum(ramp(np.abs(yy - 1113 * K), 6 * K, 9 * K), ramp(xx, cx + 16 * K, cx + 22 * K))
    cut("PanelEmblemPriestR", cx, cy, r / (RING / 72.0 * RAIL), keep, ANCHOR_R, 0.06, r - 3 * K, -1)
    # the rogue's left emblem is the first picture's too (asked for: its two crossed daggers in purple
    # smoke): they cross at 257, 590 over a bar whose rails are at 512 and 620; everything above and
    # below the bar kept whole, and over the bar what's brighter than its glass (the blades), up to
    # where the slots begin; its dark smoky round kept solid
    top, bot, lx = 512 * K, 620 * K, 257 * K
    mid, s = (top + bot) / 2, (bot - top) / RAIL
    bright = np.clip((lift.max(axis=2) - 0.14) / 0.16, 0, 1)
    near = ramp(yy - mid, -82 * K, -78 * K) * ramp(yy - mid, 70 * K, 66 * K)
    band = ramp(np.abs(yy - mid), (bot - top) / 2 + 7 * K, (bot - top) / 2 + 3 * K)
    norail = 1 - RailLines(lift, top, bot, K)
    keep = near * ramp(xx, lx - 200 * K, lx - 192 * K) * ramp(xx, lx + 120 * K, lx + 110 * K)
    keep = keep * np.maximum(norail, ramp(xx, lx + 30 * K, lx + 24 * K))   # the bar's rail stubs go
    over = bright * norail * ramp(xx, lx + 100 * K, lx + 90 * K)
    smoke = ramp(np.hypot(xx - lx, yy - mid + 14 * K), 62 * K, 56 * K)   # the smoky round behind them
    keep = keep * np.maximum(1 - band, np.maximum(np.maximum(ramp(xx, lx + 2 * K, lx - 2 * K), over), smoke))
    # a solid dark round behind the daggers, as the other emblems have (1.23.4, asked for: the bar showed
    # through around them)
    cut("PanelEmblemRogueL", lx, mid, s, keep, ANCHOR_L, 0.06, 66 * K, 1)
    # and the hunter's: the first picture's bow in its ring of leaves (asked for), the ring (about 64 px
    # round) at 255, 405 over a bar whose rails are at 355 and 462; its leaves and the bow's tips that
    # reach over the bar kept, as the rogue's blades
    top, bot, lx = 355 * K, 462 * K, 255 * K
    mid, s = (top + bot) / 2, (bot - top) / RAIL
    near = ramp(yy - mid, -80 * K, -76 * K) * ramp(yy - mid, 76 * K, 72 * K)
    band = ramp(np.abs(yy - mid), (bot - top) / 2 + 7 * K, (bot - top) / 2 + 3 * K)
    norail = 1 - RailLines(lift, top, bot, K)
    keep = near * ramp(xx, lx - 200 * K, lx - 192 * K) * ramp(xx, lx + 120 * K, lx + 110 * K)
    keep = keep * np.maximum(norail, ramp(xx, lx + 30 * K, lx + 24 * K))   # the bar's rail stubs go
    over = bright * norail * ramp(xx, lx + 100 * K, lx + 90 * K)
    ringk = ramp(np.hypot(xx - lx, yy - (mid - 3 * K)), 68 * K, 64 * K)
    keep = keep * np.maximum(1 - band, np.maximum(np.maximum(ramp(xx, lx + 2 * K, lx - 2 * K), over), ringk))
    cut("PanelEmblemHunterL", lx, mid - 3 * K, s, keep, ANCHOR_L, 0.06, 58 * K, 1)
    # the warlock's crest is the first picture's too (asked for: simpler): the fel flame in its violet ring
    # (about 35 px round, at 960, 1295), its feathers flying out; left of the ring and over the bar only
    # the ring itself (the first picture's bracket, diamonds and rails stay behind)
    cx, cy, r = 960 * K, 1295 * K, 36 * K
    near = ramp(yy - cy, -62 * K, -58 * K) * ramp(yy - cy, 50 * K, 46 * K)
    band = ramp(np.abs(yy - cy), 44 * K, 40 * K)
    rk = ramp(np.hypot(xx - cx, yy - cy), r + 3 * K, r)
    keep = near * ramp(xx, cx + 140 * K, cx + 132 * K)
    keep = keep * np.maximum(ramp(xx, cx - 14 * K, cx - 10 * K), rk)
    keep = keep * np.maximum(1 - band, np.maximum(ramp(xx, cx - 2 * K, cx + 2 * K), rk))
    # (the first picture's top rail running into the feathers, at 1239, and its bracket under the ring)
    keep = keep * np.maximum(ramp(np.abs(yy - 1239 * K), 5 * K, 8 * K), ramp(xx, cx + 70 * K, cx + 76 * K))
    keep = keep * np.maximum(ramp(yy, cy + 28 * K, cy + 24 * K), np.maximum(rk, ramp(xx, cx, cx + 6 * K)))
    cut("PanelEmblemWarlockR", cx, cy, r / (RING / 72.0 * RAIL), keep, ANCHOR_R, 0.06, r - 3 * K, 0)
    # the shaman's crest too (asked for): the lightning in its gold ring (about 36 px round, at 960,
    # 1035), its blue feathers and the star flying out; the first picture's rails (975, 1069) and its
    # bracket stay behind
    cx, cy, r = 960 * K, 1035 * K, 36 * K
    near = ramp(yy - cy, -64 * K, -60 * K) * ramp(yy - cy, 52 * K, 48 * K)
    band = ramp(np.abs(yy - cy), 44 * K, 40 * K)
    rk = ramp(np.hypot(xx - cx, yy - cy), r + 3 * K, r)
    keep = near * ramp(xx, cx + 140 * K, cx + 132 * K)
    keep = keep * np.maximum(ramp(xx, cx - 14 * K, cx - 10 * K), rk)
    keep = keep * np.maximum(1 - band, np.maximum(ramp(xx, cx - 2 * K, cx + 2 * K), rk))
    keep = keep * np.maximum(1 - RailLines(lift, 975 * K, 1069 * K, K), rk)
    keep = keep * np.maximum(ramp(yy, cy + 28 * K, cy + 24 * K), np.maximum(rk, ramp(xx, cx, cx + 6 * K)))
    # (its dark glow outside the ring isn't solid: the feathers and the star stand on their own)
    whole = alpha_all
    own = ndimage.binary_opening(lift.max(axis=2) > 0.09, iterations=1)    # no gaps filled between them
    own = np.clip(ndimage.gaussian_filter(own.astype(np.float64), 0.7 * K) * 1.2, 0, 1)
    alpha_all = np.maximum(glow_a, np.maximum(own, solid_a * ramp(np.hypot(xx - cx, yy - cy), r + 8 * K, r + 2 * K)))
    # only the ring and its lower feathers (asked for: its top wing reached far over the bar, the star
    # and sparks flew about): outside the ring, only what's under the line from 1000, 1004 to 1087,
    # 1052, the star's and spark's rounds left out, the feathers' tips faded before the picture's edge
    under = ramp(yy - (1006 * K + (xx - 1000 * K) * 48.0 / 87.0), -2 * K, 2 * K) * ramp(xx, cx + 26 * K, cx + 32 * K)
    star = np.maximum(ramp(np.hypot(xx - 1047 * K, yy - 1029 * K), 17 * K, 20 * K),
        ramp(np.hypot(xx - 1018 * K, yy - 1012 * K), 7 * K, 9 * K))
    keep = keep * np.maximum(rk, under * star) * ramp(xx, cx + 126 * K, cx + 114 * K)
    cut("PanelEmblemShamanR", cx, cy, r / (RING / 72.0 * RAIL), keep, ANCHOR_R, 0.06, r - 3 * K, 0)
    alpha_all = whole
print("wrote", OUT_BLP)
