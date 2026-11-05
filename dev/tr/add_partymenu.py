# 1.18.0: the party frames' right-click menu
import sys
D = sys.argv[1]
HERE = sys.path[0]
L = ["fr", "de", "es", "pt", "zh", "ru", "ja", "ko", "pl", "tr"]
def T(en, *vals):
    assert len(vals) == 10, en
    return (en, dict(zip(L, vals)))
P = [
 T("Inspect", "Inspecter", "Betrachten", "Inspeccionar", "Inspecionar", "观察", "Осмотреть", "調べる", "살펴보기", "Obejrzyj", "İncele"),
 T("Follow", "Suivre", "Folgen", "Seguir", "Seguir", "跟随", "Следовать", "フォロー", "따라가기", "Podążaj", "Takip et"),
 T("Whisper", "Chuchoter", "Flüstern", "Susurrar", "Sussurrar", "密语", "Шепнуть", "ささやく", "귓속말", "Szepnij", "Fısılda"),
 T("Too far away to inspect.", "Trop loin pour inspecter.", "Zu weit entfernt zum Betrachten.", "Demasiado lejos para inspeccionar.", "Longe demais para inspecionar.", "距离太远，无法观察。", "Слишком далеко для осмотра.", "遠すぎて調べられません。", "너무 멀어서 살펴볼 수 없습니다.", "Za daleko, by obejrzeć.", "İncelemek için çok uzak."),
]

def q(s): return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'
loc = open(D + "/Locale.lua", encoding="utf-8").read()
if '{ "Whisper",' not in loc:
    def row(en, t):
        return "\t{ " + q(en) + ",\n\t\t" + ",\n\t\t".join(q(t[c]) for c in ("fr", "de", "es", "pt")) + " },\n"
    rows = "\t-- the party frames' right-click menu (1.18.0)\n" + "".join(row(en, t) for en, t in P if ("{ " + q(en) + ",") not in loc)
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
