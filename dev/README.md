# Creed UI: development tools

Everything used to build and check Creed UI outside the game. Run the commands below from this
`dev` folder; the addon itself is in `../CreedUI`.

## What you need

- **Lua 5.0** (the game's own Lua): build it from [lua-5.0.3](https://www.lua.org/ftp/lua-5.0.3.tar.gz)
  (`make` in its folder; the interpreter lands in `bin/lua`). Below it's called `lua50`.
- **Python 3** with `numpy`, `Pillow`, `scipy`, `fontTools` and, for the renderer, `opencv-python`.

## The stand-in game client and its tests

`cui/mock_cui.lua` is a stand-in for the game: its widgets (only the calls the 1.12 client really
has: a missing one is an error, see `engine_methods.lua`), the Azeroth Survivors API as the game
answers it, and Azeroth Survivors' character window (`cui/mock_char.lua`). `bt/sim.lua` plays runs
on it: bosses, guardians, cards, deaths, victory.

| Command | What it checks |
| --- | --- |
| `lua50 cui/tests.lua . ../CreedUI` | Every part, end to end (500+ checks) |
| `lua50 cui/timer_tests.lua . ../CreedUI` | The boss timer |
| `lua50 cui/numbers_harness.lua . ../CreedUI/Numbers.lua` | The damage numbers (`CROWD=1` for crowds) |
| `lua50 cui/smoke.lua . ../CreedUI <out folder>` | A long run with everything on, no errors |
| `lua50 cui/globals.lua . ../CreedUI` | No stray globals (`this`, `event` and `arg1` are the game's) |
| `lua50 cui/overflow.lua . ../CreedUI` | No text spilling out of its place, in all 11 languages |
| `python3 cui/locale_check.py ../CreedUI` | Every phrase translated, its `{1}` slots kept |

## Pictures of it

The `cui/*prev.lua` scripts set a scene and write a dump; `cui/render_cui.py` draws it:

```
lua50 cui/charprev.lua . ../CreedUI out
python3 cui/render_cui.py out/char.txt out/char.png 2 0 150 590 720
```

`cui/classprev.lua` writes the party in all nine class colors (`out/class1..3.txt`); `cui/guardprev.lua`
one boss and four guardians (`out/guards.txt`); `cui/cardsprev.lua` the character window behind the
level-up cards (`out/cards.txt`). `cui/talprev.lua` opens the talent window (`out/talents.txt`); `cui/numprev.lua` a single hit beside a
stacked DoT (`out/numbers.txt`). `cui/partyprev.lua` sets friends down (a revive mark and an edge arrow), the Level Up! button and the
meter on Damage Taken (`out/party.txt`), then the run's summary (`out/summary.txt`); `cui/rankprev.lua`
the skill bar's rank boxes. `cui/skullprev.lua` sets a boss fight with the skulls over two bosses and writes `out/skulls.txt`, and
the options window in `out/hub.txt`.

A 1920x1080 game screenshot at `cui/shot.png` (or named in `CREEDUI_SHOT`) is drawn behind it,
with its action bar icons standing in for the game's; without one, a plain backdrop. The game's
fonts are stood in for by system ones (`bt/render_bt.py`).

## Translations

- French, German, Spanish and Portuguese are rows in `../CreedUI/Locale.lua`: English first.
- Chinese, Russian, Japanese, Korean, Polish and Turkish are numbered lists in `tr/<code>.py`, one
  per line of `en_keys.txt` (the English, in order). `python3 tr/gen.py ../CreedUI` writes
  `../CreedUI/Locale_<code>.lua` from them.
- A new phrase: add its row to `Locale.lua`, add its English to the end of `en_keys.txt`, its
  number to each `tr/<code>.py`, then `gen.py` and `locale_check.py`. The `tr/add_*.py` scripts
  are past examples that do all of that at once.
- New letters (Chinese, Japanese, Korean, Cyrillic, Polish, Turkish) must be in the bundled fonts:
  rebuild them with the scripts in `font/` if a check finds one missing.

## Art

- `art/make_icon.py <dir>` draws Creed UI's icon (for the addon page and listings) as icon-512/256/128.png; the drawn ones are in `art/icon/`.

All of Creed UI's art is original and drawn by these scripts (numpy and Pillow), written as BLP2
(uncompressed) with PNG copies: `python3 art/make_artN.py <blp folder> <png folder>`. Each script's
first lines say what it draws; later ones replace earlier ones where they share a name.
Copy the BLPs into `../CreedUI/Art`.
`art/upscale.py` makes 4x super-resolution copies of the user's class pictures (`<name>_x4.png`, not kept
in the repository; it says where to get its model), and `art/cut_classes.py` cuts each class's skill bar
emblem, crest and rails from them (or from the pictures themselves)
(`cut_classes.py source/class_bars.webp <blp> <png>`). (The bronze look's dragons, from
`source/bar_reference.webp`, were removed in 1.21.4; its golds are still Creed UI's.)

## Fonts

`font/build_font.py` (Chinese, Japanese, Korean, from Noto Sans CJK) and `font/build_latin.py`
(Latin and Cyrillic, from Lora) make `../CreedUI/Fonts`. They read the source fonts from the
system, or from `NOTO_CJK` and `LORA_VARIABLE`. Both sources are under the SIL Open Font License
(`font/*-src`).
