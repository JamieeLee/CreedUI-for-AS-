-- Creed UI: luck, as a charm. A bronze medallion holds the luck your level-up cards roll with
-- (yours and your level's); three gems in their settings hold the chance a card comes Rare, Epic
-- or Legendary, put as "1 in N" and glowing the brighter the likelier it is; under them, how often
-- a level-up should bring a legendary. Luck you gain shows on the medallion as "+N%" and lights it.
-- Hover the medallion for where your luck comes from, a gem for its odds. Its sides widen it, its
-- corners size it; its x hides it and the clover on the minimap's edge brings it back.
--
-- The odds follow the game's roll: with m = 1 + luck + the level's 1% a level (30% at most), the
-- five rarities weigh 60, 25m, 10m^2, 4m^3 and m^4, each card on its own.

local C = CreedUI
local DEFAULTS = { enabled = true, shown = true, scale = 1, width = 236 }
local W = 236 -- its width: its sides drag it wider or narrower (the gems spread), its corners bigger or smaller
local HEAD, H = 24, 128
local MIN_W, MAX_W, MIN_SCALE, MAX_SCALE = 200, 340, 0.6, 1.6
local MEDAL, MEDAL_X = 58, 10 -- the medallion's size and its left
local MX, MY = MEDAL_X + MEDAL / 2, -(HEAD + 5 + MEDAL / 2) -- its middle
local GEM_Y, NAME_Y, ODDS_Y = -48, -70, -83
local GAIN_FOR = 3 -- seconds a gain shows on the medallion
local LUCK = { 0.36, 0.92, 0.56 }
-- `full`: the chance at which a gem glows its brightest
local RARITIES = {
	{ index = 3, name = "Rare", color = { 0.25, 0.60, 1.00 }, full = 0.2 },
	{ index = 4, name = "Epic", color = { 0.72, 0.36, 1.00 }, full = 0.15 },
	{ index = 5, name = "Legendary", color = { 1.00, 0.58, 0.12 }, full = 0.1 },
}
local SAMPLE = { luck = 0.41, level = 16 }

local db, root
local S = { alpha = 0, stamp = -1, tipOn = false, gemTip = nil, gainT = 0 }
local odds = {}

local Call = C.Call -- no stray nil arguments (see Core)

local function LevelBonus(level)
	return math.min((level or 1) * 0.01, 0.3)
end

-- the five rarities' chances for a roll with luck m
local function Odds(m, out)
	local w1, w2, w3, w4, w5 = 60, 25 * m, 10 * m * m, 4 * m * m * m, m * m * m * m
	local sum = w1 + w2 + w3 + w4 + w5
	out[1], out[2], out[3], out[4], out[5] = w1 / sum, w2 / sum, w3 / sum, w4 / sum, w5 / sum
	return out
end

local function Whole(v) return string.format("%.0f%%", (v or 0) * 100) end
local function Pct(v) return string.format("%.1f%%", (v or 0) * 100) end

-- a chance as "1 in N": whole numbers, a tenth under 2
local function OneIn(p)
	if not p or p <= 0 then return "-" end
	local n = 1 / p
	if n < 1.95 then return C.F("1 in {1}", string.format("%.1f", n)) end
	return C.F("1 in {1}", C.Commas(math.floor(n + 0.5)))
end

-- how often a level-up's three cards hold a legendary
local function Every(each)
	local per = 1 - (1 - each) * (1 - each) * (1 - each)
	if per <= 0 then return "" end
	local n = 1 / per
	if n < 1.5 then return C.L("A legendary almost every level-up") end
	return C.F("A legendary about every {1} level-ups", math.floor(n + 0.5))
end

------------------------------------------------------------------------ building
local function NewGem(i, rar)
	local g = { rar = rar, glowA = 0, flash = 0, i = i }
	local c = rar.color
	g.glow = C.Tex(root, "BORDER", C.ART .. "Glow", "ADD")
	g.glow:SetWidth(54)
	g.glow:SetHeight(54)
	g.bezel = C.Tex(root, "ARTWORK", C.ART .. "LuckBezel")
	g.bezel:SetWidth(32)
	g.bezel:SetHeight(32)
	g.orb = C.Tex(root, "ARTWORK", C.ART .. "LuckOrb")
	g.orb:SetWidth(28)
	g.orb:SetHeight(28)
	g.orb:SetVertexColor(c[1], c[2], c[3])
	g.glint = C.Tex(root, "OVERLAY", C.ART .. "LuckGlint")
	g.glint:SetWidth(28)
	g.glint:SetHeight(28)
	g.name = C.Text(root, C.FONT, 9, nil, "CENTER", 60)
	C.LText(g.name, rar.name)
	g.name:SetTextColor(0.55 + c[1] * 0.45, 0.55 + c[2] * 0.45, 0.55 + c[3] * 0.45)
	g.odds = C.Text(root, C.FONT, 11, "OUTLINE", "CENTER", 60)
	g.odds:SetTextColor(1, 0.97, 0.9)
	g.size = 11
	-- the gem answers the mouse with its odds
	g.hit = CreateFrame("Button", nil, root)
	g.hit:SetHeight(58)
	g.hit:SetScript("OnEnter", function() S.gemTip, S.tipClock = g, 0 end)
	g.hit:SetScript("OnLeave", function()
		if S.gemTip == g then S.gemTip = nil end
		if GameTooltip then GameTooltip:Hide() end
	end)
	return g
end

local function Build()
	root = CreateFrame("Frame", "CreedUILuck", UIParent)
	root:SetFrameStrata("MEDIUM")
	root:SetWidth(W)
	root:SetHeight(H)
	root:SetClampedToScreen(true)
	root:SetScale(db.scale)
	root:EnableMouse(true)
	root:Hide()
	-- glass, a metal line round it, diamonds at the head's ends: the meter's window, which sits on it
	root.glass = C.Tex(root, "BACKGROUND", C.FLAT)
	root.glass:SetAllPoints(root)
	root.glass:SetGradientAlpha("VERTICAL", 0.02, 0.02, 0.03, 0.86, 0.07, 0.07, 0.09, 0.80)
	root.headBg = C.Tex(root, "BORDER", C.FLAT)
	root.headBg:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0)
	root.headBg:SetPoint("TOPRIGHT", root, "TOPRIGHT", 0, 0)
	root.headBg:SetHeight(HEAD)
	root.lines = {}
	for i = 1, 6 do root.lines[i] = C.Tex(root, "BORDER", C.FLAT) end
	local L = root.lines
	L[1]:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0); L[1]:SetPoint("TOPRIGHT", root, "TOPRIGHT", 0, 0); L[1]:SetHeight(1)
	L[2]:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", 0, 0); L[2]:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", 0, 0); L[2]:SetHeight(1)
	L[3]:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0); L[3]:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", 0, 0); L[3]:SetWidth(1)
	L[4]:SetPoint("TOPRIGHT", root, "TOPRIGHT", 0, 0); L[4]:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", 0, 0); L[4]:SetWidth(1)
	L[5]:SetPoint("TOPLEFT", root, "TOPLEFT", 6, -HEAD); L[5]:SetPoint("TOPRIGHT", root, "TOPRIGHT", -6, -HEAD); L[5]:SetHeight(1)
	L[6]:SetPoint("TOPLEFT", root, "TOPLEFT", 14, -97); L[6]:SetPoint("TOPRIGHT", root, "TOPRIGHT", -14, -97); L[6]:SetHeight(1)
	root.gemL = C.Tex(root, "ARTWORK", C.ART .. "Diamond")
	root.gemL:SetWidth(9)
	root.gemL:SetHeight(9)
	root.gemL:SetPoint("CENTER", root, "TOPLEFT", 0, -HEAD)
	root.gemR = C.Tex(root, "ARTWORK", C.ART .. "Diamond")
	root.gemR:SetWidth(9)
	root.gemR:SetHeight(9)
	root.gemR:SetPoint("CENTER", root, "TOPRIGHT", 0, -HEAD)

	-- the head: a four-leaf clover, the title, the x
	root.clover = C.Tex(root, "ARTWORK", C.ART .. "LuckClover")
	root.clover:SetWidth(18)
	root.clover:SetHeight(18)
	root.clover:SetPoint("LEFT", root, "TOPLEFT", 6, -HEAD * 0.5)
	root.clover:SetVertexColor(LUCK[1], LUCK[2], LUCK[3])
	root.title = C.Text(root, C.TITLE_FONT, 14, nil, "LEFT", 120)
	root.title:SetPoint("LEFT", root.clover, "RIGHT", 4, 0)
	C.LText(root.title, "Luck")
	-- x hides it (the clover on the minimap's edge brings it back), as the meter's
	root.close = CreateFrame("Button", nil, root)
	root.close:SetWidth(16)
	root.close:SetHeight(16)
	root.close:SetPoint("RIGHT", root, "TOPRIGHT", -4, -HEAD * 0.5)
	root.close.text = C.Text(root.close, C.FONT, 10, nil, "CENTER", 16)
	root.close.text:SetPoint("CENTER", root.close, "CENTER", 0, 0)
	root.close.text:SetText("x")
	root.close.text:SetTextColor(0.78, 0.74, 0.66)
	root.close:SetScript("OnClick", function()
		db.shown = false
		if C.RefreshHub then C.RefreshHub() end
	end)
	root.close:SetScript("OnEnter", function()
		root.close.text:SetTextColor(1, 0.9, 0.6)
		if GameTooltip then
			GameTooltip:SetOwner(root.close, "ANCHOR_LEFT")
			GameTooltip:AddLine(C.L("Hide the luck window (the clover on the minimap's edge brings it back)"), 1, 1, 1, 1)
			C.ShowTip()
		end
	end)
	root.close:SetScript("OnLeave", function()
		root.close.text:SetTextColor(0.78, 0.74, 0.66)
		if GameTooltip then GameTooltip:Hide() end
	end)

	-- the medallion: the luck the cards roll with, a halo that brightens as luck comes in
	root.halo = C.Tex(root, "BORDER", C.ART .. "Glow", "ADD")
	root.halo:SetWidth(MEDAL * 1.8)
	root.halo:SetHeight(MEDAL * 1.8)
	root.halo:SetPoint("CENTER", root, "TOPLEFT", MX, MY)
	root.medal = C.Tex(root, "ARTWORK", C.ART .. "LuckMedal")
	root.medal:SetWidth(MEDAL)
	root.medal:SetHeight(MEDAL)
	root.medal:SetPoint("CENTER", root, "TOPLEFT", MX, MY)
	root.total = C.Text(root, C.FONT, 14, "OUTLINE", "CENTER", MEDAL)
	root.total:SetPoint("CENTER", root, "TOPLEFT", MX, MY + 3)
	root.total:SetTextColor(LUCK[1], LUCK[2], LUCK[3])
	root.totalSize = 14
	root.word = C.Text(root, C.FONT, 8, nil, "CENTER", MEDAL)
	root.word:SetPoint("CENTER", root, "TOPLEFT", MX, MY - 10)

	-- the gems, and under them where the luck comes from and what it's worth
	root.gems = {}
	for i = 1, table.getn(RARITIES) do root.gems[i] = NewGem(i, RARITIES[i]) end
	root.foot1 = C.Text(root, C.FONT, 9, nil, "CENTER", W - 12)
	root.foot1:SetPoint("TOP", root, "TOP", 0, -102)
	root.foot1:SetTextColor(0.72, 0.70, 0.64)
	root.foot2 = C.Text(root, C.FONT, 9, nil, "CENTER", W - 12)
	root.foot2:SetPoint("TOP", root, "TOP", 0, -114)
	root.foot2:SetTextColor(0.96, 0.72, 0.40)
end

-- everything that goes by the width: the gems share what the medallion leaves
local function Layout()
	C.Width(root, W)
	C.Width(root.foot1, W - 12)
	C.Width(root.foot2, W - 12)
	local left, right = MEDAL_X + MEDAL + 6, W - 6
	local col = (right - left) / 3
	local size = col >= 46 and 11 or 10 -- narrow, the odds a size smaller so a "1 in 100" keeps to its gem
	for i = 1, table.getn(root.gems) do
		local g = root.gems[i]
		local x = left + col * (i - 0.5)
		C.Place(g.glow, "CENTER", root, "TOPLEFT", x, GEM_Y)
		C.Place(g.bezel, "CENTER", root, "TOPLEFT", x, GEM_Y)
		C.Place(g.orb, "CENTER", root, "TOPLEFT", x, GEM_Y)
		C.Place(g.glint, "CENTER", root, "TOPLEFT", x, GEM_Y)
		C.Place(g.name, "CENTER", root, "TOPLEFT", x, NAME_Y)
		C.Place(g.odds, "CENTER", root, "TOPLEFT", x, ODDS_Y)
		C.Width(g.name, col + 8)
		C.Width(g.odds, col + 8)
		C.Place(g.hit, "TOP", root, "TOPLEFT", x, GEM_Y + 18)
		C.Width(g.hit, col)
		if g.size ~= size then
			g.size = size
			C.SetFace(g.odds, C.FONT, size, "OUTLINE")
		end
	end
end

local function Theme(pal)
	local rim, t = pal.rim, pal.title
	for i = 1, 4 do root.lines[i]:SetVertexColor(rim[1], rim[2], rim[3], 0.45) end
	root.lines[5]:SetVertexColor(rim[1], rim[2], rim[3], 0.3)
	root.lines[6]:SetVertexColor(rim[1], rim[2], rim[3], 0.16)
	root.gemL:SetVertexColor(rim[1], rim[2], rim[3])
	root.gemR:SetVertexColor(rim[1], rim[2], rim[3])
	root.headBg:SetGradientAlpha("VERTICAL", 0, 0, 0, 0.2, t[1] * 0.25, t[2] * 0.25, t[3] * 0.25, 0.35)
	root.title:SetTextColor(t[1], t[2], t[3])
	-- the medallion and the settings in the bronze of the skill bar's panel
	local mr, mg, mb = C.PanelMetal(pal)
	root.medal:SetVertexColor(mr, mg, mb)
	for i = 1, table.getn(root.gems) do root.gems[i].bezel:SetVertexColor(mr, mg, mb) end
end

------------------------------------------------------------------------ the tooltips
local function ShowTip(luck, level)
	if not GameTooltip then return end
	local bonus = LevelBonus(level)
	GameTooltip:SetOwner(root, "ANCHOR_LEFT")
	GameTooltip:AddLine(C.L("Luck"), LUCK[1], LUCK[2], LUCK[3])
	GameTooltip:AddDoubleLine(C.L("Yours"), Whole(luck), 0.8, 0.8, 0.8, 1, 1, 1)
	local gear = type(AZS_STATS) == "table" and tonumber(AZS_STATS.gluck) or nil
	if gear and gear ~= 0 then
		GameTooltip:AddDoubleLine("  " .. C.L("of it from your gear"), string.format("%+.0f%%", gear * 100), 0.6, 0.6, 0.6, 0.8, 0.8, 0.8)
	end
	GameTooltip:AddDoubleLine(C.F("Level {1}", level), "+" .. Whole(bonus), 0.8, 0.8, 0.8, 1, 1, 1)
	GameTooltip:AddDoubleLine(C.L("Your cards roll with"), Whole(luck + bonus), 0.8, 0.8, 0.8, LUCK[1], LUCK[2], LUCK[3])
	if S.startLuck and luck - S.startLuck > 0.004 then
		GameTooltip:AddDoubleLine(C.L("Gained this run"), string.format("+%.0f%%", (luck - S.startLuck) * 100), 0.8, 0.8, 0.8, LUCK[1], LUCK[2], LUCK[3])
	end
	GameTooltip:AddLine(C.L("Each level adds 1%, up to 30%."), 0.62, 0.62, 0.62, 1)
	C.ShowTip()
end

local function ShowGemTip(g)
	if not GameTooltip then return end
	local c, p = g.rar.color, odds[g.rar.index] or 0
	GameTooltip:SetOwner(g.hit, "ANCHOR_TOP")
	GameTooltip:AddLine(C.L(g.rar.name), c[1], c[2], c[3])
	GameTooltip:AddDoubleLine(C.L("Each card"), Pct(p) .. "  (" .. OneIn(p) .. ")", 0.8, 0.8, 0.8, 1, 1, 1)
	GameTooltip:AddDoubleLine(C.L("A level-up's three cards"), Pct(1 - (1 - p) * (1 - p) * (1 - p)), 0.8, 0.8, 0.8, 1, 1, 1)
	if g.rar.index < 5 then
		local better = 0
		for k = g.rar.index, 5 do better = better + (odds[k] or 0) end
		GameTooltip:AddDoubleLine(C.F("{1} or better, each card", C.L(g.rar.name)), Pct(better), 0.8, 0.8, 0.8, 1, 1, 1)
	end
	C.ShowTip()
end

------------------------------------------------------------------------ every frame
local function Values(phase)
	local stats = type(AZS_STATS) == "table" and AZS_STATS or nil
	if stats and tonumber(stats.luck) and phase then
		local run = type(AZS_RUN) == "table" and AZS_RUN or {}
		local level = tonumber(run.lvl) or Call(UnitLevel, "player") or 1
		return tonumber(stats.luck), level, false
	end
	if C.unlocked then return SAMPLE.luck, SAMPLE.level, true end
	return nil
end

-- luck gained shows on the medallion; a new run starts the count of it
local function Watch(luck, sample)
	local runId = type(AZS_ZONE) == "table" and AZS_ZONE.run or nil
	if runId ~= S.run then S.run, S.startLuck, S.lastLuck = runId, nil, nil end
	if not luck or sample then return end
	if not S.startLuck then S.startLuck = luck end
	if S.lastLuck and luck > S.lastLuck + 0.004 then
		S.gainT, S.gainText = GAIN_FOR, string.format("+%.0f%%", (luck - S.lastLuck) * 100)
		S.halo = 1
	end
	S.lastLuck = luck
end

-- the words, made again only when the luck or the level changes
local function Words(luck, level)
	local bonus = LevelBonus(level)
	local total = luck + bonus
	Odds(1 + total, odds)
	C.SetText(root.total, Whole(total))
	local size = total >= 0.995 and 12 or 14
	if root.totalSize ~= size then
		root.totalSize = size
		C.SetFace(root.total, C.FONT, size, "OUTLINE")
	end
	C.SetText(root.foot1, C.F("{1} yours, +{2} from level {3}", Whole(luck), Whole(bonus), level))
	C.SetText(root.foot2, Every(odds[5]))
	for i = 1, table.getn(root.gems) do
		local g = root.gems[i]
		local p = odds[g.rar.index]
		if g.p and p > g.p + 1e-6 then g.flash = 1 end -- likelier now: a flash
		g.p = p
		C.SetText(g.odds, OneIn(p))
	end
end

local function Step(dt)
	local now = GetTime()
	local phase = Call(AZS_GetPhase)
	local luck, level, sample = nil, nil, false
	if db.enabled then luck, level, sample = Values(phase) end
	Watch(luck, sample)
	-- hidden with its x (or the gem), and away while the cards are up
	local want = (luck and (db.shown or C.unlocked) and not C.cardsUp) and 1 or 0
	S.alpha = C.Toward(S.alpha, want, 8, dt)
	if want == 1 and S.alpha > 0.995 then S.alpha = 1 end
	if S.alpha < 0.01 and want == 0 then
		C.Vis(root, false)
		if S.sizer then
			S.sizer.hover, S.sizer.active = nil, nil
			C.Vis(S.sizer.arrow, false)
		end
		return
	end
	C.Vis(root, true)
	C.Alpha(root, C.Smooth(S.alpha))
	if S.sizer then S.sizer.step() end
	if not luck then return end
	local pal = C.Pal()
	if S.stamp ~= C.palStamp then
		S.stamp = C.palStamp
		Theme(pal)
	end
	if S.luck ~= luck or S.level ~= level or S.lang ~= C.langStamp then
		S.luck, S.level, S.lang = luck, level, C.langStamp
		Words(luck, level)
	end

	-- the gems glow by how likely they are, and flash as they get likelier; the legendary's glint breathes
	for i = 1, table.getn(root.gems) do
		local g = root.gems[i]
		local c = g.rar.color
		g.glowA = C.Toward(g.glowA, 0.1 + 0.4 * C.Clamp((g.p or 0) / g.rar.full, 0, 1), 4, dt)
		if g.flash > 0 then g.flash = math.max(0, g.flash - dt * 1.4) end
		C.Color(g.glow, c[1], c[2], c[3], math.min(1, g.glowA + 0.55 * C.Smooth(g.flash)))
		if g.rar.index == 5 then C.Alpha(g.glint, 0.6 + 0.35 * math.sin(now * 2.1)) end
	end
	-- the medallion: a gain in place of its word for a while, its halo brighter
	S.halo = math.max(0, (S.halo or 0) - dt * 0.8)
	C.Color(root.halo, LUCK[1], LUCK[2], LUCK[3], 0.12 + 0.55 * C.Smooth(S.halo))
	if S.gainT > 0 then
		S.gainT = math.max(0, S.gainT - dt)
		C.SetText(root.word, S.gainText)
		local k = C.Smooth(math.min(1, S.gainT / 0.6))
		C.TextColor(root.word, 0.7 + (LUCK[1] - 0.7) * k, 0.66 + (LUCK[2] - 0.66) * k, 0.56 + (LUCK[3] - 0.56) * k)
	else
		C.SetText(root.word, C.L("luck"))
		C.TextColor(root.word, 0.7, 0.66, 0.56)
	end

	if S.tipOn or S.gemTip then
		S.tipClock = (S.tipClock or 0) - dt
		if S.tipClock <= 0 then
			S.tipClock = 0.25
			if S.gemTip then ShowGemTip(S.gemTip) else ShowTip(luck, level) end
		end
	end
end

------------------------------------------------------------------------ setup
-- by the bottom right corner, clear of the kills and gold strip (the meter sits on top of it)
local function Anchor(f)
	f:ClearAllPoints()
	f:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -58, 60)
end

-- sizing: its sides make it wider or narrower (the gems spread), its corners bigger or smaller,
-- the side or corner across from the mouse staying put
local function Sizing(mover)
	local z = {}
	local function Has(edge, part) return string.find(edge, part) ~= nil end
	S.sizer = C.Sizers(root, "CreedUILuckSizer", {
		edges = { LEFT = true, RIGHT = true, TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true },
		can = function() return not (CreedUIDB and CreedUIDB.lockWindows) end,
		start = function(edge)
			local s = root:GetEffectiveScale() / UIParent:GetEffectiveScale()
			z.s, z.scale, z.w = s, root:GetScale(), W
			z.l, z.r, z.t, z.b = root:GetLeft() * s, root:GetRight() * s, root:GetTop() * s, root:GetBottom() * s
		end,
		move = function(edge, dx, dy)
			if edge == "LEFT" or edge == "RIGHT" then
				local l, r = z.l, z.r
				if edge == "LEFT" then l = C.Clamp(l + dx, r - MAX_W * z.s, r - MIN_W * z.s)
				else r = C.Clamp(r + dx, l + MIN_W * z.s, l + MAX_W * z.s) end
				W = math.floor((r - l) / z.s + 0.5)
				Layout()
				root:ClearAllPoints()
				root:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l / z.s, z.t / z.s)
				return
			end
			-- a corner: bigger or smaller, the corner across from it in place
			local w, h = z.r - z.l, z.t - z.b
			local rx = (w + (Has(edge, "RIGHT") and dx or -dx)) / w
			local ry = (h + (Has(edge, "TOP") and dy or -dy)) / h
			local scale = C.Clamp(z.scale * (rx + ry) * 0.5, MIN_SCALE, MAX_SCALE)
			local k = scale / z.scale * z.s -- the frame's units in UIParent's, now
			root:SetScale(scale)
			local fx = Has(edge, "RIGHT") and z.l or z.r
			local fy = Has(edge, "TOP") and z.b or z.t
			local corner = (Has(edge, "TOP") and "BOTTOM" or "TOP") .. (Has(edge, "RIGHT") and "LEFT" or "RIGHT")
			root:ClearAllPoints()
			root:SetPoint(corner, UIParent, "BOTTOMLEFT", fx / k, fy / k)
		end,
		stop = function(edge)
			db.width, db.scale = W, root:GetScale()
			root.mw, root.mpx = nil, nil
			C.SavePos(mover)
		end,
	})
	S.sizer.levels(root:GetFrameLevel() + 6)
end

C.OnInit(function()
	db = C.DB("luck", DEFAULTS)
	db.edgeAngle = nil -- the former minimap toggle now lives in Creed UI Options
	db.source = nil -- the old window's choice of drop, gone with it
	W = C.Clamp(tonumber(db.width) or DEFAULTS.width, MIN_W, MAX_W)
	db.scale = C.Clamp(tonumber(db.scale) or 1, MIN_SCALE, MAX_SCALE)
	Build()
	Layout()
	root:SetScript("OnEnter", function() S.tipOn, S.tipClock = true, 0 end)
	root:SetScript("OnLeave", function()
		S.tipOn = false
		if GameTooltip then GameTooltip:Hide() end
	end)
	local mover = C.Movable(root, "luck", "Luck", Anchor)
	C.OverCards(root) -- lit over the level-up cards' veil (Core)
	-- drag it anywhere on it (its gems too) to move it
	local drag = C.Draggable(root, mover)
	for i = 1, table.getn(root.gems) do drag.handle(root.gems[i].hit) end
	Sizing(mover)
	local driver = CreateFrame("Frame", "CreedUILuckDriver")
	local broken = false
	driver:SetScript("OnUpdate", function()
		if broken then return end
		local dt = arg1 or 0
		if dt > 0.1 then dt = 0.1 end
		local ok, err = pcall(Step, dt)
		if not ok then
			broken = true
			root:Hide()
			C.Print(C.L("the luck window stopped after an error: ") .. tostring(err))
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
	key = "luck", name = "Luck",
	note = "Your luck on a bronze medallion, and the chance of a Rare, Epic or Legendary card as three gems (1 in N); luck you gain shows on the medallion. Drag its sides to widen it, its corners to size it; use the Luck toggle in Creed UI Options to show or hide the window.",
	get = function() return db and db.enabled and db.shown end,
	set = function(on)
		if db then
			if on then db.enabled, db.shown = true, true else db.shown = false end
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
