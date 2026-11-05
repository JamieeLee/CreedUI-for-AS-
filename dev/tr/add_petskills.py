# 1.16.2: the pets' skills on the pet bar
import sys
D = sys.argv[1]
HERE = sys.path[0]
L = ["fr", "de", "es", "pt", "zh", "ru", "ja", "ko", "pl", "tr"]
def T(en, *vals):
    assert len(vals) == 10, en
    return (en, dict(zip(L, vals)))
P = [
 T("Melee", "Mêlée", "Nahkampf", "Cuerpo a cuerpo", "Corpo a corpo", "近战", "Ближний бой", "近接攻撃", "근접 공격", "Walka wręcz", "Yakın dövüş"),
 T("Bite", "Morsure", "Beißen", "Mordisco", "Mordida", "撕咬", "Укус", "噛みつき", "물기", "Ugryzienie", "Isırık"),
 T("Kill Command", "Ordre de tuer", "Tötungsbefehl", "Matar", "Comando para Matar", "杀戮命令", "Команда «Взять!»", "キルコマンド", "살상 명령", "Rozkaz zabicia", "Öldür komutu"),
 T("Bestial Wrath", "Courroux bestial", "Zorn des Wildtiers", "Cólera de las bestias", "Ira Bestial", "狂野怒火", "Звериный гнев", "ビーストラス", "야수의 격노", "Zwierzęcy gniew", "Hayvani gazap"),
 T("Raptor Strike", "Attaque du raptor", "Raptorstoß", "Golpe de raptor", "Golpe do Raptor", "猛禽一击", "Удар ящера", "ラプターストライク", "랩터의 일격", "Cios raptora", "Raptor darbesi"),
 T("Frostbolt", "Éclair de givre", "Frostblitz", "Descarga de Escarcha", "Seta de Gelo", "寒冰箭", "Ледяная стрела", "フロストボルト", "얼음 화살", "Lodowy pocisk", "Buz oku"),
 T("Firebolt", "Éclair de feu", "Feuerblitz", "Descarga de fuego", "Seta de Fogo", "火焰箭", "Огненная стрела", "ファイアボルト", "화염 화살", "Ognisty pocisk", "Ateş oku"),
 T("Shadow Cleave", "Enchaînement de l'ombre", "Schattenspalten", "Rajar de las Sombras", "Clivar Sombrio", "暗影顺劈", "Теневой раскол", "シャドウクリーブ", "어둠의 회전베기", "Cios cienia", "Gölge yarması"),
 T("Cleave", "Enchaînement", "Spalten", "Rajar", "Clivar", "顺劈斩", "Рассекающий удар", "クリーブ", "회전베기", "Rozpłatanie", "Yarma"),
 T("Hellfire", "Flammes infernales", "Höllenfeuer", "Fuego infernal", "Fogo do Inferno", "地狱烈焰", "Адское пламя", "ヘルファイア", "지옥의 불길", "Piekielny ogień", "Cehennem ateşi"),
 T("Shadow Bolt", "Trait de l'ombre", "Schattenblitz", "Descarga de las Sombras", "Seta Sombria", "暗影箭", "Стрела Тьмы", "シャドウボルト", "어둠의 화살", "Pocisk cienia", "Gölge oku"),
]

def q(s): return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'
loc = open(D + "/Locale.lua", encoding="utf-8").read()
if '{ "Shadow Cleave",' not in loc:
    def row(en, t):
        return "\t{ " + q(en) + ",\n\t\t" + ",\n\t\t".join(q(t[c]) for c in ("fr", "de", "es", "pt")) + " },\n"
    rows = "\t-- the pets' skills (1.16.2)\n" + "".join(row(en, t) for en, t in P if ("{ " + q(en) + ",") not in loc)
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
