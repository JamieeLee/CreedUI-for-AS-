# 1.16.1: what a pet's skill hits for
import sys
D = sys.argv[1]
HERE = sys.path[0]
L = ["fr", "de", "es", "pt", "zh", "ru", "ja", "ko", "pl", "tr"]
def T(en, *vals):
    assert len(vals) == 10, en
    return (en, dict(zip(L, vals)))
P = [
 T("Hits for", "Frappe pour", "Trifft für", "Golpea por", "Acerta por", "每次命中", "Бьёт на", "1回のダメージ", "타격당", "Trafia za", "Vuruş"),
 T("Usually", "En général", "Meistens", "Normalmente", "Normalmente", "通常", "Обычно", "通常", "보통", "Zwykle", "Genelde"),
 T("Its value shows once it hits.", "Sa valeur s'affiche dès qu'il touche.", "Ihr Wert erscheint, sobald sie trifft.", "Su valor aparece en cuanto golpea.", "Seu valor aparece assim que acerta.", "命中后会显示其数值。", "Значение появится после первого удара.", "当たると数値が表示されます。", "적중하면 수치가 표시됩니다.", "Wartość pojawi się po trafieniu.", "Vurduğunda değeri görünür."),
]

def q(s): return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'
loc = open(D + "/Locale.lua", encoding="utf-8").read()
if '{ "Hits for",' not in loc:
    def row(en, t):
        return "\t{ " + q(en) + ",\n\t\t" + ",\n\t\t".join(q(t[c]) for c in ("fr", "de", "es", "pt")) + " },\n"
    rows = "\t-- the pet skills' values (1.16.1)\n" + "".join(row(en, t) for en, t in P if ("{ " + q(en) + ",") not in loc)
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
