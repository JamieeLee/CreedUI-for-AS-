# 1.19.0: the loot pop-up
import sys
D = sys.argv[1]
HERE = sys.path[0]
L = ["fr", "de", "es", "pt", "zh", "ru", "ja", "ko", "pl", "tr"]
def T(en, *vals):
    assert len(vals) == 10, en
    return (en, dict(zip(L, vals)))
P = [
 T("Marks", "Marques", "Marken", "Marcas", "Marcas", "印记", "Знаки", "マーク", "징표", "Znaki", "Nişanlar"),
 T("+{1} marks", "+{1} marques", "+{1} Marken", "+{1} marcas", "+{1} marcas", "+{1} 枚印记", "+{1} знаков", "+{1} マーク", "징표 +{1}", "Znaki: +{1}", "+{1} nişan"),
 T("Your own loot pop-up in Creed UI's look: each drop with its icon, its name and whether it's new to your collection, and the marks you earn. Replaces the game's pop-up.",
   "Votre fenêtre de butin au style de Creed UI : chaque objet avec son icône, son nom et s'il est nouveau dans votre collection, et les marques gagnées. Remplace celle du jeu.",
   "Ein eigenes Beute-Popup im Stil von Creed UI: jeder Fund mit Symbol, Name und ob er neu in deiner Sammlung ist, und die verdienten Marken. Ersetzt das Popup des Spiels.",
   "Tu propio aviso de botín con el estilo de Creed UI: cada objeto con su icono, su nombre y si es nuevo en tu colección, y las marcas que ganas. Sustituye al del juego.",
   "Seu próprio aviso de saque no estilo do Creed UI: cada item com ícone, nome e se é novo na sua coleção, e as marcas que você ganha. Substitui o do jogo.",
   "Creed UI 风格的战利品弹窗：每件掉落的图标、名称以及是否为收藏新增，还有获得的印记。取代游戏自带的弹窗。",
   "Своё окно добычи в стиле Creed UI: каждый предмет со значком, названием и пометкой, новый ли он в коллекции, и заработанные знаки. Заменяет окно игры.",
   "Creed UI の見た目の戦利品ポップアップ：ドロップのアイコン、名前、コレクションに新しいかどうか、獲得したマーク。ゲームのポップアップの代わりになります。",
   "Creed UI 모양의 전리품 알림: 아이템마다 아이콘, 이름, 새 수집품인지, 그리고 얻은 징표. 게임의 알림을 대신합니다.",
   "Własne okienko łupu w stylu Creed UI: każdy przedmiot z ikoną, nazwą i informacją, czy jest nowy w kolekcji, oraz zdobyte znaki. Zastępuje okienko gry.",
   "Creed UI görünümünde kendi ganimet bildirimin: her düşen eşya simgesi, adı ve koleksiyonunda yeni olup olmadığıyla, bir de kazandığın nişanlar. Oyunun bildiriminin yerini alır."),
 T("the loot pop-up stopped after an error, so the game's own is back: ", "la fenêtre de butin s'est arrêtée après une erreur, celle du jeu revient : ", "das Beute-Popup wurde nach einem Fehler gestoppt, das des Spiels ist zurück: ", "el aviso de botín se detuvo tras un error, vuelve el del juego: ", "o aviso de saque parou após um erro, o do jogo voltou: ", "战利品弹窗因错误停止，已恢复游戏自带的：", "окно добычи остановлено после ошибки, вернулось окно игры: ", "エラーのため戦利品ポップアップを止め、ゲームのものに戻しました: ", "오류로 전리품 알림이 멈춰 게임의 알림으로 돌아갑니다: ", "okienko łupu zatrzymało się po błędzie, wraca to z gry: ", "ganimet bildirimi bir hatadan sonra durdu, oyununki geri geldi: "),
]

def q(s): return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'
loc = open(D + "/Locale.lua", encoding="utf-8").read()
if '{ "+{1} marks",' not in loc:
    def row(en, t):
        return "\t{ " + q(en) + ",\n\t\t" + ",\n\t\t".join(q(t[c]) for c in ("fr", "de", "es", "pt")) + " },\n"
    rows = "\t-- the loot pop-up (1.19.0)\n" + "".join(row(en, t) for en, t in P if ("{ " + q(en) + ",") not in loc)
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
