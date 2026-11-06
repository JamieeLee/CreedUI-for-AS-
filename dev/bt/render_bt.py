#!/usr/bin/env python3
"""Render a mock frame dump (from mock_bt.lua's MOCK.Dump) the way the client draws it.

usage: render_bt.py dump.txt out.png crop_l crop_b crop_r crop_t scale [background.png]
"""
import os
import struct
import re
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.join(HERE, "art_png")
FONTS = {
    "Fonts\\FRIZQT__.TTF": "/usr/share/fonts/truetype/dejavu/DejaVuSerifCondensed-Bold.ttf",
    "Fonts\\MORPHEUS.TTF": "/usr/share/fonts/truetype/google-fonts/Lora-Variable.ttf",
    "Fonts\\NATIVE.TTF": "/usr/share/fonts/opentype/noto/NotoSerifCJK-Bold.ttc",
    "Interface\\AddOns\\CreedUI\\Fonts\\Letters.ttf": os.path.join(HERE, "..", "..", "CreedUI", "Fonts", "Letters.ttf"),
    "Interface\\AddOns\\CreedUI\\Fonts\\LettersCJK.ttf": os.path.join(HERE, "..", "..", "CreedUI", "Fonts", "LettersCJK.ttf"),
}
_tex_cache = {}
_font_cache = {}


def read_blp(path):
    """Creed UI's art: BLP2, uncompressed BGRA (as the art scripts write it)"""
    data = open(path, "rb").read()
    w, h = struct.unpack("<II", data[12:20])
    off = struct.unpack("<I", data[20:24])[0]
    px = np.frombuffer(data[off:off + w * h * 4], dtype=np.uint8).reshape(h, w, 4)
    return px[:, :, [2, 1, 0, 3]].astype(np.float32) / 255.0


def load_tex(path):
    if path in _tex_cache:
        return _tex_cache[path]
    if path == "Interface\\ChatFrame\\ChatFrameBackground" or path == "-":
        arr = np.ones((8, 8, 4), dtype=np.float32)
    else:
        name = path.split("\\")[-1]
        png, blp = os.path.join(ART, name + ".png"), os.path.join(HERE, "..", "..", "CreedUI", "Art", name + ".blp")
        if os.path.exists(png):
            arr = np.asarray(Image.open(png).convert("RGBA"), dtype=np.float32) / 255.0
        elif os.path.exists(blp):
            arr = read_blp(blp)
        else:  # a game texture we haven't got: a dim stand-in
            arr = np.zeros((8, 8, 4), dtype=np.float32)
            arr[..., :3], arr[..., 3] = 0.25, 0.85
    _tex_cache[path] = arr
    return arr


def font(path, size):
    key = (path, size)
    if key not in _font_cache:
        f = FONTS.get(path, FONTS["Fonts\\FRIZQT__.TTF"])
        if not os.path.exists(f):  # a system without that font: the addon's own serif stands in
            f = FONTS["Interface\\AddOns\\CreedUI\\Fonts\\Letters.ttf"]
        _font_cache[key] = ImageFont.truetype(f, max(4, int(round(size))))
    return _font_cache[key]


def nums(s):
    if s == "-" or s == "":
        return None
    return [float(x) for x in s.split(",")]


def sample(tex, tc, w, h):
    """Resample texture `tex` (H,W,4 float) through texcoords to a w x h patch."""
    th, tw = tex.shape[0], tex.shape[1]
    if tc is None:
        tc = [0, 1, 0, 1]
    if len(tc) == 4:
        l, r, t, b = tc
        ul, ll, ur = (l, t), (l, b), (r, t)
    else:
        ul, ll, ur = (tc[0], tc[1]), (tc[2], tc[3]), (tc[4], tc[5])
    a = (ur[0] - ul[0]) * tw / w
    bb = (ll[0] - ul[0]) * tw / h
    c = ul[0] * tw
    d = (ur[1] - ul[1]) * th / w
    e = (ll[1] - ul[1]) * th / h
    f = ul[1] * th
    # premultiply so bilinear filtering doesn't darken edges
    pm = tex.copy()
    pm[..., :3] *= pm[..., 3:4]
    out = np.zeros((h, w, 4), dtype=np.float32)
    for ch in range(4):
        img = Image.fromarray(pm[..., ch].astype(np.float32), "F")
        res = img.transform((w, h), Image.AFFINE, (a, bb, c, d, e, f), resample=Image.BILINEAR)
        out[..., ch] = np.asarray(res, dtype=np.float32)
    with np.errstate(invalid="ignore", divide="ignore"):
        out[..., :3] = np.where(out[..., 3:4] > 1e-5, out[..., :3] / out[..., 3:4], 0)
    return np.clip(out, 0, 1)


def tint_arrays(w, h, vc, grad):
    if grad:
        o, c1, c2 = grad
        c1, c2 = np.array(c1), np.array(c2)
        if o == "HORIZONTAL":
            t = (np.arange(w) + 0.5) / w
            row = c1[None, :] * (1 - t[:, None]) + c2[None, :] * t[:, None]
            return np.broadcast_to(row[None, :, :], (h, w, 4))
        t = (np.arange(h) + 0.5) / h  # top row first: max at the top
        col = c2[None, :] * (1 - t[:, None]) + c1[None, :] * t[:, None]
        return np.broadcast_to(col[:, None, :], (h, w, 4))
    if vc:
        return np.broadcast_to(np.array(vc, dtype=np.float32), (h, w, 4))
    return None


def composite(canvas, patch, x0, y0, blend):
    H, W = canvas.shape[0], canvas.shape[1]
    h, w = patch.shape[0], patch.shape[1]
    sx0, sy0 = max(0, -x0), max(0, -y0)
    dx0, dy0 = max(0, x0), max(0, y0)
    dx1, dy1 = min(W, x0 + w), min(H, y0 + h)
    if dx1 <= dx0 or dy1 <= dy0:
        return
    p = patch[sy0:sy0 + (dy1 - dy0), sx0:sx0 + (dx1 - dx0)]
    dst = canvas[dy0:dy1, dx0:dx1]
    a = p[..., 3:4]
    if blend == "ADD":
        dst[...] = dst + p[..., :3] * a
    elif blend == "MOD":
        dst[...] = dst * (p[..., :3] * a + (1 - a))
    else:
        dst[...] = p[..., :3] * a + dst * (1 - a)


COLOR_RE = re.compile(r"\|c([0-9a-fA-F]{8})|\|r")


def segments(text, base):
    out = []
    color = base
    pos = 0
    for m in COLOR_RE.finditer(text):
        if m.start() > pos:
            out.append((text[pos:m.start()], color))
        if m.group(1):
            hx = m.group(1)
            color = (int(hx[2:4], 16) / 255, int(hx[4:6], 16) / 255, int(hx[6:8], 16) / 255)
        else:
            color = base
        pos = m.end()
    if pos < len(text):
        out.append((text[pos:], color))
    return out


def draw_text(canvas, rect_px, fpath, size, flags, color, justify, shadow, text, alpha, S):
    if not text:
        return
    if "\\n" in text:
        # several lines: the first where the one-line box is, the rest under it
        x0, y0, x1, y1 = rect_px
        lh = size * S * 1.12
        for k, line in enumerate(text.split("\\n")):
            draw_text(canvas, (x0, y0 + k * lh, x1, y1 + k * lh), fpath, size, flags, color, justify, shadow, line, alpha, S)
        return
    fnt = font(fpath, size * S)
    segs = segments(text, tuple(color[:3]))
    total = sum(fnt.getlength(s) for s, _ in segs)
    x0, y0, x1, y1 = rect_px
    pad = int(6 * S)
    hgt = int(size * S * 1.6) + pad * 2
    wid = int(total + pad * 2 + 4)
    layer = Image.new("RGBA", (wid, hgt), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    stroke = int(round(1.0 * S)) if flags and "OUTLINE" in flags else 0
    asc, desc = fnt.getmetrics()
    ty = (hgt - (asc + desc)) // 2
    if shadow:
        x = pad
        for s, c in segs:
            d.text((x + S, ty + S), s, font=fnt, fill=(0, 0, 0, 255), stroke_width=stroke, stroke_fill=(0, 0, 0, 255))
            x += fnt.getlength(s)
    x = pad
    for s, c in segs:
        col = tuple(int(max(0, min(1, v)) * 255) for v in c) + (255,)
        d.text((x, ty), s, font=fnt, fill=col, stroke_width=stroke, stroke_fill=(0, 0, 0, 255))
        x += fnt.getlength(s)
    arr = np.asarray(layer, dtype=np.float32) / 255.0
    arr[..., 3] *= alpha * (color[3] if len(color) > 3 else 1)
    if justify == "LEFT":
        px = x0 - pad
    elif justify == "RIGHT":
        px = x1 - total - pad
    else:
        px = (x0 + x1) / 2 - total / 2 - pad
    py = (y0 + y1) / 2 - hgt / 2
    composite(canvas, arr, int(round(px)), int(round(py)), "BLEND")


def render(dump, out, crop, S, bg=None):
    cl, cb, cr, ct = crop
    W, H = int((cr - cl) * S), int((ct - cb) * S)
    if bg and os.path.exists(bg):
        im = Image.open(bg).convert("RGB").resize((W, H), Image.LANCZOS)
        canvas = np.asarray(im, dtype=np.float32) / 255.0
        canvas = canvas.copy()
    else:
        yy = np.linspace(0, 1, H)[:, None, None]
        canvas = (np.array([0.16, 0.18, 0.15]) * (1 - yy) + np.array([0.09, 0.10, 0.09]) * yy) * np.ones((H, W, 3))
        canvas = canvas.astype(np.float32)
    items = []
    with open(dump) as f:
        for line in f:
            p = line.rstrip("\n").split("\t")
            kind = p[0]
            l, b, r, t = map(float, p[1:5])
            strata, level, layer, rank, oid = int(p[5]), int(p[6]), int(p[7]), int(p[8]), int(p[9])
            alpha = float(p[10])
            items.append((strata, level, layer, 1 if kind == "FontString" else 0, rank, oid, kind, (l, b, r, t), alpha, p[11:]))
    items.sort(key=lambda it: it[:6])
    for strata, level, layer, istext, rank, oid, kind, (l, b, r, t), alpha, rest in items:
        x0, x1 = (l - cl) * S, (r - cl) * S
        y0, y1 = (ct - t) * S, (ct - b) * S
        if kind == "Backdrop":
            bd, border = nums(rest[0]), nums(rest[1])
            w, h = int(round(x1 - x0)), int(round(y1 - y0))
            if w < 1 or h < 1:
                continue
            patch = np.zeros((h, w, 4), dtype=np.float32)
            patch[...] = bd
            patch[..., 3] *= alpha
            composite(canvas, patch, int(round(x0)), int(round(y0)), "BLEND")
            if border and border[3] > 0:
                e = max(1, int(round(S)))
                patch = np.zeros((h, w, 4), dtype=np.float32)
                patch[:e, :] = border
                patch[-e:, :] = border
                patch[:, :e] = border
                patch[:, -e:] = border
                patch[..., 3] *= alpha
                composite(canvas, patch, int(round(x0)), int(round(y0)), "BLEND")
            continue
        if kind == "Texture":
            path, solid, blend, vc, grad, tc = rest[0], nums(rest[1]), rest[2], nums(rest[3]), rest[4], nums(rest[5])
            w, h = int(round(x1 - x0)), int(round(y1 - y0))
            if w < 1 or h < 1:
                if (x1 - x0) > 0.2 and (y1 - y0) > 0.2:
                    w, h = max(1, w), max(1, h)
                else:
                    continue
            if solid:
                patch = np.zeros((h, w, 4), dtype=np.float32)
                patch[...] = solid
            else:
                patch = sample(load_tex(path), tc, w, h)
                if len(rest) > 6 and rest[6] == "desat":  # SetDesaturated: grey by luminance
                    lum = patch[..., 0] * 0.3 + patch[..., 1] * 0.59 + patch[..., 2] * 0.11
                    patch = patch.copy()
                    patch[..., 0] = patch[..., 1] = patch[..., 2] = lum
            g = None
            if grad != "-":
                o, c1, c2 = grad.split(":")
                g = (o, nums(c1), nums(c2))
            tint = tint_arrays(w, h, vc, g)
            if tint is not None:
                patch = patch * tint
            patch[..., 3] *= alpha
            composite(canvas, patch, int(round(x0)), int(round(y0)), blend)
        else:
            fpath, size, flags, color, justify, shadow = rest[0], float(rest[1]), rest[2], nums(rest[3]), rest[4], rest[5] == "1"
            text = "\t".join(rest[6:])
            draw_text(canvas, (x0, y0, x1, y1), fpath, size, flags, color, justify, shadow, text, alpha, S)
    img = Image.fromarray((np.clip(canvas, 0, 1) * 255).astype(np.uint8), "RGB")
    img.save(out)
    return img


if __name__ == "__main__":
    dump, out = sys.argv[1], sys.argv[2]
    crop = tuple(float(x) for x in sys.argv[3:7])
    S = float(sys.argv[7])
    bg = sys.argv[8] if len(sys.argv) > 8 else None
    render(dump, out, crop, S, bg)
