-- Creed UI for Azeroth Survivors (WoW 1.12 client, Lua 5.0): the shared core.
-- Helpers every part uses, the saved settings, handing the game's own HUD parts back and forth,
-- frames you can move, the options hub and the /creed command.

CreedUI = {}
local C = CreedUI

C.VERSION = "1.24.2"
C.ART = "Interface\\AddOns\\CreedUI\\Art\\"
C.FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
C.FONT = "Fonts\\FRIZQT__.TTF"
C.TITLE_FONT = "Fonts\\MORPHEUS.TTF"

------------------------------------------------------------------------ math
function C.Clamp(v, lo, hi)
	if v < lo then return lo elseif v > hi then return hi end
	return v
end

function C.Smooth(p)
	if p <= 0 then return 0 elseif p >= 1 then return 1 end
	return p * p * (3 - 2 * p)
end

function C.Toward(cur, target, rate, dt)
	local v = cur + (target - cur) * (1 - math.exp(-rate * dt))
	if math.abs(target - v) < 0.001 then return target end -- land, so the writes stop
	return v
end

-- a critically damped spring: no overshoot, no stepping
function C.Spring(pos, vel, target, omega, dt)
	local x = pos - target
	local e = math.exp(-omega * dt)
	local c = vel + omega * x
	return target + (x + c * dt) * e, (vel - c * omega * dt) * e
end

-- an exponential approach that lands exactly on its target
function C.Ease(cur, target, k)
	local v = cur + (target - cur) * k
	if v - target < 0.0015 and target - v < 0.0015 then return target end
	return v
end

------------------------------------------------------------------------ writers that skip unchanged values
-- The client re-sorts and redraws on every write, so a frame at rest should cost nothing.
-- A region drawn through these must not be shown, hidden, sized or tinted any other way.
function C.Size(r, w, h)
	if r.mw ~= w or r.mh ~= h then
		r.mw, r.mh = w, h
		r:SetWidth(w)
		r:SetHeight(h)
	end
end

function C.Width(r, w)
	if r.mw ~= w then
		r.mw = w
		r:SetWidth(w)
	end
end

function C.Color(r, red, green, blue, a)
	if r.mr ~= red or r.mg ~= green or r.mb ~= blue or r.ma ~= a then
		r.mr, r.mg, r.mb, r.ma = red, green, blue, a
		r:SetVertexColor(red, green, blue, a)
	end
end

function C.TextColor(r, red, green, blue)
	if r.mr ~= red or r.mg ~= green or r.mb ~= blue then
		r.mr, r.mg, r.mb = red, green, blue
		r:SetTextColor(red, green, blue)
	end
end

function C.Vis(r, on)
	if on then
		if r.mv ~= true then
			r.mv = true
			r:Show()
		end
	elseif r.mv ~= false then
		r.mv = false
		r:Hide()
	end
end

function C.Alpha(r, a)
	if r.mal ~= a then
		r.mal = a
		r:SetAlpha(a)
	end
end

function C.SetText(fs, text)
	if fs.mt ~= text then
		fs.mt = text
		fs:SetText(text)
		fs.mtw = nil
	end
end

-- a font string's width, measured once per text (again while the font isn't ready)
function C.TextWidth(fs)
	if not fs.mtw or fs.mtw <= 0 then fs.mtw = fs:GetStringWidth() end
	return fs.mtw or 0
end

-- anchor a region at one point, skipping repeats
function C.Place(r, point, rel, relPoint, x, y)
	if r.mpx ~= x or r.mpy ~= y or r.mprel ~= rel or r.mpp ~= point then
		r.mpx, r.mpy, r.mprel, r.mpp = x, y, rel, point
		r:ClearAllPoints()
		r:SetPoint(point, rel, relPoint, x, y)
	end
end

------------------------------------------------------------------------ numbers as text
-- a skill's plain key: "ability:kill_command:r3" or "Kill Command" both "kill_command"
function C.SkillKey(k)
	if type(k) ~= "string" or k == "" then return nil end
	k = string.gsub(k, ":r%d+.*$", "")
	k = string.gsub(k, "^.*:", "")
	return string.lower((string.gsub(k, "[%s%-']+", "_")))
end

-- What each skill hits for, by its meter line (and its name): the last plain hit, an average of
-- the last few that settles as they come, the lowest and highest, the last crit, and how many hits
-- the last ten seconds saw. DoT ticks aside; crits apart from the plain hits.
C.hitValues = {}
function C.NoteHitValue(ev)
	local amount = tonumber(ev.amount)
	if ev.kind ~= "damage" or not amount or amount <= 0 or ev.periodic then return end
	-- by its meter line, its name, and its plain key ("ability:kill_command:r3" as "kill_command",
	-- every rank one), so a skill is found however the hit names it
	-- the meter's line decides which skill a hit is; its ability name only when it has none
	local keys
	if ev.meterSourceKey ~= nil then
		keys = { ev.meterSourceKey, C.SkillKey(ev.meterSourceKey), ev.meterSource }
	else
		keys = { ev.meterSource, ev.abilityName, C.SkillKey(ev.meterSource or ev.abilityName) }
	end
	local v
	for i = 1, 3 do
		if keys[i] ~= nil and C.hitValues[keys[i]] then v = C.hitValues[keys[i]] end
	end
	if not v then v = { times = {} } end
	for i = 1, 3 do
		if keys[i] ~= nil then C.hitValues[keys[i]] = v end
	end
	if ev.critical then
		v.crit = amount
	else
		v.avg = v.avg and (v.avg + (amount - v.avg) * 0.25) or amount
		v.last = amount
		if not v.low or amount < v.low then v.low = amount end
		if not v.high or amount > v.high then v.high = amount end
	end
	local now = GetTime()
	table.insert(v.times, now)
	while table.getn(v.times) > 0 and (now - v.times[1] > 10 or table.getn(v.times) > 200) do table.remove(v.times, 1) end
end

-- its hits per second over the last ten seconds
function C.HitRate(v)
	if not v or not v.times then return 0 end
	local now, n = GetTime(), 0
	for i = 1, table.getn(v.times) do
		if now - v.times[i] <= 10 then n = n + 1 end
	end
	return n / 10
end

function C.Short(n)
	n = n or 0
	local neg = n < 0
	if neg then n = -n end
	local s
	if n >= 1e12 then s = string.format("%.1fT", math.floor(n / 1e11) / 10)
	elseif n >= 1e9 then s = string.format("%.1fB", math.floor(n / 1e8) / 10)
	elseif n >= 1e6 then s = string.format("%.1fM", math.floor(n / 1e5) / 10)
	elseif n >= 1e4 then s = string.format("%.1fK", math.floor(n / 1e2) / 10)
	else s = C.Commas(math.floor(n + 0.5)) end
	s = string.gsub(s, "%.0([KMBT])", "%1")
	if neg then s = "-" .. s end
	return s
end

function C.Commas(n)
	local s = tostring(math.floor(n))
	local out = ""
	while string.len(s) > 3 do
		out = "," .. string.sub(s, -3) .. out
		s = string.sub(s, 1, -4)
	end
	return s .. out
end

-- seconds as m:ss, or h:mm:ss from an hour
function C.Clock(s)
	s = math.floor(math.max(0, s or 0))
	local h, m, sec = math.floor(s / 3600), math.floor(math.mod(s, 3600) / 60), math.mod(s, 60)
	if h > 0 then return string.format("%d:%02d:%02d", h, m, sec) end
	return string.format("%d:%02d", m, sec)
end

function C.Print(msg)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cffffcc55Creed UI|r: " .. msg)
	end
end

------------------------------------------------------------------------ languages
-- Creed UI's own words in the language picked (the game's own names, of bosses, zones and
-- spells, come in the game's language already). English is the source: each language's table
-- (Locale.lua) maps the English words to its own. In a template, {1}, {2}... stand for what goes
-- in, in whatever order the language wants them. Changing the language changes the words at once:
-- a text set with C.LText follows by itself; a part that makes its words once and keeps them
-- watches C.langStamp, or asks C.OnLanguage to tell it.
C.LANGS = {}
C.LANG_LIST = { { code = "en", name = "English" } }
C.lang, C.langStamp = "en", 0
C.ltexts, C.langHooks = {}, {}
local words = nil

function C.L(s)
	local t = words
	return t and t[s] or s
end

function C.F(template, ...)
	local args = arg
	return (string.gsub(C.L(template), "{(%d)}", function(n)
		local v = args[tonumber(n)]
		if v == nil then return "" end
		return tostring(v)
	end))
end

-- a font string whose words are always in the language picked
function C.LText(fs, key)
	if fs.lkey == nil then table.insert(C.ltexts, fs) end
	fs.lkey = key
	C.SetText(fs, C.L(key))
end

function C.OnLanguage(fn) table.insert(C.langHooks, fn) end

-- a language: its code, its name in its own words, the face its letters need (nil: Friz Quadrata
-- and Morpheus have them; below), and its words
C.SCRIPTS = {}
function C.AddLanguage(code, name, face, words)
	C.LANGS[code] = words
	if type(face) ~= "string" then face = nil end
	table.insert(C.LANG_LIST, { code = code, name = name, face = face })
	C.SCRIPTS[code] = face
end

------------------------------------------------------------------------ faces
-- Creed UI draws its words in Friz Quadrata and Morpheus, which have no Cyrillic, no Chinese,
-- Japanese or Korean, and not all of Polish or Turkish; the client draws nothing for a letter its
-- face lacks. So a language in other letters draws everything in a face of Creed UI's own that has
-- them (Fonts\, both under the SIL Open Font License), and back to the two when the language is
-- changed again. Each font string made through C.Text or C.SetFace is kept so its face can change.
C.FACE_LETTERS = "Interface\\AddOns\\CreedUI\\Fonts\\Letters.ttf" -- Latin, Latin Extended-A, Cyrillic
C.FACE_CJK = "Interface\\AddOns\\CreedUI\\Fonts\\LettersCJK.ttf" -- Chinese, Japanese, Korean (and Latin, Cyrillic)
C.faced = {}
local langFace = nil

-- the face to draw in, for one Creed UI meant
function C.Face(face)
	return langFace or face or C.FONT
end

-- a font string's face, size and flags, kept so the face can change with the language; `fixed`
-- draws it in that face whatever the language (a language's name in its own letters)
function C.SetFace(fs, face, size, flags, fixed)
	if not fs.cface then table.insert(C.faced, fs) end
	fs.cface, fs.csize, fs.cflags, fs.cfixed = face or C.FONT, size, flags, fixed
	fs:SetFont(fixed or C.Face(fs.cface), size, flags)
	fs.mtw = nil
end

local function Reface(code)
	local want = C.SCRIPTS[code]
	if want == langFace then return end
	langFace = want
	for i = 1, table.getn(C.faced) do
		local fs = C.faced[i]
		fs:SetFont(fs.cfixed or C.Face(fs.cface), fs.csize, fs.cflags)
		fs.mtw = nil
	end
end

-- the game's tooltip in that face while it carries Creed UI's words (its own faces lack these
-- letters too): each line's font is kept and comes back the moment anyone takes the tooltip again
local tipKept, tipHooked = {}, false
local function TipBack()
	if not next(tipKept) then return end
	for fs, k in pairs(tipKept) do
		if k.object then fs:SetFontObject(k.object) end -- following the game's font again
		if k.face and fs:GetFont() ~= k.face then fs:SetFont(k.face, k.size, k.flags) end
	end
	tipKept = {}
end
local function TipFace(fs)
	local face, size, flags = fs:GetFont()
	if not tipKept[fs] then
		tipKept[fs] = { object = fs.GetFontObject and fs:GetFontObject() or nil, face = face, size = size or 12, flags = flags }
	end
	if face ~= langFace then fs:SetFont(langFace, size or 12, flags) end
end
function C.ShowTip()
	local tip = GameTooltip
	if not tip then return end
	if not tipHooked and type(tip.SetOwner) == "function" then
		tipHooked = true
		local own = tip.SetOwner
		tip.SetOwner = function(self, ...)
			TipBack()
			return own(self, unpack(arg))
		end
	end
	if langFace then
		local i = 1
		while getglobal("GameTooltipTextLeft" .. i) do
			TipFace(getglobal("GameTooltipTextLeft" .. i))
			local r = getglobal("GameTooltipTextRight" .. i)
			if r then TipFace(r) end
			i = i + 1
		end
	else
		TipBack()
	end
	tip:Show()
end

function C.LangName(code)
	for i = 1, table.getn(C.LANG_LIST) do
		if C.LANG_LIST[i].code == code then return C.LANG_LIST[i].name end
	end
	return code
end

-- the client's language, as far as it tells (the game's own picker can say another: the menu or
-- /creed language sets it then)
local LOCALES = { frFR = "fr", deDE = "de", esES = "es", esMX = "es", ptBR = "pt", ptPT = "pt", zhCN = "zh", zhTW = "zh",
	ruRU = "ru", koKR = "ko", jaJP = "ja", plPL = "pl", trTR = "tr" }
function C.DetectLanguage()
	local ok, loc = false, nil
	if type(GetLocale) == "function" then ok, loc = pcall(GetLocale) end
	local code = ok and LOCALES[loc] or nil
	if code and C.LANGS[code] then return code end
	return "en"
end

function C.SetLanguage(code, save)
	if code ~= "en" and not C.LANGS[code] then return false end
	C.lang = code
	words = C.LANGS[code]
	C.langStamp = C.langStamp + 1
	if save then C.Root().lang = code end
	Reface(code)
	for i = 1, table.getn(C.ltexts) do
		local fs = C.ltexts[i]
		C.SetText(fs, C.L(fs.lkey))
	end
	for i = 1, table.getn(C.langHooks) do pcall(C.langHooks[i]) end
	return true
end

------------------------------------------------------------------------ regions
function C.Tex(parent, layer, file, blend)
	local t = parent:CreateTexture(nil, layer)
	t:SetTexture(file)
	if blend then t:SetBlendMode(blend) end
	return t
end

function C.Text(parent, font, size, flags, justify, width)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	C.SetFace(fs, font or C.FONT, size, flags)
	fs:SetJustifyH(justify or "CENTER")
	if width then fs:SetWidth(width) end
	fs:SetShadowColor(0, 0, 0, 1)
	fs:SetShadowOffset(1, -1)
	return fs
end

-- a child frame covering its parent, drawn above it
function C.Layer(parent)
	local f = CreateFrame("Frame", nil, parent)
	f:SetAllPoints(parent)
	return f
end

------------------------------------------------------------------------ the map's colors
-- The boss timer owns the theme (it knows the zone) and shares its gliding palette here.
C.DEFAULT_PAL = {
	title = { 1.00, 0.84, 0.40 }, rim = { 0.95, 0.80, 0.46 },
	fillA = { 0.08, 0.18, 0.46 }, fillM = { 0.20, 0.44, 0.88 }, fillB = { 0.56, 0.80, 1.00 },
	glow = { 0.72, 0.88, 1.00 }, gem = { 1.00, 0.80, 0.30 }, trough = { 0.03, 0.04, 0.08 },
	mc = { 0.75, 0.88, 1.00 },
}
C.palStamp = 0
-- Every part's metal is the skill bar's bronze gold, in every zone: the zone's palette (the timer's,
-- which keeps its own colors) with its rims, titles, gems, glows and troughs swapped for it.
C.BRONZE = {
	title = { 0.98, 0.85, 0.52 }, rim = { 0.95, 0.79, 0.44 }, gem = { 1.00, 0.78, 0.32 },
	glow = { 1.00, 0.80, 0.45 }, trough = { 0.07, 0.05, 0.03 }, mc = { 1.00, 0.88, 0.60 },
}
-- The UI's theme: the hero's class, always (1.21.4, asked for: no choice, and no bronze look any
-- more). It recolors every part's rims, titles, gems, glows and glass in the class's metal, and puts
-- the class's emblem, crest and rails (from the user's own picture) on the skill bar; the boss timer
-- keeps its bronze (C.BRONZE) whatever the class.
C.UI_THEMES = {
	{ key = "warrior", name = "Warrior", emblem = "Warrior", fill = { 0.70, 0.22, 0.14 },
		metal = { 0.80, 0.64, 0.46 },
		title = { 0.92, 0.80, 0.64 }, rim = { 0.80, 0.64, 0.46 }, gem = { 0.92, 0.26, 0.18 },
		glow = { 1.00, 0.55, 0.35 }, trough = { 0.08, 0.04, 0.03 }, mc = { 0.96, 0.82, 0.64 } },
	{ key = "paladin", name = "Paladin", emblem = "Paladin", fill = { 0.80, 0.60, 0.30 },
		metal = { 0.96, 0.62, 0.78 },
		title = { 1.00, 0.82, 0.90 }, rim = { 0.96, 0.62, 0.78 }, gem = { 1.00, 0.85, 0.40 },
		glow = { 1.00, 0.75, 0.88 }, trough = { 0.07, 0.03, 0.05 }, mc = { 1.00, 0.86, 0.93 } },
	{ key = "hunter", name = "Hunter", emblem = "Hunter", fill = { 0.42, 0.62, 0.22 },
		metal = { 0.64, 0.82, 0.42 },
		title = { 0.82, 0.94, 0.62 }, rim = { 0.64, 0.82, 0.42 }, gem = { 0.56, 0.88, 0.30 },
		glow = { 0.76, 0.96, 0.56 }, trough = { 0.03, 0.06, 0.02 }, mc = { 0.86, 0.97, 0.72 } },
	{ key = "rogue", name = "Rogue", emblem = "Rogue", fill = { 0.62, 0.32, 0.75 },
		metal = { 0.94, 0.88, 0.40 },
		title = { 1.00, 0.97, 0.62 }, rim = { 0.94, 0.88, 0.40 }, gem = { 1.00, 0.94, 0.34 },
		glow = { 1.00, 0.97, 0.56 }, trough = { 0.06, 0.06, 0.02 }, mc = { 1.00, 0.98, 0.72 } },
	{ key = "priest", name = "Priest", emblem = "Priest", fill = { 0.75, 0.72, 0.62 },
		metal = { 0.84, 0.86, 0.92 },
		title = { 0.97, 0.97, 1.00 }, rim = { 0.84, 0.86, 0.92 }, gem = { 0.90, 0.93, 1.00 },
		glow = { 0.95, 0.96, 1.00 }, trough = { 0.05, 0.05, 0.07 }, mc = { 1.00, 1.00, 1.00 } },
	{ key = "shaman", name = "Shaman", emblem = "Shaman", fill = { 0.18, 0.45, 0.90 },
		metal = { 0.30, 0.58, 0.95 },
		title = { 0.58, 0.82, 1.00 }, rim = { 0.30, 0.58, 0.95 }, gem = { 0.32, 0.66, 1.00 },
		glow = { 0.46, 0.76, 1.00 }, trough = { 0.02, 0.04, 0.08 }, mc = { 0.66, 0.86, 1.00 } },
	{ key = "mage", name = "Mage", emblem = "Mage", fill = { 0.25, 0.50, 0.95 },
		metal = { 0.48, 0.82, 0.95 },
		title = { 0.72, 0.93, 1.00 }, rim = { 0.48, 0.82, 0.95 }, gem = { 0.56, 0.88, 1.00 },
		glow = { 0.66, 0.92, 1.00 }, trough = { 0.02, 0.05, 0.07 }, mc = { 0.80, 0.95, 1.00 } },
	{ key = "warlock", name = "Warlock", emblem = "Warlock", fill = { 0.62, 0.20, 0.75 },
		metal = { 0.64, 0.55, 0.86 },
		title = { 0.84, 0.76, 1.00 }, rim = { 0.64, 0.55, 0.86 }, gem = { 0.64, 0.42, 0.96 },
		glow = { 0.76, 0.64, 1.00 }, trough = { 0.04, 0.03, 0.07 }, mc = { 0.86, 0.80, 1.00 } },
	{ key = "druid", name = "Druid", emblem = "Druid", fill = { 0.40, 0.65, 0.20 },
		metal = { 1.00, 0.58, 0.16 },
		title = { 1.00, 0.76, 0.44 }, rim = { 1.00, 0.58, 0.16 }, gem = { 1.00, 0.56, 0.10 },
		glow = { 1.00, 0.68, 0.30 }, trough = { 0.07, 0.04, 0.01 }, mc = { 1.00, 0.82, 0.52 } },
}
C.UI_THEME = C.UI_THEMES[1]
C.uiTheme = "warrior"

local function FindTheme(key)
	for i = 1, table.getn(C.UI_THEMES) do
		if C.UI_THEMES[i].key == key then return C.UI_THEMES[i] end
	end
end

-- the hero's class as a theme key: the class of the hero this run was started with (read from the
-- run's own loadout: its hero's classKey; asked for, as the game's character class needn't be the
-- run's hero's), else the last run's (kept in the settings), else the game's class, else a warrior
local function ClassKey(v)
	if type(v) ~= "string" then return nil end
	local _, _, word = string.find(string.lower(v), "(%a+)$")
	return word and FindTheme(word) and word or nil
end
function C.HeroClass()
	if C.runClass then return C.runClass end
	local saved = CreedUIDB and ClassKey(CreedUIDB.heroClass)
	if saved then return saved end
	local _, class = UnitClass("player")
	return ClassKey(class) or "warrior"
end

-- each run's hero class, read once its loadout is in (looked at every second until then)
local classRun, classAsked = nil, 0
function C.WatchRunClass(now)
	if now - classAsked < 1 or type(AZS_GetMeterContext) ~= "function" or type(AZS_GetMeterLoadout) ~= "function" then return end
	classAsked = now
	local context = C.Call(AZS_GetMeterContext)
	if type(context) ~= "table" or not context.runId or context.runId == classRun then return end
	local l = C.Call(AZS_GetMeterLoadout, { apiVersion = 1, runId = context.runId })
	local me = type(l) == "table" and type(l.actors) == "table" and l.actors[context.localOwnerId or l.ownerId or ""]
	local class = type(me) == "table" and ClassKey(me.classKey)
	if not class then return end
	classRun, C.runClass = context.runId, class
	if CreedUIDB then CreedUIDB.heroClass = class end
	C.SetTheme("class")
end

-- puts on a class's theme ("class": the hero's) and recolors every part
function C.SetTheme(key)
	if key == "class" then key = C.HeroClass() end
	local t = FindTheme(key)
	if not t then return false end
	C.uiTheme = key
	if t ~= C.UI_THEME then
		C.UI_THEME = t
		C.palStamp = C.palStamp + 1
	end
	return true
end

local bronzed, bronzedFrom, bronzedAt = {}, nil, nil
function C.Pal()
	local base = C.pal or C.DEFAULT_PAL
	if base ~= bronzedFrom or C.palStamp ~= bronzedAt then
		bronzedFrom, bronzedAt = base, C.palStamp
		for k, v in pairs(base) do bronzed[k] = v end
		for k, v in pairs(C.BRONZE) do bronzed[k] = C.UI_THEME[k] or v end
	end
	return bronzed
end

------------------------------------------------------------------------ saved settings
C.inits, C.worlds, C.logouts = {}, {}, {}
function C.OnInit(fn) table.insert(C.inits, fn) end
function C.OnWorld(fn) table.insert(C.worlds, fn) end
function C.OnLogout(fn) table.insert(C.logouts, fn) end

function C.Root()
	if type(CreedUIDB) ~= "table" then CreedUIDB = {} end
	return CreedUIDB
end

-- a part's own table inside CreedUIDB, with its defaults filled in
function C.DB(name, defaults)
	local root = C.Root()
	root.drops = nil -- the drops window is gone: forget what it kept
	if type(root[name]) ~= "table" then root[name] = {} end
	local db = root[name]
	if defaults then
		for k, v in pairs(defaults) do
			if db[k] == nil then db[k] = v end
		end
	end
	return db
end

------------------------------------------------------------------------ the game's own HUD parts
-- Each part is hidden only while the Creed UI part that replaces it is on, and only what we
-- hid is shown again (a part the player had turned off stays off).
function C.TakeHud(part)
	if type(AZS_SetHudShown) ~= "function" or type(AZS_IsHudShown) ~= "function" then return end
	local ok, shown = pcall(AZS_IsHudShown, part)
	if ok and shown then
		local root = C.Root()
		if type(root.hudWas) ~= "table" then root.hudWas = {} end
		root.hudWas[part] = true
		pcall(AZS_SetHudShown, part, false)
	end
end

function C.ReleaseHud(part)
	local root = C.Root()
	if type(root.hudWas) == "table" and root.hudWas[part] and type(AZS_SetHudShown) == "function" then
		pcall(AZS_SetHudShown, part, true)
		root.hudWas[part] = nil
	end
end

-- stock frames (PlayerFrame, TargetFrame, MainMenuBar...) go under a hidden parent
C.hidden = CreateFrame("Frame", "CreedUIHidden", UIParent)
C.hidden:Hide()
C.stock = {}
function C.HideStock(name)
	local f = getglobal(name)
	if type(f) ~= "table" or C.stock[name] or type(f.SetParent) ~= "function" then return end
	C.stock[name] = f:GetParent() or UIParent
	f:SetParent(C.hidden)
end

function C.RestoreStock(name)
	local f, parent = getglobal(name), C.stock[name]
	if type(f) == "table" and parent then
		f:SetParent(parent)
		C.stock[name] = nil
	end
end

------------------------------------------------------------------------ a bar in the timer's style
-- A dark glass trough, a shaded fill with a three-color gradient, an echo of lost health, a
-- shield, flowing light, a gloss, a glowing head and the timer's metal rim. Text sits on top.
local FLOW_SIZE, FLOW_PERIOD = 1024, 0.125 -- the flow art spans 1024 px (stored 512 wide: the game's limit)

function C.NewBar(parent, w, h, flow)
	local b = { w = w, h = h, value = 0, vel = 0, echo = 0, echoHold = 0, shield = 0, shieldShown = 0,
		flowU = math.random() * FLOW_PERIOD, flow = flow and true or false, snap = true }
	local base = CreateFrame("Frame", nil, parent)
	b.frame = base
	C.Size(base, w, h)
	b.trough = C.Tex(base, "BACKGROUND", C.FLAT)
	b.trough:SetAllPoints(base)
	b.echoTex = C.Tex(base, "BORDER", C.FLAT)
	b.echoTex:SetPoint("TOPLEFT", base, "TOPLEFT", 0, 0)
	b.echoTex:SetPoint("BOTTOMLEFT", base, "BOTTOMLEFT", 0, 0)
	b.fillA = C.Tex(base, "ARTWORK", C.ART .. "Fill")
	b.fillA:SetPoint("TOPLEFT", base, "TOPLEFT", 0, 0)
	b.fillA:SetPoint("BOTTOMLEFT", base, "BOTTOMLEFT", 0, 0)
	b.fillB = C.Tex(base, "ARTWORK", C.ART .. "Fill")
	b.fillB:SetPoint("TOPLEFT", b.fillA, "TOPRIGHT", 0, 0)
	b.fillB:SetPoint("BOTTOMLEFT", b.fillA, "BOTTOMRIGHT", 0, 0)
	b.fx = C.Layer(base)
	b.flowTex = C.Tex(b.fx, "BACKGROUND", C.ART .. "Flow", "ADD")
	b.flowTex:SetPoint("TOPLEFT", base, "TOPLEFT", 0, 0)
	b.flowTex:SetPoint("BOTTOMLEFT", base, "BOTTOMLEFT", 0, 0)
	b.gloss = C.Tex(b.fx, "BORDER", C.FLAT)
	b.gloss:SetPoint("TOPLEFT", base, "TOPLEFT", 0, 0)
	b.gloss:SetPoint("TOPRIGHT", base, "TOPRIGHT", 0, 0)
	b.gloss:SetGradientAlpha("VERTICAL", 1, 1, 1, 0, 1, 1, 1, 0.16)
	-- a shield: an icy pane with drifting stripes and a bright edge where it begins
	b.shieldTex = C.Tex(b.fx, "ARTWORK", C.FLAT)
	b.shieldTex:SetGradientAlpha("VERTICAL", 0.24, 0.56, 1, 0.78, 0.74, 0.92, 1, 0.9)
	b.shieldTex:SetPoint("TOPLEFT", base, "TOPLEFT", 0, 0)
	b.stripeTex = C.Tex(b.fx, "OVERLAY", C.ART .. "Stripes", "ADD")
	b.stripeTex:SetVertexColor(0.86, 0.96, 1)
	b.stripeTex:SetPoint("TOPLEFT", base, "TOPLEFT", 0, 0)
	b.edgeTex = C.Tex(b.fx, "OVERLAY", C.FLAT)
	b.edgeTex:SetVertexColor(0.9, 0.98, 1, 0.95)
	b.edgeTex:SetPoint("TOPLEFT", base, "TOPLEFT", 0, 0)
	b.spark = C.Tex(b.fx, "OVERLAY", C.ART .. "Spark", "ADD")
	b.rim = C.Layer(base)
	b.rimL = C.Tex(b.rim, "ARTWORK", C.ART .. "FrameL")
	b.rimR = C.Tex(b.rim, "ARTWORK", C.ART .. "FrameR")
	b.rimM = C.Tex(b.rim, "ARTWORK", C.ART .. "FrameM")
	b.top = C.Layer(base)
	C.BarLayout(b, w, h)
	C.Vis(b.shieldTex, false)
	C.Vis(b.stripeTex, false)
	C.Vis(b.edgeTex, false)
	C.Vis(b.echoTex, false)
	return b
end

function C.BarLayout(b, w, h)
	b.w, b.h = w, h
	C.Size(b.frame, w, h)
	local k = h / 12
	local rimH, reach = 22 * k, 11 * k
	b.rimL:SetWidth(rimH)
	b.rimL:SetHeight(rimH)
	b.rimL:ClearAllPoints()
	b.rimL:SetPoint("LEFT", b.frame, "LEFT", -reach, 0)
	b.rimR:SetWidth(rimH)
	b.rimR:SetHeight(rimH)
	b.rimR:ClearAllPoints()
	b.rimR:SetPoint("RIGHT", b.frame, "RIGHT", reach, 0)
	b.rimM:SetHeight(rimH)
	b.rimM:ClearAllPoints()
	b.rimM:SetPoint("LEFT", b.rimL, "RIGHT", 0, 0)
	b.rimM:SetPoint("RIGHT", b.rimR, "LEFT", 0, 0)
	b.gloss:SetHeight(math.max(2, h * 0.5))
	b.spark:SetWidth(math.max(6, h * 0.9))
	b.spark:SetHeight(h * 2.4)
	b.drawnW = nil
end

-- levels: call after the bar's frame is shown under its owner
function C.BarLevels(b, base)
	b.frame:SetFrameLevel(base)
	b.fx:SetFrameLevel(base + 1)
	b.rim:SetFrameLevel(base + 2)
	b.top:SetFrameLevel(base + 3)
end

-- colors: the fill runs a -> m -> b; trough and rim come from the map's palette
function C.BarColors(b, a, m, c)
	b.fillA:SetGradientAlpha("HORIZONTAL", a[1], a[2], a[3], 1, m[1], m[2], m[3], 1)
	b.fillB:SetGradientAlpha("HORIZONTAL", m[1], m[2], m[3], 1, c[1], c[2], c[3], 1)
	b.headR, b.headG, b.headB = 0.55 + c[1] * 0.45, 0.55 + c[2] * 0.45, 0.55 + c[3] * 0.45
end

function C.BarTheme(b, pal)
	local rim, tr = pal.rim, pal.trough
	b.rimL:SetVertexColor(rim[1], rim[2], rim[3])
	b.rimM:SetVertexColor(rim[1], rim[2], rim[3])
	b.rimR:SetVertexColor(rim[1], rim[2], rim[3])
	b.trough:SetVertexColor(tr[1] * 0.8, tr[2] * 0.8, tr[3] * 0.8, 0.92)
end

-- move the bar toward `target` (0..1): it glides up, and a drop leaves a pale echo that
-- lingers a moment, then drains after the fill. The echo waits only when it had caught up, and
-- the longer it is the faster it drains, so a stream of big hits never leaves it parked behind.
local ECHO_HOLD, ECHO_RATE, ECHO_FLOOR = 0.2, 7, 0.35 -- seconds; per second; bar per second

function C.BarStep(b, target, dt, now)
	target = C.Clamp(target or 0, 0, 1)
	if b.snap then
		b.value, b.vel, b.echo, b.snap = target, 0, target, nil
		b.lastTarget = target
	end
	if target < (b.lastTarget or target) - 0.0005 then
		-- a hit: the echo marks where the fill stood
		if b.echo < b.value then b.echo = b.value end
		if b.echo - b.value < 0.01 then b.echoHold = ECHO_HOLD end
	end
	b.lastTarget = target
	b.value, b.vel = C.Spring(b.value, b.vel, target, 16, dt)
	if math.abs(b.value - target) < 0.0004 and math.abs(b.vel) < 0.004 then b.value, b.vel = target, 0 end
	if b.value < 0 then b.value, b.vel = 0, 0 end
	if b.echoHold > 0 then
		b.echoHold = b.echoHold - dt
	else
		local gap = b.echo - b.value
		if gap > 0 then
			b.echo = b.echo - math.min(gap, gap * (1 - math.exp(-ECHO_RATE * dt)) + ECHO_FLOOR * dt)
		end
	end
	if b.echo < b.value then b.echo = b.value end
	if b.echo - b.value < 0.002 then b.echo = b.value end

	local w = b.w
	local fw = w * b.value
	if fw < 0.6 then
		C.Vis(b.fillA, false)
		C.Vis(b.fillB, false)
		C.Vis(b.flowTex, false)
		C.Vis(b.spark, false)
	else
		local half = fw * 0.5
		C.Width(b.fillA, half)
		C.Width(b.fillB, fw - half)
		local fa = C.Smooth(fw / 4)
		C.Alpha(b.fillA, fa)
		C.Alpha(b.fillB, fa)
		C.Vis(b.fillA, true)
		C.Vis(b.fillB, true)
		if b.flow and CreedUIDB and not CreedUIDB.calm then
			b.flowU = math.mod(b.flowU + dt * 20 / FLOW_SIZE, FLOW_PERIOD)
			local u = FLOW_PERIOD - b.flowU
			C.Width(b.flowTex, fw)
			b.flowTex:SetTexCoord(u, u + fw / FLOW_SIZE, 0, 1)
			C.Vis(b.flowTex, true)
		else
			C.Vis(b.flowTex, false)
		end
		-- the head glows while the bar moves, and rests dim
		local moving = C.Clamp(math.abs(b.vel) * 12 + (b.echo - b.value) * 6, 0, 1)
		local a = (0.22 + 0.55 * moving) * C.Smooth(fw / 6) * C.Smooth((w - fw) / 3 + 0.3)
		C.Place(b.spark, "CENTER", b.frame, "LEFT", fw, 0)
		C.Color(b.spark, b.headR or 1, b.headG or 1, b.headB or 1, a)
		C.Vis(b.spark, a > 0.01)
	end
	-- every strip gets its height as well as its width: a single anchor carries no height
	local ew = w * (b.echo - b.value)
	if ew > 0.5 then
		C.Place(b.echoTex, "TOPLEFT", b.frame, "TOPLEFT", fw, 0)
		C.Size(b.echoTex, ew, b.h)
		C.Color(b.echoTex, 1, 0.92, 0.82, 0.55 * C.Smooth(ew / 3))
		C.Vis(b.echoTex, true)
	else
		C.Vis(b.echoTex, false)
	end
	C.BarShield(b, w, fw, dt, now)
	return fw
end

-- a shield sits after the health, laid over its end when it doesn't fit; it flashes as it grows
local STRIPE_SPAN, STRIPE_PERIOD = 256, 8 -- the stripes art spans 256 px, a stripe every 8

function C.BarShield(b, w, fw, dt, now)
	local sh = C.Clamp(b.shield or 0, 0, 1)
	if sh > (b.shieldLast or 0) + 0.01 then b.shieldFlash = 1 end
	b.shieldLast = sh
	b.shieldShown = C.Ease(b.shieldShown, sh, 1 - math.exp(-dt * 10))
	local sw = math.min(w * b.shieldShown, w)
	if sw <= 0.6 then
		C.Vis(b.shieldTex, false)
		C.Vis(b.stripeTex, false)
		C.Vis(b.edgeTex, false)
		b.shieldFlash = 0
		return
	end
	local x0, h = fw, b.h
	if x0 + sw > w then x0 = math.max(0, w - sw) end
	local flash = b.shieldFlash or 0
	if flash > 0 then b.shieldFlash = math.max(0, flash - dt * 2.5) end
	local t = now or 0
	C.Place(b.shieldTex, "TOPLEFT", b.frame, "TOPLEFT", x0, 0)
	C.Size(b.shieldTex, sw, h)
	C.Alpha(b.shieldTex, math.min(1, 0.84 + 0.06 * math.sin(t * 2.6) + 0.16 * flash))
	C.Vis(b.shieldTex, true)
	-- the stripes drift slowly (still with the calm option)
	local drift = 0
	if not (CreedUIDB and CreedUIDB.calm) then drift = math.mod(t * 7, STRIPE_PERIOD) end
	local u0 = (x0 + STRIPE_PERIOD - drift) / STRIPE_SPAN
	local u1 = u0 + sw / STRIPE_SPAN
	if u1 > 1 then u0, u1 = u0 - (u1 - 1), 1 end
	if b.stripeU0 ~= u0 or b.stripeU1 ~= u1 then
		b.stripeU0, b.stripeU1 = u0, u1
		b.stripeTex:SetTexCoord(u0, u1, 0, 1)
	end
	C.Place(b.stripeTex, "TOPLEFT", b.frame, "TOPLEFT", x0, 0)
	C.Size(b.stripeTex, sw, h)
	C.Alpha(b.stripeTex, math.min(1, 0.5 + 0.35 * flash))
	C.Vis(b.stripeTex, true)
	-- a bright edge where the shield begins
	C.Place(b.edgeTex, "TOPLEFT", b.frame, "TOPLEFT", math.max(0, x0 - 1), 0)
	C.Size(b.edgeTex, 2, h)
	C.Vis(b.edgeTex, true)
end

------------------------------------------------------------------------ sizing by edges and corners
-- Grab strips on a frame's edges and squares on its corners, an arrow by the mouse showing the
-- way (the art's four: across, up and down, the two diagonals). spec:
--   edges = { LEFT = true, TOPRIGHT = true, ... }
--   can() -> may it be sized now; start(edge); move(edge, dx, dy) in UIParent's units; stop(edge)
-- Call the returned sizer's step() every frame. (The meter has its own, for its lines.)
local SIZE_CELLS = { LEFT = 1, RIGHT = 1, TOP = 2, BOTTOM = 2, TOPLEFT = 3, BOTTOMRIGHT = 3, TOPRIGHT = 4, BOTTOMLEFT = 4 }
local SIZE_TC = { { 0, 0.5, 0, 0.5 }, { 0.5, 1, 0, 0.5 }, { 0, 0.5, 0.5, 1 }, { 0.5, 1, 0.5, 1 } }

local function UICursor()
	local x, y = GetCursorPosition()
	local s = UIParent:GetEffectiveScale() or 1
	return (x or 0) / s, (y or 0) / s
end
C.UICursor = UICursor

-- Over an edge that sizes a window, the cursor itself becomes the arrow (the game's hand would sit
-- on a drawn one); it's the game's again the moment the mouse leaves, lets go or the window hides.
-- Without the game's SetCursor, the arrow is drawn by the cursor instead.
local SIZE_CURSORS = { C.ART .. "CursorSizeH", C.ART .. "CursorSizeV", C.ART .. "CursorSizeD1", C.ART .. "CursorSizeD2" }
local cursorBy, cursorAt = nil, 0
local function CursorOn(owner, cell)
	if type(SetCursor) ~= "function" then return false end
	-- set again now and then: the game may take it back when the mouse crosses another frame
	local now = GetTime()
	if cursorBy ~= owner or cursorBy.cell ~= cell or now - cursorAt > 0.25 then
		cursorBy, cursorAt = owner, now
		owner.cell = cell
		pcall(SetCursor, SIZE_CURSORS[cell])
	end
	return true
end
local function CursorOff(owner)
	if cursorBy ~= owner then return end
	cursorBy = nil
	if type(ResetCursor) == "function" then pcall(ResetCursor) elseif type(SetCursor) == "function" then pcall(SetCursor, nil) end
end
C.SizeCursor, C.SizeCursorOff = CursorOn, CursorOff -- the meter's own edges too

function C.Sizers(frame, name, spec)
	local z = { handles = {} }
	local function Start()
		if not spec.can() then return end
		z.active = this.edge
		z.x, z.y = UICursor()
		spec.start(z.active)
	end
	local function Stop()
		if not z.active then return end
		local edge = z.active
		z.active = nil
		spec.stop(edge)
	end
	for edge in pairs(spec.edges) do
		local h = CreateFrame("Frame", nil, frame)
		h.edge = edge
		if edge == "LEFT" or edge == "RIGHT" then
			h:SetPoint("TOPLEFT", frame, "TOP" .. edge, -3, -6)
			h:SetPoint("BOTTOMRIGHT", frame, "BOTTOM" .. edge, 3, 6)
		elseif edge == "TOP" or edge == "BOTTOM" then
			h:SetPoint("TOPLEFT", frame, edge .. "LEFT", 6, 3)
			h:SetPoint("BOTTOMRIGHT", frame, edge .. "RIGHT", -6, -3)
		else
			h:SetWidth(12)
			h:SetHeight(12)
			h:SetPoint("CENTER", frame, edge, 0, 0)
		end
		h:EnableMouse(true)
		h:RegisterForDrag("LeftButton")
		h:SetScript("OnEnter", function() z.hover = this.edge end)
		h:SetScript("OnLeave", function()
			if z.hover == this.edge then z.hover = nil end
			if not z.active then CursorOff(z) end
		end)
		h:SetScript("OnMouseDown", Start)
		h:SetScript("OnMouseUp", function()
			Stop()
			if not z.hover then CursorOff(z) end
		end)
		h:SetScript("OnDragStop", function()
			Stop()
			if not z.hover then CursorOff(z) end
		end)
		-- hidden under the mouse (its window shut, the cards came): the game's cursor back
		h:SetScript("OnHide", function()
			if z.hover == this.edge then z.hover = nil end
			if not z.active or z.active == this.edge then CursorOff(z) end
		end)
		z.handles[edge] = h
	end
	local a = CreateFrame("Frame", name, UIParent)
	a:SetFrameStrata("TOOLTIP")
	a:SetWidth(22)
	a:SetHeight(22)
	a.tex = C.Tex(a, "OVERLAY", C.ART .. "Resize")
	a.tex:SetAllPoints(a)
	a.tex:SetVertexColor(1, 0.92, 0.66)
	C.Vis(a, false)
	z.arrow = a
	function z.levels(level)
		for _, h in pairs(z.handles) do h:SetFrameLevel(level) end
	end
	function z.step()
		local can = spec.can()
		for _, h in pairs(z.handles) do C.Vis(h, can) end
		if not can and not z.active then z.hover = nil end
		if z.active then
			local x, y = UICursor()
			spec.move(z.active, x - z.x, y - z.y)
		end
		local edge = z.active or z.hover
		if edge and CursorOn(z, SIZE_CELLS[edge]) then
			C.Vis(a, false) -- the cursor is the arrow
		elseif edge then
			local x, y = UICursor()
			C.Place(a, "CENTER", UIParent, "BOTTOMLEFT", math.floor(x + 15), math.floor(y - 15))
			local cell = SIZE_CELLS[edge]
			if a.cell ~= cell then
				a.cell = cell
				local c = SIZE_TC[cell]
				a.tex:SetTexCoord(c[1], c[2], c[3], c[4])
			end
			C.Vis(a, true)
		else
			C.Vis(a, false)
			CursorOff(z)
		end
		return edge
	end
	return z
end

------------------------------------------------------------------------ an MMO panel
-- A panel in the timer's metal: brushed dark glass inside a thin round rail lit as the timer's
-- (one fine bright line on its lit side), the timer's diamonds on its corners. The skill bar's (asked
-- for) wears the hero's class: its emblem on the left end, its crest on the right, its rails, all from
-- the user's own picture (dev/art/cut_classes.py); the panel leaves C.PANEL_ROOM at each end for them,
-- so they never cover a slot. (Until 1.21.4 a painted dragon stood on each end, in a bronze look.)
local P_RAIL, P_CORNER = 8, 16
C.PANEL_ROOM = 79
-- Creed UI's gold, taken from the user's bar picture (dev/art/source/bar_reference.webp): borders and
-- rims (0.91, 0.70, 0.30), titles and tooltip heads (0.98, 0.85, 0.52), panel metal (0.95, 0.79, 0.44)
-- a class's emblem and crest (dev/art/cut_classes.py): 512x256 textures whose rails lie 110 of their
-- pixels apart; the emblem's middle is at 220 across its picture and the crest's at 292, on the line
-- between the rails. Drawn at 0.85 of the panel's scale (asked for: the bar fit the screen), their rings
-- as tall as the panel, their middles EMBLEM_IN in from its two ends
local EMBLEM_U = 76 / 110 * 0.85
local EMBLEM_W, EMBLEM_H = 512 * EMBLEM_U, 256 * EMBLEM_U
local EMBLEM_L, EMBLEM_R, EMBLEM_IN = 220, 292, 24
-- the class's rails (PanelRail<Class>T / B, 16 pixels tall round their line) at the same scale
local RAIL_TH = 16 * 76 / 110

-- every panel, so a new class recolors them all (1.24.2: the Level Up! button, the loot pop-up, the
-- pet bar, the summary and the talent window kept the class they were made in)
C.panels = {}

function C.Panel(frame, emblems)
	local p = { frame = frame, metal = {} }
	table.insert(C.panels, p)
	p.fill = C.Tex(frame, "BACKGROUND", C.ART .. "PanelFill")
	p.fill:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
	p.fill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
	local function Rail(art, a1, x1, y1, a2, x2, y2)
		local t = C.Tex(frame, "BORDER", C.ART .. art)
		t:SetPoint(a1, frame, a1, x1, y1)
		t:SetPoint(a2, frame, a2, x2, y2)
		table.insert(p.metal, t)
		return t
	end
	p.railT = Rail("PanelRailT", "TOPLEFT", P_CORNER, 0, "TOPRIGHT", -P_CORNER, 0)
	p.railT:SetHeight(P_RAIL)
	p.railB = Rail("PanelRailB", "BOTTOMLEFT", P_CORNER, 0, "BOTTOMRIGHT", -P_CORNER, 0)
	p.railB:SetHeight(P_RAIL)
	-- the end pieces (the end rails, corners and their diamonds), which the skill bar's emblem and
	-- crest stand over
	p.ends = {}
	local railL = Rail("PanelRailL", "TOPLEFT", 0, -P_CORNER, "BOTTOMLEFT", 0, P_CORNER)
	railL:SetWidth(P_RAIL)
	local railR = Rail("PanelRailR", "TOPRIGHT", 0, -P_CORNER, "BOTTOMRIGHT", 0, P_CORNER)
	railR:SetWidth(P_RAIL)
	table.insert(p.ends, railL)
	table.insert(p.ends, railR)
	for _, c in ipairs({ { "TOPLEFT", "TL", 1, -1 }, { "TOPRIGHT", "TR", -1, -1 }, { "BOTTOMLEFT", "BL", 1, 1 }, { "BOTTOMRIGHT", "BR", -1, 1 } }) do
		local t = C.Tex(frame, "BORDER", C.ART .. "PanelCorner" .. c[2])
		t:SetWidth(P_CORNER)
		t:SetHeight(P_CORNER)
		t:SetPoint(c[1], frame, c[1], 0, 0)
		table.insert(p.metal, t)
		table.insert(p.ends, t)
		-- the timer's diamond on the corner
		local d = C.Tex(frame, "ARTWORK", C.ART .. "Diamond")
		d:SetWidth(13)
		d:SetHeight(13)
		d:SetPoint("CENTER", frame, c[1], c[3] * 2, c[4] * 2)
		table.insert(p.metal, d)
		table.insert(p.ends, d)
	end
	if emblems then
		p.emblems = {}
		for i = 1, 2 do p.emblems[i] = C.Tex(frame, "OVERLAY", C.ART .. "Glow") end
		-- the end pieces step aside: the emblem and the crest stand over the ends
		for i = 1, table.getn(p.ends) do p.ends[i]:Hide() end
		-- a class's emblem on the left end, its crest on the right, its rails running whole from under
		-- the one to under the other (its line and glow as the picture paints them)
		p.PlaceEnds = function(emblem)
			for _, r in ipairs({ { p.railT, "T", "TOPLEFT", "TOPRIGHT", 1 }, { p.railB, "B", "BOTTOMLEFT", "BOTTOMRIGHT", -1 } }) do
				local t = r[1]
				t:ClearAllPoints()
				t:SetTexture(C.ART .. "PanelRail" .. emblem .. r[2])
				t:SetHeight(RAIL_TH)
				local y = r[5] * (RAIL_TH / 2 - P_RAIL / 2)
				t:SetPoint(r[3], frame, r[3], 0, y)
				t:SetPoint(r[4], frame, r[4], 0, y)
			end
			for i, side in ipairs({ "LEFT", "RIGHT" }) do
				local t = p.emblems[i]
				t:ClearAllPoints()
				t:SetTexture(C.ART .. "PanelEmblem" .. emblem .. ((i == 1) and "L" or "R"))
				t:SetWidth(EMBLEM_W)
				t:SetHeight(EMBLEM_H)
				local x = (i == 1) and (EMBLEM_IN - EMBLEM_L * EMBLEM_U) or (-EMBLEM_IN - EMBLEM_R * EMBLEM_U)
				t:SetPoint("TOPLEFT", frame, side, x, EMBLEM_H / 2)
			end
		end
		-- where the left end's art begins (the chat keeps clear of it): the emblem's round (about 70 of
		-- its pixels round its middle, at 220, 128), its wings and capes free to reach past
		p.LeftEnd = function()
			local t = p.emblems[1]
			if not (t:GetLeft() and t:GetTop()) then return nil end
			return t:GetLeft() + 150 * EMBLEM_U, t:GetTop() - 52 * EMBLEM_U
		end
	end
	return p
end

function C.PanelMetal(pal)
	local m = C.UI_THEME.metal
	return m[1], m[2], m[3]
end

function C.PanelTheme(p, pal)
	p.themed = true
	local tr = pal.trough
	local mr, mg, mb = C.PanelMetal(pal)
	for i = 1, table.getn(p.metal) do p.metal[i]:SetVertexColor(mr, mg, mb) end
	p.fill:SetVertexColor(0.5 + tr[1] * 0.3, 0.47 + tr[2] * 0.3, 0.44 + tr[3] * 0.3, 0.95)
	if p.emblems then
		-- the hero's class's emblem, crest and rails, in their own paint; the glass in the class's color
		local emblem = C.UI_THEME.emblem
		if p.emblem ~= emblem then
			p.emblem = emblem
			p.PlaceEnds(emblem)
		end
		p.railT:SetVertexColor(1, 1, 1)
		p.railB:SetVertexColor(1, 1, 1)
		-- the class's glass (1.21.8, asked for: its color, not black): Art/PanelGlass, its filigree and
		-- middle light, tinted with the theme's fill
		-- (should the game not show it, SetTexture answers nothing: the panel's own glass, darkened
		-- to the class's color, rather than a flat bright one)
		if p.glassSet == nil then
			p.glassSet = p.fill:SetTexture(C.ART .. "PanelGlass") and true or false
			if not p.glassSet then p.fill:SetTexture(C.ART .. "PanelFill") end
		end
		local f = C.UI_THEME.fill
		local k = p.glassSet and 1 or 0.45
		p.fill:SetVertexColor(f[1] * k, f[2] * k, f[3] * k, 0.97)
	end
end

function C.PanelStep(p, now)
end

------------------------------------------------------------------------ calling the game safely
-- pcall without stray arguments: the game's strict functions (the meter API) count a passed nil
-- as an argument and refuse the call.
function C.Call(fn, a, b)
	if type(fn) ~= "function" then return nil end
	local ok, r1, r2, r3
	if b ~= nil then
		ok, r1, r2, r3 = pcall(fn, a, b)
	elseif a ~= nil then
		ok, r1, r2, r3 = pcall(fn, a)
	else
		ok, r1, r2, r3 = pcall(fn)
	end
	if ok then return r1, r2, r3 end
	return nil
end

------------------------------------------------------------------------ icons by name
-- Spell icons the damage numbers have seen, by the spell's name: for meter lines that come by
-- name only (the game's older meter getters).
C.icons = {}
function C.LearnIcon(name, icon)
	if type(name) == "string" and name ~= "" and type(icon) == "string" and icon ~= "" then C.icons[name] = icon end
end

-- The meter's lines' own icons, by their sourceKey. Each hit's combat text names the line it counts
-- toward (meterSourceKey): a proc that floats in another spell's look (Shadow Weaving as Shadow Word:
-- Pain) has a line, and an icon, of its own. The meter's reads note them; a key not seen yet asks
-- the meter once (at most every 2 seconds), whether the meter window is up or not.
C.sourceIcons = {}
local sourceAsked = -10
function C.NoteSources(sources)
	if type(sources) ~= "table" then return end
	for key, src in pairs(sources) do
		local icon = type(src) == "table" and src.icon
		if type(icon) == "table" then
			if icon.status == "ready" and type(icon.path) == "string" and icon.path ~= "" then
				C.sourceIcons[key] = icon.path
			elseif icon.status == "missing" and not C.sourceIcons[key] then
				C.sourceIcons[key] = false -- the game has none: no asking again
			end
		end
	end
end
-- a read of the meter's lines, at most every 2 seconds
function C.RefreshSources()
	if GetTime() - sourceAsked < 2 or type(AZS_GetMeterSnapshot) ~= "function" then return end
	sourceAsked = GetTime()
	local context = C.Call(AZS_GetMeterContext)
	if type(context) == "table" and context.runId then
		local snap = C.Call(AZS_GetMeterSnapshot, { apiVersion = 1, runId = context.runId, metric = "damage", scope = "self",
			period = "run", groupBy = "actor_source", windowSeconds = 0 })
		if type(snap) == "table" then C.NoteSources(snap.sources) end
	end
end
function C.SourceIcon(key)
	if type(key) ~= "string" or key == "" then return nil end
	local icon = C.sourceIcons[key]
	if icon == nil then
		C.RefreshSources()
		icon = C.sourceIcons[key]
	end
	return icon or nil
end

------------------------------------------------------------------------ frames you can move
C.movers = {}
C.unlocked = false

local function SavePos(m)
	local f = m.frame
	local l, t = f:GetLeft(), f:GetTop()
	if not (l and t) then return end
	local s = f:GetScale()
	local root = C.Root()
	if type(root.pos) ~= "table" then root.pos = {} end
	root.pos[m.key] = { x = math.floor(l * s + 0.5), y = math.floor(t * s + 0.5) }
	C.ApplyPos(m)
end

C.SavePos = function(m) SavePos(m) end

function C.ApplyPos(m)
	local f = m.frame
	local root = C.Root()
	local p = type(root.pos) == "table" and root.pos[m.key]
	local s = f:GetScale()
	if type(p) == "table" and tonumber(p.x) and tonumber(p.y) then
		f:ClearAllPoints()
		f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", p.x / s, p.y / s)
	elseif m.default then
		m.default(f)
	end
end

-- frame: the movable root; key: where its place is saved; default(frame) anchors it fresh
function C.Movable(frame, key, label, default)
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	local m = { frame = frame, key = key, label = label, default = default }
	local box = CreateFrame("Frame", nil, frame)
	box:SetAllPoints(frame)
	box:SetBackdrop({ bgFile = C.FLAT, edgeFile = C.FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	box:SetBackdropColor(0.1, 0.2, 0.4, 0.35)
	box:SetBackdropBorderColor(0.91, 0.70, 0.30, 0.8)
	box:EnableMouse(true)
	box:RegisterForDrag("LeftButton")
	box:SetScript("OnDragStart", function() frame:StartMoving() end)
	box:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		SavePos(m)
	end)
	box.text = C.Text(box, C.FONT, 11, "OUTLINE", "CENTER", 260)
	box.text:SetPoint("CENTER", box, "CENTER", 0, 0)
	C.LText(box.text, label)
	box.text:SetTextColor(0.98, 0.85, 0.52)
	box:Hide()
	m.box = box
	table.insert(C.movers, m)
	C.ApplyPos(m)
	return m
end

-- A window you can drag straight away (the meter, luck): each handle starts moving it, letting go
-- saves its place. "Lock windows" in the hub stops it.
function C.Draggable(frame, mover)
	local d = { endedAt = 0 }
	function d.start()
		if CreedUIDB and CreedUIDB.lockWindows then return end
		d.moving = true
		if d.onStart then d.onStart() end
		frame:StartMoving()
	end
	function d.stop()
		if not d.moving then return end
		d.moving = false
		frame:StopMovingOrSizing()
		d.endedAt = GetTime()
		C.SavePos(mover)
	end
	function d.handle(f)
		f:RegisterForDrag("LeftButton")
		f:SetScript("OnDragStart", d.start)
		f:SetScript("OnDragStop", d.stop)
	end
	d.handle(frame)
	return d
end

function C.SetUnlocked(on)
	C.unlocked = on and true or false
	for i = 1, table.getn(C.movers) do
		local m = C.movers[i]
		if C.unlocked then
			m.box:SetFrameLevel(m.frame:GetFrameLevel() + 20)
			m.box:Show()
		else
			m.box:Hide()
		end
	end
	if C.timerLock then C.timerLock(not C.unlocked) end
end

C.resetStamp = 0 -- counts the resets (the chat watches it)
function C.ResetPositions()
	local root = C.Root()
	root.pos = {}
	for i = 1, table.getn(C.movers) do C.ApplyPos(C.movers[i]) end
	if C.timerReset then C.timerReset() end
	C.resetStamp = C.resetStamp + 1
end

------------------------------------------------------------------------ parts, for the hub
-- info: { key, name, note, get(), set(on), getScale(), setScale(v) } (the size pair is optional)
C.parts = {}
function C.RegisterPart(info)
	table.insert(C.parts, info)
end

------------------------------------------------------------------------ the options hub
local hub, RefreshHub

-- A settings window opened from the hub is a sibling of the hub under UIParent.
-- Give the whole child window a higher frame level: otherwise the hub's direct
-- FontStrings can draw over the child's title even while its child controls draw
-- above the hub. Keep the same DIALOG strata so it stays below true fullscreen
-- dialogs (such as the game's level-up cards).
function C.AboveHub(frame)
	if not frame then return end
	frame:SetFrameStrata("DIALOG")
	local level = UIParent:GetFrameLevel() + 10
	if hub then level = math.max(level, hub:GetFrameLevel() + 10) end
	frame:SetFrameLevel(level)
end

local function HubText(parent, size, r, g, b)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	C.SetFace(fs, C.FONT, size)
	fs:SetTextColor(r, g, b)
	fs:SetShadowColor(0, 0, 0, 1)
	fs:SetShadowOffset(1, -1)
	return fs
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

function C.Button(parent, width, height, label, onClick)
	local button = CreateFrame("Button", nil, parent)
	button:SetWidth(width)
	button:SetHeight(height)
	button:EnableMouse(true)
	button:SetBackdrop({ bgFile = C.FLAT, edgeFile = C.FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	button.text = HubText(button, 11, 1, 1, 1)
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

local function PartRow(parent, x, y, info)
	local row = CreateFrame("Button", nil, parent)
	row:SetWidth(200)
	row:SetHeight(20)
	row:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	row:EnableMouse(true)
	local edge = row:CreateTexture(nil, "BORDER")
	edge:SetTexture(C.FLAT)
	edge:SetVertexColor(0.38, 0.38, 0.42, 1)
	edge:SetWidth(14)
	edge:SetHeight(14)
	edge:SetPoint("LEFT", row, "LEFT", 0, 0)
	local box = row:CreateTexture(nil, "ARTWORK")
	box:SetTexture(C.FLAT)
	box:SetVertexColor(0.06, 0.06, 0.08, 1)
	box:SetPoint("TOPLEFT", edge, "TOPLEFT", 1, -1)
	box:SetPoint("BOTTOMRIGHT", edge, "BOTTOMRIGHT", -1, 1)
	row.mark = row:CreateTexture(nil, "OVERLAY")
	row.mark:SetTexture(C.FLAT)
	row.mark:SetVertexColor(0.91, 0.70, 0.30, 1)
	row.mark:SetPoint("TOPLEFT", edge, "TOPLEFT", 3, -3)
	row.mark:SetPoint("BOTTOMRIGHT", edge, "BOTTOMRIGHT", -3, 3)
	row.label = HubText(row, 12, 0.92, 0.92, 0.92)
	row.label:SetPoint("LEFT", edge, "RIGHT", 8, 0)
	C.LText(row.label, info.name)
	row:SetScript("OnEnter", function()
		row.label:SetTextColor(0.98, 0.85, 0.52)
		if GameTooltip and info.note then
			GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
			GameTooltip:AddLine(C.L(info.name), 0.98, 0.85, 0.52)
			GameTooltip:AddLine(C.L(info.note), 1, 1, 1, 1)
			C.ShowTip()
		end
	end)
	row:SetScript("OnLeave", function()
		row.label:SetTextColor(0.92, 0.92, 0.92)
		if GameTooltip then GameTooltip:Hide() end
	end)
	row:SetScript("OnClick", function()
		info.set(not info.get())
		RefreshHub()
	end)
	row.info = info
	if info.getScale then
		row.less = C.Button(parent, 22, 20, "-", function()
			info.setScale(C.Clamp(math.floor((info.getScale() - 0.05) * 20 + 0.5) / 20, 0.5, 1.8))
			RefreshHub()
		end)
		row.less:SetPoint("TOPLEFT", parent, "TOPLEFT", x + 206, y)
		row.size = HubText(parent, 11, 1, 1, 1)
		row.size:SetPoint("LEFT", row.less, "RIGHT", 0, 0)
		row.size:SetWidth(46)
		row.size:SetJustifyH("CENTER")
		row.more = C.Button(parent, 22, 20, "+", function()
			info.setScale(C.Clamp(math.floor((info.getScale() + 0.05) * 20 + 0.5) / 20, 0.5, 1.8))
			RefreshHub()
		end)
		row.more:SetPoint("LEFT", row.less, "RIGHT", 46, 0)
	end
	return row
end

RefreshHub = function()
	if not hub then return end
	for i = 1, table.getn(hub.rows) do
		local row = hub.rows[i]
		if row.info.get() then row.mark:Show() else row.mark:Hide() end
		if row.size then
			row.size:SetText(string.format("%d%%", math.floor((row.info.getScale() or 1) * 100 + 0.5)))
		end
	end
	hub.move.selected = C.unlocked
	C.LText(hub.move.text, C.unlocked and "Lock frames" or "Move frames")
	PaintButton(hub.move)
	hub.calm.selected = CreedUIDB and CreedUIDB.calm and true or false
	PaintButton(hub.calm)
	local locked = CreedUIDB and CreedUIDB.lockWindows and true or false
	hub.lock.selected = locked
	C.LText(hub.lock.text, locked and "Meter and luck windows: locked" or "Meter and luck windows: drag them to move")
	PaintButton(hub.lock)
	C.SetText(hub.lang.text, C.F("Language: {1}", C.LangName(C.lang)))
	hub.lang.selected = hub.langMenu:IsShown()
	PaintButton(hub.lang)
	for i = 1, table.getn(hub.langMenu.items) do
		local b = hub.langMenu.items[i]
		b.selected = b.code == C.lang
		PaintButton(b)
	end
end
C.RefreshHub = function() RefreshHub() end

-- The parts in two columns, the first half down the left, so the window stays well inside a
-- 768 px screen however many parts there are; the buttons under them run across its width.
local HUB_W, COL_W = 638, 312

local function BuildHub()
	local o = CreateFrame("Frame", "CreedUIOptions", UIParent)
	hub = o
	o:SetWidth(HUB_W)
	local perColumn = math.ceil(table.getn(C.parts) / 2)
	o:SetHeight(62 + perColumn * 26 + 14 + 60 + 24 + 12) -- the rows, then three lines of buttons
	o:SetPoint("CENTER", UIParent, "CENTER", 0, 10)
	o:SetFrameStrata("DIALOG")
	o:SetBackdrop({ bgFile = C.FLAT, edgeFile = C.FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	o:SetBackdropColor(0.05, 0.05, 0.07, 0.96)
	o:SetBackdropBorderColor(0, 0, 0, 1)
	o:EnableMouse(true)
	o:SetMovable(true)
	o:SetClampedToScreen(true)
	o:RegisterForDrag("LeftButton")
	o:SetScript("OnDragStart", function() o:StartMoving() end)
	o:SetScript("OnDragStop", function() o:StopMovingOrSizing() end)
	o:Hide()
	if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "CreedUIOptions") end

	local title = HubText(o, 18, 1, 0.82, 0.25)
	C.SetFace(title, C.TITLE_FONT, 20)
	title:SetPoint("TOPLEFT", o, "TOPLEFT", 14, -12)
	title:SetText("Creed UI")
	local version = HubText(o, 10, 0.55, 0.55, 0.6)
	version:SetPoint("LEFT", title, "RIGHT", 8, -2)
	version:SetText("v" .. C.VERSION)
	local close = C.Button(o, 22, 22, "x", function() o:Hide() end)
	close:SetPoint("TOPRIGHT", o, "TOPRIGHT", -10, -10)

	for col = 0, 1 do
		local head = HubText(o, 10, 0.6, 0.6, 0.65)
		head:SetPoint("TOPLEFT", o, "TOPLEFT", 14 + col * COL_W, -46)
		C.LText(head, "PART")
		local head2 = HubText(o, 10, 0.6, 0.6, 0.65)
		head2:SetPoint("TOPLEFT", o, "TOPLEFT", 244 + col * COL_W, -46)
		C.LText(head2, "SIZE")
	end

	o.rows = {}
	for i = 1, table.getn(C.parts) do
		local col = (i > perColumn) and 1 or 0
		local line = i - 1 - col * perColumn
		table.insert(o.rows, PartRow(o, 14 + col * COL_W, -62 - line * 26, C.parts[i]))
	end
	local y = -62 - perColumn * 26

	local divider = o:CreateTexture(nil, "ARTWORK")
	divider:SetTexture(C.FLAT)
	divider:SetVertexColor(1, 1, 1, 0.08)
	divider:SetWidth(HUB_W - 28)
	divider:SetHeight(1)
	divider:SetPoint("TOPLEFT", o, "TOPLEFT", 14, y - 4)
	y = y - 14

	local timerButton = C.Button(o, 148, 24, "", function()
		if C.timerOptions then C.timerOptions() end
	end)
	C.LText(timerButton.text, "Boss timer settings")
	timerButton:SetPoint("TOPLEFT", o, "TOPLEFT", 14, y)
	local numbersButton = C.Button(o, 148, 24, "", function()
		if C.numberOptions then C.numberOptions() end
	end)
	C.LText(numbersButton.text, "Damage number settings")
	numbersButton:SetPoint("TOPLEFT", o, "TOPLEFT", 168, y)
	o.move = C.Button(o, 148, 24, "Move frames", function()
		C.SetUnlocked(not C.unlocked)
		RefreshHub()
	end)
	o.move:SetPoint("TOPLEFT", o, "TOPLEFT", 14 + COL_W, y)
	local reset = C.Button(o, 148, 24, "", function()
		C.ResetPositions()
		C.Print(C.L("frames are back in their places."))
	end)
	C.LText(reset.text, "Reset positions")
	reset:SetPoint("TOPLEFT", o, "TOPLEFT", 168 + COL_W, y)
	y = y - 30
	o.calm = C.Button(o, 302, 24, "", function()
		local root = C.Root()
		root.calm = not root.calm
		RefreshHub()
	end)
	C.LText(o.calm.text, "Calm mode: no flowing light in the bars")
	o.calm:SetPoint("TOPLEFT", o, "TOPLEFT", 14, y)
	o.lock = C.Button(o, 302, 24, "Meter and luck windows: drag them to move", function()
		local root = C.Root()
		root.lockWindows = not root.lockWindows
		RefreshHub()
	end)
	o.lock:SetPoint("TOPLEFT", o, "TOPLEFT", 14 + COL_W, y)
	y = y - 30
	-- the language: a button that opens the list of them, each in its own words
	local platesButton = C.Button(o, 148, 24, "", function()
		if C.tinyPlatesOptions then C.tinyPlatesOptions(o) end
	end)
	C.LText(platesButton.text, "Tiny Plates settings")
	platesButton:SetPoint("TOPLEFT", o, "TOPLEFT", 14, y)
	local langButton = C.Button(o, 148, 24, "", function()
		if o.langMenu:IsShown() then o.langMenu:Hide() else o.langMenu:Show() end
		RefreshHub()
	end)
	C.LText(langButton.text, "Language")
	langButton:SetPoint("TOPLEFT", o, "TOPLEFT", 168, y)
	o.lang = langButton
	local menu = CreateFrame("Frame", "CreedUILanguageMenu", o)
	o.langMenu = menu
	local n = table.getn(C.LANG_LIST)
	local rows = math.ceil(n / 2) -- two columns
	menu:SetWidth(298)
	menu:SetHeight(rows * 22 + 8)
	menu:SetPoint("BOTTOM", o.lang, "TOP", 0, 2) -- upward: the options reach low on the screen
	menu:SetFrameStrata("FULLSCREEN_DIALOG")
	menu:SetBackdrop({ bgFile = C.FLAT, edgeFile = C.FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	menu:SetBackdropColor(0.05, 0.05, 0.07, 0.98)
	menu:SetBackdropBorderColor(0.91, 0.70, 0.30, 0.8)
	menu:EnableMouse(true)
	menu:Hide()
	menu.items = {}
	for i = 1, n do
		local info = C.LANG_LIST[i]
		local b = C.Button(menu, 142, 20, info.name, function()
			C.SetLanguage(this.code, true)
			menu:Hide()
			RefreshHub()
		end)
		b.code = info.code
		-- each name in its own letters, in the face that has them, whatever the language
		if info.face then C.SetFace(b.text, C.FONT, 11, nil, info.face) end
		local col, row = math.mod(i - 1, 2), math.floor((i - 1) / 2)
		b:SetPoint("TOPLEFT", menu, "TOPLEFT", 4 + col * 148, -4 - row * 22)
		menu.items[i] = b
	end
end

function C.ToggleHub()
	if not hub then BuildHub() end
	if hub:IsShown() then
		hub:Hide()
	else
		RefreshHub()
		hub:Show()
	end
end

------------------------------------------------------------------------ /creed
local function Slash(msg)
	msg = msg or ""
	local _, _, cmd, rest = string.find(msg, "^%s*(%S*)%s*(.-)%s*$")
	cmd = string.lower(cmd or "")
	if cmd == "" or cmd == "options" or cmd == "config" then
		C.ToggleHub()
	elseif cmd == "timer" or cmd == "sbt" then
		if C.timerSlash then C.timerSlash(rest) end
	elseif cmd == "numbers" or cmd == "sn" or cmd == "dmg" then
		if C.numberSlash then C.numberSlash(rest) end
	elseif cmd == "talents" then
		if C.ToggleTalents then C.ToggleTalents() end
	elseif cmd == "probe" then
		if C.Probe then C.Probe() end
		if C.ProbeAnchors then C.ProbeAnchors() end
		if C.ProbeRanks then C.ProbeRanks() end
	elseif cmd == "move" or cmd == "unlock" then
		C.SetUnlocked(true)
		C.Print(C.L("drag the frames, then type /creed lock."))
	elseif cmd == "lock" then
		C.SetUnlocked(false)
		C.Print(C.L("frames locked."))
	elseif cmd == "reset" then
		C.ResetPositions()
		C.Print(C.L("frames are back in their places."))
	elseif cmd == "language" or cmd == "lang" or cmd == "langue" or cmd == "sprache" or cmd == "idioma" then
		local want = string.lower(rest or "")
		if want == "auto" then want = C.DetectLanguage() end
		local codes = {}
		for i = 1, table.getn(C.LANG_LIST) do
			local l = C.LANG_LIST[i]
			table.insert(codes, l.code .. " (" .. l.name .. ")")
			if string.lower(l.name) == want then want = l.code end
		end
		if want ~= "" and C.SetLanguage(want, true) then
			C.Print(C.F("language: {1}", C.LangName(C.lang)))
		else
			C.Print(C.F("/creed language followed by one of: {1}, or auto", table.concat(codes, ", ")))
		end
	else
		local handled = false
		for i = 1, table.getn(C.parts) do
			local p = C.parts[i]
			if p.key == cmd then
				local r = string.lower(rest or "")
				if r == "on" then p.set(true) elseif r == "off" then p.set(false) else p.set(not p.get()) end
				C.Print(C.F(p.get() and "{1}: on." or "{1}: off.", C.L(p.name)))
				handled = true
			end
		end
		if not handled then
			local keys = {}
			for i = 1, table.getn(C.parts) do table.insert(keys, C.parts[i].key) end
			C.Print(C.F("/creed (options), move, lock, reset, language, timer ..., numbers ..., or a part on/off: {1}",
				table.concat(keys, ", ")))
		end
	end
	RefreshHub()
end

SLASH_CREEDUI1 = "/creed"
SLASH_CREEDUI2 = "/cui"
SlashCmdList["CREEDUI"] = Slash

------------------------------------------------------------------------ start up
local core = CreateFrame("Frame", "CreedUICore")
local started = false
core:RegisterEvent("ADDON_LOADED")
core:RegisterEvent("VARIABLES_LOADED")
core:RegisterEvent("PLAYER_ENTERING_WORLD")
core:RegisterEvent("PLAYER_LOGOUT")
core:SetScript("OnEvent", function()
	if event == "ADDON_LOADED" or event == "VARIABLES_LOADED" then
		if (event == "VARIABLES_LOADED" or arg1 == "CreedUI") and not started then
			started = true
			local root = C.Root()
			C.SetLanguage(root.lang or C.DetectLanguage())
			for i = 1, table.getn(C.inits) do
				local ok, err = pcall(C.inits[i])
				if not ok then C.Print(C.L("error while starting: ") .. tostring(err)) end
			end
			-- the two addons Creed UI grew out of would draw everything twice
			local old = {}
			if type(IsAddOnLoaded) == "function" then
				if IsAddOnLoaded("SmoothNumbers") then table.insert(old, "Smooth Numbers") end
				if IsAddOnLoaded("SmoothBossTimer") then table.insert(old, "Smooth Boss Timer") end
			end
			if table.getn(old) > 0 then
				C.Print(C.F("{1} are part of Creed UI now. Turn them off in Options -> AddOns; until then Creed UI leaves that part to them.",
					table.concat(old, C.L(" and "))))
			end
		end
	elseif event == "PLAYER_ENTERING_WORLD" then
		for i = 1, table.getn(C.worlds) do pcall(C.worlds[i]) end
		pcall(C.KeepOverCards, true)
	elseif event == "PLAYER_LOGOUT" then
		for i = 1, table.getn(C.logouts) do pcall(C.logouts[i]) end
	end
end)

------------------------------------------------------------------------ over the game's cards
-- While level-up or jewelry cards are up, the game veils the screen and the interface goes dark
-- under it, all but the frames it keeps on top (AZS_SetOnTopOfScreens, the game's 0.126 on):
-- those stay lit and take their own clicks. Left under, a frame can even come out half lit, as
-- the game draws some of its art over the veil where a frame on top uses the same. A frame clear
-- of the cards' part of the screen goes on top; one moved over it stays under, so it never
-- covers a card or takes its click. The game reads the list as the cards open, so it is kept
-- current once a second.
local CARDS = { left = 0.22, right = 0.78, top = 0.80 } -- shares of the screen, from the bottom left
C.overCards = {}

function C.OverCards(frame)
	if not frame then return end
	for i = 1, table.getn(C.overCards) do
		if C.overCards[i].frame == frame then return end
	end
	table.insert(C.overCards, { frame = frame })
end

-- clear of the cards (less than a quarter of it over their part)? nil while it has no place yet
local function ClearOfCards(f)
	if type(GetScreenWidth) ~= "function" or type(GetScreenHeight) ~= "function" then return nil end
	local l, b, w, h = f:GetLeft(), f:GetBottom(), f:GetWidth(), f:GetHeight()
	local sw, sh = GetScreenWidth(), GetScreenHeight()
	if not (l and b and w and h and sw and sh) or sw <= 0 or sh <= 0 or w <= 0 or h <= 0 then return nil end
	local k = (f:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
	l, b, w, h = l * k / sw, b * k / sh, w * k / sw, h * k / sh
	local ox = math.min(l + w, CARDS.right) - math.max(l, CARDS.left)
	local oy = math.min(b + h, CARDS.top) - math.max(b, 0)
	if ox <= 0 or oy <= 0 then return true end
	return ox * oy < 0.25 * w * h
end

function C.KeepOverCards(force)
	if type(AZS_SetOnTopOfScreens) ~= "function" then return end
	for i = 1, table.getn(C.overCards) do
		local o = C.overCards[i]
		local clear = ClearOfCards(o.frame)
		if o.frame.creedDocked then clear = true end -- riding on a frame that's on top
		if clear == nil then clear = o.on ~= false end
		if force or o.on ~= clear then
			o.on = clear
			pcall(AZS_SetOnTopOfScreens, o.frame, clear)
		end
	end
	if force then pcall(AZS_SetOnTopOfScreens, "GameTooltip", true) end
end

-- While the cards are up, the pieces that would lie over them (the skill bar, the meter, the luck,
-- the party and boss bars) fade away: C.cardsFade runs 0 to 1, and back as the cards close.
C.cardsUp, C.cardsFade = false, 0

do
	local overClock = 0
	local watch = CreateFrame("Frame", "CreedUIOverCards")
	watch:SetScript("OnUpdate", function()
		local dt = arg1 or 0
		if dt > 0.1 then dt = 0.1 end
		local up = false
		if type(AZS_GetPhase) == "function" then
			local ok, phase = pcall(AZS_GetPhase)
			up = ok and phase == "choosing"
		end
		C.cardsUp = up
		C.cardsFade = C.Toward(C.cardsFade, up and 1 or 0, up and 10 or 6, dt)
		overClock = overClock - dt
		if overClock > 0 then return end
		overClock = 1
		pcall(C.KeepOverCards, false)
	end)
end

------------------------------------------------------------------------ the old game menu
-- On the game's own Paused screen, Escape resumes the run, but the same key also reaches the
-- stock 1.12 game menu, which then pops up over the game. That menu is put away again when it
-- opens while the run is paused (or just was). Out of a run it opens as usual.
local menu = { pausedAt = -10, hideNext = false, done = false }

local function Paused()
	if type(AZS_GetPhase) ~= "function" then return false end
	local ok, phase = pcall(AZS_GetPhase)
	return ok and phase == "paused"
end

local function GuardGameMenu()
	if menu.done or type(GameMenuFrame) ~= "table" or type(GameMenuFrame.GetScript) ~= "function" then return end
	menu.done = true
	local old = GameMenuFrame:GetScript("OnShow")
	GameMenuFrame:SetScript("OnShow", function()
		if old then old() end
		if Paused() or GetTime() - menu.pausedAt < 0.6 then
			GameMenuFrame:SetAlpha(0) -- unseen until it's closed, next frame
			menu.hideNext = true
		end
	end)
	local watch = CreateFrame("Frame", "CreedUIMenuGuard")
	watch:SetScript("OnUpdate", function()
		if Paused() then menu.pausedAt = GetTime() end
		if menu.hideNext then
			menu.hideNext = false
			if GameMenuFrame:IsShown() then
				if type(HideUIPanel) == "function" then
					pcall(HideUIPanel, GameMenuFrame)
				end
				if GameMenuFrame:IsShown() then GameMenuFrame:Hide() end
			end
			GameMenuFrame:SetAlpha(1)
		end
	end)
end
C.OnInit(function() pcall(GuardGameMenu) end)
-- the theme is the hero's class (1.21.4, asked for, in place of a choice in the options): put on as the
-- addon starts and each time the hero enters the world, and as each run's hero class comes in (1.21.7)
C.OnInit(function() C.SetTheme("class") end)
-- the music button's settings, gone with it (1.24.0)
C.OnInit(function() if CreedUIDB then CreedUIDB.music = nil end end)
C.OnWorld(function() C.SetTheme("class") end)
do
	local watch = CreateFrame("Frame", "CreedUIClassWatch", UIParent)
	local stamp = C.palStamp
	watch:SetScript("OnUpdate", function()
		pcall(C.WatchRunClass, GetTime())
		-- a new class (or zone palette): every panel already dressed takes its colors
		if stamp ~= C.palStamp then
			stamp = C.palStamp
			for i = 1, table.getn(C.panels) do
				if C.panels[i].themed then pcall(C.PanelTheme, C.panels[i], C.Pal()) end
			end
		end
	end)
end

-- is the addon this part grew out of still running? then that part stays off
function C.OldAddon(name)
	return type(IsAddOnLoaded) == "function" and IsAddOnLoaded(name) and true or false
end
