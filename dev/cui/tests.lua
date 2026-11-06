-- Behaviour tests for Creed UI under Lua 5.0 with the mock client.
-- usage: lua50 tests.lua <scratch> <addon dir>
MOCK_SCRATCH = arg[1]
local DIR = arg[2]
dofile(MOCK_SCRATCH .. "/cui/mock_cui.lua")
dofile(MOCK_SCRATCH .. "/bt/sim.lua")
local M = MOCK

local failures, passes = {}, 0
local function check(cond, what)
	if cond then passes = passes + 1 else
		table.insert(failures, what)
		print("FAIL: " .. what)
	end
end
local function frames(n, dt) for i = 1, n do M.Frame(dt or (1 / 30)) end end
local function problems(label)
	local n = table.getn(M.problems)
	check(n == 0, label .. ": no mock problems (" .. n .. ")")
	for i = 1, math.min(n, 3) do print("  " .. M.problems[i]) end
	M.problems = {}
end
local function chatHas(pat)
	for i = 1, table.getn(M.chat) do if string.find(M.chat[i], pat) then return true end end
	return false
end
local function visibleAlpha(o)
	if not M.Visible(o) then return 0 end
	return (o.__alpha or 1) * M.FrameAlpha(o.__parent)
end
-- visible text under a frame (any depth)
local function under(o, root)
	local p = o.__parent
	while p do
		if p == root then return true end
		p = p.__parent
	end
	return false
end
local function textsUnder(root)
	local out = {}
	for _, o in ipairs(M.All()) do
		if o.__kind == "FontString" and o.__text and o.__text ~= "" and under(o, root) and visibleAlpha(o) > 0.05 then
			table.insert(out, M.Plain(o.__text))
		end
	end
	return out
end
local function findText(root, pat)
	local t = textsUnder(root)
	for i = 1, table.getn(t) do if string.find(t[i], pat) then return t[i] end end
	return nil
end
local function countTex(root, pat, minAlpha)
	local n = 0
	for _, o in ipairs(M.All()) do
		if o.__kind == "Texture" and o.__tex and string.find(o.__tex, pat) and under(o, root) then
			local a = visibleAlpha(o) * (o.__vc and o.__vc[4] or 1)
			if a > (minAlpha or 0.3) then n = n + 1 end
		end
	end
	return n
end

------------------------------------------------------------------ 1. load
M.InstallAPI()
M.phase = "ready"
M.hud.clock, M.hud.bosses, M.hud.build = true, true, true
M.Load(DIR)
frames(30)
check(M.hud.clock == false and M.hud.bosses == false and M.hud.build == false, "the game's clock, boss bars and build rows are hidden")
check(PlayerFrame.__parent == CreedUIHidden and TargetFrame.__parent == CreedUIHidden and MainMenuBar.__parent == CreedUIHidden,
	"the game's player frame, target frame and bar are tucked away")
check(CreedUIPlayer.__shown, "your frame shows out of a run")
check(CreedUIBar.__shown, "the skill bar shows out of a run")
check(not CreedUITimerFrame.__shown, "the timer waits for a run")
problems("load")

------------------------------------------------------------------ 2. a run with bosses and a guardian
SIM.StartRun("naxx", { killAfter = 40 })
local b = SIM.run.bosses
M.runTime = b[2].at + 4
b[1].state = "dead"
SIM.Publish()
M.guardians = { { id = 77, name = "Sir Zeliek", hp = 21500, hpm = 36000, awake = true } }
SIM.Advance(2, 1 / 30)
check(CreedUITimerFrame.__shown, "the timer shows in the run")
check(findText(CreedUIBosses, "^Noth the Plaguebringer$") ~= nil, "a bar for the boss that's up: " .. table.concat(textsUnder(CreedUIBosses), " | "))
check(findText(CreedUIBosses, "^Sir Zeliek$") ~= nil, "a bar for the awake mini-boss")
check(findText(CreedUIBosses, "^21.5K / 36K   60%%$") ~= nil, "the mini-boss shows its real health: " .. tostring(findText(CreedUIBosses, "36K")))
local noth = findText(CreedUIBosses, "/ 100K")
check(noth ~= nil, "the boss shows its real health: " .. tostring(noth))
-- the bars sit under the timer's next-boss line, never over it
local callout
for _, o in ipairs(M.All()) do
	if o.__kind == "FontString" and o.__text and string.find(M.Plain(o.__text), "^Patchwerk") and under(o, CreedUITimerFrame) then callout = o end
end
check(callout ~= nil, "the timer's next-boss line is there")
if callout then
	local _, cb = M.Rect(callout)
	local highest = -1
	for _, o in ipairs(M.All()) do
		if (o.__kind == "FontString" or o.__kind == "Texture") and under(o, CreedUIBosses) and visibleAlpha(o) > 0.05 then
			local _, ob, _, ot = M.Rect(o)
			if ot > highest and o.__tex ~= nil and string.find(o.__tex or "", "Glow") == nil then highest = ot end
			if o.__kind == "FontString" and ot > highest then highest = ot end
		end
	end
	check(highest < cb, string.format("the boss bars start below the next-boss line (%.1f < %.1f)", highest, cb))
end
-- the boss dies: its bar drains and goes; the mini-boss bar slides up
SIM.Advance(40, 1 / 30)
check(findText(CreedUIBosses, "^Noth the Plaguebringer$") == nil, "a slain boss's bar goes away")
check(findText(CreedUIBosses, "^Sir Zeliek$") ~= nil, "the mini-boss bar stays")
M.guardians = {}
SIM.Advance(2, 1 / 30)
check(not CreedUIBosses.__shown or visibleAlpha(CreedUIBosses) < 0.05, "no bars when nothing big is fighting")
problems("bosses")

------------------------------------------------------------------ 3. damage numbers: a DoT on a crowd merges
local function labelsWith(iconPat)
	local n = 0
	for _, o in ipairs(M.All()) do
		if o.__kind == "Texture" and o.__tex and string.find(o.__tex, iconPat) and under(o, CreedUINumbersLayer) and visibleAlpha(o) > 0.2 then
			n = n + 1
		end
	end
	return n
end
local crowd = {}
for i = 1, 12 do crowd[i] = M.Enemy("Ghoul", -14 + math.mod(i, 4) * 6, -6 + math.floor(i / 4) * 5) end
local maxCorr, sawTotal = 0, false
for second = 1, 4 do
	for i = 1, 12 do M.Hit(crowd[i], 10, "corruption", true) end
	for f = 1, 30 do
		M.Frame(1 / 30)
		local n = labelsWith("AbominationExplosion")
		if n > maxCorr then maxCorr = n end
		for _, o in ipairs(M.All()) do
			if o.__kind == "FontString" and o.__text and under(o, CreedUINumbersLayer) and visibleAlpha(o) > 0.2 and M.Plain(o.__text) == "120" then sawTotal = true end
		end
	end
end
check(maxCorr >= 1 and maxCorr <= 3, "Corruption on 12 enemies shows one number a second, not twelve (most at once: " .. maxCorr .. ")")
check(sawTotal, "the merged number is the whole second's damage (12 x 10 = 120)")
frames(120)
-- two enemies: each keeps its own DoT total
local pair = { M.Enemy("Ghoul", -20, 8), M.Enemy("Ghoul", 20, 8) }
local maxPair = 0
for second = 1, 3 do
	M.Hit(pair[1], 10, "corruption", true)
	M.Hit(pair[2], 10, "corruption", true)
	for f = 1, 30 do
		M.Frame(1 / 30)
		local n = labelsWith("AbominationExplosion")
		if n > maxPair then maxPair = n end
	end
end
check(maxPair == 2, "a DoT on two enemies keeps one total each (" .. maxPair .. ")")
frames(200)
-- every spell merged, as an option
CreedUIDB.numbers.bySpell = true
local maxStrike = 0
for f = 1, 60 do
	if math.mod(f, 6) == 0 then for i = 1, 6 do M.Hit(crowd[i], 500, "strike", false) end end
	M.Frame(1 / 30)
	local n = labelsWith("RitualOfSacrifice")
	if n > maxStrike then maxStrike = n end
end
check(maxStrike >= 1 and maxStrike <= 3, "with every spell merged, strikes on six enemies show one number a second (" .. maxStrike .. ")")
CreedUIDB.numbers.bySpell = false
frames(200)
problems("numbers")

------------------------------------------------------------------ 4. your frame
AZS_RUN.sh, AZS_RUN.lives, AZS_RUN.proc, AZS_RUN.pv, AZS_RUN.pm, AZS_RUN.lvl = 300, 2, "seal_fate", 4, 5, 20
M.unit.player.hp, M.unit.player.hpm = 1840, 2400
frames(20)
check(findText(CreedUIPlayer, "^1,840 / 2,400  %+300$") ~= nil, "your health with real numbers and the shield: " .. table.concat(textsUnder(CreedUIPlayer), " | "))
check(findText(CreedUIPlayer, "^85 / 100$") ~= nil, "your energy")
check(findText(CreedUIPlayer, "^x2$") ~= nil, "your extra lives")
check(findText(CreedUIPlayer, "^20$") ~= nil, "your run level on the badge")
check(countTex(CreedUIPlayer, "Diamond", 0.3) == 5, "five combo point gems (" .. countTex(CreedUIPlayer, "Diamond", 0.3) .. ")")
M.unit.player.hp = 300
frames(40)
check(findText(CreedUIPlayer, "^300 / 2,400") ~= nil, "health text follows")
problems("player")

------------------------------------------------------------------ 5. your target's frame
M.unit.target = { exists = true, name = "Plagued Ghoul", hp = 300, hpm = 900, level = 20, hostile = true }
AZS_TARGET = { kind = "elite", id = 5, name = "Plagued Ghoul", hp = 640, hpm = 1600, state = 0, elite = 1 }
M.Fire("PLAYER_TARGET_CHANGED")
frames(20)
check(visibleAlpha(CreedUITarget) > 0.9, "the target frame shows")
check(findText(CreedUITarget, "^640 / 1,600$") ~= nil, "the target's real health (from the game's run data): " .. table.concat(textsUnder(CreedUITarget), " | "))
check(findText(CreedUITarget, "^Elite$") ~= nil, "its kind")
-- a boss targeted wears the game's gold elite dragon round its portrait; a guardian the silver one
local function dragon(file)
	local n = 0
	for _, o in ipairs(M.All()) do
		if o.__kind == "Texture" and o.__tex and string.find(o.__tex, file .. "$") and under(o, CreedUITarget) and M.Visible(o) then n = n + 1 end
	end
	return n
end
check(dragon("UI%-TargetingFrame%-Elite") == 0 and dragon("UI%-TargetingFrame%-Rare") == 0, "an elite pack mob: no dragon")
AZS_TARGET = { kind = "boss", id = 9, name = "Kirtonos the Herald", hp = 9000, hpm = 10000, state = 0 }
M.unit.target = { exists = true, name = "Kirtonos the Herald", hp = 9000, hpm = 10000, level = 63, hostile = true }
frames(10)
check(dragon("UI%-TargetingFrame%-Elite") == 3, "a boss: the gold elite dragon round its portrait (three pieces)")
AZS_TARGET = { kind = "guardian", id = 10, name = "Risen Construct", hp = 5000, hpm = 6000, state = 0 }
M.unit.target = { exists = true, name = "Risen Construct", hp = 5000, hpm = 6000, level = 62, hostile = true }
frames(10)
check(dragon("UI%-TargetingFrame%-Rare") == 3 and dragon("UI%-TargetingFrame%-Elite") == 0, "a guardian: the silver dragon")
M.unit.target = { exists = false }
AZS_TARGET = { kind = "none" }
M.Fire("PLAYER_TARGET_CHANGED")
frames(30)
check(not CreedUITarget.__shown, "it fades away without a target")
problems("target")

------------------------------------------------------------------ 6. the skill bar
M.actions[3].start, M.actions[3].dur = M.now, 8
frames(10)
check(findText(CreedUIBar, "^8$") ~= nil, "a cooldown counts down on its ability: " .. table.concat(textsUnder(CreedUIBar), " | "))
check(findText(CreedUIBar, "^Level 20  %-  %d+ / %d+$") ~= nil, "the run's experience")
check(countTex(CreedUIBar, "Necklace") == 1 and countTex(CreedUIBar, "Ring_03") == 1, "your neck and ring in their sockets")
local sockets = 0
for _, o in ipairs(M.All()) do
	if o.__kind == "Texture" and o.__tex and string.find(o.__tex, "Art\\Jewel$") and under(o, CreedUIBar) and M.Visible(o) then sockets = sockets + 1 end
end
check(sockets == 5, "five jewelry sockets: neck, two rings, two trinkets (" .. sockets .. ")")
M.gear[14] = { tex = "Interface\\Icons\\INV_Trinket_04", q = 3 }
frames(30)
check(countTex(CreedUIBar, "INV_Trinket_04") == 1, "a second trinket shows in its own socket")
M.gear[14] = nil
frames(30)
local icons = countTex(CreedUIBar, "Icons", 0.5)
check(icons == 7, "four abilities, the racial and two jewels show their icons (" .. icons .. ")")
SIM.Advance(8.5, 1 / 30)
check(findText(CreedUIBar, "^%d$") == nil, "the countdown ends")
-- hovering: the game's own tooltips
local function slotWith(pat)
	for _, o in ipairs(M.All()) do
		if o.__kind == "Texture" and o.__tex and string.find(o.__tex, pat) and under(o, CreedUIBar) then return o.__parent end
	end
end
local neck = slotWith("Necklace")
this = neck
neck.__scripts.OnEnter()
check(M.tip.shown and M.tip.inv == 2, "hovering the neck shows its item tooltip")
neck.__scripts.OnLeave()
local strike = slotWith("RitualOfSacrifice")
strike.__scripts.OnEnter()
check(M.tip.shown and M.tip.action == 1, "hovering an ability shows its tooltip")
strike.__scripts.OnLeave()
-- a new ring from the cards appears in its socket
M.gear[12] = { tex = "Interface\\Icons\\INV_Jewelry_Ring_15", q = 5 }
frames(30)
check(countTex(CreedUIBar, "Ring_15") == 1, "a newly picked ring shows up")
-- a level up runs the bar to the end and starts again
AZS_RUN.lvl, AZS_RUN.xp, AZS_RUN.xpn = 21, 2, 27
frames(60)
check(findText(CreedUIBar, "^Level 21") ~= nil, "the level up shows")
problems("bar")

------------------------------------------------------------------ 7. the hub and turning parts off and on
M.Slash("")
check(CreedUIOptions and CreedUIOptions.__shown, "/creed opens the options")
M.Slash("bosses off")
frames(5)
check(M.hud.bosses == true, "boss bars off gives the game's boss bars back")
M.Slash("bosses on")
check(M.hud.bosses == false, "and on hides them again")
M.Slash("bar off")
check(M.hud.build == true and MainMenuBar.__parent ~= CreedUIHidden and not CreedUIBar.__shown, "skill bar off brings the game's bar back")
M.Slash("bar on")
check(M.hud.build == false and MainMenuBar.__parent == CreedUIHidden and CreedUIBar.__shown, "and on replaces it again")
M.Slash("player off")
check(PlayerFrame.__parent ~= CreedUIHidden and not CreedUIPlayer.__shown, "your frame off brings the game's back")
M.Slash("player on")
frames(3)
check(PlayerFrame.__parent == CreedUIHidden and CreedUIPlayer.__shown, "and on replaces it")
M.Slash("target off")
check(TargetFrame.__parent ~= CreedUIHidden, "target frame off brings the game's back")
M.Slash("target on")
M.Slash("timer off")
frames(10)
check(M.hud.clock == true, "timer off gives the game's clock back")
M.Slash("timer on")
frames(5)
check(M.hud.clock == false, "and on hides it again")
M.Slash("numbers off")
check(M.cvars.CombatDamage == "1", "numbers off gives the game's numbers back")
M.Slash("numbers on")
check(M.cvars.CombatDamage == "0", "and on hides them again")
-- every hub row and button can be clicked
local clicked = 0
for _, o in ipairs(M.All()) do
	if o.__kind == "Button" and under(o, CreedUIOptions) and o.__scripts.OnClick then
		local label = nil
		for _, k in ipairs(M.All()) do
			if k.__parent == o and k.__kind == "FontString" then label = k.__text end
		end
		if label ~= "x" and not under(o, CreedUILanguageMenu) then -- the languages have a test of their own
			this = o
			o:Click()
			clicked = clicked + 1
			frames(2)
			o:Click() -- and back
			frames(2)
		end
	end
end
check(clicked >= 14, "every hub control works (" .. clicked .. ")")
problems("hub")
-- the themes: a class's metal on every part, the dragons cast in it, the timer still bronze
local function near(a, b) return math.abs(a - b) < 0.01 end
local function onBar(file)
	local n = 0
	for _, o in ipairs(M.All()) do
		if o.__kind == "Texture" and o.__tex and string.find(o.__tex, file .. "$") and under(o, CreedUIBar) and M.Visible(o) then n = n + 1 end
	end
	return n
end
-- the theme is the hero's class, no choice in the options (asked for)
check(CreedUI.uiTheme == "rogue" and near(CreedUI.Pal().rim[1], 0.94), "your class (a rogue): the rogue's yellow metal")
check(onBar("PanelEmblemRogueL") == 1 and onBar("PanelEmblemRogueR") == 1, "the rogue's emblem and crest on the bar")
check(onBar("PanelRailRogueT") == 1 and onBar("PanelRailRogueB") == 1, "and the rogue's own rails along it")
check(onBar("PanelRailL") == 0 and onBar("PanelCornerTL") == 0 and onBar("PanelRailR") == 0 and onBar("PanelCornerBR") == 0, "the panel's end pieces step aside under the emblem and the crest")
check(CreedUIThemeMenu == nil and findText(CreedUIOptions, "^Theme") == nil, "no theme to pick in the options")
check(near(CreedUI.BRONZE.rim[1], 0.95), "the boss timer keeps its bronze")
M.unit.player.class = "Mage"
M.Fire("PLAYER_ENTERING_WORLD")
frames(5)
local rim = CreedUI.Pal().rim
check(near(rim[1], 0.48) and near(rim[3], 0.95), "a mage enters the world: the parts' rims turn frost blue")
check(onBar("PanelEmblemMageL") == 1 and onBar("PanelEmblemMageR") == 1 and onBar("PanelDragon") == 0, "the mage's emblem on the left end and crest on the right")
local fill
for _, o in ipairs(M.All()) do
	if o.__kind == "Texture" and o.__tex and string.find(o.__tex, "PanelGlass$") and under(o, CreedUIBar) then fill = o end
end
check(fill and fill.__vc and near(fill.__vc[3], 0.95) and fill.__vc[3] > fill.__vc[1], "the bar's glass in the mage's blue")
-- a game that can't show the glass: the panel's own, darkened to the class's color, never flat bright
CreedUIBar.deco.glassSet = nil
M.missingArt = { PanelGlass = true }
CreedUI.palStamp = CreedUI.palStamp + 1
frames(3)
check(fill.__tex and string.find(fill.__tex, "PanelFill$") and fill.__vc[3] < 0.5, "no glass texture: the panel's own glass, darkened in the mage's blue")
M.missingArt = nil
CreedUIBar.deco.glassSet = nil
CreedUI.palStamp = CreedUI.palStamp + 1
frames(3)
check(string.find(fill.__tex, "PanelGlass$") ~= nil, "and the class glass when it's there")
M.unit.player.class = nil
M.Fire("PLAYER_ENTERING_WORLD")
frames(5)
check(CreedUI.uiTheme == "warrior", "before any run or class is known: a warrior's look, no bronze")
check(not CreedUI.SetTheme("bronze") and CreedUI.uiTheme == "warrior", "there is no bronze look any more")
check(onBar("PanelDragon") == 0, "nor dragons")
M.unit.player.class = "Rogue"
M.Fire("PLAYER_ENTERING_WORLD")
frames(5)
-- the class of the hero the run was started with, read from the run's loadout (asked for: the
-- character's class isn't the run's hero's)
local meterWas, loadoutWas, runWas = M.meter, M.loadout, M.meterRun
M.meter = M.meter or { damage = {} }
M.loadout, M.heroClass, M.meterRun = { abilities = {} }, "druid", "runA"
SIM.Advance(1.5, 1 / 30)
check(CreedUI.uiTheme == "druid" and onBar("PanelEmblemDruidL") == 1, "a run started as a druid (the character a rogue): the druid's look")
check(CreedUIDB.heroClass == "druid", "kept for next time")
M.Fire("PLAYER_ENTERING_WORLD")
frames(5)
check(CreedUI.uiTheme == "druid", "and it stays through a loading screen")
M.heroClass, M.meterRun = "HUNTER", "runB"
SIM.Advance(1.5, 1 / 30)
check(CreedUI.uiTheme == "hunter", "the next run, as a hunter: the hunter's look")
M.heroClass, M.meterRun = nil, "runC"
SIM.Advance(1.5, 1 / 30)
check(CreedUI.uiTheme == "rogue", "a run as the rogue again: the rogue's look")
M.meter, M.loadout, M.meterRun = meterWas, loadoutWas, runWas
problems("themes")

------------------------------------------------------------------ 8. moving frames
M.Slash("move")
frames(3)
local box
for _, o in ipairs(M.All()) do
	if o.__kind == "Frame" and o.__parent == CreedUIPlayer and o.__backdrop and o.__shown then box = o end
end
check(box ~= nil, "move shows a handle on your frame")
if box then
	M.dragBy = { 200, -100 }
	this = box
	box.__scripts.OnDragStart()
	box.__scripts.OnDragStop()
	M.dragBy = nil
	local p = CreedUIDB.pos and CreedUIDB.pos.player
	check(p ~= nil, "the new place is saved")
end
M.Slash("lock")
M.Slash("reset")
check(CreedUIDB.pos and CreedUIDB.pos.player == nil, "reset puts frames back")
problems("move")

------------------------------------------------------------------ 9. logout and reload
M.Fire("PLAYER_LOGOUT")
check(M.hud.clock == true and M.hud.bosses == true and M.hud.build == true, "logout leaves the game's HUD settings as they were")
M.Reload(DIR, false)
frames(10)
check(M.hud.clock == false and M.hud.bosses == false and M.hud.build == false, "hidden again after the reload")
problems("reload")

------------------------------------------------------------------ 10. the old addons still installed
M.loaded.SmoothNumbers, M.loaded.SmoothBossTimer = true, true
M.chat = {}
M.Reload(DIR, true)
frames(10)
check(chatHas("part of Creed UI now"), "a note to turn the old addons off")
check(not CreedUITimerFrame, "the timer stays off while Smooth Boss Timer runs")
M.loaded.SmoothNumbers, M.loaded.SmoothBossTimer = nil, nil
M.Reload(DIR, true)
frames(10)
problems("old addons")

------------------------------------------------------------------ 11. a long run, everything on
SIM.StartRun("arena", { killAfter = 30 })
M.guardians = { { id = 9, name = "Gurubashi Champion", hp = 8000, hpm = 9000, awake = true } }
M.calls, M.callNames = 0, {}
local hits = 0
SIM.Advance(120, 1 / 60, function(s)
	if math.mod(s, 30) == 0 then
		for i = 1, 12 do M.Hit(crowd[i], 12, "corruption", true) end
		M.Hit(crowd[1], 800, "strike", false)
		M.guardians[1].hp = math.max(0, M.guardians[1].hp - 40)
	end
end)
print(string.format("widget calls per frame, everything on: %.0f", M.calls / 7200))
local list = {}
for k, v in pairs(M.callNames) do table.insert(list, { k, v }) end
table.sort(list, function(a, c) return a[2] > c[2] end)
for i = 1, math.min(8, table.getn(list)) do io.write(string.format("%s %.1f  ", list[i][1], list[i][2] / 7200)) end
print()
problems("long run")

------------------------------------------------------------------ 11b. what came after 1.0
do
	-- a fast skill counts down in tenths, and every cooldown shows a number
	M.actions[2].start, M.actions[2].dur = M.now, 1.5
	frames(4)
	check(findText(CreedUIBar, "^1%.%d$") ~= nil, "a fast skill counts down in tenths: " .. table.concat(textsUnder(CreedUIBar), " | "))
	frames(60)
	check(findText(CreedUIBar, "^%d%.%d$") == nil, "and the number clears when it's ready")

	-- while the cards are up the cooldowns hold still (the game's own numbers jump about then)
	M.phase = "playing"
	M.actions[3].start, M.actions[3].dur = M.now, 8
	frames(10)
	M.phase = "choosing"
	frames(2)
	-- the bar fades away under the cards, but its numbers must hold still for its return
	local function cdText()
		for _, o in ipairs(M.All()) do
			if o.__kind == "FontString" and o.__text and under(o, CreedUIBar) and o.__shown then
				local t = M.Plain(o.__text)
				if string.find(t, "^%d$") or string.find(t, "^%d%.%d$") then return t end
			end
		end
	end
	local held = cdText()
	local steady = held ~= nil
	for f = 1, 45 do
		M.actions[3].start = M.now - math.random() * 2 -- the jitter
		M.actions[1].start, M.actions[1].dur = M.now - 0.01, (math.mod(f, 2) == 0) and 0.02 or 0
		M.Frame(1 / 30)
		if cdText() ~= held then steady = false end
	end
	check(steady, "while choosing a card the cooldown numbers hold still (" .. tostring(held) .. ")")
	check(not CreedUIBar.__shown, "and the bar is away, clear of the cards")
	M.actions[1].start, M.actions[1].dur = 0, 0
	M.actions[3].start, M.actions[3].dur = M.now - 1, 8
	M.phase = "playing"
	frames(45)
	check(findText(CreedUIBar, "^%d$") ~= held, "and count on once the game goes on")
	frames(240)

	-- the experience bar is gold
	local xpFill
	for _, o in ipairs(M.All()) do
		if o.__kind == "Texture" and o.__tex and string.find(o.__tex, "Art\\Fill$") and under(o, CreedUIBar) and o.__grad then xpFill = o.__grad[2] end
	end
	check(xpFill and xpFill[1] > 0.7 and xpFill[2] > 0.5 and xpFill[3] < 0.3, "the experience bar is gold")

	-- pets' and summons' swings get an icon, even with several kinds out
	CreedUIDB.numbers.crowd = false
	local function PetHit(e, amount, kind, sourceId)
		local w = M.world
		w.nAnchor = w.nAnchor + 1
		local anchorId = "a" .. w.nAnchor
		w.anchors[anchorId] = { enemy = e, born = M.now }
		w.nEvents = w.nEvents + 1
		w.events[w.nEvents] = { eventId = "e" .. w.nEvents, presentedAt = M.now, targetId = e.id, targetName = e.name,
			sourceKind = kind, sourceId = sourceId, kind = "damage", amount = amount, critical = false, periodic = false,
			anchorId = anchorId, anchorStatus = "ready", damageType = "melee", schoolMask = 1 }
	end
	M.summons = {
		{ id = 5, key = "wolf", kind = "pet", name = "Wolf", icon = "Interface\\Icons\\Ability_Hunter_Pet_Wolf", permanent = true },
		{ id = 6, key = "infernal", kind = "infernal", name = "Infernal", icon = "Interface\\Icons\\Spell_Shadow_SummonInfernal" },
		{ id = 7, key = "infernal", kind = "infernal", name = "Infernal", icon = "Interface\\Icons\\Spell_Shadow_SummonInfernal" },
		{ id = 8, key = "imp", kind = "imp", name = "Imp", icon = "Interface\\Icons\\Spell_Shadow_SummonImp", permanent = true },
	}
	AZS_PETS_UPDATED = M.now
	frames(2)
	local foes = {}
	for i = 1, 6 do foes[i] = M.Enemy("Ghoul", -16 + i * 5, 12) end
	PetHit(foes[1], 50, "pet", "zz1")
	frames(3)
	check(labelsWith("Pet_Wolf") >= 1, "a pet's swing shows the pet's icon")
	PetHit(foes[2], 60, "summon", "zz2")
	frames(3)
	check(labelsWith("SummonInfernal") >= 1, "a summon's swing shows the most numerous summon's icon")
	for k = 1, 12 do
		PetHit(foes[3], 40, "pet", 8)
		frames(2)
	end
	frames(200)
	PetHit(foes[5], 40, "pet", 8)
	frames(3)
	check(labelsWith("SummonImp") >= 1, "once the attacker ids prove to match, each swing shows its own summon (the Imp)")
	M.summons = {}
	AZS_PETS_UPDATED = M.now
	M.unit.player.class = "Hunter"
	frames(2)
	PetHit(foes[4], 30, "pet", "zz3")
	frames(3)
	check(labelsWith("BeastCall") >= 1, "with no summon list, a hunter's pet still gets an icon")
	M.unit.player.class = "Rogue"
	CreedUIDB.numbers.crowd = true
	frames(200)

	-- any spell on three or more enemies merges into one number
	local most = 0
	for f = 1, 60 do
		if math.mod(f, 6) == 0 then for i = 1, 6 do M.Hit(crowd[i], 500, "strike", false) end end
		M.Frame(1 / 30)
		local n = labelsWith("RitualOfSacrifice")
		if n > most then most = n end
	end
	check(most >= 1 and most <= 3, "strikes on six enemies merge into one number a second (" .. most .. ")")
	frames(200)
	problems("numbers after 1.0")

	-- every enemy bar is red, mini-bosses too
	M.guardians = { { id = 31, name = "Lady Blaumeux", hp = 125500, hpm = 127900, awake = true } }
	AZS_UNITS_UPDATED = M.now
	frames(30)
	local gfill
	for _, o in ipairs(M.All()) do
		if o.__kind == "Texture" and o.__tex and string.find(o.__tex, "Art\\Fill$") and under(o, CreedUIBosses) and M.Visible(o) and o.__grad then gfill = o.__grad[2] end
	end
	check(gfill and gfill[1] > gfill[2] * 3 and gfill[1] > gfill[3] * 3, "the mini-boss bar is red")
	-- the run ends: the bars fade without draining, as nothing died
	M.phase = "dead"
	frames(3)
	check(findText(CreedUIBosses, "^125.5K / 127.9K") ~= nil and findText(CreedUIBosses, "^0%%$") == nil,
		"when the run ends the bars fade as they are: " .. table.concat(textsUnder(CreedUIBosses), " | "))
	frames(60)
	-- "Again?": the game still holds the last run's units until it sends new ones
	AZS_ZONE_UPDATED = M.now
	M.runTime = 1
	M.phase = "playing"
	frames(30)
	check(findText(CreedUIBosses, "^Lady Blaumeux$") == nil, "a new run doesn't bring back the last run's mini-bosses")
	AZS_UNITS_UPDATED = M.now
	frames(15)
	check(findText(CreedUIBosses, "^Lady Blaumeux$") ~= nil, "fresh units from the new run show")
	-- a mini-boss that walks home to sleep fades, without draining as if slain
	M.guardians[1].awake = false
	AZS_UNITS_UPDATED = M.now
	frames(3)
	check(findText(CreedUIBosses, "^0%%$") == nil, "a mini-boss gone back to sleep isn't shown as slain")
	frames(60)
	-- another "Again?": a unit publication heard after the start counts, even with the same time
	M.guardians = { { id = 32, name = "Thane Korth'azz", hp = 123800, hpm = 126300, awake = true } }
	AZS_ZONE_UPDATED = M.now + 0.5
	frames(20)
	check(findText(CreedUIBosses, "^Thane Korth'azz$") == nil, "the old list waits for the new run's units")
	M.Fire("CHAT_MSG_ADDON", "AZSUNITS")
	frames(10)
	check(findText(CreedUIBosses, "^Thane Korth'azz$") ~= nil, "a unit publication heard after the start lets them show")
	M.guardians = {}
	frames(60)
	problems("boss bars after 1.0")

	-- kills, gold and the next cache
	AZS_RUN.kills, AZS_RUN.gold, AZS_RUN.chest = 188, 143, 31
	frames(40)
	check(M.hud.tally == false, "the game's kills and gold box is hidden")
	check(findText(CreedUITally, "^188$") and findText(CreedUITally, "^143$") and findText(CreedUITally, "^31$"),
		"kills, gold and the next cache's price: " .. table.concat(textsUnder(CreedUITally), " | "))
	check(countTex(CreedUITally, "Art\\Skull$") == 1 and countTex(CreedUITally, "Art\\Coin$") == 1 and countTex(CreedUITally, "Art\\Chest$") == 1,
		"each with its little icon")
	check(countTex(CreedUITally, "Glow", 0.1) >= 1, "the cache glows while you can afford it")
	AZS_RUN.gold = 10
	frames(40)
	check(countTex(CreedUITally, "Glow", 0.1) == 0, "and stops when you can't")
	AZS_RUN.kills = 250
	frames(40)
	check(findText(CreedUITally, "^250$") ~= nil, "kills roll up to the new count")
	this = CreedUITally
	CreedUITally.__scripts.OnEnter()
	local tipText = table.concat(M.tip.lines, " / ")
	check(M.tip.shown and string.find(tipText, "Next cache | 31 gold", 1, true) ~= nil, "its tooltip tells the run's tally: " .. tipText)
	CreedUITally.__scripts.OnLeave()
	problems("tally")

	-- the party, in class colors
	M.unit.party1 = { exists = true, name = "Melkor", class = "Mage", level = 20, hp = 1500, hpm = 2000, mp = 800, mpm = 1200, power = 0 }
	M.unit.party2 = { exists = true, name = "Zulyara", class = "Priest", level = 20, hp = 900, hpm = 1800, mp = 300, mpm = 1500, power = 0 }
	M.unit.party3 = { exists = true, name = "Damyen", class = "Warrior", level = 19, hp = 0, hpm = 3000, mp = 0, mpm = 100, power = 1, dead = true }
	M.unit.party4 = { exists = true, name = "Huofa", class = "Hunter", level = 18, hp = 2000, hpm = 2000, offline = true }
	M.Fire("PARTY_MEMBERS_CHANGED")
	frames(40)
	check(PartyMemberFrame1.__parent == CreedUIHidden and PartyMemberFrame4.__parent == CreedUIHidden, "the game's party frames are tucked away")
	check(findText(CreedUIParty, "^Melkor$") ~= nil and findText(CreedUIParty, "^1,500 / 2,000$") ~= nil,
		"a friend's name and real health: " .. table.concat(textsUnder(CreedUIParty), " | "))
	check(findText(CreedUIParty, "^Dead$") ~= nil, "a dead friend says so")
	check(findText(CreedUIParty, "^Offline$") ~= nil, "an offline friend says so")
	local function hpFill(row)
		local best
		for _, o in ipairs(M.All()) do
			if o.__kind == "Texture" and o.__tex and string.find(o.__tex, "Art\\Fill$") and under(o, row) and o.__grad then
				local _, b, _, t = M.Rect(o)
				if t - b > 9 then best = o.__grad[2] end
			end
		end
		return best
	end
	local mage, priest, warrior = hpFill(CreedUIParty1), hpFill(CreedUIParty2), hpFill(CreedUIParty3)
	check(mage and mage[3] > mage[1] * 1.5, "a mage's health bar is mage blue")
	check(priest and priest[3] >= priest[1] and priest[1] > 0.15, "a priest's starts in deep slate")
	check(warrior and warrior[1] > warrior[3] * 1.4, "a warrior's is tan")
	-- strong colors: the true and bright stops keep the class's hue instead of going whitish
	local function stops(row)
		local a2, b2
		for _, o in ipairs(M.All()) do
			if o.__kind == "Texture" and o.__tex and string.find(o.__tex, "Art\\Fill$") and under(o, row) and o.__grad then
				local _, b, _, t = M.Rect(o)
				if t - b > 9 then
					if not a2 then a2 = o else b2 = o end
				end
			end
		end
		return a2 and a2.__grad[3], b2 and b2.__grad[3]
	end
	local function sat(c) local hi, lo = math.max(c[1], c[2], c[3]), math.min(c[1], c[2], c[3]) return hi > 0 and (hi - lo) / hi or 0 end
	local mid, bright = stops(CreedUIParty1)
	check(mid and bright and sat(mid) > 0.5 and sat(bright) > 0.45 and math.max(mid[1], mid[2], mid[3]) > 0.8,
		string.format("a mage's bar is a strong, bright blue (%.2f, %.2f)", mid and sat(mid) or 0, bright and sat(bright) or 0))
	mid, bright = stops(CreedUIParty3)
	check(mid and sat(mid) > 0.4, string.format("a warrior's tan is rich, not grey (%.2f)", mid and sat(mid) or 0))
	local pmid = stops(CreedUIParty2)
	check(pmid and pmid[3] > pmid[1] and pmid[1] > 0.6, "a priest's reads as a pearl white")
	this = CreedUIParty1
	CreedUIParty1.__scripts.OnClick()
	check(M.targeted == "party1", "clicking a friend targets them")
	-- a friend's shield on their health, as your own frame shows yours
	check((CreedUIParty1.creedBar.shield or 0) == 0, "no shield, no pane")
	M.unit.party1.buffs = { "Interface\\Icons\\Spell_Nature_Regeneration", "Interface\\Icons\\Spell_Holy_PowerWordShield" }
	frames(18)
	check(CreedUIParty1.creedBar.shield > 0 and CreedUIParty1.creedBar.shieldTex.__shown ~= false and M.Visible(CreedUIParty1.creedBar.shieldTex),
		"Power Word: Shield on a friend shows its icy pane on their health: " .. tostring(CreedUIParty1.creedBar.shield))
	M.unit.party1.buffs = nil
	frames(18)
	frames(12)
	check(CreedUIParty1.creedBar.shield == 0 and not M.Visible(CreedUIParty1.creedBar.shieldTex), "and it goes when the shield does")
	-- a right click: Inspect, Follow, Whisper
	this, arg1 = CreedUIParty1, "RightButton"
	CreedUIParty1.__scripts.OnClick()
	arg1 = "LeftButton"
	check(CreedUIPartyMenu and M.Visible(CreedUIPartyMenu) and findText(CreedUIPartyMenu, "^Melkor$") ~= nil
		and findText(CreedUIPartyMenu, "^Inspect$") and findText(CreedUIPartyMenu, "^Follow$") and findText(CreedUIPartyMenu, "^Whisper$"),
		"a right click opens Inspect, Follow and Whisper under their name: " .. (CreedUIPartyMenu and table.concat(textsUnder(CreedUIPartyMenu), " | ") or "none"))
	local function press(word)
		for _, o in ipairs(M.All()) do
			if o.__kind == "FontString" and o.__text == word and under(o, CreedUIPartyMenu) then
				this = o.__parent
				o.__parent.__scripts.OnClick()
				return
			end
		end
	end
	press("Inspect")
	check(M.targeted == "party1" and M.asked[table.getn(M.asked)] == "inspect target" and not M.Visible(CreedUIPartyMenu),
		"Inspect targets them and inspects the target, as the game's own menu does; the menu closes")
	this, arg1 = CreedUIParty1, "RightButton"
	CreedUIParty1.__scripts.OnClick()
	press("Follow")
	check(M.asked[table.getn(M.asked)] == "follow party1", "Follow follows them")
	this, arg1 = CreedUIParty1, "RightButton"
	CreedUIParty1.__scripts.OnClick()
	press("Whisper")
	check(ChatFrameEditBox:GetText() == "/w Melkor ", "Whisper opens the chat box to them: " .. tostring(ChatFrameEditBox:GetText()))
	ChatFrameEditBox:SetText("")
	ChatFrameEditBox:Hide()
	arg1 = "LeftButton"
	M.unit.party4 = { exists = false }
	M.Fire("PARTY_MEMBERS_CHANGED")
	frames(40)
	check(findText(CreedUIParty, "^Offline$") == nil, "a friend who leaves goes away")
	M.Slash("party off")
	frames(10)
	check(PartyMemberFrame1.__parent ~= CreedUIHidden, "turned off, the game's party frames come back")
	M.Slash("party on")
	frames(10)
	problems("party")

	-- the minimap
	frames(30)
	check(not MinimapBorder:IsShown() and not MinimapZoomIn:IsShown() and not MinimapZoomOut:IsShown(), "the minimap's old border and zoom buttons go")
	check(CreedUIMinimap.__shown, "the ring is on")
	check(findText(CreedUIMinimap, "^" .. M.zoneText .. "$") ~= nil, "the zone's name over it: " .. table.concat(textsUnder(CreedUIMinimap), " | "))
	check(findText(CreedUIMinimapClock, "^10:42 PM$") ~= nil and M.hud.localClock == false, "the clock in its box on the ring, the game's hidden")
	this, arg1 = Minimap, 1
	Minimap.__scripts.OnMouseWheel()
	check(Minimap:GetZoom() == 1, "the wheel zooms in")
	arg1 = -1
	Minimap.__scripts.OnMouseWheel()
	check(Minimap:GetZoom() == 0, "and out")
	M.Slash("minimap off")
	frames(5)
	check(MinimapBorder:IsShown() and MinimapZoomIn:IsShown() and M.hud.localClock == true, "turned off, the game's minimap is back as it was")
	M.Slash("minimap on")
	frames(5)
	problems("minimap")

	-- Escape on the paused screen doesn't also open the old game menu
	M.phase = "paused"
	frames(2)
	ShowUIPanel(GameMenuFrame)
	frames(2)
	check(not GameMenuFrame:IsShown() and (GameMenuFrame.__alpha or 1) == 1, "the old game menu doesn't pop up over the paused game")
	M.phase = "ready"
	frames(40)
	ShowUIPanel(GameMenuFrame)
	frames(2)
	check(GameMenuFrame:IsShown(), "out of a run it opens as usual")
	HideUIPanel(GameMenuFrame)

	-- a party gathering ("Move to begin"): the new run's zone is in, the bar shows at 0:00
	M.phase = "dead"
	frames(10)
	AZS_ZONE_UPDATED = M.now
	M.phase, M.runTime = "ready", 0
	frames(60)
	check(CreedUITimerFrame.__shown and findText(CreedUITimerFrame, "^0:00$") ~= nil,
		"waiting to begin, the timer shows 0:00: " .. table.concat(textsUnder(CreedUITimerFrame), " | "))
	M.phase = "victory"
	frames(10)
	M.phase = "ready"
	frames(90)
	check(not CreedUITimerFrame.__shown, "back in town after a run, the timer stays away")
	M.phase = "playing"
	problems("after 1.0")
end

------------------------------------------------------------------ 11c. the damage meter and the luck window
do
	local function buttonLabeled(rootFrame, label)
		for _, o in ipairs(M.All()) do
			if o.__kind == "FontString" and o.__text == label and under(o, rootFrame) then return o.__parent end
		end
	end
	local function lineCount()
		local n = 0
		for _, o in ipairs(M.All()) do
			if o.__kind == "FontString" and o.__text and under(o, CreedUIMeter) and visibleAlpha(o) > 0.05 and string.find(M.Plain(o.__text), "^%d+%. ") then n = n + 1 end
		end
		return n
	end
	M.meter = {
		damage = {
			{ key = "ability:ss:r3", name = "Sinister Strike", icon = "Interface\\Icons\\Spell_Shadow_RitualOfSacrifice", amount = 13200, school = 1 },
			{ key = "ability:bf:r2", name = "Blade Flurry", icon = "Interface\\Icons\\Ability_Warrior_PunishingBlow", amount = 10600, school = 1 },
			{ key = "ability:bs:r1", name = "Backstab", ability = "bs", icon = "Interface\\Icons\\Ability_BackStab", amount = 8000, school = 1 },
			{ key = "talent:rogue.riposte:r1", name = "Riposte", icon = "Interface\\Icons\\Ability_Warrior_Challange", amount = 154, school = 1, proc = true },
			{ key = "melee", name = "Melee", amount = 1500 },
		},
		healing = { { key = "regen", name = "Regeneration", amount = 900 } },
	}
	M.phase = "playing"
	frames(30)
	check(M.hud.meter == false, "the game's meter window is hidden")
	check(CreedUIMeter.__shown and visibleAlpha(CreedUIMeter) > 0.9, "the meter shows")
	check(CreedUIDB.meter.tab == "damage" and findText(CreedUIMeter, "^Damage") ~= nil, "it opens on Damage Done")
	check(findText(CreedUIMeter, "^1%. Sinister Strike$") ~= nil, "the most damage first: " .. table.concat(textsUnder(CreedUIMeter), " | "))
	check(findText(CreedUIMeter, "^13%.2k %(132, 39%%%)$") ~= nil, "each line's amount, per second and share")
	check(findText(CreedUIMeter, "^proc$") ~= nil, "a talent's own damage is tagged proc")
	check(countTex(CreedUIMeter, "RitualOfSacrifice") == 1 and countTex(CreedUIMeter, "QuestionMark") == 1, "each line with its icon (a question mark when the game has none)")
	check(findText(CreedUIMeter, "^%d+ dps$") ~= nil, "the total per second up top")
	check(lineCount() == 5, "five lines (" .. lineCount() .. ")")
	-- every line its own color, though they're all physical
	local seen, distinct, fills = {}, true, 0
	for _, o in ipairs(M.All()) do
		if o.__kind == "Texture" and o.__tex and string.find(o.__tex, "Art\\Fill$") and under(o, CreedUIMeter) and M.Visible(o) and o.__grad then
			fills = fills + 1
			local c = o.__grad[3]
			local key = string.format("%.2f,%.2f,%.2f", c[1], c[2], c[3])
			if seen[key] then distinct = false end
			seen[key] = true
		end
	end
	check(fills == 5 and distinct, "each skill's bar has its own color (" .. fills .. " bars)")
	-- a skill's ranks are one line (the game counts each rank apart)
	table.insert(M.meter.damage, { key = "spell:53", name = "Backstab", icon = "Interface\\Icons\\Ability_BackStab", amount = 700, school = 1 })
	table.insert(M.meter.damage, { key = "ability:bs:r3", name = "Backstab", ability = "bs", icon = "Interface\\Icons\\Ability_BackStab", amount = 300, school = 1 })
	frames(30)
	local backstabs = 0
	for _, o in ipairs(M.All()) do
		if o.__kind == "FontString" and o.__text and string.find(M.Plain(o.__text), "^%d+%. Backstab$") and under(o, CreedUIMeter) and visibleAlpha(o) > 0.05 then backstabs = backstabs + 1 end
	end
	check(backstabs == 1 and lineCount() == 5 and findText(CreedUIMeter, "^9%.0k ") ~= nil,
		"Backstab's three ranks are one line of 9.0k: " .. table.concat(textsUnder(CreedUIMeter), " | "))
	table.remove(M.meter.damage)
	table.remove(M.meter.damage)
	frames(30)
	-- every pet's and summon's skills together on one Pet line; its tooltip names the best of them
	table.insert(M.meter.damage, { key = "melee", name = "Melee", amount = 600, actor = { id = "P7", kind = "pet", name = "Wolf", summonKey = "wolf" } })
	table.insert(M.meter.damage, { key = "melee", name = "Melee", amount = 400, actor = { id = "P8", kind = "pet", name = "Wolf", summonKey = "wolf" } })
	table.insert(M.meter.damage, { key = "immolation", name = "Immolation", amount = 300, actor = { id = "P9", kind = "summon", name = "Infernal", summonKey = "infernal" } })
	frames(30)
	check(findText(CreedUIMeter, "^%d+%. Pet$") ~= nil and findText(CreedUIMeter, "^1%.3k ") ~= nil and lineCount() == 6
		and findText(CreedUIMeter, "Wolf") == nil and findText(CreedUIMeter, "Infernal") == nil,
		"all the pets' skills are one Pet line: " .. table.concat(textsUnder(CreedUIMeter), " | "))
	local petRow
	for _, o in ipairs(M.All()) do
		if o.__kind == "FontString" and o.__text and string.find(M.Plain(o.__text), "^%d+%. Pet$") and under(o, CreedUIMeter) then petRow = o.__parent end
	end
	while petRow and not (petRow.__scripts and petRow.__scripts.OnEnter) do petRow = petRow.__parent end
	if petRow then
		this = petRow
		petRow.__scripts.OnEnter()
	end
	frames(2)
	local tipText = table.concat(M.tip.lines, " / ")
	check(string.find(tipText, "Best spell | Wolf: Melee", 1, true) ~= nil, "its tooltip names the pets' best skill: " .. tipText)
	if petRow and petRow.__scripts.OnLeave then petRow.__scripts.OnLeave() end
	-- the Pet line's words never wrap, whatever the pet is called
	M.meter.damage[table.getn(M.meter.damage) - 1].actor.name = "White Devilsaur of the Untamed Wilds"
	frames(30)
	local wraps = 0
	for _, o in ipairs(M.All()) do
		if o.__kind == "FontString" and o.__text and under(o, CreedUIMeter) and visibleAlpha(o) > 0.05 then
			if o.__w and M.TextWidth and M.TextWidth(o) > o.__w + 0.5 then wraps = wraps + 1 end
		end
	end
	check(wraps == 0, "no line's words wrap: " .. wraps)
	table.remove(M.meter.damage)
	table.remove(M.meter.damage)
	table.remove(M.meter.damage)
	frames(30)
	-- the views
	CreedUIDB.meter.tab = "healing"
	frames(30)
	check(findText(CreedUIMeter, "^Healing") ~= nil and findText(CreedUIMeter, "^1%. Regeneration$") ~= nil, "Healing Done")
	CreedUIDB.meter.tab = "boss"
	frames(30)
	check(findText(CreedUIMeter, "^No boss fight yet%.$") ~= nil, "Boss Damage before the first boss fight says so")
	CreedUIDB.meter.tab = "party"
	frames(30)
	check(findText(CreedUIMeter, "^Not in a party%.$") ~= nil, "Party DPS alone says so")
	M.meter.party = { { key = "H1", name = "Creed", class = "rogue", amount = 20000 }, { key = "H2", name = "Melkor", class = "mage", amount = 15000 } }
	frames(30)
	check(findText(CreedUIMeter, "^1%. Creed$") ~= nil and findText(CreedUIMeter, "^2%. Melkor$") ~= nil, "Party DPS lists the heroes")
	-- each hero's best skill in a tag on their line
	M.meter.partySkills = { { owner = "H1", key = "ss", name = "Sinister Strike", amount = 12000 },
		{ owner = "H1", key = "bs", name = "Backstab", amount = 8000 }, { owner = "H2", key = "fb", name = "Fireball", amount = 15000 } }
	frames(30)
	check(findText(CreedUIMeter, "^Sinister") ~= nil and findText(CreedUIMeter, "^Fireball$") ~= nil and findText(CreedUIMeter, "^Backstab$") == nil,
		"each hero's best skill shows on their line: " .. table.concat(textsUnder(CreedUIMeter), " | "))
	M.meter.partySkills = nil
	check(countTex(CreedUIMeter, "^Portrait:pk1$") == 1, "with their portraits")
	-- the title opens the four views
	local head = CreedUIMeter.head
	this = head
	head.__scripts.OnClick()
	local pick = buttonLabeled(CreedUIMeter, "Damage Done")
	check(pick ~= nil and M.Visible(pick), "the title opens the views' menu")
	if pick then
		this = pick
		pick.__scripts.OnClick()
	end
	frames(30)
	check(CreedUIDB.meter.tab == "damage" and findText(CreedUIMeter, "^1%. Sinister Strike$") ~= nil, "picking one switches to it")
	-- Reset: this window counts again from now
	local reset = buttonLabeled(CreedUIMeter, "Reset")
	this = reset
	reset.__scripts.OnClick()
	M.meter.damage[1].amount = M.meter.damage[1].amount + 500
	frames(30)
	check(lineCount() == 1 and findText(CreedUIMeter, "^500 ") ~= nil, "after Reset only what came since counts: " .. table.concat(textsUnder(CreedUIMeter), " | "))
	-- a new world ends the game's checkpoints: the meter shows the run again
	M.Fire("PLAYER_ENTERING_WORLD")
	frames(30)
	check(lineCount() == 5, "after a new world the whole run shows again")
	-- the older getters, by name only: icons from the hits seen
	local snapFn = AZS_GetMeterSnapshot
	AZS_GetMeterSnapshot = nil
	function AZS_GetMeter()
		return { { name = "Sinister Strike", dmg = 13700, dps = 99, share = 0.4 }, { name = "Riposte", dmg = 154, dps = 1, share = 0.01, proc = 1 } }, 13854, 100
	end
	frames(30)
	check(findText(CreedUIMeter, "^1%. Sinister Strike$") ~= nil and countTex(CreedUIMeter, "RitualOfSacrifice") == 1, "with the older getters too, icons included")
	check(findText(CreedUIMeter, "^100 dps$") ~= nil, "and their total per second")
	AZS_GetMeterSnapshot = snapFn
	AZS_GetMeter = nil
	frames(30)
	-- close it; its toggle in the options brings it back
	local close = buttonLabeled(CreedUIMeter, "x")
	this = close
	close.__scripts.OnClick()
	frames(40)
	check(not CreedUIMeter.__shown, "x hides the meter")
	M.Slash("meter on")
	frames(40)
	check(CreedUIMeter.__shown, "its toggle in the options brings it back")
	-- fold it to the title
	local fold = buttonLabeled(CreedUIMeter, "^")
	this = fold
	fold.__scripts.OnClick()
	frames(10)
	check(lineCount() == 0 and findText(CreedUIMeter, "^Damage") ~= nil, "^ folds it to its title")
	this = fold
	fold.__scripts.OnClick()
	frames(10)
	check(lineCount() == 5, "and opens it again")
	-- drag it by its title, or by a line, and it stays where it's let go
	CreedUIDB.pos = CreedUIDB.pos or {}
	CreedUIDB.pos.meter = nil
	local title = CreedUIMeter.head
	this = title
	title.__scripts.OnDragStart()
	check(CreedUIMeter.__moving == true, "dragging the meter's title moves it")
	title.__scripts.OnDragStop()
	check(type(CreedUIDB.pos.meter) == "table", "and its new place is kept")
	local menuOpen = false
	for _, o in ipairs(M.All()) do
		if o.__kind == "FontString" and o.__text == "Healing Done" and under(o, CreedUIMeter) and M.Visible(o) then menuOpen = true end
	end
	check(not menuOpen, "letting go of a drag doesn't open the views' menu")
	local lineFrame
	for _, o in ipairs(M.All()) do
		if o.__kind == "FontString" and o.__text and string.find(M.Plain(o.__text), "^1%. ") and under(o, CreedUIMeter) then lineFrame = o.__parent end
	end
	CreedUIMeter.__moving = false
	this = lineFrame
	lineFrame.__scripts.OnDragStart()
	check(CreedUIMeter.__moving == true, "a line drags the meter too")
	lineFrame.__scripts.OnDragStop()
	-- locked in the hub: no dragging
	CreedUIDB.lockWindows = true
	CreedUIMeter.__moving = false
	this = title
	title.__scripts.OnDragStart()
	check(CreedUIMeter.__moving ~= true, "locked, it stays put")
	title.__scripts.OnDragStop()
	CreedUIDB.lockWindows = nil
	-- by default it sits on the luck window, as wide as it, their right edges in line
	M.Slash("reset")
	frames(10)
	local ml, mb, mr, mt = M.Rect(CreedUIMeter)
	local ll, lb, lr, lt = M.Rect(CreedUILuck)
	check(math.abs(mr - lr) < 0.5 and math.abs((mb - lt) - 8) < 0.5 and math.abs((mr - ml) - (lr - ll)) < 0.5,
		string.format("the meter sits on the luck window, as wide (%.0f / %.0f), 8 above it (%.1f)", mr - ml, lr - ll, mb - lt))
	check(lb > 56 and lb < 64, "the luck window keeps to the bottom right corner, clear of the kills and gold (" .. lb .. ")")
	-- any edge or corner sizes it: the side under the mouse follows it, the other stays put
	local sizers = CreedUIMeter.sizers
	local arrow = CreedUIMeterSizer
	local function drag(edge, x0, y0, dx, dy)
		M.cursorX, M.cursorY = x0, y0
		this = sizers[edge]
		sizers[edge].__scripts.OnEnter()
		frames(2)
		local hovered = arrow.__shown
		this = sizers[edge] -- the frames in between ran other scripts
		sizers[edge].__scripts.OnMouseDown()
		M.cursorX, M.cursorY = x0 + dx, y0 + dy
		frames(3)
		local during = { M.Rect(CreedUIMeter) }
		this = sizers[edge]
		sizers[edge].__scripts.OnMouseUp()
		this = sizers[edge]
		sizers[edge].__scripts.OnLeave()
		frames(30)
		return hovered, during
	end
	local ol, ob, or_, ot = M.Rect(CreedUIMeter)
	local hovered = drag("RIGHT", or_, (ob + ot) / 2, 84, 0)
	local nl, nb, nr, nt = M.Rect(CreedUIMeter)
	check(hovered and arrow.tex.__tc and arrow.tex.__tc[1] == 0 and arrow.tex.__tc[2] == 0.5,
		"an arrow across shows by the mouse on the right edge: " .. tostring(hovered) .. " " .. tostring(arrow.tex.__tc and table.concat(arrow.tex.__tc, ",")))
	check(not arrow.__shown, "and goes when the mouse leaves")
	check(CreedUIDB.meter.width == 320 and math.abs((nr - nl) - 320) < 0.5 and math.abs(nl - ol) < 0.5,
		string.format("the right edge makes it wider, its left edge stays (%.0f wide, left %.1f -> %.1f)", nr - nl, ol, nl))
	-- the bottom edge: it follows the mouse, then settles on whole lines
	local _, during = drag("BOTTOM", (nl + nr) / 2, nb, 0, -45)
	local hl, hb, hr, ht = M.Rect(CreedUIMeter)
	check(math.abs((during[4] - during[2]) - (nt - nb + 45)) < 0.6, string.format("the bottom follows the mouse (%.0f tall)", during[4] - during[2]))
	check(CreedUIDB.meter.rows == 10 and math.abs((ht - hb) - (24 + 10 * 18 + 10)) < 0.6 and math.abs(ht - nt) < 0.6,
		string.format("and settles on whole lines, its top in place (%d lines, %.1f tall)", CreedUIDB.meter.rows, ht - hb))
	check(CreedUIDB.meter.rowsSet and CreedUIDB.meter.widthSet, "the new size is kept")
	local wideLine = false
	for _, o in ipairs(M.All()) do
		if o.__kind == "FontString" and o.__text and string.find(M.Plain(o.__text), "^1%. ") and under(o, CreedUIMeter) and visibleAlpha(o) > 0.05 then
			local fl, fb, fr = M.Rect(o.__parent)
			wideLine = math.abs((fr - fl) - (320 - 10)) < 0.5
		end
	end
	check(wideLine, "its lines follow the new width")
	-- the top left corner: up and left, the bottom right corner stays
	local cl, cb, cr, ct = M.Rect(CreedUIMeter)
	drag("TOPLEFT", cl, ct, -30, 18)
	local kl, kb, kr, kt = M.Rect(CreedUIMeter)
	check(math.abs(kr - cr) < 0.6 and math.abs(kb - cb) < 0.6 and math.abs((kr - kl) - (cr - cl + 30)) < 0.6
		and CreedUIDB.meter.rows == 11, string.format("the top left corner sizes it both ways (%.0f wide, %d lines)", kr - kl, CreedUIDB.meter.rows))
	check(arrow.tex.__tc and arrow.tex.__tc[1] == 0 and arrow.tex.__tc[3] == 0.5, "with a diagonal arrow")
	CreedUIDB.lockWindows = true
	frames(2)
	check(not sizers.LEFT.__shown and not sizers.BOTTOMRIGHT.__shown, "locked windows can't be sized")
	CreedUIDB.lockWindows = nil
	frames(2)
	check(sizers.LEFT.__shown, "unlocked, they can again")
	-- back to the width the next checks expect
	local bl, bb, br, bt = M.Rect(CreedUIMeter)
	drag("LEFT", bl, (bb + bt) / 2, 30, 0)
	-- two lines about equal keep their order instead of swapping back and forth
	M.meter.damage[2].amount = M.meter.damage[1].amount * 0.99
	frames(30)
	local first = findText(CreedUIMeter, "^1%. ")
	M.meter.damage[2].amount = M.meter.damage[1].amount * 1.01
	frames(30)
	check(findText(CreedUIMeter, "^1%. ") == first, "a line 1% ahead doesn't swap places: " .. tostring(first))
	M.meter.damage[2].amount = M.meter.damage[1].amount * 1.2
	frames(30)
	check(findText(CreedUIMeter, "^1%. ") ~= first, "20% ahead, it does")
	M.meter.damage[2].amount = 10600
	CreedUIDB.meter.width, CreedUIDB.meter.widthSet, CreedUIDB.meter.rows = 236, nil, 6
	problems("meter")

	-- luck: a medallion and three gems
	AZS_STATS = { luck = 0.41, gluck = 0.22 }
	AZS_RUN.lvl = 16
	frames(30)
	check(CreedUILuck.__shown and visibleAlpha(CreedUILuck) > 0.9, "the luck window shows")
	check(findText(CreedUILuck, "^57%%$") ~= nil and findText(CreedUILuck, "^41%% yours, %+16%% from level 16$") ~= nil,
		"the medallion holds the luck the cards roll with, yours and your level's under it: " .. table.concat(textsUnder(CreedUILuck), " | "))
	check(findText(CreedUILuck, "^Rare$") and findText(CreedUILuck, "^1 in 6$") and findText(CreedUILuck, "^1 in 9$") and findText(CreedUILuck, "^1 in 24$"),
		"the gems: a Rare, an Epic and a Legendary card's chance, 1 in N, as the game rolls them")
	check(findText(CreedUILuck, "^A legendary about every 8 level%-ups$") ~= nil, "and how often a level-up brings a legendary")
	check(countTex(CreedUILuck, "LuckMedal$") == 1 and countTex(CreedUILuck, "LuckOrb$") == 3 and countTex(CreedUILuck, "LuckClover$") == 1,
		"its own art: the medallion, three gems, the clover")
	check(findText(CreedUILuck, "Spells") == nil and findText(CreedUILuck, "Amulets") == nil and findText(CreedUILuck, "among 3") == nil,
		"none of the old table's words")
	-- a gem's own odds
	local legend = CreedUILuck.gems[3].hit
	this = legend
	legend.__scripts.OnEnter()
	frames(10)
	local gemTip = table.concat(M.tip.lines, " / ")
	check(string.find(gemTip, "Legendary", 1, true) ~= nil and string.find(gemTip, "4.2%  (1 in 24)", 1, true) ~= nil
		and string.find(gemTip, "three cards | 12.0%", 1, true) ~= nil, "a gem shows its odds: " .. gemTip)
	legend.__scripts.OnLeave()
	-- luck gained shows on the medallion
	AZS_STATS = { luck = 0.47, gluck = 0.28 }
	frames(15)
	check(findText(CreedUILuck, "^63%%$") ~= nil and findText(CreedUILuck, "^%+6%%$") ~= nil, "luck gained shows on the medallion: " .. table.concat(textsUnder(CreedUILuck), " | "))
	frames(120)
	check(findText(CreedUILuck, "^%+6%%$") == nil and findText(CreedUILuck, "^luck$") ~= nil, "then its word comes back")
	this = CreedUILuck
	CreedUILuck.__scripts.OnEnter()
	frames(10)
	local tipText = table.concat(M.tip.lines, " / ")
	check(string.find(tipText, "from your gear | +28%", 1, true) ~= nil and string.find(tipText, "Your cards roll with | 63%", 1, true) ~= nil
		and string.find(tipText, "Gained this run | +6%", 1, true) ~= nil, "its tooltip: where the luck comes from: " .. tipText)
	AZS_STATS = { luck = 0.41, gluck = 0.22 }
	CreedUILuck.__scripts.OnLeave()
	CreedUIDB.pos.luck = nil
	this = CreedUILuck
	CreedUILuck.__scripts.OnDragStart()
	check(CreedUILuck.__moving == true, "the luck window drags anywhere")
	CreedUILuck.__scripts.OnDragStop()
	check(type(CreedUIDB.pos.luck) == "table", "and keeps its new place")
	problems("luck")

end

------------------------------------------------------------------ 11d. the chat
do
	local function stockBorder()
		local n = 0
		for _, o in ipairs(M.All()) do
			if o.__kind == "Texture" and o.__tex and string.find(o.__tex, "UI%-ChatInputBorder") and o.__shown then n = n + 1 end
		end
		return n
	end
	frames(10)
	check(ChatFrame1UpButton.__parent == CreedUIHidden and ChatFrame1BottomButton.__parent == CreedUIHidden
		and ChatFrame2DownButton.__parent == CreedUIHidden and ChatFrameMenuButton.__parent == CreedUIHidden,
		"the chat's scroll buttons and speech bubble are tucked away")
	this, arg1 = ChatFrame1, 1
	ChatFrame1.__scripts.OnMouseWheel()
	check(ChatFrame1.__scroll == 2, "a notch of the wheel scrolls two lines")
	frames(10)
	check(CreedUIChatDown.__shown and visibleAlpha(CreedUIChatDown) > 0.3, "an arrow shows while you're scrolled up")
	this = CreedUIChatDown
	CreedUIChatDown.__scripts.OnClick()
	check(ChatFrame1:AtBottom(), "the arrow brings you back to the newest lines")
	frames(30)
	check(not CreedUIChatDown.__shown, "and then goes")
	M.shift = true
	this, arg1 = ChatFrame1, 1
	ChatFrame1.__scripts.OnMouseWheel()
	check(ChatFrame1.__scroll == 99, "Shift and the wheel jump to the top")
	arg1 = -1
	ChatFrame1.__scripts.OnMouseWheel()
	check(ChatFrame1:AtBottom(), "and back to the bottom")
	M.shift = nil
	local l, b, r, t = M.Rect(ChatFrame1)
	M.cursorX, M.cursorY = (l + r) / 2, (b + t) / 2
	frames(20)
	check(CreedUIChatGlass.__shown and visibleAlpha(CreedUIChatGlass) > 0.9, "a glass fades in behind the lines under the mouse")
	M.cursorX, M.cursorY = 0, 0
	frames(50)
	check(not CreedUIChatGlass.__shown, "and out when the mouse leaves")
	check(stockBorder() == 0, "the typing box's old border is off")
	ChatFrameEditBox:Show()
	frames(20)
	check(countTex(ChatFrameEditBox, "Diamond", 0.3) == 2, "the typing box wears the timer's diamonds")
	check(CreedUIChatGlass.__shown and visibleAlpha(CreedUIChatGlass) > 0.9, "and the glass shows while you type")
	check(findText(ChatFrameEditBox, "^Say:$") ~= nil, "the channel's name stays")
	ChatFrameEditBox:Hide()
	M.Slash("chat off")
	frames(5)
	check(ChatFrame1UpButton.__parent == ChatFrame1 and ChatFrameMenuButton.__parent == UIParent, "turned off, the buttons come back")
	check(stockBorder() == 3, "and the typing box's own border")
	check(ChatFrame1.__scripts.OnMouseWheel == nil, "and the wheel is the game's again")
	M.Slash("chat on")
	frames(5)
	check(ChatFrame1UpButton.__parent == CreedUIHidden and stockBorder() == 0, "and on again")
	problems("chat")
end

------------------------------------------------------------------ 11e. the bars' echo and shield; over the cards
do
	local C = CreedUI
	local holder = CreateFrame("Frame", "CreedUITestBar", UIParent)
	holder:SetWidth(200)
	holder:SetHeight(12)
	holder:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	local b = C.NewBar(holder, 200, 12, false)
	b.frame:SetPoint("CENTER", holder, "CENTER", 0, 0)
	local now, dt = 0, 1 / 60
	local function step(target, seconds, each)
		local maxGap = 0
		local t = 0
		while t < seconds do
			if each then target = each(t, target) end
			C.BarStep(b, target, dt, now)
			now, t = now + dt, t + dt
			if b.echo - b.value > maxGap then maxGap = b.echo - b.value end
		end
		return maxGap, target
	end
	step(1, 0.5)
	-- one big hit: a pale trail shows, full height, and is gone within a second
	step(0.8, 0.15)
	local _, eb, _, et = M.Rect(b.echoTex)
	check(b.echoTex.__shown and b.echo - b.value > 0.05, "a big hit leaves a pale trail")
	check(et - eb > 11, "the trail is as tall as the bar: " .. (et - eb))
	step(0.8, 0.85)
	check(b.echo == b.value and not b.echoTex.__shown, "and it drains within a second")
	-- a stream of big hits: the trail keeps up instead of parking behind
	local nextHit = 0
	local maxGap, last = step(0.8, 3, function(t, target)
		if t >= nextHit and target > 0.25 then nextHit = t + 0.2; return target - 0.04 end
		return target
	end)
	check(maxGap < 0.1, string.format("hit after hit the trail stays short (%.3f)", maxGap))
	step(last, 0.6)
	check(b.echo == b.value, "and it's gone soon after the last hit")
	-- a shield after the health, over its end when it doesn't fit; never without a height
	b.shield = 0.2
	step(0.5, 1)
	local l0 = M.Rect(b.frame)
	local sl, sb, sr, st = M.Rect(b.shieldTex)
	check(b.shieldTex.__shown and b.stripeTex.__shown and b.edgeTex.__shown, "a shield shows its pane, stripes and edge")
	check(math.abs(sl - l0 - 100) < 1 and math.abs(sr - sl - 40) < 1, string.format("after the health (%.1f, %.1f)", sl - l0, sr - sl))
	check(st - sb > 11, "as tall as the bar: " .. (st - sb))
	b.shield = 0.3
	step(1, 1)
	sl, sb, sr, st = M.Rect(b.shieldTex)
	check(math.abs(sl - l0 - 140) < 1 and math.abs(sr - l0 - 200) < 1, string.format("over the end at full health (%.1f..%.1f)", sl - l0, sr - l0))
	b.shield = 0
	step(1, 1)
	check(not b.shieldTex.__shown and not b.stripeTex.__shown and not b.edgeTex.__shown, "and goes when it breaks")
	holder:Hide()
	-- over the level-up cards' veil: the frames clear of the cards, not one moved over them
	M.Fire("PLAYER_ENTERING_WORLD")
	frames(40)
	local on = M.onTop or {}
	check(on.CreedUIPlayer == true and on.CreedUITarget == true and on.CreedUIParty == true, "your frame, target and party stay lit over the cards")
	check(on.CreedUILuck == true and on.GameTooltip == true, "and the luck and the tooltips")
	-- the meter, widened by an earlier test, now reaches over the cards on this small screen
	check(on.CreedUIMeter ~= nil, "the meter is looked at too")
	check(on.CreedUITally == true, "the tally, docked in the skill bar's panel, rides over them with it")
	CreedUILuck:ClearAllPoints()
	CreedUILuck:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	frames(40)
	check(M.onTop.CreedUILuck == false, "moved over the cards, the luck stays under them")
	for i = 1, table.getn(C.movers) do
		if C.movers[i].frame == CreedUILuck then C.ApplyPos(C.movers[i]) end
	end
	frames(40)
	check(M.onTop.CreedUILuck == true, "and back in its corner, over them again")
	problems("echo, shield, cards")
end

------------------------------------------------------------------ 11f. caches on the minimap; the clock on its ring
do
	local hero = { px = 100, py = 200, gold = 50, chest = 31 }
	M.zoneText = "Raven Hill Cemetery"
	local pub = SIM.Publish
	SIM.Publish = function()
		pub()
		if AZS_RUN then AZS_RUN.px, AZS_RUN.py, AZS_RUN.gold, AZS_RUN.chest = hero.px, hero.py, hero.gold, hero.chest end
	end
	SIM.StartRun("naxx", { killAfter = 60 })
	M.runTime = 30
	SIM.Publish()
	AZS_CHESTS = { { id = 1, x = 100, y = 170, z = 0, mx = -1, my = -1 } } -- 30 yards east
	AZS_CHESTS_UPDATED = M.now
	SIM.Advance(1, 1 / 30)
	local function pins()
		local out = {}
		for _, o in ipairs(M.All()) do
			if o.__kind == "Texture" and o.__tex and string.find(o.__tex, "Chest$") and under(o, CreedUIChests)
				and visibleAlpha(o) > 0.3 then
				local l, b, r, t = M.Rect(o)
				local ml, mb, mr, mt = M.Rect(Minimap)
				table.insert(out, { x = (l + r) / 2 - (ml + mr) / 2, y = (b + t) / 2 - (mb + mt) / 2, w = r - l, tex = o })
			end
		end
		return out
	end
	local function shownUnder(pat)
		for _, o in ipairs(M.All()) do
			if o.__kind == "Texture" and o.__tex and string.find(o.__tex, pat) and under(o, CreedUIChests) and visibleAlpha(o) > 0.05 then return true end
		end
		return false
	end
	local p = pins()
	check(table.getn(p) == 1, "a cache on the field shows on the minimap: " .. table.getn(p))
	-- zoom 0 spans 466.67 yards across the 140 of the minimap: 30 yards east is 9 to the right
	check(p[1] and math.abs(p[1].x - 9) < 0.3 and math.abs(p[1].y) < 0.3,
		string.format("where it lies (%.2f, %.2f)", p[1] and p[1].x or -1, p[1] and p[1].y or -1))
	check(not shownUnder("Ring"), "a cache there from the start doesn't ring")
	-- one right where you stand fades to a ghost, so the game's arrow shows over it
	AZS_CHESTS = { AZS_CHESTS[1], { id = 9, x = 100, y = 200, z = 0, mx = -1, my = -1 } }
	AZS_CHESTS_UPDATED = M.now
	SIM.Advance(0.3, 1 / 30)
	local ghost
	for _, o in ipairs(M.All()) do
		if o.__kind == "Texture" and o.__tex and string.find(o.__tex, "Chest$") and under(o, CreedUIChests) and M.Visible(o) then
			local l, b, r, t = M.Rect(o)
			local ml, mb, mr, mt = M.Rect(Minimap)
			if math.abs((l + r) / 2 - (ml + mr) / 2) < 1 and math.abs((b + t) / 2 - (mb + mt) / 2) < 1 then ghost = visibleAlpha(o) end
		end
	end
	check(ghost and ghost < 0.3, "a cache under your arrow fades so the arrow shows: " .. tostring(ghost))
	check(table.getn(pins()) == 1, "and one a little away stays clear")
	AZS_CHESTS = { AZS_CHESTS[1] }
	AZS_CHESTS_UPDATED = M.now
	SIM.Advance(0.3, 1 / 30)
	check(shownUnder("Glow"), "it glows while your gold pays for it")
	-- one drops far to the north: on the rim, smaller, and it rings
	AZS_CHESTS = { AZS_CHESTS[1], { id = 2, x = 1100, y = 200, z = 0, mx = -1, my = -1 } }
	AZS_CHESTS_UPDATED = M.now
	SIM.Advance(0.3, 1 / 30)
	p = pins()
	local far
	for i = 1, table.getn(p) do if p[i].y > 30 then far = p[i] end end
	check(far ~= nil and math.abs(far.y - 63) < 0.6 and math.abs(far.x) < 0.3 and far.w < 14,
		"a far cache sits on the rim toward it: " .. (far and string.format("%.1f, %.1f, %.0f wide", far.x, far.y, far.w) or "none"))
	check(shownUnder("Ring"), "a new cache rings as it drops")
	SIM.Advance(2, 1 / 30)
	check(not shownUnder("Ring"), "and the ring fades")
	-- zoomed in, the near one moves out
	Minimap:SetZoom(5)
	SIM.Advance(0.2, 1 / 30)
	p = pins()
	local near
	for i = 1, table.getn(p) do if p[i].y < 30 then near = p[i] end end
	check(near and math.abs(near.x - 31.5) < 0.4, "zoomed in, the same cache sits farther out: " .. (near and string.format("%.1f", near.x) or "none"))
	Minimap:SetZoom(0)
	hero.gold = 10
	SIM.Advance(0.3, 1 / 30)
	check(not shownUnder("Glow"), "no glow while your gold falls short")
	-- the cards' veil: they wait
	M.phase = "choosing"
	SIM.Advance(0.2, 1 / 30)
	check(table.getn(pins()) == 0, "no caches on the minimap while the cards are up")
	M.phase = "playing"
	-- the client's own position, each frame, and the coordinate space a cache must share
	function AZS_GetPlayerPosition() return { apiVersion = 1, x = 100, y = 230, spaceId = "m1:7", sampleId = 1 } end
	AZS_CHESTS = { { id = 3, x = 100, y = 200, spaceId = "m1:7" }, { id = 4, x = 120, y = 230, spaceId = "m2:7" } }
	AZS_CHESTS_UPDATED = M.now
	SIM.Advance(0.3, 1 / 30)
	p = pins()
	check(table.getn(p) == 1 and math.abs(p[1].x - 9) < 0.3, "the live position places them, only those of your map: "
		.. table.getn(p) .. (p[1] and string.format(" at %.2f", p[1].x) or ""))
	AZS_GetPlayerPosition = nil
	-- the local time in the box on the ring's foot, the zone's name under it, no clock line under that
	check(CreedUIMinimapClock.__shown and findText(CreedUIMinimapClock, "^10:42 PM$") ~= nil,
		"the local time shows in the box on the minimap: " .. table.concat(textsUnder(CreedUIMinimapClock), " | "))
	local clockLines = 0
	for _, o in ipairs(M.All()) do
		if o.__kind == "FontString" and o.__text == "10:42 PM" and under(o, CreedUIMinimap) and M.Visible(o) then clockLines = clockLines + 1 end
	end
	check(clockLines == 1, "and only there, not under the zone's name: " .. clockLines)
	local _, rb = M.Rect(CreedUIMinimapClock)
	local title
	for _, o in ipairs(M.All()) do
		if o.__kind == "FontString" and o.__text == "Raven Hill Cemetery" and under(o, CreedUIMinimap) then title = o end
	end
	check(title ~= nil, "the zone's name is there")
	if title then
		local _, _, _, tt = M.Rect(title)
		check(tt < rb - 3, string.format("the zone's name sits under the box (%.1f < %.1f)", tt, rb))
	end
	M.Slash("clock off")
	SIM.Advance(1.2, 1 / 30)
	check(not CreedUIMinimapClock.__shown and M.hud.localClock == true, "the clock turns off, the game's comes back")
	M.Slash("clock on")
	SIM.Advance(1.2, 1 / 30)
	check(CreedUIMinimapClock.__shown and M.hud.localClock == false, "and on again")
	M.Slash("chests off")
	SIM.Advance(0.2, 1 / 30)
	check(table.getn(pins()) == 0, "the chests turn off")
	M.Slash("chests on")
	M.phase = "ready"
	SIM.Advance(0.2, 1 / 30)
	check(table.getn(pins()) == 0, "out of a run no caches show")
	check(CreedUIMinimapClock.__shown, "the clock stays out of a run")
	AZS_CHESTS = nil
	SIM.Publish = pub
	problems("chests and the clock")
end

------------------------------------------------------------------ 11g. debuffs under the boss bars
do
	SIM.StartRun("naxx", { killAfter = 120 })
	local b = SIM.run.bosses
	M.runTime = b[2].at + 4
	b[1].state = "dead"
	SIM.Publish()
	M.guardians = { { id = 77, name = "Sir Zeliek", hp = 21500, hpm = 36000, awake = true } }
	AZS_UNITS_UPDATED = M.now + 0.01 -- the new run's units
	SIM.Advance(1.5, 1 / 30)
	local function guardTop()
		for _, o in ipairs(M.All()) do
			if o.__kind == "FontString" and o.__text == "Sir Zeliek" and under(o, CreedUIBosses) and M.Visible(o) then
				local _, _, _, t = M.Rect(o)
				return t
			end
		end
	end
	local before = guardTop()
	M.debuffs = { ["Noth the Plaguebringer"] = {
		{ name = "Corruption", icon = "Interface\\Icons\\Spell_Shadow_AbominationExplosion", ends = M.runTime + 9.6, duration = 18, dispelType = "Magic" },
		{ name = "Rupture", icon = "Interface\\Icons\\Ability_BackStab", ends = M.runTime + 2.3, duration = 16, stacks = 3 },
	} }
	SIM.Advance(1, 1 / 30)
	local icons, texts = 0, {}
	for _, o in ipairs(M.All()) do
		if o.__kind == "Texture" and o.__tex and string.find(o.__tex, "Interface\\Icons\\") and under(o, CreedUIBosses) and M.Visible(o) then icons = icons + 1 end
		if o.__kind == "FontString" and o.__text and o.__text ~= "" and under(o, CreedUIBosses) and M.Visible(o) and o.__parent ~= CreedUIBosses then
			local t = M.Plain(o.__text)
			if string.find(t, "^%d+%.?%d*$") then table.insert(texts, t) end
		end
	end
	check(icons == 2, "the boss's two debuffs show under its bar: " .. icons)
	local joined = table.concat(texts, " ")
	check(string.find(joined, "^9 ") or string.find(joined, " 9 ") or string.find(joined, " 9$") or string.find(joined, "^9$"), "each with the time it has left: " .. joined)
	check(string.find(joined, "1%.%d") ~= nil and string.find(joined, "3") ~= nil, "a short one in tenths, the stacks shown: " .. joined)
	local after = guardTop()
	check(before and after and before - after > 18, string.format("the bar under it makes room (%.1f -> %.1f)", before or -1, after or -1))
	SIM.Advance(1.2, 1 / 30)
	M.debuffs = {}
	SIM.Advance(1.5, 1 / 30)
	local left = 0
	for _, o in ipairs(M.All()) do
		if o.__kind == "Texture" and o.__tex and string.find(o.__tex, "Interface\\Icons\\") and under(o, CreedUIBosses) and M.Visible(o) then left = left + 1 end
	end
	local back = guardTop()
	check(left == 0 and back and math.abs(back - before) < 1, "gone, the bars close up again")
	M.guardians = {}
	problems("debuffs")
end

------------------------------------------------------------------ 11h. the cards: what would lie over them fades away
do
	SIM.StartRun("naxx", { killAfter = 120 })
	local b = SIM.run.bosses
	M.runTime = b[2].at + 4
	b[1].state = "dead"
	SIM.Publish()
	AZS_UNITS_UPDATED = M.now + 0.02
	AZS_STATS = { luck = 0.2 }
	M.unit.party1 = { exists = true, name = "Melkor", class = "Mage", level = 20, hp = 1500, hpm = 2000, mp = 800, mpm = 1200, power = 0 }
	M.Fire("PARTY_MEMBERS_CHANGED")
	SIM.Advance(1.5, 1 / 30)
	local function lit(f) return f.__shown and visibleAlpha(f) > 0.9 end
	check(lit(CreedUIBar) and lit(CreedUIMeter) and lit(CreedUILuck) and lit(CreedUIBosses) and lit(CreedUIParty),
		"before the cards: bar, meter, luck, boss and party frames up")
	M.phase = "choosing"
	SIM.Advance(0.8, 1 / 30)
	local function gone(f) return not f.__shown or visibleAlpha(f) < 0.01 end
	check(gone(CreedUIBar) and gone(CreedUIMeter) and gone(CreedUILuck) and gone(CreedUIBosses) and gone(CreedUIParty) and gone(CreedUITally),
		string.format("the cards up, they fade away (bar %s, meter %s, luck %s, bosses %s, party %s)", tostring(gone(CreedUIBar)),
			tostring(gone(CreedUIMeter)), tostring(gone(CreedUILuck)), tostring(gone(CreedUIBosses)), tostring(gone(CreedUIParty))))
	check(lit(CreedUIPlayer) and CreedUITimerFrame.__shown, "your frame and the timer, clear of them, stay")
	M.phase = "playing"
	SIM.Advance(1, 1 / 30)
	check(lit(CreedUIBar) and lit(CreedUIMeter) and lit(CreedUILuck) and lit(CreedUIBosses) and lit(CreedUIParty),
		"the cards picked, they come back")
	M.unit.party1 = { exists = false }
	M.Fire("PARTY_MEMBERS_CHANGED")
	problems("cards")
end

------------------------------------------------------------------ 11i. the luck box: sized by its edges, hidden by its x or the gem
do
	SIM.StartRun("naxx", { killAfter = 120 })
	M.runTime = 30
	SIM.Publish()
	AZS_STATS = { luck = 0.3 }
	M.Slash("reset")
	SIM.Advance(1, 1 / 30)
	local sizers = {}
	for _, o in ipairs(M.All()) do
		if o.__kind == "Frame" and o.__parent == CreedUILuck and o.edge then sizers[o.edge] = o end
	end
	local function drag(edge, x0, y0, dx, dy)
		M.cursorX, M.cursorY = x0, y0
		this = sizers[edge]
		sizers[edge].__scripts.OnEnter()
		frames(2)
		local hovered = CreedUILuckSizer.__shown
		this = sizers[edge]
		sizers[edge].__scripts.OnMouseDown()
		M.cursorX, M.cursorY = x0 + dx, y0 + dy
		frames(3)
		this = sizers[edge]
		sizers[edge].__scripts.OnMouseUp()
		this = sizers[edge]
		sizers[edge].__scripts.OnLeave()
		frames(3)
		return hovered
	end
	check(sizers.RIGHT and sizers.TOPLEFT and sizers.BOTTOMRIGHT, "the luck box has grab strips on its sides and corners")
	local l, b, r, t = M.Rect(CreedUILuck)
	local hovered = drag("RIGHT", r, (b + t) / 2, 40, 0)
	local l2, b2, r2, t2 = M.Rect(CreedUILuck)
	check(hovered, "an arrow shows by the mouse on its edge")
	check(math.abs((r2 - l2) - (r - l + 40)) < 0.6 and math.abs(l2 - l) < 0.6 and math.abs(t2 - t) < 0.6,
		string.format("its right edge widens it, the left one stays (%.0f -> %.0f)", r - l, r2 - l2))
	check(CreedUIDB.luck.width == math.floor(r - l + 40 + 0.5), "and the width is kept: " .. tostring(CreedUIDB.luck.width))
	drag("BOTTOMRIGHT", r2, b2, 30, -30)
	local l3, b3, r3, t3 = M.Rect(CreedUILuck)
	check(CreedUILuck:GetScale() > 1.05 and math.abs(l3 - l2) < 0.6 and math.abs(t3 - t2) < 0.6,
		string.format("a corner makes it bigger, the corner across from it in place (scale %.2f)", CreedUILuck:GetScale()))
	-- its x hides it; its toggle in the options brings it back
	this = CreedUILuck.close
	CreedUILuck.close.__scripts.OnClick()
	frames(30)
	check(not CreedUILuck.__shown, "its x hides it")
	M.Slash("luck on")
	frames(30)
	check(CreedUILuck.__shown, "and its toggle brings it back")
	CreedUIDB.luck.width, CreedUIDB.luck.scale = 236, 1
	CreedUILuck:SetScale(1)
	M.Slash("reset")
	frames(5)
	problems("luck sizing")
end

------------------------------------------------------------------ 11j. the meter's head: its total never runs into the name
do
	SIM.StartRun("naxx", { killAfter = 120 })
	M.runTime = 30
	SIM.Publish()
	M.Slash("reset")
	CreedUIDB.meter.shown, CreedUIDB.meter.collapsed = true, false
	frames(10)
	local sizers = CreedUIMeter.sizers
	local function setWidth(w)
		local l, b, r, t = M.Rect(CreedUIMeter)
		M.cursorX, M.cursorY = r, (b + t) / 2
		this = sizers.RIGHT
		sizers.RIGHT.__scripts.OnEnter()
		frames(1)
		this = sizers.RIGHT
		sizers.RIGHT.__scripts.OnMouseDown()
		M.cursorX = r + (w - (r - l))
		frames(2)
		this = sizers.RIGHT
		sizers.RIGHT.__scripts.OnMouseUp()
		this = sizers.RIGHT
		sizers.RIGHT.__scripts.OnLeave()
		frames(3)
	end
	-- the total per second each view shows for a total amount (the mock: damage over 80 s, the rest over 100 s)
	local function feed(tab, total)
		local line = { { key = "melee", name = "Melee", amount = total } }
		M.meter = { damage = line, healing = { { key = "regen", name = "Regeneration", amount = total } }, boss = line,
			party = { { key = "H1", name = "Creed", class = "rogue", amount = total } } }
		AZS_TAKEN = { { source = "Melee", dmg = total } }
		CreedUIDB.meter.tab = tab
		frames(20)
	end
	local function head()
		local title, caret, rate = CreedUIMeter.title, CreedUIMeter.caret, CreedUIMeter.rate
		local tl = M.Rect(title)
		local cl, _, cr = M.Rect(caret)
		local _, _, rr = M.Rect(rate)
		local tw, rw = M.TextWidth(title), M.TextWidth(rate)
		return M.Plain(title.__text or ""), tl + tw, cl, cr, rr - rw, M.Plain(rate.__text or "")
	end
	local worst, worstCase, overlaps, cases, blank, wrongRate = 99, "", 0, 0, 0, 0
	local fullAt300 = true
	for _, tab in ipairs({ "damage", "healing", "boss", "party", "taken" }) do
		for _, w in ipairs({ 200, 236, 300, 440 }) do
			setWidth(w)
			for _, total in ipairs({ 30000, 1060000, 79990000 }) do
				feed(tab, total)
				local name, nameEnd, caretL, caretR, rateL, rateText = head()
				cases = cases + 1
				local gap = rateL - caretR
				if gap < worst then worst, worstCase = gap, tab .. " " .. w .. " '" .. name .. "' / '" .. rateText .. "'" end
				if gap < 6 or nameEnd > caretL + 0.5 then overlaps = overlaps + 1 end
				if name == "" then blank = blank + 1 end
				if not string.find(rateText, "^[%d%.]+[km]? [dh]t?ps$") then wrongRate = wrongRate + 1 end
				local full = ({ damage = "Damage Done", healing = "Healing Done", boss = "Boss Damage", party = "Party DPS", taken = "Damage Taken" })[tab]
				if w >= 300 and name ~= full then fullAt300 = false end
			end
		end
	end
	check(overlaps == 0, string.format("at any width, view and total, the total stays clear of the name and its caret (%d cases, closest %.1f: %s)",
		cases, worst, worstCase))
	check(wrongRate == 0, "the total always shows whole")
	check(blank == 0, "and the view keeps a name, if a shorter one")
	check(fullAt300, "with room, each view goes by its whole name")
	-- the name settles: it doesn't flick back and forth as the total ticks across a size
	setWidth(236)
	feed("damage", 30000)
	local first = head()
	feed("damage", 1060000)
	local second = head()
	feed("damage", 30000)
	local third = head()
	check(third == second, string.format("the name keeps its shorter form as the total ticks back (%s, %s, %s)", first, second, third))
	setWidth(236)
	M.Slash("reset")
	frames(5)
	problems("meter head")
end

------------------------------------------------------------------ 11k. the skill bar's panel keeps its shape through a card pick
do
	SIM.StartRun("naxx", { killAfter = 120 })
	M.runTime = 30
	SIM.Publish()
	M.Slash("reset")
	AZS_RUN.kills, AZS_RUN.gold, AZS_RUN.chest = 93, 56, 31
	M.phase = "playing"
	frames(60)
	local function right()
		local _, _, r = M.Rect(CreedUIBar.panel)
		return r
	end
	local w0 = right()
	check(CreedUITally.creedDocked == true and CreedUI.tallyDock.on, "the kills, gold and cache sit in the panel")
	local lo, hi, undocked = w0, w0, false
	local function watch(n)
		for i = 1, n do
			frames(1)
			local r = right()
			if r < lo then lo = r end
			if r > hi then hi = r end
			if not CreedUITally.creedDocked then undocked = true end
		end
	end
	M.phase = "choosing"
	watch(45)
	check(not CreedUIBar.__shown and not CreedUITally.__shown, "the bar and the strip step aside for the cards")
	M.phase = "playing"
	watch(45)
	check(CreedUIBar.__shown and CreedUITally.__shown, "and come back")
	check(not undocked, "the strip stays docked through the cards")
	check(hi - lo < 0.5, string.format("the panel keeps its shape through a card pick (right edge %.1f .. %.1f)", lo, hi))
	-- dragged away and docked again: the panel reaches round its new shape, never past it
	CreedUIDB.pos = CreedUIDB.pos or {}
	CreedUIDB.pos.tally = { x = 500, y = 300 }
	frames(45)
	local away = right()
	check(not CreedUITally.creedDocked and away < w0 - 20, string.format("dragged away, the panel closes up (%.1f -> %.1f)", w0, away))
	CreedUIDB.pos.tally = nil
	local peak = away
	for i = 1, 60 do
		frames(1)
		peak = math.max(peak, right())
	end
	local back = right()
	check(math.abs(back - w0) < 0.5 and peak <= back + 0.5,
		string.format("docked again, it reaches round it and never past (%.1f, peak %.1f, before %.1f)", back, peak, w0))
	problems("panel through the cards")
end

------------------------------------------------------------------ 11l. the guardians' lairs on the minimap, and the time to the next guardian
do
	local pub = SIM.Publish
	SIM.Publish = function()
		pub()
		if AZS_RUN then AZS_RUN.px, AZS_RUN.py = 100, 200 end
	end
	SIM.StartRun("naxx", { killAfter = 120 })
	M.runTime = 30
	SIM.Publish()
	M.hud.flag = nil
	AZS_LAIRS = {
		{ index = 1, state = "asleep", name = "Gnoll Packleader", id = 31, left = -1, x = 100, y = 170, flag = 1 }, -- 30 yards east
		{ index = 2, state = "awake", name = "Kobold Geomancer", id = 32, left = -1, x = 130, y = 200, flag = 0 }, -- 30 north
		{ index = 3, state = "empty", name = "Murloc Tidecaller", id = 0, left = 42, x = 100, y = 230, flag = 0 }, -- 30 west
	}
	AZS_LAIRS_UPDATED = M.now
	SIM.Advance(2.5, 1 / 30)
	local function tokens()
		local out = {}
		for _, o in ipairs(M.All()) do
			if o.__kind == "Texture" and o.__tex and string.find(o.__tex, "Skull$") and under(o, CreedUIChests) and visibleAlpha(o) > 0.3 then
				local l, b, r, t = M.Rect(o)
				local ml, mb, mr, mt = M.Rect(Minimap)
				table.insert(out, { x = (l + r) / 2 - (ml + mr) / 2, y = (b + t) / 2 - (mb + mt) / 2, pin = o.__parent })
			end
		end
		return out
	end
	local tk = tokens()
	local east, north, west
	for i = 1, table.getn(tk) do
		if tk[i].x > 5 then east = tk[i] elseif tk[i].y > 5 then north = tk[i] elseif tk[i].x < -5 then west = tk[i] end
	end
	check(table.getn(tk) == 3 and east and north and west and math.abs(east.x - 9) < 0.3 and math.abs(north.y - 9) < 0.3
		and math.abs(west.x + 9) < 0.3, "each lair shows on the minimap where it lies: " .. table.getn(tk))
	local function shown(pat)
		for _, o in ipairs(M.All()) do
			if o.__kind == "Texture" and o.__tex and string.find(o.__tex, pat) and under(o, CreedUIChests) and visibleAlpha(o) > 0.05 then return o end
		end
	end
	check(east and east.pin.base.__vc and east.pin.base.__vc[3] < 0.5 and north and north.pin.base.__vc[2] < 0.4
		and west and west.pin.base.__vc[1] == west.pin.base.__vc[2], "asleep bronze, awake red, empty grey")
	check(findText(CreedUIChests, "^0:40$") ~= nil, "the empty one counts down to its next guardian: " .. table.concat(textsUnder(CreedUIChests), " | "))
	check(shown("Ring") ~= nil, "the one to head for rings")
	check(M.hud.flag == false, "the game's red flag is hidden while the lairs show")
	SIM.Advance(10, 1 / 30)
	check(findText(CreedUIChests, "^0:30$") ~= nil, "ten seconds on: " .. table.concat(textsUnder(CreedUIChests), " | "))
	M.phase = "paused"
	SIM.Advance(5, 1 / 30)
	check(findText(CreedUIChests, "^0:30$") ~= nil, "paused, the count holds as the game's does")
	M.phase = "playing"
	AZS_LAIRS[3].left = 3
	AZS_LAIRS_UPDATED = M.now
	SIM.Advance(0.2, 1 / 30)
	check(findText(CreedUIChests, "^0:03$") ~= nil, "a new word from the game sets it again")
	SIM.Advance(4, 1 / 30)
	check(findText(CreedUIChests, "^soon$") ~= nil, "due, it says soon")
	-- hovered: what's in it
	local pin = east and east.pin
	this = pin
	pin.__scripts.OnEnter()
	local tip = table.concat(M.tip.lines, " / ")
	check(string.find(tip, "Gnoll Packleader", 1, true) and string.find(tip, "Asleep", 1, true) and string.find(tip, "30 yards away", 1, true),
		"hover a lair for its guardian: " .. tip)
	pin.__scripts.OnLeave()
	-- off: gone, and the game's flag back
	M.Slash("lairs off")
	SIM.Advance(0.5, 1 / 30)
	check(table.getn(tokens()) == 0 and M.hud.flag == true, "the lairs turn off and the game's flag comes back")
	M.Slash("lairs on")
	SIM.Advance(0.5, 1 / 30)
	check(table.getn(tokens()) == 3, "and on again")
	AZS_LAIRS = nil
	SIM.Publish = pub
	problems("lairs")
end

------------------------------------------------------------------ 11m. XP a second on the XP bar
do
	local pub, t0 = SIM.Publish, 10
	SIM.Publish = function()
		pub()
		if AZS_RUN then
			local gained = 3 * (M.runTime - t0) -- 3 XP a second, 100 a level
			AZS_RUN.lvl, AZS_RUN.xp, AZS_RUN.xpn = 5 + math.floor(gained / 100), math.mod(gained, 100), 100
		end
	end
	SIM.StartRun("naxx", { killAfter = 120 })
	M.runTime = t0
	SIM.Publish()
	SIM.Advance(3, 1 / 30)
	check(findText(CreedUIBar, "xp/s") == nil, "no pace before there's enough of the run to tell")
	SIM.Advance(40, 1 / 30)
	local text = findText(CreedUIBar, "xp/s") or ""
	check(string.find(text, "^Level 6  %-  %d+ / 100  %-  3%.0 xp/s$") ~= nil, "XP a second, through level ups: " .. text)
	M.phase = "choosing"
	SIM.Advance(15, 1 / 30)
	M.phase = "playing"
	SIM.Advance(1, 1 / 30)
	text = findText(CreedUIBar, "xp/s") or ""
	check(string.find(text, " 3%.0 xp/s") ~= nil, "picking cards doesn't drag it down: " .. text)
	SIM.Publish = pub
	problems("xp pace")
end

------------------------------------------------------------------ 11n. languages: a menu in the options, and the words change at once
do
	local pub = SIM.Publish
	SIM.Publish = function()
		pub()
		if AZS_RUN then AZS_RUN.kills, AZS_RUN.gold, AZS_RUN.chest, AZS_RUN.lvl, AZS_RUN.xp, AZS_RUN.xpn = 50, 20, 31, 16, 10, 100 end
	end
	SIM.StartRun("naxx", { killAfter = 120 })
	M.runTime = 30
	SIM.Publish()
	AZS_STATS = { luck = 0.41 }
	M.meter = { damage = { { key = "melee", name = "Melee", amount = 30000 } } }
	M.Slash("reset")
	CreedUIDB.meter.shown, CreedUIDB.luck.shown = true, true
	SIM.Advance(1.5, 1 / 30)
	check(CreedUI.lang == "en" and findText(CreedUILuck, "^Luck$") ~= nil, "English to start with")
	if not (CreedUIOptions and CreedUIOptions.__shown) then M.Slash("") end
	frames(2)
	this = CreedUIOptions.lang
	CreedUIOptions.lang:Click()
	check(CreedUILanguageMenu.__shown and table.getn(CreedUILanguageMenu.items) == 11, "the options' language button opens the list of eleven")
	local fr
	for _, b in ipairs(CreedUILanguageMenu.items) do if b.code == "fr" then fr = b end end
	this = fr
	fr:Click()
	SIM.Advance(0.7, 1 / 30)
	check(CreedUI.lang == "fr" and CreedUIDB.lang == "fr" and not CreedUILanguageMenu.__shown, "picking Français sets it, keeps it and closes the list")
	check(findText(CreedUILuck, "^Chance$") and findText(CreedUILuck, "^Légendaire$") and findText(CreedUILuck, "^chance$")
		and findText(CreedUILuck, "^1 sur %d+$"), "the luck window speaks French at once: " .. table.concat(textsUnder(CreedUILuck), " | "))
	check(findText(CreedUIOptions, "^Langue : Français$") and findText(CreedUIOptions, "^Barre de sorts$") and findText(CreedUIOptions, "^Déplacer les cadres$"),
		"and the options")
	check(findText(CreedUIMeter, "^Dégâts") ~= nil and findText(CreedUIMeter, "^Réinit%.$") ~= nil, "and the meter: " .. table.concat(textsUnder(CreedUIMeter), " | "))
	check(findText(CreedUIBar, "^Niveau 16") ~= nil, "and the XP bar")
	this = CreedUITally
	CreedUITally.__scripts.OnEnter()
	local tip = table.concat(M.tip.lines, " / ")
	check(string.find(tip, "Cette partie", 1, true) and string.find(tip, "Victimes | 50", 1, true), "tooltips are made in it: " .. tip)
	CreedUITally.__scripts.OnLeave()
	-- the meter's head stays clear of its total in the longer words too
	local title, caret, rate = CreedUIMeter.title, CreedUIMeter.caret, CreedUIMeter.rate
	local _, _, cr = M.Rect(caret)
	local _, _, rr = M.Rect(rate)
	check(rr - M.TextWidth(rate) - cr >= 6, string.format("the meter's head keeps clear in French ('%s')", M.Plain(title.__text or "")))
	-- by the chat too, and its name works as well as its code
	M.Slash("language deutsch")
	SIM.Advance(0.3, 1 / 30)
	check(CreedUI.lang == "de" and findText(CreedUILuck, "^Glück$") ~= nil and chatHas("Sprache: Deutsch"), "/creed language deutsch: German")
	M.Slash("language xx")
	check(CreedUI.lang == "de" and chatHas("/creed language"), "an unknown one keeps it and lists them")
	-- Chinese: its words, and every text in the game's own face (Friz Quadrata may not have them)
	local function faces(root)
		local base, native, other = 0, 0, 0
		for _, o in ipairs(M.All()) do
			if o.__kind == "FontString" and under(o, root) then
				if o.__font == CreedUI.FACE_CJK then native = native + 1
				elseif o.__font == "Fonts\\FRIZQT__.TTF" or o.__font == "Fonts\\MORPHEUS.TTF" then base = base + 1
				else other = other + 1 end
			end
		end
		return base, native, other
	end
	M.Slash("language zh")
	SIM.Advance(0.5, 1 / 30)
	local b1, n1 = faces(CreedUILuck)
	local b2, n2 = faces(CreedUIMeter)
	local b3, n3 = faces(CreedUITimerFrame)
	check(CreedUI.lang == "zh" and findText(CreedUILuck, "^幸运$") ~= nil and findText(CreedUILuck, "^传说$") ~= nil,
		"中文: " .. table.concat(textsUnder(CreedUILuck), " | "))
	check(b1 + b2 + b3 == 0 and n1 > 5 and n2 > 5 and n3 > 2, string.format("in Creed UI's own face with those letters, all of it (%d %d %d left)", b1, b2, b3))
	local zhName
	for _, b in ipairs(CreedUILanguageMenu.items) do if b.code == "zh" then zhName = b.text end end
	M.Slash("language ru")
	SIM.Advance(0.3, 1 / 30)
	check(findText(CreedUILuck, "^Удача$") ~= nil and findText(CreedUIMeter, "^Урон") ~= nil, "Русский")
	local cyr = 0
	for _, o in ipairs(M.All()) do
		if o.__kind == "FontString" and under(o, CreedUILuck) and o.__font == CreedUI.FACE_LETTERS then cyr = cyr + 1 end
	end
	check(cyr > 5, "in the face with Cyrillic: " .. cyr)
	M.Slash("language en")
	SIM.Advance(0.3, 1 / 30)
	check(CreedUI.lang == "en" and findText(CreedUILuck, "^Luck$") ~= nil and findText(CreedUIOptions, "^Language: English$") ~= nil, "and back to English")
	local b4, n4 = faces(CreedUILuck)
	check(n4 == 0 and b4 > 5, "and to its own faces")
	check(zhName and zhName.__font == CreedUI.FACE_CJK, "a language's name in the list keeps the face its letters need, whatever the language")
	if CreedUIOptions.__shown then M.Slash("") end
	SIM.Publish = pub
	problems("languages")
end

------------------------------------------------------------------ 11n2. the stats window: the run's stats, grouped, the ones you pick
do
	local was = AZS_STATS
	AZS_STATS = { dmg = 2.57, crit = 0.404, cm = 2.97, cd = 0.71, echo = 0.32, hp = 2480, arm = 0.39, reg = 4.5, lch = 0.015,
		spd = 1.58, luck = 0.2, area = 1.3, cnt = 2, xp = 1.2, gold = 1.27, pick = 9, heal = 0, thn = 0, liv = 1, bp = 0.3,
		dots = 1, doth = 0, big = 0, exe = 0.3, cc = 0, dotd = 0.15, shd = 0, auto = 0.1, pet = 0 }
	M.phase = "playing"
	frames(30)
	check(CreedUIStats and M.Visible(CreedUIStats), "the stats window shows in a run")
	check(findText(CreedUIStats, "^Stats$") ~= nil and findText(CreedUIStats, "^OFFENSE$") ~= nil and findText(CreedUIStats, "^SURVIVAL$") ~= nil,
		"titled, its groups under their headers")
	check(findText(CreedUIStats, "^%+157%%$") ~= nil and findText(CreedUIStats, "^40.4%%$") ~= nil and findText(CreedUIStats, "^297%%$") ~= nil,
		"damage, crit and crit damage as the game writes them: " .. table.concat(textsUnder(CreedUIStats), " | "))
	check(findText(CreedUIStats, "^2,480$") ~= nil and findText(CreedUIStats, "^39%%$") ~= nil and findText(CreedUIStats, "^%+58%%$") ~= nil, "health, armor and speed")
	local function rowShown(label)
		for _, o in ipairs(M.All()) do
			if o.__kind == "FontString" and o.__text == label and under(o, CreedUIStats) and not under(o, CreedUIStatsMenu) and M.Visible(o) then return true end
		end
		return false
	end
	check(not rowShown("Melee") and not rowShown("Pickup"), "the ones not picked stay out")
	-- the + opens the list; ticking Melee adds it, kept in the settings
	local pick
	for _, o in ipairs(M.All()) do
		if o.__kind == "Button" and o.__parent == CreedUIStats and o.__scripts.OnClick then
			for _, k in ipairs(M.All()) do if k.__parent == o and k.__text == "+" then pick = o end end
		end
	end
	this = pick
	pick:Click()
	frames(3)
	check(M.Visible(CreedUIStatsMenu), "its + opens the list of every stat")
	for _, b in ipairs(CreedUIStatsMenu.items) do if b.name == "Melee" then this = b; b:Click() end end
	frames(5)
	check(rowShown("Melee") and findText(CreedUIStats, "^%+10%%$") ~= nil and CreedUIDB.stats.track["Melee"] == true, "ticked: Melee shows, and is kept")
	for _, b in ipairs(CreedUIStatsMenu.items) do if b.name == "Crit" then this = b; b:Click() end end
	frames(5)
	check(not rowShown("Crit"), "unticked: Crit goes")
	for _, b in ipairs(CreedUIStatsMenu.items) do if b.name == "Crit" then this = b; b:Click() end end
	-- a stat going up flashes green
	AZS_STATS.dmg = 2.80
	frames(15)
	local v
	for _, o in ipairs(M.All()) do
		if o.__kind == "FontString" and o.__text == "+180%" and under(o, CreedUIStats) then v = o end
	end
	check(v and v.__color and v.__color[2] > v.__color[1] + 0.1, "damage going up flashes green")
	-- out of a run, it goes
	AZS_STATS = nil
	frames(40)
	check(not M.Visible(CreedUIStats), "no run: no stats window")
	AZS_STATS = was
	this = pick
	pick:Click()
	problems("stats window")
end

------------------------------------------------------------------ 11o. the chat stops short of the skill bar's emblem
do
	SIM.StartRun("naxx", { killAfter = 120 })
	M.runTime = 30
	SIM.Publish()
	M.Slash("reset")
	ChatFrame1:SetWidth(420)
	SIM.Advance(1.5, 1 / 30)
	local dl = CreedUIBar.deco.LeftEnd() - 4 -- (dl + 4: where the emblem's paint begins)
	local cl, cb, cr = M.Rect(ChatFrame1)
	check(cr + 8 <= dl + 4 - 5, string.format("the chat's glass stops short of the emblem's paint (%.0f < %.0f)", cr + 8, dl + 4))
	check(ChatFrame1:GetWidth() < 420 and ChatFrame1:GetWidth() >= 200, "by giving up the end of its width: " .. ChatFrame1:GetWidth())
	-- sized by hand, that width is the one it keeps clear with
	local clearW = math.floor(dl + 4 - 6 - 8 - cl) - 10 -- well short of the emblem
	ChatFrame1:SetWidth(clearW)
	SIM.Advance(1, 1 / 30)
	check(ChatFrame1:GetWidth() == clearW, "a width set by hand that's already clear stays: " .. ChatFrame1:GetWidth() .. " / " .. clearW)
	ChatFrame1:SetWidth(420)
	SIM.Advance(1, 1 / 30)
	-- the part off: the width back as it was
	M.Slash("chat off")
	SIM.Advance(0.5, 1 / 30)
	check(ChatFrame1:GetWidth() == 420, "the chat part off, its whole width back: " .. ChatFrame1:GetWidth())
	M.Slash("chat on")
	SIM.Advance(1, 1 / 30)
	check(ChatFrame1:GetWidth() < 420, "and on, clear again")
	-- the bar moved far away: the whole width back
	CreedUIDB.pos = CreedUIDB.pos or {}
	CreedUIDB.pos.bar = { x = 700, y = 600 }
	for i = 1, table.getn(CreedUI.movers) do
		if CreedUI.movers[i].frame == CreedUIBar then CreedUI.ApplyPos(CreedUI.movers[i]) end
	end
	SIM.Advance(1, 1 / 30)
	check(ChatFrame1:GetWidth() == 420, "with the bar away from it, all of it: " .. ChatFrame1:GetWidth())
	CreedUIDB.pos.bar = nil
	M.Slash("reset")
	SIM.Advance(1, 1 / 30)
	problems("chat and dragon")
end

------------------------------------------------------------------ 11p. the Creed button on the minimap's edge
do
	local _, _, SW, SH = M.Rect(UIParent)
	local function centre(o)
		local l, b, r, t = M.Rect(o)
		local ml, mb, mr, mt = M.Rect(Minimap)
		return (l + r) / 2 - (ml + mr) / 2, (b + t) / 2 - (mb + mt) / 2
	end
	local b = CreedUIMinimapButton
	check(b ~= nil and M.Visible(b), "the Creed button sits on the minimap")
	if b then
		local x, y = centre(b)
		check(math.abs(math.sqrt(x * x + y * y) - 80) < 1 and x > 0 and y < 0, string.format("on the rim, lower right (%.1f, %.1f)", x, y))
		local l, bt, r, t = M.Rect(b)
		check(l >= 0 and bt >= 0 and r <= SW and t <= SH, "on the screen")
		for _, g in ipairs({ CreedUIMinimapClock }) do
			local gl, gb, gr, gt = M.Rect(g)
			check(gr <= l or gl >= r or gt <= bt or gb >= t, "clear of " .. g:GetName())
		end
		check(b:GetFrameLevel() > CreedUIMinimap:GetFrameLevel(), "over the ring")
		-- a click opens the menu, another closes it; the halo glows while it's open
		if CreedUIOptions and CreedUIOptions.__shown then M.Slash("") end
		this, arg1 = b, "LeftButton"
		b.__scripts.OnClick()
		check(CreedUIOptions and CreedUIOptions.__shown, "a click opens the menu")
		frames(20)
		local halo
		for _, o in ipairs(M.All()) do
			if o.__kind == "Texture" and o.__parent == b and o.__tex and string.find(o.__tex, "Ring$") then halo = o end
		end
		check(halo and halo.__vc and halo.__vc[4] > 0.3, "its halo glows while the menu is open")
		arg1 = "LeftButton"
		b.__scripts.OnClick()
		check(not CreedUIOptions.__shown, "and a second click closes it")
		frames(30)
		check(halo and halo.__vc[4] < 0.05, "the halo fades with it")
		-- a right click frees the frames, another locks them
		arg1 = "RightButton"
		b.__scripts.OnClick()
		check(CreedUI.unlocked and chatHas("right%-click the Creed button to lock them"), "a right click frees the frames to move")
		arg1 = "RightButton"
		b.__scripts.OnClick()
		check(not CreedUI.unlocked, "and the next locks them")
		-- its tooltip
		b.__scripts.OnEnter()
		local tip = table.concat(M.tip.lines, " / ")
		check(string.find(tip, "Creed UI", 1, true) and string.find(tip, "Click: open or close the menu", 1, true)
			and string.find(tip, "Right-click: move the frames", 1, true) and string.find(tip, "Drag:", 1, true), "its tooltip: " .. tip)
		b.__scripts.OnLeave()
		-- dragged round to the upper right; the mouse let go is no click
		b.__scripts.OnDragStart()
		local mx, my = Minimap:GetCenter()
		local k = Minimap:GetEffectiveScale()
		M.cursorX, M.cursorY = (mx + 50) * k, (my + 50) * k
		frames(3)
		arg1 = "LeftButton"
		b.__scripts.OnDragStop()
		b.__scripts.OnClick()
		check(CreedUIDB.minimapButton.angle == 45, "dragged, it follows the cursor round: " .. tostring(CreedUIDB.minimapButton.angle))
		x, y = centre(b)
		check(math.abs(x - 56.6) < 0.6 and math.abs(y - 56.6) < 0.6, string.format("to the upper right (%.1f, %.1f)", x, y))
		l, bt, r, t = M.Rect(b)
		check(r <= SW and t <= SH, "still on the screen")
		check(not CreedUIOptions.__shown, "letting go after the drag opens nothing")
		frames(15)
		-- kept over a reload
		M.Reload(DIR, true)
		frames(5)
		b = CreedUIMinimapButton
		x, y = centre(b)
		check(math.abs(x - 56.6) < 0.6 and math.abs(y - 56.6) < 0.6, "where it was left, after a reload")
		-- its own part: off and on, and there with the game's own minimap too
		M.Slash("button off")
		check(not M.Visible(b), "/creed button off hides it")
		M.Slash("button on")
		check(M.Visible(b), "and on shows it")
		M.Slash("minimap off")
		frames(2)
		check(M.Visible(b), "with the minimap left as the game's, it's still there")
		M.Slash("minimap on")
		frames(2)
		-- in Chinese: the game's tooltip in the face with those letters while it's ours, back after
		local holder = CreateFrame("Frame", "MockTooltipLines", UIParent)
		GameTooltipTextLeft1 = holder:CreateFontString()
		GameTooltipTextRight1 = holder:CreateFontString()
		GameTooltipTextLeft2 = holder:CreateFontString()
		GameTooltipTextLeft1:SetFont("Fonts\\FRIZQT__.TTF", 14, "")
		GameTooltipTextRight1:SetFont("Fonts\\FRIZQT__.TTF", 14, "")
		GameTooltipTextLeft2:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
		M.Slash("language zh")
		SIM.Advance(0.2, 1 / 30)
		this = b
		b.__scripts.OnEnter()
		tip = table.concat(M.tip.lines, " / ")
		check(string.find(tip, "点击", 1, true) ~= nil, "its tooltip in Chinese: " .. tip)
		check(GameTooltipTextLeft1.__font == CreedUI.FACE_CJK and GameTooltipTextRight1.__font == CreedUI.FACE_CJK
			and GameTooltipTextLeft2.__font == CreedUI.FACE_CJK and GameTooltipTextLeft1.__size == 14 and GameTooltipTextLeft2.__size == 12,
			"the tooltip's lines in the face with those letters, their sizes kept")
		b.__scripts.OnLeave()
		GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR") -- the game's own, for a unit or a bag
		check(GameTooltipTextLeft1.__font == "Fonts\\FRIZQT__.TTF" and GameTooltipTextLeft1.__size == 14
			and GameTooltipTextLeft2.__font == "Fonts\\FRIZQT__.TTF", "and the game's faces back the moment it's anyone else's")
		M.Slash("language en")
		SIM.Advance(0.2, 1 / 30)
		b.__scripts.OnEnter()
		check(GameTooltipTextLeft1.__font == "Fonts\\FRIZQT__.TTF", "in English, the game's own faces")
		b.__scripts.OnLeave()
		GameTooltipTextLeft1, GameTooltipTextRight1, GameTooltipTextLeft2 = nil, nil, nil
	end
	problems("minimap button")
end

------------------------------------------------------------------ 11p2. the meter's swords and the luck window's clover on the edge
do
	local _, _, SW, SH = M.Rect(UIParent)
	local function centre(o)
		local l, b, r, t = M.Rect(o)
		local ml, mb, mr, mt = M.Rect(Minimap)
		return (l + r) / 2 - (ml + mr) / 2, (b + t) / 2 - (mb + mt) / 2
	end
	local function crestOf(b)
		for _, o in ipairs(M.All()) do
			if o.__kind == "Texture" and o.__parent == b and o.__tex and string.find(o.__tex, "Map[SC][wl]o?[ro]") then return o end
		end
	end
	-- 1.14.3: one button on the edge; the meter and the luck window are shown or hidden in the options
	check(CreedUIMeterToggle == nil and CreedUILuckToggle == nil, "no swords or clover on the minimap")
	M.Slash("meter off")
	frames(30)
	check(not M.Visible(CreedUIMeter) or visibleAlpha(CreedUIMeter) < 0.05, "the meter's toggle hides it")
	M.Slash("meter on")
	frames(30)
	check(M.Visible(CreedUIMeter), "and brings it back")
	M.Slash("luck off")
	frames(30)
	check(not M.Visible(CreedUILuck), "the luck window's toggle hides it")
	M.Slash("luck on")
	frames(30)
	check(M.Visible(CreedUILuck), "and brings it back")
	problems("edge buttons")
end

------------------------------------------------------------------ 11q. a proc in another spell's look: its own number, its own icon
do
	frames(200)
	local saved = M.meter
	local SW = "Interface\\Icons\\Spell_Shadow_BlackPlague"
	M.meter = { damage = {
		{ key = "ability:sinister_strike:r4", name = "Sinister Strike", ability = "sinister_strike", icon = "Interface\\Icons\\Spell_Shadow_RitualOfSacrifice", amount = 900 },
		{ key = "talent:shadow_weaving:r1", name = "Shadow Weaving", icon = SW, amount = 300 } } }
	local e = M.Enemy("Ghoul", 2, 4)
	local function hit(amount, fields)
		M.Hit(e, amount, "strike", false)
		local ev = M.world.events[M.world.nEvents]
		for k, v in pairs(fields) do ev[k] = v end
	end
	local function shown(text)
		for _, o in ipairs(M.All()) do
			if o.__kind == "FontString" and o.__text and under(o, CreedUINumbersLayer) and visibleAlpha(o) > 0.2 and M.Plain(o.__text) == text then return true end
		end
		return false
	end
	local apart, merged, maxSW = false, false, 0
	hit(500, { meterSource = "Sinister Strike", meterSourceKey = "ability:sinister_strike:r4" })
	hit(77, { meterSource = "Shadow Weaving", meterSourceKey = "talent:shadow_weaving:r1" })
	for f = 1, 20 do
		M.Frame(1 / 30)
		if shown("500") and shown("77") then apart = true end
		if shown("577") then merged = true end
		local n = labelsWith("BlackPlague")
		if n > maxSW then maxSW = n end
	end
	check(apart and not merged, "a Shadow Weaving strike in Sinister Strike's look keeps its own number on the enemy")
	check(maxSW == 1 and CreedUI.sourceIcons["talent:shadow_weaving:r1"] == SW, "with Shadow Weaving's own icon, from the meter's line (" .. maxSW .. ")")
	frames(200)
	-- a skill's ranks are one: rank 3 and rank 4 hits add up as before
	merged = false
	hit(40, { meterSource = "Sinister Strike", meterSourceKey = "ability:sinister_strike:r3" })
	hit(60, { meterSource = "Sinister Strike", meterSourceKey = "ability:sinister_strike:r4" })
	for f = 1, 10 do
		M.Frame(1 / 30)
		if shown("100") then merged = true end
	end
	check(merged, "a skill's two ranks still add up into one number")
	frames(200)
	-- no meter line known for it: the look it floats in, as before
	M.meter = nil
	hit(33, { meterSource = "Mystery Echo", meterSourceKey = "talent:mystery_echo:r1" })
	frames(5)
	check(labelsWith("RitualOfSacrifice") >= 1, "a proc the meter can't show yet keeps the icon it floats with")
	frames(200)
	M.meter = saved
	problems("procs in another's look")
end

------------------------------------------------------------------ 11r. the cursor becomes the arrow over an edge that sizes
do
	local cursor, resets = nil, 0
	SetCursor = function(path) cursor = path end
	ResetCursor = function() cursor = nil; resets = resets + 1 end
	CreedUIDB.lockWindows = nil
	CreedUIDB.meter.shown = true
	frames(30)
	local sizers, arrow = CreedUIMeter.sizers, CreedUIMeterSizer
	local ml, mb, mr, mt = M.Rect(CreedUIMeter)
	M.cursorX, M.cursorY = mr, (mb + mt) / 2
	this = sizers.RIGHT
	sizers.RIGHT.__scripts.OnEnter()
	frames(2)
	check(cursor and string.find(cursor, "CursorSizeH$") and not arrow.__shown, "over the right edge the cursor is the arrow across, none drawn: " .. tostring(cursor))
	this = sizers.RIGHT
	sizers.RIGHT.__scripts.OnMouseDown()
	M.cursorX = mr + 30
	this = sizers.RIGHT
	sizers.RIGHT.__scripts.OnLeave() -- the mouse runs ahead of the edge while sizing
	frames(3)
	check(cursor and string.find(cursor, "CursorSizeH$"), "it stays the arrow while sizing, the mouse off the edge")
	this = sizers.RIGHT
	sizers.RIGHT.__scripts.OnMouseUp()
	frames(2)
	check(cursor == nil, "let go away from the edge: the game's cursor again")
	-- a corner: the slanted arrow; the window shut under the mouse gives the cursor back
	this = sizers.BOTTOMRIGHT
	sizers.BOTTOMRIGHT.__scripts.OnEnter()
	frames(2)
	check(cursor and string.find(cursor, "CursorSizeD1$"), "over the bottom right corner, the slanted arrow: " .. tostring(cursor))
	CreedUIDB.meter.shown = false
	frames(40)
	check(cursor == nil, "the meter hidden under the mouse: the game's cursor back")
	CreedUIDB.meter.shown = true
	frames(30)
	-- the windows locked while hovered
	this = sizers.LEFT
	sizers.LEFT.__scripts.OnEnter()
	frames(2)
	check(cursor ~= nil, "over the left edge, the arrow")
	CreedUIDB.lockWindows = true
	frames(3)
	check(cursor == nil, "the windows locked: the game's cursor back")
	CreedUIDB.lockWindows = nil
	SetCursor, ResetCursor = nil, nil
	frames(5)
	problems("size cursor")
end

------------------------------------------------------------------ 11s. the character window, dressed
do
	local function alpha(o) return o.__alpha or 1 end
	CharacterFrame:Show()
	frames(10)
	local bg, panel = CreedUICharacterBack, CreedUICharacterStats
	check(bg and M.Visible(bg) and M.Visible(panel), "opened, the window is dressed: its body and the stats beside it")
	check(CreedUICharacterTalents == nil, "no talents strip (for later)")
	-- behind the level-up cards it goes as dark as the game's own, and comes back after
	local phaseWas = M.phase
	M.phase = "choosing"
	frames(40)
	check(visibleAlpha(panel) < 0.15 and visibleAlpha(bg) < 0.15, string.format("behind the cards the window is dark like the game's (%.2f)", visibleAlpha(panel)))
	M.phase = phaseWas == "choosing" and "playing" or phaseWas
	frames(60)
	check(visibleAlpha(panel) > 0.99, "and lit again once they close")
	-- the game's art goes, its slots and model stay
	local art, artFaded = 0, 0
	for _, r in ipairs({ PaperDollFrame:GetRegions() }) do
		if r.__kind == "Texture" and r.__tex and string.find(r.__tex, "UI%-Character%-General") then
			art = art + 1
			if alpha(r) == 0 then artFaded = artFaded + 1 end
		end
	end
	check(art == 4 and artFaded == 4, "the game's art gone (" .. artFaded .. " of " .. art .. ")")
	check(alpha(CharacterFramePortrait) == 0 and alpha(CharacterNameText) == 0 and CreedUICharacterFace and M.Visible(CreedUICharacterFace),
		"the portrait in our ring, the name ours")
	check(alpha(CharacterHeadSlot) == 1 and alpha(CharacterMainHandSlot) == 1 and alpha(CharacterModelFrame) == 1 and CharacterHeadSlot.__mouse,
		"the slots and the model stay as they are")
	check(alpha(CharacterHeadSlot:GetNormalTexture()) == 0, "the slots' square edge gone for our metal")
	local bl, bb, br, bt = M.Rect(bg)
	local hl = M.Rect(CharacterHeadSlot)
	local _, _, hr = M.Rect(CharacterHandsSlot)
	local _, mb = M.Rect(CharacterMainHandSlot)
	check(bl < hl and br > hr and bb < mb, string.format("the body round the slots (%.0f..%.0f, foot %.0f)", bl, br, bb))
	-- every stat the game shows, grouped, its value as the game writes it; the game's boxes see-through
	local rows, labels = {}, {}
	for _, o in ipairs(M.All()) do
		if o.__kind == "FontString" and o.__parent == panel and o.__text and M.Visible(o) and (o.__alpha or 1) > 0 then
			table.insert(labels, M.Plain(o.__text))
		end
	end
	local all = table.concat(labels, " | ")
	for _, want in ipairs({ "OFFENSE", "SURVIVAL", "AREA AND DOTS", "RUN", "Damage", "+46%", "Crit Dmg", "243%", "Vs Afflicted", "Pickup", "22 yd", "Buff Power", "Lifesteal", "1.5%" }) do
		if not string.find(all, want, 1, true) then check(false, "the stats panel shows " .. want .. ": " .. all) end
	end
	local n = 0
	for _ in pairs(labels) do n = n + 1 end
	check(n >= 24 * 2 + 4, "all 24 stats with their values, under 4 heads (" .. n .. " texts)")
	local boxesGone = true
	for _, box in ipairs(M.charBoxes) do if alpha(box) ~= 0 or box.__mouse then boxesGone = false end end
	check(boxesGone and alpha(M.runPanel) == 0 and not M.runPanel.__mouse, "the game's boxes and Run Stats see-through, deaf to the mouse")
	-- at nothing, dimmed
	local killHeal
	for _, r in ipairs({ panel:GetRegions() }) do if r.__text == "Kill Heal" then killHeal = r end end
	check(killHeal and alpha(killHeal) < 0.5, "a stat at nothing (Kill Heal) dimmed")
	-- a change while it's open flashes by its number
	M.runValues["Gold:"]:SetText("+32%")
	frames(10)
	local flash
	for _, r in ipairs({ panel:GetRegions() }) do if r.__text == "+5%" and alpha(r) > 0.5 then flash = r end end
	check(flash ~= nil and flash.__color and flash.__color[2] > 0.9 and flash.__color[1] < 0.5, "Gold +27% -> +32%: '+5%' flashes, green")
	frames(200)
	check(flash and alpha(flash) == 0, "and fades")
	-- shut, changed, opened again: the change since the last look
	CharacterFrame:Hide()
	frames(2)
	check(alpha(CharacterFramePortrait) == 1 and alpha(M.runPanel) == 1 and M.runPanel.__mouse, "shut: the game's portrait and Run Stats back")
	M.runValues["Execute:"]:SetText("+40%")
	CharacterFrame:Show()
	frames(10)
	flash = nil
	for _, r in ipairs({ panel:GetRegions() }) do if r.__text == "+10%" and alpha(r) > 0.5 then flash = r end end
	check(flash ~= nil, "opened again: Execute's +10% since the last look shows")
	-- the slots lit in their items' rarity
	local function bezelOf(slot)
		for _, k in ipairs({ slot:GetChildren() }) do if k.bezel then return k end end
	end
	local epic, blue, plain = bezelOf(CharacterMainHandSlot), bezelOf(CharacterChestSlot), bezelOf(CharacterHeadSlot)
	check(epic and math.abs(epic.bezel.__vc[1] - 163 / 255) < 0.01 and math.abs(epic.bezel.__vc[3] - 238 / 255) < 0.01, "the epic blade's slot in purple")
	check(blue and math.abs(blue.bezel.__vc[3] - 221 / 255) < 0.01 and blue.glow.__vc[4] > 0.3, "the blue chest's in blue, glowing")
	check(plain and math.abs(plain.bezel.__vc[1] - 0.94) < 0.01 and math.abs(plain.bezel.__vc[2] - 0.88) < 0.01 and plain.glow.__vc[4] == 0, "a plain helm's in the panel's metal (the rogue's)")
	-- another page: the window's own pieces back, ours away; and back to this one
	PaperDollFrame:Hide()
	check(alpha(CharacterFramePortrait) == 1 and alpha(CharacterNameText) == 1 and not M.Visible(bg) and not M.Visible(panel),
		"on the Skills page, the game's portrait and name, ours gone")
	PaperDollFrame:Show()
	frames(3)
	check(alpha(CharacterFramePortrait) == 0 and M.Visible(bg), "back on the character page, dressed again")
	-- in another language: the heads and the stats' names in its words
	M.Slash("language fr")
	frames(5)
	labels = {}
	for _, r in ipairs({ panel:GetRegions() }) do if r.__text and M.Visible(r) then table.insert(labels, M.Plain(r.__text)) end end
	all = table.concat(labels, " | ")
	check(string.find(all, "OFFENSIVE", 1, true) and string.find(all, "Dégâts", 1, true), "en français: " .. all)
	M.Slash("language en")
	frames(5)
	-- off: the game's window as it was
	M.Slash("character off")
	frames(2)
	local back = alpha(CharacterFramePortrait) == 1 and alpha(CharacterHeadSlot:GetNormalTexture()) == 1 and not M.Visible(bg)
	for _, box in ipairs(M.charBoxes) do if alpha(box) ~= 1 or not box.__mouse then back = false end end
	for _, r in ipairs({ PaperDollFrame:GetRegions() }) do if r.__kind == "Texture" and alpha(r) ~= 1 then back = false end end
	for _, r in ipairs({ CharacterFrameTab1:GetRegions() }) do if r.__kind == "Texture" and r.__tex and string.find(r.__tex, "InActiveTab") and alpha(r) ~= 1 then back = false end end
	check(back and M.runPanel.__mouse, "/creed character off: the game's window as it was")
	M.Slash("character on")
	frames(3)
	check(M.Visible(bg) and alpha(CharacterFramePortrait) == 0, "and on again, open, dressed")
	M.Slash("probe")
	check(chatHas("AZS_RUN:") and chatHas("stats: .*Damage=%+46%%"), "/creed probe tells what the game gives")
	CharacterFrame:Hide()
	frames(2)
	problems("character window")
end

------------------------------------------------------------------ 11t. the Talents tab opens Creed UI's talent window; no Honor
do
	local function alpha(o) return o.__alpha or 1 end
	CharacterFrame:Show()
	this = CharacterFrameTab1
	CharacterFrameTab1.__scripts.OnClick()
	frames(5)
	check(CharacterFrameTab4Text.__text == "Talents" and not M.Visible(CharacterFrameTab5), "the Skills tab says Talents, the Honor tab's gone: " .. tostring(CharacterFrameTab4Text.__text))
	-- the Talents tab: Creed UI's talent window opens, the character window steps aside
	M.talentToggles = 0
	this = CharacterFrameTab4
	CharacterFrameTab4.__scripts.OnClick()
	frames(3)
	check(M.talentToggles == 1 and not (CreedUITalents and M.Visible(CreedUITalents)), "the Talents tab opens the game's own Talents window")
	check(not M.Visible(CharacterFrame), "and the character window closes for it")
	check(CreedUITalentPage == nil, "no talent page of Creed UI's own any more")
	-- opened again: on the Character page, dressed, not straight back to talents
	CharacterFrame:Show()
	frames(5)
	check(M.Visible(PaperDollFrame) and not M.Visible(SkillFrame) and M.Visible(CreedUICharacterBack) and M.talentToggles == 1,
		"opened again, it's on the Character page, dressed (and the talents didn't open again)")
	check(alpha(CharacterFramePortrait) == 0 and alpha(M.runPanel) == 0, "the page in our dress: the portrait ours, the game's Run Stats away")
	CharacterFrame:Hide()
	frames(2)
	check(alpha(CharacterFramePortrait) == 1 and alpha(M.runPanel) == 1, "shut: the game's pieces back")
	-- in Chinese: the tab in the face with those letters
	CharacterFrame:Show()
	M.Slash("language zh")
	frames(40)
	check(CharacterFrameTab4Text.__text == "天赋" and CharacterFrameTab4Text.__font == CreedUI.FACE_CJK, "中文: the tab " .. tostring(CharacterFrameTab4Text.__text))
	M.Slash("language en")
	frames(40)
	-- off: Skills and Honor as the game had them, the Skills tab its own page again
	M.Slash("character off")
	frames(2)
	check(CharacterFrameTab4Text.__text == "Skills" and CharacterFrameTab4Text.__font == "Fonts\\FRIZQT__.TTF" and M.Visible(CharacterFrameTab5),
		"/creed character off: Skills and Honor as the game had them")
	this = CharacterFrameTab4
	CharacterFrameTab4.__scripts.OnClick()
	frames(3)
	check(M.Visible(SkillFrame) and alpha(SkillFrame) == 1 and SkillListMock.__mouse and M.talentToggles == 1, "and its Skills page is the game's, untouched")
	this = CharacterFrameTab1
	CharacterFrameTab1.__scripts.OnClick()
	M.Slash("character on")
	frames(3)
	CharacterFrame:Hide()
	frames(2)
	problems("talents tab")
end

------------------------------------------------------------------ 11c. the boss skulls
do
	local function skulls(minAlpha)
		local out = {}
		for _, o in ipairs(M.All()) do
			if o.__kind == "Texture" and o.__tex and (string.find(o.__tex, "BossSkull$") or string.find(o.__tex, "BossSkullFierce$"))
				and under(o, CreedUISkulls) and visibleAlpha(o) > (minAlpha or 0.5) then
				table.insert(out, o)
			end
		end
		return out
	end
	local function center(o)
		local l, b, r, t = M.Rect(o)
		return (l + r) / 2, (b + t) / 2, r - l
	end
	local function skullOf(name)
		-- the skull over a boss: the one nearest its spot across the screen
		local i = name == "Kel'Thuzad" and 2 or 1
		local want = 640 + (i * 10 - 15) * 9
		for _, o in ipairs(skulls()) do
			local cx = center(o)
			if math.abs(cx - want) < 1 then return o end
		end
	end
	local part
	for i = 1, table.getn(CreedUI.parts) do if CreedUI.parts[i].key == "skulls" then part = CreedUI.parts[i] end end
	check(part ~= nil and part.get(), "the boss skulls are a part, on at first")
	M.Slash("downed off") -- the skulls' own frame handler alone, for these checks
	M.Slash("skulls on")
	M.guardians = { { id = 77, name = "Sir Zeliek", hp = 21500, hpm = 36000, awake = true } }
	M.bosses = { { name = "Anub'Rekhan", hp = 9000, hpm = 10000 }, { name = "Kel'Thuzad", hp = 50000, hpm = 60000, final = true } }
	M.waSpots, M.waNear, M.waOff, M.waNoHead, M.waLast = {}, {}, {}, {}, {}
	frames(30)
	check(table.getn(skulls()) == 3, "a skull over each boss and the awake mini-boss (" .. table.getn(skulls()) .. ")")
	local fierce, plain, eyes = 0, 0, 0
	for _, o in ipairs(skulls()) do
		if string.find(o.__tex, "Fierce$") then fierce = fierce + 1 else plain = plain + 1 end
	end
	for _, o in ipairs(M.All()) do
		if o.__kind == "Texture" and o.__tex and string.find(o.__tex, "BossSkullEyes$") and under(o, CreedUISkulls) and visibleAlpha(o) > 0.5 then eyes = eyes + 1 end
	end
	check(fierce == 2 and plain == 1 and eyes == 2, string.format("bosses wear the fierce skull with red eyes, the mini-boss the plain one (%d, %d, %d)", fierce, plain, eyes))
	M.guardians[1].awake = false
	frames(40)
	check(table.getn(skulls(0.05)) == 2, "a mini-boss asleep in its lair has none")
	M.guardians = {} -- the bosses alone from here
	check(M.waHandler ~= nil, "the skulls move with the game's camera (its frame handler)")
	check(M.waLast["boss:Anub'Rekhan"] == "overhead", "the bosses' heads are asked for")
	local s1 = skullOf("Anub'Rekhan")
	local cx, cy, w = 0, 0, 0
	if s1 then cx, cy, w = center(s1) end
	local head = 330 + 6 * 9 + (3 + 1.2) * 9
	check(s1 and math.abs(cx - (640 - 5 * 9)) < 1 and math.abs(cy - (head + w / 2)) <= 2.5,
		string.format("the skull floats just over the boss's head (%.1f, %.1f; head at %.1f)", cx, cy, head))
	check(s1 and math.abs(w - 26) < 1, "a far boss's skull is small, but not smaller than 26 (" .. w .. ")")
	-- nearer: bigger, up to a limit
	M.waNear["Anub'Rekhan"] = 3
	frames(30)
	local _, _, w1 = center(skullOf("Anub'Rekhan"))
	local _, _, w2 = center(skullOf("Kel'Thuzad"))
	check(math.abs(w1 - 51.8) < 1.5 and math.abs(w2 - 26) < 1, string.format("a near boss's skull is bigger (%.1f vs %.1f)", w1, w2))
	M.waNear["Anub'Rekhan"] = 10
	frames(30)
	_, _, w1 = center(skullOf("Anub'Rekhan"))
	check(math.abs(w1 - 77) < 1, "and no bigger than 77 however near (" .. w1 .. ")")
	M.waNear["Anub'Rekhan"] = nil
	part.setScale(1.5)
	frames(30)
	_, _, w2 = center(skullOf("Kel'Thuzad"))
	check(math.abs(w2 - 39) < 1, "the size setting scales them (" .. w2 .. ")")
	part.setScale(1)
	-- the final boss glows gold, the others red
	local gold, red = 0, 0
	for _, o in ipairs(M.All()) do
		if o.__kind == "Texture" and o.__tex and string.find(o.__tex, "Glow", 1, true) and under(o, CreedUISkulls) and visibleAlpha(o) > 0.5 and o.__vc then
			if o.__vc[2] > 0.6 then gold = gold + 1 elseif o.__vc[2] < 0.2 then red = red + 1 end
		end
	end
	check(gold == 1 and red == 1, "the final boss's skull glows gold, the other's red (" .. gold .. ", " .. red .. ")")
	-- off the screen: no skull at the edge of it
	M.waOff["Kel'Thuzad"] = true
	frames(30)
	check(table.getn(skulls()) == 1 and skullOf("Anub'Rekhan"), "a boss off the screen has no skull")
	M.waOff["Kel'Thuzad"] = nil
	-- a boss the game has no head for: over its feet, higher
	M.waNoHead["Kel'Thuzad"] = true
	frames(30)
	check(M.waLast["boss:Kel'Thuzad"] == "position" and skullOf("Kel'Thuzad") ~= nil, "a boss with no head spot gets its skull over its feet")
	M.waNoHead["Kel'Thuzad"] = nil
	-- a boss that falls loses its skull; then the other goes
	M.bosses[1].hp = 0
	frames(40)
	check(table.getn(skulls(0.05)) == 1 and skullOf("Kel'Thuzad"), "a fallen boss's skull fades away")
	M.bosses = {}
	frames(40)
	check(table.getn(skulls(0.05)) == 0, "no boss, no skull")
	-- bosses come and go many times: the skulls are reused, not piled up
	local function framesUnder()
		local n = 0
		for _, o in ipairs(M.All()) do if o.__kind == "Frame" and under(o, CreedUISkulls) then n = n + 1 end end
		return n
	end
	local before = framesUnder()
	for k = 1, 5 do
		M.bosses = { { name = "Boss" .. k, hp = 10, hpm = 10 } }
		frames(20)
		M.bosses = {}
		frames(40)
	end
	check(framesUnder() <= math.max(before, 2), "skulls are reused (" .. before .. " then " .. framesUnder() .. " frames)")
	-- two skulls back in the pool, then three bosses at once: each takes one (in Lua 5.0 a list
	-- emptied with [n] = nil keeps its count, which once handed out a missing skull and stopped them)
	M.bosses = { { name = "A", hp = 10, hpm = 10 }, { name = "B", hp = 10, hpm = 10 } }
	frames(20)
	M.bosses = {}
	frames(40)
	M.bosses = { { name = "C", hp = 10, hpm = 10 }, { name = "D", hp = 10, hpm = 10 }, { name = "E", hp = 10, hpm = 10 } }
	frames(20)
	M.bosses = { { name = "F", hp = 10, hpm = 10 }, { name = "G", hp = 10, hpm = 10 }, { name = "H", hp = 10, hpm = 10 }, { name = "I", hp = 10, hpm = 10 } }
	frames(30)
	check(part.get() and table.getn(skulls()) == 4 and not chatHas("boss skulls stopped"), "skulls taken from the pool and new ones together, no error")
	M.bosses = {}
	frames(40)
	-- the game failing: nothing breaks, no skull, the part stays on
	M.bosses = { { name = "Anub'Rekhan", hp = 9000, hpm = 10000 } }
	frames(20)
	M.waThrows = true
	frames(40)
	check(table.getn(skulls(0.05)) == 0 and part.get() and not chatHas("boss skulls stopped"), "the game failing hides the skulls and nothing breaks")
	M.waThrows = nil
	frames(30)
	check(table.getn(skulls()) == 1, "and they come back with it")
	-- off: no skulls, no handler, no more questions to the game
	M.Slash("skulls off")
	frames(5)
	local asked = M.waCalls.list
	frames(30)
	check(table.getn(skulls(0.05)) == 0 and M.waHandler == nil and M.waCalls.list == asked, "/creed skulls off: none, and the game is left alone")
	-- a game without the frame handler: they move from Creed UI's own updates
	local register = AZS_RegisterWorldAnchorFrameHandler
	AZS_RegisterWorldAnchorFrameHandler = nil
	M.Slash("skulls on")
	frames(30)
	check(M.waHandler == nil and table.getn(skulls()) == 1, "without the game's frame handler they still show")
	AZS_RegisterWorldAnchorFrameHandler = register
	frames(200)
	check(M.waHandler ~= nil, "and take it once the game has it")
	-- /creed probe shows what the anchors look like
	M.chat = {}
	M.Slash("probe")
	check(chatHas(": AZS tables: .*AZS_RUN%(%d+%)") and chatHas("AZS_STATS%("), "/creed probe lists the game's AZS tables with their sizes")
	check(chatHas(": anchors: ") and chatHas("entries=1") and chatHas(": projected: ") and chatHas("state=onScreen") and chatHas(": downed: 0"),
		"/creed probe shows the game's anchors, a projection and the downed friends")
	M.bosses = {}
	frames(40)
	-- the options window: two columns, inside a 768 px screen, every row inside it
	if not (CreedUIOptions and CreedUIOptions.__shown) then M.Slash("") end
	local ol, ob, or_, ot = M.Rect(CreedUIOptions)
	check(ot - ob <= 700, "the options window stays low enough for any screen (" .. (ot - ob) .. ")")
	local inside, rowsSeen = true, 0
	for _, o in ipairs(M.All()) do
		if o.__kind == "Button" and o.__parent == CreedUIOptions and M.Visible(o) then
			rowsSeen = rowsSeen + 1
			local l, b, r, t = M.Rect(o)
			if l < ol or r > or_ or b < ob or t > ot then inside = false end
		end
	end
	check(inside and rowsSeen >= table.getn(CreedUI.parts), "every row and button sits inside it (" .. rowsSeen .. ")")
	M.Slash("")
	M.Slash("downed on")
	problems("boss skulls")
end

------------------------------------------------------------------ 11d. the abilities' ranks
do
	-- the slot showing an icon, and the rank written in its box (nil: no box)
	local function slotOf(pat)
		for _, o in ipairs(M.All()) do
			if o.__kind == "Texture" and o.__tex and string.find(o.__tex, pat, 1, true) and under(o, CreedUIBar)
				and o.__parent.__kind == "Button" then return o.__parent end
		end
	end
	local function rankOf(pat)
		local b = slotOf(pat)
		if not b then return "no slot" end
		for _, o in ipairs(M.All()) do
			if o.__kind == "FontString" and under(o, b) and o.__text and o.__text ~= "" and visibleAlpha(o) > 0.5
				and string.find(o.__text, "^%d+$") then
				local l, bt, r, tp = M.Rect(o)
				local bl, bb, br, btp = M.Rect(b)
				if (l + r) / 2 > (bl + br) / 2 and (bt + tp) / 2 < (bb + btp) / 2 then return o.__text end
			end
		end
		return nil
	end
	local SS, BF, BS, EV, AM = "Spell_Shadow_RitualOfSacrifice", "Ability_Warrior_PunishingBlow", "Ability_BackStab",
		"Ability_Warrior_Challange", "Ability_Ambush"
	if not CreedUIBar.__shown then M.Slash("bar on") end
	for _, a in pairs(M.actions) do a.start, a.dur = 0, 0 end
	M.meter = M.meter or { damage = {} }
	-- listed in another order than the bar, slot numbers that don't match: the icons decide
	M.loadout = { abilities = {
		{ key = "ability:bs", rank = 2, slotId = 9, icon = "Interface\\Icons\\" .. BS },
		{ key = "ability:ss", rank = 3, slotId = 8, icon = "Interface/Icons/" .. string.lower(SS) .. ".blp" },
		{ key = "ability:ev", rank = 5, slotId = 7, icon = "Interface\\Icons\\" .. EV },
		{ key = "ability:bf", rank = 1, slotId = 6, icon = "Interface\\Icons\\" .. BF },
		{ key = "passive:x", rank = 4, slotId = 1, passive = true, icon = "Interface\\Icons\\" .. AM },
	} }
	frames(40)
	check(rankOf(SS) == "3" and rankOf(BF) == "1" and rankOf(BS) == "2" and rankOf(EV) == "5",
		"each ability's rank in a box on its bottom right, found by its icon (" .. tostring(rankOf(SS)) .. tostring(rankOf(BF))
		.. tostring(rankOf(BS)) .. tostring(rankOf(EV)) .. ")")
	check(rankOf(AM) == nil, "the racial has no rank box (and a passive is never shown)")
	-- a card ranks one up: soon after the game's spells change, the box shows it and flashes
	local glowBefore = countTex(slotOf(BF), "Art\\Glow", 0.2)
	M.loadout.abilities[4].rank = 2
	AZS_SPELLS_UPDATED = M.now
	frames(10)
	check(rankOf(BF) == "2", "a rank up shows within a third of a second (" .. tostring(rankOf(BF)) .. ")")
	local rim
	for _, o in ipairs(M.All()) do
		if o.__kind == "Texture" and o.__tex == CreedUI.FLAT and under(o, slotOf(BF)) and o.__vc and o.__vc[4] == 1 and M.Visible(o) then
			local l, b, r, t = M.Rect(o)
			if r - l < 30 then rim = o end
		end
	end
	check(glowBefore == 0 and countTex(slotOf(BF), "Art\\Glow", 0.2) == 1 and rim and rim.__vc[1] > 0.97 and rim.__vc[3] > 0.5,
		"and it flashes gold")
	frames(60)
	check(rim and rim.__vc[1] < 0.95 and rim.__vc[3] < 0.4 and countTex(slotOf(BF), "Art\\Glow", 0.2) == 0, "then cools back")
	-- ranked up while the cards are up: the flash waits for the bar to come back
	M.phase = "choosing"
	frames(40)
	M.loadout.abilities[4].rank = 3
	AZS_SPELLS_UPDATED = M.now
	frames(40)
	check(rankOf(BF) == nil or CreedUI.cardsFade > 0.9, "the bar is away while the cards are up")
	M.phase = "playing"
	frames(12)
	check(rankOf(BF) == "3" and rim and rim.__vc[1] > 0.97, "back from the cards, the new rank flashes then")
	frames(60)
	-- two digits fit
	M.loadout.abilities[2].rank = 12
	frames(40)
	local b = slotOf(SS)
	local box
	for _, o in ipairs(M.All()) do if o.__kind == "Frame" and under(o, b) and o.__w and o.__w > 15 and o.__w < 30 then box = o end end
	check(rankOf(SS) == "12" and box ~= nil, "a two-digit rank widens its box")
	-- no icons from the game: the slot numbers decide
	M.loadout = { abilities = { { key = "a1", rank = 4, slotId = 1 }, { key = "a2", rank = 7, slotId = 2 } } }
	frames(40)
	check(rankOf(SS) == "4" and rankOf(BF) == "7" and rankOf(BS) == nil, "without icons, by slot number")
	-- the game not ready yet keeps them; out of a run they go
	M.loadout = nil
	frames(40)
	check(rankOf(SS) == "4", "a loadout not in yet keeps the ranks shown")
	local meter = M.meter
	M.meter = nil
	frames(40)
	check(rankOf(SS) == nil and rankOf(BF) == nil, "out of a run, no ranks")
	M.meter = meter
	-- a game without the loadout: nothing breaks
	local loadout = AZS_GetMeterLoadout
	AZS_GetMeterLoadout = nil
	frames(40)
	check(rankOf(SS) == nil, "no loadout in the game: no boxes")
	AZS_GetMeterLoadout = loadout
	-- the loadout isn't read every frame
	M.loadout = { abilities = { { key = "a1", rank = 4, slotId = 1 } } }
	M.loadoutReads = 0
	frames(90)
	check(M.loadoutReads >= 2 and M.loadoutReads <= 4, "the loadout is read about once a second (" .. M.loadoutReads .. " in 3 s)")
	M.chat = {}
	M.Slash("probe")
	check(chatHas(": loadout: a1 r4 slot1") and chatHas(": bar: 1=spell_shadow_ritualofsacrifice r4"), "/creed probe shows the spells' ranks and what each slot found")
	M.loadout = nil
	problems("ranks")
end

------------------------------------------------------------------ 11e. damage taken, stored level-ups, the run's summary, friends down
do
	local function partOf(key)
		for i = 1, table.getn(CreedUI.parts) do if CreedUI.parts[i].key == key then return CreedUI.parts[i] end end
	end
	M.meter = M.meter or { damage = {} }
	M.phase = "playing"
	-- Damage Taken: what hit you, the most first, a skull for each one's icon, per second over the run
	if not CreedUIMeter.__shown then M.Slash("meter on") end
	CreedUIDB.meter.shown = true
	M.runTime = 100
	AZS_TAKEN = { { source = "Plagued Ghoul", dmg = 1200 }, { source = "Anub'Rekhan", dmg = 5400 }, { source = "Nobody", dmg = 0 } }
	CreedUIDB.meter.tab = "taken"
	frames(30)
	check(findText(CreedUIMeter, "^Damage Taken") ~= nil and findText(CreedUIMeter, "^1%. Anub'Rekhan$") ~= nil
		and findText(CreedUIMeter, "^2%. Plagued Ghoul$") ~= nil and findText(CreedUIMeter, "^3%.") == nil,
		"Damage Taken lists what hit you, the most first: " .. table.concat(textsUnder(CreedUIMeter), " | "))
	check(findText(CreedUIMeter, "^66 dtps$") ~= nil, "with the damage you take a second (" .. tostring(findText(CreedUIMeter, "dtps")) .. ")")
	check(countTex(CreedUIMeter, "Art\\Skull$", 0.3) == 2, "a skull for each line's icon")
	local reset
	for _, o in ipairs(M.All()) do
		if o.__kind == "Button" and under(o, CreedUIMeter) and o.__scripts.OnClick then
			for _, k in ipairs(M.All()) do if k.__parent == o and k.__kind == "FontString" and k.__text == "Reset" then reset = o end end
		end
	end
	this = reset
	reset.__scripts.OnClick()
	AZS_TAKEN[1].dmg = 1500
	frames(30)
	check(findText(CreedUIMeter, "^1%. Plagued Ghoul$") ~= nil and findText(CreedUIMeter, "^2%.") == nil, "Reset counts what hit you since")
	AZS_TAKEN = {}
	frames(30)
	check(findText(CreedUIMeter, "^No damage taken yet%.$") ~= nil, "nothing yet says so")
	CreedUIDB.meter.tab = "damage"
	frames(10)
	problems("damage taken")

	-- stored level-ups: a button over the bar with how many wait; a click opens them
	local lv = partOf("levelups")
	check(lv and lv.get(), "stored level-ups are a part, on at first")
	check(M.hud.levels == false, "the game's Level Up! button is hidden while it's on")
	M.storing, M.storedLevels = true, 0
	frames(20)
	check(not M.Visible(CreedUILevelUps), "nothing waiting: no button")
	M.storedLevels = 2
	frames(20)
	check(M.Visible(CreedUILevelUps) and findText(CreedUILevelUps, "^Level Up!$") and findText(CreedUILevelUps, "^2$"), "two waiting: Level Up! with a 2")
	-- its frame in the class's metal, and a new class recolors it (it stayed in the class it was made in)
	local function railOf(f)
		for _, o in ipairs(M.All()) do
			if o.__kind == "Texture" and o.__tex and string.find(o.__tex, "PanelRailT$") and o.__parent == f then return o end
		end
	end
	local rail = railOf(CreedUILevelUps)
	local mr = CreedUI.PanelMetal(CreedUI.Pal())
	check(rail and rail.__vc and math.abs(rail.__vc[1] - mr) < 0.01, "the Level Up! button's frame in the class's metal")
	CreedUI.SetTheme("mage")
	frames(3)
	check(rail and math.abs(rail.__vc[1] - 0.48) < 0.01 and math.abs(rail.__vc[3] - 0.95) < 0.01, "a mage's run: the frame turns the mage's blue")
	CreedUI.SetTheme("warrior")
	frames(3)
	check(rail and math.abs(rail.__vc[1] - 0.80) < 0.01 and math.abs(rail.__vc[3] - 0.46) < 0.01, "a warrior's: the warrior's bronze, no longer blue")
	CreedUI.SetTheme("class")
	frames(3)
	local glow = CreedUILevelUps.glow
	frames(20)
	local calm = glow.__alpha
	M.storedLevels = 3
	frames(3)
	check(findText(CreedUILevelUps, "^3$") and glow.__alpha > calm + 0.2, "one more pulses it")
	M.openedLevels = 0
	this = CreedUILevelUps
	CreedUILevelUps.__scripts.OnClick()
	check(M.openedLevels == 1, "a click opens them, as the game's button does")
	-- while the cards are up it steps aside
	M.phase = "choosing"
	frames(40)
	check(visibleAlpha(CreedUILevelUps) < 0.05, "it steps aside for the cards")
	M.phase = "playing"
	M.storing = false
	frames(30)
	check(not M.Visible(CreedUILevelUps), "with Store Level-Ups off, none")
	M.storing = true
	M.Slash("levelups off")
	frames(20)
	check(M.hud.levels == true and not M.Visible(CreedUILevelUps), "off: the game's button is back")
	M.Slash("levelups on")
	frames(5)
	check(M.hud.levels == false, "and on hides it again")
	M.storedLevels = 0
	frames(20)
	problems("stored level-ups")

	-- the run's summary: when a run ends, a panel with what it came to, counting up
	check(partOf("summary") and partOf("summary").get(), "the run summary is a part, on at first")
	M.runEnd = nil
	frames(10)
	check(not M.Visible(CreedUISummary), "no summary while the run goes on")
	M.runTime = 600
	M.runEnd = { result = "victory", t = 600, lvl = 24, kills = 1834, elites = 12, guardians = 3, bosses = 5, dmg = 2400000,
		taken = 81234, gold = 512, chests = 9, magnets = 2, endl = 0, hero = "Creed" }
	frames(6)
	check(M.Visible(CreedUISummary) and findText(CreedUISummary, "^Victory!$") ~= nil and findText(CreedUISummary, "^Creed$") ~= nil,
		"a won run: Victory! and the hero")
	local early = findText(CreedUISummary, "^[%d,]+$")
	frames(60)
	local texts = table.concat(textsUnder(CreedUISummary), " | ")
	check(findText(CreedUISummary, "^10:00$") and findText(CreedUISummary, "^24$") and findText(CreedUISummary, "^1,834$")
		and findText(CreedUISummary, "^2.4M$") and findText(CreedUISummary, "^4,000$") and findText(CreedUISummary, "^81,234$")
		and findText(CreedUISummary, "^512$") and findText(CreedUISummary, "^9$") and findText(CreedUISummary, "^Damage a second$"),
		"every line, damage a second from the damage and the time: " .. texts)
	check(early ~= nil and early ~= "1,834", "the numbers count up as it opens (" .. tostring(early) .. ")")
	local l = M.Rect(CreedUISummary)
	check(l < 200, "it sits at the left, clear of the game's end screen")
	-- closed by its x
	local x
	for _, o in ipairs(M.All()) do
		if o.__kind == "Button" and o.__parent == CreedUISummary then x = o end
	end
	this = x
	x.__scripts.OnClick()
	frames(30)
	check(not M.Visible(CreedUISummary), "its x closes it")
	-- you fall in co-op: the summary opens, and its numbers stay still while the party plays on
	M.runEnd = { result = "defeat", t = 420, lvl = 18, kills = 900, dmg = 100000, taken = 40000, gold = 100, chests = 2, hero = "Creed" }
	M.runTime = 420
	frames(60)
	check(M.Visible(CreedUISummary) and findText(CreedUISummary, "^You have fallen$") ~= nil, "a fallen run: You have fallen")
	local before = table.concat(textsUnder(CreedUISummary), "|")
	local changed = 0
	for k = 1, 30 do
		M.runEnd.t, M.runEnd.kills, M.runEnd.dmg, M.runTime = 420 + k, 900 + k * 7, 100000 + k * 999, 420 + k
		frames(3)
		if table.concat(textsUnder(CreedUISummary), "|") ~= before then changed = changed + 1 end
	end
	check(changed == 0 and M.Visible(CreedUISummary), "while the party plays on, the numbers stay still (" .. changed .. " changes)")
	check(findText(CreedUISummary, "^900$") ~= nil and findText(CreedUISummary, "^7:00$") ~= nil, "they are the run's at its end")
	-- your friends win after you fell: that's another ending, taken once
	M.runEnd = { result = "victory", t = 1200, lvl = 18, kills = 2000, dmg = 300000, taken = 50000, gold = 300, chests = 4, hero = "Creed" }
	M.runTime = 1200
	frames(60)
	check(findText(CreedUISummary, "^Victory!$") ~= nil and findText(CreedUISummary, "^2,000$") ~= nil, "the party wins after: Victory! with the new numbers")
	-- fighting on in endless after a victory puts it away
	M.runTime = 1210
	frames(30)
	check(not M.Visible(CreedUISummary), "fighting on past a victory (endless) puts it away")
	M.runEnd = nil
	frames(10)
	problems("run summary")

	-- friends down: a banner and a sound, a mark where they lie, an arrow while they're off the screen
	local dn = partOf("downed")
	check(dn and dn.get(), "downed friends are a part, on at first")
	M.unit.party1 = { exists = true, name = "Melkor", class = "Mage", level = 20, hp = 0, hpm = 2000, mp = 0, mpm = 1200, power = 0, dead = true }
	M.unit.party2 = { exists = true, name = "Zulyara", class = "Priest", level = 20, hp = 1650, hpm = 1800, mp = 1100, mpm = 1500, power = 0 }
	M.downed, M.revive, M.sounds = {}, {}, {}
	frames(20)
	check(not M.Visible(CreedUIDownedBanner), "nobody down: no banner")
	M.downed = { { id = 2, name = "Melkor", anchorId = "downed:2", anchorStatus = "ready", positionAvailable = true, wx = 8, wy = -6 } }
	frames(10)
	check(M.Visible(CreedUIDownedBanner) and findText(CreedUIDownedBanner, "^Melkor is down!$") ~= nil, "Melkor falls: a banner says so")
	check(M.sounds[1] == "RaidWarning", "with the raid warning sound")
	local function markOf(name)
		for _, o in ipairs(M.All()) do
			if o.__kind == "FontString" and under(o, CreedUIDowned) and o.__text == name and visibleAlpha(o) > 0.3 then return o.__parent, o end
		end
	end
	local mark, label = markOf("Melkor")
	local mx, my = 0, 0
	if mark then
		local l2, b2, r2, t2 = M.Rect(mark)
		mx, my = (l2 + r2) / 2, (b2 + t2) / 2
	end
	check(mark and math.abs(mx - (640 + 8 * 9)) < 1 and math.abs(my - (330 - 6 * 9 + 0.2 * 9)) < 1,
		string.format("a mark where they lie (%.1f, %.1f)", mx, my))
	check(label and label.__color and label.__color[1] < 0.6 and label.__color[3] > 0.8, "their name in their class color (a mage's blue)")
	check(findText(CreedUIDowned, "^20 yd$") ~= nil, "and how far they are")
	-- their class crest inside the mark, as see-through as the mark
	local crest, ringTex
	for _, o in ipairs(M.All()) do
		if o.__kind == "Texture" and under(o, CreedUIDowned) and M.Visible(o) and o.__tex then
			if string.find(o.__tex, "UI%-CharacterCreate%-Classes") then crest = o end
			if string.find(o.__tex, "Revive") then ringTex = o.__tex end
		end
	end
	check(crest and crest.__tc and math.abs(crest.__tc[1] - 0.25) < 0.01 and crest.__tc[3] == 0, "a mage's crest inside the mark")
	check(crest and (crest.__alpha or 1) >= 0.65 and (crest.__alpha or 1) <= 0.72, "see-through, as the mark is, but plain to see (" .. tostring(crest and crest.__alpha) .. ")")
	check(ringTex and string.find(ringTex, "ReviveRing$"), "on the ring with a clear middle")
	local p1 = M.unit.party1
	M.unit.party1 = nil -- their class unknown for a moment
	frames(3)
	local glyph, crests = false, 0
	for _, o in ipairs(M.All()) do
		if o.__kind == "Texture" and under(o, CreedUIDowned) and M.Visible(o) and o.__tex then
			if string.find(o.__tex, "ReviveMark$") then glyph = true end
			if string.find(o.__tex, "Classes$") then crests = crests + 1 end
		end
	end
	check(glyph and crests == 0, "a friend of no known class: the rising spirit, no crest")
	M.unit.party1 = p1
	frames(3)
	frames(150)
	check(not M.Visible(CreedUIDownedBanner), "the banner fades after a few seconds")
	check(markOf("Melkor") ~= nil, "the mark stays while they're down")
	-- you stand on them: it counts up in green
	M.revive = { down = 0, reviving = "Melkor", rshare = 0.45 }
	frames(5)
	check(findText(CreedUIDowned, "^Reviving 45%%$") ~= nil, "standing on them counts the revive up: " .. table.concat(textsUnder(CreedUIDowned), " | "))
	M.revive = {}
	-- off the screen: an arrow on its edge toward them, with the distance
	M.downed[1].wx, M.downed[1].wy = 120, 10
	frames(5)
	local arrow
	for _, o in ipairs(M.All()) do
		if o.__kind == "Texture" and o.__tex and string.find(o.__tex, "EdgeArrow", 1, true) and under(o, CreedUIDowned) and visibleAlpha(o) > 0.5 then arrow = o end
	end
	local al, ab, ar, at = 0, 0, 0, 0
	if arrow then al, ab, ar, at = M.Rect(arrow) end
	check(arrow and ar <= 1280 and ar > 1280 - 80 and (ab + at) / 2 > 360, string.format("off the screen: an arrow on the right edge (%.0f, %.0f)", (al + ar) / 2, (ab + at) / 2))
	check(markOf("Melkor") == nil and findText(CreedUIDowned, "^Melkor  20 yd$") ~= nil, "naming them, with the distance")
	-- behind the camera: the arrow turns the other way
	M.waBehind = { Melkor = true }
	frames(5)
	if arrow then al, ab, ar, at = M.Rect(arrow) end
	check(arrow and al < 80, "behind the camera: the arrow points the other way")
	M.waBehind = nil
	-- a second friend falls: one banner, the sound again
	M.downed[2] = { id = 3, name = "Zulyara", anchorId = "downed:3", anchorStatus = "ready", positionAvailable = true, wx = -4, wy = 4 }
	frames(10)
	check(findText(CreedUIDownedBanner, "^Zulyara is down!$") ~= nil and table.getn(M.sounds) == 2, "a second friend: a banner and the sound again")
	-- back up: no marks
	M.downed = {}
	frames(10)
	check(markOf("Melkor") == nil and markOf("Zulyara") == nil and table.getn(M.sounds) == 2, "back on their feet: no marks, no sound")
	-- off: nothing, the game left alone
	M.Slash("downed off")
	M.downed = { { id = 2, name = "Melkor", anchorId = "downed:2", anchorStatus = "ready", positionAvailable = true, wx = 8, wy = -6 } }
	frames(20)
	check(not M.Visible(CreedUIDownedBanner) and markOf("Melkor") == nil and table.getn(M.sounds) == 2, "/creed downed off: no banner, no mark")
	M.Slash("downed on")
	frames(10)
	check(markOf("Melkor") ~= nil and table.getn(M.sounds) == 2, "on again: the mark, but no alarm for who was already down")
	M.downed = {}
	frames(10)
	M.unit.party1, M.unit.party2 = nil, nil
	problems("friends down")
end

------------------------------------------------------------------ 11f. four guardians stay a small stack
do
	local function barOf(name)
		for _, o in ipairs(M.All()) do
			if o.__kind == "FontString" and o.__text == name and under(o, CreedUIBosses) and visibleAlpha(o) > 0.5 then
				local l, b, r, t = M.Rect(o.__parent.__parent)
				return r - l, t - b, (l + r) / 2
			end
		end
	end
	M.phase = "playing"
	if not CreedUIDB.bosses.enabled then M.Slash("bosses on") end
	local saveB, saveG = M.bosses, M.guardians
	M.bosses = { { name = "Hakkar", hp = 90000, hpm = 100000 } }
	M.guardians = {
		{ id = 41, name = "Gnoll Packleader", hp = 9000, hpm = 10000, awake = true },
		{ id = 42, name = "Kobold Geomancer", hp = 8000, hpm = 10000, awake = true },
		{ id = 43, name = "Murloc Tidecaller", hp = 7000, hpm = 10000, awake = true },
		{ id = 44, name = "Defias Pillager", hp = 6000, hpm = 10000, awake = true },
	}
	AZS_UNITS_UPDATED = M.now
	frames(60)
	local bw, bh, bx = barOf("Hakkar")
	local gw, gh, gx = barOf("Gnoll Packleader")
	check(bw and gw and gw < bw * 0.75 and gh < bh, string.format("a guardian's bar is narrower and thinner than a boss's (%s x %s vs %s x %s)",
		tostring(gw), tostring(gh), tostring(bw), tostring(bh)))
	check(bw and math.abs(bw - CreedUIDB.bosses.width * 1.2) < 1, "the boss keeps its full bar, a fifth bigger")
	check(bx and gx and math.abs(bx - gx) < 1, "the guardians' bars sit centered under the boss's")
	local l, b, r, t = M.Rect(CreedUIBosses)
	local lowest = 9999
	for _, o in ipairs(M.All()) do
		if o.__kind == "FontString" and o.__text == "Defias Pillager" and under(o, CreedUIBosses) then
			local _, b2 = M.Rect(o.__parent.__parent)
			lowest = b2
		end
	end
	check(t - lowest < 180, "a boss and four guardians take less than 180 px (" .. math.floor(t - lowest) .. ")")
	-- a row that was a guardian's, then a boss's: it takes the boss's look again
	M.guardians = {}
	M.bosses = { { name = "Hakkar", hp = 90000, hpm = 100000 }, { name = "Jin'do", hp = 50000, hpm = 60000 } }
	AZS_UNITS_UPDATED = M.now
	frames(90)
	local jw = barOf("Jin'do")
	check(jw and math.abs(jw - CreedUIDB.bosses.width * 1.2) < 1, "a reused row takes a boss's full look")
	M.bosses, M.guardians = saveB, saveG
	frames(30)
	problems("compact guardians")
end

------------------------------------------------------------------ 11g. damage numbers and the level-up cards
do
	local function shownHolders()
		local n = 0
		for _, o in ipairs(M.All()) do
			if o.__kind == "Frame" and o.__parent == CreedUINumbersLayer and o.__shown then n = n + 1 end
		end
		return n
	end
	M.phase = "playing"
	if CreedUIDB.numbers and not CreedUIDB.numbers.enabled then M.Slash("numbers on") end
	local foe = M.Enemy("Ghoul", 6, 4)
	frames(30)
	M.Hit(foe, 420, "strike", false)
	frames(6)
	check(labelsWith("RitualOfSacrifice") >= 1, "a hit shows its number and icon")
	-- the cards come up: the numbers step aside at once (under the veil their icons came out black)
	M.phase = "choosing"
	frames(2)
	check(labelsWith("RitualOfSacrifice") == 0 and visibleAlpha(CreedUINumbersLayer) == 0, "the cards up: no numbers, no black icons")
	M.Hit(foe, 99, "strike", false)
	frames(20)
	check(labelsWith("RitualOfSacrifice") == 0, "hits while picking stay hidden")
	-- a card picked: the old numbers are dropped, nothing flies across the screen
	foe.x, foe.y = -30, -12
	M.phase = "playing"
	frames(1)
	check(shownHolders() == 0, "the cards closed: the numbers from before are gone (" .. shownHolders() .. ")")
	frames(30)
	M.Hit(foe, 300, "strike", false)
	frames(10)
	check(labelsWith("RitualOfSacrifice") >= 1 and visibleAlpha(CreedUINumbersLayer) > 0.9, "and new hits show as the fight resumes")
	frames(90)
	problems("numbers and cards")
end

------------------------------------------------------------------ 11h. the talent window
do
	local function texts() return table.concat(textsUnder(CreedUITalents), " | ") end
	local I = "Interface\\Icons\\"
	M.phase = "playing"
	M.meter = M.meter or { damage = {} }
	-- out of a run: it says where the talents show
	local meter = M.meter
	M.meter = nil
	M.Slash("talents")
	frames(3)
	check(M.Visible(CreedUITalents) and findText(CreedUITalents, "^Your talents show here during a run%.$") ~= nil, "/creed talents opens it; out of a run it says so")
	M.meter = meter
	M.loadout = { abilities = {}, talents = {} }
	frames(40)
	check(findText(CreedUITalents, "^No talents learned yet%.$") ~= nil, "a run with none learned: it says so")
	M.loadout.talents = {
		{ key = "t:mortal", tree = "warrior.arms", rank = 5, name = "Improved Heroic Strike", icon = I .. "Ability_Rogue_Ambush" },
		{ key = "t:deep", tree = "warrior.arms", rank = 3, name = "Deep Wounds", icon = I .. "Ability_BackStab" },
		{ key = "t:sweep", tree = "warrior.arms", rank = 1, name = "Sweeping Strikes", icon = I .. "Ability_Warrior_PunishingBlow" },
		{ key = "t:a4", tree = "warrior.arms", rank = 2, name = "Two-Handed Mastery", icon = I .. "Ability_Warrior_Challange" },
		{ key = "t:a5", tree = "warrior.arms", rank = 4, name = "Impale", icon = I .. "Spell_Shadow_RitualOfSacrifice" },
		{ key = "t:fury1", tree = "warrior.fury", rank = 5, name = "Cruelty", icon = I .. "Ability_Rogue_Eviscerate" },
		{ key = "t:prot0", tree = "warrior.protection", rank = 0, name = "Shield Specialization", icon = I .. "Ability_Ambush" },
		{ key = "t:prot1", tree = "warrior.protection", rank = 12, name = "Toughness", icon = I .. "Ability_Ambush" },
	}
	frames(40)
	check(findText(CreedUITalents, "^Arms$") and findText(CreedUITalents, "^Fury$") and findText(CreedUITalents, "^Protection$"),
		"the trees by name, side by side: " .. texts())
	check(findText(CreedUITalents, "^15 points$") and findText(CreedUITalents, "^5 points$") and findText(CreedUITalents, "^12 points$"),
		"each tree's points")
	check(findText(CreedUITalents, "^32 points spent$") ~= nil, "the total at the foot")
	local icons, ranks = 0, {}
	for _, o in ipairs(M.All()) do
		if o.__kind == "Frame" and o.data and under(o, CreedUITalents) and M.Visible(o) then
			icons = icons + 1
			for _, k in ipairs(M.All()) do
				if k.__kind == "FontString" and under(k, o) and k.__text then table.insert(ranks, k.__text) end
			end
		end
	end
	table.sort(ranks)
	check(icons == 7 and table.concat(ranks, ",") == "1,12,2,3,4,5,5", "every learned talent as its icon with its rank (none at 0): " .. icons .. " " .. table.concat(ranks, ","))
	-- five in a tree wrap onto a second row
	local first, fifth
	for _, o in ipairs(M.All()) do
		if o.__kind == "Frame" and o.data and under(o, CreedUITalents) then
			if o.data.name == "Improved Heroic Strike" then first = o end
			if o.data.name == "Impale" then fifth = o end
		end
	end
	local fl, fb = M.Rect(first)
	local vl, vb = M.Rect(fifth)
	check(math.abs(fl - vl) < 1 and vb < fb - 30, "four to a row, the fifth under the first")
	-- the trees in the language picked, by the game's own names
	M.Slash("language fr")
	frames(40)
	check(findText(CreedUITalents, "^Armes$") and findText(CreedUITalents, "^Fureur$") and findText(CreedUITalents, "^15 points$"), "in French: Armes, Fureur")
	M.Slash("language en")
	frames(40)
	-- a talent's name on hover
	M.tip.lines = {}
	this = first
	first.__scripts.OnEnter()
	check(M.tip.lines[1] == "Improved Heroic Strike" and M.tip.lines[2] == "Rank 5", "pointing at one shows its name and rank")
	first.__scripts.OnLeave()
	-- inside the screen, in the panel's look, closed by its x
	local l, b, r, t2 = M.Rect(CreedUITalents)
	check(l >= 0 and r <= 1280 and b >= 0 and t2 <= 720, "it fits the screen")
	local x
	for _, o in ipairs(M.All()) do if o.__kind == "Button" and o.__parent == CreedUITalents then x = o end end
	this = x
	x.__scripts.OnClick()
	check(not M.Visible(CreedUITalents), "its x closes it")
	M.Slash("talents")
	frames(2)
	M.Slash("talents")
	check(not M.Visible(CreedUITalents), "/creed talents again closes it")
	M.loadout = nil
	problems("talent window")
end

------------------------------------------------------------------ 11i. a stacking number grows, to a cap
do
	-- the size a number shows at: its icon's frame's scale
	local function sizeOf(iconPat)
		local best = 0
		for _, o in ipairs(M.All()) do
			if o.__kind == "Texture" and o.__tex and string.find(o.__tex, iconPat) and under(o, CreedUINumbersLayer) and visibleAlpha(o) > 0.2 then
				best = math.max(best, o.__parent.__scale or 1)
			end
		end
		return best
	end
	M.phase = "playing"
	frames(120)
	-- one hit: the smaller baseline
	local lone = M.Enemy("Ghoul", -10, 6)
	M.Hit(lone, 300, "strike", false)
	frames(12)
	local one = sizeOf("RitualOfSacrifice")
	check(one > 0.6 and one < 0.82, string.format("a single hit shows a touch smaller than before (%.2f)", one))
	frames(120)
	-- a DoT ticking on one enemy: it grows as the ticks stack, then holds
	local foe = M.Enemy("Ghoul", 10, 6)
	M.Hit(foe, 40, "corruption", true)
	frames(12)
	local first = sizeOf("AbominationExplosion")
	local sizes = {}
	for k = 1, 8 do
		M.Hit(foe, 40, "corruption", true)
		frames(15) -- a tick every half second
		sizes[k] = sizeOf("AbominationExplosion")
	end
	check(first > 0 and sizes[3] > first * 1.2, string.format("ticking on, it grows (%.2f to %.2f)", first, sizes[3]))
	check(sizes[8] <= first * 1.4 and math.abs(sizes[8] - sizes[5]) < 0.02, string.format("and stops at about a third bigger (%.2f, %.2f, %.2f)", sizes[5], sizes[8], first * 1.35))
	frames(150)
	problems("stacking numbers")
end

------------------------------------------------------------------ 11j. the class's emblem and crest sit on the bar's ends, clear of the slots
do
	M.phase = "playing"
	frames(10)
	local e1, e2 = CreedUIBar.deco.emblems[1], CreedUIBar.deco.emblems[2]
	local pl, pb, pr, pt = M.Rect(CreedUIBar.panel)
	local l1, b1, r1, t1 = M.Rect(e1)
	local l2, b2, r2, t2 = M.Rect(e2)
	local sl = 9999
	local sr = -9999
	for _, o in ipairs(M.All()) do
		if o.__kind == "Button" and o.__parent == CreedUIBar and M.Visible(o) then
			local l, _, r = M.Rect(o)
			sl, sr = math.min(sl, l), math.max(sr, r)
		end
	end
	local u = 76 / 110 * 0.85
	-- drawn at 0.85 of the bar's scale; the emblem's middle (220 of its 512) 24 in from the panel's left
	-- end, its ring (about 66 of its pixels round) clear of the first slot; the crest's (292) likewise
	check(math.abs(l1 + 220 * u - (pl + 24)) < 1 and pl + 24 + 70 * u < sl, string.format("the emblem's middle just in from the panel's left end, its ring clear of the first slot (%.0f < %.0f)", pl + 24 + 70 * u, sl))
	check(math.abs(l2 + 292 * u - (pr - 24)) < 1 and pr - 24 - 70 * u > sr, "the crest's middle just in from the right end, clear of the last")
	check(math.abs((t1 - b1) / 2 + b1 - (pb + pt) / 2) < 1 and math.abs(t1 - b1 - 256 * u) < 1, "both centred on the bar")
	check(l1 > pl - 120 and r2 < pr + 120 + 512 * u, "reaching less far past the bar's ends")
	check(not e1.__vc and not e2.__vc, "painted in their own colors (no tint)")
	check(t1 > pt + 20, "the emblem rising over the panel's top")
	problems("bar emblems")
end

------------------------------------------------------------------ 11k. the bar keeps its size as a run starts
do
	local function width() local l, _, r = M.Rect(CreedUIBar.panel) return r - l end
	M.phase = "ready"
	AZS_RUN = nil
	frames(90)
	local before = width()
	SIM.StartRun("naxx", { killAfter = 120 })
	M.runTime = 30
	local pub, tally = SIM.Publish, { kills = 59, gold = 71, chest = 20 }
	SIM.Publish = function()
		pub()
		if AZS_RUN then AZS_RUN.kills, AZS_RUN.gold, AZS_RUN.chest = tally.kills, tally.gold, tally.chest end
	end
	SIM.Publish()
	M.phase = "playing"
	SIM.Advance(3, 1 / 30)
	local during = width()
	check(M.Visible(CreedUITally) and math.abs(during - before) < 1,
		string.format("a run starting: the kills, gold and cache show, the bar keeps its size (%.0f, %.0f)", before, during))
	tally.kills, tally.gold = 4812, 1290
	SIM.Advance(2, 1 / 30)
	check(math.abs(width() - before) < 1, string.format("and as the numbers grow (%.0f)", width()))
	SIM.Publish = pub
	problems("bar size")
end

------------------------------------------------------------------ 11l. the class's metal in every zone
do
	-- a zone with silver-blue metal (as Duskwood's): every part's still the hero's class's (a rogue's)
	local was = CreedUI.pal
	CreedUI.pal = { title = { 0.7, 0.8, 1 }, rim = { 0.62, 0.70, 0.86 }, gem = { 0.5, 0.7, 1 }, glow = { 0.6, 0.8, 1 },
		trough = { 0.02, 0.04, 0.09 }, mc = { 0.7, 0.8, 1 }, fillA = { 0.1, 0.2, 0.5 }, fillM = { 0.2, 0.4, 0.9 }, fillB = { 0.5, 0.8, 1 } }
	CreedUI.palStamp = CreedUI.palStamp + 1
	frames(10)
	local p = CreedUI.Pal()
	check(p.rim[1] == 0.94 and p.rim[2] == 0.88 and p.title[1] == 1.00 and p.fillM[3] == 0.9, "the palette keeps the zone's fills, its metal the rogue's")
	local rim
	for _, o in ipairs(M.All()) do
		if o.__kind == "Texture" and o.__tex and string.find(o.__tex, "Art\\FrameL$") and under(o, CreedUIPlayer) then rim = o end
	end
	check(rim and rim.__vc and math.abs(rim.__vc[1] - 0.94) < 0.01 and math.abs(rim.__vc[3] - 0.40) < 0.01, "your frame's bar rim is the rogue's metal, not the zone's silver")
	CreedUI.pal = was
	CreedUI.palStamp = CreedUI.palStamp + 1
	frames(5)
	problems("class metal")
end

------------------------------------------------------------------ 11m. the bar's ends even; the timer's metal bronze
do
	M.phase = "playing"
	frames(30)
	local pl, pb, pr, pt = M.Rect(CreedUIBar.panel)
	local first, last = 9999, -9999
	for _, o in ipairs(M.All()) do
		if o.__kind == "Button" and o.__parent == CreedUIBar and M.Visible(o) then
			local l, _, r = M.Rect(o)
			first = math.min(first, l)
			last = math.max(last, r)
		end
	end
	local tl, _, tr = M.Rect(CreedUITally)
	if M.Visible(CreedUITally) then last = math.max(last, tr) end
	local gapL, gapR = first - pl, pr - last
	check(M.Visible(CreedUITally) and math.abs(gapL - gapR) < 16, string.format("the bar's two ends look the same: %.0f and %.0f from the panel's ends", gapL, gapR))
	local mid
	for _, o in ipairs(M.All()) do
		if o.__kind == "Texture" and o.__tex and string.find(o.__tex, "Art\\Diamond$") and o.__parent == CreedUIBar.panel and o.__w == 20 then
			local l, _, r = M.Rect(o)
			mid = (l + r) / 2
		end
	end
	check(mid and math.abs(mid - (pl + pr) / 2) < 1, "the rails' diamonds sit at the frame's middle")
	-- the timer: its metal bronze gold, its fill and title the zone's
	local rimM
	for _, o in ipairs(M.All()) do
		if o.__kind == "Texture" and o.__tex and string.find(o.__tex, "Art\\FrameM$") and under(o, CreedUITimerFrame) and o.__vc then rimM = o end
	end
	check(rimM and math.abs(rimM.__vc[1] - 0.95) < 0.01 and math.abs(rimM.__vc[2] - 0.79) < 0.01 and math.abs(rimM.__vc[3] - 0.44) < 0.01,
		"the timer's rails are bronze gold")
	problems("bar ends and timer metal")
end

------------------------------------------------------------------ 11b. damage taken: red numbers by the hero
do
	SIM.StartRun("naxx", { killAfter = 60 })
	AZS_TAKEN = { { source = "Plagued Ghoul", dmg = 900 } } -- already taken when a /reload comes mid-run
	M.Reload(DIR, true)
	SIM.Advance(0.5, 1 / 30)
	check(findText(CreedUIHurt, "^%-") == nil, "what was taken before isn't shown again: " .. table.concat(textsUnder(CreedUIHurt), " | "))
	AZS_TAKEN = { { source = "Plagued Ghoul", dmg = 1200 }, { source = "Anub'Rekhan", dmg = 450 } }
	SIM.Advance(0.3, 1 / 30)
	check(findText(CreedUIHurt, "^%-750$") ~= nil, "new blows rise as one red number: " .. table.concat(textsUnder(CreedUIHurt), " | "))
	local red
	for _, o in ipairs(M.All()) do
		if o.__kind == "FontString" and o.__text == "-750" and under(o, CreedUIHurt) then red = o end
	end
	check(red and red.__color and red.__color[1] > 0.9 and red.__color[2] < 0.4, "in red")
	local l, b, r, t = M.Rect(red)
	local ul, ub, ur, ut = M.Rect(UIParent)
	check(red and (l + r) / 2 < (ul + ur) / 2 and (b + t) / 2 > (ub + ut) / 2, "beside the hero, at the middle of the screen")
	SIM.Advance(2, 1 / 30)
	check(findText(CreedUIHurt, "^%-750$") == nil, "and it fades away")
	-- the health you get back, in green on the other side
	AZS_HEALING = { { name = "Renew", dmg = 250 } }
	SIM.Advance(0.3, 1 / 30)
	local green
	for _, o in ipairs(M.All()) do
		if o.__kind == "FontString" and o.__text == "+250" and under(o, CreedUIHurt) then green = o end
	end
	check(green and green.__color and green.__color[2] > 0.9 and green.__color[1] < 0.5, "a heal rises as a green +250")
	local gl, gb, gr, gt = M.Rect(green)
	local hl, hb, hr, ht = M.Rect(UIParent)
	check(green and (gl + gr) / 2 > (hl + hr) / 2, "on the hero's other side")
	AZS_HEALING = nil
	M.Slash("") -- the options open and close without trouble
	problems("damage taken")
end

------------------------------------------------------------------ 11c. the pet bar; a gold chest over each cache
do
	SIM.StartRun("naxx", { killAfter = 60 })
	M.petActions, M.summons = nil, {}
	frames(30)
	check(not M.Visible(CreedUIPetBar) or visibleAlpha(CreedUIPetBar) < 0.05, "no pet out: no pet bar")
	-- summons: each kind's face, count and the skills the meter saw it use
	local I = "Interface\\Icons\\"
	M.summons = { { id = 1, key = "spirit_wolf", kind = "pet", name = "Spirit Wolf", icon = I .. "Spell_Nature_SpiritWolf" },
		{ id = 2, key = "spirit_wolf", kind = "pet", name = "Spirit Wolf", icon = I .. "Spell_Nature_SpiritWolf" } }
	CreedUIDB.meter.tab = "damage"
	table.insert(M.meter.damage, { key = "bite", name = "Bite", icon = I .. "Ability_Racial_Cannibalize", amount = 700,
		actor = { id = "P1", kind = "pet", name = "Spirit Wolf", summonKey = "spirit_wolf" } })
	frames(40)
	check(M.Visible(CreedUIPetBar) and visibleAlpha(CreedUIPetBar) > 0.9, "summons out: the pet bar shows")
	check(countTex(CreedUIPetBar, "SpiritWolf$") == 1 and findText(CreedUIPetBar, "^2$") ~= nil, "the wolves' face and their count: " .. table.concat(textsUnder(CreedUIPetBar), " | "))
	check(countTex(CreedUIPetBar, "Cannibalize$") == 0, "a skill whose hits haven't been seen isn't shown (no value to give)")
	-- each kind its own face, by its name; a skill shows what it hits for, not its total
	table.insert(M.summons, { id = 3, key = "raptor", kind = "pet", name = "Raptor", icon = I .. "INV_Misc_QuestionMark" })
	local foe = M.Enemy("Ghoul", 2, 4)
	M.Hit(foe, 350, "strike", false)
	local ev = M.world.events[M.world.nEvents]
	ev.meterSourceKey, ev.meterSource = "bite", "Bite"
	frames(20)
	check(countTex(CreedUIPetBar, "Pet_Raptor$") == 1 and countTex(CreedUIPetBar, "QuestionMark$") == 0, "the raptor wears a raptor")
	-- a skill shows once its hits are seen, with its own icon; a buff that deals none never does
	check(countTex(CreedUIPetBar, "BeastCall$") == 0 and countTex(CreedUIPetBar, "FerociousBite$") == 0,
		"no Kill Command or Bestial Wrath before any of their hits")
	table.insert(M.summons, { id = 5, key = "imp", kind = "imp", name = "Imp", icon = I .. "INV_Misc_QuestionMark" })
	frames(10)
	check(countTex(CreedUIPetBar, "SummonImp$") == 1 and countTex(CreedUIPetBar, "FireBolt$") == 0, "a new Imp: its face, no Firebolt yet")
	M.Hit(M.Enemy("Ghoul", 2, 4), 222, "strike", false)
	local fe = M.world.events[M.world.nEvents]
	fe.meterSourceKey, fe.meterSource = "ability:imp_firebolt:r1", "Firebolt"
	frames(10)
	check(countTex(CreedUIPetBar, "FireBolt$") == 1 and findText(CreedUIPetBar, "^222$") ~= nil, "its Firebolt shows once it hits, with the game's icon for it")
	table.remove(M.summons)
	check(findText(CreedUIPetBar, "^350$") ~= nil and findText(CreedUIPetBar, "700") == nil,
		"Bite shows what it hits for (350), not its total (700): " .. table.concat(textsUnder(CreedUIPetBar), " | "))
	-- its tooltip: what it does and its damage now, as a skill's would
	M.Hit(foe, 900, "strike", false, true)
	ev = M.world.events[M.world.nEvents]
	ev.meterSourceKey, ev.meterSource = "bite", "Bite"
	AZS_STATS = AZS_STATS or {}
	local petWas = AZS_STATS.pet
	AZS_STATS.pet = 0.25
	frames(10)
	local bite
	for _, o in ipairs(M.All()) do
		if o.__kind == "Texture" and o.__tex and string.find(o.__tex, "Cannibalize$") and under(o, CreedUIPetBar) then bite = o.__parent end
	end
	this = bite
	bite.__scripts.OnEnter()
	local tip = table.concat(M.tip.lines, " / ")
	check(string.find(tip, "Bites the enemy you attack.", 1, true) and string.find(tip, "Hits for | 350", 1, true)
		and string.find(tip, "Crits for | 900", 1, true) and string.find(tip, "Pet Damage | +25%", 1, true)
		and string.find(tip, "Hits per second", 1, true), "Bite's tooltip: what it does, its hits, its crit, the pet bonus: " .. tip)
	bite.__scripts.OnLeave()
	AZS_STATS.pet = petWas
	-- Kill Command's hits come under its key, not its name: still its own value
	M.Hit(foe, 1234, "strike", false)
	ev = M.world.events[M.world.nEvents]
	ev.meterSourceKey, ev.meterSource, ev.abilityName = "ability:kill_command:r2", nil, nil
	frames(10)
	check(findText(CreedUIPetBar, "^1%.2K$") ~= nil, "Kill Command's hits register by its key: " .. table.concat(textsUnder(CreedUIPetBar), " | "))
	-- big values side by side: short, and never over each other
	for _, hit in ipairs({ { 48712, "bite" }, { 5868, "ability:kill_command:r2" } }) do
		M.Hit(foe, hit[1], "strike", false)
		ev = M.world.events[M.world.nEvents]
		ev.meterSourceKey, ev.meterSource, ev.abilityName = hit[2], nil, nil
	end
	frames(10)
	local vals = {}
	for _, o in ipairs(M.All()) do
		if o.__kind == "FontString" and o.__text and under(o, CreedUIPetBar) and visibleAlpha(o) > 0.05 and string.find(o.__text, "^[%d%.]+[KM]?$") then
			local l, b, r, t = M.Rect(o)
			local w = M.TextWidth and M.TextWidth(o) or (r - l)
			local cx = (l + r) / 2
			table.insert(vals, { text = o.__text, l = cx - w / 2, r = cx + w / 2, y = (b + t) / 2 })
		end
	end
	local clash = 0
	for i = 1, table.getn(vals) do
		for j = i + 1, table.getn(vals) do
			local a, b = vals[i], vals[j]
			if math.abs(a.y - b.y) < 6 and a.l < b.r and b.l < a.r then clash = clash + 1 end
		end
	end
	check(findText(CreedUIPetBar, "^49K$") ~= nil and findText(CreedUIPetBar, "^5%.9K$") ~= nil and clash == 0,
		"big values read 49K, 5.9K and don't overlap: " .. clash .. " | " .. table.concat(textsUnder(CreedUIPetBar), " | "))
	table.remove(M.summons)
	local pl, pb, pr = M.Rect(CreedUIPetBar)
	local bl, bb, br, bt = M.Rect(CreedUIBar)
	check(pb >= bt and pl < (bl + br) / 2, string.format("over the skill bar, on its left (%.0f over %.0f)", pb, bt))
	-- the game's own pet buttons, when it gives them
	M.petActions = { { name = "PET_ACTION_ATTACK", token = true, icon = "PET_ATTACK_TEXTURE", active = false },
		{ name = "Furious Howl", icon = I .. "Ability_Hunter_Pet_Wolf", autoAllowed = true, auto = true, cdStart = M.now, cdDur = 10 } }
	PET_ACTION_ATTACK, PET_ATTACK_TEXTURE = "Attack", "Interface\\Icons\\Ability_GhoulFrenzy"
	frames(10)
	check(countTex(CreedUIPetBar, "GhoulFrenzy$") == 1 and countTex(CreedUIPetBar, "Pet_Wolf$") == 1 and countTex(CreedUIPetBar, "SpiritWolf$") == 0,
		"the pet's own buttons replace the summons")
	local howl
	for _, o in ipairs(M.All()) do
		if o.__kind == "Texture" and o.__tex and string.find(o.__tex, "Pet_Wolf$") and under(o, CreedUIPetBar) then howl = o.__parent end
	end
	this, arg1 = howl, "LeftButton"
	howl.__scripts.OnClick()
	arg1 = "RightButton"
	howl.__scripts.OnClick()
	check(M.petCast[1] == "cast 2" and M.petCast[2] == "auto 2", "a click uses it, a right click switches its autocast: " .. table.concat(M.petCast, ", "))
	howl.__scripts.OnEnter()
	check(M.tip.shown and M.tip.petAction == 2, "pointing at it shows the game's tooltip")
	howl.__scripts.OnLeave()
	M.petActions, M.summons = nil, {}
	table.remove(M.meter.damage)
	frames(40)
	check(not M.Visible(CreedUIPetBar) or visibleAlpha(CreedUIPetBar) < 0.05, "and it goes when the pets do")
	-- a cache on the field wears a gold chest; taken, it fades
	AZS_CHESTS = { { id = 7, x = 100, y = 170, z = 0, mx = -1, my = -1 } }
	AZS_CHESTS_UPDATED = M.now
	frames(40)
	local chest
	for _, o in ipairs(M.All()) do
		if o.__kind == "Texture" and o.__tex and string.find(o.__tex, "Art\\Chest$") and not under(o, CreedUIChests) and not under(o, CreedUITally)
			and visibleAlpha(o) > 0.5 then chest = o end
	end
	check(chest ~= nil and chest.__vc and chest.__vc[3] < 0.6, "a gold chest over the cache in the world")
	AZS_CHESTS[1].taken = true
	frames(60)
	check(not chest or not M.Visible(chest) or visibleAlpha(chest) < 0.05, "taken, its chest fades")
	AZS_CHESTS = {}
	problems("pet bar and cache marks")
end

------------------------------------------------------------------ 11d. how many of a spell are out, on its slot
do
	SIM.StartRun("naxx", { killAfter = 60 })
	local saved1, saved2 = M.actions[1], M.actions[2]
	M.actions[1] = { tex = "Interface\\Icons\\Spell_Frost_IceStorm", start = 0, dur = 0 }
	M.actions[2] = { tex = "Interface\\Icons\\Spell_Fire_SearingTotem", start = 0, dur = 0 }
	frames(10)
	local function countOn(i)
		local want = M.actions[i].tex
		for _, o in ipairs(M.All()) do
			if o.__kind == "Texture" and o.__tex == want and under(o, CreedUIBar) then
				local b = o.__parent
				for _, f in ipairs(M.All()) do
					if f.__kind == "FontString" and f.__text and f.__text ~= "" and under(f, b) and string.find(f.__text, "^%d+$") and visibleAlpha(f) > 0.05 then
						return f.__text
					end
				end
				return nil
			end
		end
	end
	for k = 1, 3 do
		M.actions[1].start, M.actions[1].dur = M.now, 2
		frames(75) -- cast again as its two seconds of cooldown run out
	end
	check(countOn(1) == "3", "three Blizzards burning at once: " .. tostring(countOn(1)))
	M.actions[1].start, M.actions[1].dur = 0, 0
	frames(300)
	check(countOn(1) == nil, "and none once they've burned out: " .. tostring(countOn(1)))
	M.totems = { { key = "searing", name = "Searing Totem", icon = "Interface\\Icons\\Spell_Fire_SearingTotem", count = 2, cap = 3 } }
	frames(10)
	check(countOn(2) == "2", "the totems standing, by the game's count: " .. tostring(countOn(2)))
	M.totems = nil
	M.actions[1], M.actions[2] = saved1, saved2
	frames(10)
	problems("active counts")
end

------------------------------------------------------------------ 11e. damage numbers: four ways to move
do
	frames(200)
	local function track(motion, amount)
		CreedUIDB.numbers.motion = motion
		local e = M.Enemy("Dummy " .. motion, 3, 3)
		M.Hit(e, amount, "strike", false)
		local text = tostring(amount)
		local function at()
			for _, o in ipairs(M.All()) do
				if o.__kind == "FontString" and o.__text and under(o, CreedUINumbersLayer) and visibleAlpha(o) > 0.05 and M.Plain(o.__text) == text then
					local h = o.__parent
					while h and h.__parent ~= CreedUINumbersLayer do h = h.__parent end
					local l, b, r, t = M.Rect(h or o)
					return (l + r) / 2, (b + t) / 2
				end
			end
		end
		frames(2)
		local x0, y0 = at()
		frames(18)
		local x1, y1 = at()
		frames(120)
		if not (x0 and x1) then return 0, 0 end
		return x1 - x0, y1 - y0
	end
	local sx, sy = track("smooth", 431)
	local rx, ry = track("rise", 432)
	local fx, fy = track("fountain", 433)
	local ix, iy = track("impact", 434)
	check(sy > 2 and math.abs(sx) < 1, string.format("smooth: drifts up (%.1f, %.1f)", sx, sy))
	check(ry > sy * 2 and math.abs(rx) < 1, string.format("rise: climbs much faster (%.1f against %.1f)", ry, sy))
	check(math.abs(fx) > 15, string.format("fountain: arcs off to the side (%.1f, %.1f)", fx, fy))
	check(math.abs(iy) < 1 and math.abs(ix) < 1, string.format("impact: stays put (%.1f, %.1f)", ix, iy))
	M.Slash("numbers rise")
	check(CreedUIDB.numbers.motion == "rise", "/creed numbers rise picks it")
	CreedUIDB.numbers.motion = "smooth"
	problems("number motions")
end

------------------------------------------------------------------ 11f. the loot pop-up
do
	SIM.StartRun("naxx", { killAfter = 60 })
	frames(10)
	check(M.hud.loot == false, "the game's own loot pop-up is put away")
	local function toasts()
		local out = {}
		for _, o in ipairs(M.All()) do
			if o.__kind == "Frame" and o.__parent == CreedUILoot and M.Visible(o) and visibleAlpha(o) > 0.3 then table.insert(out, o) end
		end
		return out
	end
	check(table.getn(toasts()) == 0, "no pop-up before any loot")
	-- the game's line as it comes: a plain name in brackets, then whether it's new to the collection
	ChatFrame1:AddMessage("You receive loot: [Novice's Boots] New in your collection!")
	frames(10)
	check(table.getn(toasts()) == 1 and findText(CreedUILoot, "^Novice's Boots$") ~= nil and findText(CreedUILoot, "^New in your collection!$") ~= nil,
		"a drop pops up: its name and that it's new: " .. table.concat(textsUnder(CreedUILoot), " | "))
	check(countTex(CreedUILoot, "INV_Boots_01$") == 1 and countTex(CreedUILoot, "Art\\Slot$") == 1, "with an icon by what it is, in a metal slot")
	ChatFrame1:AddMessage("Du erhältst Beute: [Signet of the Fallen] Bereits gesammelt")
	M.items = { [16801] = { name = "Arcanist Belt", quality = 4, icon = "Interface\\Icons\\INV_Belt_30" } }
	ChatFrame1:AddMessage("You receive loot: |cffa335ee|Hitem:16801:0:0:0|h[Arcanist Belt]|h|r.")
	ChatFrame1:AddMessage("You earn 5 marks (120 in all).")
	frames(10)
	check(table.getn(toasts()) == 3, "three at most, the oldest gone: " .. table.getn(toasts()))
	check(findText(CreedUILoot, "^%+5 marks$") ~= nil and findText(CreedUILoot, "^120 in all$") ~= nil and countTex(CreedUILoot, "Token_ArgentDawn$") == 1,
		"marks earned pop up on an Argent Dawn token")
	check(findText(CreedUILoot, "^Already in your collection%.$") ~= nil and countTex(CreedUILoot, "INV_Belt_30$") == 1, "a ring you had, and a belt with its own icon")
	local belt
	for _, o in ipairs(M.All()) do
		if o.__kind == "FontString" and o.__text == "Arcanist Belt" and under(o, CreedUILoot) then belt = o end
	end
	check(belt and belt.__color and belt.__color[1] > 0.6 and belt.__color[3] > 0.9, "a name in its rarity's color (epic purple)")
	-- the newest lowest
	local marksY, beltY
	for _, f in ipairs(toasts()) do
		local _, _, _, top = M.Rect(f)
		for _, o in ipairs(M.All()) do
			if o.__kind == "FontString" and o.__parent == f and o.__text == "+5 marks" then marksY = top end
			if o.__kind == "FontString" and o.__parent == f and o.__text == "Arcanist Belt" then beltY = top end
		end
	end
	check(marksY and beltY and marksY < beltY, "the newest lowest, nearest the skill bar")
	-- each drop in its rarity's color, known by its set's or weapon's name (the line gives none)
	SIM.Advance(6, 1 / 30)
	ChatFrame1:AddMessage("You receive loot: [Dreadmist Mantle] New in your collection!")
	ChatFrame1:AddMessage("You receive loot: [Deathmist Robe] New in your collection!")
	ChatFrame1:AddMessage("You receive loot: [Ashbringer] New in your collection!")
	frames(10)
	local function colorOf(text)
		for _, o in ipairs(M.All()) do
			if o.__kind == "FontString" and o.__text == text and under(o, CreedUILoot) then return o.__color end
		end
	end
	local g, b, o = colorOf("Dreadmist Mantle"), colorOf("Deathmist Robe"), colorOf("Ashbringer")
	check(g and g[2] > 0.9 and g[1] < 0.3, "Dreadmist (Uncommon) in green")
	check(b and b[1] > 0.6 and b[3] > 0.9 and b[2] < 0.3, "Deathmist (Tier 0.5) in purple, as the game shows it")
	check(o and o[1] > 0.9 and o[2] > 0.4 and o[2] < 0.6 and o[3] < 0.1, "Ashbringer (Legendary) in orange")
	ChatFrame1:AddMessage("You receive loot: [Plagueheart Robe] New in your collection!")
	frames(10)
	local p = colorOf("Plagueheart Robe")
	check(p and p[1] > 0.6 and p[3] > 0.9 and p[2] < 0.3, "the top sets' armor (Plagueheart) in purple, as in game; only their weapons orange")
	ChatFrame1:AddMessage("Melkor says: You receive loot: nothing, haha")
	frames(5)
	check(findText(CreedUILoot, "nothing") == nil, "someone saying the words in chat isn't loot")
	SIM.Advance(6, 1 / 30)
	check(table.getn(toasts()) == 0, "a few seconds on, they melt away")
	M.Slash("loot off")
	frames(5)
	check(M.hud.loot ~= false, "turned off, the game's own pop-up comes back")
	M.Slash("loot on")
	frames(5)
	problems("loot")
end

------------------------------------------------------------------ 11g. the chat and the hero's numbers, moved and sized
do
	frames(5)
	local chat = ChatFrame1
	local l0, b0 = chat:GetLeft(), chat:GetBottom()
	local w0 = chat:GetWidth()
	check(not M.Visible(CreedUIChatMover), "no chat box while the frames are locked")
	CreedUI.SetUnlocked(true)
	frames(3)
	check(M.Visible(CreedUIChatMover), "unlocked: a Chat box over the chat")
	M.dragBy = { 60, 40 }
	this = CreedUIChatMover
	CreedUIChatMover.__scripts.OnDragStart()
	CreedUIChatMover.__scripts.OnDragStop()
	M.dragBy = nil
	check(math.abs(chat:GetLeft() - (l0 + 60)) < 1 and math.abs(chat:GetBottom() - (b0 + 40)) < 1,
		string.format("dragging moves the chat (%.0f,%.0f -> %.0f,%.0f)", l0, b0, chat:GetLeft(), chat:GetBottom()))
	this = CreedUIChatGrip
	CreedUIChatGrip.__scripts.OnMouseDown()
	chat:SetWidth(w0 + 90)
	CreedUIChatGrip.__scripts.OnMouseUp()
	check(CreedUIDB.chat.place and math.abs(CreedUIDB.chat.place.w - (w0 + 90)) < 1, "its corner sizes it, and the size is kept")
	M.Reload(DIR, true)
	frames(5)
	check(math.abs(ChatFrame1:GetLeft() - (l0 + 60)) < 1 and math.abs(ChatFrame1:GetWidth() - (w0 + 90)) < 1, "both kept over a reload")
	-- the hero's numbers have a spot to drag too
	check(CreedUIHurtSpot ~= nil, "the damage taken numbers have a spot")
	CreedUI.SetUnlocked(true)
	frames(2)
	local boxes = 0
	for _, o in ipairs(M.All()) do
		if o.__kind == "Frame" and o.__parent == CreedUIHurtSpot and o.__backdrop and M.Visible(o) then boxes = boxes + 1 end
	end
	check(boxes == 1, "shown as a box to drag while unlocked")
	CreedUI.ResetPositions()
	frames(3)
	check(CreedUIDB.chat.place == nil and math.abs(ChatFrame1:GetLeft() - l0) < 1, "resetting the frames puts the chat back")
	CreedUI.SetUnlocked(false)
	frames(2)
	problems("chat moved")
end

------------------------------------------------------------------ 11h. damage numbers: crit backdrops and Creed UI's own fonts
do
	frames(200)
	local function backs(name)
		local n = 0
		for _, o in ipairs(M.All()) do
			if o.__kind == "Texture" and o.__tex and string.find(o.__tex, name .. "$") and under(o, CreedUINumbersLayer) and M.Visible(o) and visibleAlpha(o) > 0.05 then n = n + 1 end
		end
		return n
	end
	M.Slash("numbers backdrop fire")
	check(CreedUIDB.numbers.backdrop == "fire", "/creed numbers backdrop fire picks it")
	local e = M.Enemy("Crit dummy", 3, 3)
	M.Hit(e, 4321, "strike", false, true)
	local e2 = M.Enemy("Plain dummy", -3, -3)
	M.Hit(e2, 1234, "strike", false, false)
	frames(6)
	check(backs("Art\\NumFlame") == 1, "a crit wears the fire burst, a plain hit doesn't: " .. backs("Art\\NumFlame"))
	CreedUIDB.numbers.backdrop = "frost"
	local e3 = M.Enemy("Crit dummy 2", 5, -2)
	M.Hit(e3, 999, "strike", false, true)
	frames(6)
	check(backs("Art\\NumFrost") >= 1, "another backdrop: the ice star")
	CreedUIDB.numbers.backdrop = "none"
	frames(6)
	check(backs("Art\\NumFrost") == 0 and backs("Art\\NumFlame") == 0, "None: no backdrop")
	-- the burst: it swells past its size in a sixth of a second, then settles
	frames(150) -- the earlier numbers gone
	local function backW(name)
		for _, o in ipairs(M.All()) do
			if o.__kind == "Texture" and o.__tex and string.find(o.__tex, name .. "$") and under(o, CreedUINumbersLayer) and M.Visible(o) then return o.__w end
		end
	end
	CreedUIDB.numbers.backdrop = "storm"
	local e5 = M.Enemy("Crit dummy 3", -4, 1)
	M.Hit(e5, 2468, "strike", false, true)
	frames(2)
	local early = backW("Art\\NumStorm")
	frames(4)
	local peak = backW("Art\\NumStorm")
	frames(12)
	local settled = backW("Art\\NumStorm")
	check(early and peak and settled and early < peak and settled < peak,
		string.format("the backdrop bursts in and settles (%s, %s, %s)", tostring(early), tostring(peak), tostring(settled)))
	CreedUIDB.numbers.backdrop = "blood" -- a choice from before 1.20.4: gone, so none
	M.Reload(DIR, true)
	frames(3)
	check(CreedUIDB.numbers.backdrop == "none", "a saved Blood backdrop (removed) falls back to none")
	-- a font of Creed UI's own, from the addon's folder
	local was = CreedUIDB.numbers.font
	M.Slash("numbers font cinzel")
	check(CreedUIDB.numbers.font == 5, "/creed numbers font cinzel picks it")
	local e4 = M.Enemy("Font dummy", 1, 6)
	M.Hit(e4, 777, "strike", false, false)
	frames(20)
	local face
	for _, o in ipairs(M.All()) do
		if o.__kind == "FontString" and o.__text and string.find(M.Plain(o.__text), "%d") and under(o, CreedUINumbersLayer)
			and M.Visible(o) and visibleAlpha(o) > 0.05 then face = o.__font end
	end
	check(face and string.find(face, "NumCinzel%.ttf$"), "a number in Creed UI's own font (Cinzel): " .. tostring(face))
	CreedUIDB.numbers.font = was
	frames(100)
	problems("crit backdrops and fonts")
end

------------------------------------------------------------------ 12. no API at all
M.RemoveAPI()
AZS_TARGET = nil
M.Reload(DIR, false)
frames(60)
problems("no api")
M.InstallAPI()

print(string.format("%d passed, %d failed", passes, table.getn(failures)))
for i = 1, table.getn(M.chat) do
	if string.find(M.chat[i], "error") or string.find(M.chat[i], "problem") or string.find(M.chat[i], "stopped") then print("CHAT: " .. M.chat[i]) end
end
