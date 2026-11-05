# 1.17.0: the run's loot window
import sys
D = sys.argv[1]
HERE = sys.path[0]
L = ["fr", "de", "es", "pt", "zh", "ru", "ja", "ko", "pl", "tr"]
def T(en, *vals):
    assert len(vals) == 10, en
    return (en, dict(zip(L, vals)))
P = [
 T("Loot", "Butin", "Beute", "Botín", "Saque", "战利品", "Добыча", "戦利品", "전리품", "Łup", "Ganimet"),
 T("Nothing yet this run.", "Rien encore cette partie.", "Noch nichts in diesem Lauf.", "Nada aún en esta partida.", "Nada ainda nesta partida.", "本局还没有收获。", "Пока ничего в этом забеге.", "この周回ではまだ何もありません。", "이번 판에는 아직 없습니다.", "Na razie nic w tym biegu.", "Bu koşuda henüz bir şey yok."),
 T("and {1} more", "et {1} de plus", "und {1} weitere", "y {1} más", "e mais {1}", "还有 {1} 件", "и ещё {1}", "ほか {1} 個", "외 {1}개", "i {1} więcej", "ve {1} tane daha"),
 T("The run's loot in a small window: its gold and caches, then every item you received, newest first, with its icon and rarity. Point at one for its tooltip.",
   "Le butin de la partie dans une petite fenêtre : son or et ses caches, puis chaque objet reçu, le plus récent d'abord, avec son icône et sa rareté. Survolez-en un pour son infobulle.",
   "Die Beute des Laufs in einem kleinen Fenster: Gold und Verstecke, dann jeder erhaltene Gegenstand, der neueste zuerst, mit Symbol und Seltenheit. Zeige auf einen für seinen Tooltip.",
   "El botín de la partida en una ventanita: su oro y alijos, y luego cada objeto recibido, el más nuevo primero, con su icono y rareza. Señala uno para ver su descripción.",
   "O saque da partida numa janelinha: ouro e esconderijos, depois cada item recebido, o mais novo primeiro, com ícone e raridade. Aponte para um para ver a dica.",
   "小窗口显示本局战利品：金币和宝箱，然后是你获得的每件物品，最新的在前，带图标和品质。指向物品可查看提示。",
   "Добыча забега в маленьком окне: золото и тайники, затем каждый полученный предмет, новые сверху, со значком и редкостью. Наведите на предмет, чтобы увидеть подсказку.",
   "周回の戦利品を小さなウィンドウに：ゴールドとキャッシュ、そして手に入れたアイテムを新しい順に、アイコンとレア度付きで。指すとツールチップを表示。",
   "이번 판의 전리품을 작은 창에: 골드와 보물 상자, 그리고 받은 아이템을 최신순으로 아이콘과 등급과 함께. 가리키면 툴팁이 나옵니다.",
   "Łup biegu w małym oknie: złoto i skrzynie, potem każdy otrzymany przedmiot, najnowszy pierwszy, z ikoną i rzadkością. Wskaż jeden, by zobaczyć opis.",
   "Koşunun ganimeti küçük bir pencerede: altını ve sandıkları, sonra aldığın her eşya, en yenisi önce, simgesi ve nadirliğiyle. Açıklaması için birinin üstüne gel."),
 T("the loot window stopped after an error: ", "la fenêtre de butin s'est arrêtée après une erreur : ", "das Beutefenster wurde nach einem Fehler gestoppt: ", "la ventana de botín se detuvo tras un error: ", "a janela de saque parou após um erro: ", "战利品窗口因错误停止：", "окно добычи остановлено после ошибки: ", "エラーのため戦利品ウィンドウを止めました: ", "오류로 전리품 창이 멈췄습니다: ", "okno łupu zatrzymało się po błędzie: ", "ganimet penceresi bir hatadan sonra durdu: "),
]

def q(s): return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'
loc = open(D + "/Locale.lua", encoding="utf-8").read()
if 'Nothing yet this run.' not in loc:
    def row(en, t):
        return "\t{ " + q(en) + ",\n\t\t" + ",\n\t\t".join(q(t[c]) for c in ("fr", "de", "es", "pt")) + " },\n"
    rows = "\t-- the loot window (1.17.0)\n" + "".join(row(en, t) for en, t in P if ("{ " + q(en) + ",") not in loc)
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
