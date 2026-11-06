#!/usr/bin/env python3
"""Writes CreedUI/LootSets.lua: the game's gear set names and weapon names, in all of its languages,
with the rarity each stands for, so a drop the game names without a link (the loot pop-up) gets its
rarity's color. The game numbers them so: set.<class>.<rarity> and weapon.<class>.<n>.<rarity>
(0 Common, 1 Uncommon, 2 Rare, 3 Epic, 4 Legendary, 7 Tier 0.5), read from its client's JSON.

    python3 loot_sets.py <wenilla_bg.wasm> <CreedUI dir>
"""
import json
import re
import sys

wasm, out = sys.argv[1], sys.argv[2]
b = open(wasm, "rb").read()
sets, weps = {}, {}
for m in re.finditer(rb'"set\.([a-z]+)\.(\d+)": "((?:[^"\\]|\\.)*)"', b):
    sets.setdefault(json.loads(b'"' + m.group(3) + b'"'), set()).add(int(m.group(2)))
for m in re.finditer(rb'"weapon\.([a-z]+)\.(\d+)\.(\d+)": "((?:[^"\\]|\\.)*)"', b):
    weps.setdefault(json.loads(b'"' + m.group(4) + b'"'), set()).add(int(m.group(3)))


def q(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def rows(d):
    # a name that stands for two rarities (one word in two languages) is left out
    return "".join("\t[%s] = %d,\n" % (q(k), min(v)) for k, v in sorted(d.items()) if len(v) == 1)


lua = ("-- Creed UI: the game's gear set and weapon names, in all its languages, each with its rarity\n"
       "-- (0 Common, 1 Uncommon, 2 Rare, 3 Epic, 4 Legendary, 7 Tier 0.5). Written by dev/tr/loot_sets.py\n"
       "-- from the game's own words; the loot pop-up colors a drop by them.\n\n"
       "CreedUI.lootSets = {\n" + rows(sets) + "}\n\nCreedUI.lootWeapons = {\n" + rows(weps) + "}\n")
open(out + "/LootSets.lua", "w", encoding="utf-8").write(lua)
print("sets", len(sets), "weapons", len(weps))
