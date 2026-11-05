# 1.18.1: new to the collection, in the loot window
import sys
D = sys.argv[1]
HERE = sys.path[0]
L = ["fr", "de", "es", "pt", "zh", "ru", "ja", "ko", "pl", "tr"]
def T(en, *vals):
    assert len(vals) == 10, en
    return (en, dict(zip(L, vals)))
P = [
 T("New", "Nouveau", "Neu", "Nuevo", "Novo", "新", "Новое", "新規", "새것", "Nowe", "Yeni"),
 T("New in your collection!", "Nouveau dans votre collection !", "Neu in deiner Sammlung!", "¡Nuevo en tu colección!", "Novo na sua coleção!", "收藏新增！", "Новое в вашей коллекции!", "コレクションに新しく追加！", "새로운 수집품!", "Nowość w twojej kolekcji!", "Koleksiyonunda yeni!"),
 T("Already in your collection.", "Déjà dans votre collection.", "Bereits in deiner Sammlung.", "Ya en tu colección.", "Já na sua coleção.", "已收藏。", "Уже в вашей коллекции.", "入手済みです。", "이미 수집함.", "Już w twojej kolekcji.", "Zaten koleksiyonunda."),
]

def q(s): return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'
loc = open(D + "/Locale.lua", encoding="utf-8").read()
if 'Already in your collection.' not in loc:
    def row(en, t):
        return "\t{ " + q(en) + ",\n\t\t" + ",\n\t\t".join(q(t[c]) for c in ("fr", "de", "es", "pt")) + " },\n"
    rows = "\t-- the loot window's collection tags (1.18.1)\n" + "".join(row(en, t) for en, t in P if ("{ " + q(en) + ",") not in loc)
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
