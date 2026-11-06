# 1.22.0: the stats window
import sys
D = sys.argv[1]
HERE = sys.path[0]
L = ["fr", "de", "es", "pt", "zh", "ru", "ja", "ko", "pl", "tr"]
def T(en, *vals):
    assert len(vals) == 10, en
    return (en, dict(zip(L, vals)))
P = [
 T("Stats", "Statistiques", "Werte", "Estadísticas", "Atributos", "属性", "Характеристики", "ステータス", "능력치", "Statystyki", "İstatistikler"),
 T("Vs Elites", "Contre élites", "Gegen Elite", "Contra élites", "Contra elites", "对精英", "Против элиты", "対エリート", "정예 대상", "Na elity", "Elitlere karşı"),
 T("Vs Controlled", "Contre contrôlés", "Gegen Kontrollierte", "Contra controlados", "Contra controlados", "对受控", "Против контроля", "対行動阻害", "제어 대상", "Na kontrolowanych", "Kontrol altındakilere"),
 T("Shielded", "Sous bouclier", "Abgeschirmt", "Con escudo", "Com escudo", "护盾时", "Под щитом", "シールド中", "보호막 중", "Pod tarczą", "Kalkanlıyken"),
 T("Pick the stats to show", "Choisir les stats affichées", "Angezeigte Werte wählen", "Elegir las estadísticas", "Escolher os atributos", "选择显示的属性", "Выбрать показатели", "表示するステータスを選ぶ", "표시할 능력치 선택", "Wybierz statystyki", "Gösterilecek istatistikleri seç"),
 T("Hide the stats window (Creed UI Options brings it back)", "Masquer la fenêtre des stats (les options de Creed UI la rappellent)", "Wertefenster ausblenden (Creed-UI-Optionen holen es zurück)", "Ocultar la ventana de estadísticas (las opciones de Creed UI la recuperan)", "Ocultar a janela de atributos (as opções do Creed UI a trazem de volta)", "隐藏属性窗口（Creed UI 选项可恢复）", "Скрыть окно характеристик (вернуть — в настройках Creed UI)", "ステータス窓を隠す（Creed UI の設定で戻せます）", "능력치 창 숨기기 (Creed UI 설정에서 되돌림)", "Ukryj okno statystyk (opcje Creed UI je przywrócą)", "İstatistik penceresini gizle (Creed UI ayarları geri getirir)"),
 T("the stats window stopped after an error: ", "la fenêtre des stats s'est arrêtée après une erreur : ", "das Wertefenster stoppte nach einem Fehler: ", "la ventana de estadísticas se detuvo tras un error: ", "a janela de atributos parou após um erro: ", "属性窗口出错后停止：", "окно характеристик остановлено после ошибки: ", "ステータス窓はエラーで停止しました：", "능력치 창이 오류로 멈췄습니다: ", "okno statystyk zatrzymało się po błędzie: ", "istatistik penceresi bir hatadan sonra durdu: "),
 T("Your run's stats at a glance, grouped (Offense, Survival, Area and DoTs, Run); a change flashes green going up, red going down. The + in its head picks the stats it shows.",
   "Les stats de la partie d'un coup d'œil, groupées (Attaque, Survie, Zone et DoT, Partie) ; un changement brille en vert s'il monte, en rouge s'il baisse. Le + de son en-tête choisit les stats affichées.",
   "Die Werte des Laufs auf einen Blick, gruppiert (Angriff, Überleben, Fläche und DoTs, Lauf); eine Änderung leuchtet grün nach oben, rot nach unten. Das + im Kopf wählt die angezeigten Werte.",
   "Las estadísticas de la partida de un vistazo, agrupadas (Ataque, Supervivencia, Área y DoT, Partida); un cambio brilla en verde al subir y en rojo al bajar. El + de su cabecera elige las que muestra.",
   "Os atributos da partida num relance, agrupados (Ataque, Sobrevivência, Área e DoTs, Partida); uma mudança brilha verde ao subir e vermelha ao descer. O + no topo escolhe os que mostra.",
   "一眼看清本局属性，分组显示（进攻、生存、范围与持续伤害、本局）；数值上升闪绿，下降闪红。标题上的 + 可选择显示的属性。",
   "Характеристики забега одним взглядом, по группам (Атака, Выживание, Область и DoT, Забег); рост вспыхивает зелёным, падение — красным. Кнопка + в заголовке выбирает показатели.",
   "ランのステータスを一目で、グループ別に（攻撃、生存、範囲とDoT、ラン）。上がると緑、下がると赤に光ります。見出しの + で表示するステータスを選べます。",
   "이번 판의 능력치를 한눈에, 묶어서 (공격, 생존, 범위와 지속 피해, 판); 오르면 초록, 내리면 빨강으로 빛납니다. 머리의 + 로 표시할 능력치를 고릅니다.",
   "Statystyki rozgrywki w skrócie, w grupach (Atak, Przetrwanie, Obszar i DoT, Rozgrywka); wzrost błyska na zielono, spadek na czerwono. Przycisk + w nagłówku wybiera statystyki.",
   "Koşunun istatistikleri bir bakışta, gruplu (Saldırı, Hayatta kalma, Alan ve DoT, Koşu); artış yeşil, düşüş kırmızı yanar. Başlıktaki + gösterilecekleri seçer."),
]

def q(s): return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'
loc = open(D + "/Locale.lua", encoding="utf-8").read()
if "{ \"Pick the stats to show\"," not in loc:
    def row(en, t):
        return "\t{ " + q(en) + ",\n\t\t" + ",\n\t\t".join(q(t[c]) for c in ("fr", "de", "es", "pt")) + " },\n"
    rows = "\t-- the stats window (1.22.0)\n" + "".join(row(en, t) for en, t in P if ("{ " + q(en) + ",") not in loc)
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
