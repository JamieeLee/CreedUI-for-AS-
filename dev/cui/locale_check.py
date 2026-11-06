#!/usr/bin/env python3
"""Creed UI's translations: every phrase the code looks up has a row, every row has all four
languages, and each translation keeps its template's slots ({1}, {2}..., %d, %%).
usage: locale_check.py <addon dir>"""
import glob
import os
import re
import sys

D = sys.argv[1]
STR = r'"((?:[^"\\]|\\.)*)"'

# the rows, as Locale.lua writes them: { "en", "fr", "de", "es", "pt" }
src = open(os.path.join(D, "Locale.lua"), encoding="utf-8").read()
body = src[src.index("local ROWS = {"):src.index("C.LOCALE_ROWS")]
rows = []
for m in re.finditer(r'\{\s*((?:' + STR + r'\s*,?\s*(?:--[^\n]*)?\s*){2,})\}', body):
    rows.append(re.findall(STR, m.group(1)))
problems = []
keys = {}
for r in rows:
    if len(r) != 5:
        problems.append("row without all four languages: %r" % (r[:2],))
        continue
    if r[0] in keys:
        problems.append("twice: %r" % r[0])
    keys[r[0]] = r


def slots(s):
    return sorted(re.findall(r"\{\d\}", s)), len(re.findall(r"%d", s)), len(re.findall(r"%%", s))


for en, *tr in keys.values():
    for code, t in zip(("fr", "de", "es", "pt"), tr):
        if slots(t) != slots(en):
            problems.append("%s keeps other slots: %r -> %r" % (code, en, t))
        if t.strip() == "" and en.strip() != "":
            problems.append("%s empty: %r" % (code, en))

# the languages in files of their own (Locale_<code>.lua): every phrase, no other, slots kept
for f in sorted(glob.glob(os.path.join(D, "Locale_*.lua"))):
    code = os.path.basename(f)[7:-4]
    text = open(f, encoding="utf-8").read()
    pairs = re.findall(r'\[' + STR + r'\]\s*=\s*' + STR + ',', text)
    have = {}
    for k, v in pairs:
        if k in have:
            problems.append("%s: twice %r" % (code, k))
        have[k] = v
    for k in keys:
        if k not in have:
            problems.append("%s: missing %r" % (code, k))
        elif slots(have[k]) != slots(k):
            problems.append("%s keeps other slots: %r -> %r" % (code, k, have[k]))
        elif have[k].strip() == "" and k.strip() != "":
            problems.append("%s empty: %r" % (code, k))
    for k in have:
        if k not in keys:
            problems.append("%s: a phrase the English doesn't have: %r" % (code, k))
    print("%s: %d phrases" % (code, len(have)))

# what the code looks up
used = {}
def add(k, f):
    used.setdefault(k, f)
for f in sorted(glob.glob(os.path.join(D, "*.lua"))):
    name = os.path.basename(f)
    if name.startswith("Locale"):
        continue
    code = open(f, encoding="utf-8").read()
    for m in re.finditer(r'(?:\bC\.L|\bC\.F|\bCUI\.L|\bCUI\.F|(?<![\w.])L|(?<![\w.])F|LText)\((?:[^,()"]*,\s*)?' + STR, code):
        add(m.group(1), name)
    for m in re.finditer(r'(?:\bname|\bnote|\bempty)\s*=\s*' + STR, code):
        add(m.group(1), name)
    for m in re.finditer(r'short\s*=\s*\{([^}]*)\}', code):
        for k in re.findall(STR, m.group(1)):
            add(k, name)
    for m in re.finditer(r'C\.Movable\([^,]+,\s*"[a-z]+",\s*' + STR, code):
        add(m.group(1), name)
    for m in re.finditer(r'(?:MakeCheck|TextButton)\([^"\n]*?' + STR, code):
        add(m.group(1), name)
    for m in re.finditer(r'Row\(-\d+,\s*' + STR, code):
        add(m.group(1), name)
    for m in re.finditer(r'Build\("CreedUI\w+",\s*"\w+",\s*' + STR, code):
        add(m.group(1), name)
    for table in ("KIND_TAGS", "AFFIX_NAMES", "PRESET_NAMES", "PRESET_NOTES", "RARITIES"):
        m = re.search(table + r"\s*=\s*\{(.*?)\n\}", code, re.S)
        if m:
            for k in re.findall(r'(?:=\s*\{\s*|=\s*|\bname\s*=\s*)' + STR, m.group(1)):
                if " " in k or k[:1].isupper():
                    add(k, name)
    m = re.search(r'local labels = \{([^}]*)\}', code)
    if m:
        for k in re.findall(r'=\s*' + STR, m.group(1)):
            add(k, name)

# not words to translate: names, samples, symbols, keys
NOT_WORDS = {"", "x", "+", "-", "<", ">", "^", "English", "Azeroth", "Naxxramas", "Creed UI", "Smooth Boss Timer",
             "Friz Quadrata", "Cinzel", "Bangers", "Creepster", "Uncial Antiqua", "Black Ops One", "Pirata One", "Arial Narrow", "Skurri", "Morpheus", "Fireball", "Frostbolt", "Lightning Bolt", "Moonfire",
             "Corruption", "Rupture", "Edwin VanCleef", "Sir Zeliek", "Jaina", "Anduin", "Varian", "CreedUIPlayer",
             "CreedUITarget", "NeckSlot", "Finger0Slot", "Finger1Slot", "Trinket0Slot", "Trinket1Slot", "Magic",
             "Glow", "Training Dummy"}
for k, f in sorted(used.items()):
    if k in NOT_WORDS or re.match(r"^[a-z_]+$", k) and k not in keys or "\\" in k:
        continue
    if k not in keys:
        problems.append("no row for %r (%s)" % (k, f))
unused = [k for k in keys if k not in used]
print("%d rows, %d phrases looked up, %d rows not found in the code" % (len(keys), len(used), len(unused)))
for k in unused:
    print("  (row the code doesn't name directly: %r)" % k)
for p in problems:
    print("PROBLEM: " + p)
print("LOCALE OK" if not problems else "%d LOCALE PROBLEMS" % len(problems))
