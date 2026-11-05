# 1.16.2: the pet skills' tooltips
import sys
D = sys.argv[1]
HERE = sys.path[0]
L = ["fr", "de", "es", "pt", "zh", "ru", "ja", "ko", "pl", "tr"]
def T(en, *vals):
    assert len(vals) == 10, en
    return (en, dict(zip(L, vals)))
P = [
 T("Range", "Écart", "Spanne", "Rango", "Faixa", "范围", "Разброс", "範囲", "범위", "Zakres", "Aralık"),
 T("Crits for", "Critique", "Kritisch", "Crítico", "Crítico", "暴击", "Крит", "クリティカル", "치명타", "Krytyk", "Kritik"),
 T("Hits per second", "Coups par seconde", "Treffer pro Sekunde", "Golpes por segundo", "Golpes por segundo", "每秒命中", "Ударов в секунду", "毎秒ヒット数", "초당 타격", "Trafień na sekundę", "Saniye başına vuruş"),
 T("Pet Damage", "Dégâts des familiers", "Begleiterschaden", "Daño de mascotas", "Dano de mascotes", "宠物伤害", "Урон питомцев", "ペットのダメージ", "소환수 피해", "Obrażenia zwierzaków", "Evcil hayvan hasarı"),
 T("Its own swings at the enemy in front of it.", "Ses propres coups sur l'ennemi devant lui.", "Seine eigenen Hiebe gegen den Feind vor ihm.", "Sus propios golpes al enemigo que tiene delante.", "Seus próprios golpes no inimigo à sua frente.", "它对面前敌人的普通攻击。", "Его собственные удары по врагу перед ним.", "目の前の敵への通常攻撃。", "앞의 적에게 하는 일반 공격.", "Jego własne ciosy we wroga przed nim.", "Önündeki düşmana kendi vuruşları."),
 T("Bites the enemy you attack.", "Mord l'ennemi que vous attaquez.", "Beißt den Feind, den du angreifst.", "Muerde al enemigo que atacas.", "Morde o inimigo que você ataca.", "撕咬你攻击的敌人。", "Кусает врага, которого вы атакуете.", "あなたが攻撃する敵に噛みつきます。", "당신이 공격하는 적을 뭅니다.", "Gryzie wroga, którego atakujesz.", "Saldırdığın düşmanı ısırır."),
 T("Sends each pet charging at its own target, bosses and elites first.", "Envoie chaque familier charger sa propre cible, boss et élites d'abord.", "Schickt jeden Begleiter auf sein eigenes Ziel, Bosse und Elite zuerst.", "Envía a cada mascota a cargar contra su propio objetivo, jefes y élites primero.", "Manda cada mascote atacar seu próprio alvo, chefes e elites primeiro.", "让每只宠物冲向各自的目标，首领和精英优先。", "Каждый питомец бросается на свою цель, сперва боссы и элита.", "各ペットが自分の標的へ突撃します。ボスとエリートが優先。", "각 소환수가 자신의 목표에게 돌진합니다. 보스와 정예 우선.", "Każdy zwierzak szarżuje na własny cel, najpierw bossy i elity.", "Her evcil hayvanı kendi hedefine saldırtır, önce boss ve elitler."),
 T("Its bites strike 5 more enemies for 150% damage each.", "Ses morsures frappent 5 ennemis de plus pour 150 % des dégâts chacun.", "Seine Bisse treffen 5 weitere Feinde für je 150 % Schaden.", "Sus mordiscos alcanzan a 5 enemigos más por un 150 % de daño cada uno.", "Suas mordidas atingem mais 5 inimigos com 150% de dano cada.", "撕咬额外命中 5 个敌人，各造成 150% 伤害。", "Укусы поражают ещё 5 врагов, по 150% урона каждому.", "噛みつきがさらに5体の敵に各150%のダメージ。", "물기가 적 5명을 더 공격해 각각 150%의 피해를 줍니다.", "Ugryzienia trafiają 5 kolejnych wrogów, każdego za 150% obrażeń.", "Isırıkları 5 düşmana daha her biri %150 hasarla vurur."),
 T("Strikes three times in quick succession.", "Frappe trois fois coup sur coup.", "Schlägt dreimal schnell hintereinander zu.", "Golpea tres veces seguidas.", "Golpeia três vezes seguidas.", "快速连击三次。", "Бьёт три раза подряд.", "素早く3回攻撃します。", "빠르게 세 번 공격합니다.", "Uderza trzy razy szybko po sobie.", "Arka arkaya üç kez vurur."),
 T("Hurls Frostbolts at your enemies.", "Lance des Éclairs de givre sur vos ennemis.", "Schleudert Frostblitze auf deine Feinde.", "Lanza Descargas de Escarcha a tus enemigos.", "Arremessa Setas de Gelo nos seus inimigos.", "向你的敌人投掷寒冰箭。", "Мечет Ледяные стрелы во врагов.", "敵にフロストボルトを放ちます。", "적에게 얼음 화살을 던집니다.", "Ciska Lodowymi pociskami we wrogów.", "Düşmanlarına Buz oku fırlatır."),
 T("Hurls bolts of fire at your enemies.", "Lance des éclairs de feu sur vos ennemis.", "Schleudert Feuerblitze auf deine Feinde.", "Lanza descargas de fuego a tus enemigos.", "Arremessa setas de fogo nos seus inimigos.", "向你的敌人投掷火焰箭。", "Мечет огненные стрелы во врагов.", "敵に炎の矢を放ちます。", "적에게 화염 화살을 던집니다.", "Ciska ognistymi pociskami we wrogów.", "Düşmanlarına ateş okları fırlatır."),
 T("Hits 2 enemies at once.", "Frappe 2 ennemis à la fois.", "Trifft 2 Feinde auf einmal.", "Golpea a 2 enemigos a la vez.", "Atinge 2 inimigos de uma vez.", "同时击中 2 个敌人。", "Бьёт 2 врагов разом.", "一度に2体の敵を攻撃します。", "한 번에 적 2명을 공격합니다.", "Trafia 2 wrogów naraz.", "Aynı anda 2 düşmana vurur."),
 T("Cleaves up to 10 enemies; every third swing deals double damage.", "Frappe jusqu'à 10 ennemis ; un coup sur trois inflige le double.", "Trifft bis zu 10 Feinde; jeder dritte Hieb macht doppelten Schaden.", "Golpea hasta 10 enemigos; cada tercer golpe hace el doble de daño.", "Atinge até 10 inimigos; cada terceiro golpe causa dano dobrado.", "顺劈最多 10 个敌人；每第三击造成双倍伤害。", "Рассекает до 10 врагов; каждый третий удар — двойной урон.", "最大10体をなぎ払い、3回に1回は2倍のダメージ。", "적을 최대 10명까지 베며, 세 번째 공격마다 두 배 피해를 줍니다.", "Rozpłatuje do 10 wrogów; co trzeci cios zadaje podwójne obrażenia.", "10 düşmana kadar yarar; her üçüncü vuruş iki kat hasar verir."),
 T("Burns the enemies around it.", "Brûle les ennemis autour de lui.", "Verbrennt die Feinde um ihn herum.", "Quema a los enemigos a su alrededor.", "Queima os inimigos ao redor.", "灼烧周围的敌人。", "Сжигает врагов вокруг себя.", "周囲の敵を焼きます。", "주위의 적을 불태웁니다.", "Pali wrogów wokół siebie.", "Etrafındaki düşmanları yakar."),
 T("Hurls Shadow Bolts at your enemies.", "Lance des Traits de l'ombre sur vos ennemis.", "Schleudert Schattenblitze auf deine Feinde.", "Lanza Descargas de las Sombras a tus enemigos.", "Arremessa Setas Sombrias nos seus inimigos.", "向你的敌人投掷暗影箭。", "Мечет Стрелы Тьмы во врагов.", "敵にシャドウボルトを放ちます。", "적에게 어둠의 화살을 던집니다.", "Ciska Pociskami cienia we wrogów.", "Düşmanlarına Gölge oku fırlatır."),
]

def q(s): return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'
loc = open(D + "/Locale.lua", encoding="utf-8").read()
if '{ "Hits per second",' not in loc:
    def row(en, t):
        return "\t{ " + q(en) + ",\n\t\t" + ",\n\t\t".join(q(t[c]) for c in ("fr", "de", "es", "pt")) + " },\n"
    rows = "\t-- the pet skills' tooltips (1.16.2)\n" + "".join(row(en, t) for en, t in P if ("{ " + q(en) + ",") not in loc)
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
