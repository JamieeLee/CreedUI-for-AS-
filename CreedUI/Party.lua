-- Creed UI: your party. Up to four friends under your target, each with a health bar in their
-- class's color and the real numbers, their mana, energy or rage, a portrait and their level. A
-- friend who is down or offline says so. Click one to target them. While this part is on, the
-- game's party frames are tucked away; turning it off brings them back.

local C = CreedUI
local DEFAULTS = { enabled = true, scale = 1 }
local ROW_W, ROW_H, GAP = 232, 44, 6
local HP_W, HP_H, POW_H = 160, 11, 5
local BAR_X = 56
local CLASS_COLORS = {
	HUNTER = { 0.67, 0.83, 0.45 }, WARLOCK = { 0.58, 0.51, 0.79 }, PRIEST = { 1.00, 1.00, 1.00 },
	PALADIN = { 0.96, 0.55, 0.73 }, MAGE = { 0.41, 0.80, 0.94 }, ROGUE = { 1.00, 0.96, 0.41 },
	DRUID = { 1.00, 0.49, 0.04 }, SHAMAN = { 0.00, 0.44, 0.87 }, WARRIOR = { 0.78, 0.61, 0.43 },
}
local NO_CLASS = { 0.55, 0.55, 0.58 }
local POWER_COLORS = {
	[0] = { { 0.03, 0.10, 0.36 }, { 0.10, 0.34, 0.86 }, { 0.48, 0.74, 1.00 } }, -- mana
	[1] = { { 0.34, 0.02, 0.02 }, { 0.76, 0.08, 0.06 }, { 1.00, 0.38, 0.26 } }, -- rage
	[2] = { { 0.36, 0.16, 0.02 }, { 0.84, 0.44, 0.08 }, { 1.00, 0.72, 0.32 } }, -- focus
	[3] = { { 0.40, 0.33, 0.02 }, { 0.86, 0.74, 0.10 }, { 1.00, 0.96, 0.46 } }, -- energy
}
local GREY = { { 0.10, 0.10, 0.11 }, { 0.30, 0.30, 0.32 }, { 0.50, 0.50, 0.52 } }
local SAMPLES = {
	{ name = "Jaina", class = "MAGE", level = 20, hp = 1840, hpm = 2300, power = 0, mp = 900, mpm = 1400 },
	{ name = "Anduin", class = "PRIEST", level = 19, hp = 2050, hpm = 2100, power = 0, mp = 600, mpm = 1500 },
	{ name = "Varian", class = "WARRIOR", level = 20, hp = 0, hpm = 3300, power = 1, mp = 0, mpm = 100, dead = true },
}

local db, root
local rows = {}
local S = { alpha = 0, stamp = -1, levelled = false, portraitClock = 0 }

local Call = C.Call -- no stray nil arguments (see Core)

local function HPText(hp, hpm)
	if hpm >= 100000 then return C.Short(hp) .. " / " .. C.Short(hpm) end
	return C.Commas(hp) .. " / " .. C.Commas(hpm)
end

-- a class color as the bar's three-stop fill: deep, true, bright, all in the class's own hue. The
-- color is made richer first (pulled away from grey), and the bright end stays the class's color
-- instead of fading toward white, so every class reads at a glance. Priest white, which has no hue
-- to strengthen, gets a pearl sheen with a deep slate start, so it reads as white and not as empty.
local VIVID = 1.45
local function ClassFill(c, out)
	local lum = c[1] * 0.3 + c[2] * 0.59 + c[3] * 0.11
	local v = {}
	for i = 1, 3 do v[i] = C.Clamp(lum + (c[i] - lum) * VIVID, 0, 1) end
	local top = math.max(v[1], v[2], v[3], 0.01)
	if top - math.min(v[1], v[2], v[3]) < 0.08 and lum <= 0.8 then
		-- grey (no class known): as it is
		for i = 1, 3 do
			out[1][i], out[2][i], out[3][i] = c[i] * 0.3, c[i] * 0.78, c[i]
		end
		return out
	elseif top - math.min(v[1], v[2], v[3]) < 0.08 then
		-- white: slate to pearl
		out[1][1], out[1][2], out[1][3] = 0.22, 0.25, 0.32
		out[2][1], out[2][2], out[2][3] = 0.68, 0.72, 0.80
		out[3][1], out[3][2], out[3][3] = 0.96, 0.97, 1.00
		return out
	end
	-- the true color at full strength: its brightest channel up to 1
	for i = 1, 3 do v[i] = v[i] / top end
	out[1][1], out[1][2], out[1][3] = v[1] * 0.32, v[2] * 0.32, v[3] * 0.32
	out[2][1], out[2][2], out[2][3] = v[1] * 0.86, v[2] * 0.86, v[3] * 0.86
	out[3][1], out[3][2], out[3][3] = v[1] + (1 - v[1]) * 0.12, v[2] + (1 - v[2]) * 0.12, v[3] + (1 - v[3]) * 0.12
	return out
end

------------------------------------------------------------------------ the right-click menu
-- A right click on a friend's frame opens a small gold-railed menu beside it, their name on top:
-- Inspect (their gear, as the game's own window shows it), Follow, Whisper (the chat box opens
-- with "/w Name" typed). It closes after a choice, on Escape, or when the mouse leaves it a while.
local menu

local function Whisper(name)
	if type(ChatFrame_SendTell) == "function" then
		Call(ChatFrame_SendTell, name)
		return
	end
	local box = ChatFrameEditBox
	if type(box) == "table" and box.SetText then
		box:Show()
		box:SetText("/w " .. name .. " ")
		box:SetFocus()
	end
end

-- As the game's own menu does it: the friend becomes your target, then the target is inspected (the
-- client's inspect window works from the target); the game itself says when they're too far.
local function Inspect(unit)
	if type(TargetUnit) == "function" then Call(TargetUnit, unit) end
	if type(InspectUnit) == "function" then
		Call(InspectUnit, "target")
		return
	end
	-- no InspectUnit: the 1.12 inspect window, loaded when first wanted
	if type(LoadAddOn) == "function" and type(InspectFrame_Show) ~= "function" then pcall(LoadAddOn, "Blizzard_InspectUI") end
	if type(InspectFrame_Show) == "function" then
		Call(InspectFrame_Show, "target")
	elseif type(NotifyInspect) == "function" then
		Call(NotifyInspect, "target")
	end
end

local function Follow(unit)
	if type(FollowUnit) == "function" then Call(FollowUnit, unit) end
end

local function BuildMenu()
	local m = CreateFrame("Frame", "CreedUIPartyMenu", UIParent)
	menu = m
	m:SetWidth(132)
	m:SetHeight(104)
	m:SetFrameStrata("DIALOG")
	m:EnableMouse(true)
	m.deco = C.Panel(m, false)
	C.PanelTheme(m.deco, C.Pal())
	m.title = C.Text(m, C.FONT, 12, "OUTLINE", "CENTER", 120)
	m.title:SetPoint("TOP", m, "TOP", 0, -9)
	m.title:SetTextColor(0.98, 0.85, 0.52)
	local acts = {
		{ "Inspect", function() Inspect(m.unit) end },
		{ "Follow", function() Follow(m.unit) end },
		{ "Whisper", function() Whisper(m.name) end },
	}
	m.buttons = {}
	for i = 1, table.getn(acts) do
		local act = acts[i][2]
		local b = C.Button(m, 112, 20, "", function()
			m:Hide()
			if m.unit and Call(UnitExists, m.unit) then act() end
		end)
		C.LText(b.text, acts[i][1])
		b:SetPoint("TOP", m, "TOP", 0, -28 - (i - 1) * 24)
		m.buttons[i] = b
	end
	m:SetScript("OnUpdate", function()
		-- away from it for a moment: it closes
		if MouseIsOver and MouseIsOver(m) then
			m.away = 0
		else
			m.away = (m.away or 0) + (arg1 or 0)
			if m.away > 2.5 then m:Hide() end
		end
	end)
	if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "CreedUIPartyMenu") end -- Escape closes it
	m:Hide()
end

local function OpenMenu(f, unit)
	if not menu then BuildMenu() end
	local name = Call(UnitName, unit)
	if not name then return end
	menu.unit, menu.name, menu.away = unit, name, 0
	menu.title:SetText(name)
	menu:ClearAllPoints()
	menu:SetPoint("TOPLEFT", f, "TOPRIGHT", 6, 0)
	menu:Show()
	if GameTooltip then GameTooltip:Hide() end
end

------------------------------------------------------------------------ a row
local function NewRow(i)
	local unit = "party" .. i
	local r = { unit = unit, i = i, alpha = 0, y = nil, yv = 0, fill = { { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 } } }
	local f = CreateFrame("Button", "CreedUIParty" .. i, root)
	r.frame = f
	f:SetWidth(ROW_W)
	f:SetHeight(ROW_H)
	f:EnableMouse(true)
	f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	f:SetScript("OnClick", function()
		if not Call(UnitExists, unit) then return end
		if arg1 == "RightButton" then
			OpenMenu(f, unit) -- Inspect, Follow, Whisper
		else
			Call(TargetUnit, unit)
		end
	end)
	f:SetScript("OnEnter", function()
		if GameTooltip and Call(UnitExists, unit) then
			GameTooltip:SetOwner(f, "ANCHOR_RIGHT")
			GameTooltip:SetUnit(unit)
			GameTooltip:Show()
		end
	end)
	f:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

	-- portrait in the metal ring, level on a badge
	r.face = CreateFrame("Frame", nil, f)
	r.face:SetWidth(42)
	r.face:SetHeight(42)
	r.face:SetPoint("LEFT", f, "LEFT", 4, 0)
	r.faceBg = C.Tex(r.face, "BACKGROUND", C.ART .. "Badge")
	r.faceBg:SetWidth(38)
	r.faceBg:SetHeight(38)
	r.faceBg:SetPoint("CENTER", r.face, "CENTER", 0, 0)
	r.portrait = r.face:CreateTexture(nil, "BORDER")
	r.portrait:SetWidth(34)
	r.portrait:SetHeight(34)
	r.portrait:SetPoint("CENTER", r.face, "CENTER", 0, 0)
	r.faceTop = CreateFrame("Frame", nil, r.face)
	r.faceTop:SetAllPoints(r.face)
	r.ring = C.Tex(r.faceTop, "ARTWORK", C.ART .. "Portrait")
	r.ring:SetAllPoints(r.face)
	r.badge = C.Tex(r.faceTop, "OVERLAY", C.ART .. "Badge")
	r.badge:SetWidth(18)
	r.badge:SetHeight(18)
	r.badge:SetPoint("CENTER", r.face, "BOTTOMLEFT", 7, 7)
	r.levelTop = CreateFrame("Frame", nil, r.faceTop)
	r.levelTop:SetAllPoints(r.face)
	r.level = C.Text(r.levelTop, C.FONT, 9, "OUTLINE", "CENTER", 30)
	r.level:SetPoint("CENTER", r.badge, "CENTER", 0, 0)

	-- health in the class's color, then the power bar
	r.hp = C.NewBar(f, HP_W, HP_H, true)
	f.creedBar = r.hp -- (the stand-in's tests read its shield)
	r.hp.frame:SetPoint("TOPLEFT", f, "TOPLEFT", BAR_X, -18)
	r.hpText = C.Text(r.hp.top, C.FONT, 10, "OUTLINE", "CENTER", HP_W + 30)
	r.hpText:SetPoint("CENTER", r.hp.frame, "CENTER", 0, 0)
	r.name = C.Text(r.hp.top, C.FONT, 11, "OUTLINE", "LEFT", HP_W - 50)
	r.name:SetPoint("BOTTOMLEFT", r.hp.frame, "TOPLEFT", 3, 4)
	r.tag = C.Text(r.hp.top, C.FONT, 10, "OUTLINE", "RIGHT", 70)
	r.tag:SetPoint("BOTTOMRIGHT", r.hp.frame, "TOPRIGHT", -2, 4)
	r.pow = C.NewBar(f, HP_W, POW_H, false)
	r.pow.frame:SetPoint("TOPLEFT", r.hp.frame, "BOTTOMLEFT", 0, -5)
	f:Hide()
	return r
end

local function RowLevels(r)
	local base = r.frame:GetFrameLevel()
	r.face:SetFrameLevel(base + 1)
	r.faceTop:SetFrameLevel(base + 3)
	r.levelTop:SetFrameLevel(base + 4)
	C.BarLevels(r.hp, base + 1)
	C.BarLevels(r.pow, base + 1)
end

local function Theme(r, pal)
	C.BarTheme(r.hp, pal)
	C.BarTheme(r.pow, pal)
	local rim = pal.rim
	r.ring:SetVertexColor(rim[1], rim[2], rim[3])
	r.badge:SetVertexColor(rim[1], rim[2], rim[3])
	r.faceBg:SetVertexColor(0.5, 0.5, 0.5)
end

local function Portrait(r)
	if type(SetPortraitTexture) == "function" and Call(UnitExists, r.unit) then
		pcall(SetPortraitTexture, r.portrait, r.unit)
		C.Vis(r.portrait, true)
	else
		C.Vis(r.portrait, false)
	end
end

------------------------------------------------------------------------ reading a friend
-- fills `d` with what the row shows: from the unit, or from a made-up friend while placing frames
local function Read(r, d, sample)
	if sample then
		d.name, d.class, d.level = sample.name, sample.class, sample.level
		d.hp, d.hpm, d.power, d.mp, d.mpm = sample.hp, sample.hpm, sample.power, sample.mp, sample.mpm
		d.dead, d.offline = sample.dead and true or false, false
		return
	end
	local unit = r.unit
	d.name = Call(UnitName, unit) or "?"
	local _, class = Call(UnitClass, unit)
	d.class = class
	d.level = Call(UnitLevel, unit) or 0
	d.hp, d.hpm = Call(UnitHealth, unit) or 0, Call(UnitHealthMax, unit) or 0
	d.power = Call(UnitPowerType, unit) or 0
	d.mp, d.mpm = Call(UnitMana, unit) or 0, Call(UnitManaMax, unit) or 0
	d.dead = Call(UnitIsDeadOrGhost, unit) and true or false
	local connected = Call(UnitIsConnected, unit)
	d.offline = (type(UnitIsConnected) == "function" and not connected) and true or false
end

------------------------------------------------------------------------ a friend's shield
-- A friend wearing a shield (Power Word: Shield, Ice Barrier, a ward...) shows it on their health
-- as your own frame does: an icy pane after the health. How much it holds is read off the buff's
-- own words ("Absorbing 442 damage"); when those give no number, a small pane still says one is up.
local SHIELDS = {
	spell_holy_powerwordshield = true, spell_ice_lament = true, spell_shadow_detectlesserinvisibility = true,
	spell_frost_frostward = true, spell_fire_firearmor = true, spell_shadow_sacrificialshield = true,
	spell_holy_divineintervention = true, spell_holy_restoration = true, spell_holy_sealofprotection = true,
}
local SHIELD_SEEN = 0.2 -- the pane when the amount can't be read: a fifth of their health
local scan -- a hidden tooltip to read a buff's words; false when the client can't make one

local function Amount(unit, i)
	if scan == nil then
		local ok, tip = pcall(CreateFrame, "GameTooltip", "CreedUIShieldScan", UIParent, "GameTooltipTemplate")
		scan = ok and tip or false
	end
	if not scan then return nil end
	scan:SetOwner(WorldFrame, "ANCHOR_NONE")
	scan:ClearLines()
	if not pcall(scan.SetUnitBuff, scan, unit, i) then return nil end
	local most
	for l = 2, scan:NumLines() do
		local line = getglobal("CreedUIShieldScanTextLeft" .. l)
		local text = line and line:GetText()
		if text then
			for n in string.gfind(text, "%d+") do
				n = tonumber(n)
				if n and (not most or n > most) then most = n end
			end
		end
	end
	scan:Hide()
	return most
end

-- the share of their health their shields hold now (0 with none)
local function ShieldOf(unit, hpm)
	if type(UnitBuff) ~= "function" then return 0 end
	local held, any = 0, false
	for i = 1, 32 do
		local tex = Call(UnitBuff, unit, i)
		if not tex then break end
		local _, _, base = string.find(string.lower(tex), "([^\\/]+)$")
		if base and SHIELDS[base] then
			any = true
			held = held + (Amount(unit, i) or 0)
		end
	end
	if not any then return 0 end
	if held > 0 then return C.Clamp(held / math.max(hpm, 1), 0.04, 1) end
	return SHIELD_SEEN
end

------------------------------------------------------------------------ drawing a row
local function StepRow(r, d, slotY, dt, now)
	if not r.y then r.y = slotY - 8 end
	r.y, r.yv = C.Spring(r.y, r.yv, slotY, 13, dt)
	if math.abs(r.y - slotY) < 0.05 and math.abs(r.yv) < 0.05 then r.y, r.yv = slotY, 0 end
	C.Place(r.frame, "TOPLEFT", root, "TOPLEFT", 0, -r.y)

	local hpm = d.hpm > 0 and d.hpm or 1
	local hp = d.dead and 0 or d.hp
	-- their shield, looked for twice a second
	r.shieldClock = (r.shieldClock or 0) - dt
	if r.shieldClock <= 0 then
		r.shieldClock = 0.5
		r.hp.shield = (d.dead or d.offline) and 0 or ShieldOf(r.unit, hpm)
	end
	C.BarStep(r.hp, d.offline and 1 or C.Clamp(hp / hpm, 0, 1), dt, now)
	-- the class's color; grey while offline
	local key = d.offline and "offline" or (d.class or "none")
	if r.colorsFor ~= key then
		r.colorsFor = key
		local fill = d.offline and GREY or ClassFill(CLASS_COLORS[d.class or ""] or NO_CLASS, r.fill)
		C.BarColors(r.hp, fill[1], fill[2], fill[3])
		-- the flowing light in the class's color too, so it shines without bleaching it
		local f3 = fill[3]
		C.Color(r.hp.flowTex, f3[1], f3[2], f3[3], 1)
	end
	local cols = POWER_COLORS[d.power] or POWER_COLORS[0]
	if r.powerFor ~= d.power then
		r.powerFor = d.power
		C.BarColors(r.pow, cols[1], cols[2], cols[3])
	end
	if d.mpm > 0 and not d.offline then
		C.BarStep(r.pow, d.dead and 0 or C.Clamp(d.mp / d.mpm, 0, 1), dt, now)
		C.Vis(r.pow.frame, true)
	else
		C.Vis(r.pow.frame, false)
	end

	-- text: health, name in the class's color, and Dead / Down / Offline (the numbers' words
	-- made again only when they change)
	if d.offline then
		C.SetText(r.hpText, C.L("Offline"))
		r.tHp = nil
	elseif d.dead then
		C.SetText(r.hpText, C.L("Dead"))
		r.tHp = nil
	elseif r.tHp ~= hp or r.tHpm ~= d.hpm then
		r.tHp, r.tHpm = hp, d.hpm
		if d.hpm > 100 then
			C.SetText(r.hpText, HPText(math.floor(hp + 0.5), math.floor(d.hpm + 0.5)))
		else
			C.SetText(r.hpText, math.floor(hp / hpm * 100 + 0.5) .. "%")
		end
	end
	if d.offline or d.dead then C.TextColor(r.hpText, 0.75, 0.75, 0.75) else C.TextColor(r.hpText, 1, 1, 1) end
	C.SetText(r.name, d.name)
	local cc = CLASS_COLORS[d.class or ""] or NO_CLASS
	C.TextColor(r.name, 0.35 + cc[1] * 0.65, 0.35 + cc[2] * 0.65, 0.35 + cc[3] * 0.65)
	local tag = (d.offline and "Offline") or (d.dead and "Dead") or (hp <= 0 and "Down") or nil
	if tag then
		C.SetText(r.tag, C.L(tag))
		if d.offline then C.TextColor(r.tag, 0.6, 0.6, 0.62) else C.TextColor(r.tag, 1, 0.36, 0.28) end
	end
	C.Vis(r.tag, tag ~= nil)
	if r.tLevel ~= d.level then
		r.tLevel = d.level
		C.SetText(r.level, (d.level and d.level > 0) and tostring(d.level) or "??")
	end
	-- a friend who is offline or dead fades back a little
	local dim = (d.offline or d.dead) and 0.55 or 1
	r.dim = C.Toward(r.dim or 1, dim, 4, dt)
	C.Alpha(r.frame, C.Smooth(r.alpha) * r.dim)
end

------------------------------------------------------------------------ every frame
local data = {}

local function Step(dt)
	local now = GetTime()
	local pal = C.Pal()
	if not S.levelled then
		S.levelled = true
		for i = 1, 4 do RowLevels(rows[i]) end
	end
	if S.stamp ~= C.palStamp then
		S.stamp = C.palStamp
		for i = 1, 4 do Theme(rows[i], pal) end
	end
	S.portraitClock = S.portraitClock - dt
	local refresh = S.portraitClock <= 0
	if refresh then S.portraitClock = 3 end

	local samples = C.unlocked and (Call(GetNumPartyMembers) or 0) == 0
	local y, any = 0, false
	for i = 1, 4 do
		local r = rows[i]
		local sample = samples and SAMPLES[i] or nil
		local here = db.enabled and (sample ~= nil or (Call(UnitExists, r.unit) and true or false))
		local d = data[i]
		if not d then
			d = {}
			data[i] = d
		end
		if here then
			Read(r, d, sample)
			-- a new friend in this place: snap the bars, read the face
			local who = sample and ("sample" .. i) or d.name
			if r.who ~= who then
				r.who = who
				r.hp.snap, r.pow.snap = true, true
				if sample then C.Vis(r.portrait, false) else Portrait(r) end
			elseif refresh and not sample then
				Portrait(r)
			end
		end
		r.alpha = C.Toward(r.alpha, here and 1 or 0, here and 7 or 5, dt)
		if here and r.alpha > 0.997 then r.alpha = 1 end
		if r.alpha < 0.005 and not here then
			if r.shown then
				r.shown, r.y, r.who = false, nil, nil
				C.Vis(r.frame, false)
			end
		else
			r.shown = true
			C.Vis(r.frame, true)
			StepRow(r, d, y, dt, now)
			y = y + (ROW_H + GAP) * C.Smooth(r.alpha)
			any = true
		end
	end
	C.Vis(root, db.enabled and (any or C.unlocked) and C.cardsFade < 0.99 and true or false)
	C.Alpha(root, 1 - C.cardsFade) -- away while the cards are up
end

------------------------------------------------------------------------ on and off
local STOCK = { "PartyMemberFrame1", "PartyMemberFrame2", "PartyMemberFrame3", "PartyMemberFrame4", "PartyMemberBackground" }

local function Apply()
	for i = 1, table.getn(STOCK) do
		if db.enabled then C.HideStock(STOCK[i]) else C.RestoreStock(STOCK[i]) end
	end
end

local function Anchor(f)
	f:ClearAllPoints()
	f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 14, -172) -- under the target frame
end

C.OnInit(function()
	db = C.DB("party", DEFAULTS)
	root = CreateFrame("Frame", "CreedUIParty", UIParent)
	root:SetFrameStrata("LOW")
	root:SetWidth(ROW_W)
	root:SetHeight(4 * ROW_H + 3 * GAP)
	root:SetScale(db.scale)
	root:Hide()
	for i = 1, 4 do rows[i] = NewRow(i) end
	C.Movable(root, "party", "Party frames", Anchor)
	C.OverCards(root) -- lit over the level-up cards' veil (Core)

	local driver = CreateFrame("Frame", "CreedUIPartyDriver")
	driver:RegisterEvent("PARTY_MEMBERS_CHANGED")
	driver:RegisterEvent("UNIT_PORTRAIT_UPDATE")
	driver:RegisterEvent("PLAYER_ENTERING_WORLD")
	driver:SetScript("OnEvent", function()
		if event == "UNIT_PORTRAIT_UPDATE" then
			for i = 1, 4 do
				if rows[i].unit == arg1 and rows[i].shown then Portrait(rows[i]) end
			end
		elseif event == "PARTY_MEMBERS_CHANGED" then
			for i = 1, 4 do rows[i].who = nil end -- faces may have moved up a place
		else
			Apply()
		end
	end)
	local broken = false
	driver:SetScript("OnUpdate", function()
		if broken then return end
		local dt = arg1 or 0
		if dt > 0.1 then dt = 0.1 end
		local ok, err = pcall(Step, dt)
		if not ok then
			broken = true
			db.enabled = false
			Apply()
			db.enabled = true
			root:Hide()
			C.Print(C.L("party frames stopped after an error, so the game's own are back: ") .. tostring(err))
		end
	end)
	Apply()
end)

C.RegisterPart({
	key = "party", name = "Party frames",
	note = "Up to four friends with health bars in their class's color and the real numbers, their mana/energy/rage, and Dead or Offline when they are. Click one to target them. Replaces the game's party frames.",
	get = function() return db and db.enabled end,
	set = function(on)
		if db then
			db.enabled = on and true or false
			Apply()
		end
	end,
	getScale = function() return db and db.scale or 1 end,
	setScale = function(v)
		if db then
			db.scale = v
			root:SetScale(v)
			for i = 1, table.getn(C.movers) do
				if C.movers[i].frame == root then C.ApplyPos(C.movers[i]) end
			end
		end
	end,
})
