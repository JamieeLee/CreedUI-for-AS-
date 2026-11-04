# Creed UI

A clean, smooth HUD for **Azeroth Survivors** ([wow.aethus.pl](https://wow.aethus.pl)), the World of Warcraft 1.12 roguelike. Everything is drawn in one look (dark glass, a gold rail, the timer's metal) and steps aside while you pick your cards.

## What's in it

- **Boss timer:** a themed countdown to each boss, with the run's time.
- **Tiny Plates:** compact half-size regular enemy plates and full-size boss/guardian plates, with Creed UI's layered health bars, matching typography, optional health numbers, and debuffs. Native nameplates and V-key visibility are restored when disabled.
- **Boss and mini-boss bars:** red bars with real health numbers and the debuffs on them.
- **Skulls:** a horned skull with red eyes floating over each boss, and a plainer one over each guardian, wherever it is on the screen, large when near and small when far.
- **Your frame, your target and your party:** in class colors, portraits in metal rings.
- **Downed friends (co-op):** a warning and a sound when a friend goes down, a glowing mark with their class crest where you can revive them, and an arrow at the screen's edge with the distance while they're off it.
- **Skill bar:** your abilities (each with its rank, flashing when a card ranks it up) and jewelry, your XP a second, on a gold-framed panel with a painted golden dragon on each end.
- **Kills, gold and cache:** in the panel; hover for what each gives.
- **Stored level-ups:** a glowing Level Up! button with how many wait (with the game's Store Level-Ups on).
- **Damage meter:** Damage Done, Healing Done, Boss Damage, Party DPS and Damage Taken, with icons, per second and shares. Resizable from any edge.
- **Luck medallion:** your luck and the odds of a Rare, Epic or Legendary card.
- **Minimap:** a metal ring, your local time, the caches and the guardians' lairs. The single **C** button opens Creed UI Options; use the **Luck** and **Damage meter** controls there to show or hide those windows.
- **Character window:** gear slots lit in their rarity color and your run's stats grouped beside it (zeros dimmed, changes flashing); its Talents tab opens Creed UI's talent window (your trees, points and learned talents with their ranks).
- **Chat:** dressed to match, and kept clear of the skill bar's dragon.
- **Damage numbers:** calm and readable; a spell hitting a crowd adds up into one number a second, and a number that keeps stacking grows.
- **Run summary:** when a run ends, your time, level, kills, bosses, damage dealt and taken, gold and caches on one panel.

Every part can be turned on or off, sized and moved.

**Languages:** English, French, German, Spanish, Portuguese, Chinese, Russian, Japanese, Korean, Polish and Turkish, picked from the options or with `/creed language`.

## Install

1. Download the latest `CreedUi-<version>.zip` from [Releases](../../releases).
2. Unzip it into your game's `Interface/AddOns` folder. You should end up with `Interface/AddOns/CreedUI/CreedUI.toc`.
3. The folder must stay named `CreedUI`: the game loads it by that name, and your settings are kept under it.

## Commands

| Command | What it does |
| --- | --- |
| `/creed` | Opens the options (or click the C on the minimap's edge) |
| `/creed move`, `/creed lock` | Frees the frames to drag them, then locks them |
| `/creed reset` | Puts every frame back in its place |
| `/creed language <code>` | Picks the language (`auto` follows the game) |
| `/creed timer ...`, `/creed numbers ...` | The boss timer's and damage numbers' own settings |
| `/creed <part> on/off` | Turns a part on or off |
| `/creed talents` | Opens the talent window |
| `/creed probe` | Prints what the game gives addons, for reporting what's missing |

## Credits

Original art made for Creed UI. The bundled fonts in `CreedUI/Fonts` are made from Lora and Noto Sans CJK, both under the SIL Open Font License (see `CreedUI/Fonts/LICENSE.txt`).

## Working on it

The tools that build and check Creed UI (a stand-in game client with its tests, the translation, art and font scripts, a preview renderer) are in [`dev`](dev/README.md).
