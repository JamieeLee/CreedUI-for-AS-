# 1.16.1: heals received beside the hero
import sys
D = sys.argv[1]
HERE = sys.path[0]
L = ["fr", "de", "es", "pt", "zh", "ru", "ja", "ko", "pl", "tr"]
def T(en, *vals):
    assert len(vals) == 10, en
    return (en, dict(zip(L, vals)))
P = [
 T("What hits you rises beside your hero as red numbers, heavier blows bigger; the health you get back rises in green on the other side.",
   "Ce qui vous frappe s'élève près de votre héros en chiffres rouges, les coups lourds plus gros ; la vie récupérée s'élève en vert de l'autre côté.",
   "Was dich trifft, steigt neben deinem Helden als rote Zahlen auf, schwere Treffer größer; zurückgewonnene Gesundheit steigt grün auf der anderen Seite auf.",
   "Lo que te golpea sube junto a tu héroe en números rojos, los golpes fuertes más grandes; la salud que recuperas sube en verde al otro lado.",
   "O que te atinge sobe ao lado do herói em números vermelhos, golpes pesados maiores; a vida recuperada sobe em verde do outro lado.",
   "你受到的伤害以红色数字在英雄旁升起，重击更大；恢复的生命以绿色数字在另一侧升起。",
   "Удары по вам всплывают у героя красными числами, тяжёлые крупнее; восстановленное здоровье — зелёными с другой стороны.",
   "受けたダメージが赤い数字で英雄の横に浮かび、重い一撃ほど大きく、回復した体力は反対側に緑で浮かびます。",
   "받은 피해가 영웅 옆에 빨간 숫자로 떠오르며 큰 타격일수록 커지고, 회복한 생명력은 반대쪽에 초록색으로 떠오릅니다.",
   "To, co cię trafia, unosi się przy bohaterze czerwonymi liczbami, mocne ciosy większe; odzyskane zdrowie unosi się na zielono z drugiej strony.",
   "Sana vuranlar kahramanının yanında kırmızı sayılarla yükselir, ağır darbeler daha büyük; geri kazandığın can diğer tarafta yeşil yükselir."),
]

def q(s): return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'
loc = open(D + "/Locale.lua", encoding="utf-8").read()
if 'the health you get back rises in green' not in loc:
    def row(en, t):
        return "\t{ " + q(en) + ",\n\t\t" + ",\n\t\t".join(q(t[c]) for c in ("fr", "de", "es", "pt")) + " },\n"
    rows = "\t-- heals received (1.16.1)\n" + "".join(row(en, t) for en, t in P if ("{ " + q(en) + ",") not in loc)
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
