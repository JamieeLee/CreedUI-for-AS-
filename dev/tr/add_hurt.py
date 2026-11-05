# 1.14.3: damage taken by the hero
import sys
D = sys.argv[1]
HERE = sys.path[0]
L = ["fr", "de", "es", "pt", "zh", "ru", "ja", "ko", "pl", "tr"]
def T(en, *vals):
    assert len(vals) == 10, en
    return (en, dict(zip(L, vals)))
P = [
 T("Pet", "Familier", "Begleiter", "Mascota", "Mascote", "宠物", "Питомец", "ペット", "소환수", "Zwierzak", "Evcil hayvan"),
 T("Scholomance", "Scholomance", "Scholomance", "Scholomance", "Scholomance", "通灵学院", "Некроситет", "スカロマンス", "스칼로맨스", "Scholomance", "Scholomance"),
 T("What hits you rises beside your hero as red numbers, heavier blows bigger.",
   "Ce qui vous frappe s'élève près de votre héros en chiffres rouges, les coups lourds plus gros.",
   "Was dich trifft, steigt neben deinem Helden als rote Zahlen auf, schwere Treffer größer.",
   "Lo que te golpea sube junto a tu héroe en números rojos, los golpes fuertes más grandes.",
   "O que te atinge sobe ao lado do herói em números vermelhos, golpes pesados maiores.",
   "你受到的伤害以红色数字在英雄旁升起，重击更大。",
   "Удары по вам всплывают у героя красными числами, тяжёлые крупнее.",
   "受けたダメージが赤い数字で英雄の横に浮かび、重い一撃ほど大きく。",
   "받은 피해가 영웅 옆에 빨간 숫자로 떠오르며, 큰 타격일수록 커집니다.",
   "To, co cię trafia, unosi się przy bohaterze czerwonymi liczbami, mocne ciosy większe.",
   "Sana vuranlar kahramanının yanında kırmızı sayılarla yükselir, ağır darbeler daha büyük."),
 T("the damage you take stopped showing after an error: ",
   "les dégâts subis ne s'affichent plus après une erreur : ",
   "der erlittene Schaden wird nach einem Fehler nicht mehr gezeigt: ",
   "el daño recibido dejó de mostrarse tras un error: ",
   "o dano sofrido deixou de aparecer após um erro: ",
   "受到的伤害因错误停止显示：",
   "получаемый урон больше не показывается после ошибки: ",
   "エラーのため受けたダメージの表示を止めました: ",
   "오류로 받은 피해 표시가 멈췄습니다: ",
   "otrzymywane obrażenia przestały się wyświetlać po błędzie: ",
   "bir hatadan sonra alınan hasar artık gösterilmiyor: "),
]

def q(s): return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'
loc = open(D + "/Locale.lua", encoding="utf-8").read()
if '{ "Pet",' not in loc:
    def row(en, t):
        return "\t{ " + q(en) + ",\n\t\t" + ",\n\t\t".join(q(t[c]) for c in ("fr", "de", "es", "pt")) + " },\n"
    rows = "\t-- the meter's Pet line (1.14.3)\n" + "".join(row(en, t) for en, t in P if ("{ " + q(en) + ",") not in loc)
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
