-- Creed UI: the run's stats at a glance (1.22.0, asked for by a player: "a window like this one,
-- maybe allowing us to choose which stats to track"). A small window in the meter's glass: the stats
-- the game keeps for the run (AZS_STATS, as its own character panel words them), grouped as the
-- character window groups them (Offense, Survival, Area and DoTs, Run), each group under a fine
-- header in its own color. A value that changes flashes green as it rises, red as it falls. The +
-- in its head opens the list of every stat to tick the ones it shows; the x hides it (Creed UI
-- Options brings it back). Drag it anywhere on it to move it; size it in the options.

local C = CreedUI
local DEFAULTS = { enabled = true, shown = true, scale = 1 }
local W, HEAD, ROW, GAP, SECTION = 196, 24, 15, 6, 17
local FLASH = 2.5 -- seconds a change shows by its number
-- each stat: its name (the game's word), its group, how to read it off AZS_STATS, how to write it
local function Pct(v) return string.format("%+.0f%%", v * 100) end
local STATS = {
	{ "Damage", 1, function(s) return s.dmg and s.dmg - 1 end, Pct },
	{ "Crit", 1, function(s) return s.crit end, function(v) return string.format("%.1f%%", v * 100) end },
	{ "Crit Dmg", 1, function(s) return s.cm end, function(v) return string.format("%.0f%%", v * 100) end },
	{ "Haste", 1, function(s) return s.cd and 1 - s.cd end, Pct },
	{ "Melee", 1, function(s) return s.auto end, Pct },
	{ "Pet Damage", 1, function(s) return s.pet end, Pct },
	{ "Buff Power", 1, function(s) return s.bp end, Pct },
	{ "Vs Elites", 1, function(s) return s.big end, Pct },
	{ "Execute", 1, function(s) return s.exe end, Pct },
	{ "Vs Controlled", 1, function(s) return s.cc end, Pct },
	{ "Vs Afflicted", 1, function(s) return s.dotd end, Pct },
	{ "Shielded", 1, function(s) return s.shd end, Pct },
	{ "Health", 2, function(s) return s.hp end, function(v) return C.Commas(math.floor(v + 0.5)) end },
	{ "Armor", 2, function(s) return s.arm end, function(v) return string.format("%.0f%%", v * 100) end },
	{ "Regen", 2, function(s) return s.reg end, function(v) return string.format("%.1f", v) end },
	{ "Lifesteal", 2, function(s) return s.lch end, function(v) return string.format("%.1f%%", v * 100) end },
	{ "Kill Heal", 2, function(s) return s.heal end, function(v) return string.format("%.0f", v) end },
	{ "Thorns", 2, function(s) return s.thn end, function(v) return string.format("%.0f%%", v * 100) end },
	{ "Lives", 2, function(s) return s.liv end, function(v) return string.format("%d", v) end },
	{ "Echo", 3, function(s) return s.echo end, function(v) return string.format("%.0f%%", v * 100) end },
	{ "Area", 3, function(s) return s.area and s.area - 1 end, Pct },
	{ "Targets", 3, function(s) return s.cnt end, function(v) return string.format("+%d", v) end },
	{ "DoT Stacks", 3, function(s) return s.dots end, function(v) return string.format("%d", v) end },
	{ "DoT Haste", 3, function(s) return s.doth end, Pct },
	{ "Speed", 4, function(s) return s.spd and s.spd - 1 end, Pct },
	{ "Pickup", 4, function(s) return s.pick end, function(v) return string.format("%.0f yd", v) end },
	{ "Experience", 4, function(s) return s.xp and s.xp - 1 end, Pct },
	{ "Gold", 4, function(s) return s.gold and s.gold - 1 end, Pct },
	{ "Luck", 4, function(s) return s.luck end, Pct },
}
-- the groups, as the character window names them, each in its own color
local GROUPS = {
	{ name = "OFFENSE", color = { 1.00, 0.52, 0.36 } },
	{ name = "SURVIVAL", color = { 0.46, 0.72, 1.00 } },
	{ name = "AREA AND DOTS", color = { 0.78, 0.58, 1.00 } },
	{ name = "RUN", color = { 0.48, 0.90, 0.52 } },
}
-- what it shows until you pick: the stats most players watch
local TRACK = { ["Damage"] = true, ["Crit"] = true, ["Crit Dmg"] = true, ["Haste"] = true, ["Echo"] = true,
	["Health"] = true, ["Armor"] = true, ["Regen"] = true, ["Lifesteal"] = true, ["Speed"] = true, ["Luck"] = true }
-- while moving the frames with no run: numbers to show its size by
local SAMPLE = { dmg = 2.57, crit = 0.404, cm = 2.97, cd = 0.71, echo = 0.32, hp = 2480, arm = 0.39, reg = 4.5,
	lch = 0.015, spd = 1.58, luck = 0.2, area = 1.3, cnt = 2, xp = 1.2, gold = 1.27, pick = 9, heal = 0, thn = 0,
	liv = 1, bp = 0.3, dots = 1, doth = 0, big = 0, exe = 0.3, cc = 0, dotd = 0.15, shd = 0, auto = 0, pet = 0 }

local db, root, menu
local S = { alpha = 0, stamp = -1, lang = -1, layoutKey = nil, values = {}, flash = {}, readClock = 0 }
local Call = C.Call

local function Tracked(name)
	local t = db and db.track
	if type(t) == "table" and t[name] ~= nil then return t[name] and true or false end
	return TRACK[name] and true or false
end

------------------------------------------------------------------------ building
local function NewRow(i)
	local r = CreateFrame("Frame", nil, root)
	r:SetHeight(ROW)
	r.shade = C.Tex(r, "BACKGROUND", C.FLAT)
	r.shade:SetAllPoints(r)
	r.shade:SetVertexColor(1, 1, 1, 0)
	r.label = C.Text(r, C.FONT, 10, nil, "LEFT", 120)
	r.label:SetPoint("LEFT", r, "LEFT", 4, 0)
	r.label:SetTextColor(0.80, 0.78, 0.72)
	r.value = C.Text(r, C.FONT, 10, "OUTLINE", "RIGHT", 80)
	r.value:SetPoint("RIGHT", r, "RIGHT", -4, 0)
	return r
end

local function NewHead(i)
	local h = { }
	h.text = C.Text(root, C.FONT, 9, nil, "CENTER", W - 40)
	h.lineL = C.Tex(root, "ARTWORK", C.FLAT)
	h.lineL:SetHeight(1)
	h.lineR = C.Tex(root, "ARTWORK", C.FLAT)
	h.lineR:SetHeight(1)
	return h
end

local function HeadButton(text, tip, onClick)
	local b = CreateFrame("Button", nil, root)
	b:SetWidth(16)
	b:SetHeight(16)
	b.text = C.Text(b, C.FONT, 11, nil, "CENTER", 16)
	b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
	b.text:SetText(text)
	b.text:SetTextColor(0.78, 0.74, 0.66)
	b:SetScript("OnClick", onClick)
	b:SetScript("OnEnter", function()
		b.text:SetTextColor(1, 0.9, 0.6)
		if GameTooltip then
			GameTooltip:SetOwner(b, "ANCHOR_LEFT")
			GameTooltip:AddLine(C.L(tip), 1, 1, 1, 1)
			C.ShowTip()
		end
	end)
	b:SetScript("OnLeave", function()
		b.text:SetTextColor(0.78, 0.74, 0.66)
		if GameTooltip then GameTooltip:Hide() end
	end)
	return b
end

local function BuildMenu()
	-- the list of every stat, a tick by each it shows: beside the window, in its glass
	menu = CreateFrame("Frame", "CreedUIStatsMenu", root)
	menu:SetFrameStrata("DIALOG")
	menu:SetWidth(150)
	menu:SetHeight(table.getn(STATS) * 14 + 26)
	menu:SetPoint("TOPLEFT", root, "TOPRIGHT", 4, 0)
	menu:SetBackdrop({ bgFile = C.FLAT, edgeFile = C.FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	menu:SetBackdropColor(0.04, 0.04, 0.05, 0.96)
	menu:SetBackdropBorderColor(0.91, 0.70, 0.30, 0.7)
	menu:EnableMouse(true)
	menu:Hide()
	menu.title = C.Text(menu, C.FONT, 10, nil, "CENTER", 140)
	menu.title:SetPoint("TOP", menu, "TOP", 0, -6)
	C.LText(menu.title, "Pick the stats to show")
	menu.items = {}
	for i = 1, table.getn(STATS) do
		local st = STATS[i]
		local b = CreateFrame("Button", nil, menu)
		b:SetWidth(140)
		b:SetHeight(14)
		b:SetPoint("TOPLEFT", menu, "TOPLEFT", 5, -20 - (i - 1) * 14)
		b.box = C.Tex(b, "ARTWORK", C.FLAT)
		b.box:SetWidth(9)
		b.box:SetHeight(9)
		b.box:SetPoint("LEFT", b, "LEFT", 2, 0)
		b.tick = C.Tex(b, "OVERLAY", C.ART .. "Check")
		b.tick:SetWidth(12)
		b.tick:SetHeight(12)
		b.tick:SetPoint("CENTER", b.box, "CENTER", 1, 1)
		b.label = C.Text(b, C.FONT, 10, nil, "LEFT", 124)
		b.label:SetPoint("LEFT", b, "LEFT", 16, 0)
		C.LText(b.label, st[1])
		local c = GROUPS[st[2]].color
		b.label:SetTextColor(0.55 + c[1] * 0.45, 0.55 + c[2] * 0.45, 0.55 + c[3] * 0.45)
		b.name = st[1]
		b:SetScript("OnClick", function()
			if type(db.track) ~= "table" then db.track = {} end
			db.track[this.name] = not Tracked(this.name)
			S.layoutKey = nil
		end)
		menu.items[i] = b
	end
end

local function Build()
	root = CreateFrame("Frame", "CreedUIStats", UIParent)
	root:SetFrameStrata("MEDIUM")
	root:SetWidth(W)
	root:SetHeight(HEAD + 40)
	root:SetClampedToScreen(true)
	root:SetScale(db.scale)
	root:EnableMouse(true)
	root:Hide()
	-- glass, a metal line round it, diamonds at the head's ends: the meter's and the luck window's
	root.glass = C.Tex(root, "BACKGROUND", C.FLAT)
	root.glass:SetAllPoints(root)
	root.glass:SetGradientAlpha("VERTICAL", 0.02, 0.02, 0.03, 0.86, 0.07, 0.07, 0.09, 0.80)
	root.headBg = C.Tex(root, "BORDER", C.FLAT)
	root.headBg:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0)
	root.headBg:SetPoint("TOPRIGHT", root, "TOPRIGHT", 0, 0)
	root.headBg:SetHeight(HEAD)
	root.lines = {}
	for i = 1, 5 do root.lines[i] = C.Tex(root, "BORDER", C.FLAT) end
	local L = root.lines
	L[1]:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0); L[1]:SetPoint("TOPRIGHT", root, "TOPRIGHT", 0, 0); L[1]:SetHeight(1)
	L[2]:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", 0, 0); L[2]:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", 0, 0); L[2]:SetHeight(1)
	L[3]:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0); L[3]:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", 0, 0); L[3]:SetWidth(1)
	L[4]:SetPoint("TOPRIGHT", root, "TOPRIGHT", 0, 0); L[4]:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", 0, 0); L[4]:SetWidth(1)
	L[5]:SetPoint("TOPLEFT", root, "TOPLEFT", 6, -HEAD); L[5]:SetPoint("TOPRIGHT", root, "TOPRIGHT", -6, -HEAD); L[5]:SetHeight(1)
	root.gemL = C.Tex(root, "ARTWORK", C.ART .. "Diamond")
	root.gemL:SetWidth(9)
	root.gemL:SetHeight(9)
	root.gemL:SetPoint("CENTER", root, "TOPLEFT", 0, -HEAD)
	root.gemR = C.Tex(root, "ARTWORK", C.ART .. "Diamond")
	root.gemR:SetWidth(9)
	root.gemR:SetHeight(9)
	root.gemR:SetPoint("CENTER", root, "TOPRIGHT", 0, -HEAD)
	-- the head: a gem, the title, the + (pick the stats) and the x
	root.icon = C.Tex(root, "ARTWORK", C.ART .. "Diamond")
	root.icon:SetWidth(13)
	root.icon:SetHeight(13)
	root.icon:SetPoint("LEFT", root, "TOPLEFT", 8, -HEAD * 0.5)
	root.title = C.Text(root, C.TITLE_FONT, 14, nil, "LEFT", 120)
	root.title:SetPoint("LEFT", root.icon, "RIGHT", 5, 0)
	C.LText(root.title, "Stats")
	root.close = HeadButton("x", "Hide the stats window (Creed UI Options brings it back)", function()
		db.shown = false
		if menu then menu:Hide() end
		if C.RefreshHub then C.RefreshHub() end
	end)
	root.close:SetPoint("RIGHT", root, "TOPRIGHT", -4, -HEAD * 0.5)
	root.pick = HeadButton("+", "Pick the stats to show", function()
		if menu:IsShown() then menu:Hide() else menu:Show() end
	end)
	root.pick:SetPoint("RIGHT", root.close, "LEFT", -2, 0)
	root.rows, root.heads = {}, {}
	for i = 1, table.getn(STATS) do root.rows[i] = NewRow(i) end
	for i = 1, table.getn(GROUPS) do root.heads[i] = NewHead(i) end
	BuildMenu()
end

-- the tracked stats in their groups, top to bottom; the window as tall as they need
local function Layout()
	local y = -HEAD - GAP
	local any = false
	for gi = 1, table.getn(GROUPS) do
		local h = root.heads[gi]
		local shown = false
		for i = 1, table.getn(STATS) do
			if STATS[i][2] == gi and Tracked(STATS[i][1]) then shown = true end
		end
		C.Vis(h.text, shown)
		C.Vis(h.lineL, shown)
		C.Vis(h.lineR, shown)
		if shown then
			any = true
			C.Place(h.text, "TOP", root, "TOP", 0, y - 2)
			local half = math.min(W / 2 - 10, (h.text:GetStringWidth() or 60) / 2 + 8)
			C.Place(h.lineL, "TOPLEFT", root, "TOPLEFT", 10, y - SECTION / 2)
			C.Width(h.lineL, W / 2 - 10 - half)
			C.Place(h.lineR, "TOPRIGHT", root, "TOPRIGHT", -10, y - SECTION / 2)
			C.Width(h.lineR, W / 2 - 10 - half)
			y = y - SECTION
			local n = 0
			for i = 1, table.getn(STATS) do
				local st, r = STATS[i], root.rows[i]
				if st[2] == gi and Tracked(st[1]) then
					C.Place(r, "TOPLEFT", root, "TOPLEFT", 6, y)
					C.Width(r, W - 12)
					C.Vis(r, true)
					-- every other row a breath lighter, to follow a line across
					C.Color(r.shade, 1, 1, 1, math.mod(n, 2) == 1 and 0.035 or 0)
					y = y - ROW
					n = n + 1
				end
			end
			y = y - 3
		end
	end
	for i = 1, table.getn(STATS) do
		if not Tracked(STATS[i][1]) then C.Vis(root.rows[i], false) end
	end
	if not any then y = y - ROW end
	C.Size(root, W, -y + GAP)
	for i = 1, table.getn(menu.items) do
		local b = menu.items[i]
		C.Vis(b.tick, Tracked(b.name))
	end
end

local function Theme(pal)
	local rim, t = pal.rim, pal.title
	for i = 1, 4 do root.lines[i]:SetVertexColor(rim[1], rim[2], rim[3], 0.45) end
	root.lines[5]:SetVertexColor(rim[1], rim[2], rim[3], 0.3)
	root.gemL:SetVertexColor(rim[1], rim[2], rim[3])
	root.gemR:SetVertexColor(rim[1], rim[2], rim[3])
	root.icon:SetVertexColor(rim[1], rim[2], rim[3])
	root.headBg:SetGradientAlpha("VERTICAL", 0, 0, 0, 0.2, t[1] * 0.25, t[2] * 0.25, t[3] * 0.25, 0.35)
	root.title:SetTextColor(t[1], t[2], t[3])
	menu:SetBackdropBorderColor(rim[1], rim[2], rim[3], 0.7)
	for i = 1, table.getn(menu.items) do menu.items[i].box:SetVertexColor(rim[1] * 0.35, rim[2] * 0.35, rim[3] * 0.35, 1) end
	for gi = 1, table.getn(GROUPS) do
		local c, h = GROUPS[gi].color, root.heads[gi]
		h.text:SetTextColor(c[1], c[2], c[3])
		h.lineL:SetGradientAlpha("HORIZONTAL", c[1], c[2], c[3], 0, c[1], c[2], c[3], 0.7)
		h.lineR:SetGradientAlpha("HORIZONTAL", c[1], c[2], c[3], 0.7, c[1], c[2], c[3], 0)
	end
end

local function Words()
	for gi = 1, table.getn(GROUPS) do C.LText(root.heads[gi].text, GROUPS[gi].name) end
	for i = 1, table.getn(STATS) do C.LText(root.rows[i].label, STATS[i][1]) end
	S.layoutKey = nil
end

------------------------------------------------------------------------ each frame
local function Step(dt)
	local stats = type(AZS_STATS) == "table" and AZS_STATS or nil
	local sample = false
	if not stats and C.unlocked then stats, sample = SAMPLE, true end
	local want = (db.enabled and stats and (db.shown or C.unlocked) and not C.cardsUp) and 1 or 0
	S.alpha = C.Toward(S.alpha, want, 8, dt)
	if want == 1 and S.alpha > 0.995 then S.alpha = 1 end
	if S.alpha < 0.01 and want == 0 then
		C.Vis(root, false)
		return
	end
	C.Vis(root, true)
	C.Alpha(root, C.Smooth(S.alpha))
	if not stats then return end
	if S.stamp ~= C.palStamp then
		S.stamp = C.palStamp
		Theme(C.Pal())
	end
	if S.lang ~= C.langStamp then
		S.lang = C.langStamp
		Words()
	end
	if S.layoutKey ~= true then
		S.layoutKey = true
		Layout()
	end
	-- the numbers, read a few times a second; a change flashes green going up, red going down
	S.readClock = S.readClock - dt
	local read = S.readClock <= 0
	if read then S.readClock = 0.25 end
	for i = 1, table.getn(STATS) do
		local st, r = STATS[i], root.rows[i]
		if Tracked(st[1]) then
			if read then
				local ok, v = pcall(st[3], stats)
				v = ok and tonumber(v) or nil
				local was = S.values[i]
				if v and was and not sample and math.abs(v - was) > 1e-6 then
					S.flash[i] = { t = FLASH, up = v > was }
				end
				S.values[i] = v
				C.SetText(r.value, v and st[4](v) or "-")
			end
			local c = GROUPS[st[2]].color
			local base1, base2, base3 = 0.80 + c[1] * 0.2, 0.80 + c[2] * 0.2, 0.80 + c[3] * 0.2
			local f = S.flash[i]
			if f then
				f.t = f.t - dt
				if f.t <= 0 then S.flash[i] = nil end
				local k = C.Smooth(C.Clamp(f.t / FLASH, 0, 1))
				local tr, tg, tb = 0.45, 1.0, 0.45
				if not f.up then tr, tg, tb = 1.0, 0.42, 0.36 end
				C.TextColor(r.value, base1 + (tr - base1) * k, base2 + (tg - base2) * k, base3 + (tb - base3) * k)
			else
				C.TextColor(r.value, base1, base2, base3)
			end
		end
	end
end

------------------------------------------------------------------------ setup
-- by the left edge, over the chat
local function Anchor(f)
	f:ClearAllPoints()
	f:SetPoint("LEFT", UIParent, "LEFT", 18, 40)
end

C.OnInit(function()
	db = C.DB("stats", DEFAULTS)
	db.scale = C.Clamp(tonumber(db.scale) or 1, 0.6, 1.6)
	Build()
	local mover = C.Movable(root, "stats", "Stats", Anchor)
	C.OverCards(root)
	C.Draggable(root, mover)
	local driver = CreateFrame("Frame", "CreedUIStatsDriver")
	local broken = false
	driver:SetScript("OnUpdate", function()
		if broken then return end
		local dt = arg1 or 0
		if dt > 0.1 then dt = 0.1 end
		local ok, err = pcall(Step, dt)
		if not ok then
			broken = true
			root:Hide()
			C.Print(C.L("the stats window stopped after an error: ") .. tostring(err))
		end
	end)
end)

C.OnWorld(function()
	if not db then return end
	for i = 1, table.getn(C.movers) do
		if C.movers[i].frame == root then C.ApplyPos(C.movers[i]) end
	end
end)

C.RegisterPart({
	key = "stats", name = "Stats",
	note = "Your run's stats at a glance, grouped (Offense, Survival, Area and DoTs, Run); a change flashes green going up, red going down. The + in its head picks the stats it shows.",
	get = function() return db and db.enabled and db.shown end,
	set = function(on)
		if db then
			if on then db.enabled, db.shown = true, true else db.shown = false end
			if not on and menu then menu:Hide() end
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
