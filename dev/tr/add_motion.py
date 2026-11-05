# 1.16.0: the damage numbers' four motions
import sys
D = sys.argv[1]
HERE = sys.path[0]
L = ["fr", "de", "es", "pt", "zh", "ru", "ja", "ko", "pl", "tr"]
def T(en, *vals):
    assert len(vals) == 10, en
    return (en, dict(zip(L, vals)))
P = [
 T("Motion", "Mouvement", "Bewegung", "Movimiento", "Movimento", "动态", "Движение", "動き", "움직임", "Ruch", "Hareket"),
 T("motion: ", "mouvement : ", "Bewegung: ", "movimiento: ", "movimento: ", "动态：", "движение: ", "動き: ", "움직임: ", "ruch: ", "hareket: "),
 T("/creed numbers smooth, fountain, rise or impact - how the numbers move", "/creed numbers smooth, fountain, rise ou impact - le mouvement des chiffres", "/creed numbers smooth, fountain, rise oder impact - wie sich die Zahlen bewegen", "/creed numbers smooth, fountain, rise o impact - cómo se mueven los números", "/creed numbers smooth, fountain, rise ou impact - como os números se movem", "/creed numbers smooth、fountain、rise 或 impact - 数字的动态", "/creed numbers smooth, fountain, rise или impact - как движутся числа", "/creed numbers smooth、fountain、rise、impact - 数字の動き", "/creed numbers smooth, fountain, rise, impact - 숫자의 움직임", "/creed numbers smooth, fountain, rise lub impact - jak poruszają się liczby", "/creed numbers smooth, fountain, rise veya impact - sayıların hareketi"),
 T("Smooth", "Douce", "Sanft", "Suave", "Suave", "平滑", "Плавно", "なめらか", "부드럽게", "Płynnie", "Yumuşak"),
 T("Fountain", "Fontaine", "Fontäne", "Fuente", "Fonte", "喷泉", "Фонтан", "噴水", "분수", "Fontanna", "Çeşme"),
 T("Rise", "Montée", "Aufstieg", "Ascenso", "Subida", "上升", "Подъём", "上昇", "상승", "Wznoszenie", "Yükseliş"),
 T("Impact", "Impact", "Wucht", "Impacto", "Impacto", "冲击", "Удар", "衝撃", "충격", "Uderzenie", "Darbe"),
 T("Numbers drift up gently and melt away.", "Les chiffres montent doucement puis s'effacent.", "Die Zahlen steigen sanft auf und verblassen.", "Los números suben suavemente y se desvanecen.", "Os números sobem suavemente e somem.", "数字缓缓上升后淡出。", "Числа плавно поднимаются и тают.", "数字がゆっくり上がって消えます。", "숫자가 천천히 올라가며 사라집니다.", "Liczby łagodnie unoszą się i znikają.", "Sayılar yavaşça yükselip kaybolur."),
 T("Numbers arc up and fall away to the side.", "Les chiffres jaillissent en arc et retombent sur le côté.", "Die Zahlen fliegen im Bogen hoch und fallen zur Seite.", "Los números saltan en arco y caen hacia un lado.", "Os números sobem em arco e caem para o lado.", "数字呈弧线跃起，向一侧落下。", "Числа взлетают дугой и падают в сторону.", "数字が弧を描いて跳ね、横へ落ちます。", "숫자가 호를 그리며 튀어 올라 옆으로 떨어집니다.", "Liczby wylatują łukiem i opadają w bok.", "Sayılar kavis çizerek yükselir ve yana düşer."),
 T("Numbers scroll straight up, quickly.", "Les chiffres défilent tout droit vers le haut, vite.", "Die Zahlen ziehen schnell gerade nach oben.", "Los números suben rectos y rápido.", "Os números sobem retos e rápido.", "数字快速笔直向上滚动。", "Числа быстро уходят прямо вверх.", "数字がまっすぐ素早く上へ流れます。", "숫자가 빠르게 곧장 위로 올라갑니다.", "Liczby szybko suną prosto w górę.", "Sayılar hızla dümdüz yukarı kayar."),
 T("Numbers punch in big and stay put; crits shake.", "Les chiffres frappent en grand et restent en place ; les critiques tremblent.", "Die Zahlen schlagen groß ein und bleiben stehen; Kritische beben.", "Los números entran grandes y se quedan quietos; los críticos tiemblan.", "Os números entram grandes e ficam parados; críticos tremem.", "数字大幅弹出并停在原处；暴击会震动。", "Числа появляются крупно и стоят на месте; криты дрожат.", "数字が大きく飛び出してその場に留まり、クリティカルは揺れます。", "숫자가 크게 튀어나와 제자리에 머물고, 치명타는 흔들립니다.", "Liczby wskakują duże i stoją w miejscu; krytyki drżą.", "Sayılar büyük çıkar ve yerinde kalır; kritikler titrer."),
]

def q(s): return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'
loc = open(D + "/Locale.lua", encoding="utf-8").read()
if '{ "Motion",' not in loc:
    def row(en, t):
        return "\t{ " + q(en) + ",\n\t\t" + ",\n\t\t".join(q(t[c]) for c in ("fr", "de", "es", "pt")) + " },\n"
    rows = "\t-- the damage numbers' motions (1.16.0)\n" + "".join(row(en, t) for en, t in P if ("{ " + q(en) + ",") not in loc)
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
