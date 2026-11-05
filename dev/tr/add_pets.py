# 1.15.0: the pet bar and the cache marks
import sys
D = sys.argv[1]
HERE = sys.path[0]
L = ["fr", "de", "es", "pt", "zh", "ru", "ja", "ko", "pl", "tr"]
def T(en, *vals):
    assert len(vals) == 10, en
    return (en, dict(zip(L, vals)))
P = [
 T("Pet bar", "Barre du familier", "Begleiterleiste", "Barra de mascota", "Barra do mascote", "宠物栏", "Панель питомца", "ペットバー", "소환수 바", "Pasek zwierzaka", "Evcil hayvan çubuğu"),
 T("Over the skill bar on the left: your pet's own buttons (click to use, right-click for autocast), or each kind of summon you have out with its count, time left and the skills it has used.",
   "Au-dessus de la barre de sorts, à gauche : les boutons de votre familier (clic pour utiliser, clic droit pour l'auto-lancer), ou chaque sorte d'invocation avec son nombre, son temps restant et les techniques qu'elle a utilisées.",
   "Über der Fähigkeitsleiste links: die Tasten deines Begleiters (Klick zum Benutzen, Rechtsklick für automatisches Wirken) oder jede Art Beschwörung mit Anzahl, Restzeit und den Fähigkeiten, die sie benutzt hat.",
   "Sobre la barra de habilidades, a la izquierda: los botones de tu mascota (clic para usar, clic derecho para el lanzamiento automático), o cada tipo de invocación con su número, su tiempo restante y las habilidades que ha usado.",
   "Sobre a barra de habilidades, à esquerda: os botões do seu mascote (clique para usar, clique direito para lançamento automático), ou cada tipo de invocação com quantidade, tempo restante e as habilidades que usou.",
   "技能栏上方左侧：宠物自己的按钮（点击使用，右键切换自动施放），或每种召唤物的数量、剩余时间和它用过的技能。",
   "Над панелью умений слева: кнопки питомца (щелчок — применить, правый щелчок — автоприменение) или каждый вид призванных с числом, оставшимся временем и умениями, которые он применял.",
   "スキルバーの上の左側：ペットのボタン（クリックで使用、右クリックで自動詠唱）、または召喚物の種類ごとの数、残り時間、使ったスキル。",
   "스킬 바 위 왼쪽: 소환수의 버튼(클릭하여 사용, 오른쪽 클릭으로 자동 시전), 또는 소환물 종류마다 수, 남은 시간, 사용한 기술.",
   "Nad paskiem umiejętności po lewej: przyciski zwierzaka (klik, by użyć, prawy klik — automatyczne rzucanie) albo każdy rodzaj przywołańca z liczbą, pozostałym czasem i użytymi umiejętnościami.",
   "Yetenek çubuğunun üstünde solda: evcil hayvanının düğmeleri (kullanmak için tıkla, otomatik kullanım için sağ tıkla) ya da her çağırma türü sayısı, kalan süresi ve kullandığı yeteneklerle."),
 T("{1} out", "{1} invoqués", "{1} da", "{1} invocados", "{1} invocados", "{1} 个在场", "призвано: {1}", "{1} 体", "{1}마리", "{1} przywołanych", "{1} tane"),
 T("{1} s left", "{1} s restantes", "noch {1} s", "quedan {1} s", "restam {1} s", "剩余 {1} 秒", "осталось {1} с", "残り {1} 秒", "{1}초 남음", "zostało {1} s", "{1} sn kaldı"),
 T("Its skills show here once it uses them.", "Ses techniques s'affichent ici dès qu'il les utilise.", "Seine Fähigkeiten erscheinen hier, sobald er sie benutzt.", "Sus habilidades aparecen aquí en cuanto las usa.", "Suas habilidades aparecem aqui assim que as usa.", "它用过技能后会显示在这里。", "Его умения появятся здесь, как только он их применит.", "スキルは使うとここに表示されます。", "기술을 사용하면 여기에 표시됩니다.", "Jego umiejętności pojawią się tu, gdy ich użyje.", "Yeteneklerini kullandıkça burada görünür."),
 T("the pet bar stopped after an error: ", "la barre du familier s'est arrêtée après une erreur : ", "die Begleiterleiste wurde nach einem Fehler gestoppt: ", "la barra de mascota se detuvo tras un error: ", "a barra do mascote parou após um erro: ", "宠物栏因错误停止：", "панель питомца остановлена после ошибки: ", "エラーのためペットバーを止めました: ", "오류로 소환수 바가 멈췄습니다: ", "pasek zwierzaka zatrzymał się po błędzie: ", "evcil hayvan çubuğu bir hatadan sonra durdu: "),
 T("A skull over each boss and awake guardian, and a gold chest over each cache, wherever they are on the screen: large when near, small when far.",
   "Un crâne au-dessus de chaque boss et gardien éveillé, et un coffre doré au-dessus de chaque cache, où qu'ils soient à l'écran : grands de près, petits de loin.",
   "Ein Schädel über jedem Boss und wachen Wächter und eine goldene Truhe über jedem Versteck, wo immer sie auf dem Bildschirm sind: groß, wenn nah, klein, wenn fern.",
   "Una calavera sobre cada jefe y guardián despierto, y un cofre dorado sobre cada alijo, estén donde estén en pantalla: grandes de cerca, pequeños de lejos.",
   "Uma caveira sobre cada chefe e guardião desperto, e um baú dourado sobre cada esconderijo, onde quer que estejam na tela: grandes de perto, pequenos de longe.",
   "每个首领和醒着的守护者头上有骷髅，每个宝箱上有金色箱子，无论在屏幕何处：近大远小。",
   "Череп над каждым боссом и бодрствующим стражем и золотой сундук над каждым тайником, где бы они ни были на экране: вблизи крупнее, вдали меньше.",
   "各ボスと目覚めたガーディアンの上にドクロ、各キャッシュの上に金の宝箱。画面のどこにいても表示：近いと大きく、遠いと小さく。",
   "각 보스와 깨어난 수호자 위에 해골, 각 보물 상자 위에 금색 상자를 화면 어디에 있든 표시합니다: 가까우면 크게, 멀면 작게.",
   "Czaszka nad każdym bossem i przebudzonym strażnikiem oraz złota skrzynia nad każdym skarbem, gdziekolwiek są na ekranie: duże z bliska, małe z daleka.",
   "Her boss ve uyanık muhafızın üstünde bir kafatası, her sandığın üstünde altın bir sandık, ekranın neresinde olurlarsa: yakındayken büyük, uzaktayken küçük."),
]

def q(s): return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'
loc = open(D + "/Locale.lua", encoding="utf-8").read()
if '{ "Pet bar",' not in loc:
    def row(en, t):
        return "\t{ " + q(en) + ",\n\t\t" + ",\n\t\t".join(q(t[c]) for c in ("fr", "de", "es", "pt")) + " },\n"
    rows = "\t-- the pet bar and the cache marks (1.15.0)\n" + "".join(row(en, t) for en, t in P if ("{ " + q(en) + ",") not in loc)
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
