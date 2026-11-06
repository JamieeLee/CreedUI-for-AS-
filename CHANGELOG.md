# Changelog

## 1.20.2
- **Loot pop-up: each drop in its rarity's color.** The game's loot line doesn't say how rare a drop is, so Creed UI knows it by the piece's set or weapon name, in any of the game's languages: Common in white, Uncommon in green, Rare and Tier 0.5 in blue, Epic in purple, Legendary in orange.

## 1.20.1
- **Party frames: your friends' shields.** A friend wearing a shield (Power Word: Shield, Ice Barrier, Mana Shield, Frost or Fire Ward, Sacrifice, Divine Shield or Protection, Blessing of Protection) shows it on their health as your own frame does: an icy pane after their health, as big as the shield holds (read from the buff's own words), or a small one when the game doesn't say.

## 1.20.0
- **Damage numbers: crit backdrops.** Pick one in the numbers' options (Crit backdrop) or with `/creed numbers backdrop <name>`, and every critical hit wears it behind its number: **Blood** (a splatter with flung droplets), **Fire** (a burst of flames), **Frost** (an ice star), **Arcane** (a ring of runes), **Holy** (a sunburst) or **Shadow** (a curl of smoke). Off by default.
- **Damage numbers: six new fonts** to pick from, beside the game's four: **Cinzel** (regal capitals), **Bangers** (comic punch), **Creepster** (dripping horror), **Uncial Antiqua** (old runic hand), **Black Ops One** (stencil) and **Pirata One** (gothic). Pick one in the options or with `/creed numbers font <name>`. (In Chinese, Japanese, Korean and Russian the language's own letters stay.)

## 1.19.2
- **Pet bar: big numbers no longer pile up.** The value under each pet skill is kept short (487, 5.9K, 49K, 1.2M) and each skill gets the room its number needs, so neighbours never run into each other.

## 1.19.1
- **Inspect from the party menu opens their gear.** It now works as the game's own menu does: your friend becomes your target and the target is inspected (the game's inspect window works from the target). The game itself says when they're too far away.

## 1.19.0
- **Loot pop-up instead of the loot window.** When the game gives you loot, a Creed UI pop-up rises in over the skill bar in place of the game's own: the item's icon in a metal slot, its name, and whether it's new to your collection (in green) or one you already had. Marks you earn pop up too, on an Argent Dawn token, with how many you have in all. Up to three stack, and each melts away after a few seconds. The loot window is gone; turning the Loot part off brings back the game's own pop-up.

## 1.18.1
- **Loot window: an icon for every drop.** The game's loot line names the item but doesn't say what it looks like, so each one gets an icon by what it is (boots, a helm, a ring, a sword...), or its own when the game gives it. Its name shows without brackets, and gear new to your collection gets a green **New** tag (its tooltip says which are new and which you already had).

## 1.18.0
- **Party frames: right-click menu.** A right click on a friend's frame opens a small menu beside it with their name: **Inspect** (their gear, in the game's own window; it says so when they're too far away), **Follow**, and **Whisper** (the chat box opens with "/w Name" typed). A left click still targets them.

## 1.17.3
- **Loot window: marks and boss gear only.** Its head shows the marks you earned this run on an Argent Dawn token, and how many you have in all; the gold and caches are gone. Below, the gear that dropped for you. Both are read from the game's own lines in the chat, in any of its languages (someone typing the same words doesn't count).

## 1.17.2
- **Pet bar: only skills with a real value.** A pet's skill shows once its hits are seen, with what it hits for; one whose damage the game doesn't report on its own (Bestial Wrath, and any the game folds into another skill) no longer sits there empty.
- **Hit values kept apart:** each hit now counts toward the skill the game's meter puts it under, so two skills can't share one value.

## 1.17.1
- **Move and size the chat:** with the frames unlocked (right-click the C on the minimap), a Chat box lies over the chat: drag it to move the chat, drag its corner grip to make it wider, narrower, taller or shorter. Its place and size are kept; resetting the frames puts the game's back.
- **Move the hero's numbers:** the spot the damage-taken and heal numbers rise from is now a box you can drag too, like every other part.

## 1.17.0
- **Loot window** (new part): the run's loot beside the damage meter. The gold you picked up and the caches you opened at its head, then every item you received, newest first, with its icon, its name in its rarity's color, how many, and the moment of the run it came. Point at one for the item's own tooltip. It starts empty each run and keeps the last run's after it ends. Its x closes it; the Loot toggle in the options brings it back.

## 1.16.3
- **Kill Command on the pet bar:** its hits now register under it (the game names them by the skill's key, not its name), so its value and tooltip fill in like the others'.
- **Pet skill tooltips:** point at a pet's skill for what it does and its damage as it is now: what it just hit for, what it usually hits for, its lowest to highest hit, its last crit, its hits per second, and your Pet Damage bonus. The numbers come from its own hits, so they already carry your stats, gear and buffs, and change as soon as those do.

## 1.16.2
- **Pet bar: what each pet can do, from the start.** Every pet shows its skills as soon as it's out, as the game describes them: the Wolf's Bite, the Raptor's Raptor Strike, Kill Command and Bestial Wrath for the hunter's beasts, the Imp's Firebolt, the Voidwalker's Shadow Cleave, the Felguard's Cleave, the Infernal's Hellfire, the Doomguard's Shadow Bolt, the Water Elemental's Frostbolt, and Melee for those that fight in close. Each one's hit value fills in under it once it lands; any other skill the meter sees a pet use is added after.

## 1.16.1
- **Heals received:** the health you get back (heals, life drained) now rises beside your hero too, as green "+" numbers on the other side from the red damage ones. Part of Damage taken, so the same switch turns both off.
- **Pet bar faces:** each summon shows its own picture by its name: a wolf for the Wolf, a raptor for the Raptor, the Spirit Wolf, Imp, Voidwalker, Infernal, Doomguard, Water Elemental and Treant their own, and every hunter beast family (cat, bear, owl, gorilla, scorpid, turtle...) theirs.
- **Pet skills show their value:** under each pet skill, what it hits for now (its last plain hit), and on its tooltip that and what it usually hits for, instead of the damage it has added up. Read from the hits the damage numbers see, so they need the damage numbers on.

## 1.16.0
- **Damage numbers: four ways to move.** A new Motion row in the numbers' options (or `/creed numbers smooth|fountain|rise|impact`). **Smooth** is the gentle drift so far. **Fountain** arcs each number up and lets it fall away to the side. **Rise** scrolls them straight up, quickly. **Impact** punches them in big and keeps them in place, crits shaking.
- **Active skill counts:** a gold number on a skill's slot says how many are out at once: totems standing (the game's own count) and spells still burning on the ground (Blizzard, Flamestrike, Rain of Fire, Consecration, Hurricane, Hellfire, Volley, Frost and Immolation Traps).
- **Damage meter, Party DPS:** each hero's line shows their best skill in a tag, its damage per second on the tooltip.

## 1.15.0
- **Pet bar** (new part): just over the skill bar on its left. When the game gives your pet its own buttons, they're here: click to use, right-click to switch autocast, point at one for the game's tooltip, with a dark veil while it cools down. Otherwise each kind of summon you have out (Spirit Wolves, Treants, an Infernal...) shows its face, how many there are, the seconds left, and the skills you've seen it use, each with its damage on its tooltip.
- **Caches marked in the world:** every cache on the field wears a gold chest in a gold glow, so one that drops is easy to find. It fades once taken. (Part of Boss skulls, so the same toggle turns it off.)

## 1.14.3
- **Scholomance** (the game's 0.140.0 zone): the boss timer has its own look there, bone and ghostly green, and knows its five bosses (Kirtonos the Herald, Ras Frostwhisper, Doctor Theolen Krastinov, Lord Alexei Barov, Darkmaster Gandling) even right after a /reload.
- **Damage meter:** every pet's and summon's skills (a hunter's Kill Command, a wolf's bite, an Infernal's Immolation...) are counted together on one **Pet** line. Point at it to see its best skill. Totems keep their own lines.
- **Damage taken** (new part): what hits you rises beside your hero as red numbers, blows a split second apart gathered into one, heavier ones bigger. It hides behind the level-up cards and can be turned off in the options.
- **Minimap:** a cache or lair pin right where you stand fades to a ghost, so the game's arrow (you) shows through it.
- **Tiny Plates:** regular enemy plates use compact half-size Arcane-derived layered health bars and Creed UI typography; bosses and guardians keep full-size plates with the same styling and their debuffs below. Health numbers have an independent toggle, and disabling Tiny Plates restores the game's native plates and V-key visibility behavior.
- **One minimap button:** the separate Luck clover and Damage Meter swords are removed. The Creed C and the central options hub remain; Luck and the damage meter are shown or hidden from the hub, without extra minimap buttons.


## 1.14.2
- **Skill bar:** both ends look the same now (the kills, gold and cache sit at the right end of their room, the rails' diamonds at the frame's middle), so the right side no longer looks stretched.
- **Boss timer:** its metal (rails and the bosses' sockets) is the dark bronze gold of the rest of Creed UI; its bar, glow and title keep each zone's colors, and the bosses' diamonds are red in every zone.
- **Talents:** the Talents tab opens the game's own Talents window again (`/creed talents` still opens Creed UI's).
- **Boss bars** are a fifth bigger, and so are the **skulls over bosses** (guardians' skulls stay as they were).

## 1.14.1
- **Bronze gold everywhere:** every frame's metal (your frame, your target and party, the boss bars, the minimap ring, the meter, the luck window and the rest) is the skill bar's bronze gold in every zone, instead of taking the zone's colors. The boss timer keeps its own.
- **Dragons:** both face out now, perched on the bar's ends with the end rail behind them.
- **The skill bar keeps one size:** it no longer grows when a run starts and the kills, gold and cache show up, or as their numbers get longer.

## 1.14.0
- **New skill bar look**, from your own bar picture: a painted golden dragon sits on each end of the bar, facing in, wings raised, with room so it never covers a slot; gold diamonds mark the middle of the top and bottom rails.
- **One gold everywhere:** the panels' metal, the titles and tooltip headings, the borders and the rank boxes all take the same golds as that picture.

## 1.13.2
- **Dragons:** the body is one smooth piece now (neck, chest, haunch and thigh flow into each other instead of reading as separate shapes), with a band of domed belly plates down its front. The second wing is folded over the neck instead of sticking up behind it, and the front legs are a pair.

## 1.13.1
- **Dragons:** the skill bar's dragons are redrawn rearing up: jaws open, forelegs raised with claws curled, crouched on a hind leg, wings spread high, and the tail sweeping along the ground to a tip of flame. Their scales are now raised plates with depth: each one domed, overlapping the next with a step of shadow.

## 1.13.0
- **Talent window:** the Talents tab (or `/creed talents`) opens Creed UI's own talent window: your trees side by side with their names and points, every talent you learned as its icon with its rank (point at one for its name), and the total. Tree names are in your language, by the game's own words.
- **Damage numbers:** a number that keeps adding hits (a DoT ticking on, a spell's crowd total) grows as it stacks, up to about a third bigger after a second and a half. Every number is a touch smaller to make room.
- **Dragons:** the skill bar dragons' front legs bend naturally at the elbow and grip the ground with clawed hands, the hind feet have toes and claws, and the tail ends in a barb instead of an anchor.
- **Downed friends:** the mark and its class crest are more solid (still see-through).

## 1.12.1
- **Damage numbers and the level-up cards:** picking a card no longer sends black icons flashing across the screen. The numbers step aside while the cards are up, the ones from before are dropped as the cards close, and new hits show as the fight resumes.

## 1.12.0
Fixes from playtesting:
- **Talents:** the Talents tab opens the game's own Talents window, with Azeroth Survivors' real trees, milestones and points (Creed UI's page showed the wrong talents).
- **Level-up cards:** behind the cards, the character window now goes as dark as the rest of the game instead of showing through half lit.
- **Addon list:** Creed UI's description in Options → AddOns is one short line instead of a wall of text.
- **Party frames:** the health bars' class colors are richer and brighter, so every class reads at a glance.
- **Run summary:** the numbers stay still once it opens (in co-op the run goes on after you fall, and they kept flickering).
- **Guardian bars:** narrower, thinner and closer together, so several guardians don't crowd the screen; bosses keep their full bars.
- **Skulls:** guardians get a skull too (in an amber glow), and bosses a fiercer horned skull with smouldering red eyes. Also fixes the skulls switching themselves off with an error after a few bosses had come and gone.
- **Downed friends:** their class crest shows inside the revive mark, as see-through as the mark.
- `/creed probe` also lists the game's AZS tables.

## 1.11.0
- **Downed friends (co-op):** when a friend goes down, a banner says so with the raid warning sound. A glowing mark shows where they lie (stand on it to bring them back), with their name in their class color and the distance; while you revive them it turns green and counts up. While they're off the screen, a gold arrow at its edge points the way, with the distance.
- **Stored level-ups:** with the game's Store Level-Ups on, a glowing Level Up! button over the skill bar shows how many wait; click it to pick their cards. It pulses when one more comes.
- **Run summary:** when a run ends, a panel shows your time, level, kills, elites, guardians and bosses slain, damage dealt (and a second) and taken, gold earned and caches opened, counting up. Close it with its x; it moves with Move frames.
- **Damage Taken:** a new view in the damage meter: what hit you, the most first, per second.
- The options window has room for the three new parts.

## 1.10.0
- Each ability on the skill bar shows its rank in a little gold-rimmed box on its bottom right corner. When a card ranks one up, the box and the ability flash gold as you come back from the cards.
- `/creed probe` also shows the game's spells, their ranks and the rank each slot found.

## 1.9.0
- A skull floats over each boss, wherever it is on the screen, without a target or a nameplate: large when the boss is near, small when it's far, glowing gold over the final boss. It fades away when the boss falls. Mini-bosses have none. Turn it off or size it in the options (Boss skulls).
- The options window has two columns now, so it fits on any screen.
- `/creed probe` also shows what the game says about the bosses' places and downed friends.

## 1.8.3
- The Talents page now looks like the game's talent window: each tree in its own framed panel with its background painting, the full grid of talents, and branches with arrows from each talent to the ones it opens. Talents with points are lit with their rank, ones you could take are in color, locked ones are greyed.

## 1.8.2
- The Skills tab becomes a Talents page with your three talent trees side by side.
- The Honor tab is gone (no PvP).

## 1.8.1
- The talents strip under the model is removed for now.

## 1.8.0
- Character window in Creed UI's look: gear slots lit in their rarity color, the run's stats grouped in a panel beside it (zeros dimmed, changes flashing), the portrait in a ring.
- `/creed probe` prints what the game gives addons.

## 1.7.4
- New heavier dragons on the skill bar, wrapped in their wings and sitting flush against the frame.
- Over an edge that sizes a window, the cursor becomes the resize arrow.

## 1.7.3
- The meter's and luck window's gems become crossed swords and a clover on the minimap's edge, draggable around it, dimmed while their window is hidden.

## 1.7.2
- A C button on the minimap's edge opens the options; right-click frees or locks the frames.
- Tooltips show Chinese, Japanese, Korean, Russian, Polish and Turkish letters.
- Damage numbers keep a proc's hits (like Shadow Weaving) apart from the spell it borrows, with its own icon.

## 1.7.1
- Bundled fonts so every language shows its letters.
