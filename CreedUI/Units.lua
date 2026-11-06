-- Creed UI: your frame and your target's, in the boss timer's style, with the real health
-- numbers. Your frame shows your shield, your energy, mana or rage, your class's meter (combo
-- points, soul shards...) and your extra lives. While these are on, the game's PlayerFrame and
-- TargetFrame are tucked away; turning a part off brings its frame back.

local C = CreedUI
local DEFAULTS = { player = true, target = true, playerScale = 1, targetScale = 1 }
local W, H = 300, 74
local HP_W, HP_H = 200, 14
local RES_H = 8
local BAR_X = 88

local db
local P, T -- the two frames

local HP_COLORS = {
	{ 0.04, 0.28, 0.07 }, { 0.14, 0.62, 0.18 }, { 0.58, 0.96, 0.36 },
}
local LOW_COLORS = {
	{ 0.36, 0.04, 0.02 }, { 0.80, 0.16, 0.06 }, { 1.00, 0.52, 0.20 },
}
local ENEMY_COLORS = {
	{ 0.30, 0.02, 0.02 }, { 0.72, 0.05, 0.04 }, { 1.00, 0.30, 0.14 },
}
local POWER_COLORS = {
	[0] = { { 0.03, 0.10, 0.36 }, { 0.10, 0.34, 0.86 }, { 0.48, 0.74, 1.00 } }, -- mana
	[1] = { { 0.34, 0.02, 0.02 }, { 0.76, 0.08, 0.06 }, { 1.00, 0.38, 0.26 } }, -- rage
	[2] = { { 0.36, 0.16, 0.02 }, { 0.84, 0.44, 0.08 }, { 1.00, 0.72, 0.32 } }, -- focus
	[3] = { { 0.40, 0.33, 0.02 }, { 0.86, 0.74, 0.10 }, { 1.00, 0.96, 0.46 } }, -- energy
}
local KIND_TAGS = {
	final = { "Final boss", 1, 0.32, 0.22 }, boss = { "Boss", 1, 0.32, 0.22 },
	guardian = { "Guardian", 1, 0.72, 0.30 }, elite = { "Elite", 1, 0.84, 0.36 },
}
local ENEMY_KINDS = { final = true, boss = true, guardian = true, elite = true, normal = true }

local Call = C.Call -- no stray nil arguments (see Core)

local function HPText(hp, hpm)
	if hpm >= 100000 then return C.Short(hp) .. " / " .. C.Short(hpm) end
	return C.Commas(hp) .. " / " .. C.Commas(hpm)
end

local function Mix(a, b, t, out)
	out[1] = a[1] + (b[1] - a[1]) * t
	out[2] = a[2] + (b[2] - a[2]) * t
	out[3] = a[3] + (b[3] - a[3]) * t
	return out
end

------------------------------------------------------------------------ building a frame
local function Build(name, key, label, default, isPlayer)
	local u = { isPlayer = isPlayer, alpha = isPlayer and 1 or 0, low = 0, colA = { 0, 0, 0 }, colM = { 0, 0, 0 }, colB = { 0, 0, 0 } }
	local f = CreateFrame("Frame", name, UIParent)
	u.root = f
	f:SetWidth(W)
	f:SetHeight(H)
	f:SetFrameStrata("LOW")

	-- portrait in a metal ring, with the level on a badge
	u.face = CreateFrame("Frame", nil, f)
	u.face:SetWidth(66)
	u.face:SetHeight(66)
	u.face:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -4)
	u.faceBg = C.Tex(u.face, "BACKGROUND", C.ART .. "Badge")
	u.faceBg:SetWidth(60)
	u.faceBg:SetHeight(60)
	u.faceBg:SetPoint("CENTER", u.face, "CENTER", 0, 0)
	u.portrait = u.face:CreateTexture(nil, "BORDER")
	u.portrait:SetWidth(54)
	u.portrait:SetHeight(54)
	u.portrait:SetPoint("CENTER", u.face, "CENTER", 0, 0)
	u.faceTop = CreateFrame("Frame", nil, u.face)
	u.faceTop:SetAllPoints(u.face)
	u.ring = C.Tex(u.faceTop, "ARTWORK", C.ART .. "Portrait")
	u.ring:SetAllPoints(u.face)
	u.badge = C.Tex(u.faceTop, "OVERLAY", C.ART .. "Badge")
	u.badge:SetWidth(24)
	u.badge:SetHeight(24)
	u.badge:SetPoint("CENTER", u.face, "BOTTOMLEFT", 10, 10)
	u.levelTop = CreateFrame("Frame", nil, u.faceTop)
	u.levelTop:SetAllPoints(u.face)
	u.level = C.Text(u.levelTop, C.FONT, 11, "OUTLINE", "CENTER", 40)
	u.level:SetPoint("CENTER", u.badge, "CENTER", 0, 0)

	-- health
	u.hp = C.NewBar(f, HP_W, HP_H, true)
	u.hp.frame:SetPoint("TOPLEFT", f, "TOPLEFT", BAR_X, -26)
	u.hpText = C.Text(u.hp.top, C.FONT, 11, "OUTLINE", "CENTER", HP_W + 40)
	u.hpText:SetPoint("CENTER", u.hp.frame, "CENTER", 0, 0)
	u.name = C.Text(u.hp.top, C.FONT, 13, "OUTLINE", "LEFT", HP_W)
	u.name:SetPoint("BOTTOMLEFT", u.hp.frame, "TOPLEFT", 4, 6)
	u.tag = C.Text(u.hp.top, C.FONT, 11, "OUTLINE", "RIGHT", 120)
	u.tag:SetPoint("BOTTOMRIGHT", u.hp.frame, "TOPRIGHT", -2, 6)

	if isPlayer then
		u.res = C.NewBar(f, HP_W - 24, RES_H, false)
		u.res.frame:SetPoint("TOPLEFT", u.hp.frame, "BOTTOMLEFT", 0, -9)
		u.resText = C.Text(u.res.top, C.FONT, 9, "OUTLINE", "CENTER", HP_W)
		u.resText:SetPoint("CENTER", u.res.frame, "CENTER", 0, 0)
		-- the class meter: up to six gems under the bars
		u.pipFrame = CreateFrame("Frame", nil, f)
		u.pipFrame:SetAllPoints(f)
		u.pips = {}
		for i = 1, 6 do
			local p = C.Tex(u.pipFrame, "ARTWORK", C.ART .. "Diamond")
			p:SetWidth(14)
			p:SetHeight(14)
			p:SetPoint("CENTER", u.res.frame, "BOTTOMLEFT", 7 + (i - 1) * 16, -11)
			u.pips[i] = { tex = p, lit = 0 }
		end
		u.pipText = C.Text(u.pipFrame, C.FONT, 10, "OUTLINE", "LEFT", 140)
		u.pipText:SetPoint("LEFT", u.res.frame, "BOTTOMLEFT", 0, -10)
		-- extra lives, beside the name
		u.lifeGem = C.Tex(u.pipFrame, "ARTWORK", C.ART .. "Gem")
		u.lifeGem:SetWidth(14)
		u.lifeGem:SetHeight(14)
		u.lifeText = C.Text(u.hp.top, C.FONT, 11, "OUTLINE", "LEFT", 40)
	end

	f:Hide()
	u.mover = C.Movable(f, key, label, default)
	return u
end

local function Levels(u)
	local base = u.root:GetFrameLevel()
	u.face:SetFrameLevel(base + 1)
	u.faceTop:SetFrameLevel(base + 3)
	u.levelTop:SetFrameLevel(base + 4)
	C.BarLevels(u.hp, base + 1)
	if u.res then
		C.BarLevels(u.res, base + 1)
		u.pipFrame:SetFrameLevel(base + 5)
	end
end

------------------------------------------------------------------------ your frame
local function StepPlayer(u, dt, now, pal)
	local run = type(AZS_RUN) == "table" and AZS_RUN or {}
	local phase = Call(AZS_GetPhase)
	local inRun = phase == "playing" or phase == "choosing" or phase == "paused" or phase == "dead" or phase == "victory"
	local hp, hpm = Call(UnitHealth, "player") or 0, Call(UnitHealthMax, "player") or 0
	if inRun and tonumber(run.hpm) and run.hpm > 0 and (hpm <= 1 or math.abs(run.hpm - hpm) > 1) then
		hp, hpm = tonumber(run.hp) or hp, run.hpm
	end
	if hpm <= 0 then hpm = 1 end
	local frac = C.Clamp(hp / hpm, 0, 1)
	local sh = inRun and tonumber(run.sh) or 0
	u.hp.shield = (sh and sh > 0) and sh / hpm or 0
	C.BarStep(u.hp, frac, dt, now)

	-- health turns hot and pulses when it runs low
	local lowT = frac < 0.3 and 1 or 0
	u.low = C.Toward(u.low, lowT, 3, dt)
	if u.low > 0.002 or not u.colorsDone then
		u.colorsDone = true
		local t = u.low * (0.8 + 0.2 * math.sin(now * 5))
		C.BarColors(u.hp, Mix(HP_COLORS[1], LOW_COLORS[1], t, u.colA), Mix(HP_COLORS[2], LOW_COLORS[2], t, u.colM),
			Mix(HP_COLORS[3], LOW_COLORS[3], t, u.colB))
	end
	local text = HPText(math.floor(hp + 0.5), math.floor(hpm + 0.5))
	if sh and sh > 0 then text = text .. "  |cffbde6ff+" .. C.Short(sh) .. "|r" end
	C.SetText(u.hpText, text)

	-- energy, mana or rage
	local power = Call(UnitPowerType, "player") or 0
	local mp, mpm = Call(UnitMana, "player") or 0, Call(UnitManaMax, "player") or 0
	if u.power ~= power then
		u.power = power
		local cols = POWER_COLORS[power] or POWER_COLORS[0]
		C.BarColors(u.res, cols[1], cols[2], cols[3])
	end
	if mpm > 0 then
		C.BarStep(u.res, mp / mpm, dt, now)
		C.SetText(u.resText, math.floor(mp + 0.5) .. " / " .. math.floor(mpm + 0.5))
		C.Vis(u.res.frame, true)
	else
		C.Vis(u.res.frame, false)
	end

	-- the class meter
	local proc, pv, pm = run.proc, tonumber(run.pv) or 0, tonumber(run.pm) or 0
	local pipsShown = 0
	if inRun and type(proc) == "string" and proc ~= "" and pm > 0 and pm <= 6 then pipsShown = math.floor(pm + 0.5) end
	local gem, glow = pal.gem, pal.glow
	for i = 1, 6 do
		local p = u.pips[i]
		local on = i <= pipsShown
		p.lit = C.Toward(p.lit, (on and pv >= i) and 1 or 0, 10, dt)
		if on then
			local l = p.lit
			C.Color(p.tex, 0.22 + (1 - 0.22) * l, 0.22 + (0.78 - 0.22) * l, 0.24 + (0.30 - 0.24) * l, 0.6 + 0.4 * l)
			local s = 12 + 4 * l
			C.Size(p.tex, s, s)
		end
		C.Vis(p.tex, on)
	end
	if inRun and pipsShown == 0 and type(proc) == "string" and proc ~= "" and pm > 0 then
		C.SetText(u.pipText, string.format("%d%%", math.floor(pv / pm * 100 + 0.5)))
		C.TextColor(u.pipText, glow[1], glow[2], glow[3])
		C.Vis(u.pipText, true)
	else
		C.Vis(u.pipText, false)
	end

	-- name, level and lives
	local name = Call(UnitName, "player") or C.L("You")
	C.SetText(u.name, name)
	local t = pal.title
	C.TextColor(u.name, t[1], t[2], t[3])
	local level = (inRun and tonumber(run.lvl)) or Call(UnitLevel, "player") or 1
	C.SetText(u.level, tostring(level))
	local lives = inRun and tonumber(run.lives) or 0
	if lives and lives > 0 then
		local nw = C.TextWidth(u.name)
		C.Place(u.lifeGem, "LEFT", u.name, "LEFT", math.min(nw, HP_W - 60) + 8, 0)
		C.Place(u.lifeText, "LEFT", u.lifeGem, "RIGHT", 2, 0)
		C.Color(u.lifeGem, 0.45, 1, 0.55, 1)
		C.SetText(u.lifeText, "x" .. lives)
		C.TextColor(u.lifeText, 0.6, 1, 0.65)
		C.Vis(u.lifeGem, true)
		C.Vis(u.lifeText, true)
	else
		C.Vis(u.lifeGem, false)
		C.Vis(u.lifeText, false)
	end
	C.Vis(u.tag, false)
end

------------------------------------------------------------------------ the dragon round a boss's portrait
-- A boss targeted wears the game's own gold elite dragon round its portrait, a guardian the silver
-- one, as the classic target frame showed them: the game's texture, turned to face out to the left,
-- in three pieces (its head, its coils by the ring, its claws) so the old frame's bars stay out.
local DRAGONS = { boss = "UI-TargetingFrame-Elite", final = "UI-TargetingFrame-Elite", guardian = "UI-TargetingFrame-Rare" }
local DRAGON_PIECES = { { 130, 0, 19 }, { 149, 19, 70 }, { 130, 70, 100 } } -- texture x from, y from, y to (of 256 x 128)
local DRAGON_SCALE = 66 / 72 -- the texture's ring is 72 across; the portrait's 66

local function SetDragon(u, kind)
	local file = kind and DRAGONS[kind]
	if u.dragonFile == file then return end
	u.dragonFile = file
	if not u.dragon then
		u.dragon = {}
		local s = DRAGON_SCALE
		for i = 1, table.getn(DRAGON_PIECES) do
			local p = DRAGON_PIECES[i]
			local t = u.faceTop:CreateTexture(nil, "ARTWORK")
			t:SetWidth((256 - p[1]) * s)
			t:SetHeight((p[3] - p[2]) * s)
			-- mirrored: the texture's right edge (x 256) on the left; its ring's middle (182, 46) on the portrait's
			t:SetPoint("TOPLEFT", u.face, "CENTER", -74 * s, (46 - p[2]) * s)
			t:SetTexCoord(1, p[1] / 256, p[2] / 128, p[3] / 128)
			u.dragon[i] = t
		end
	end
	for i = 1, table.getn(u.dragon) do
		if file then u.dragon[i]:SetTexture("Interface\\TargetingFrame\\" .. file) end
		C.Vis(u.dragon[i], file and true or false)
	end
	C.Vis(u.ring, not file) -- the dragon brings its own ring
end

------------------------------------------------------------------------ your target's frame
local function StepTarget(u, dt, now, pal)
	local exists = Call(UnitExists, "target")
	local t = type(AZS_TARGET) == "table" and AZS_TARGET or {}
	local kind = t.kind
	local enemy = ENEMY_KINDS[kind] and true or false
	local dead = Call(UnitIsDead, "target") or kind == "dead"
	local want = exists and 1 or 0
	u.alpha = C.Toward(u.alpha, want, want > u.alpha and 8 or 5, dt)
	if want == 1 and u.alpha > 0.997 then u.alpha = 1 end
	if u.alpha < 0.01 and want == 0 then
		C.Vis(u.root, false)
		u.hp.snap = true
		return
	end
	C.Vis(u.root, true)
	C.Alpha(u.root, C.Smooth(u.alpha))
	if not exists then return end -- fading out: keep the last picture

	SetDragon(u, (not dead) and kind or nil)
	local name = Call(UnitName, "target") or t.name or "?"
	local hp, hpm
	if enemy and tonumber(t.hpm) and t.hpm > 0 then
		hp, hpm = tonumber(t.hp) or 0, t.hpm
	else
		hp, hpm = Call(UnitHealth, "target") or 0, Call(UnitHealthMax, "target") or 1
	end
	if hpm <= 0 then hpm = 1 end
	if dead then hp = 0 end
	C.BarStep(u.hp, C.Clamp(hp / hpm, 0, 1), dt, now)
	local hostile = enemy or Call(UnitCanAttack, "player", "target")
	local cols = hostile and ENEMY_COLORS or HP_COLORS
	if u.colorsFor ~= cols then
		u.colorsFor = cols
		C.BarColors(u.hp, cols[1], cols[2], cols[3])
	end
	if enemy or hpm > 100 then
		C.SetText(u.hpText, HPText(math.floor(hp + 0.5), math.floor(hpm + 0.5)))
	else
		C.SetText(u.hpText, math.floor(hp / hpm * 100 + 0.5) .. "%")
	end
	C.SetText(u.name, name)
	if hostile then
		C.TextColor(u.name, 1, 0.86, 0.78)
	else
		C.TextColor(u.name, pal.title[1], pal.title[2], pal.title[3])
	end
	local tag = KIND_TAGS[kind]
	if tag then
		C.SetText(u.tag, C.L(tag[1]))
		C.TextColor(u.tag, tag[2], tag[3], tag[4])
		C.Vis(u.tag, true)
	else
		C.Vis(u.tag, false)
	end
	local level = Call(UnitLevel, "target")
	if kind == "boss" or kind == "final" or not level or level < 0 then
		C.SetText(u.level, "??")
	else
		C.SetText(u.level, tostring(level))
	end
end

------------------------------------------------------------------------ portraits and theme
local function Portrait(u, unit)
	if type(SetPortraitTexture) == "function" and Call(UnitExists, unit) then
		pcall(SetPortraitTexture, u.portrait, unit)
		u.portrait:Show()
	end
end

local function Theme(u, pal)
	C.BarTheme(u.hp, pal)
	if u.res then C.BarTheme(u.res, pal) end
	local rim = pal.rim
	u.ring:SetVertexColor(rim[1], rim[2], rim[3])
	u.badge:SetVertexColor(rim[1], rim[2], rim[3])
	u.faceBg:SetVertexColor(0.5, 0.5, 0.5)
end

------------------------------------------------------------------------ on and off
local function ApplyPlayer()
	if db.player then
		C.HideStock("PlayerFrame")
	else
		C.RestoreStock("PlayerFrame")
		P.root:Hide()
		P.root.mv = false
	end
end

local function ApplyTarget()
	if db.target then
		C.HideStock("TargetFrame")
		C.HideStock("ComboFrame")
	else
		C.RestoreStock("TargetFrame")
		C.RestoreStock("ComboFrame")
		T.root:Hide()
		T.root.mv = false
	end
end

local function Rescale(u, s)
	u.root:SetScale(s)
	C.ApplyPos(u.mover)
end

local levelled, portraitClock, stamp = false, 0, -1

local function Tick(dt)
	local now = GetTime()
	local pal = C.Pal()
	if stamp ~= C.palStamp then
		stamp = C.palStamp
		Theme(P, pal)
		Theme(T, pal)
	end
	portraitClock = portraitClock - dt
	if portraitClock <= 0 then
		portraitClock = 3
		Portrait(P, "player")
	end
	if not levelled then
		levelled = true
		Levels(P)
		Levels(T)
	end
	if db.player then
		C.Vis(P.root, true)
		StepPlayer(P, dt, now, pal)
	end
	if db.target then StepTarget(T, dt, now, pal) end
end

C.OnInit(function()
	db = C.DB("units", DEFAULTS)
	P = Build("CreedUIPlayer", "player", "Your frame", function(f)
		f:ClearAllPoints()
		f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 14, -10)
	end, true)
	T = Build("CreedUITarget", "target", "Target frame", function(f)
		f:ClearAllPoints()
		f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 14, -90)
	end, false)
	P.root:SetScale(db.playerScale)
	T.root:SetScale(db.targetScale)
	C.ApplyPos(P.mover)
	C.ApplyPos(T.mover)
	C.OverCards(P.root) -- lit over the level-up cards' veil (Core)
	C.OverCards(T.root)

	local driver = CreateFrame("Frame", "CreedUIUnitsDriver")
	driver:RegisterEvent("PLAYER_TARGET_CHANGED")
	driver:RegisterEvent("UNIT_PORTRAIT_UPDATE")
	driver:RegisterEvent("PLAYER_ENTERING_WORLD")
	driver:SetScript("OnEvent", function()
		if event == "PLAYER_TARGET_CHANGED" then
			T.hp.snap = true
			Portrait(T, "target")
		elseif event == "UNIT_PORTRAIT_UPDATE" then
			if arg1 == "player" then Portrait(P, "player") elseif arg1 == "target" then Portrait(T, "target") end
		else
			Portrait(P, "player")
			Portrait(T, "target")
			if db.player then C.HideStock("PlayerFrame") end
			if db.target then
				C.HideStock("TargetFrame")
				C.HideStock("ComboFrame")
			end
		end
	end)
	local broken = false
	driver:SetScript("OnUpdate", function()
		if broken then return end
		local dt = arg1 or 0
		if dt > 0.1 then dt = 0.1 end
		local ok, err = pcall(Tick, dt)
		if not ok then
			broken = true
			C.RestoreStock("PlayerFrame")
			C.RestoreStock("TargetFrame")
			C.RestoreStock("ComboFrame")
			P.root:Hide()
			T.root:Hide()
			C.Print(C.L("unit frames stopped after an error, so the game's own are back: ") .. tostring(err))
		end
	end)
	ApplyPlayer()
	ApplyTarget()
end)

C.RegisterPart({
	key = "player", name = "Your frame",
	note = "Your health with the real numbers, shield, energy/mana/rage, class meter and extra lives. Replaces the game's player frame.",
	get = function() return db and db.player end,
	set = function(on) if db then db.player = on and true or false; ApplyPlayer() end end,
	getScale = function() return db and db.playerScale or 1 end,
	setScale = function(v) if db then db.playerScale = v; Rescale(P, v) end end,
})
C.RegisterPart({
	key = "target", name = "Target frame",
	note = "Your target's health with the real numbers, and whether it's a boss, guardian or elite. Replaces the game's target frame.",
	get = function() return db and db.target end,
	set = function(on) if db then db.target = on and true or false; ApplyTarget() end end,
	getScale = function() return db and db.targetScale or 1 end,
	setScale = function(v) if db then db.targetScale = v; Rescale(T, v) end end,
})
