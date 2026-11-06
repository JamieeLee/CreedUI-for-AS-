# 1.20.0: crit backdrops for the damage numbers
import sys
D = sys.argv[1]
HERE = sys.path[0]
L = ["fr", "de", "es", "pt", "zh", "ru", "ja", "ko", "pl", "tr"]
def T(en, *vals):
    assert len(vals) == 10, en
    return (en, dict(zip(L, vals)))
P = [
 T("Crit backdrop", "Fond des critiques", "Kritischer Hintergrund", "Fondo de críticos", "Fundo de críticos", "暴击背景", "Фон критов", "クリティカル背景", "치명타 배경", "Tło krytyków", "Kritik arka planı"),
 T("crit backdrop: ", "fond des critiques : ", "kritischer Hintergrund: ", "fondo de críticos: ", "fundo de críticos: ", "暴击背景：", "фон критов: ", "クリティカル背景: ", "치명타 배경: ", "tło krytyków: ", "kritik arka planı: "),
 T("/creed numbers backdrop none, blood, fire, frost, arcane, holy or shadow - behind crits", "/creed numbers backdrop none, blood, fire, frost, arcane, holy ou shadow - derrière les critiques", "/creed numbers backdrop none, blood, fire, frost, arcane, holy oder shadow - hinter kritischen Treffern", "/creed numbers backdrop none, blood, fire, frost, arcane, holy o shadow - detrás de los críticos", "/creed numbers backdrop none, blood, fire, frost, arcane, holy ou shadow - atrás dos críticos", "/creed numbers backdrop none、blood、fire、frost、arcane、holy 或 shadow - 暴击背后", "/creed numbers backdrop none, blood, fire, frost, arcane, holy или shadow - за критами", "/creed numbers backdrop none、blood、fire、frost、arcane、holy、shadow - クリティカルの背後", "/creed numbers backdrop none, blood, fire, frost, arcane, holy, shadow - 치명타 뒤", "/creed numbers backdrop none, blood, fire, frost, arcane, holy lub shadow - za krytykami", "/creed numbers backdrop none, blood, fire, frost, arcane, holy veya shadow - kritiklerin arkasında"),
 T("None", "Aucun", "Keiner", "Ninguno", "Nenhum", "无", "Нет", "なし", "없음", "Brak", "Yok"),
 T("Blood", "Sang", "Blut", "Sangre", "Sangue", "鲜血", "Кровь", "血", "피", "Krew", "Kan"),
 T("Fire", "Feu", "Feuer", "Fuego", "Fogo", "火焰", "Огонь", "炎", "화염", "Ogień", "Ateş"),
 T("Frost", "Givre", "Frost", "Escarcha", "Gelo", "冰霜", "Лёд", "冷気", "냉기", "Mróz", "Ayaz"),
 T("Arcane", "Arcanes", "Arkan", "Arcano", "Arcano", "奥术", "Тайная магия", "秘術", "비전", "Tajemna magia", "Arkan"),
 T("Holy", "Sacré", "Heilig", "Sagrado", "Sagrado", "神圣", "Свет", "神聖", "신성", "Święty", "Kutsal"),
 T("Shadow", "Ombre", "Schatten", "Sombras", "Sombra", "暗影", "Тьма", "闇", "암흑", "Cień", "Gölge"),
]

def q(s): return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'
loc = open(D + "/Locale.lua", encoding="utf-8").read()
if '{ "Crit backdrop",' not in loc:
    def row(en, t):
        return "\t{ " + q(en) + ",\n\t\t" + ",\n\t\t".join(q(t[c]) for c in ("fr", "de", "es", "pt")) + " },\n"
    rows = "\t-- the damage numbers' crit backdrops (1.20.0)\n" + "".join(row(en, t) for en, t in P if ("{ " + q(en) + ",") not in loc)
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
