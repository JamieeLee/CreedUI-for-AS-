--[[
Creed UI: damage numbers (Smooth Numbers) - calmer, cleaner damage numbers for Azeroth Survivors.

The game gives addons every hit you deal, with a place in the world to draw it
(its world-anchored combat text API). Smooth Numbers turns the game's own
floating numbers off and draws its own in their place:

  - the hits on one enemy add up into one number that counts up
  - the skill's icon beside each number (then each number is one skill's)
  - a DoT's ticks add up in one number until its enemy dies
  - big numbers are shortened: 12.3K, 1.2M
  - when the screen gets busy only the biggest numbers show
  - numbers that would overlap step aside, or quietly drop out
  - a soft pop, a slow drift, and a smooth melt instead of flying text: every
    fade, push and move is eased (no number ever blinks out or jumps)

A spell hitting a crowd (three or more enemies) adds up into one number a
second over the middle of the enemies it hits; on one or two enemies its hits
show as usual (a DoT's total counting up until the enemy dies).

/creed numbers opens the options. /creed numbers off gives the game its own
numbers back.

Written for the 1.12 client's Lua 5.0: no # operator, no string methods,
table.getn and math.mod, and the this/event/arg1 globals in handlers.
]]

local CUI = CreedUI
-- the words in the language picked (Core); as they are when run on their own
local L = CUI.L or function(s) return s end
local LText = CUI.LText or function(fs, s) fs:SetText(s) end
local VERSION = CUI.VERSION

------------------------------------------------------------------------------
-- Look and timing

local FONT_SIZE = 24            -- every number is drawn at this size, then scaled
local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"

local FADE_IN = 0.1             -- seconds to appear
local HOLD = 0.5                -- a number stays this long after its last hit
local FADE_OUT = 0.55           -- then floats up and melts away this long
local CULL_FADE = 0.3           -- a number pushed out (or slipping away) melts this long
local CROWD_FADE = 0.18         -- one boxed in by others melts quicker, as it overlaps
local SPRING = 14               -- how briskly a number steps aside (a soft spring)
local POP_SPRING = 28           -- how briskly a hit's punch swells in
local EDGE_FADE = 0.2           -- a number leaving (or coming back into) the view
local POP_TIME = 0.18           -- the pop when a number appears
local MAX_AGE = 4.6             -- the game keeps a hit's place for 5 seconds
local STALE = 0.6               -- hits older than this when read are skipped
local BASE_RISE = 16            -- a number starts this far over the enemy
local DRIFT = 22                -- and drifts up this much while it lives
local FADE_RISE = 18            -- and this much more as it fades, gathering pace
local FADE_SHRINK = 0.12        -- and shrinks this much as it fades
local CULL_SHRINK = 0.15        -- a number pushed out shrinks this much as it goes
local GROUP_RADIUS = 70         -- "one number per group": hits this close share one
local CROWD_TIME = 0.06         -- a number boxed in this long fades out
local MIN_SHOW = 0.5            -- once shown, a number stays at least this long
local ICON_SIZE = 22            -- the skill icon, in the number's own units
local ICON_GAP = 4              -- between the icon and the number
local DOT_FIRST_HOLD = 3.4      -- a DoT's number waits this long for the next tick at first
local DOT_MAX_HOLD = 3.9        -- and never longer (the game keeps a hit's place 5 s)
local KILL_HOLD = 1.2           -- a DoT's total stays this long once its enemy dies
local KILL_GRACE = 0.4          -- ticks read just after the death still count
local CROWD_COUNT = 3           -- a spell hitting this many enemies at once merges
local CROWD_TICK = 3.2          -- an enemy counts this long after a DoT's tick on it
local CROWD_HIT = 1.6           -- and this long after any other hit
local MERGE_WINDOW = 1.0        -- a merged number takes one second of its spell's hits
local MAX_SPOTS = 12            -- the enemies a merged number centers over
-- every number a touch smaller (shrink), so one that keeps adding hits has room to grow by up to
-- `grow` over `time` seconds of hits, then hold its size (one table: Lua 5.0 allows 200 locals)
local STACK = { shrink = 0.88, grow = 0.35, time = 1.5 }

-- Icons for hits that come without one: a swing shows the weapon in hand, a
-- shot the ranged one, a damage shield Thorns (read from your gear when it can).
local MELEE_ICON = "Interface\\Icons\\INV_Sword_04"
local SHOT_ICON = "Interface\\Icons\\Ability_Whirlwind"
local SHIELD_ICON = "Interface\\Icons\\Spell_Nature_Thorns"

local FONTS = {
	{ name = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF" },
	{ name = "Arial Narrow", path = "Fonts\\ARIALN.TTF" },
	{ name = "Skurri", path = "Fonts\\SKURRI.TTF" },
	{ name = "Morpheus", path = "Fonts\\MORPHEUS.TTF" },
	-- Creed UI's own, open fonts (Fonts/NumberFonts-LICENSE.txt); in a language written in other
	-- letters (Chinese, Russian...), its bundled face stands in
	{ name = "Cinzel", path = "Interface\\AddOns\\CreedUI\\Fonts\\NumCinzel.ttf", own = true },
	{ name = "Bangers", path = "Interface\\AddOns\\CreedUI\\Fonts\\NumBangers.ttf", own = true },
	{ name = "Creepster", path = "Interface\\AddOns\\CreedUI\\Fonts\\NumCreepster.ttf", own = true },
	{ name = "Uncial Antiqua", path = "Interface\\AddOns\\CreedUI\\Fonts\\NumUncial.ttf", own = true },
	{ name = "Black Ops One", path = "Interface\\AddOns\\CreedUI\\Fonts\\NumBlackOps.ttf", own = true },
	{ name = "Pirata One", path = "Interface\\AddOns\\CreedUI\\Fonts\\NumPirata.ttf", own = true },
}

local COLOR_NORMAL = { 1.00, 0.96, 0.88 }
local COLOR_CRIT = { 1.00, 0.80, 0.18 }
local COLOR_DOT = { 0.86, 0.84, 0.80 }
local COLOR_MISS = { 0.70, 0.70, 0.72 }
local SCHOOL_COLORS = {
	[1] = { 1.00, 0.96, 0.88 },  -- Physical
	[2] = { 1.00, 0.92, 0.55 },  -- Holy
	[4] = { 1.00, 0.55, 0.22 },  -- Fire
	[8] = { 0.50, 1.00, 0.42 },  -- Nature
	[16] = { 0.52, 0.84, 1.00 }, -- Frost
	[32] = { 0.74, 0.52, 1.00 }, -- Shadow
	[64] = { 1.00, 0.58, 1.00 }, -- Arcane
}

-- The three styles. Picking one sets these; the switches can then be changed.
local PRESETS = {
	minimal = { maxLabels = 6, group = true, mergeAge = 1.2, misses = false, minShare = 0.12 },
	clean = { maxLabels = 12, group = false, mergeAge = 0.9, misses = false, minShare = 0 },
	detailed = { maxLabels = 20, group = false, mergeAge = 0.5, misses = true, minShare = 0 },
}
local PRESET_ORDER = { "minimal", "clean", "detailed" }
local PRESET_NAMES = { minimal = "Minimal", clean = "Clean", detailed = "Detailed" }
local PRESET_NOTES = {
	minimal = "Fewest numbers: nearby enemies share one.",
	clean = "One number per enemy, counting up.",
	detailed = "More numbers, sooner, plus Miss and Immune.",
}

-- How the numbers move, picked apart from the style (in STACK: Lua 5.0 allows 200 locals).
-- What a crit wears behind its number (in STACK: Lua 5.0 allows 200 locals): an original picture
-- each, drawn by dev/art/make_art20.py.
STACK.backs = {
	order = { "none", "blood", "fire", "frost", "arcane", "holy", "shadow" },
	names = { none = "None", blood = "Blood", fire = "Fire", frost = "Frost", arcane = "Arcane", holy = "Holy", shadow = "Shadow" },
	tex = { blood = "NumBlood", fire = "NumFlame", frost = "NumFrost", arcane = "NumArcane", holy = "NumHoly", shadow = "NumShadow" },
}

STACK.motion = {
	order = { "smooth", "fountain", "rise", "impact" },
	names = { smooth = "Smooth", fountain = "Fountain", rise = "Rise", impact = "Impact" },
	notes = {
		smooth = "Numbers drift up gently and melt away.",
		fountain = "Numbers arc up and fall away to the side.",
		rise = "Numbers scroll straight up, quickly.",
		impact = "Numbers punch in big and stay put; crits shake.",
	},
}

local DEFAULTS = {
	enabled = true,
	preset = "clean", motion = "smooth", backdrop = "none",
	maxLabels = 12, group = false, mergeAge = 0.9, misses = false, minShare = 0,
	size = 1.0, font = 1,
	short = true, spread = true, count = false, school = false, icons = true,
	dotTotals = true, crowd = true, bySpell = false,
}

local db -- CreedUIDB.numbers, set up when the addon loads

------------------------------------------------------------------------------
-- Small helpers

local function Print(msg)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cffffcc55Creed UI|r " .. L("numbers") .. ": " .. msg)
	end
end

local function Clamp(value, low, high)
	if value < low then return low end
	if value > high then return high end
	return value
end

-- Smoothstep: 0 to 1 with a soft start and a soft end, so nothing on screen
-- ever starts or stops moving (or fading) with a jolt.
local function Smooth(p)
	if p <= 0 then
		return 0
	end
	if p >= 1 then
		return 1
	end
	return p * p * (3 - 2 * p)
end

local function Capitalize(word)
	word = tostring(word or "")
	return string.upper(string.sub(word, 1, 1)) .. string.sub(word, 2)
end

-- 1234567 -> "1,234,567" (%.0f, as %d overflows past two billion)
local function Commas(n)
	local s = string.format("%.0f", math.floor(n + 1e-6))
	local len = string.len(s)
	if len <= 3 then
		return s
	end
	local head = math.mod(len, 3)
	if head == 0 then
		head = 3
	end
	local out = string.sub(s, 1, head)
	local i = head + 1
	while i <= len do
		out = out .. "," .. string.sub(s, i, i + 2)
		i = i + 3
	end
	return out
end

-- 950 -> "950", 1234 -> "1.2K", 12345 -> "12.3K", 123456 -> "123K", 1234567 -> "1.2M".
-- Rounded down, so a number counting up never shows more than it holds.
local UNITS = { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }

local function Short(n)
	for i = 1, 4 do
		local unit = UNITS[i]
		if n >= unit[1] then
			local v = n / unit[1]
			if v >= 100 then
				return string.format("%.0f", math.floor(v + 1e-6)) .. unit[2]
			end
			v = math.floor(v * 10 + 1e-6) / 10
			local text = string.format("%.1f", v)
			if string.sub(text, -2) == ".0" then
				text = string.sub(text, 1, -3)
			end
			return text .. unit[2]
		end
	end
	return string.format("%.0f", math.floor(n + 1e-6))
end

local function FormatAmount(n)
	if n < 0 then
		n = 0
	end
	if db and db.short == false then
		return Commas(n)
	end
	return Short(n)
end

------------------------------------------------------------------------------
-- Settings

local function InitDB()
	db = CUI.DB("numbers")
	for key, value in pairs(DEFAULTS) do
		if db[key] == nil or type(db[key]) ~= type(value) then
			db[key] = value
		end
	end
	if not PRESETS[db.preset] then
		db.preset = "clean"
	end
	db.size = Clamp(db.size, 0.6, 1.8)
	db.maxLabels = Clamp(math.floor(db.maxLabels), 1, 80)
	db.mergeAge = Clamp(db.mergeAge, 0.1, 2)
	db.minShare = Clamp(db.minShare, 0, 0.9)
	if not STACK.backs.names[db.backdrop or ""] then
		db.backdrop = "none"
	end
	if not STACK.motion.names[db.motion or ""] then
		db.motion = "smooth"
	end
	if not FONTS[db.font] then
		db.font = 1
	end
end

local function ApplyPreset(name)
	local preset = PRESETS[name]
	if not preset then
		return
	end
	for key, value in pairs(preset) do
		db[key] = value
	end
	db.preset = name
end

------------------------------------------------------------------------------
-- The number widgets: a holder placed on the enemy, a visual inside it that
-- scales (so a pop never moves the number), and the text. Kept in a pool.

local layer = CreateFrame("Frame", "CreedUINumbersLayer", WorldFrame)
layer:SetAllPoints(WorldFrame)
layer:SetFrameStrata("LOW")
layer:EnableMouse(false)

local widgetPool, nWidgetPool = {}, 0
local allWidgets, nAllWidgets = {}, 0

-- the face picked; in a language the game's own face draws (Core), that one
local function FontPath()
	local font = FONTS[db and db.font or 1] or FONTS[1]
	if CUI.Face then
		-- the language's own face when it has one (other letters); else the font picked
		local lang = CUI.Face(font.path)
		if font.own and lang ~= font.path then return lang end
		return lang
	end
	return font.path
end

local function ApplyFont(w)
	local ok = pcall(w.text.SetFont, w.text, FontPath(), FONT_SIZE, "OUTLINE")
	if not ok or not w.text:GetFont() then
		pcall(w.text.SetFont, w.text, FONTS[1].path, FONT_SIZE, "OUTLINE")
	end
	w.lastText = nil
end

local function NewWidget()
	local holder = CreateFrame("Frame", nil, layer)
	holder:SetFrameStrata("LOW")
	holder:SetWidth(1)
	holder:SetHeight(1)
	holder:EnableMouse(false)
	holder:Hide()
	local visual = CreateFrame("Frame", nil, holder)
	visual:SetWidth(320)
	visual:SetHeight(64)
	visual:SetPoint("CENTER", holder, "CENTER", 0, 0)
	visual:EnableMouse(false)
	-- The skill's icon, left of the number, on a thin dark edge.
	local icon = visual:CreateTexture(nil, "OVERLAY")
	icon:SetWidth(ICON_SIZE)
	icon:SetHeight(ICON_SIZE)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	icon:SetPoint("LEFT", visual, "CENTER", 0, 0)
	icon:Hide()
	local edge = visual:CreateTexture(nil, "ARTWORK")
	edge:SetTexture(FLAT)
	edge:SetVertexColor(0, 0, 0, 0.8)
	edge:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
	edge:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
	edge:Hide()
	local text = visual:CreateFontString(nil, "OVERLAY")
	text:SetPoint("LEFT", visual, "CENTER", 0, 0)
	-- Wide on purpose: a tight width makes the client cut digits into "...".
	-- Left-aligned, and placed so icon and number sit centred together.
	text:SetWidth(420)
	text:SetHeight(FONT_SIZE * 2)
	text:SetJustifyH("LEFT")
	text:SetJustifyV("MIDDLE")
	text:SetShadowColor(0, 0, 0, 0.9)
	text:SetShadowOffset(1, -1)
	-- a crit's backdrop (Blood, Fire...), behind the icon and the number
	local back = visual:CreateTexture(nil, "BACKGROUND")
	back:SetPoint("CENTER", visual, "CENTER", 0, 0)
	back:Hide()
	local w = { holder = holder, visual = visual, text = text, icon = icon, edge = edge, back = back }
	ApplyFont(w)
	nAllWidgets = nAllWidgets + 1
	allWidgets[nAllWidgets] = w
	return w
end

-- Centres the icon (if any) and the number together on the spot. As the
-- number grows a digit, the pair glides to its new centre instead of jumping.
local function Layout(w, textWidth, iconPath, dt)
	local block = textWidth
	if iconPath then
		block = ICON_SIZE + ICON_GAP + textWidth
		if w.iconPath ~= iconPath then
			w.icon:SetTexture(iconPath)
			w.iconPath = iconPath
		end
	end
	w.block = block
	local target = -block / 2
	if w.left == nil or w.layoutIcon ~= iconPath then
		w.left = target
	else
		w.left = w.left + (target - w.left) * (1 - math.exp(-dt * 22))
	end
	local left = math.floor(w.left + 0.5)
	if w.layoutLeft == left and w.layoutIcon == iconPath then
		return
	end
	w.layoutLeft, w.layoutIcon = left, iconPath
	if iconPath then
		w.icon:SetPoint("LEFT", w.visual, "CENTER", left, 0)
		w.text:SetPoint("LEFT", w.visual, "CENTER", left + ICON_SIZE + ICON_GAP, 0)
		w.icon:Show()
		w.edge:Show()
	else
		w.text:SetPoint("LEFT", w.visual, "CENTER", left, 0)
		w.icon:Hide()
		w.edge:Hide()
	end
end

local function AcquireWidget()
	local w
	if nWidgetPool > 0 then
		w = widgetPool[nWidgetPool]
		widgetPool[nWidgetPool] = nil
		nWidgetPool = nWidgetPool - 1
	else
		w = NewWidget()
	end
	w.lastText, w.scale, w.alpha, w.px, w.py = nil, nil, nil, nil, nil
	w.r, w.g, w.b, w.shown = nil, nil, nil, false
	w.layoutIcon, w.layoutLeft, w.left = false, nil, nil
	return w
end

local function ReleaseWidget(w)
	w.holder:Hide()
	w.shown = false
	nWidgetPool = nWidgetPool + 1
	widgetPool[nWidgetPool] = w
end

local function ApplyFontAll()
	for i = 1, nAllWidgets do
		ApplyFont(allWidgets[i])
	end
end

local function RefreshAllText()
	for i = 1, nAllWidgets do
		allWidgets[i].lastText = nil
		allWidgets[i].layoutIcon = false
	end
end

-- a language in other letters draws the numbers in the game's own face (Core): faces again
if CUI.OnLanguage then
	CUI.OnLanguage(function()
		if db then
			ApplyFontAll()
			RefreshAllText()
		end
	end)
end

------------------------------------------------------------------------------
-- Labels: one number on screen and the hits it holds.

local labels, nLabels = {}, 0
local byKey, missByKey = {}, {} -- the open number for an enemy (and skill)
local nextLabelId = 0
local pending, nPending = {}, 0
local bossNames = {}
local frameNow = 0           -- the time of the frame being worked on
local crowdTargets = {}      -- per spell: enemy -> until when it counts as hit
local dotCrowd, crowdAt, crowdUntil = {}, {}, {}

-- How long a DoT's number waits for its next tick: a bit more than the
-- longest wait seen between its ticks so far.
local function DotHold(label)
	if label.tickGap then
		return Clamp(label.tickGap * 1.25 + 0.35, 1, DOT_MAX_HOLD)
	end
	return DOT_FIRST_HOLD
end

-- Whether a number still takes hits. A DoT's stays open as long as the DoT
-- keeps ticking, until its enemy dies; any other closes after a moment.
local function IsOpen(label, now)
	if label == nil or label.dead then
		return false
	end
	if label.finished then
		return now - label.finishAt < KILL_GRACE
	end
	if label.merged then
		return now - label.born < MERGE_WINDOW
	end
	if label.dot then
		return now - label.lastHit < DotHold(label)
	end
	return now - label.born < db.mergeAge and now - label.lastHit < HOLD
end

-- What dealt a hit: the damage meter's line it counts toward when the hit says (a proc floating
-- in another spell's look is its own; a skill's ranks are one), else its spell, else how it landed
-- (a pet's swing is not yours).
local function SkillOf(ev)
	local m = ev.meterSourceKey
	if type(m) == "string" and m ~= "" then
		local skill = ev.cuiSkill
		if not skill then
			skill = "m" .. (string.gsub(m, ":r%d+.*$", "")) .. "|" .. tostring(ev.meterSource or "") .. "|" .. tostring(ev.sourceKind or "player")
			ev.cuiSkill = skill
		end
		return skill
	end
	if ev.spellId then
		return "s" .. ev.spellId
	end
	if ev.abilityName then
		return "n" .. ev.abilityName
	end
	if ev.reflected then
		return "shield"
	end
	return (ev.sourceKind or "player") .. ":" .. (ev.damageType or "melee")
end

-- Every spell counts the enemies it hit lately. On a crowd (three or more) its
-- hits merge, and stay merged two seconds after the crowd thins out, so it
-- can't flip back and forth around three.
local function NoteHit(ev, now)
	if not (ev.kind == "damage" and ev.targetId) then
		return
	end
	local skill = SkillOf(ev)
	local t = crowdTargets[skill]
	if not t then
		t = {}
		crowdTargets[skill] = t
	end
	local untilAt = now + (ev.periodic and CROWD_TICK or CROWD_HIT)
	if not t[ev.targetId] or t[ev.targetId] < untilAt then
		t[ev.targetId] = untilAt
	end
end

local function Crowded(skill, now)
	if crowdAt[skill] == now then
		return dotCrowd[skill]
	end
	crowdAt[skill] = now
	local t = crowdTargets[skill]
	local n = 0
	if t then
		for id, untilAt in pairs(t) do
			if untilAt < now then
				t[id] = nil
			else
				n = n + 1
			end
		end
	end
	if n >= CROWD_COUNT then
		crowdUntil[skill] = now + 2
	end
	dotCrowd[skill] = (crowdUntil[skill] or 0) > now
	return dotCrowd[skill]
end

-- Whether a hit joins its spell's one number a second (over the middle of the
-- enemies it hit) instead of a number on its enemy.
local function Merges(ev)
	if ev.kind ~= "damage" then
		return false
	end
	if db.bySpell then
		return true
	end
	return db.crowd and Crowded(SkillOf(ev), frameNow) or false
end

-- A tick of a DoT, with "DoT totals" on (and not merged with a crowd).
local function IsDotTick(ev)
	return ev.periodic and ev.kind == "damage" and db.dotTotals and not Merges(ev)
end

-- With icons on, every number holds one skill's hits on one enemy, so its
-- icon is always right; with them off, one number holds all of an enemy's.
local function KeyOf(ev)
	if not ev.targetId then
		return nil
	end
	if Merges(ev) then
		return "spell#" .. SkillOf(ev)
	end
	if IsDotTick(ev) then
		-- A DoT's ticks add up in a number of their own, apart from the hits.
		if db.icons then
			return ev.targetId .. "#dot#" .. SkillOf(ev)
		end
		return ev.targetId .. "#dot"
	end
	if db.icons then
		return ev.targetId .. "#" .. SkillOf(ev)
	end
	return ev.targetId
end

local meleeIcon, shotIcon, summonIcon, totemIcon = MELEE_ICON, SHOT_ICON, nil, nil
local petIcon, classPetIcon = nil, nil
local summonById = {}          -- a summon's id -> { icon, seen }, kept a little after it goes
local idsMatch, idsMiss = 0, 0 -- whether hits name their attacker with the summon list's ids
local petsStamp
-- what a pet or summon's swing shows when nothing better is known: the class's own summoning art
local CLASS_PET_ICONS = {
	HUNTER = "Interface\\Icons\\Ability_Hunter_BeastCall",
	WARLOCK = "Interface\\Icons\\Spell_Shadow_SummonImp",
	SHAMAN = "Interface\\Icons\\Spell_Nature_SpiritWolf",
	DRUID = "Interface\\Icons\\Spell_Nature_Regeneration",
	MAGE = "Interface\\Icons\\Spell_Frost_FrostBolt02",
}

local function GearIcon(slot)
	if type(GetInventoryItemTexture) ~= "function" then
		return nil
	end
	local ok, texture = pcall(GetInventoryItemTexture, "player", slot)
	if ok and type(texture) == "string" and texture ~= "" then
		return texture
	end
	return nil
end

-- Your pets and summons: each one's icon by its id (when a swing names its
-- attacker), the main pet's (the one that stays), and the most numerous
-- temporary summons' (Infernals, Legion Gate's demons...).
local function RefreshSummonIcons(now)
	petIcon, summonIcon = nil, nil
	now = now or 0
	if type(AZS_GetSummonGroups) == "function" then
		local ok, groups = pcall(AZS_GetSummonGroups)
		if ok and type(groups) == "table" then
			local most = 0
			for i = 1, table.getn(groups) do
				local g = groups[i]
				if type(g) == "table" and type(g.icon) == "string" and g.icon ~= "" then
					if not petIcon and (tonumber(g.permanent) or 0) > 0 then petIcon = g.icon end
					local temporary = tonumber(g.temporary) or 0
					if temporary > most then summonIcon, most = g.icon, temporary end
					if not petIcon and g.kind == "pet" then petIcon = g.icon end
				end
			end
			if not petIcon and type(groups[1]) == "table" and type(groups[1].icon) == "string" then petIcon = groups[1].icon end
			summonIcon = summonIcon or petIcon
		end
	end
	if type(AZS_GetSummons) == "function" then
		local ok, list = pcall(AZS_GetSummons)
		if ok and type(list) == "table" then
			for i = 1, table.getn(list) do
				local one = list[i]
				if type(one) == "table" and one.id ~= nil and type(one.icon) == "string" and one.icon ~= "" then
					local key = tostring(one.id)
					local rec = summonById[key]
					if not rec then
						rec = {}
						summonById[key] = rec
					end
					rec.icon, rec.seen = one.icon, now
				end
			end
		end
	end
	-- one that's gone stays a while: its last hits can still be on their way
	for key, rec in pairs(summonById) do
		if now - rec.seen > 8 then
			summonById[key] = nil
		end
	end
	if type(UnitClass) == "function" then
		local ok, _, class = pcall(UnitClass, "player")
		classPetIcon = ok and CLASS_PET_ICONS[class or ""] or nil
	end
end

-- The first totem out's icon (Searing and Magma's own hits name their spell anyway).
local function TotemIcon()
	if type(AZS_GetTotems) ~= "function" then
		return nil
	end
	local ok, list = pcall(AZS_GetTotems)
	if ok and type(list) == "table" then
		for i = 1, table.getn(list) do
			local t = list[i]
			if type(t) == "table" and type(t.icon) == "string" and t.icon ~= "" then
				return t.icon
			end
		end
	end
	return nil
end

-- Read now and then: the weapon in hand, the summons and totem out.
local function RefreshFallbackIcons(now)
	meleeIcon = GearIcon(16) or MELEE_ICON
	shotIcon = GearIcon(18) or SHOT_ICON
	RefreshSummonIcons(now)
	totemIcon = TotemIcon()
end

-- The summon list changes as they come and go: read it again the moment it does.
local function WatchSummons(now)
	local stamp = AZS_PETS_UPDATED
	if stamp ~= petsStamp then
		petsStamp = stamp
		RefreshSummonIcons(now)
	end
end

-- Do hits name their attacker with the summon list's own ids? Every pet or summon hit counts,
-- and the ids are trusted once they keep matching (the game may number them apart).
local function NoteSource(ev)
	local source = ev.sourceKind
	if not source or source == "player" or source == "totem" or ev.sourceId == nil then
		return
	end
	if summonById[tostring(ev.sourceId)] then
		idsMatch = idsMatch + 1
	else
		idsMiss = idsMiss + 1
	end
	if idsMatch + idsMiss > 400 then
		idsMatch, idsMiss = idsMatch * 0.5, idsMiss * 0.5
	end
end

local function IconOf(ev)
	-- your proc in another spell's look (Shadow Weaving floating as Shadow Word: Pain): the icon of
	-- its own line, as the meter shows it, when the game has one
	local own = ev.meterSource
	if type(own) == "string" and own ~= "" and ev.abilityName and own ~= ev.abilityName
		and (ev.sourceKind == nil or ev.sourceKind == "player") then
		local art = (CUI.SourceIcon and CUI.SourceIcon(ev.meterSourceKey)) or (CUI.icons and CUI.icons[own])
		if art then
			return art
		end
	end
	local icon = ev.icon
	-- A question mark means the game has no art for it: use the fallbacks.
	if type(icon) == "string" and icon ~= "" and not string.find(string.lower(icon), "questionmark", 1, true) then
		if not string.find(icon, "[\\/]") then
			icon = "Interface\\Icons\\" .. icon -- a bare name
		end
		return icon
	end
	if ev.reflected then
		return SHIELD_ICON
	end
	local source = ev.sourceKind
	if source == "totem" then
		return totemIcon
	end
	if source and source ~= "player" then
		-- a pet's or summon's swing: that very one's icon when the hit names it and the ids
		-- have proved to be the summon list's
		if ev.sourceId ~= nil and idsMatch >= 4 and idsMatch >= idsMiss * 4 then
			local rec = summonById[tostring(ev.sourceId)]
			if rec then
				return rec.icon
			end
		end
		if source == "pet" then
			return petIcon or summonIcon or classPetIcon
		end
		return summonIcon or petIcon or classPetIcon
	end
	if ev.spellId or ev.damageType == "spell" then
		return nil -- a spell the game has no art for: no icon beats a wrong one
	end
	if ev.damageType == "ranged" then
		return shotIcon
	end
	return meleeIcon
end

local function Retire(label)
	label.dead = true
	if label.w then
		ReleaseWidget(label.w)
		label.w = nil
	end
	if label.key then
		if byKey[label.key] == label then
			byKey[label.key] = nil
		end
		if missByKey[label.key] == label then
			missByKey[label.key] = nil
		end
	end
end

local function ClearAll()
	for i = 1, nLabels do
		Retire(labels[i])
		labels[i] = nil
	end
	nLabels = 0
	byKey, missByKey = {}, {}
	for i = 1, nPending do
		pending[i] = nil
	end
	nPending = 0
end

local function MissWord(ev)
	local result = ev.result
	if type(result) == "table" then
		if type(result.text) == "string" and result.text ~= "" then
			return result.text
		end
		if result.key then
			return L(Capitalize(result.key))
		end
	end
	return L("Miss")
end

local function NewLabel(ev, now)
	nextLabelId = nextLabelId + 1
	local amount = ev.amount or 0
	local label = {
		id = nextLabelId,
		target = ev.targetId,
		key = KeyOf(ev),
		skill = SkillOf(ev),
		icon = IconOf(ev),
		miss = ev.kind == "miss",
		total = amount,
		shown = amount,
		count = 1,
		crit = (ev.critical and not IsDotTick(ev)) and true or false, -- a DoT's total is never gold
		critDamage = 0,
		direct = not ev.periodic,
		dot = IsDotTick(ev) and true or false,
		lastTick = ev.periodic and now or nil,
		biggest = amount,
		school = ev.schoolMask,
		anchorId = ev.anchorId,
		fake = ev.fake,
		born = now,
		lastHit = now,
		boss = (ev.targetName ~= nil and bossNames[ev.targetName]) and true or false,
		bump = 0,
		nudge = 0,
		nudgeGoal = 0,
		placed = false,
		crowd = 0,
		cullFade = 1,
		culled = false,
		dying = false,
		vis = 1,
		x = ev.x,
		y = ev.y,
		onScreen = ev.onScreen and true or false,
	}
	if label.key and string.sub(label.key, 1, 6) == "spell#" then
		-- a merged number: it sits over the middle of the enemies its spell hit
		label.merged = true
		label.target = nil
		label.anchorId = nil
		label.fake = nil
		label.spots = { { id = ev.anchorId, fake = ev.fake, target = ev.targetId, at = now,
			lx = ev.onScreen and ev.x or nil, ly = ev.onScreen and ev.y or nil } }
	end
	if label.miss then
		label.word = MissWord(ev)
	elseif ev.critical then
		label.critDamage = amount
	end
	nLabels = nLabels + 1
	labels[nLabels] = label
	if label.key then
		if label.miss then
			missByKey[label.key] = label
		else
			byKey[label.key] = label
		end
	end
	return label
end

local function Merge(label, ev, now)
	local amount = ev.amount or 0
	label.total = label.total + amount
	label.count = label.count + 1
	label.lastHit = now
	-- Every crit gives the number a pop; it turns gold when crits are at
	-- least half of what it holds.
	if ev.critical then
		label.critDamage = label.critDamage + amount
		label.bump = label.bump + 0.3
	elseif label.dot then
		label.bump = label.bump + 0.07 -- a soft pulse each tick
	else
		label.bump = label.bump + 0.1
	end
	if label.dot and ev.periodic then
		-- Ticks closer than this are one round of the DoT's stacks.
		if label.lastTick and now - label.lastTick > 0.15 then
			local gap = now - label.lastTick
			if not label.tickGap or gap > label.tickGap then
				label.tickGap = gap
			end
		end
		label.lastTick = now
	end
	label.crit = (not label.dot) and label.critDamage > 0 and label.critDamage * 2 >= label.total
	if label.bump > 0.45 then
		label.bump = 0.45
	end
	if not ev.periodic then
		label.direct = true
	end
	if amount > label.biggest then
		-- The colour and icon follow the hardest hit in the number.
		label.biggest = amount
		label.school = ev.schoolMask
		label.icon = IconOf(ev)
	end
	if ev.targetName and bossNames[ev.targetName] then
		label.boss = true
	end
	-- One enemy's number follows its newest hit, whose place lasts longest.
	if ev.anchorId and ev.targetId ~= nil and ev.targetId == label.target then
		label.anchorId = ev.anchorId
	end
	if label.spots and (ev.anchorId or ev.fake) then
		local spots, found = label.spots, nil
		for i = 1, table.getn(spots) do
			if spots[i].target == ev.targetId then
				found = spots[i]
			end
		end
		if found then
			found.id, found.lost = ev.anchorId or found.id, nil
		elseif table.getn(spots) < MAX_SPOTS then
			table.insert(spots, { id = ev.anchorId, fake = ev.fake, target = ev.targetId, at = now })
		end
	end
end

local function Intake(ev, now)
	local key = KeyOf(ev)
	if ev.kind == "miss" then
		local label = key and missByKey[key]
		if IsOpen(label, now) then
			label.count = label.count + 1
			label.lastHit = now
			label.bump = math.min(0.3, label.bump + 0.08)
		elseif ev.anchorId or ev.fake then
			NewLabel(ev, now)
		end
		return
	end
	local label = key and byKey[key]
	if not IsOpen(label, now) then
		label = nil
		local boss = ev.targetName ~= nil and bossNames[ev.targetName]
		if db.group and ev.onScreen and not boss and not IsDotTick(ev) and not Merges(ev) then
			-- The nearest open number around this spot takes the hit (the
			-- same skill's, with icons on).
			local skill = db.icons and SkillOf(ev)
			local radius = GROUP_RADIUS * db.size
			local best, bestDistance = nil, radius * radius
			for i = 1, nLabels do
				local other = labels[i]
				if not other.miss and not other.boss and not other.dot and other.onScreen
					and IsOpen(other, now) and (not skill or other.skill == skill) then
					local dx, dy = other.x - ev.x, other.y - ev.y
					local distance = dx * dx + dy * dy
					if distance < bestDistance then
						best, bestDistance = other, distance
					end
				end
			end
			label = best
		end
	end
	if label then
		Merge(label, ev, now)
		if key then
			byKey[key] = label
		end
	elseif ev.anchorId or ev.fake then
		NewLabel(ev, now)
	end
end

------------------------------------------------------------------------------
-- Reading the game's hits

local apiReady, active, registered, warnedNoApi = false, false, false, false
local cursor

local function ApiReady()
	if type(AZS_GetCombatTextCapabilities) ~= "function"
		or type(AZS_GetCombatTextEvents) ~= "function"
		or type(AZS_ProjectCombatTextAnchors) ~= "function"
		or type(AZS_RegisterCombatTextFrameHandler) ~= "function" then
		return false
	end
	local ok, caps = pcall(AZS_GetCombatTextCapabilities)
	return ok and type(caps) == "table" and type(caps.apiVersion) == "number" and caps.apiVersion >= 1
end

local function Wanted(ev, now)
	if type(ev) ~= "table" then
		return false
	end
	if type(ev.presentedAt) == "number" and now - ev.presentedAt > STALE then
		return false
	end
	if ev.kind == "damage" then
		return type(ev.amount) == "number" and ev.amount > 0
	end
	if ev.kind == "miss" then
		return db.misses and true or false
	end
	return false
end

local function Subscribe()
	-- With no cursor the game starts us at the newest hit, with no history.
	local ok, batch = pcall(AZS_GetCombatTextEvents, nil, 256)
	if ok and type(batch) == "table" and batch.cursor then
		cursor = batch.cursor
	end
end

local function ReadEvents(now)
	if not cursor then
		Subscribe()
		return
	end
	for round = 1, 8 do
		local ok, batch, err = pcall(AZS_GetCombatTextEvents, cursor, 256)
		if not ok then
			return
		end
		if type(batch) ~= "table" then
			if type(err) == "table" and err.code == "STREAM_CHANGED" then
				-- A new world, run or /reload: start over.
				ClearAll()
				cursor = nil
				Subscribe()
			end
			return
		end
		if batch.cursor then
			cursor = batch.cursor
		end
		local events = batch.events
		if type(events) == "table" then
			local count = table.getn(events)
			for i = 1, count do
				local ev = events[i]
				if Wanted(ev, now) then
					NoteHit(ev, now)
					NoteSource(ev)
					if ev.abilityName and ev.icon and CUI.LearnIcon then CUI.LearnIcon(ev.abilityName, ev.icon) end
					if CUI.NoteHitValue then CUI.NoteHitValue(ev) end -- what each skill hits for (the pet bar)
					nPending = nPending + 1
					pending[nPending] = ev
				end
			end
		end
		if not batch.hasMore then
			return
		end
	end
end

------------------------------------------------------------------------------
-- Preview: a ring of pretend enemies around the middle of the screen.

local TEST_ENEMIES = 9
-- A pretend hero's skills: four spells and a weapon swing, plus a DoT ticking
-- on every pretend enemy until it dies (then a new one takes its place).
local TEST_SKILLS = {
	{ id = 133, name = "Fireball", school = 4, icon = "Interface\\Icons\\Spell_Fire_FlameBolt" },
	{ id = 116, name = "Frostbolt", school = 16, icon = "Interface\\Icons\\Spell_Frost_FrostBolt02" },
	{ id = 403, name = "Lightning Bolt", school = 8, icon = "Interface\\Icons\\Spell_Nature_Lightning" },
	{ id = 8921, name = "Moonfire", school = 64, icon = "Interface\\Icons\\Spell_Nature_StarFall" },
	{ school = 1 },
}
local TEST_DOT = { id = 172, name = "Corruption", school = 32, icon = "Interface\\Icons\\Spell_Shadow_AbominationExplosion" }
local testUntil, testSerial, testAcc = nil, 0, 0
local testLives = {} -- per pretend enemy: which life it is on, when it dies, its next tick

local function FakePosition(index, now)
	local width = WorldFrame:GetWidth() or 1024
	local height = WorldFrame:GetHeight() or 768
	local angle = index * 2 * math.pi / TEST_ENEMIES + now * 0.35
	local radius = 55 + 42 * math.mod(index, 3)
	return width / 2 + math.cos(angle) * radius * 1.35, height / 2 + math.sin(angle) * radius * 0.75
end

local function TestTarget(index)
	return "preview-enemy-" .. index .. "-" .. testLives[index].life
end

local function TestEvent(index, now, skill)
	testSerial = testSerial + 1
	local ev = {
		eventId = "preview" .. testSerial,
		presentedAt = now,
		targetId = TestTarget(index),
		targetName = "Training Dummy",
		sourceKind = "player",
		fake = index,
		spellId = skill.id,
		abilityName = skill.name,
		icon = skill.icon,
		schoolMask = skill.school,
		damageType = "melee",
	}
	if skill.id then
		ev.damageType = "spell"
	end
	return ev
end

local function Queue(ev, now)
	if Wanted(ev, now) then
		NoteHit(ev, now)
		NoteSource(ev)
		nPending = nPending + 1
		pending[nPending] = ev
	end
end

local function TestHits(now, dt)
	if now > testUntil then
		testUntil = nil
		return
	end
	for index = 1, TEST_ENEMIES do
		local life = testLives[index]
		if now >= life.diesAt then
			-- It dies: its numbers stay where it fell, and a new one comes.
			local target = TestTarget(index)
			local x, y = FakePosition(index, now)
			for i = 1, nLabels do
				local label = labels[i]
				if label.target == target then
					label.targetGone = true
					label.deadX, label.deadY = x, y
				end
			end
			life.life = life.life + 1
			life.diesAt = now + 3 + math.random() * 3.5
			life.nextTick = now + 0.3 + math.random() * 0.6
		elseif now >= life.nextTick then
			life.nextTick = life.nextTick + 1
			local ev = TestEvent(index, now, TEST_DOT)
			ev.kind = "damage"
			ev.periodic = true
			ev.critical = math.random() < 0.1
			ev.amount = math.random(300, 650)
			if ev.critical then
				ev.amount = ev.amount * 2
			end
			Queue(ev, now)
		end
	end
	testAcc = testAcc + dt * 30 -- hits per second
	while testAcc >= 1 do
		testAcc = testAcc - 1
		local ev = TestEvent(math.random(1, TEST_ENEMIES), now, TEST_SKILLS[math.random(1, 5)])
		if math.random() < 0.05 then
			ev.kind = "miss"
			ev.result = { key = "immune" }
		else
			ev.kind = "damage"
			ev.critical = math.random() < 0.18
			ev.amount = math.random(900, 3800)
			if ev.critical then
				ev.amount = ev.amount * 2
			end
		end
		Queue(ev, now)
	end
end

local function StartTest()
	local now = GetTime()
	testUntil = now + 9
	testAcc = 0
	for index = 1, TEST_ENEMIES do
		local life = 1
		if testLives[index] then
			life = testLives[index].life + 1
		end
		testLives[index] = { life = life, diesAt = now + 2.5 + math.random() * 4, nextTick = now + math.random() }
	end
	Print(L("preview for 9 seconds around the middle of the screen."))
end

------------------------------------------------------------------------------
-- Where things are on screen

-- Puts the labels' and the new hits' places through the camera. Returns
-- "world" when the world changed under us.
local function ProjectAnchors(now)
	local ids, refs, n = {}, {}, 0
	for i = 1, nLabels do
		local label = labels[i]
		label.onScreen = false
		if label.spots then
			if not label.frozen and not (label.culled and not label.w) then
				for j = 1, table.getn(label.spots) do
					local spot = label.spots[j]
					spot.onScreen = false
					if spot.fake then
						spot.x, spot.y = FakePosition(spot.fake, now)
						spot.onScreen = true
					elseif spot.id and not spot.lost then
						n = n + 1
						ids[n] = spot.id
						refs[n] = spot
					end
				end
			end
		elseif label.fake then
			if label.deadX then
				label.x, label.y = label.deadX, label.deadY
			else
				label.x, label.y = FakePosition(label.fake, now)
			end
			label.onScreen = true
		elseif label.anchorId and not label.frozen and not (label.culled and not label.w and not label.dot) then
			-- (a number that will never show needs no place; a DoT's may come back)
			n = n + 1
			ids[n] = label.anchorId
			refs[n] = label
		end
	end
	for i = 1, nPending do
		local ev = pending[i]
		ev.onScreen = false
		if ev.fake then
			ev.x, ev.y = FakePosition(ev.fake, now)
			ev.onScreen = true
		elseif ev.anchorId and ev.kind == "damage" and not IsOpen(byKey[KeyOf(ev) or ""], now) then
			-- Only a hit that may start a number needs its place.
			n = n + 1
			ids[n] = ev.anchorId
			refs[n] = ev
		elseif ev.anchorId and ev.kind == "miss" then
			n = n + 1
			ids[n] = ev.anchorId
			refs[n] = ev
		end
	end
	if n == 0 or not apiReady then
		return true
	end
	local first = 1
	while first <= n do
		local last = math.min(n, first + 255)
		local chunk = ids
		if first > 1 or last < n then
			chunk = {}
			for j = first, last do
				chunk[j - first + 1] = ids[j]
			end
		end
		local ok, result = pcall(AZS_ProjectCombatTextAnchors, chunk, "follow")
		if not ok or type(result) ~= "table" or type(result.entries) ~= "table" then
			return false
		end
		local entries = result.entries
		for j = first, last do
			local entry = entries[j - first + 1]
			local ref = refs[j]
			if type(entry) == "table" then
				if entry.targetState == "dead" or entry.targetState == "unavailable" then
					ref.targetGone = true
				end
				if entry.state == "onScreen" and type(entry.x) == "number" and type(entry.y) == "number" then
					ref.x, ref.y = entry.x, entry.y
					ref.onScreen = true
				elseif entry.state == "worldChanged" then
					return "world"
				elseif entry.state == "expired" or entry.state == "unknownAnchor" then
					ref.lost = true
				end
			end
		end
		first = last + 1
	end
	return true
end

-- A merged number sits over the middle of the enemies its spell hit; a newly
-- hit enemy eases into that middle instead of yanking the number over.
local function Centroids(now)
	for i = 1, nLabels do
		local label = labels[i]
		if label.spots and not label.frozen then
			local sx, sy, sw, seen = 0, 0, 0, false
			for j = 1, table.getn(label.spots) do
				local spot = label.spots[j]
				if spot.onScreen then
					spot.lx, spot.ly = spot.x, spot.y
					seen = true
				end
				if spot.lx then
					local w = Smooth((now - spot.at) / 0.35) + 0.002
					sx, sy, sw = sx + spot.lx * w, sy + spot.ly * w, sw + w
				end
			end
			if sw > 0 then
				label.x, label.y = sx / sw, sy / sw
			end
			label.onScreen = seen
		end
	end
end

local function Project(now)
	local result = ProjectAnchors(now)
	if result ~= "world" then
		Centroids(now)
	end
	return result
end

------------------------------------------------------------------------------
-- Which numbers show

local function BaseScale(label)
	local scale
	if label.miss then
		scale = 0.62
	elseif label.crit then
		scale = 1.15
	elseif label.finished then
		scale = 0.95 -- a DoT's final total grows a little as its enemy dies
	elseif label.merged then
		scale = 0.86 -- a crowd's total, a little larger than one enemy's tick
	elseif not label.direct then
		scale = 0.74
	else
		scale = 0.88
	end
	if label.boss then
		scale = scale * 1.12
	end
	-- a number adding hit after hit grows with how long it has stacked, to a cap: a DoT ticking
	-- on, a spell's crowd total climbing; one hit stays its size
	if (label.count or 1) > 1 and label.lastHit and label.born then
		scale = scale * (1 + STACK.grow * Smooth((label.lastHit - label.born) / STACK.time))
	end
	return scale * STACK.shrink * db.size
end

local function Lift(label, now)
	local age = now - label.born
	return (BASE_RISE + DRIFT * (1 - math.exp(-age * 2.5))) * db.size
end

local function ScoreOrder(a, b)
	if a.score ~= b.score then
		return a.score > b.score
	end
	return a.id > b.id
end

local function CullLabel(label, now, quick)
	label.culled = true
	label.culledAt = now
	label.cullTime = CULL_FADE
	if quick then
		label.cullTime = CROWD_FADE
	end
end

-- A DoT's number left out for room may come back once its total has grown
-- (a DoT starts small and keeps adding up), after a pause so it can't flicker.
local function MayReturn(label, now)
	return label.culled and label.dot and not label.w and not label.finished
		and label.culledAt ~= nil and now - label.culledAt > 1
end

-- Too many numbers: the biggest (and the bosses') stay, the rest never show
-- or fade out. A number already on screen keeps its place unless a new one
-- is clearly bigger, so they don't flicker in and out; a DoT's, which stays
-- up for a long time, holds on to its place firmly. A DoT's growing total
-- counts for more, and one left out can come back once it has grown: into a
-- free place, or (one a frame) in place of a number far smaller.
local function Cull(now)
	local list, n, biggest, returning = {}, 0, 0, false
	for i = 1, nLabels do
		local label = labels[i]
		label.back = label.onScreen and MayReturn(label, now)
		if label.onScreen and (not label.culled or label.back) then
			n = n + 1
			list[n] = label
			returning = returning or label.back
			local score
			if label.miss then
				score = -1
				if label.w then
					score = -0.5
				end
			else
				score = label.total
				if label.crit then
					score = score * 1.6
				end
				if label.dot and not db.group then
					score = score * 1.8 -- a DoT's growing total (groups keep it plain)
				end
				if label.w then
					if label.dot then
						score = score * 3
					else
						score = score * 2
					end
				elseif label.back then
					score = score * 0.5
				end
				if not IsOpen(label, now) then
					score = score * 0.6
				end
				if label.boss then
					score = score + 1e15
				else
					if label.w and label.shownAt and now - label.shownAt < MIN_SHOW then
						score = score + 1e14 -- just shown: not pushed out yet
					elseif label.finished and now - label.finishAt < KILL_HOLD then
						score = score + 1e14 -- a DoT's final total: kept for its moment
					end
					if label.total > biggest then
						biggest = label.total -- bosses aside, so they don't hide the rest
					end
				end
			end
			label.score = score
		end
	end
	if db.minShare > 0 and biggest > 0 then
		local floor = biggest * db.minShare
		for i = 1, n do
			local label = list[i]
			-- (only numbers not on screen yet: one showing is never cut short)
			if not label.boss and not label.crit and not label.w and (label.miss or label.total < floor) then
				if label.back then
					label.back = false
				elseif not label.culled then
					CullLabel(label, now)
				end
			end
		end
	end
	if n <= db.maxLabels and not returning then
		return
	end
	table.sort(list, ScoreOrder)
	-- DoTs' totals take at most three places in four, so the hits always
	-- have some (a boss's DoT doesn't count).
	local dotCap = math.max(2, math.floor(db.maxLabels * 0.75 + 0.5))
	local kept, keptDots, weakest, weakestDot = 0, 0, nil, nil
	for i = 1, n do
		local label = list[i]
		if not label.culled then
			local isDot = label.dot and not label.boss
			if kept >= db.maxLabels or (isDot and keptDots >= dotCap) then
				CullLabel(label, now)
			else
				kept = kept + 1
				if isDot then
					keptDots = keptDots + 1
				end
				if label.score < 1e14 then
					weakest = label -- the smallest one kept that may give way
					if isDot then
						weakestDot = label
					end
				end
			end
		end
	end
	for i = 1, n do
		local label = list[i]
		if label.back then
			local room = kept < db.maxLabels and keptDots < dotCap
			if not room then
				local victim = weakest
				if keptDots >= dotCap then
					victim = weakestDot
				end
				if victim and label.score > victim.score * 2 then
					CullLabel(victim, now)
					kept = kept - 1
					if victim.dot and not victim.boss then
						keptDots = keptDots - 1
					end
					weakest, weakestDot = nil, nil -- one a frame
					room = true
				end
			end
			if room then
				-- Back on screen: it fades in and pops as if new.
				kept = kept + 1
				keptDots = keptDots + 1
				label.culled = false
				label.cullFade = 1
				label.crowd = 0
				label.placed = false
				label.shownAt = nil
			end
		end
	end
end

-- Who gets a seat first: the numbers still taking hits and already showing
-- (they stay put), then new ones, then the finished ones on their way out,
-- which move up out of the way as new ones come in under them.
local function SeatRank(label, now)
	if label.miss then
		if label.w then
			return 1
		end
		return 0
	end
	local rank = 10
	if IsOpen(label, now) then
		rank = 20
		if label.w then
			rank = 30
		elseif label.crit or label.boss then
			rank = 40 -- a new crit or boss number takes its seat first
		end
	end
	if label.boss then
		rank = rank + 2
	end
	if label.crit then
		rank = rank + 1
	end
	return rank
end

local function SeatOrder(a, b)
	if a.rank ~= b.rank then
		return a.rank > b.rank
	end
	if a.rank >= 30 and a.rank < 40 then
		return a.id < b.id -- showing: the older keeps its seat
	end
	if a.rank >= 20 and a.total ~= b.total then
		return a.total > b.total -- new: the bigger first
	end
	return a.id > b.id
end

-- Numbers that would cover each other step up (or down) a line. A new one
-- with no room doesn't show; one already showing that is boxed in for a
-- moment fades out, unless it is a crit or a boss's.
local STEPS = { 0, 1, -1, 2, -2, 3, 4 }
local NSTEPS = 7
local MOVES = { 0, 1, -1 }      -- a number on screen: stay, or move a line
                                -- (one fading out only stays or moves up)
local placedX, placedY, placedW, placedH = {}, {}, {}, {}

local function Spread(now, dt)
	local list, n = {}, 0
	for i = 1, nLabels do
		local label = labels[i]
		if not label.culled and label.onScreen then
			n = n + 1
			list[n] = label
			label.rank = SeatRank(label, now)
		end
	end
	if n == 0 then
		return
	end
	if not db.spread then
		for i = 1, n do
			list[i].nudgeGoal = 0
			list[i].crowd = 0
		end
		return
	end
	table.sort(list, SeatOrder)
	local placed = 0
	for i = 1, n do
		local label = list[i]
		local scale = BaseScale(label)
		local width = label.textWidth
		if not width then
			width = string.len(FormatAmount(label.total)) * FONT_SIZE * 0.55
		end
		if db.icons and label.icon then
			width = width + ICON_SIZE + ICON_GAP
		end
		local halfW = width * scale * 0.5 + 3
		local halfH = FONT_SIZE * scale * 0.42 + 1
		local cx = label.x
		local cy = label.y + Lift(label, now)
		-- A number already showing puts up with a little overlap before it
		-- moves, so numbers don't hop about as the enemies shuffle.
		local slack = 1
		if label.w then
			slack = 0.85
		end
		-- A new number takes the nearest free line. One already showing keeps
		-- its line or moves a single line, never sliding across the others;
		-- boxed in, it fades out instead.
		local goal
		local line = halfH * 2 + 1 -- a hair more than a number's height, so neighbours fit
		local moving = label.w and label.placed
		local tries = NSTEPS
		if moving then
			tries = 3
			if label.dying then
				tries = 2
			end
		end
		for k = 1, tries do
			local offset
			if moving then
				offset = (label.nudgeGoal or 0) + MOVES[k] * line
			else
				offset = STEPS[k] * line
			end
			local y = cy + offset
			-- never wander more than a few lines from its enemy
			local clear = offset <= 4.5 * line and offset >= -2.5 * line
			for j = 1, placed do
				if not clear then
					break
				end
				if math.abs(cx - placedX[j]) < (halfW + placedW[j]) * slack
					and math.abs(y - placedY[j]) < (halfH + placedH[j]) * slack then
					clear = false
					break
				end
			end
			if clear then
				goal = offset
				break
			end
		end
		local important = (label.crit or label.boss) and label.rank >= 20 -- and still taking hits
		if goal then
			label.crowd = 0
		elseif not label.w and not important then
			goal = 0
			CullLabel(label, now)
		elseif important then
			goal = label.nudgeGoal or 0
			label.crowd = 0
		else
			goal = label.nudgeGoal or 0
			label.crowd = label.crowd + dt
			if label.crowd > CROWD_TIME then
				CullLabel(label, now, true)
			end
		end
		label.nudgeGoal = goal
		if not label.placed then
			label.nudge = goal
			label.nudgeSpeed = 0
			label.placed = true
		end
		if not label.culled then
			placed = placed + 1
			placedX[placed] = cx
			placedY[placed] = cy + goal
			placedW[placed] = halfW
			placedH[placed] = halfH
		end
	end
end

------------------------------------------------------------------------------
-- Drawing

local function LabelColor(label)
	if label.miss then
		return COLOR_MISS
	end
	if label.crit then
		return COLOR_CRIT
	end
	if db.school and label.school and SCHOOL_COLORS[label.school] then
		return SCHOOL_COLORS[label.school]
	end
	if not label.direct and not label.finished then
		return COLOR_DOT
	end
	return COLOR_NORMAL
end

local function LabelText(label)
	local text
	if label.miss then
		text = label.word
	else
		text = FormatAmount(label.shown)
	end
	if db.count and label.count > 1 then
		text = text .. " |cffbbbbbbx" .. label.count .. "|r"
	end
	return text
end

-- Returns false when the label is done. Every way a number leaves is eased:
-- it floats up, shrinks a little and melts away; pushed out, it melts where
-- it is; leaving the view (or losing its place) it fades where it last was.
local function Animate(label, now, dt, ratio)
	if label.frozen then
		label.onScreen = label.x ~= nil
	end
	-- A hit's number fades a moment after its last hit; a DoT's when the DoT
	-- stops ticking, or a moment after its enemy died.
	local fadeAt
	if label.finished then
		fadeAt = label.finishAt + KILL_HOLD
	elseif label.dot then
		fadeAt = label.lastHit + DotHold(label)
	else
		fadeAt = label.lastHit + HOLD
	end
	local fadeP = 0
	if now > fadeAt then
		label.dying = true
		fadeP = (now - fadeAt) / FADE_OUT
		if fadeP >= 1 then
			return false
		end
	end
	-- Its place comes from its newest hit, which the game keeps 5 s: near the
	-- end of that, or with the place lost, it slips away where it is.
	local leaving = now - label.lastHit > MAX_AGE or label.lost
	if leaving then
		if not label.culled then
			CullLabel(label, now)
		end
		if label.lost then
			label.frozen = true
			label.onScreen = label.x ~= nil
		end
	end
	if label.culled then
		-- Off the screen (or never on it), it still takes its enemy's hits
		-- until it would have faded, so they don't start a new number each
		-- frame.
		if not label.w then
			return not leaving
		end
		label.cullFade = label.cullFade - dt / (label.cullTime or CULL_FADE)
		if label.cullFade <= 0 then
			ReleaseWidget(label.w)
			label.w = nil
			return not leaving
		end
	end
	-- Out of the view it fades where it last was; back in, it fades back.
	if label.onScreen then
		label.vis = math.min(1, label.vis + dt / EDGE_FADE)
	else
		label.vis = math.max(0, label.vis - dt / EDGE_FADE)
	end
	local w = label.w
	if not label.onScreen and (not w or label.vis <= 0 or not label.x) then
		if w and w.shown then
			w.holder:Hide()
			w.shown = false
		end
		return true
	end
	if not w then
		w = AcquireWidget()
		label.w = w
		if not label.shownAt then
			label.shownAt = now
		end
	end

	-- The number counts up to what it holds.
	if label.shown < label.total then
		label.shown = label.shown + (label.total - label.shown) * (1 - math.exp(-dt * 16))
		if label.total - label.shown < 1 then
			label.shown = label.total
		end
	end
	local text = LabelText(label)
	if text ~= w.lastText then
		w.text:SetText(text)
		w.lastText = text
		local width = w.text:GetStringWidth()
		if type(width) ~= "number" or width <= 0 then
			width = string.len(text) * FONT_SIZE * 0.55
		end
		label.textWidth = width
	end
	local icon = nil
	if db.icons then
		icon = label.icon
	end
	Layout(w, label.textWidth or 0, icon, dt)

	-- Colours blend into each other (a crit's gold, a DoT's final white).
	local color = LabelColor(label)
	local r, g, b = color[1], color[2], color[3]
	if w.r then
		local k = 1 - math.exp(-dt * 12)
		r = w.r + (r - w.r) * k
		g = w.g + (g - w.g) * k
		b = w.b + (b - w.b) * k
		if math.abs(r - color[1]) + math.abs(g - color[2]) + math.abs(b - color[3]) < 0.01 then
			r, g, b = color[1], color[2], color[3]
		end
	end
	if w.r ~= r or w.g ~= g or w.b ~= b then
		w.text:SetTextColor(r, g, b)
		w.r, w.g, w.b = r, g, b
	end

	-- Pop and fade in from when it first shows (it may have been off screen).
	local shownAge = now - label.shownAt
	-- A hit's punch swells in and relaxes on a quick soft spring: no frame
	-- ever jumps in size.
	label.bump = label.bump * math.exp(-dt * 10)
	local away = (label.swell or 0) - label.bump
	local speed = label.swellSpeed or 0
	local decay = math.exp(-POP_SPRING * dt)
	local push = (speed + POP_SPRING * away) * dt
	label.swellSpeed = (speed - POP_SPRING * push) * decay
	label.swell = label.bump + (away + push) * decay
	local pop = 1
	local motion = db.motion
	local popTime = (motion == "impact") and 0.32 or POP_TIME
	if shownAge < popTime then
		local t = 1 - shownAge / popTime
		local strength = 0.25
		if label.crit then
			strength = 0.55
		elseif label.miss then
			strength = 0.1
		end
		if motion == "impact" then strength = strength * 2.6 end
		pop = 1 + strength * t * t * t
	end
	local fading = Smooth(fadeP)
	local pushed = 0
	if label.culled then
		pushed = Smooth(1 - label.cullFade)
	end
	-- A change of size (a number turning gold, a DoT's final total) grows in.
	local base = BaseScale(label)
	if label.base then
		base = label.base + (base - label.base) * (1 - math.exp(-dt * 14))
	end
	label.base = base
	local scale = base * pop * (1 + label.swell) * (1 - FADE_SHRINK * fading) * (1 - CULL_SHRINK * pushed)
	if not w.scale or math.abs(w.scale - scale) > 0.003 then
		w.visual:SetScale(scale)
		w.scale = scale
	end

	local alpha = (1 - fading) * (1 - pushed) * Smooth(label.vis)
	if shownAge < FADE_IN then
		alpha = alpha * Smooth(shownAge / FADE_IN)
	end
	alpha = Clamp(alpha, 0, 1)
	-- a crit wears its backdrop (Blood, Fire...), sized to its number
	local back = label.crit and db.backdrop ~= "none" and STACK.backs.tex[db.backdrop]
	if back then
		if w.backTex ~= back then
			w.back:SetTexture((CUI.ART or "Interface\\AddOns\\CreedUI\\Art\\") .. back)
			w.backTex = back
		end
		local bw = math.floor((w.block or 60) * 1.6 + 46)
		if w.backW ~= bw then
			w.back:SetWidth(bw)
			w.back:SetHeight(math.min(math.floor(bw * 0.5 + 0.5), FONT_SIZE * 3))
			w.backW = bw
		end
		if not w.backShown then
			w.back:Show()
			w.backShown = true
		end
	elseif w.backShown then
		w.back:Hide()
		w.backShown = false
	end
	if not w.alpha or math.abs(w.alpha - alpha) > 0.004 then
		w.holder:SetAlpha(alpha)
		w.alpha = alpha
	end

	-- It drifts up as it lives; fading, it floats off, gently at first.
	-- Stepping aside rides a critically damped spring: it starts gently,
	-- speeds up, and settles without overshoot.
	local offset = label.nudge - label.nudgeGoal
	local speed = label.nudgeSpeed or 0
	local decay = math.exp(-SPRING * dt)
	local push = (speed + SPRING * offset) * dt
	label.nudgeSpeed = (speed - SPRING * push) * decay
	label.nudge = label.nudgeGoal + (offset + push) * decay
	local rise = Lift(label, now) + label.nudge + FADE_RISE * db.size * fadeP * fadeP
	local sideways = 0
	local age = now - label.born
	if motion == "fountain" then
		-- up in an arc and down, off to one side (every other number the other way)
		if not label.side then label.side = (math.mod(math.floor(label.born * 997), 2) == 0) and 1 or -1 end
		sideways = label.side * 52 * db.size * (1 - math.exp(-age * 1.8))
		rise = (BASE_RISE + 95 * age - 80 * age * age) * db.size + label.nudge
	elseif motion == "rise" then
		rise = (BASE_RISE + 85 * age) * db.size + label.nudge + FADE_RISE * db.size * fadeP
	elseif motion == "impact" then
		rise = BASE_RISE * db.size + label.nudge
		if label.crit and shownAge < 0.3 then
			sideways = math.sin(shownAge * 95) * 5 * db.size * (1 - shownAge / 0.3)
		end
	end
	local px = math.floor((label.x + sideways) * ratio * 10 + 0.5) / 10
	local py = math.floor((label.y + rise) * ratio * 10 + 0.5) / 10
	if w.px ~= px or w.py ~= py then
		w.holder:SetPoint("CENTER", WorldFrame, "BOTTOMLEFT", px, py)
		w.px, w.py = px, py
	end
	if not w.shown then
		w.holder:Show()
		w.shown = true
	end
	return true
end

local function Render(now, dt)
	-- The game's places are in WorldFrame's units; ours may be scaled.
	local ratio = 1
	local worldScale = WorldFrame:GetEffectiveScale()
	local layerScale = layer:GetEffectiveScale()
	if type(worldScale) == "number" and type(layerScale) == "number" and layerScale > 0 then
		ratio = worldScale / layerScale
	end
	local kept = 0
	for i = 1, nLabels do
		local label = labels[i]
		if Animate(label, now, dt, ratio) then
			kept = kept + 1
			labels[kept] = label
		else
			Retire(label)
		end
	end
	for i = kept + 1, nLabels do
		labels[i] = nil
	end
	nLabels = kept
end

------------------------------------------------------------------------------
-- Every frame

local lastNow, nextBossRefresh, nextSweep = nil, 0, 0

local function RefreshBossNames()
	bossNames = {}
	local units = AZS_UNITS
	if type(units) ~= "table" then
		return
	end
	if type(AZS_GetPhase) == "function" then
		local phase = AZS_GetPhase()
		if phase == nil or phase == "ready" then
			return -- out of a run the list may be the last run's
		end
	end
	for i = 1, table.getn(units) do
		local unit = units[i]
		if type(unit) == "table" then
			local kind = unit.kind or unit[1]
			local name = unit.name or unit[3]
			if name and (kind == "final" or kind == "boss" or kind == "guardian") then
				bossNames[name] = true
			end
		end
	end
end

local function Sweep()
	for key, label in pairs(byKey) do
		if label.dead then
			byKey[key] = nil
		end
	end
	for key, label in pairs(missByKey) do
		if label.dead then
			missByKey[key] = nil
		end
	end
end

-- The level-up cards: while they're up the numbers step aside (under the game's veil their icons
-- come out black), and the ones from before are dropped as the cards close, so none of them flies
-- across the screen to where its enemy has gone meanwhile. New hits show as the fight resumes.
local cards = { was = false, alpha = 1 }

local function StepCards()
	local up = CUI.cardsUp and true or false
	if cards.was and not up then
		ClearAll()
	end
	cards.was = up
	local a = 1 - Clamp(CUI.cardsFade or 0, 0, 1)
	if up then a = 0 end
	if a ~= cards.alpha then
		cards.alpha = a
		layer:SetAlpha(a)
	end
end

local function Step(now)
	frameNow = now
	StepCards()
	local dt = 0
	if lastNow then
		dt = now - lastNow
	end
	dt = Clamp(dt, 0, 0.1)
	lastNow = now
	if now >= nextBossRefresh then
		RefreshBossNames()
		nextBossRefresh = now + 1
	end
	if now >= nextSweep then
		Sweep()
		RefreshFallbackIcons(now)
		nextSweep = now + 2
	end
	WatchSummons(now)

	if active then
		ReadEvents(now)
	end
	if testUntil then
		TestHits(now, dt)
	end
	if nLabels == 0 and nPending == 0 then
		return
	end
	if Project(now) == "world" then
		ClearAll()
		return
	end
	for i = 1, nPending do
		Intake(pending[i], now)
		pending[i] = nil
	end
	nPending = 0
	for i = 1, nLabels do
		local label = labels[i]
		if label.dot and label.targetGone and not label.finished then
			-- The enemy died: the DoT's whole total pops and stays a moment.
			label.finished = true
			label.finishAt = now
			label.bump = math.min(0.6, label.bump + 0.35)
		end
	end
	Cull(now)
	Spread(now, dt)
	Render(now, dt)
end

local errors, lastErrorAt, errorShown, giveUp = 0, 0, false, false
local blocked = false -- Smooth Numbers itself is running, so this part stays off
local SetEnabled -- below

-- A problem in one frame never reaches the game: that frame's numbers are
-- dropped. Many problems in a row switch the addon off (done from OnUpdate,
-- not inside the game's frame handler).
local function SafeStep(now)
	local ok, err = pcall(Step, now)
	if not ok then
		if now - lastErrorAt > 10 then
			errors = 0
		end
		lastErrorAt = now
		errors = errors + 1
		pcall(ClearAll)
		if not errorShown then
			errorShown = true
			Print(L("ran into a problem and skipped it: ") .. tostring(err))
		end
		if errors >= 30 then
			giveUp = true
		end
	end
end

-- The game calls this every frame in the world, after the camera moved and
-- before anything is drawn, so the numbers stay glued to the enemies.
local handlerAt = -1
local function OnFrame()
	local now = GetTime()
	handlerAt = now
	SafeStep(now)
end

------------------------------------------------------------------------------
-- On and off

local function HideGameNumbers()
	if type(GetCVar) ~= "function" or type(SetCVar) ~= "function" then
		return
	end
	local current = GetCVar("CombatDamage")
	if not db.hidGame then
		db.gameNumbers = current or "1"
		db.hidGame = true
	end
	if current ~= "0" then
		SetCVar("CombatDamage", "0")
	end
end

local function ShowGameNumbers()
	if type(GetCVar) ~= "function" or type(SetCVar) ~= "function" then
		return
	end
	if db.hidGame then
		local wanted = db.gameNumbers or "1"
		if GetCVar("CombatDamage") ~= wanted then
			SetCVar("CombatDamage", wanted)
		end
		db.hidGame = nil
	end
end

local function Activate()
	apiReady = ApiReady()
	if not apiReady then
		active = false
		if not warnedNoApi then
			warnedNoApi = true
			Print(L("this version of the game doesn't give addons its hits yet, so the game's own numbers stay on."))
		end
		return
	end
	if not registered then
		local ok, result, failure = pcall(AZS_RegisterCombatTextFrameHandler, OnFrame)
		registered = ok and failure == nil and result ~= false
	end
	ClearAll()
	cursor = nil
	HideGameNumbers()
	active = true
end

local function Deactivate()
	active = false
	if registered and type(AZS_UnregisterCombatTextFrameHandler) == "function" then
		pcall(AZS_UnregisterCombatTextFrameHandler, OnFrame)
	end
	registered = false
	cursor = nil
	ClearAll()
	ShowGameNumbers()
end

local RefreshOptions -- below

SetEnabled = function(on)
	db.enabled = on and true or false
	if db.enabled then
		errors = 0
		Activate()
	else
		Deactivate()
	end
	if RefreshOptions then
		RefreshOptions()
	end
end

------------------------------------------------------------------------------
-- The options window (/creed numbers)

local options

local function Fill(parent, drawLayer, r, g, b, a)
	local texture = parent:CreateTexture(nil, drawLayer)
	texture:SetTexture(FLAT)
	texture:SetVertexColor(r, g, b, a)
	return texture
end

local function Text(parent, size, r, g, b)
	local text = parent:CreateFontString(nil, "OVERLAY")
	if CUI.SetFace then CUI.SetFace(text, FONTS[1].path, size) else text:SetFont(FONTS[1].path, size) end
	text:SetTextColor(r, g, b)
	text:SetShadowColor(0, 0, 0, 1)
	text:SetShadowOffset(1, -1)
	return text
end

local function PaintButton(button)
	if button.selected then
		button:SetBackdropColor(0.50, 0.38, 0.07, 1)
		button:SetBackdropBorderColor(0.91, 0.70, 0.30, 1)
	elseif button.hot then
		button:SetBackdropColor(0.24, 0.24, 0.28, 1)
		button:SetBackdropBorderColor(0.65, 0.65, 0.7, 1)
	else
		button:SetBackdropColor(0.13, 0.13, 0.16, 1)
		button:SetBackdropBorderColor(0.32, 0.32, 0.36, 1)
	end
end

local function MakeButton(parent, width, height, label, onClick)
	local button = CreateFrame("Button", nil, parent)
	button:SetWidth(width)
	button:SetHeight(height)
	button:EnableMouse(true)
	button:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	button.text = Text(button, 11, 1, 1, 1)
	button.text:SetPoint("CENTER", button, "CENTER", 0, 0)
	button.text:SetText(label or "")
	button.hot, button.selected = false, false
	button:SetScript("OnEnter", function()
		button.hot = true
		PaintButton(button)
	end)
	button:SetScript("OnLeave", function()
		button.hot = false
		PaintButton(button)
	end)
	button:SetScript("OnClick", onClick)
	PaintButton(button)
	return button
end

local function OnSettingChanged(key)
	if key == "short" or key == "count" or key == "icons" then
		RefreshAllText()
	elseif key == "font" then
		ApplyFontAll()
	end
end

local function MakeCheck(parent, y, label, key)
	local check = CreateFrame("Button", nil, parent)
	check:SetWidth(272)
	check:SetHeight(20)
	check:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, y)
	check:EnableMouse(true)
	check.edge = Fill(check, "BORDER", 0.38, 0.38, 0.42, 1)
	check.edge:SetWidth(14)
	check.edge:SetHeight(14)
	check.edge:SetPoint("LEFT", check, "LEFT", 0, 0)
	check.box = Fill(check, "ARTWORK", 0.06, 0.06, 0.08, 1)
	check.box:SetPoint("TOPLEFT", check.edge, "TOPLEFT", 1, -1)
	check.box:SetPoint("BOTTOMRIGHT", check.edge, "BOTTOMRIGHT", -1, 1)
	check.mark = Fill(check, "OVERLAY", 0.91, 0.70, 0.30, 1)
	check.mark:SetPoint("TOPLEFT", check.edge, "TOPLEFT", 3, -3)
	check.mark:SetPoint("BOTTOMRIGHT", check.edge, "BOTTOMRIGHT", -3, 3)
	check.label = Text(check, 11, 0.92, 0.92, 0.92)
	check.label:SetPoint("LEFT", check.edge, "RIGHT", 8, 0)
	LText(check.label, label)
	check.key = key
	check:SetScript("OnEnter", function()
		check.label:SetTextColor(0.98, 0.85, 0.52)
	end)
	check:SetScript("OnLeave", function()
		check.label:SetTextColor(0.92, 0.92, 0.92)
	end)
	check:SetScript("OnClick", function()
		db[key] = not db[key]
		OnSettingChanged(key)
		RefreshOptions()
	end)
	return check
end

RefreshOptions = function()
	if not options or not db then
		return
	end
	local o = options
	o.toggle.selected = db.enabled
	if db.enabled then
		o.toggle.text:SetText(L("ON: Creed UI draws your damage"))
	else
		o.toggle.text:SetText(L("OFF: the game's own numbers"))
	end
	PaintButton(o.toggle)
	for i = 1, 3 do
		local button = o.presets[i]
		button.selected = db.preset == button.preset
		PaintButton(button)
	end
	o.styleNote:SetText(L(PRESET_NOTES[db.preset] or ""))
	for i = 1, 4 do
		local button = o.motions[i]
		button.selected = db.motion == button.motion
		PaintButton(button)
	end
	o.motionNote:SetText(L(STACK.motion.notes[db.motion] or ""))
	o.backText:SetText(L(STACK.backs.names[db.backdrop] or "None"))
	o.sizeText:SetText(string.format("%d%%", math.floor(db.size * 100 + 0.5)))
	o.fontText:SetText(FONTS[db.font].name)
	for i = 1, table.getn(o.checks) do
		local check = o.checks[i]
		if db[check.key] then
			check.mark:Show()
		else
			check.mark:Hide()
		end
	end
end

local function BuildOptions()
	local o = CreateFrame("Frame", "CreedUINumbersOptions", UIParent)
	options = o
	o:SetWidth(300)
	o:SetHeight(662)
	o:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
	if CUI.AboveHub then CUI.AboveHub(o) else o:SetFrameStrata("DIALOG") end
	o:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	o:SetBackdropColor(0.05, 0.05, 0.07, 0.96)
	o:SetBackdropBorderColor(0, 0, 0, 1)
	o:EnableMouse(true)
	o:SetMovable(true)
	o:SetClampedToScreen(true)
	o:RegisterForDrag("LeftButton")
	o:SetScript("OnDragStart", function()
		o:StartMoving()
	end)
	o:SetScript("OnDragStop", function()
		o:StopMovingOrSizing()
	end)
	o:Hide()
	if type(UISpecialFrames) == "table" then
		table.insert(UISpecialFrames, "CreedUINumbersOptions") -- Escape closes it
	end

	local title = Text(o, 16, 1, 0.82, 0.25)
	title:SetPoint("TOPLEFT", o, "TOPLEFT", 14, -14)
	LText(title, "Damage numbers")
	local version = Text(o, 10, 0.55, 0.55, 0.6)
	version:SetPoint("LEFT", title, "RIGHT", 8, -1)
	version:SetText("v" .. VERSION)

	local close = MakeButton(o, 22, 22, "x", function()
		o:Hide()
	end)
	close:SetPoint("TOPRIGHT", o, "TOPRIGHT", -10, -10)

	o.toggle = MakeButton(o, 272, 28, "", function()
		SetEnabled(not db.enabled)
	end)
	o.toggle:SetPoint("TOPLEFT", o, "TOPLEFT", 14, -46)

	local styleHead = Text(o, 12, 0.85, 0.85, 0.9)
	styleHead:SetPoint("TOPLEFT", o, "TOPLEFT", 14, -88)
	LText(styleHead, "Style")
	o.presets = {}
	for i = 1, 3 do
		local name = PRESET_ORDER[i]
		local button = MakeButton(o, 88, 24, PRESET_NAMES[name], function()
			ApplyPreset(name)
			RefreshOptions()
		end)
		button.preset = name
		LText(button.text, PRESET_NAMES[name])
		button:SetPoint("TOPLEFT", o, "TOPLEFT", 14 + (i - 1) * 92, -106)
		o.presets[i] = button
	end
	o.styleNote = Text(o, 10, 0.6, 0.6, 0.65)
	o.styleNote:SetPoint("TOPLEFT", o, "TOPLEFT", 14, -136)
	o.styleNote:SetWidth(272)
	o.styleNote:SetJustifyH("LEFT")

	local sizeHead = Text(o, 12, 0.85, 0.85, 0.9)
	sizeHead:SetPoint("TOPLEFT", o, "TOPLEFT", 14, -166)
	LText(sizeHead, "Size")
	local smaller = MakeButton(o, 26, 22, "-", function()
		db.size = Clamp(math.floor(db.size * 10 + 0.5) / 10 - 0.1, 0.6, 1.8)
		RefreshOptions()
	end)
	smaller:SetPoint("TOPLEFT", o, "TOPLEFT", 126, -162)
	o.sizeText = Text(o, 12, 1, 1, 1)
	o.sizeText:SetPoint("LEFT", smaller, "RIGHT", 0, 0)
	o.sizeText:SetWidth(80)
	o.sizeText:SetJustifyH("CENTER")
	local bigger = MakeButton(o, 26, 22, "+", function()
		db.size = Clamp(math.floor(db.size * 10 + 0.5) / 10 + 0.1, 0.6, 1.8)
		RefreshOptions()
	end)
	bigger:SetPoint("LEFT", smaller, "RIGHT", 80, 0)

	local fontHead = Text(o, 12, 0.85, 0.85, 0.9)
	fontHead:SetPoint("TOPLEFT", o, "TOPLEFT", 14, -198)
	LText(fontHead, "Font")
	local previous = MakeButton(o, 26, 22, "<", function()
		db.font = db.font - 1
		if db.font < 1 then
			db.font = table.getn(FONTS)
		end
		OnSettingChanged("font")
		RefreshOptions()
	end)
	previous:SetPoint("TOPLEFT", o, "TOPLEFT", 112, -194)
	o.fontText = Text(o, 11, 1, 1, 1)
	o.fontText:SetPoint("LEFT", previous, "RIGHT", 0, 0)
	o.fontText:SetWidth(120)
	o.fontText:SetJustifyH("CENTER")
	local nextFont = MakeButton(o, 26, 22, ">", function()
		db.font = db.font + 1
		if db.font > table.getn(FONTS) then
			db.font = 1
		end
		OnSettingChanged("font")
		RefreshOptions()
	end)
	nextFont:SetPoint("LEFT", previous, "RIGHT", 120, 0)

	local divider = Fill(o, "ARTWORK", 1, 1, 1, 0.08)
	divider:SetPoint("TOPLEFT", o, "TOPLEFT", 14, -228)
	divider:SetWidth(272)
	divider:SetHeight(1)

	o.checks = {
		MakeCheck(o, -238, "Skill icons (one number per skill)", "icons"),
		MakeCheck(o, -262, "DoT totals until the enemy dies", "dotTotals"),
		MakeCheck(o, -286, "Short numbers (12.3K)", "short"),
		MakeCheck(o, -310, "One number per group of enemies", "group"),
		MakeCheck(o, -334, "Move overlapping numbers apart", "spread"),
		MakeCheck(o, -358, "Show hit count (x5)", "count"),
		MakeCheck(o, -382, "Color by spell school", "school"),
		MakeCheck(o, -406, "Show Miss and Immune", "misses"),
		MakeCheck(o, -430, "Merge a spell on 3+ enemies: one number a second", "crowd"),
		MakeCheck(o, -454, "Merge every spell: one number a second", "bySpell"),
	}

	local preview = MakeButton(o, 132, 26, "Preview", function()
		StartTest()
	end)
	preview:SetPoint("TOPLEFT", o, "TOPLEFT", 14, -488)
	LText(preview.text, "Preview")
	local reset = MakeButton(o, 132, 26, "Reset", function()
		for key, value in pairs(DEFAULTS) do
			if key ~= "enabled" then
				db[key] = value
			end
		end
		ApplyFontAll()
		RefreshAllText()
		RefreshOptions()
		Print(L("settings reset."))
	end)
	reset:SetPoint("TOPLEFT", o, "TOPLEFT", 154, -488)
	LText(reset.text, "Reset settings")

	-- how they move
	local motionHead = Text(o, 12, 0.85, 0.85, 0.9)
	motionHead:SetPoint("TOPLEFT", o, "TOPLEFT", 14, -524)
	LText(motionHead, "Motion")
	o.motions = {}
	for i = 1, 4 do
		local name = STACK.motion.order[i]
		local button = MakeButton(o, 66, 24, STACK.motion.names[name], function()
			db.motion = name
			RefreshOptions()
		end)
		button.motion = name
		LText(button.text, STACK.motion.names[name])
		button:SetPoint("TOPLEFT", o, "TOPLEFT", 14 + (i - 1) * 69, -542)
		o.motions[i] = button
	end
	o.motionNote = Text(o, 10, 0.6, 0.6, 0.65)
	o.motionNote:SetPoint("TOPLEFT", o, "TOPLEFT", 14, -572)
	o.motionNote:SetWidth(272)
	o.motionNote:SetJustifyH("LEFT")

	-- what a crit wears behind its number
	local backHead = Text(o, 12, 0.85, 0.85, 0.9)
	backHead:SetPoint("TOPLEFT", o, "TOPLEFT", 14, -604)
	LText(backHead, "Crit backdrop")
	local function Step(by)
		local order, at = STACK.backs.order, 1
		for i = 1, table.getn(order) do
			if order[i] == db.backdrop then at = i end
		end
		at = math.mod(at - 1 + by + table.getn(order), table.getn(order)) + 1
		db.backdrop = order[at]
		RefreshOptions()
	end
	local prevBack = MakeButton(o, 26, 22, "<", function() Step(-1) end)
	prevBack:SetPoint("TOPLEFT", o, "TOPLEFT", 112, -600)
	o.backText = Text(o, 11, 1, 1, 1)
	o.backText:SetPoint("LEFT", prevBack, "RIGHT", 0, 0)
	o.backText:SetWidth(120)
	o.backText:SetJustifyH("CENTER")
	local nextBack = MakeButton(o, 26, 22, ">", function() Step(1) end)
	nextBack:SetPoint("LEFT", prevBack, "RIGHT", 120, 0)

	local footer = Text(o, 10, 0.5, 0.5, 0.55)
	footer:SetPoint("BOTTOM", o, "BOTTOM", 0, 10)
	LText(footer, "Type /creed numbers to open this window.")
	if CUI.OnLanguage then CUI.OnLanguage(function() if o:IsShown() then RefreshOptions() end end) end
end

local function ToggleOptions()
	if not options then
		BuildOptions()
	end
	if options:IsShown() then
		options:Hide()
	else
		if CUI.AboveHub then CUI.AboveHub(options) end
		RefreshOptions()
		options:Show()
	end
end

------------------------------------------------------------------------------
-- Slash commands

local function Help()
	Print(L("damage number commands:"))
	Print(L("/creed numbers - options window"))
	Print(L("/creed numbers on | off - Creed UI's numbers or the game's own"))
	Print(L("/creed numbers minimal | clean | detailed - pick a style"))
	Print(L("/creed numbers size 120 - number size in percent (60 to 180)"))
	Print(L("/creed numbers icons - skill icons on or off"))
	Print(L("/creed numbers dots - DoT totals until the enemy dies, on or off"))
	Print(L("/creed numbers crowd - merge a spell hitting 3+ enemies, on or off"))
	Print(L("/creed numbers spells - merge every spell, on or off"))
	Print(L("/creed numbers smooth, fountain, rise or impact - how the numbers move"))
	Print(L("/creed numbers backdrop none, blood, fire, frost, arcane, holy or shadow - behind crits"))
	Print(L("/creed numbers font <name> - Friz Quadrata, Cinzel, Bangers, Creepster, Uncial Antiqua, Black Ops One, Pirata One..."))
	Print(L("/creed numbers preview - show some pretend numbers"))
	Print(L("/creed numbers reset - default settings"))
end

local function NumberSlash(msg)
	if not db then
		InitDB()
	end
	local _, _, command, rest = string.find(msg or "", "^%s*(%S*)%s*(.-)%s*$")
	command = string.lower(command or "")
	if command == "" or command == "options" or command == "config" then
		ToggleOptions()
	elseif command == "on" then
		SetEnabled(true)
		if active then
			Print(L("on."))
		end
	elseif command == "off" then
		SetEnabled(false)
		Print(L("off: the game's own numbers are back."))
	elseif PRESETS[command] then
		ApplyPreset(command)
		if RefreshOptions then
			RefreshOptions()
		end
		Print(L("style: ") .. L(PRESET_NAMES[command]) .. ". " .. L(PRESET_NOTES[command]))
	elseif command == "font" and rest ~= "" then
		-- by its name, or the start of it ("cinzel", "black")
		local want = string.lower(rest)
		for i = 1, table.getn(FONTS) do
			if string.find(string.lower(FONTS[i].name), want, 1, true) == 1 then
				db.font = i
				OnSettingChanged("font")
				if RefreshOptions then RefreshOptions() end
				Print(L("font: ") .. FONTS[i].name)
				return
			end
		end
		Help()
	elseif command == "backdrop" and STACK.backs.names[string.lower(rest or "")] then
		db.backdrop = string.lower(rest)
		if RefreshOptions then
			RefreshOptions()
		end
		Print(L("crit backdrop: ") .. L(STACK.backs.names[db.backdrop]))
	elseif STACK.motion.names[command] then
		db.motion = command
		if RefreshOptions then
			RefreshOptions()
		end
		Print(L("motion: ") .. L(STACK.motion.names[command]) .. ". " .. L(STACK.motion.notes[command]))
	elseif command == "size" then
		local value = tonumber(rest)
		if value then
			if value > 3 then
				value = value / 100
			end
			db.size = Clamp(value, 0.6, 1.8)
			RefreshOptions()
			Print(string.format(L("size %d%%."), math.floor(db.size * 100 + 0.5)))
		else
			Help()
		end
	elseif command == "dots" or command == "dot" then
		db.dotTotals = not db.dotTotals
		RefreshOptions()
		if db.dotTotals then
			Print(L("DoT totals on: a DoT's damage adds up until its enemy dies."))
		else
			Print(L("DoT totals off: DoT ticks show like other hits."))
		end
	elseif command == "icons" then
		db.icons = not db.icons
		OnSettingChanged("icons")
		RefreshOptions()
		if db.icons then
			Print(L("skill icons on."))
		else
			Print(L("skill icons off."))
		end
	elseif command == "crowd" or command == "crowds" then
		db.crowd = not db.crowd
		RefreshOptions()
		if db.crowd then
			Print(L("a spell hitting 3 or more enemies now adds up into one number a second."))
		else
			Print(L("spells on crowds show on each enemy again."))
		end
	elseif command == "spells" or command == "spell" then
		db.bySpell = not db.bySpell
		RefreshOptions()
		if db.bySpell then
			Print(L("every spell now adds up into one number a second."))
		else
			Print(L("spells show on each enemy again (spells on crowds still merge if that's on)."))
		end
	elseif command == "preview" or command == "test" then
		StartTest()
	elseif command == "reset" then
		for key, value in pairs(DEFAULTS) do
			if key ~= "enabled" then
				db[key] = value
			end
		end
		ApplyFontAll()
		RefreshAllText()
		RefreshOptions()
		Print(L("settings reset."))
	else
		Help()
	end
end

CUI.numberSlash = function(msg)
	if blocked then
		Print(L("Smooth Numbers is still on, so it draws the numbers. Turn it off in Options -> AddOns."))
		return
	end
	NumberSlash(msg)
end
CUI.numberOptions = function()
	CUI.numberSlash("")
end
SLASH_CREEDUINUMBERS1 = "/sn"
SlashCmdList["CREEDUINUMBERS"] = CUI.numberSlash

CUI.RegisterPart({
	key = "numbers", name = "Damage numbers",
	note = "Your hits as calm numbers with the skill's icon. A spell hitting 3+ enemies adds up into one number a second.",
	get = function() return db and db.enabled and not blocked end,
	set = function(on) if db and not blocked then SetEnabled(on) end end,
	getScale = function() return db and db.size or 1 end,
	setScale = function(v)
		if db then
			db.size = Clamp(v, 0.6, 1.8)
			if RefreshOptions then RefreshOptions() end
		end
	end,
})

------------------------------------------------------------------------------
-- Events

local driver = CreateFrame("Frame", "CreedUINumbersDriver")
driver:RegisterEvent("VARIABLES_LOADED")
driver:RegisterEvent("PLAYER_ENTERING_WORLD")
driver:RegisterEvent("PLAYER_LEAVING_WORLD")
driver:RegisterEvent("PLAYER_LOGOUT")

driver:SetScript("OnEvent", function(self, eventArg, argument)
	local name = eventArg or event
	local first = argument or arg1
	if name == "VARIABLES_LOADED" then
		if not db then
			InitDB()
		end
		blocked = CUI.OldAddon("SmoothNumbers") -- the old addon draws the numbers then
	elseif name == "PLAYER_ENTERING_WORLD" then
		if not db then
			InitDB()
			blocked = CUI.OldAddon("SmoothNumbers")
		end
		lastNow = nil
		if db.enabled and not blocked then
			Activate()
		end
	elseif name == "PLAYER_LEAVING_WORLD" then
		ClearAll()
		cursor = nil
	elseif name == "PLAYER_LOGOUT" then
		-- Give the game its numbers back as it closes, so removing the addon
		-- leaves them on; they are switched off again at the next start.
		if db and active then
			ShowGameNumbers()
		end
	end
end)

-- If the game isn't calling our frame handler (the preview while off, or a
-- handler the game dropped), the numbers move from here instead, and the
-- handler is asked for again now and then.
local nextRegisterTry = 0
driver:SetScript("OnUpdate", function()
	if not db or blocked then
		return
	end
	local now = GetTime()
	if giveUp then
		giveUp = false
		errors = 0
		Print(L("too many problems, so it switched itself off and gave the game its numbers back. /creed numbers on to try again."))
		SetEnabled(false)
		return
	end
	if now - handlerAt <= 0.25 then
		return
	end
	if active or nLabels > 0 or testUntil then
		SafeStep(now)
	end
	if active and now - handlerAt > 1 and now >= nextRegisterTry then
		nextRegisterTry = now + 5
		local ok, result, failure = pcall(AZS_RegisterCombatTextFrameHandler, OnFrame)
		if ok and failure == nil and result ~= false then
			registered = true
		end
	end
end)
