# 1.21.0: the class themes
import sys
D = sys.argv[1]
HERE = sys.path[0]
L = ["fr", "de", "es", "pt", "zh", "ru", "ja", "ko", "pl", "tr"]
def T(en, *vals):
    assert len(vals) == 10, en
    return (en, dict(zip(L, vals)))
P = [
 T("Theme: {1}", "Thème : {1}", "Thema: {1}", "Tema: {1}", "Tema: {1}", "主题：{1}", "Тема: {1}", "テーマ：{1}", "테마: {1}", "Motyw: {1}", "Tema: {1}"),
 T("theme: {1}", "thème : {1}", "Thema: {1}", "tema: {1}", "tema: {1}", "主题：{1}", "тема: {1}", "テーマ：{1}", "테마: {1}", "motyw: {1}", "tema: {1}"),
 T("/creed theme followed by one of: {1}", "/creed theme suivi de : {1}", "/creed theme gefolgt von: {1}", "/creed theme seguido de: {1}", "/creed theme seguido de: {1}", "/creed theme 后接其一：{1}", "/creed theme и одно из: {1}", "/creed theme の後に次のいずれか：{1}", "/creed theme 뒤에 다음 중 하나: {1}", "/creed theme, a po nim jedno z: {1}", "/creed theme ardından şunlardan biri: {1}"),
 T("Bronze", "Bronze", "Bronze", "Bronce", "Bronze", "青铜", "Бронза", "ブロンズ", "청동", "Brąz", "Bronz"),
 T("Your class", "Votre classe", "Deine Klasse", "Tu clase", "Sua classe", "你的职业", "Ваш класс", "あなたのクラス", "내 직업", "Twoja klasa", "Sınıfın"),
 T("Warrior", "Guerrier", "Krieger", "Guerrero", "Guerreiro", "战士", "Воин", "ウォーリアー", "전사", "Wojownik", "Savaşçı"),
 T("Paladin", "Paladin", "Paladin", "Paladín", "Paladino", "圣骑士", "Паладин", "パラディン", "성기사", "Paladyn", "Paladin"),
 T("Hunter", "Chasseur", "Jäger", "Cazador", "Caçador", "猎人", "Охотник", "ハンター", "사냥꾼", "Łowca", "Avcı"),
 T("Rogue", "Voleur", "Schurke", "Pícaro", "Ladino", "潜行者", "Разбойник", "ローグ", "도적", "Łotr", "Haydut"),
 T("Priest", "Prêtre", "Priester", "Sacerdote", "Sacerdote", "牧师", "Жрец", "プリースト", "사제", "Kapłan", "Rahip"),
 T("Shaman", "Chaman", "Schamane", "Chamán", "Xamã", "萨满祭司", "Шаман", "シャーマン", "주술사", "Szaman", "Şaman"),
 T("Mage", "Mage", "Magier", "Mago", "Mago", "法师", "Маг", "メイジ", "마법사", "Mag", "Büyücü"),
 T("Warlock", "Démoniste", "Hexenmeister", "Brujo", "Bruxo", "术士", "Чернокнижник", "ウォーロック", "흑마법사", "Czarnoksiężnik", "Kara Büyücü"),
 T("Druid", "Druide", "Druide", "Druida", "Druida", "德鲁伊", "Друид", "ドルイド", "드루이드", "Druid", "Druid"),
]

def q(s): return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'
loc = open(D + "/Locale.lua", encoding="utf-8").read()
if "{ \"Theme: {1}\"," not in loc:
    def row(en, t):
        return "\t{ " + q(en) + ",\n\t\t" + ",\n\t\t".join(q(t[c]) for c in ("fr", "de", "es", "pt")) + " },\n"
    rows = "\t-- the class themes (1.21.0)\n" + "".join(row(en, t) for en, t in P if ("{ " + q(en) + ",") not in loc)
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
