# 1.17.3: marks in the loot window
import sys
D = sys.argv[1]
HERE = sys.path[0]
L = ["fr", "de", "es", "pt", "zh", "ru", "ja", "ko", "pl", "tr"]
def T(en, *vals):
    assert len(vals) == 10, en
    return (en, dict(zip(L, vals)))
P = [
 T("{1} in all", "{1} au total", "insgesamt {1}", "{1} en total", "{1} no total", "共 {1}", "всего {1}", "合計 {1}", "총 {1}", "łącznie {1}", "toplam {1}"),
 T("The run's loot in a small window: the marks you earned, then the gear that dropped for you, newest first, with its icon and rarity. Point at one for its tooltip.",
   "Le butin de la partie dans une petite fenêtre : les marques gagnées, puis l'équipement tombé pour vous, le plus récent d'abord, avec son icône et sa rareté. Survolez-en un pour son infobulle.",
   "Die Beute des Laufs in einem kleinen Fenster: die verdienten Marken, dann die Ausrüstung, die für dich fiel, die neueste zuerst, mit Symbol und Seltenheit. Zeige auf eine für ihren Tooltip.",
   "El botín de la partida en una ventanita: las marcas ganadas y luego el equipo que cayó para ti, el más nuevo primero, con su icono y rareza. Señala uno para ver su descripción.",
   "O saque da partida numa janelinha: as marcas ganhas e depois o equipamento que caiu para você, o mais novo primeiro, com ícone e raridade. Aponte para um para ver a dica.",
   "小窗口显示本局战利品：获得的印记，然后是为你掉落的装备，最新的在前，带图标和品质。指向物品可查看提示。",
   "Добыча забега в маленьком окне: заработанные знаки, затем выпавшее вам снаряжение, новое сверху, со значком и редкостью. Наведите на предмет, чтобы увидеть подсказку。".replace("。", "."),
   "周回の戦利品を小さなウィンドウに：獲得したマーク、そしてドロップした装備を新しい順に、アイコンとレア度付きで。指すとツールチップを表示。",
   "이번 판의 전리품을 작은 창에: 얻은 징표, 그리고 떨어진 장비를 최신순으로 아이콘과 등급과 함께. 가리키면 툴팁이 나옵니다.",
   "Łup biegu w małym oknie: zdobyte znaki, potem sprzęt, który dla ciebie wypadł, najnowszy pierwszy, z ikoną i rzadkością. Wskaż jeden, by zobaczyć opis.",
   "Koşunun ganimeti küçük bir pencerede: kazandığın nişanlar, sonra senin için düşen teçhizat, en yenisi önce, simgesi ve nadirliğiyle. Açıklaması için birinin üstüne gel."),
]

def q(s): return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'
loc = open(D + "/Locale.lua", encoding="utf-8").read()
if '{ "{1} in all",' not in loc:
    def row(en, t):
        return "\t{ " + q(en) + ",\n\t\t" + ",\n\t\t".join(q(t[c]) for c in ("fr", "de", "es", "pt")) + " },\n"
    rows = "\t-- the loot window's marks (1.17.3)\n" + "".join(row(en, t) for en, t in P if ("{ " + q(en) + ",") not in loc)
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
