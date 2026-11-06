# 1.20.0: /creed numbers font
import sys
D = sys.argv[1]
HERE = sys.path[0]
L = ["fr", "de", "es", "pt", "zh", "ru", "ja", "ko", "pl", "tr"]
def T(en, *vals):
    assert len(vals) == 10, en
    return (en, dict(zip(L, vals)))
P = [
 T("font: ", "police : ", "Schrift: ", "fuente: ", "fonte: ", "字体：", "шрифт: ", "フォント: ", "글꼴: ", "czcionka: ", "yazı tipi: "),
 T("/creed numbers font <name> - Friz Quadrata, Cinzel, Bangers, Creepster, Uncial Antiqua, Black Ops One, Pirata One...",
   "/creed numbers font <nom> - Friz Quadrata, Cinzel, Bangers, Creepster, Uncial Antiqua, Black Ops One, Pirata One...",
   "/creed numbers font <Name> - Friz Quadrata, Cinzel, Bangers, Creepster, Uncial Antiqua, Black Ops One, Pirata One...",
   "/creed numbers font <nombre> - Friz Quadrata, Cinzel, Bangers, Creepster, Uncial Antiqua, Black Ops One, Pirata One...",
   "/creed numbers font <nome> - Friz Quadrata, Cinzel, Bangers, Creepster, Uncial Antiqua, Black Ops One, Pirata One...",
   "/creed numbers font <名称> - Friz Quadrata、Cinzel、Bangers、Creepster、Uncial Antiqua、Black Ops One、Pirata One……",
   "/creed numbers font <название> - Friz Quadrata, Cinzel, Bangers, Creepster, Uncial Antiqua, Black Ops One, Pirata One...",
   "/creed numbers font <名前> - Friz Quadrata、Cinzel、Bangers、Creepster、Uncial Antiqua、Black Ops One、Pirata One など",
   "/creed numbers font <이름> - Friz Quadrata, Cinzel, Bangers, Creepster, Uncial Antiqua, Black Ops One, Pirata One...",
   "/creed numbers font <nazwa> - Friz Quadrata, Cinzel, Bangers, Creepster, Uncial Antiqua, Black Ops One, Pirata One...",
   "/creed numbers font <ad> - Friz Quadrata, Cinzel, Bangers, Creepster, Uncial Antiqua, Black Ops One, Pirata One..."),
]

def q(s): return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'
loc = open(D + "/Locale.lua", encoding="utf-8").read()
if '{ "font: ",' not in loc:
    def row(en, t):
        return "\t{ " + q(en) + ",\n\t\t" + ",\n\t\t".join(q(t[c]) for c in ("fr", "de", "es", "pt")) + " },\n"
    rows = "\t-- the damage numbers' font command (1.20.0)\n" + "".join(row(en, t) for en, t in P if ("{ " + q(en) + ",") not in loc)
    anchor = "\n\t-- what stops after an error says so\n"
    assert loc.count(anchor) == 1
    loc = loc.replace(anchor, "\n" + rows + anchor)
    open(D + "/Locale.lua", "w", encoding="utf-8").write(loc)

kp = HERE + "/../en_keys.txt"
keys = open(kp, encoding="utf-8").read().split("\n")
new = [en for en, _ in P if en not in keys]
start = len(keys) + 1
if new:
    open(kp, "w", encoding="utf-8").write("\n".join(keys + new))
    for code in ("zh", "ru", "ja", "ko", "pl", "tr"):
        p = HERE + "/" + code + ".py"
        s = open(p, encoding="utf-8").read().rstrip()
        assert s.endswith("}")
        add = "".join("%d: %s,\n" % (start + n, q(dict(P)[en][code])) for n, en in enumerate(new))
        open(p, "w", encoding="utf-8").write(s[:-1] + add + "}\n")
print("added", len(new), "from", start)
