# Creed UI: handoff for Claude Code

Read this first. It's where the work stands, the rules the code depends on, how to check it, and
what's next. It was written at the end of a long Claude session that built Creed UI with the
user (GitHub: **CreedASui**), who plays the game and publishes the addon. The user is not a
programmer: they test in game and send screenshots. Ship them a ready-to-install zip and a
picture of the change.

## 1. What this is

- **Creed UI** is a HUD addon for **Azeroth Survivors** ([wow.aethus.pl](https://wow.aethus.pl)), a
  World of Warcraft 1.12.1 roguelike played in the browser on **benilla**, a 1.12 client rewritten
  in Rust ([github.com/samwhosung/benilla](https://github.com/samwhosung/benilla)). The game adds its
  own addon API (`AZS_*`, see section 6).
- Addon language: **Lua 5.0** with the **1.12 widget API**.
- Current version: **1.20.2**. Repository: <https://github.com/CreedASui/CreedUI-for-AS->.
- 11 languages: en, fr, de, es, pt, zh, ru, ja, ko, pl, tr.

## 2. Releases

The repository holds everything since 1.8.3. Claude Code sessions here may push only their own
branch and can't make tags or GitHub releases. Releases are made by the **Release** workflow
(`.github/workflows/release.yml`, after the SurvivorsForge creator guide, steps 5 and 6): the user
opens **Actions → Release → Run workflow** on GitHub and types the version. It sets `## Version`
in the .toc and `C.VERSION` in Core.lua, commits, tags `v<version>`, zips only the `CreedUI/`
folder as **`CreedUi-<version>.zip`**, and creates the release **Creed UI <version>** with that
version's `CHANGELOG.md` entry as its text. So a session ships by merging the work with its
CHANGELOG entry (bumping the version itself is optional; the workflow does it), then telling the
user the version to type. On SurvivorsForge the release zip name is `CreedUi-*.zip` and the addon
folder `CreedUI`. If the workflow's push is refused: Settings → Actions → General → Workflow
permissions → Read and write.

## 3. Layout

```
CreedUI/            the addon (this folder name is the install folder; never rename it)
  CreedUI.toc       load order, version, notes
  Core.lua          helpers, memo writers, language system, the options hub, /creed, panel art,
                    sizers and the resize cursor, tooltip faces, the meter's per-line icons
  Locale.lua        en/fr/de/es/pt rows; Locale_<zh|ru|ja|ko|pl|tr>.lua are generated (dev/tr)
  Timer.lua         the boss timer (DON'T TOUCH unless asked: the user loves it; 1.14.2 made its rims and
                    sockets C.BRONZE and its gems red, asked for)
  Numbers.lua       floating damage numbers (combat text API); 1.20.0: crit backdrops (STACK.backs, art
                    by dev/art/make_art20.py) and six bundled OFL fonts (Fonts/Num*.ttf, licences in
                    Fonts/NumberFonts-LICENSE.txt; only Cinzel modified: instanced at Bold)
  Hurt.lua          damage taken as red numbers by the hero (new hits on AZS_TAKEN; the combat text
                    API carries outgoing hits only), heals got as green ones (AZS_HEALING; 1.16.1)
  Bosses.lua        boss and mini-boss bars        Units.lua    player and target frames
  Skulls.lua        a skull over each boss (horned, red eyes) and guardian, a gold chest over each cache
                    (world anchors, kind `cache`; 1.15.0), sized by distance
  Party.lua         party frames; a friend's shield on their health (1.20.1: UnitBuff by icon, SHIELDS; the
                    amount read off the buff's tooltip with a hidden GameTooltip, else a 20% pane; not seen
                    live: whether AS's shields are auras at all); right click: Inspect (TargetUnit then InspectUnit("target"), as the
                    game's own menu; 1.19.1: InspectUnit("party1") opened nothing live), Follow (FollowUnit), Whisper
                    (ChatFrame_SendTell, else the chat box with "/w Name"); 1.18.0                   Chat.lua     dressed chat, kept clear of the dragon; moved and sized while unlocked (db.place,
                    the game's own kept as db.home; C.resetStamp tells it of a reset)
  Downed.lua        friends down: banner + sound, a revive mark on their spot, edge arrows (world anchors)
  LevelUps.lua      the Level Up! button for stored level-ups (replaces the game's "levels" HUD part)
  Summary.lua       the run's summary panel when it ends (AZS_GetRunSummary)
  Talents.lua       the talent window: trees side by side, learned talents with ranks (meter loadout)
  Pets.lua          the pet bar over the skill bar's left end (1.15.0): the 1.12 pet buttons
                    (GetPetActionInfo...) when the game fills them, else AZS_GetSummonGroups with the
                    skills Meter.lua saw each summon use (C.petSkills, by summonKey), each with what it
                    hits for (C.hitValues, from Numbers.lua's combat text events; 1.16.1). Faces by name (FACES);
                    each pet's skills from the game's own descriptions (KNOWS, 1.16.2), shown only once
                    their hits are seen (1.17.2, asked for: Kill Command, Bite showed nothing live); their tooltips
                    (1.16.3) show the measured hits (C.hitValues: last, avg, low/high, crit, C.HitRate)
                    and AZS_STATS.pet (the game exposes no pet damage formulas)
  Bar.lua           skill bar, each ability's rank box, jewelry, XP/s, the gold panel (C.PANEL_ROOM at each
                    end for its painted dragons, Core's C.Panel)
  Tally.lua         kills / gold / cache, docked inside the bar's panel
  Minimap.lua       metal ring, local clock, zone name
  MinimapButton.lua C.EdgeButton (a draggable round button on the minimap's edge): the C button only
  Chests.lua        caches and guardians' lairs as pins on the minimap
  Meter.lua         damage meter (shown or hidden from the options hub since 1.14.3)
  Loot.lua          the loot pop-up (1.19.0, replacing 1.17's loot window, asked for): takes the game's
                    `loot` HUD part and pops up each drop and each marks gain over the skill bar, read
                    from the game's chat lines ("You receive loot: [Name] New in your collection!",
                    "marks.earned"; all 14 languages, from the client's JSON) by wrapping each
                    ChatFrame's AddMessage. No link, icon or rarity reach Lua (the game's own toast has
                    them natively), so the icon is guessed from the name (LOOKS) and the rarity from the
                    set or weapon name (LootSets.lua, written by dev/tr/loot_sets.py from the game's
                    "set.<class>.<rarity>" and "weapon.<class>.<n>.<rarity>" words; 1.20.2)
  Luck.lua          luck medallion (shown or hidden from the options hub since 1.14.3)
  TinyPlates.lua    nameplates (contributor JamieeLee, 1.14.3): based on Valorless's MIT-licensed
  TinyPlatesOptions.lua  ASTinyPlates (TinyPlates-LICENSE.txt); its own panel from the hub's button
  Character.lua     the game's character window dressed: gear slots lit by rarity, the run's stats
                    read off the game's own labels and regrouped beside it; the Skills tab is called
                    Talents and opens Talents.lua's window (the game's own if that's missing); Honor hidden.
                    Behind the level-up cards it dims (it shares panel art with the lit skill bar)
  Art/              original art, BLP2 uncompressed (made by dev/art scripts)
  Fonts/            Letters.ttf (Latin+Cyrillic, from Lora), LettersCJK.ttf (from Noto Sans CJK), OFL
dev/                tools: stand-in game client + tests, translations, art, fonts, renderer
                    (dev/README.md explains each)
dev/attic/          code kept for later (the 1.8.0 talents strip, the 1.11.0 talent-tree page)
README.md, CHANGELOG.md   (the top level holds only these, CLAUDE.md and the two folders; 1.17.3 removed an old
                    1.14.0 copy of the addon that had been uploaded there by hand)
```

## 4. Rules the code depends on

**The game and its client**
- The install folder must stay `CreedUI`. The client loads it by its .toc name, every texture and
  font path is `Interface\\AddOns\\CreedUI\\...`, and settings live in `CreedUIDB` under that name.
  Release zips are named **`CreedUi-<version>.zip`** (the user's choice) and contain `CreedUI/`.
- **Lua 5.0:** no `#` (use `table.getn`), no `string.match` (use `string.find` with captures), no
  hex literals, `math.mod` not `%`, varargs through `arg` (`arg.n`), and at most 32 upvalues per function.
  Scripts get `this`, `event` and `arg1` as globals.
- **Only real 1.12 widget methods.** `dev/engine_methods.lua` lists them; the stand-in client errors
  on anything else, even *reading* a method a widget type doesn't have (`texture.IsMouseEnabled`). Check
  the object type first.
- **At most 200 locals** at a file's top level (Lua 5.0): Numbers.lua is near it; group new constants
  in a table.
- **Lists:** take items off with `table.remove`, never `list[n] = nil`: in Lua 5.0 that leaves
  `table.getn` as it was (it broke the skulls' pool in 1.9.0 to 1.11.0).
- **No stray `nil` arguments.** The game's API counts a passed `nil` as an argument and refuses
  the call. Use `C.Call(fn, a, b)`, and pass exact counts (`SetTexCoord` takes 4 *or* 8).
- **Memo writers** in Core (`C.SetText`, `C.Size`, `C.Width`, `C.Place`, `C.Vis`, `C.Alpha`, `C.Color`,
  `C.TextColor`, `C.TextWidth`) skip unchanged writes. Never mix them with direct calls on the same
  region.

**Text and languages**
- The game's fonts have no Chinese, Japanese, Korean or Cyrillic letters (and miss some Polish and
  Turkish ones), and a missing letter draws *nothing*.
  - Make font strings with `C.Text` / `C.SetFace` so the language's bundled face applies.
  - Show our own tooltips with `C.ShowTip()` (it swaps the tooltip's faces) instead of
    `GameTooltip:Show()`. Tooltips with the game's own content (`SetUnit`, `SetAction`, `SetTalent`)
    keep `GameTooltip:Show()`.
- Every word the player sees goes through `C.L` / `C.F` / `C.LText` and is translated into all 11
  languages: see "Translations" in `dev/README.md`. Then run `gen.py`, `locale_check.py` and
  `overflow.lua`, and check the bundled fonts have every new letter (fontTools cmap).

**Design and code style**
- **Art must be original.** The user doesn't want anything looking lifted from other addons. All
  art is drawn by the scripts in `dev/art` (numpy/PIL), except the skill bar's dragon (1.14.0): cut
  from the user's own bar picture (`dev/art/source/bar_reference.webp`, made for them with an image
  generator) by `dev/art/cut_dragon.py`. `make_dragon.py` is the earlier drawn dragon, kept.
- **The gold** comes from that picture: panel metal (0.95, 0.79, 0.44), titles and tooltip heads
  (0.98, 0.85, 0.52), borders and rims (0.91, 0.70, 0.30). Use these for anything gold.
  `C.Pal()` is the timer's zone palette with its metal (rim, title, gem, glow, trough, mc) swapped
  for `C.BRONZE` in every zone (1.14.1, asked for): every part is bronze gold; the timer keeps its own.
- The look: dark glass, a gold rail, the timer's metal, diamonds on corners (`C.Panel`). Smooth,
  "eye candy", but calm.
- **Parts:** every part registers with `C.RegisterPart` (key, name, note, get, set; optional scale),
  can be turned off (giving back the game's own UI exactly), and wraps its OnUpdate in `pcall`. After
  an error it turns itself off with a translated message.
- Comments are plain English prose describing what the player sees. Keep that voice.
- The options hub lays the parts out in two columns (the first half on the left) and grows 26 px
  per two parts: at 23 parts it's about 484 px tall. A test keeps it under 700 px.

## 5. Checking before shipping

Build Lua 5.0.3 (lua.org) and install Python 3 with numpy, Pillow, scipy, fontTools and opencv-python.
From `dev/`:

```
lua50 cui/tests.lua . ../CreedUI                # 623 passed, 0 failed
lua50 cui/tiny_plates_tests.lua . ../CreedUI    # 35 passed
lua50 cui/timer_tests.lua . ../CreedUI          # 82 passed
lua50 cui/numbers_harness.lua . ../CreedUI/Numbers.lua   # ALL CHECKS PASSED (also with CROWD=1)
lua50 cui/smoke.lua . ../CreedUI out            # problems: 0
lua50 cui/globals.lua . ../CreedUI              # only this, event, arg1
lua50 cui/overflow.lua . ../CreedUI             # overflows: 0
python3 cui/locale_check.py ../CreedUI          # LOCALE OK
```

For pictures, use a `cui/*prev.lua` scene and then `cui/render_cui.py`. To ship: bump `C.VERSION` in
Core.lua and `## Version` in the .toc, add a `CHANGELOG.md` entry, zip as `CreedUi-<version>.zip`,
send the user the zip and a preview, and tag and release on GitHub.

Add a test for every new behaviour, and prove a fix by showing the test fails on the old code.

## 6. The game's addon API (AZS)

The stand-in client (`dev/cui/mock_cui.lua`) encodes the exact shapes the code relies on. Read it
before using an API. Known:

- **Run state:** `AZS_RUN` (`lvl`, `xp`, `xpn`, `gold`, `kills`, `chest`, `rr`, `rrc`, `px`, `py`, ...),
  `AZS_STATS` (`luck`, `gluck`, ...; the full field list isn't known yet). `AZS_GetPhase`,
  `AZS_GetRunTime` (stops during cards and pause), `AZS_GetRunLength`, `AZS_GetLocalTime`.
- **Minimap data:** `AZS_LAIRS` + `AZS_LAIRS_UPDATED` (state asleep/awake/empty, `left`, `x`, `y`,
  `flag`), `AZS_CHESTS`.
- **The game's HUD pieces:** `AZS_SetHudShown` / `AZS_IsHudShown` (parts like `flag` and `localClock`),
  `AZS_SetOnTopOfScreens`.
- **Combat text:** `AZS_GetCombatTextCapabilities`, `AZS_GetCombatTextEvents(cursor, max)`,
  `AZS_ProjectCombatTextAnchors`, `AZS_RegisterCombatTextFrameHandler`. Events carry `meterSource` and
  `meterSourceKey` (the meter line a hit counts toward) and now a distance from the hero.
- **Meter API v1:** `AZS_GetMeterContext`, `AZS_GetMeterSnapshot(query)` (strict query keys;
  `sources` carry names and icons), checkpoints. Also summons, totems, bosses and guardians getters.
  `AZS_GetMeterLoadout({ apiVersion = 1, runId [, ownerId] })` (those keys only): `abilities` (`sourceKey`,
  `rank`, `slotId`, `learned`, `passive`), `equipment`, `talents`, `runJewelry`, and `sources[key].icon`.
  The skill bar's rank boxes match each slot to its ability by icon (by `slotId` if there are none).
- **Spells:** `AZS_SPELLS` (+ `AZS_SPELLS_UPDATED`): `{ key, spell, rank, cd, cdmax }` each, no slot.
- **The run's end:** `AZS_GetRunSummary()` is nil while the run goes on, else `AZS_END`: `result`
  (`victory`, `defeat`, `left`), `t` (seconds), `lvl`, `kills`, `elites`, `guardians`, `bosses`, `dmg`,
  `taken`, `gold`, `chests`, `magnets`, `endl`, `hero`.
- **Damage taken:** `AZS_TAKEN` (+ `_UPDATED`): `{ source, dmg }` each. The meter API itself has only
  `damage` and `healing` metrics.
- **Stored level-ups:** `AZS_GetStoredLevels()` (`AZS_RUN.sl`), `AZS_IsStoringLevels()`,
  `AZS_OpenStoredLevels()` (as the game's Level Up! button), `AZS_SetStoringLevels(on)`. The game's
  button is the `levels` HUD part.
- **Downed and revive lines:** `AZS_DOWNED` raw `{ id, name, x, y, z, ep, state }`; `AZS_GetRevive()`
  `{ down, share, by, reviving, rshare }`. `PlaySound(kit)` plays the game's sounds ("RaidWarning").
- **The game's own words** in its 14 languages (`"end.victory": "..."` and so on) are JSON inside the
  client file too: read them as UTF-8 from the bytes (`strings` drops non-ASCII letters).
- **World anchors (API 0.139.2):** read from the game's own code (below), mirrored in the stand-in.
  - `AZS_GetWorldAnchorCapabilities()`: kinds `enemy`, `elite`, `guardian`, `boss`, `finalBoss`,
    `cache`, `guardianLair`, `downedPartyMember`; attachments `position`, `overhead`; 256 a call.
  - `AZS_GetWorldAnchors(query, cursor, limit)`: query nil or `{ kinds = {...}, states = {...} }` (no
    other keys), cursor nil or a string, limit 1 to 256. Answers `{ apiVersion, catalogId, entries,
    hasMore, nextCursor, overflowed }`; each entry has `anchorId`, `kind`, a state (`alive`, `dead`,
    `downed`, `asleep`, `awake`, `empty`...), `attachments`, `positionAvailable`, `x/y/z`, ids
    (`unitId`, `cacheId`, `lairIndex`, `memberId`). Errors `NOT_READY`, `CATALOG_CHANGED` (read again
    from the start), `INVALID_ARGUMENT`.
  - `AZS_ProjectWorldAnchors(requests)`: each `{ anchorId, attachment = "position"|"overhead", offset =
    { x, y, z } }` in yards. Answers `{ cameraSampleId, frameCurrent, entries }`; each entry `state`
    (`onScreen`, `offscreen`, `behindCamera`, `clipped`, `notReady`, `expired`, `unknownAnchor`,
    `worldChanged`, `unsupportedAttachment`), `targetState`, `x`, `y` (WorldFrame's bottom left, as
    combat text), `cameraDepth`, `uiUnitsPerYard`, `playerDistance`.
  - `AZS_RegisterWorldAnchorFrameHandler(fn)`: called each frame after the camera, as combat text's.
  - `AZS_GetDownedPartyMembers()`: no arguments; a list of `{ id, name, positionAvailable, anchorStatus,
    anchorId, x, y, z, mapId, runId, spaceId }` (nil and an error before the run's lines come).
    `AZS_GetRevive()` / `AZS_REVIVE`: `{ down, share, by, reviving, rshare }` (your own revive and
    the friend you stand over). `AZS_DOWNED` + `AZS_DOWNED_UPDATED` are the raw list.
  - The exact nesting of the answers is the one thing not seen live: `/creed probe` prints them.
- **Where the API is written down:** the game's Lua for every `AZS_*` function, with comments, is
  inside its client, `https://wow.aethus.pl/wenilla_bg.wasm` (about 90 MB): `strings -n 3` it and
  search for `function AZS_`. The native side's field names and error messages are there too.
- `/creed probe` prints `AZS_STATS`, `AZS_RUN` and the stats the character panel found. Ask the user
  for its output when you need field names.

## 7. Next

1. **Boss skulls (1.9.0):** done, not yet seen in the real client. Ask the user for a screenshot in a
   boss fight and the output of `/creed probe` there; adjust `Skulls.lua` and the stand-in if the
   answers are nested differently.
2. **1.11.0, not yet seen in the real client:** downed friends (does the projection give `x`/`y` for
   off-screen anchors? the arrow needs them; is `AZS_GetRevive().reviving` a name or an id? both are
   matched), the summary's fields, the Level Up! button, Damage Taken. Ask for screenshots.
   Ideas not done yet: talent/summon timers (`AZS_GetTimers`), arrows to caches and lairs, the
   upcoming bosses (`AZS_GetUpcomingBosses`; ask first, the timer is the user's favorite).
3. **The user's list, not done yet (2026-11-04):** the pet
   bar (done in 1.15.0; not seen live: whether the game fills the 1.12 pet buttons); the meter counting
   echo and procs right (since 0.141.0 the game files Windfury under Windfury Weapon and pet skills
   under the pet; 1.14.3 puts every pet's and summon's skills on one Pet line, asked for).
   Done in 1.16.0: number motions (Numbers.lua `STACK.motion`: Lua 5.0's 200-local limit is reached,
   so new constants go in an existing table), active counts on the skill bar (Bar.lua `LASTS` by icon,
   guessed durations, counted from cooldown restarts; totems from AZS_GetTotems), each hero's best
   skill on Party DPS (a second snapshot, scope party, groupBy source).
   Done in 1.14.3: Scholomance timer theme (zone key `scholomance`), damage taken by the hero
   (Hurt.lua), pins fading under the minimap's arrow (no facing in the API to redraw it on top).
4. **Talents (1.13.0):** the tab opens the game's window again (`ToggleTalentFrame()`, 1.14.2, asked
   for); `/creed talents` opens Talents.lua's: the meter loadout's `talents` (`sourceKey`, `rank`,
   `treeKey`, `specKey`; names and icons in `sources`), learned ones only. Tree names: the key's last
   part in title case, through C.L (the game's 24 tree names are rows). Not seen live: `treeKey`.
5. **Not yet confirmed in the real client:**
   - the bundled TTFs loading from the addon folder, and CJK rendering;
   - `SetCursor` taking an addon texture (the resize arrow; if it fails, the drawn arrow comes back);
   - the character window's assumptions: stats are read as "Label:" with the value on the same row,
     and the Run Stats panel is found by its title;
   - the downed mark's class crest (`Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes`,
     in the game's boot manifest; the 1.12 coordinates).

   Ask the user for a screenshot after each change in these areas.
