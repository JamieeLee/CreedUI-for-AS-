# 1.14.3: Tiny Plates, the hub's buttons, the meter's and luck window's new notes
import sys
D = sys.argv[1]
HERE = sys.path[0]
L = ["fr", "de", "es", "pt", "zh", "ru", "ja", "ko", "pl", "tr"]
def T(en, *vals):
    assert len(vals) == 10, en
    return (en, dict(zip(L, vals)))
P = [
 T("Language", "Langue", "Sprache", "Idioma", "Idioma", "语言", "Язык", "言語", "언어", "Język", "Dil"),
 T("Tiny Plates", "Mini-plaques", "Kleine Plaketten", "Placas pequeñas", "Placas pequenas", "迷你姓名板", "Мини-таблички", "小型ネームプレート", "작은 이름표", "Małe tabliczki", "Küçük plakalar"),
 T("Tiny Plates settings", "Réglages des mini-plaques", "Kleine Plaketten: Optionen", "Ajustes de placas pequeñas", "Ajustes das placas pequenas", "迷你姓名板设置", "Настройки мини-табличек", "小型ネームプレート設定", "작은 이름표 설정", "Ustawienia małych tabliczek", "Küçük plaka ayarları"),
 T("Half-size regular nameplates, with full-size boss and guardian plates.", "Plaques normales réduites de moitié, plaques entières pour boss et gardiens.", "Halb so große normale Namensplaketten, volle Größe für Bosse und Wächter.", "Placas normales a mitad de tamaño; jefes y guardianes a tamaño completo.", "Placas normais pela metade; chefes e guardiões em tamanho cheio.", "普通姓名板缩小一半，首领和守护者保持原尺寸。", "Обычные таблички вдвое меньше, у боссов и стражей полные.", "通常のネームプレートは半分、ボスとガーディアンは原寸。", "일반 이름표는 절반 크기, 보스와 수호자는 원래 크기.", "Zwykłe tabliczki o połowę mniejsze, bossowie i strażnicy w pełnym rozmiarze.", "Normal plakalar yarı boyutta, boss ve muhafız plakaları tam boyutta."),
 T("Creed UI nameplates stopped after an error: ", "les plaques de Creed UI se sont arrêtées après une erreur : ", "Creed-UI-Namensplaketten nach einem Fehler gestoppt: ", "las placas de Creed UI se detuvieron tras un error: ", "as placas do Creed UI pararam após um erro: ", "Creed UI 姓名板因错误停止：", "таблички Creed UI остановлены после ошибки: ", "エラーのため Creed UI のネームプレートを止めました: ", "오류로 Creed UI 이름표가 멈췄습니다: ", "tabliczki Creed UI zatrzymały się po błędzie: ", "Creed UI plakaları bir hatadan sonra durdu: "),
 T("Creed UI nameplate debuff update stopped after an error: ", "les effets sur les plaques de Creed UI se sont arrêtés après une erreur : ", "Schwächungen auf Creed-UI-Plaketten nach einem Fehler gestoppt: ", "los perjuicios en las placas de Creed UI se detuvieron tras un error: ", "as penalidades nas placas do Creed UI pararam após um erro: ", "Creed UI 姓名板减益更新因错误停止：", "дебаффы на табличках Creed UI остановлены после ошибки: ", "エラーのため Creed UI のデバフ表示を止めました: ", "오류로 Creed UI 이름표 약화 효과 갱신이 멈췄습니다: ", "osłabienia na tabliczkach Creed UI zatrzymały się po błędzie: ", "Creed UI plaka zayıflatmaları bir hatadan sonra durdu: "),
 T("Boss & guardian plates", "Plaques des boss et gardiens", "Plaketten von Bossen und Wächtern", "Placas de jefes y guardianes", "Placas de chefes e guardiões", "首领和守护者姓名板", "Таблички боссов и стражей", "ボスとガーディアン", "보스와 수호자 이름표", "Tabliczki bossów i strażników", "Boss ve muhafız plakaları"),
 T("Show debuffs", "Afficher les affaiblissements", "Schwächungen zeigen", "Mostrar perjuicios", "Mostrar penalidades", "显示减益", "Показывать дебаффы", "デバフを表示", "약화 효과 표시", "Pokaż osłabienia", "Zayıflatmaları göster"),
 T("Show boss and guardian debuffs, stack counts and remaining time.", "Affiche les affaiblissements des boss et gardiens, leurs cumuls et le temps restant.", "Zeigt Schwächungen von Bossen und Wächtern, Stapel und Restzeit.", "Muestra los perjuicios de jefes y guardianes, acumulaciones y tiempo restante.", "Mostra as penalidades de chefes e guardiões, acúmulos e tempo restante.", "显示首领和守护者的减益、层数和剩余时间。", "Дебаффы боссов и стражей, их стаки и оставшееся время.", "ボスとガーディアンのデバフ、スタック数、残り時間を表示。", "보스와 수호자의 약화 효과, 중첩, 남은 시간을 표시합니다.", "Pokazuje osłabienia bossów i strażników, stosy i pozostały czas.", "Boss ve muhafızların zayıflatmalarını, yığınlarını ve kalan süreyi gösterir."),
 T("Hide boss / guardian names", "Masquer les noms des boss et gardiens", "Namen von Bossen und Wächtern ausblenden", "Ocultar nombres de jefes y guardianes", "Ocultar nomes de chefes e guardiões", "隐藏首领和守护者名字", "Скрыть имена боссов и стражей", "ボスとガーディアンの名前を隠す", "보스와 수호자 이름 숨기기", "Ukryj imiona bossów i strażników", "Boss ve muhafız adlarını gizle"),
 T("Hide the name label above special plates.", "Masque le nom au-dessus de ces plaques.", "Blendet den Namen über diesen Plaketten aus.", "Oculta el nombre sobre estas placas.", "Oculta o nome sobre essas placas.", "隐藏这些姓名板上方的名字。", "Скрывает имя над этими табличками.", "これらのプレートの上の名前を隠します。", "이 이름표 위의 이름을 숨깁니다.", "Ukrywa imię nad tymi tabliczkami.", "Bu plakaların üstündeki adı gizler."),
 T("Regular plates", "Plaques normales", "Normale Plaketten", "Placas normales", "Placas normais", "普通姓名板", "Обычные таблички", "通常のプレート", "일반 이름표", "Zwykłe tabliczki", "Normal plakalar"),
 T("Hide regular plates", "Masquer les plaques normales", "Normale Plaketten ausblenden", "Ocultar placas normales", "Ocultar placas normais", "隐藏普通姓名板", "Скрыть обычные таблички", "通常のプレートを隠す", "일반 이름표 숨기기", "Ukryj zwykłe tabliczki", "Normal plakaları gizle"),
 T("Hide ordinary mob plates entirely. Requires overlapping nameplates.", "Masque entièrement les plaques des monstres ordinaires. Demande des plaques superposées.", "Blendet Plaketten gewöhnlicher Gegner ganz aus. Braucht überlappende Namensplaketten.", "Oculta del todo las placas de enemigos comunes. Requiere placas superpuestas.", "Oculta totalmente as placas de inimigos comuns. Requer placas sobrepostas.", "完全隐藏普通怪物的姓名板。需要开启重叠姓名板。", "Полностью скрывает таблички обычных врагов. Нужны перекрывающиеся таблички.", "通常の敵のプレートを完全に隠します。重なるネームプレートが必要です。", "일반 적의 이름표를 모두 숨깁니다. 겹치는 이름표가 필요합니다.", "Całkiem ukrywa tabliczki zwykłych wrogów. Wymaga nakładających się tabliczek.", "Sıradan düşman plakalarını tamamen gizler. Üst üste binen plakalar gerekir."),
 T("Show names on nameplates", "Afficher les noms sur les plaques", "Namen auf Plaketten zeigen", "Mostrar nombres en las placas", "Mostrar nomes nas placas", "在姓名板上显示名字", "Показывать имена на табличках", "プレートに名前を表示", "이름표에 이름 표시", "Pokaż imiona na tabliczkach", "Plakalarda adları göster"),
 T("Show each regular mob name above its shrunken plate.", "Affiche le nom de chaque monstre au-dessus de sa petite plaque.", "Zeigt den Namen jedes Gegners über seiner kleinen Plakette.", "Muestra el nombre de cada enemigo sobre su placa reducida.", "Mostra o nome de cada inimigo sobre sua placa reduzida.", "在每个普通怪物的小姓名板上方显示名字。", "Имя каждого обычного врага над его маленькой табличкой.", "通常の敵の名前を小さなプレートの上に表示します。", "일반 적의 이름을 작은 이름표 위에 표시합니다.", "Pokazuje imię każdego zwykłego wroga nad jego małą tabliczką.", "Her sıradan düşmanın adını küçük plakasının üstünde gösterir."),
 T("Health display", "Affichage de la vie", "Gesundheitsanzeige", "Salud", "Vida", "生命值显示", "Здоровье", "体力表示", "생명력 표시", "Zdrowie", "Can gösterimi"),
 T("Show health numbers", "Afficher les points de vie", "Gesundheitszahlen zeigen", "Mostrar números de salud", "Mostrar números de vida", "显示生命值数字", "Показывать числа здоровья", "体力の数値を表示", "생명력 수치 표시", "Pokaż liczby zdrowia", "Can sayılarını göster"),
 T("Show current / maximum health numbers inside each plate. The colored health bars remain visible either way.", "Affiche la vie actuelle / maximale dans chaque plaque. Les barres colorées restent visibles dans tous les cas.", "Zeigt aktuelle / maximale Gesundheit in jeder Plakette. Die farbigen Balken bleiben so oder so sichtbar.", "Muestra la salud actual / máxima en cada placa. Las barras de color se ven igualmente.", "Mostra a vida atual / máxima em cada placa. As barras coloridas continuam visíveis.", "在每个姓名板内显示当前 / 最大生命值。彩色血条始终可见。", "Текущее / максимальное здоровье на каждой табличке. Цветные полоски видны в любом случае.", "各プレートに現在 / 最大体力を表示します。色付きのバーは常に見えます。", "각 이름표에 현재 / 최대 생명력을 표시합니다. 색 막대는 항상 보입니다.", "Pokazuje obecne / maksymalne zdrowie w każdej tabliczce. Kolorowe paski widać zawsze.", "Her plakada mevcut / en yüksek canı gösterir. Renkli can çubukları her durumda görünür."),
 T("Custom bar color", "Couleur de barre perso", "Eigene Balkenfarbe", "Color de barra propio", "Cor de barra própria", "自定义血条颜色", "Свой цвет полосы", "バーの色を変更", "막대 색 지정", "Własny kolor paska", "Özel çubuk rengi"),
 T("Use your own color instead of the game's health-bar color.", "Utilise votre couleur au lieu de celle du jeu.", "Nutzt deine Farbe statt der des Spiels.", "Usa tu color en lugar del color del juego.", "Usa sua cor em vez da cor do jogo.", "用你自己的颜色代替游戏的血条颜色。", "Ваш цвет вместо цвета полосы здоровья игры.", "ゲームの体力バーの色の代わりに自分の色を使います。", "게임의 생명력 막대 색 대신 직접 고른 색을 씁니다.", "Twój kolor zamiast koloru paska zdrowia z gry.", "Oyunun can çubuğu rengi yerine kendi rengini kullan."),
 T("Boss / guardian health color", "Couleur de vie des boss et gardiens", "Gesundheitsfarbe von Bossen und Wächtern", "Color de salud de jefes y guardianes", "Cor de vida de chefes e guardiões", "首领和守护者血条颜色", "Цвет здоровья боссов и стражей", "ボスとガーディアンの体力の色", "보스와 수호자 생명력 색", "Kolor zdrowia bossów i strażników", "Boss ve muhafız can rengi"),
 T("Regular health color", "Couleur de vie normale", "Normale Gesundheitsfarbe", "Color de salud normal", "Cor de vida normal", "普通血条颜色", "Цвет здоровья обычных", "通常の体力の色", "일반 생명력 색", "Zwykły kolor zdrowia", "Normal can rengi"),
 T("Blue", "Bleu", "Blau", "Azul", "Azul", "蓝色", "Синий", "青", "파랑", "Niebieski", "Mavi"),
 T("Orange", "Orange", "Orange", "Naranja", "Laranja", "橙色", "Оранжевый", "オレンジ", "주황", "Pomarańczowy", "Turuncu"),
 T("Sky blue", "Bleu ciel", "Himmelblau", "Celeste", "Azul-celeste", "天蓝色", "Голубой", "空色", "하늘색", "Błękitny", "Gök mavisi"),
 T("Vermillion", "Vermillon", "Zinnober", "Bermellón", "Vermelhão", "朱红色", "Киноварь", "朱色", "주홍", "Cynobrowy", "Zinober"),
 T("Yellow", "Jaune", "Gelb", "Amarillo", "Amarelo", "黄色", "Жёлтый", "黄", "노랑", "Żółty", "Sarı"),
 T("Pink", "Rose", "Rosa", "Rosa", "Rosa", "粉色", "Розовый", "ピンク", "분홍", "Różowy", "Pembe"),
 T("Damage Done, Healing Done, Boss Damage and Party DPS with icons, per second and shares; Reset counts again in this window only. Drag the title to move it, the corner to resize. Use the Damage meter toggle in Creed UI Options to show or hide it; while enabled, it replaces the game's meter window.",
   "Dégâts infligés, soins prodigués, dégâts aux boss et DPS du groupe avec icônes, par seconde et parts ; Réinit. recompte dans cette fenêtre seulement. Glissez le titre pour la déplacer, le coin pour la redimensionner. Affichez-la ou masquez-la depuis les options de Creed UI ; activée, elle remplace la fenêtre du jeu.",
   "Verursachter Schaden, Heilung, Bossschaden und Gruppen-DPS mit Symbolen, pro Sekunde und Anteilen; Reset zählt nur in diesem Fenster neu. Titel ziehen zum Verschieben, Ecke zum Ändern der Größe. In den Creed-UI-Optionen ein- oder ausblenden; aktiviert ersetzt es das Fenster des Spiels.",
   "Daño hecho, sanación, daño a jefes y DPS del grupo con iconos, por segundo y porcentajes; Borrar vuelve a contar solo en esta ventana. Arrastra el título para moverla y la esquina para cambiar su tamaño. Muéstrala u ocúltala en las opciones de Creed UI; activada, sustituye la ventana del juego.",
   "Dano causado, cura, dano em chefes e DPS do grupo com ícones, por segundo e parcelas; Zerar reconta só nesta janela. Arraste o título para mover e o canto para redimensionar. Mostre ou oculte nas opções do Creed UI; ativada, substitui a janela do jogo.",
   "造成伤害、治疗、首领伤害和队伍 DPS，带图标、每秒数值和占比；重置只在此窗口重新计数。拖动标题移动，拖动角落调整大小。在 Creed UI 选项中显示或隐藏；启用时取代游戏的统计窗口。",
   "Нанесённый урон, исцеление, урон по боссам и DPS группы со значками, в секунду и долями; Сброс считает заново только в этом окне. Тяните заголовок, чтобы двигать, угол — чтобы менять размер. Показ и скрытие — в настройках Creed UI; включённое, оно заменяет окно игры.",
   "与ダメージ、回復、ボスへのダメージ、パーティーDPSをアイコン、毎秒、割合で表示。リセットはこのウィンドウだけ数え直します。タイトルをドラッグで移動、角でサイズ変更。Creed UI のオプションで表示を切り替え、有効な間はゲームのウィンドウの代わりになります。",
   "가한 피해, 치유, 보스 피해, 파티 DPS를 아이콘, 초당 수치, 비율로 표시합니다. 초기화는 이 창에서만 다시 셉니다. 제목을 끌어 옮기고 모서리로 크기를 바꿉니다. Creed UI 옵션에서 표시하거나 숨기며, 켜져 있으면 게임의 창을 대신합니다.",
   "Zadane obrażenia, leczenie, obrażenia bossów i DPS drużyny z ikonami, na sekundę i udziałami; Reset liczy od nowa tylko w tym oknie. Przeciągnij tytuł, by przesunąć, róg, by zmienić rozmiar. Pokaż lub ukryj w opcjach Creed UI; włączone zastępuje okno gry.",
   "Verilen hasar, iyileştirme, boss hasarı ve grup DPS'i simgelerle, saniye başına ve paylarla; Sıfırla yalnızca bu pencerede yeniden sayar. Taşımak için başlığı, boyutlandırmak için köşeyi sürükle. Creed UI seçeneklerinden göster veya gizle; açıkken oyunun penceresinin yerini alır."),
 T("Your luck on a bronze medallion, and the chance of a Rare, Epic or Legendary card as three gems (1 in N); luck you gain shows on the medallion. Drag its sides to widen it, its corners to size it; use the Luck toggle in Creed UI Options to show or hide the window.",
   "Votre chance sur un médaillon de bronze, et la probabilité d'une carte Rare, Épique ou Légendaire en trois gemmes (1 sur N) ; la chance gagnée s'affiche sur le médaillon. Glissez ses côtés pour l'élargir, ses coins pour la redimensionner ; affichez-la ou masquez-la depuis les options de Creed UI.",
   "Dein Glück auf einem Bronzemedaillon und die Chance auf eine seltene, epische oder legendäre Karte als drei Edelsteine (1 zu N); gewonnenes Glück zeigt das Medaillon. Seiten ziehen zum Verbreitern, Ecken für die Größe; in den Creed-UI-Optionen ein- oder ausblenden.",
   "Tu suerte en un medallón de bronce y la probabilidad de una carta rara, épica o legendaria en tres gemas (1 entre N); la suerte ganada aparece en el medallón. Arrastra sus lados para ensancharla y sus esquinas para su tamaño; muéstrala u ocúltala en las opciones de Creed UI.",
   "Sua sorte num medalhão de bronze e a chance de uma carta rara, épica ou lendária em três gemas (1 em N); a sorte ganha aparece no medalhão. Arraste os lados para alargar e os cantos para o tamanho; mostre ou oculte nas opções do Creed UI.",
   "你的幸运显示在青铜徽章上，稀有、史诗、传说卡牌的几率显示为三颗宝石（N 分之 1）；获得的幸运显示在徽章上。拖动两侧加宽，拖动角落调整大小；在 Creed UI 选项中显示或隐藏。",
   "Ваша удача на бронзовом медальоне и шанс редкой, эпической или легендарной карты тремя камнями (1 из N); полученная удача видна на медальоне. Тяните края, чтобы расширить, углы — чтобы менять размер; показ и скрытие — в настройках Creed UI.",
   "幸運を青銅のメダルに、レア・エピック・レジェンダリーのカードの確率を3つの宝石（N分の1）で表示。得た幸運はメダルに出ます。端をドラッグで幅、角でサイズ変更。Creed UI のオプションで表示を切り替えます。",
   "행운을 청동 메달에, 희귀·영웅·전설 카드 확률을 보석 세 개(N분의 1)로 표시합니다. 얻은 행운은 메달에 나타납니다. 옆면을 끌어 넓히고 모서리로 크기를 바꿉니다. Creed UI 옵션에서 표시하거나 숨깁니다.",
   "Twoje szczęście na brązowym medalionie i szansa na rzadką, epicką lub legendarną kartę jako trzy klejnoty (1 na N); zdobyte szczęście widać na medalionie. Przeciągnij boki, by poszerzyć, rogi, by zmienić rozmiar; pokaż lub ukryj w opcjach Creed UI.",
   "Şansın bronz bir madalyonda, Nadir, Destansı veya Efsanevi kart olasılığı üç mücevherde (N'de 1); kazandığın şans madalyonda görünür. Genişletmek için kenarlarını, boyutlandırmak için köşelerini sürükle; Creed UI seçeneklerinden göster veya gizle."),
]

def q(s): return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'
loc = open(D + "/Locale.lua", encoding="utf-8").read()
if '{ "Tiny Plates",' not in loc:
    def row(en, t):
        return "\t{ " + q(en) + ",\n\t\t" + ",\n\t\t".join(q(t[c]) for c in ("fr", "de", "es", "pt")) + " },\n"
    rows = "\t-- Tiny Plates and the options hub (1.14.3)\n" + "".join(row(en, t) for en, t in P if ("{ " + q(en) + ",") not in loc)
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
