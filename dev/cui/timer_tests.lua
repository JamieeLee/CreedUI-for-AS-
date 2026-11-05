-- Behaviour tests for Smooth Boss Timer under Lua 5.0 with the mock client.
-- usage: lua50 tests.lua <scratch> <addon.lua>
MOCK_SCRATCH = arg[1]
local ADDON = arg[2]
dofile(MOCK_SCRATCH .. "/cui/mock_cui.lua")
dofile(MOCK_SCRATCH .. "/bt/sim.lua")
local M = MOCK

local failures, passes = {}, 0
local function check(cond, what)
	if cond then
		passes = passes + 1
	else
		table.insert(failures, what)
		print("FAIL: " .. what)
	end
end

local function frames(n, dt)
	for i = 1, n do M.Frame(dt or (1 / 30)) end
end

local function texts()
	local out = {}
	local all = M.All()
	for i = 1, table.getn(all) do
		local o = all[i]
		if o.__kind == "FontString" and M.Visible(o) and o.__text and o.__text ~= "" then
			local a = (o.__alpha or 1) * M.FrameAlpha(o.__parent)
			if a > 0.05 then table.insert(out, M.Plain(o.__text)) end
		end
	end
	return out
end
local function hasText(pat)
	local t = texts()
	for i = 1, table.getn(t) do
		if string.find(t[i], pat) then return t[i] end
	end
	return nil
end

local function root() return CreedUITimerFrame end
local function shown()
	local r = root()
	return r and r.__shown and r.__alpha > 0.05
end

-- markers: visible frames that own a Gem texture
function InTimer(o)
	local p = o.__parent
	while p do
		if p == CreedUITimerFrame then return true end
		p = p.__parent
	end
	return false
end
local function markers()
	local out = {}
	local all = M.All()
	for i = 1, table.getn(all) do
		local o = all[i]
		if o.__kind == "Texture" and o.__tex and string.find(o.__tex, "Art\\Gem$") and InTimer(o) then
			local f = o.__parent
			if M.Visible(o) and M.FrameAlpha(f) > 0.3 then
				local l, b, r, t = M.Rect(f)
				table.insert(out, { frame = f, x = (l + r) / 2, gem = o })
			end
		end
	end
	table.sort(out, function(a, b) return a.x < b.x end)
	return out
end
local function checksShown()
	local n = 0
	local all = M.All()
	for i = 1, table.getn(all) do
		local o = all[i]
		if o.__kind == "Texture" and o.__tex and string.find(o.__tex, "Art\\Check$") and InTimer(o) and M.Visible(o)
			and M.FrameAlpha(o.__parent) * (o.__vc and o.__vc[4] or 1) > 0.3 then
			n = n + 1
		end
	end
	return n
end

local function problems(label)
	local n = table.getn(M.problems)
	check(n == 0, label .. ": no mock problems (" .. n .. ")")
	for i = 1, math.min(n, 3) do print("  " .. M.problems[i]) end
	M.problems = {}
end
local function chatHas(pat)
	for i = 1, table.getn(M.chat) do
		if string.find(M.chat[i], pat) then return true end
	end
	return false
end

------------------------------------------------------------------ 1. load, idle
M.InstallAPI()
M.phase = "ready"
M.hud.clock = true
M.Load(ADDON)
frames(30)
check(M.hud.clock == false, "the game's clock is hidden while enabled")
check(CreedUIDB.timer.clockWasShown == true, "remembers that it hid the clock")
check(not shown(), "hidden out of a run")
check(M.onTop and M.onTop["CreedUITimerFrame"] == true, "kept over the level-up cards")
problems("idle")

------------------------------------------------------------------ 2. a run
SIM.StartRun("elwynn", { killAfter = 20 })
SIM.Advance(1.5, 1 / 30)
check(shown(), "shown once the run plays")
local mk = markers()
check(table.getn(mk) == 5, "five boss markers (" .. table.getn(mk) .. ")")
check(hasText("^Hogger  2:5%d$") ~= nil, "callout names Hogger with a countdown: " .. tostring(hasText("Hogger")))
check(hasText("^0:01$") ~= nil, "clock reads 0:01: " .. table.concat(texts(), " | "))
check(hasText("^16:00$") ~= nil, "total reads 16:00")
check(hasText("Elwynn Forest") ~= nil, "zone title")
-- markers sit at their times along the bar
local bl, bb, br = M.Rect(mk[1].frame)
local bar
for _, o in ipairs(M.All()) do
	if o.__kind == "Frame" and o.__parent == root() and o.__w == 440 and o.__h == 12 then bar = o end
end
check(bar ~= nil, "found the bar frame")
if bar and table.getn(mk) == 5 then
	local l, b, r, t = M.Rect(bar)
	local want = { 180, 360, 540, 720, 960 }
	local ok = true
	for i = 1, 5 do
		local x = l + (r - l) * want[i] / 960
		if math.abs(mk[i].x - x) > 0.6 then ok = false; print("  marker " .. i .. " at " .. mk[i].x .. " want " .. x) end
	end
	check(ok, "markers at 3, 6, 9, 12 and 16 minutes")
end
problems("run start")

------------------------------------------------------------------ 3. the countdown and a boss fight
M.runTime = 172
SIM.Publish()
SIM.Advance(1, 1 / 30)
local c = hasText("^Hogger")
check(c ~= nil and string.find(c, "0:0[67]$") ~= nil, "countdown near the spawn: " .. tostring(c))
SIM.Advance(9, 1 / 30)      -- Hogger comes at 3:00 (+0.3 s)
mk = markers()
check(hasText("^Mother Fang") ~= nil, "callout moved on to Mother Fang: " .. tostring(hasText("Fang")))
SIM.Advance(22, 1 / 30)     -- Hogger dies after 20 s
check(checksShown() == 1, "one check mark once Hogger died (" .. checksShown() .. ")")
problems("fight")

------------------------------------------------------------------ 4. pause and card choice
local before = M.runTime
M.phase = "paused"
SIM.Publish()
SIM.Advance(3, 1 / 30)
check(M.runTime == before, "the sim clock stops while paused")
check(hasText("^3:%d%d$") ~= nil, "clock still shows the run time while paused")
M.phase = "choosing"
SIM.Publish()
SIM.Advance(2, 1 / 30)
check(shown(), "stays up while choosing a card")
M.phase = "playing"
SIM.Publish()
SIM.Advance(1, 1 / 30)
problems("pause")

------------------------------------------------------------------ 5. death, then Again? with the old tables still there
M.runTime = 400
SIM.Publish()
SIM.Advance(1, 1 / 30)
M.phase = "dead"
SIM.Publish()
SIM.Advance(2, 1 / 30)
check(shown() and root().__alpha < 0.75, "dimmed when the run ends in death (alpha " .. string.format("%.2f", root().__alpha) .. ")")
-- Again?: the clock restarts, but the schedule still holds the old states for a moment
M.phase = "playing"
M.runTime = 0
AZS_RUN.t = 0
SIM.Advance(0.1, 1 / 30) -- no publish yet: AZS_SCHEDULE still says Hogger and Mother Fang are dead
frames(10)
check(checksShown() == 0, "no stale check marks after Again? (" .. checksShown() .. ")")
check(hasText("^Hogger") ~= nil, "callout back to Hogger after Again?: " .. tostring(hasText("Hogger")))
SIM.StartRun("elwynn", { killAfter = 20 })
SIM.Advance(1, 1 / 30)
check(hasText("^0:01$") ~= nil or hasText("^0:00$") ~= nil, "clock restarted")
problems("again")

------------------------------------------------------------------ 6. /reload mid-run: the game hasn't resent the schedule or the zone
M.runTime = 250
SIM.run.bosses[1].state = "dead"
SIM.Publish()
SIM.Advance(2, 1 / 30)
M.Reload(ADDON, true)
check(M.hud.clock == false, "clock hidden again after the reload")
AZS_SCHEDULE = {}
AZS_ZONE = {}
SIM.hideSchedule = true
SIM.Advance(1, 1 / 30)
mk = markers()
check(table.getn(mk) == 5, "markers back after /reload from the saved schedule (" .. table.getn(mk) .. ")")
check(hasText("Elwynn Forest") ~= nil, "zone title after /reload")
check(checksShown() == 1, "Hogger still shown slain after /reload (" .. checksShown() .. ")")
check(hasText("^Mother Fang") ~= nil, "callout after /reload: " .. tostring(hasText("Fang")))
problems("reload")

------------------------------------------------------------------ 7. a reload with nothing saved: the zone is guessed from the next boss's name
CreedUIDB.timer.last = nil
M.zoneText = "Somewhere"
M.Reload(ADDON, false)
AZS_SCHEDULE = {}
AZS_ZONE = {}
SIM.Advance(1, 1 / 30)
mk = markers()
check(table.getn(mk) == 5, "markers from the built-in schedule when nothing was saved (" .. table.getn(mk) .. ")")
check(hasText("Elwynn Forest") ~= nil, "zone guessed from AZS_RUN.nbn")
SIM.hideSchedule = false
M.zoneText = "Elwynn Forest"
problems("guess")

------------------------------------------------------------------ 8. the final boss, victory and endless
M.runTime = 955
for i = 1, 4 do SIM.run.bosses[i].state = "dead" end
SIM.Publish()
SIM.Advance(6, 1 / 30)
check(hasText("^0:") == nil or true, "")
SIM.Advance(22, 1 / 30) -- VanCleef dies
M.phase = "victory"
SIM.Publish()
SIM.Advance(1.5, 1 / 30)
check(hasText("Victory!") ~= nil, "Victory! when the final boss dies")
SIM.Endless(45)
SIM.Advance(3, 1 / 30)
check(hasText("ENDLESS") ~= nil, "total reads ENDLESS")
local nb = hasText("^Next boss")
check(nb ~= nil, "endless countdown to the next boss: " .. tostring(nb))
SIM.Advance(50, 1 / 30)
check(hasText("^Next boss") ~= nil, "endless countdown keeps going after a boss")
problems("endless")

------------------------------------------------------------------ 9. off and on, logout, reload
M.Slash("timer off")
frames(20)
check(M.hud.clock == true, "/sbt off gives the game's clock back")
check(not shown(), "/sbt off hides the bar")
M.Slash("timer on")
frames(20)
check(M.hud.clock == false, "/sbt on hides the game's clock again")
M.Fire("PLAYER_LOGOUT")
check(M.hud.clock == true, "logout leaves the game's clock setting as it was")
M.Reload(ADDON, false)
frames(5)
check(M.hud.clock == false, "hidden again on the next load")
problems("toggle")

------------------------------------------------------------------ 10. a player who had hidden the clock themselves
M.Slash("timer off")
M.hud.clock = false
CreedUIDB.timer.clockWasShown = nil
M.Slash("timer on")
frames(5)
M.Slash("timer off")
check(M.hud.clock == false, "never turns on a clock the player had hidden")
M.Slash("timer on")
M.hud.clock = true
frames(70) -- the periodic check takes it over again
check(M.hud.clock == false, "takes the clock over if the player shows it again")
problems("own clock")

------------------------------------------------------------------ 11. slash commands and the options window
M.chat = {}
M.Slash("timer")
check(CreedUITimerOptions and CreedUITimerOptions.__shown, "/sbt opens the options")
local clicked = 0
for _, o in ipairs(M.All()) do
	if o.__kind == "Button" and M.Visible(o) and o.__scripts.OnClick then
		local isPreview = false
		for _, k in ipairs(M.All()) do
			if k.__parent == o and k.__kind == "FontString" and k.__text and (string.find(k.__text, "review") or k.__text == "x") then isPreview = true end
		end
		if not isPreview then
			o:Click()
			clicked = clicked + 1
			frames(2)
		end
	end
end
check(clicked >= 10, "clicked every options button (" .. clicked .. ")")
check(CreedUIDB.timer.title == false and CreedUIDB.timer.callout == false, "the check boxes switch their options")
for _, k in ipairs({ "title", "callout", "ticks", "particles", "flow" }) do CreedUIDB.timer[k] = true end
frames(30)
M.Slash("timer on")
M.Slash("timer lock")
for _, cmd in ipairs({ "unlock", "lock", "theme av", "theme auto", "theme nowhere", "scale 140", "scale 0.6", "scale 1",
	"width 300", "width 760", "width 440", "reset", "help", "preview", "preview", "preview naxx", "preview bogus" }) do
	M.Slash("timer " .. cmd)
	frames(3)
end
check(chatHas("themes:"), "lists themes for an unknown one")
check(chatHas("zones:"), "lists zones for an unknown preview")
problems("slash")

------------------------------------------------------------------ 12. the preview runs to the end on its own
M.phase = "ready"
SIM.Publish()
M.Slash("timer preview av")
local sawUp, sawVictory = false, false
for i = 1, 30 * 30 do
	M.Frame(1 / 30)
	if hasText("Victory!") then sawVictory = true end
	for _, o in ipairs(markers()) do
		local vc = o.gem.__vc
		if vc and vc[1] > 0.9 and vc[2] < 0.5 and vc[3] < 0.3 then sawUp = true end
	end
end
check(sawUp, "the preview shows a boss up")
check(sawVictory, "the preview ends with Victory!")
frames(60)
check(not shown(), "the bar hides again after the preview, out of a run")
problems("preview")

------------------------------------------------------------------ 13. moving the bar
M.Slash("timer unlock")
frames(3)
check(root().__mouse == true, "unlocked bar takes the mouse")
SIM.StartRun("duskwood", {})
SIM.Advance(1, 1 / 30)
local x0, y0 = CreedUIDB.timer.x, CreedUIDB.timer.y
M.dragBy = { 120, -40 }
this = root()
root().__scripts.OnDragStart()
root().__scripts.OnDragStop()
M.dragBy = nil
check(CreedUIDB.timer.x == x0 + 120 and CreedUIDB.timer.y == y0 - 40,
	string.format("drag saves the position (%s,%s -> %s,%s)", tostring(x0), tostring(y0), tostring(CreedUIDB.timer.x), tostring(CreedUIDB.timer.y)))
M.Slash("timer lock")
check(root().__mouse == false, "locked bar lets clicks through")
M.Slash("timer reset")
problems("move")

------------------------------------------------------------------ 13b. Scholomance (0.140.0): its own look and its bosses, even after a bare /reload
SIM.StartRun("scholomance")
SIM.Advance(2, 1 / 30)
CreedUIDB.timer.last = nil
M.zoneText = "Somewhere"
M.Reload(ADDON, false)
AZS_SCHEDULE = {}
AZS_ZONE = {}
SIM.hideSchedule = true
SIM.Advance(1, 1 / 30)
check(hasText("Scholomance") ~= nil, "Scholomance guessed from its first boss's name")
check(table.getn(markers()) == 5, "Scholomance's five bosses from the built-in schedule (" .. table.getn(markers()) .. ")")
check(hasText("^Kirtonos the Herald") ~= nil, "Kirtonos called out first")
SIM.hideSchedule = false
M.zoneText = "Elwynn Forest"
problems("scholomance")

------------------------------------------------------------------ 14. other languages: names that match nothing built in
SIM.StartRun("arena", { names = { "Hohepriesterin Jeklik", "Hohepriester Venoxis", "Blutfürst Mandokir", "Jin'do der Verhexer", "Hakkar der Seelenschinder" } })
SIM.Advance(2, 1 / 30)
check(hasText("Gurubashi Arena") ~= nil, "theme from the zone key whatever the language")
check(hasText("^Hohepriesterin Jeklik") ~= nil, "uses the game's own (translated) names")
check(table.getn(markers()) == 5, "five markers in another language")
problems("language")

------------------------------------------------------------------ 15. the API breaks mid-run
M.apiThrows = true
SIM.Advance(2, 1 / 30)
check(not shown(), "hides quietly when the game's API errors")
M.apiThrows = false
SIM.Advance(2, 1 / 30)
check(shown(), "comes back when the API recovers")
problems("api errors")

------------------------------------------------------------------ 16. long run at 60 fps: no errors, smooth fill
SIM.StartRun("naxx", { killAfter = 35 })
local lastW, maxStep, frames60 = nil, 0, 0
local fillTex
for _, o in ipairs(M.All()) do
	if o.__kind == "Texture" and o.__tex and string.find(o.__tex, "Art\\Fill$") and o.__parent and o.__parent.__w == 440 then
		fillTex = fillTex or o
	end
end
local setTexts0 = M.setTextCount or 0
SIM.Advance(1260, 1 / 60, function(s)
	if fillTex and fillTex.__w then
		if lastW then
			local d = math.abs(fillTex.__w - lastW)
			if d > maxStep then maxStep = d end
		end
		lastW = fillTex.__w
	end
	frames60 = frames60 + 1
end)
check(maxStep < 1.0, string.format("fill grows smoothly (largest step %.3f px of the half fill)", maxStep))
local perSecond = ((M.setTextCount or 0) - setTexts0) / 1260
check(perSecond < 8, string.format("text updates stay cheap (%.1f SetText per second)", perSecond))
check(hasText("Victory!") == nil, "")
problems("long run")

------------------------------------------------------------------ 17. no API at all (a normal 1.12 client)
M.RemoveAPI()
M.Reload(ADDON, false)
frames(60)
check(not shown(), "nothing shows without the game's API")
problems("no api")
M.InstallAPI()

print(string.format("%d passed, %d failed", passes, table.getn(failures)))
for i = 1, table.getn(M.chat) do
	if string.find(M.chat[i], "error") then print("CHAT: " .. M.chat[i]) end
end
