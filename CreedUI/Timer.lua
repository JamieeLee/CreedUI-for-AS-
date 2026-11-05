-- Creed UI: the boss timer (WoW 1.12 client, Lua 5.0).
-- A themed, animated replacement for the game's run clock and "next boss" line.
-- While it's enabled it hides the game's own clock (the "clock" HUD part) and puts it back
-- when it's turned off or the game closes. It also owns the map's theme, which it shares
-- with the rest of Creed UI.

local CUI = CreedUI
local L, F = CUI.L, CUI.F -- the words in the language picked (Core)
local VERSION = CUI.VERSION
local ART = CUI.ART
local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local FONT = "Fonts\\FRIZQT__.TTF"
local TITLE_FONT = "Fonts\\MORPHEUS.TTF"

local BAR_H = 12          -- the trough the fill runs in
local RIM = 22            -- the rim art's height, and each end cap's width
local CAP = 11            -- how far each end cap reaches past the trough's ends
local MARK = 22           -- a boss's socket
local MARK_FINAL = 32     -- the final boss's socket
local PAD = 72            -- room left and right of the bar inside the main frame
local ROOT_H = 74
local BAR_TOP = 30        -- from the frame's top to the trough's top
local MAX_TICKS = 40
local MAX_PARTS = 36
local FLOW_SIZE = 1024    -- pixels the flow art spans (stored 512 wide: the game's limit)
local FLOW_PERIOD = 0.125 -- its pattern repeats every 128 texels
local DATA_EVERY = 0.1    -- how often the schedule and the bosses are read
local TWO_PI = 6.2831853

local SHOWN_PHASES = { playing = true, choosing = true, paused = true, dead = true, victory = true }
local STOPPED_PHASES = { choosing = true, paused = true, dead = true, victory = true }

local DEFAULTS = {
	enabled = true,
	locked = true,
	scale = 1,
	width = 440,
	theme = "auto",
	title = true,
	callout = true,
	ticks = true,
	particles = true,
	flow = true,
	x = 0,
	y = -12,
}

------------------------------------------------------------------------ themes
-- Colors are { r, g, b }. fillA -> fillM -> fillB run along the fill, glow lights its head and
-- flowing light, gem colors the boss markers, rim tints the metal, mc colors the particles.
local THEMES = {
	default = {
		name = "Azeroth", sub = "",
		title = { 1.00, 0.84, 0.40 }, rim = { 0.95, 0.80, 0.46 },
		fillA = { 0.08, 0.18, 0.46 }, fillM = { 0.20, 0.44, 0.88 }, fillB = { 0.56, 0.80, 1.00 },
		glow = { 0.72, 0.88, 1.00 }, gem = { 1.00, 0.80, 0.30 }, trough = { 0.03, 0.04, 0.08 },
		motif = "motes", mc = { 0.75, 0.88, 1.00 },
	},
	elwynn = {
		name = "Elwynn Forest", sub = "The Defias Uprising",
		title = { 1.00, 0.85, 0.42 }, rim = { 1.00, 0.80, 0.42 },
		fillA = { 0.10, 0.34, 0.09 }, fillM = { 0.36, 0.64, 0.15 }, fillB = { 0.90, 0.88, 0.34 },
		glow = { 1.00, 0.94, 0.60 }, gem = { 0.95, 0.27, 0.20 }, trough = { 0.04, 0.07, 0.03 },
		motif = "fireflies", mc = { 1.00, 0.88, 0.45 },
	},
	duskwood = {
		name = "Duskwood", sub = "Night of the Nightbane",
		title = { 0.82, 0.82, 1.00 }, rim = { 0.76, 0.78, 0.90 },
		fillA = { 0.12, 0.08, 0.30 }, fillM = { 0.28, 0.24, 0.66 }, fillB = { 0.62, 0.64, 1.00 },
		glow = { 0.80, 0.85, 1.00 }, gem = { 1.00, 0.70, 0.24 }, trough = { 0.04, 0.03, 0.08 },
		motif = "mist", mc = { 0.70, 0.68, 1.00 },
	},
	wsg = {
		name = "Warsong Gulch", sub = "The Burning Legion",
		title = { 0.66, 1.00, 0.32 }, rim = { 0.58, 0.68, 0.36 },
		fillA = { 0.05, 0.20, 0.02 }, fillM = { 0.24, 0.62, 0.06 }, fillB = { 0.72, 1.00, 0.18 },
		glow = { 0.80, 1.00, 0.40 }, gem = { 0.78, 0.34, 1.00 }, trough = { 0.02, 0.05, 0.01 },
		motif = "fel", mc = { 0.55, 1.00, 0.25 },
	},
	ungoro = {
		name = "Un'Goro Crater", sub = "The Primal Hunt",
		title = { 0.58, 1.00, 0.72 }, rim = { 0.88, 0.80, 0.62 },
		fillA = { 0.02, 0.22, 0.18 }, fillM = { 0.08, 0.55, 0.38 }, fillB = { 0.52, 0.98, 0.60 },
		glow = { 0.76, 1.00, 0.76 }, gem = { 1.00, 0.54, 0.16 }, trough = { 0.01, 0.06, 0.04 },
		motif = "spores", mc = { 0.82, 1.00, 0.45 },
	},
	ab = {
		name = "Arathi Basin", sub = "The Highlands Rise",
		title = { 0.84, 0.90, 1.00 }, rim = { 0.78, 0.78, 0.76 },
		fillA = { 0.08, 0.14, 0.36 }, fillM = { 0.20, 0.38, 0.72 }, fillB = { 0.58, 0.78, 1.00 },
		glow = { 0.84, 0.92, 1.00 }, gem = { 1.00, 0.80, 0.30 }, trough = { 0.02, 0.03, 0.08 },
		motif = "wind", mc = { 1.00, 0.90, 0.66 },
	},
	feralas = {
		name = "Feralas", sub = "The Gates of Dire Maul",
		title = { 0.92, 0.70, 1.00 }, rim = { 0.84, 0.76, 0.56 },
		fillA = { 0.03, 0.16, 0.26 }, fillM = { 0.30, 0.32, 0.70 }, fillB = { 0.94, 0.50, 0.96 },
		glow = { 1.00, 0.76, 1.00 }, gem = { 0.38, 1.00, 0.54 }, trough = { 0.02, 0.04, 0.06 },
		motif = "leaves", mc = { 0.42, 0.86, 0.46 },
	},
	arena = {
		name = "Gurubashi Arena", sub = "The Blood God Wakes",
		title = { 1.00, 0.54, 0.50 }, rim = { 0.94, 0.72, 0.34 },
		fillA = { 0.26, 0.01, 0.06 }, fillM = { 0.62, 0.04, 0.16 }, fillB = { 1.00, 0.26, 0.38 },
		glow = { 1.00, 0.56, 0.60 }, gem = { 0.38, 1.00, 0.58 }, trough = { 0.07, 0.01, 0.02 },
		motif = "blood", mc = { 1.00, 0.22, 0.26 },
	},
	sm = {
		name = "Scarlet Monastery", sub = "The Crusade's Last Stand",
		title = { 1.00, 0.88, 0.62 }, rim = { 0.98, 0.92, 0.78 },
		fillA = { 0.34, 0.02, 0.02 }, fillM = { 0.78, 0.10, 0.08 }, fillB = { 1.00, 0.48, 0.24 },
		glow = { 1.00, 0.90, 0.62 }, gem = { 1.00, 0.80, 0.30 }, trough = { 0.06, 0.01, 0.01 },
		motif = "holy", mc = { 1.00, 0.92, 0.66 },
	},
	av = {
		name = "Alterac Valley", sub = "The Frozen Wilds",
		title = { 0.84, 0.95, 1.00 }, rim = { 0.82, 0.90, 0.98 },
		fillA = { 0.05, 0.16, 0.36 }, fillM = { 0.22, 0.52, 0.86 }, fillB = { 0.82, 0.96, 1.00 },
		glow = { 0.88, 0.97, 1.00 }, gem = { 0.58, 0.86, 1.00 }, trough = { 0.02, 0.04, 0.08 },
		motif = "snow", mc = { 0.95, 0.98, 1.00 },
	},
	brm = {
		name = "Blackrock Mountain", sub = "The Lord of Blackrock",
		title = { 1.00, 0.68, 0.32 }, rim = { 0.64, 0.56, 0.50 },
		fillA = { 0.26, 0.03, 0.00 }, fillM = { 0.72, 0.18, 0.02 }, fillB = { 1.00, 0.60, 0.12 },
		glow = { 1.00, 0.78, 0.36 }, gem = { 0.82, 0.44, 1.00 }, trough = { 0.06, 0.02, 0.00 },
		motif = "embers", mc = { 1.00, 0.56, 0.16 },
	},
	scholomance = {
		name = "Scholomance", sub = "The Great Ossuary",
		title = { 0.86, 0.96, 0.78 }, rim = { 0.80, 0.82, 0.74 },
		fillA = { 0.06, 0.12, 0.08 }, fillM = { 0.26, 0.48, 0.30 }, fillB = { 0.84, 0.94, 0.70 },
		glow = { 0.82, 1.00, 0.78 }, gem = { 0.70, 1.00, 0.46 }, trough = { 0.02, 0.04, 0.03 },
		motif = "mist", mc = { 0.66, 0.96, 0.62 },
	},
	aq = {
		name = "Gates of Ahn'Qiraj", sub = "The Old God Stirs",
		title = { 1.00, 0.88, 0.56 }, rim = { 0.92, 0.80, 0.56 },
		fillA = { 0.30, 0.18, 0.05 }, fillM = { 0.70, 0.48, 0.16 }, fillB = { 1.00, 0.88, 0.50 },
		glow = { 1.00, 0.93, 0.68 }, gem = { 0.76, 0.36, 1.00 }, trough = { 0.05, 0.03, 0.01 },
		motif = "sand", mc = { 1.00, 0.85, 0.56 },
	},
	naxx = {
		name = "Naxxramas", sub = "The Scourge Invasion",
		title = { 0.64, 1.00, 0.78 }, rim = { 0.82, 0.86, 0.78 },
		fillA = { 0.12, 0.04, 0.20 }, fillM = { 0.14, 0.38, 0.34 }, fillB = { 0.50, 1.00, 0.58 },
		glow = { 0.72, 1.00, 0.82 }, gem = { 0.58, 0.84, 1.00 }, trough = { 0.03, 0.02, 0.05 },
		motif = "necrotic", mc = { 0.52, 1.00, 0.62 },
	},
}
local ZONE_ORDER = { "elwynn", "duskwood", "wsg", "ungoro", "ab", "feralas", "arena", "sm", "av", "brm", "scholomance", "aq", "naxx" }
local PAL_KEYS = { "title", "rim", "fillA", "fillM", "fillB", "glow", "gem", "trough", "mc" }

-- Each zone's bosses, used when the game hasn't sent the schedule (right after a /reload).
-- { run length, time, name, time, name, ... } in seconds.
local FALLBACK = {
	elwynn = { 960, 180, "Hogger", 360, "Mother Fang", 540, "Rhahk'Zor", 720, "Mr. Smite", 960, "Edwin VanCleef" },
	duskwood = { 960, 180, "Naraxis", 360, "Mor'Ladim", 540, "Stitches", 720, "Lupos", 960, "Morbent Fel" },
	wsg = { 960, 180, "Doomguard Commander", 360, "Mannoroth's Herald", 540, "Varimathras", 720, "Lord Hel'nurath", 960, "Lord Kazzak" },
	ungoro = { 960, 180, "Ravasaur Matriarch", 360, "Uhk'loc", 540, "Lar'korwi", 720, "Tyrant Devilsaur", 960, "King Mosh" },
	ab = { 1080, 240, "Kovork", 420, "Nimar the Slayer", 660, "Marez Cowl", 840, "Lord Falconcrest", 1080, "Lord Aliden Perenolde" },
	feralas = { 1080, 240, "Zevrim Thornhoof", 420, "Alzzin the Wildshaper", 660, "Tendris Warpwood", 840, "Immol'thar", 1080, "King Gordok" },
	arena = { 1080, 240, "High Priestess Jeklik", 420, "High Priest Venoxis", 660, "Bloodlord Mandokir", 840, "Jin'do the Hexxer", 1080, "Hakkar the Soulflayer" },
	sm = { 1080, 240, "Houndmaster Loksey", 420, "Arcanist Doan", 660, "Herod", 840, "Scarlet Commander Mograine", 1080, "High Inquisitor Whitemane" },
	av = { 1200, 240, "Korrak the Bloodrager", 480, "Ivus the Forest Lord", 720, "Lokholar the Ice Lord", 960, "Glacius the Frozen Titan", 1200, "Azuregos" },
	brm = { 1200, 240, "General Angerforge", 480, "Warchief Rend Blackhand", 720, "Emperor Dagran Thaurissan", 960, "Majordomo Executus", 1200, "Nefarian" },
	scholomance = { 1200, 240, "Kirtonos the Herald", 480, "Ras Frostwhisper", 720, "Doctor Theolen Krastinov", 960, "Lord Alexei Barov", 1200, "Darkmaster Gandling" },
	aq = { 1200, 240, "Kurinnaxx", 480, "General Rajaxx", 720, "Princess Huhuran", 960, "Ossirian the Unscarred", 1200, "C'Thun" },
	naxx = { 1200, 240, "Anub'Rekhan", 480, "Noth the Plaguebringer", 720, "Patchwerk", 960, "Sapphiron", 1200, "Kel'Thuzad" },
}

-- Particles per zone. where: fill (along the fill), head (near its leading edge), bar (along
-- the whole bar), above (falling from above it). Speeds in UI units per second, +y is up.
local MOTIFS = {
	motes = { tex = "Mote", blend = "ADD", rate = 2.2, where = "fill", y0 = -4, y1 = 5, vx0 = -3, vx1 = 3,
		vy0 = 4, vy1 = 10, wob = 4, wobf = 0.9, life0 = 2.0, life1 = 3.2, w0 = 4, w1 = 7, a = 0.8 },
	fireflies = { tex = "Mote", blend = "ADD", rate = 3.0, where = "fill", y0 = -4, y1 = 6, vx0 = -4, vx1 = 4,
		vy0 = 5, vy1 = 11, wob = 5, wobf = 1.2, life0 = 2.2, life1 = 3.6, w0 = 5, w1 = 9, a = 0.95, twinkle = 5 },
	mist = { tex = "Glow", blend = "ADD", rate = 1.7, where = "fill", y0 = -3, y1 = 3, vx0 = 5, vx1 = 11,
		vy0 = 0, vy1 = 3, wob = 2, wobf = 0.4, life0 = 3.5, life1 = 5.5, w0 = 28, w1 = 46, aspect = 0.42,
		a = 0.26, grow = 0.35 },
	fel = { tex = "Spark", blend = "ADD", rate = 7.5, where = "head", spread = 40, y0 = -5, y1 = 4, vx0 = -5, vx1 = 5,
		vy0 = 18, vy1 = 36, wob = 2, wobf = 3, life0 = 0.8, life1 = 1.5, w0 = 3, w1 = 5, aspect = 2.6, a = 0.95,
		flicker = 14, grow = -0.4 },
	spores = { tex = "Mote", blend = "ADD", rate = 2.6, where = "fill", y0 = -5, y1 = 5, vx0 = -3, vx1 = 3,
		vy0 = 3, vy1 = 9, wob = 7, wobf = 0.7, life0 = 3.0, life1 = 4.8, w0 = 4, w1 = 8, a = 0.85,
		alt = { chance = 0.2, tex = "Twinkle", w0 = 5, w1 = 8, mc = { 1.00, 0.62, 0.22 } } },
	wind = { tex = "Spark", blend = "ADD", rate = 4.5, where = "bar", y0 = -12, y1 = 12, vx0 = 34, vx1 = 60,
		vy0 = -2, vy1 = 2, wob = 2, wobf = 1.5, life0 = 1.0, life1 = 1.8, w0 = 9, w1 = 16, aspect = 0.22,
		a = 0.6, rot = 1.5708 },
	leaves = { tex = "Leaf", blend = "BLEND", rate = 1.3, where = "above", y0 = 13, y1 = 20, vx0 = 5, vx1 = 13,
		vy0 = -14, vy1 = -9, wob = 6, wobf = 0.5, life0 = 3.0, life1 = 3.8, w0 = 8, w1 = 11, a = 0.9,
		spin = 1.6 },
	blood = { tex = "Mote", blend = "ADD", rate = 4.5, where = "fill", y0 = -4, y1 = 4, vx0 = -3, vx1 = 3,
		vy0 = 10, vy1 = 22, wob = 2, wobf = 1.5, life0 = 1.1, life1 = 1.8, w0 = 3, w1 = 6, a = 0.95, grow = -0.3 },
	holy = { tex = "Twinkle", blend = "ADD", rate = 2.6, where = "fill", y0 = -4, y1 = 5, vx0 = -2, vx1 = 2,
		vy0 = 5, vy1 = 11, wob = 3, wobf = 0.8, life0 = 1.4, life1 = 2.4, w0 = 7, w1 = 11, a = 0.95, twinkle = 7 },
	snow = { tex = "Flake", blend = "BLEND", rate = 4.0, where = "above", y0 = 15, y1 = 22, vx0 = -4, vx1 = 4,
		vy0 = -24, vy1 = -13, wob = 5, wobf = 0.6, life0 = 2.2, life1 = 3.0, w0 = 5, w1 = 9, a = 0.9, spin = 1.2 },
	embers = { tex = "Spark", blend = "ADD", rate = 6.0, where = "head", spread = 52, y0 = -5, y1 = 4, vx0 = -8, vx1 = 8,
		vy0 = 16, vy1 = 34, wob = 3, wobf = 2.5, life0 = 0.9, life1 = 1.7, w0 = 3, w1 = 4, aspect = 2.4, a = 0.95,
		flicker = 12, grow = -0.4 },
	sand = { tex = "Mote", blend = "ADD", rate = 9.0, where = "bar", y0 = -11, y1 = 11, vx0 = 45, vx1 = 80,
		vy0 = -3, vy1 = 3, wob = 2, wobf = 1.2, life0 = 0.9, life1 = 1.6, w0 = 2, w1 = 3.5, a = 0.8,
		alt = { chance = 0.04, tex = "Twinkle", w0 = 6, w1 = 9, mc = { 0.78, 0.40, 1.00 } } },
	necrotic = { tex = "Glow", blend = "ADD", rate = 3.0, where = "fill", y0 = -4, y1 = 4, vx0 = -3, vx1 = 3,
		vy0 = 5, vy1 = 12, wob = 4, wobf = 0.7, life0 = 1.8, life1 = 2.8, w0 = 9, w1 = 15, a = 0.5, grow = 0.4,
		alt = { chance = 0.3, tex = "Twinkle", w0 = 5, w1 = 8, mc = { 0.70, 0.90, 1.00 } } },
}

local HEROIC_COLORS = {
	{ 0.45, 0.70, 1.00 }, { 0.55, 0.72, 0.92 }, { 0.95, 0.62, 0.36 }, { 1.00, 0.34, 0.26 }, { 0.95, 0.16, 0.16 },
}
local ROMAN = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X" }
local AFFIX_NAMES = { bolstering = "Bolstering", sanguine = "Sanguine", explosive = "Explosive" }

------------------------------------------------------------------------ state
local db
local W = {}       -- widgets
local EMPTY = {}
local S = {
	alpha = 0, slide = 0, width = 440, len = 960, t = 0, lastRaw = nil,
	fill = 0, fillV = 0, fillTarget = 0, flow1 = 0, flow2 = 0, shineStart = -100, shineNext = 0,
	titleA = 0, titleW = nil, titleWant = nil, titleShown = nil, totalA = 0, totalShown = nil,
	pal = {}, theme = nil, themeKey = nil, palMoving = true,
	marks = {}, nextIndex = nil, quietUntil = 0,
	textX = nil, textV = 0, caretX = nil, caretV = 0, callScale = 1, callScaleV = 0,
	callAlpha = 0, callName = nil, callBuilt = nil, callSecond = nil,
	clockText = nil, totalText = nil, titleKey = nil, titleNext = 0, tickKey = nil,
	parts = {}, partAcc = 0,
	dataClock = 0, clockCheck = 0, zoneStamp = nil, lastPhase = nil,
	deadline = nil, cycle = nil, endLeft = nil, endless = false,
	tookClock = false, errors = 0, errorAt = -100, broken = false, dragging = false,
	hover = nil, hoverNext = 0, saveNext = 0,
}
local R = { ok = false, sched = {}, n = 0, phase = nil, rawT = 0, len = 960 } -- what the bar shows
local P = { on = false }    -- the preview's simulated run
local optionsOpen = false

------------------------------------------------------------------------ helpers
local function Clamp(v, lo, hi)
	if v < lo then return lo elseif v > hi then return hi end
	return v
end

local function Smooth(p)
	if p <= 0 then return 0 elseif p >= 1 then return 1 end
	return p * p * (3 - 2 * p)
end

local function Toward(cur, target, rate, dt)
	return cur + (target - cur) * (1 - math.exp(-rate * dt))
end

-- a critically damped spring: no overshoot, no stepping
local function Spring(pos, vel, target, omega, dt)
	local x = pos - target
	local e = math.exp(-omega * dt)
	local c = vel + omega * x
	return target + (x + c * dt) * e, (vel - c * omega * dt) * e
end

local function Hex(c, k)
	k = k or 1
	return string.format("|cff%02x%02x%02x", math.floor(Clamp(c[1] * k, 0, 1) * 255),
		math.floor(Clamp(c[2] * k, 0, 1) * 255), math.floor(Clamp(c[3] * k, 0, 1) * 255))
end

local function Clock(s)
	if s < 0 then s = 0 end
	s = math.floor(s)
	local h = math.floor(s / 3600)
	local m = math.floor(math.mod(s, 3600) / 60)
	local sec = math.mod(s, 60)
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, sec)
	end
	return string.format("%d:%02d", m, sec)
end

local function Print(msg)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cffffcc55Creed UI|r " .. L("timer") .. ": " .. msg)
	end
end

local function Call(fn)
	if type(fn) ~= "function" then return nil end
	local ok, result = pcall(fn)
	if ok then return result end
	return nil
end

local NAME_TO_ZONE, ZNAME_TO_ZONE = {}, {}
for key, list in pairs(FALLBACK) do
	for i = 3, table.getn(list), 2 do
		NAME_TO_ZONE[string.lower(list[i])] = key
	end
	ZNAME_TO_ZONE[string.lower(THEMES[key].name)] = key
end

------------------------------------------------------------------------ the game's clock HUD
local function TakeClock()
	if type(AZS_SetHudShown) ~= "function" or type(AZS_IsHudShown) ~= "function" then return end
	local ok, shown = pcall(AZS_IsHudShown, "clock")
	if ok and shown then
		db.clockWasShown = true -- only remember what we changed
		pcall(AZS_SetHudShown, "clock", false)
	end
	S.tookClock = true
end

local function ReleaseClock()
	if db and db.clockWasShown and type(AZS_SetHudShown) == "function" then
		pcall(AZS_SetHudShown, "clock", true)
		db.clockWasShown = nil
	end
	S.tookClock = false
end

------------------------------------------------------------------------ widgets
local function Tex(parent, layer, file, blend)
	local t = parent:CreateTexture(nil, layer)
	t:SetTexture(file)
	if blend then
		t:SetBlendMode(blend)
	end
	return t
end

local function Text(parent, font, size, flags, justify, width)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	CUI.SetFace(fs, font, size, flags)
	fs:SetJustifyH(justify or "CENTER")
	if width then
		fs:SetWidth(width)
	end
	fs:SetShadowColor(0, 0, 0, 1)
	fs:SetShadowOffset(1, -1)
	return fs
end

local function SetSize(region, w, h)
	region:SetWidth(w)
	region:SetHeight(h)
end

-- Writers that skip a value the region already has: a bar at rest costs the client nothing.
-- A region drawn through these must not be shown, hidden, sized or tinted any other way.
local function Size(r, w, h)
	if r.mw ~= w or r.mh ~= h then
		r.mw, r.mh = w, h
		r:SetWidth(w)
		r:SetHeight(h)
	end
end

local function Color(r, red, green, blue, a)
	if r.mr ~= red or r.mg ~= green or r.mb ~= blue or r.ma ~= a then
		r.mr, r.mg, r.mb, r.ma = red, green, blue, a
		r:SetVertexColor(red, green, blue, a)
	end
end

local function Vis(r, on)
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

local function Alpha(r, a)
	if r.mal ~= a then
		r.mal = a
		r:SetAlpha(a)
	end
end

-- an exponential approach that lands exactly on its target
local function Ease(cur, target, k)
	local v = cur + (target - cur) * k
	if v - target < 0.0015 and target - v < 0.0015 then return target end
	return v
end

local SavePosition, ShowMarkerTip, ShowTitleTip

local function BuildBar()
	local root = CreateFrame("Frame", "CreedUITimerFrame", UIParent)
	W.root = root
	root:SetFrameStrata("MEDIUM")
	SetSize(root, 440 + PAD * 2, ROOT_H)
	root:SetMovable(true)
	root:SetClampedToScreen(true)
	root:RegisterForDrag("LeftButton")
	root:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	root:SetBackdropColor(0, 0, 0, 0)
	root:SetBackdropBorderColor(1, 1, 1, 0)
	root:SetScript("OnDragStart", function()
		if db and not db.locked then
			S.dragging = true
			root:StartMoving()
		end
	end)
	root:SetScript("OnDragStop", function()
		root:StopMovingOrSizing()
		S.dragging = false
		SavePosition()
	end)
	root:SetAlpha(0)
	root:Hide()

	local function Layer()
		local f = CreateFrame("Frame", nil, root)
		f:SetAllPoints(root)
		return f
	end
	W.bar = Layer()
	W.bar:ClearAllPoints()
	W.bar:SetPoint("TOPLEFT", root, "TOPLEFT", PAD, -BAR_TOP)
	SetSize(W.bar, 440, BAR_H)
	W.fx = Layer()
	W.rim = Layer()
	W.parts = Layer()
	W.marks = Layer()
	W.top = Layer()

	-- the trough, minute marks and fill
	W.trough = Tex(W.bar, "BACKGROUND", FLAT)
	W.trough:SetAllPoints(W.bar)
	W.ticks = {}
	for i = 1, MAX_TICKS do
		local t = Tex(W.bar, "BORDER", FLAT)
		SetSize(t, 1, BAR_H)
		t:Hide()
		W.ticks[i] = t
	end
	W.fillA = Tex(W.bar, "ARTWORK", ART .. "Fill")
	W.fillA:SetPoint("TOPLEFT", W.bar, "TOPLEFT", 0, 0)
	W.fillA:SetPoint("BOTTOMLEFT", W.bar, "BOTTOMLEFT", 0, 0)
	W.fillA:SetWidth(1)
	W.fillB = Tex(W.bar, "ARTWORK", ART .. "Fill")
	W.fillB:SetPoint("TOPLEFT", W.fillA, "TOPRIGHT", 0, 0)
	W.fillB:SetPoint("BOTTOMLEFT", W.fillA, "BOTTOMRIGHT", 0, 0)
	W.fillB:SetWidth(1)

	-- light inside the fill
	W.flow1 = Tex(W.fx, "BACKGROUND", ART .. "Flow", "ADD")
	W.flow1:SetPoint("TOPLEFT", W.bar, "TOPLEFT", 0, 0)
	W.flow1:SetPoint("BOTTOMLEFT", W.bar, "BOTTOMLEFT", 0, 0)
	W.flow1:SetWidth(1)
	W.flow2 = Tex(W.fx, "BACKGROUND", ART .. "Flow", "ADD")
	W.flow2:SetPoint("TOPLEFT", W.bar, "TOPLEFT", 0, 0)
	W.flow2:SetPoint("BOTTOMLEFT", W.bar, "BOTTOMLEFT", 0, 0)
	W.flow2:SetWidth(1)
	W.gloss = Tex(W.fx, "BORDER", FLAT)
	W.gloss:SetPoint("TOPLEFT", W.bar, "TOPLEFT", 0, 0)
	W.gloss:SetPoint("TOPRIGHT", W.bar, "TOPRIGHT", 0, 0)
	W.gloss:SetHeight(6)
	W.gloss:SetGradientAlpha("VERTICAL", 1, 1, 1, 0, 1, 1, 1, 0.17)
	W.shine = Tex(W.fx, "ARTWORK", ART .. "Shine", "ADD")
	W.shine:SetHeight(BAR_H)
	W.shine:Hide()
	W.spark = Tex(W.fx, "OVERLAY", ART .. "Spark", "ADD")
	SetSize(W.spark, 12, 30)
	W.head = Tex(W.fx, "OVERLAY", ART .. "Glow", "ADD")
	SetSize(W.head, 40, 30)

	-- the metal rim
	W.rimL = Tex(W.rim, "ARTWORK", ART .. "FrameL")
	SetSize(W.rimL, RIM, RIM)
	W.rimL:SetPoint("LEFT", W.bar, "LEFT", -CAP, 0)
	W.rimR = Tex(W.rim, "ARTWORK", ART .. "FrameR")
	SetSize(W.rimR, RIM, RIM)
	W.rimR:SetPoint("RIGHT", W.bar, "RIGHT", CAP, 0)
	W.rimM = Tex(W.rim, "ARTWORK", ART .. "FrameM")
	W.rimM:SetHeight(RIM)
	W.rimM:SetPoint("LEFT", W.rimL, "RIGHT", 0, 0)
	W.rimM:SetPoint("RIGHT", W.rimR, "LEFT", 0, 0)

	-- particles
	for i = 1, MAX_PARTS do
		local t = W.parts:CreateTexture(nil, "ARTWORK")
		t:Hide()
		S.parts[i] = { tex = t, on = false }
	end

	-- text
	W.clock = Text(W.top, FONT, 15, "OUTLINE", "RIGHT", 120)
	W.clock:SetPoint("RIGHT", W.bar, "LEFT", -19, 0)
	W.total = Text(W.top, FONT, 11, "OUTLINE", "LEFT", 120)
	W.total:SetPoint("LEFT", W.bar, "RIGHT", 25, 0)

	W.titleBg = Tex(W.top, "BACKGROUND", ART .. "Glow")
	W.titleBg:SetVertexColor(0, 0, 0, 0.5)
	W.titleBg:SetPoint("CENTER", W.bar, "TOP", 0, 16)
	W.title = Text(W.top, TITLE_FONT, 15, nil, "CENTER", 440)
	W.title:SetPoint("CENTER", W.bar, "TOP", 0, 16)
	W.lineL = Tex(W.top, "BORDER", FLAT)
	SetSize(W.lineL, 64, 1)
	W.lineR = Tex(W.top, "BORDER", FLAT)
	SetSize(W.lineR, 64, 1)
	W.gemL = Tex(W.top, "ARTWORK", ART .. "Diamond")
	SetSize(W.gemL, 9, 9)
	W.gemR = Tex(W.top, "ARTWORK", ART .. "Diamond")
	SetSize(W.gemR, 9, 9)
	W.titleHit = CreateFrame("Frame", nil, W.top)
	SetSize(W.titleHit, 200, 20)
	W.titleHit:SetPoint("CENTER", W.bar, "TOP", 0, 16)
	W.titleHit:EnableMouse(true)
	W.titleHit:SetScript("OnEnter", function()
		ShowTitleTip()
	end)
	W.titleHit:SetScript("OnLeave", function()
		if GameTooltip then GameTooltip:Hide() end
	end)

	-- the next boss, under the bar
	W.call = CreateFrame("Frame", nil, W.top)
	SetSize(W.call, 10, 10)
	W.call:SetPoint("CENTER", W.bar, "BOTTOMLEFT", 0, -24)
	W.callBg = Tex(W.call, "BACKGROUND", ART .. "Glow")
	W.callBg:SetVertexColor(0, 0, 0, 0.5)
	W.callBg:SetPoint("CENTER", W.call, "CENTER", 0, 0)
	W.caret = Tex(W.call, "ARTWORK", ART .. "Caret")
	SetSize(W.caret, 9, 9)
	W.caret:SetPoint("CENTER", W.call, "CENTER", 0, 13)
	W.callText = Text(W.call, FONT, 12, "OUTLINE", "CENTER", 400)
	W.callText:SetPoint("CENTER", W.call, "CENTER", 0, 0)
	W.call:SetAlpha(0)

	W.hint = Text(W.top, FONT, 10, "OUTLINE", "CENTER", 360)
	W.hint:SetPoint("TOP", root, "BOTTOM", 0, -2)
	CUI.LText(W.hint, "Drag to move. Type /creed lock when done.")
	W.hint:SetTextColor(1, 0.85, 0.4)
	W.hint:Hide()

	if type(AZS_SetOnTopOfScreens) == "function" then
		pcall(AZS_SetOnTopOfScreens, root, true)
		pcall(AZS_SetOnTopOfScreens, "GameTooltip", true)
	end
end

local function SetLevels()
	local base = W.root:GetFrameLevel()
	W.bar:SetFrameLevel(base + 1)
	W.fx:SetFrameLevel(base + 2)
	W.rim:SetFrameLevel(base + 3)
	W.parts:SetFrameLevel(base + 4)
	W.marks:SetFrameLevel(base + 5)
	W.top:SetFrameLevel(base + 8)
	for i = 1, table.getn(S.marks) do
		S.marks[i]:SetFrameLevel(base + 6)
		S.marks[i].top:SetFrameLevel(base + 7)
	end
	if S.endMark then
		S.endMark:SetFrameLevel(base + 6)
		S.endMark.top:SetFrameLevel(base + 7)
	end
	W.call:SetFrameLevel(base + 9)
	W.titleHit:SetFrameLevel(base + 9)
end

local function NewMarker()
	local m = CreateFrame("Frame", nil, W.marks)
	SetSize(m, MARK, MARK)
	m:EnableMouse(true)
	m.glow = Tex(m, "BACKGROUND", ART .. "Glow", "ADD")
	m.glow:SetPoint("CENTER", m, "CENTER", 0, 0)
	m.ring = Tex(m, "BACKGROUND", ART .. "Ring", "ADD")
	m.ring:SetPoint("CENTER", m, "CENTER", 0, 0)
	m.ring:Hide()
	m.socket = Tex(m, "BORDER", ART .. "Socket")
	m.socket:SetPoint("CENTER", m, "CENTER", 0, 0)
	-- the gem's empty part while its boss is up: the same gem, dark
	m.gemBack = Tex(m, "ARTWORK", ART .. "Gem")
	m.gemBack:SetPoint("CENTER", m, "CENTER", 0, 0)
	m.gemBack:Hide()
	-- the lit gem, its shine and the check sit one level up so they always draw on top
	m.top = CreateFrame("Frame", nil, m)
	m.top:SetAllPoints(m)
	m.gem = Tex(m.top, "ARTWORK", ART .. "Gem")
	m.shine = Tex(m.top, "OVERLAY", ART .. "GemShine", "ADD")
	m.shine:SetPoint("CENTER", m, "CENTER", 0, 0)
	m.check = Tex(m.top, "OVERLAY", ART .. "Check")
	m.check:SetPoint("CENTER", m, "CENTER", 0, 0)
	m.check:Hide()
	m.scale, m.scaleV, m.vis, m.glowA, m.hp = 1, 0, 0, 0, 1
	m.r, m.g, m.b, m.gr, m.gg, m.gb = 1, 1, 1, 1, 1, 1
	m.snap = true
	m:SetScript("OnEnter", function()
		S.hover = m
		ShowMarkerTip(m)
	end)
	m:SetScript("OnLeave", function()
		if S.hover == m then S.hover = nil end
		if GameTooltip then GameTooltip:Hide() end
	end)
	m:SetFrameLevel(W.root:GetFrameLevel() + 6)
	m.top:SetFrameLevel(W.root:GetFrameLevel() + 7)
	m:SetAlpha(0)
	m:Hide()
	return m
end

------------------------------------------------------------------------ layout and position
local function ApplyPosition()
	local root = W.root
	local s = db.scale
	root:SetScale(s)
	root:ClearAllPoints()
	root:SetPoint("TOP", UIParent, "TOP", db.x / s, (db.y + S.slide) / s)
end

SavePosition = function()
	local root = W.root
	local s = db.scale
	local l, r, t = root:GetLeft(), root:GetRight(), root:GetTop()
	if not (l and r and t) then return end
	db.x = math.floor((l + r) * 0.5 * s - UIParent:GetWidth() * 0.5 + 0.5)
	db.y = math.floor(t * s - UIParent:GetHeight() + 0.5)
	ApplyPosition()
end

local function Layout()
	S.width = db.width
	W.root:SetWidth(S.width + PAD * 2)
	W.bar:SetWidth(S.width)
	S.tickKey = nil
	S.titleKey = nil
	for i = 1, table.getn(S.marks) do
		S.marks[i].x = nil
	end
	if S.endMark then S.endMark.x = nil end
	ApplyPosition()
end

local function ApplyLock()
	local root = W.root
	if db.locked then
		root:EnableMouse(false)
		root:SetBackdropColor(0, 0, 0, 0)
		root:SetBackdropBorderColor(1, 1, 1, 0)
		W.hint:Hide()
	else
		root:EnableMouse(true)
		root:SetBackdropColor(0, 0, 0, 0.35)
		root:SetBackdropBorderColor(1, 0.85, 0.4, 0.6)
		W.hint:Show()
	end
	local mouse = db.locked
	for i = 1, table.getn(S.marks) do
		S.marks[i]:EnableMouse(mouse)
	end
	if S.endMark then S.endMark:EnableMouse(mouse) end
	W.titleHit:EnableMouse(mouse)
end

------------------------------------------------------------------------ palette
-- the bosses' gems along the bar: red in every zone
local GEM_RED = { 0.95, 0.27, 0.20 }
local function ApplyPalette()
	local p = S.pal
	CUI.pal = p
	CUI.palStamp = CUI.palStamp + 1
	local a, m, b = p.fillA, p.fillM, p.fillB
	W.fillA:SetGradientAlpha("HORIZONTAL", a[1], a[2], a[3], 1, m[1], m[2], m[3], 1)
	W.fillB:SetGradientAlpha("HORIZONTAL", m[1], m[2], m[3], 1, b[1], b[2], b[3], 1)
	local tr = p.trough
	W.trough:SetVertexColor(tr[1], tr[2], tr[3], 0.9)
	local g = p.glow
	W.flow1:SetVertexColor(g[1], g[2], g[3], 0.5)
	W.flow2:SetVertexColor(g[1], g[2], g[3], 0.32)
	-- its metal in Creed UI's bronze gold, as every part's (Core's C.BRONZE), in every zone; the
	-- zone's colors stay in its fill, glow and title
	local bronze = CUI.BRONZE
	local rim = bronze and bronze.rim or p.rim
	W.rimL:SetVertexColor(rim[1], rim[2], rim[3])
	W.rimM:SetVertexColor(rim[1], rim[2], rim[3])
	W.rimR:SetVertexColor(rim[1], rim[2], rim[3])
	W.gemL:SetVertexColor(rim[1], rim[2], rim[3])
	W.gemR:SetVertexColor(rim[1], rim[2], rim[3])
	local t = p.title
	W.title:SetTextColor(t[1], t[2], t[3])
	W.lineL:SetGradientAlpha("HORIZONTAL", t[1], t[2], t[3], 0, t[1], t[2], t[3], 0.75)
	W.lineR:SetGradientAlpha("HORIZONTAL", t[1], t[2], t[3], 0.75, t[1], t[2], t[3], 0)
	W.clock:SetTextColor(0.45 + t[1] * 0.55, 0.45 + t[2] * 0.55, 0.45 + t[3] * 0.55)
	W.total:SetTextColor(t[1] * 0.8, t[2] * 0.8, t[3] * 0.8)
	W.caret:SetVertexColor(t[1], t[2], t[3])
end

-- the colors glide from one theme to the next
local function StepPalette(dt)
	local theme = S.theme
	local k = 1 - math.exp(-dt * 3.5)
	local far = 0
	for i = 1, table.getn(PAL_KEYS) do
		local key = PAL_KEYS[i]
		local c, tc = S.pal[key], theme[key]
		for j = 1, 3 do
			local d = tc[j] - c[j]
			if d > far then far = d elseif -d > far then far = -d end
			c[j] = c[j] + d * k
		end
	end
	if far < 0.002 then
		for i = 1, table.getn(PAL_KEYS) do
			local key = PAL_KEYS[i]
			local c, tc = S.pal[key], theme[key]
			c[1], c[2], c[3] = tc[1], tc[2], tc[3]
		end
		S.palMoving = false
	end
	ApplyPalette()
	S.callBuilt = nil -- the next boss line carries colors too
	S.titleKey = nil
end

local function SetTheme(theme, key, instant)
	if S.theme == theme then return end
	S.theme, S.themeKey = theme, key
	CUI.themeKey = key
	S.motif = MOTIFS[theme.motif] or MOTIFS.motes
	if instant or not S.pal.title then
		for i = 1, table.getn(PAL_KEYS) do
			local k = PAL_KEYS[i]
			S.pal[k] = { theme[k][1], theme[k][2], theme[k][3] }
		end
	end
	S.palMoving = true
end

------------------------------------------------------------------------ reading the run
local function SameRun(last, t)
	if type(last) ~= "table" or not last.t or not last.when or not t then return false end
	if t < last.t - 10 then return false end
	if t - last.t > (GetTime() - last.when) + 10 then return false end
	local run = type(AZS_RUN) == "table" and AZS_RUN or EMPTY
	local fin = tonumber(run.fin)
	if fin and fin > 0 and last.len and math.abs(fin - last.len) > 1 then return false end
	return true
end

local function ParseLiveSchedule(out)
	local s = AZS_SCHEDULE
	if type(s) ~= "table" then return 0 end
	local n = 0
	for i = 1, table.getn(s) do
		local e = s[i]
		if type(e) == "table" then
			local at = tonumber(e.at or e[2])
			if at and at > 0 then
				n = n + 1
				local o = out[n]
				if not o then
					o = {}
					out[n] = o
				end
				o.at = at
				local name = e.name or e[3]
				o.name = name and tostring(name) or ""
				local fin = e.final or e[4]
				o.final = fin == 1 or fin == true or fin == "1"
				local st = e.state or e[5]
				if st ~= "due" and st ~= "up" and st ~= "dead" then st = nil end
				o.state = st
				o.hp, o.enraged = nil, nil
			end
		end
	end
	return n
end

local function CopyList(list, out, first, step)
	local n = 0
	for i = first, table.getn(list), step do
		n = n + 1
		local o = out[n]
		if not o then
			o = {}
			out[n] = o
		end
		if step == 2 then
			o.at, o.name, o.final = list[i], list[i + 1], false
		else
			local e = list[i]
			o.at, o.name, o.final = e.at, e.name, e.final
		end
		o.state, o.hp, o.enraged = nil, nil, nil
	end
	if n > 0 and step == 2 then out[n].final = true end
	return n
end

local function SortSchedule(out, n)
	for i = 2, n do
		local e = out[i]
		local j = i - 1
		while j >= 1 and out[j].at > e.at do
			out[j + 1] = out[j]
			j = j - 1
		end
		out[j + 1] = e
	end
	local anyFinal = false
	for i = 1, n do
		if out[i].final then anyFinal = true end
	end
	if n > 0 and not anyFinal then out[n].final = true end
end

local function FindBoss(bosses, name, final)
	if type(bosses) ~= "table" then return nil end
	local n = table.getn(bosses)
	for i = 1, n do
		local b = bosses[i]
		if type(b) == "table" and b.name == name then return b end
	end
	if final then
		for i = 1, n do
			local b = bosses[i]
			if type(b) == "table" and b.final then return b end
		end
	end
	return nil
end

local function GuessZone(bosses)
	local run = type(AZS_RUN) == "table" and AZS_RUN or EMPTY
	if type(run.nbn) == "string" and NAME_TO_ZONE[string.lower(run.nbn)] then
		return NAME_TO_ZONE[string.lower(run.nbn)]
	end
	for i = 1, R.n do
		local key = NAME_TO_ZONE[string.lower(R.sched[i].name or "")]
		if key then return key end
	end
	if type(bosses) == "table" then
		for i = 1, table.getn(bosses) do
			local b = bosses[i]
			local key = type(b) == "table" and type(b.name) == "string" and NAME_TO_ZONE[string.lower(b.name)]
			if key then return key end
		end
	end
	if type(GetRealZoneText) == "function" then
		local text = GetRealZoneText()
		if type(text) == "string" and ZNAME_TO_ZONE[string.lower(text)] then
			return ZNAME_TO_ZONE[string.lower(text)]
		end
	end
	return nil
end

-- remember the run so a /reload can pick it up again
local function Remember(key, z, t)
	local last = db.last
	if type(last) ~= "table" then
		last = {}
		db.last = last
	end
	last.zone, last.len, last.t, last.when = key, S.len, t, GetTime()
	last.zname = z.zname or last.zname
	last.zsub = z.zsub or last.zsub
	last.heroic = tonumber(z.heroic) or last.heroic
	last.affixes = z.affixes or last.affixes
	local sched = last.sched
	local same = type(sched) == "table" and table.getn(sched) == R.n
	if same then
		for i = 1, R.n do
			if sched[i].at ~= R.sched[i].at or sched[i].name ~= R.sched[i].name then same = false end
		end
	end
	if not same then
		sched = {}
		for i = 1, R.n do
			local e = R.sched[i]
			sched[i] = { at = e.at, name = e.name, final = e.final }
		end
		last.sched = sched
	end
	db.lastZone = key
end

-- the schedule, zone and bosses: read ten times a second
local function RefreshData(t)
	local z = type(AZS_ZONE) == "table" and AZS_ZONE or EMPTY
	local key = z.zone
	if type(key) ~= "string" or key == "" then key = nil end
	local bosses = Call(AZS_GetBosses)
	local n = ParseLiveSchedule(R.sched)
	local source = n > 0 and "live" or nil
	local last = db.last
	local same = SameRun(last, t)
	if not key and same then key = last.zone end
	if n == 0 and same and type(last.sched) == "table" and table.getn(last.sched) > 0 then
		n = CopyList(last.sched, R.sched, 1, 1)
		source = "saved"
	end
	R.n = n
	if not key then key = GuessZone(bosses) end
	if n == 0 and key and FALLBACK[key] then
		n = CopyList(FALLBACK[key], R.sched, 2, 2)
		source = "fallback"
		R.n = n
	end
	SortSchedule(R.sched, n)

	local run = type(AZS_RUN) == "table" and AZS_RUN or EMPTY
	local bs = tonumber(run.bs)
	for i = 1, n do
		local e = R.sched[i]
		local b = FindBoss(bosses, e.name, e.final)
		if not e.state then
			if b then
				e.state = "up"
			elseif (bs and i <= bs) or (not bs and e.at <= t) then
				e.state = "dead"
			else
				e.state = "due"
			end
		end
		-- the previous run's states can linger for a moment after "Again?"
		if e.state ~= "due" and e.at > t + 5 then e.state = "due" end
		if e.state == "up" and b and tonumber(b.hpm) and b.hpm > 0 then
			e.hp = Clamp((tonumber(b.hp) or 0) / b.hpm, 0, 1)
			e.enraged = b.enraged and true or false
		end
	end

	local fb = key and FALLBACK[key]
	local theme = key and THEMES[key]
	R.zone = key
	R.zname = (type(z.zname) == "string" and z.zname ~= "" and z.zname) or (same and last.zname)
		or (theme and theme.name) or ""
	R.zsub = (type(z.zsub) == "string" and z.zsub ~= "" and z.zsub) or (same and last.zsub)
		or (theme and theme.sub) or ""
	R.heroic = tonumber(z.heroic) or (same and last.heroic) or 0
	R.affixes = (type(z.affixes) == "string" and z.affixes) or (same and last.affixes) or ""
	local len = Call(AZS_GetRunLength)
	if type(len) ~= "number" or len <= 0 then len = tonumber(run.fin) end
	if (not len or len <= 0) and tonumber(z.len) then len = tonumber(z.len) end
	if (not len or len <= 0) and same and last.len then len = last.len end
	if (not len or len <= 0) and fb then len = fb[1] end
	if (not len or len <= 0) and n > 0 then len = R.sched[n].at end
	if not len or len <= 0 then len = 960 end
	R.len = len
	R.source = source
	if source == "live" and key then
		S.len = len
		Remember(key, z, t)
	elseif same and last then
		last.t, last.when = t, GetTime()
	end
end

local function ReadLive()
	R.ok = false
	if type(AZS_GetPhase) ~= "function" then return end
	local run = type(AZS_RUN) == "table" and AZS_RUN or EMPTY
	local phase = Call(AZS_GetPhase)
	R.phase = phase
	-- A new run's zone comes in before anyone moves ("Move to begin", a party gathering): until
	-- the clock starts, the bar already shows, at 0:00. Any zone seen in another phase is old.
	local zoneStamp = AZS_ZONE_UPDATED
	if phase ~= "ready" then S.oldZone = zoneStamp end
	if phase == "ready" and zoneStamp ~= nil and zoneStamp ~= S.oldZone then
		R.ok, R.rawT, R.stopped = true, 0, true
		R.endless, R.nb = tonumber(run.endl) == 1, tonumber(run.nb)
		return
	end
	if not phase or not SHOWN_PHASES[phase] then return end
	local t = Call(AZS_GetRunTime)
	if type(t) ~= "number" then return end
	R.ok = true
	R.rawT = t
	R.stopped = STOPPED_PHASES[phase] and true or false
	R.endless = tonumber(run.endl) == 1
	R.nb = tonumber(run.nb)
end

------------------------------------------------------------------------ preview and placeholder
local function PreviewZone(key)
	if key and THEMES[key] and key ~= "default" then return key end
	if db.theme ~= "auto" and THEMES[db.theme] then return db.theme end
	if R.zone and FALLBACK[R.zone] then return R.zone end
	if db.lastZone and FALLBACK[db.lastZone] then return db.lastZone end
	return "elwynn"
end

local PREVIEW_RUN = 22   -- seconds of preview for the whole run
local PREVIEW_FIGHT = 2.4 -- seconds each preview boss lives

local function FillFake(key, t, now, elapsed)
	local list = FALLBACK[key]
	local n = CopyList(list, R.sched, 2, 2)
	local len = list[1]
	R.n, R.len, R.zone = n, len, key
	R.zname, R.zsub = THEMES[key].name, THEMES[key].sub
	R.heroic, R.affixes = 0, ""
	R.endless, R.nb, R.stopped = false, nil, false
	R.ok = true
	if elapsed then
		-- a running preview: bosses arrive on time and die PREVIEW_FIGHT seconds later
		local allDead = true
		for i = 1, n do
			local e = R.sched[i]
			local born = e.at / len * PREVIEW_RUN
			if elapsed < born then
				e.state = "due"
				allDead = false
			elseif elapsed < born + PREVIEW_FIGHT then
				e.state = "up"
				local f = (elapsed - born) / PREVIEW_FIGHT
				e.hp = 1 - f
				e.enraged = e.hp < 0.3
				allDead = false
			else
				e.state = "dead"
			end
		end
		R.rawT = math.min(len, elapsed / PREVIEW_RUN * len)
		R.phase = allDead and "victory" or "playing"
	else
		-- a still picture for placing the bar: one boss down, one up, the rest to come
		R.rawT = t
		for i = 1, n do
			local e = R.sched[i]
			if e.at <= t then e.state = "dead" else e.state = "due" end
		end
		if n >= 2 and R.sched[2].at <= t then
			R.sched[2].state = "up"
			R.sched[2].hp = 0.6 + 0.05 * math.sin(now * 0.7)
		end
		R.phase = "playing"
	end
end

local function StopPreview()
	if not P.on then return end
	P.on = false
	S.dataClock = 0
	S.quietUntil = GetTime() + 1
	S.lastRaw = nil
	S.resetNext = true
end

local function StartPreview(key)
	P.on = true
	P.zone = PreviewZone(key)
	P.start = GetTime()
	S.quietUntil = GetTime() + 0.2
	S.lastRaw = nil
	S.resetNext = true
end

------------------------------------------------------------------------ drawing: the fill
local function StepFill(dt, now)
	local target = S.fillTarget
	-- a spring starts and ends gently, so even a big change (endless starting a new countdown,
	-- a corrected clock) glides instead of snapping
	S.fill, S.fillV = Spring(S.fill, S.fillV, target, 6, dt)
	if math.abs(target - S.fill) < 0.0002 and math.abs(S.fillV) < 0.002 then
		S.fill, S.fillV = target, 0
	end
	if S.fill < 0 then S.fill, S.fillV = 0, 0 end
	local fw = S.width * S.fill
	if fw < 0.75 then
		Vis(W.fillA, false)
		Vis(W.fillB, false)
		Vis(W.flow1, false)
		Vis(W.flow2, false)
		Vis(W.spark, false)
		Vis(W.head, false)
		Vis(W.shine, false)
		return 0
	end
	local half = fw * 0.5
	local fa = Smooth(fw / 5) -- the first pixels fade in rather than pop
	W.fillA:SetWidth(half)
	W.fillB:SetWidth(fw - half)
	Alpha(W.fillA, fa)
	Alpha(W.fillB, fa)
	Vis(W.fillA, true)
	Vis(W.fillB, true)

	if db.flow then
		local speed = R.stopped and 0.35 or 1
		S.flow1 = math.mod(S.flow1 + dt * 26 * speed / FLOW_SIZE, FLOW_PERIOD)
		S.flow2 = math.mod(S.flow2 + dt * 11 * speed / FLOW_SIZE, FLOW_PERIOD)
		local u = FLOW_PERIOD - S.flow1
		W.flow1:SetWidth(fw)
		W.flow1:SetTexCoord(u, u + fw / FLOW_SIZE, 0, 1)
		local u2 = FLOW_PERIOD - S.flow2
		W.flow2:SetWidth(fw)
		W.flow2:SetTexCoord(u2, u2 + fw * 0.5 / FLOW_SIZE, 1, 0)
		Alpha(W.flow1, fa)
		Alpha(W.flow2, fa)
		Vis(W.flow1, true)
		Vis(W.flow2, true)
	else
		Vis(W.flow1, false)
		Vis(W.flow2, false)
	end

	-- the glowing head
	local g = S.pal.glow
	local flick = 0.84 + 0.09 * math.sin(now * 7.3) + 0.06 * math.sin(now * 12.9)
	local edge = Smooth(fw / 6)
	W.spark:SetPoint("CENTER", W.bar, "LEFT", fw, 0)
	W.spark:SetVertexColor(g[1], g[2], g[3], 0.9 * flick * edge)
	W.head:SetPoint("CENTER", W.bar, "LEFT", fw - 5, 0)
	W.head:SetVertexColor(g[1], g[2], g[3], 0.36 * flick * edge)
	Vis(W.spark, true)
	Vis(W.head, true)

	-- a sheen that sweeps along the fill now and then
	if now >= S.shineNext then
		S.shineStart = now
		S.shineNext = now + 6 + math.random() * 3.5
	end
	local p = (now - S.shineStart) / 1.6
	if p >= 0 and p <= 1 and db.flow then
		local bw = 70
		local bx = -bw + (fw + bw * 2) * Smooth(p)
		local x0, x1 = math.max(bx, 0), math.min(bx + bw, fw)
		if x1 - x0 > 0.5 then
			W.shine:SetWidth(x1 - x0)
			W.shine:SetPoint("LEFT", W.bar, "LEFT", x0, 0)
			W.shine:SetTexCoord((x0 - bx) / bw, (x1 - bx) / bw, 0, 1)
			W.shine:SetVertexColor(1, 1, 1, math.sin(p * 3.14159) * 0.42)
			Vis(W.shine, true)
		else
			Vis(W.shine, false)
		end
	else
		Vis(W.shine, false)
	end
	return fw
end

local function LayoutTicks()
	local key = string.format("%s:%s:%s:%s", tostring(S.len), tostring(S.width), tostring(db.ticks), tostring(S.endless))
	if key == S.tickKey then return end
	S.tickKey = key
	local n = 0
	local len = S.len
	if db.ticks and not S.endless and len and len > 60 then
		local k = 1
		while k * 60 < len - 1 and n < MAX_TICKS do
			n = n + 1
			local t = W.ticks[n]
			t:ClearAllPoints()
			t:SetPoint("TOPLEFT", W.bar, "TOPLEFT", S.width * k * 60 / len, 0)
			if math.mod(k, 5) == 0 then
				t:SetVertexColor(1, 1, 1, 0.16)
			else
				t:SetVertexColor(1, 1, 1, 0.07)
			end
			t:Show()
			k = k + 1
		end
	end
	for i = n + 1, MAX_TICKS do
		W.ticks[i]:Hide()
	end
end

------------------------------------------------------------------------ drawing: markers
local function StepMarker(m, e, x, isNext, soon, dt, now, visTarget)
	local pal = S.pal
	local final = e.final and true or false
	local state = e.state or "due"
	if m.final ~= final then
		m.final = final
		if final then
			m.socket:SetTexture(ART .. "SocketFinal")
			SetSize(m, MARK_FINAL, MARK_FINAL)
		else
			m.socket:SetTexture(ART .. "Socket")
			SetSize(m, MARK, MARK)
		end
	end
	if m.state ~= state then
		if m.state and now >= S.quietUntil and m.vis > 0.3 then
			if state == "up" then
				m.burst, m.br, m.bg, m.bb = now, 1, 0.34, 0.18
				m.scaleV = m.scaleV + 4.5
			elseif state == "dead" then
				local t = pal.title
				m.burst, m.br, m.bg, m.bb = now, t[1], t[2], t[3]
				m.scaleV = m.scaleV + 5.5
				m.checkAt = now
				-- an emptied gem doesn't refill: the slain gem fades in over it
				if m.hp < 0.95 then
					m.hp, m.gemFade = 1, 0
				end
			end
		else
			m.snap = true
			m.burst = nil
			m.checkAt = state == "dead" and (now - 1) or nil
		end
		m.state = state
	end
	if m.x ~= x then
		m.x = x
		m:SetPoint("CENTER", W.bar, "LEFT", x, 0)
	end

	-- where each part of the marker is heading
	local tr, tg, tb, glowA, gr, gg, gb, scaleT, shineA, sockA, sockK
	if state == "up" then
		local pulse = 0.5 + 0.5 * math.sin(now * (e.enraged and 2.1 or 0.9) * TWO_PI)
		tr, tg, tb = 1, 0.20 + 0.20 * pulse, 0.12
		glowA, gr, gg, gb = 0.40 + 0.32 * pulse, 1, 0.22, 0.10
		scaleT, shineA, sockA, sockK = 1.12 + 0.04 * pulse, 0.9, 1, 1
	elseif state == "dead" then
		local gem = GEM_RED
		tr, tg, tb = 0.40 + gem[1] * 0.14, 0.40 + gem[2] * 0.14, 0.42 + gem[3] * 0.14
		glowA, gr, gg, gb = 0, 0, 0, 0
		scaleT, shineA, sockA, sockK = 0.84, 0.22, 0.85, 0.62
	else
		local gem = GEM_RED
		local k = isNext and 1 or 0.86
		tr, tg, tb = gem[1] * k, gem[2] * k, gem[3] * k
		gr, gg, gb = gem[1], gem[2], gem[3]
		if isNext then
			local pulse = 0.5 + 0.5 * math.sin(now * (0.7 + 1.7 * soon) * TWO_PI)
			glowA = 0.22 + 0.12 * pulse + soon * (0.34 + 0.26 * pulse)
			scaleT = 1.1 + 0.14 * soon + 0.03 * pulse * soon
		elseif final then
			glowA = 0.16 + 0.06 * math.sin(now * 1.7)
			scaleT = 1
		else
			glowA, scaleT = 0, 1
		end
		shineA, sockA, sockK = 0.85, 1, 1
	end

	local k = 1 - math.exp(-dt * 7)
	if m.snap then
		k = 1
		m.scale, m.scaleV = scaleT, 0
		m.hp = (state == "up" and e.hp) or 1
		m.gemFade = 1
		m.snap = nil
	end
	-- everything settles exactly, so a marker at rest stops writing to the client
	m.gemFade = Ease(m.gemFade or 1, 1, 1 - math.exp(-dt * 4.5))
	m.r, m.g, m.b = Ease(m.r, tr, k), Ease(m.g, tg, k), Ease(m.b, tb, k)
	m.gr, m.gg, m.gb = Ease(m.gr, gr, k), Ease(m.gg, gg, k), Ease(m.gb, gb, k)
	m.glowA = Ease(m.glowA, glowA, k)
	m.sockA = Ease(m.sockA or sockA, sockA, k)
	m.sockK = Ease(m.sockK or sockK, sockK, k)
	m.shineA = Ease(m.shineA or shineA, shineA, k)
	m.scale, m.scaleV = Spring(m.scale, m.scaleV, scaleT, 12, dt)
	if math.abs(m.scale - scaleT) < 0.0004 and math.abs(m.scaleV) < 0.004 then m.scale, m.scaleV = scaleT, 0 end
	local hp = (state == "up" and e.hp) or 1
	m.hp = Ease(m.hp, hp, 1 - math.exp(-dt * (state == "up" and 6 or 3)))
	m.vis = Toward(m.vis, visTarget, 6, dt)
	if visTarget > 0 and m.vis > 0.995 then m.vis = 1 end

	if m.vis < 0.01 and visTarget == 0 then
		Vis(m, false)
		return
	end
	Vis(m, true)
	Alpha(m, Smooth(m.vis))

	local base = final and MARK_FINAL or MARK
	local s = base * m.scale
	Size(m.socket, s, s)
	local rim = CUI.BRONZE and CUI.BRONZE.rim or pal.rim
	Color(m.socket, rim[1] * m.sockK, rim[2] * m.sockK, rim[3] * m.sockK, m.sockA)

	-- the gem drains from the top while its boss is up
	local g = s * (final and 0.9375 or 1)
	local f = Clamp(m.hp, 0, 1)
	if f < 0.004 then
		Vis(m.gem, false)
	else
		local top = 0.82 - 0.64 * f
		Size(m.gem, g, g * (1 - top))
		if m.gemTop ~= top or m.gemG ~= g then
			m.gemTop, m.gemG = top, g
			m.gem:SetTexCoord(0, 1, top, 1)
			m.gem:SetPoint("BOTTOM", m, "CENTER", 0, -g * 0.5)
		end
		Color(m.gem, m.r, m.g, m.b, Smooth(f / 0.05) * m.gemFade)
		Vis(m.gem, true)
	end
	if f < 0.995 or m.gemFade < 1 then
		Size(m.gemBack, g, g)
		local ba = math.max(Smooth((1 - f) / 0.06), 1 - m.gemFade)
		Color(m.gemBack, 0.1 + m.r * 0.26, 0.1 + m.g * 0.2, 0.12 + m.b * 0.2, ba)
		Vis(m.gemBack, true)
	else
		Vis(m.gemBack, false)
	end
	Size(m.shine, g, g)
	Alpha(m.shine, m.shineA * (0.45 + 0.55 * f))

	if m.glowA > 0.01 then
		local gs = s * (final and 2.5 or 2.3)
		Size(m.glow, gs, gs)
		Color(m.glow, m.gr, m.gg, m.gb, m.glowA)
		Vis(m.glow, true)
	else
		Vis(m.glow, false)
	end

	if m.burst then
		local p = (now - m.burst) / 0.8
		if p >= 1 then
			m.burst = nil
			Vis(m.ring, false)
		else
			local rs = base * (0.9 + 2.1 * Smooth(p))
			Size(m.ring, rs, rs)
			local a = 1 - p
			Color(m.ring, m.br, m.bg, m.bb, 0.9 * a * a)
			Vis(m.ring, true)
		end
	end

	if state == "dead" and m.checkAt then
		local p = Clamp((now - m.checkAt) / 0.35, 0, 1)
		local cs = base * 0.6 * (1 + 0.8 * (1 - Smooth(p)))
		Size(m.check, cs, cs)
		local t = pal.title
		Color(m.check, t[1], t[2], t[3], 0.95 * Smooth(p))
		Vis(m.check, true)
	else
		Vis(m.check, false)
	end
end

local ENDLESS_ENTRY = { final = true, state = "due", name = "Next boss" }

local function StepMarkers(dt, now)
	local len = S.len
	local Wd = S.width
	local nextIndex, soon = nil, 0
	if not S.endless then
		for i = 1, R.n do
			if R.sched[i].state == "due" then
				nextIndex = i
				break
			end
		end
		if nextIndex then
			local left = R.sched[nextIndex].at - S.t
			soon = Clamp(1 - left / 10, 0, 1)
		end
	end
	S.nextIndex = nextIndex
	local regular = S.endless and 0 or 1
	for i = 1, R.n do
		local m = S.marks[i]
		if not m then
			m = NewMarker()
			m:EnableMouse(db.locked)
			S.marks[i] = m
		end
		local e = R.sched[i]
		StepMarker(m, e, Wd * Clamp(e.at / len, 0, 1), i == nextIndex, soon, dt, now, regular)
		m.entry = e
	end
	for i = R.n + 1, table.getn(S.marks) do
		local m = S.marks[i]
		if m.vis > 0 or m:IsShown() then
			StepMarker(m, m.entry or ENDLESS_ENTRY, m.x or 0, false, 0, dt, now, 0)
		end
	end
	-- endless: one marker at the end for the boss that's coming
	if S.endless or S.endMark then
		if not S.endMark then
			S.endMark = NewMarker()
			S.endMark:EnableMouse(db.locked)
		end
		local esoon = S.endLeft and Clamp(1 - S.endLeft / 10, 0, 1) or 0
		StepMarker(S.endMark, ENDLESS_ENTRY, Wd, S.endless and S.endLeft ~= nil, esoon, dt, now, S.endless and 1 or 0)
		S.endMark.entry = ENDLESS_ENTRY
	end
end

------------------------------------------------------------------------ drawing: the next boss
local function StepCallout(dt, now)
	local pal = S.pal
	local name, left, cx
	if R.phase == "victory" then
		name, cx = "|victory", S.width
	elseif S.endless then
		if S.endLeft then
			name, left, cx = "|endless", S.endLeft, S.width
		end
	elseif S.nextIndex then
		local e = R.sched[S.nextIndex]
		name, left, cx = e.name, e.at - S.t, S.width * Clamp(e.at / S.len, 0, 1)
	end
	if not db.callout then name = nil end

	-- change bosses with a quick fade; the pointer glides to the next marker
	local want = 0
	if name then
		if S.callName == name then
			want = 1
		elseif S.callName == nil or S.callAlpha < 0.04 then
			S.callName = name
			S.callBuilt = nil
			want = 1
			if not S.textX then
				S.textX, S.caretX = cx, cx
			end
		end
	end
	S.callAlpha = Toward(S.callAlpha, want, want > 0 and 8 or 11, dt)
	if want == 0 and S.callAlpha < 0.01 then
		S.callAlpha = 0
		if not name then S.callName = nil end
		Vis(W.call, false)
		return
	end
	if want > 0 and S.callAlpha > 0.998 then S.callAlpha = 1 end
	Vis(W.call, true)
	if cx and S.callName == name then
		S.callCx = cx
	end
	cx = S.callCx or cx or 0

	-- text: the boss's name, then the countdown, warming up over the last ten seconds
	-- (while the line fades out for the next boss, it keeps its last words)
	local second = left and math.ceil(left - 0.0001) or -1
	local soon = left and Clamp(1 - left / 10, 0, 1) or 0
	local warm = math.floor(soon * 8 + 0.5)
	local fading = S.callName ~= name
	if fading and S.callSecond then
		second, warm = S.callSecond, S.callWarm or warm
	end
	local key = S.callName .. "#" .. second .. "#" .. warm .. "#" .. CUI.langStamp
	if key ~= S.callBuilt then
		if S.callSecond and second ~= S.callSecond and left and left <= 10 and left > 0 and not fading then
			S.callScaleV = S.callScaleV + 2.6 -- a small beat each second
		end
		S.callSecond, S.callWarm = second, warm
		S.callBuilt = key
		local text
		if S.callName == "|victory" then
			text = Hex(pal.title) .. L("Victory!") .. "|r"
		else
			local who = S.callName
			if who == "|endless" or who == "" then who = L("Next boss") end
			local w = warm / 8
			local count = { 1 - 0 * w, 1 - 0.62 * w, 1 - 0.75 * w }
			text = Hex(pal.title) .. who .. "|r  " .. Hex(count) .. Clock(second) .. "|r"
		end
		W.callText:SetText(text)
		S.callTw = nil
	end

	-- measure the line once per change (again while the font's metrics aren't ready)
	if not S.callTw or S.callTw <= 0 then S.callTw = W.callText:GetStringWidth() end
	local tw = S.callTw
	if not tw or tw <= 0 then tw = string.len(S.callName) * 7 + 30 end
	local half = tw * 0.5
	local lo, hi = -PAD + half + 4, S.width + PAD - half - 4
	local tx = Clamp(cx, lo, math.max(lo, hi))
	local caretTarget = Clamp(cx, 0, S.width)
	S.textX, S.textV = Spring(S.textX or tx, S.textV, tx, 9, dt)
	if math.abs(S.textX - tx) < 0.02 and math.abs(S.textV) < 0.05 then S.textX, S.textV = tx, 0 end
	S.caretX, S.caretV = Spring(S.caretX or caretTarget, S.caretV, caretTarget, 10, dt)
	if math.abs(S.caretX - caretTarget) < 0.02 and math.abs(S.caretV) < 0.05 then S.caretX, S.caretV = caretTarget, 0 end
	S.callScale, S.callScaleV = Spring(S.callScale, S.callScaleV, 1, 14, dt)
	if math.abs(S.callScale - 1) < 0.0005 and math.abs(S.callScaleV) < 0.005 then S.callScale, S.callScaleV = 1, 0 end
	local sc = Clamp(S.callScale, 0.8, 1.4)

	-- place only what moved
	if sc ~= S.callSc or S.textX ~= S.callTx or S.caretX ~= S.callCaret then
		S.callSc, S.callTx, S.callCaret = sc, S.textX, S.caretX
		W.call:SetScale(sc)
		W.call:SetPoint("CENTER", W.bar, "BOTTOMLEFT", S.textX / sc, -24 / sc)
		W.caret:SetPoint("CENTER", W.call, "CENTER", (S.caretX - S.textX) / sc, 13 / sc)
	end
	Size(W.callBg, tw + 60, 26)
	Alpha(W.call, Smooth(S.callAlpha))
end

------------------------------------------------------------------------ drawing: text
local TITLE_PARTS = { "title", "titleBg", "lineL", "lineR", "gemL", "gemR" }

local function StepText(now, dt)
	local clock = Clock(S.t)
	if clock ~= S.clockText then
		S.clockText = clock
		W.clock:SetText(clock)
	end
	if R.stopped and R.phase ~= "dead" and R.phase ~= "victory" then
		Alpha(W.clock, 0.62 + 0.3 * math.sin(now * 3.2))
	else
		Alpha(W.clock, 1)
	end

	-- the run's length, or ENDLESS: a change fades out and back in
	local total = S.endless and "ENDLESS" or Clock(S.len)
	if total ~= S.totalShown then
		S.totalA = Toward(S.totalA, 0, 12, dt)
		if S.totalA < 0.03 or S.totalShown == nil then
			S.totalShown = total
			W.total:SetText(total)
		end
	else
		S.totalA = Toward(S.totalA, 1, 8, dt)
		if S.totalA > 0.997 then S.totalA = 1 end
	end
	Alpha(W.total, S.totalA)

	-- the zone's name, with flourishes that hug it
	if now >= S.titleNext then
		S.titleNext = now + 0.25
		S.titleKey = nil
	end
	local key = string.format("%s|%s|%s|%s", R.zname or "", tostring(R.heroic), tostring(S.endless), tostring(db.title))
	if key ~= S.titleKey then
		S.titleKey = key
		local want
		if db.title and R.zname and R.zname ~= "" then
			want = R.zname
			local h = tonumber(R.heroic) or 0
			if h > 0 then
				local c = HEROIC_COLORS[math.min(h, 5)]
				want = want .. "  " .. Hex(c) .. "Heroic " .. (ROMAN[h] or tostring(h)) .. "|r"
			end
			if S.endless then
				want = want .. "  " .. Hex(S.theme.glow) .. "Endless|r"
			end
		end
		S.titleWant = want
	end
	-- a new name fades the old one out first; the flourishes slide to fit it
	if S.titleWant ~= S.titleShown then
		S.titleA = Toward(S.titleA, 0, 12, dt)
		if S.titleA < 0.03 or S.titleShown == nil then
			S.titleShown = S.titleWant
			if S.titleShown then
				W.title:SetText(S.titleShown)
				local tw = W.title:GetStringWidth()
				if not tw or tw <= 0 then tw = string.len(S.titleShown) * 8 end
				S.titleTarget = tw
				if not S.titleW then S.titleW = tw end
			end
		end
	else
		S.titleA = Toward(S.titleA, S.titleShown and 1 or 0, 7, dt)
		if S.titleA > 0.997 then S.titleA = 1 end
	end
	-- the flourishes stay up while only the words change, and fade with the name otherwise
	S.frameA = Toward(S.frameA or 0, S.titleWant and 1 or 0, S.titleWant and 7 or 11, dt)
	if S.frameA > 0.997 then S.frameA = 1 end
	if S.titleA < 0.005 and S.frameA < 0.005 and not S.titleShown then
		for i = 1, table.getn(TITLE_PARTS) do Vis(W[TITLE_PARTS[i]], false) end
		return
	end
	local tw = S.titleTarget or 0
	if S.titleW ~= tw or S.titleLaidW ~= S.width then
		S.titleW = Toward(S.titleW or tw, tw, 9, dt)
		if math.abs(S.titleW - tw) < 0.05 then S.titleW = tw end
		S.titleLaidW = S.width
		local cx, w = S.width * 0.5, S.titleW
		W.lineL:ClearAllPoints()
		W.lineL:SetPoint("RIGHT", W.bar, "TOPLEFT", cx - w * 0.5 - 15, 16)
		W.lineR:ClearAllPoints()
		W.lineR:SetPoint("LEFT", W.bar, "TOPLEFT", cx + w * 0.5 + 15, 16)
		W.gemL:ClearAllPoints()
		W.gemL:SetPoint("CENTER", W.bar, "TOPLEFT", cx - w * 0.5 - 10, 16)
		W.gemR:ClearAllPoints()
		W.gemR:SetPoint("CENTER", W.bar, "TOPLEFT", cx + w * 0.5 + 10, 16)
		SetSize(W.titleBg, w + 110, 30)
		SetSize(W.titleHit, w + 30, 20)
	end
	local frame = S.frameA
	Alpha(W.title, S.titleA)
	Alpha(W.titleBg, frame)
	Alpha(W.lineL, frame)
	Alpha(W.lineR, frame)
	Alpha(W.gemL, frame)
	Alpha(W.gemR, frame)
	for i = 1, table.getn(TITLE_PARTS) do Vis(W[TITLE_PARTS[i]], true) end
end

------------------------------------------------------------------------ drawing: particles
local function Rotate(tex, a)
	local c, s = math.cos(a) * 0.5, math.sin(a) * 0.5
	tex:SetTexCoord(0.5 - c - s, 0.5 + s - c, 0.5 - c + s, 0.5 + s + c,
		0.5 + c - s, 0.5 - s - c, 0.5 + c + s, 0.5 - s + c)
end

local function Rand(a, b)
	return a + (b - a) * math.random()
end

local function Spawn(motif, fw, boost)
	local p
	for i = 1, MAX_PARTS do
		if not S.parts[i].on then
			p = S.parts[i]
			break
		end
	end
	if not p then return end
	local src = motif
	local color = S.pal.mc
	if motif.alt and math.random() < motif.alt.chance then
		src = motif.alt
		color = motif.alt.mc
	end
	local where = motif.where
	local x
	if where == "fill" then
		if fw < 8 then return end
		x = Rand(3, fw - 3)
	elseif where == "head" then
		if fw < 4 then return end
		x = Rand(math.max(2, fw - (motif.spread or 30)), fw)
	else
		x = Rand(-8, S.width + 8)
	end
	p.on = true
	p.x, p.y = x, Rand(motif.y0, motif.y1)
	p.vx, p.vy = Rand(motif.vx0, motif.vx1), Rand(motif.vy0, motif.vy1)
	if boost then
		p.vy = p.vy * 1.6 + 6
	end
	p.age, p.life = 0, Rand(motif.life0, motif.life1)
	p.w = Rand(src.w0 or motif.w0, src.w1 or motif.w1)
	p.aspect = (src == motif and motif.aspect) or 1
	p.wob, p.wobf, p.ph = motif.wob or 0, motif.wobf or 1, Rand(0, TWO_PI)
	p.a = motif.a or 1
	p.flicker, p.twinkle = motif.flicker, (src.tex == "Twinkle" and 7) or motif.twinkle
	p.grow = motif.grow or 0
	p.r, p.g, p.b = color[1], color[2], color[3]
	local tex = src.tex or motif.tex
	if p.file ~= tex then
		p.file = tex
		p.tex:SetTexture(ART .. tex)
	end
	local blend = (src == motif and motif.blend) or "ADD"
	if p.blend ~= blend then
		p.blend = blend
		p.tex:SetBlendMode(blend)
	end
	p.spin = motif.spin and Rand(-motif.spin, motif.spin) or nil
	p.rot = (motif.rot or 0) + (p.spin and Rand(0, TWO_PI) or 0)
	if p.spin or p.rot ~= 0 then
		Rotate(p.tex, p.rot)
		p.turned = true
	elseif p.turned then
		p.tex:SetTexCoord(0, 1, 0, 1)
		p.turned = nil
	end
	p.tex:Show()
end

local function StepParticles(dt, fw)
	local on = db.particles and S.alpha > 0.05
	if on then
		local motif = S.motif or MOTIFS.motes
		local rate = motif.rate * (R.stopped and 0.4 or 1)
		S.partAcc = S.partAcc + rate * dt
		local guard = 0
		while S.partAcc >= 1 and guard < 6 do
			S.partAcc = S.partAcc - 1
			guard = guard + 1
			Spawn(motif, fw)
		end
		if S.burstParts and S.burstParts > 0 then
			for i = 1, math.min(S.burstParts, 4) do
				Spawn(motif, fw, true)
			end
			S.burstParts = S.burstParts - 4
		end
	else
		S.partAcc = 0
	end
	for i = 1, MAX_PARTS do
		local p = S.parts[i]
		if p.on then
			p.age = p.age + dt
			if p.age >= p.life or not on then
				p.on = false
				p.tex:Hide()
			else
				p.x = p.x + p.vx * dt
				p.y = p.y + p.vy * dt
				local u = p.age / p.life
				local a = p.a * Smooth(u / 0.18) * Smooth((1 - u) / 0.4)
				if p.flicker then a = a * (0.72 + 0.28 * math.sin(p.ph * 3 + p.age * p.flicker)) end
				if p.twinkle then a = a * (0.55 + 0.45 * math.sin(p.ph + p.age * p.twinkle)) end
				local w = p.w * (1 + p.grow * u)
				SetSize(p.tex, w, w * p.aspect)
				p.tex:SetPoint("CENTER", W.bar, "LEFT", p.x + p.wob * math.sin(p.ph + p.age * p.wobf * TWO_PI), p.y)
				p.tex:SetVertexColor(p.r, p.g, p.b, a)
				if p.spin then Rotate(p.tex, p.rot + p.spin * p.age) end
			end
		end
	end
end

------------------------------------------------------------------------ tooltips
ShowMarkerTip = function(m)
	if not GameTooltip or not m.entry then return end
	local e = m.entry
	GameTooltip:SetOwner(m, "ANCHOR_NONE")
	GameTooltip:ClearAllPoints()
	GameTooltip:SetPoint("TOP", m, "BOTTOM", 0, -6)
	local t = S.pal.title
	if e == ENDLESS_ENTRY then
		GameTooltip:AddLine(L("Endless"), t[1], t[2], t[3])
		if S.endLeft then
			GameTooltip:AddLine(F("Next boss in {1}", Clock(math.ceil(S.endLeft))), 1, 1, 1)
		end
	else
		GameTooltip:AddLine((e.name and e.name ~= "") and e.name or L("Boss"), t[1], t[2], t[3])
		if e.final then
			GameTooltip:AddLine(L("Final boss"), 1, 0.82, 0.3)
		end
		if e.state == "up" then
			local line = L("Up now")
			if e.hp then line = F("Up now: {1}% health", math.floor(e.hp * 100 + 0.5)) end
			if e.enraged then line = line .. " " .. L("(enraged)") end
			GameTooltip:AddLine(line, 1, 0.35, 0.25)
		elseif e.state == "dead" then
			GameTooltip:AddLine(L("Slain"), 0.55, 0.9, 0.55)
		else
			GameTooltip:AddLine(F("Comes at {1}, in {2}", Clock(e.at), Clock(math.ceil(e.at - S.t))), 1, 1, 1)
		end
	end
	CUI.ShowTip()
end

ShowTitleTip = function()
	if not GameTooltip or not R.zname or R.zname == "" then return end
	GameTooltip:SetOwner(W.titleHit, "ANCHOR_NONE")
	GameTooltip:ClearAllPoints()
	GameTooltip:SetPoint("TOP", W.titleHit, "BOTTOM", 0, -40)
	local t = S.pal.title
	GameTooltip:AddLine(R.zname, t[1], t[2], t[3])
	if R.zsub and R.zsub ~= "" then GameTooltip:AddLine(R.zsub, 1, 1, 1) end
	local h = tonumber(R.heroic) or 0
	if h > 0 then
		local c = HEROIC_COLORS[math.min(h, 5)]
		GameTooltip:AddLine(F("Heroic {1}", ROMAN[h] or tostring(h)), c[1], c[2], c[3])
	end
	if R.affixes and R.affixes ~= "" then
		local list, start = {}, 1
		while true do
			local a, b = string.find(R.affixes, ",", start, true)
			local piece = string.sub(R.affixes, start, a and (a - 1) or string.len(R.affixes))
			if piece ~= "" then table.insert(list, L(AFFIX_NAMES[piece] or piece)) end
			if not a then break end
			start = b + 1
		end
		if table.getn(list) > 0 then
			GameTooltip:AddLine(table.concat(list, ", "), 0.85, 0.85, 0.85)
		end
	end
	GameTooltip:AddLine(F("{1}, {2} bosses", Clock(S.len), R.n), 0.7, 0.7, 0.7)
	CUI.ShowTip()
end

------------------------------------------------------------------------ the frame step
local function ResetRun(now)
	S.quietUntil = now + 1.5
	S.t = R.rawT or 0
	S.deadline, S.cycle, S.endLeft = nil, nil, nil
	S.callName, S.callAlpha, S.textX, S.caretX = nil, 0, nil, nil
	S.callSecond, S.callWarm = nil, nil
	for i = 1, table.getn(S.marks) do
		local m = S.marks[i]
		m.snap, m.state, m.burst, m.checkAt = true, nil, nil, nil
	end
	if S.endMark then
		S.endMark.snap, S.endMark.state = true, nil
	end
	S.dataClock = 0
end

local function StepTime(dt, now)
	local raw = R.rawT or 0
	if S.resetNext then
		S.resetNext = nil
		ResetRun(now)
		S.fill, S.fillV = Clamp(raw / (R.len > 0 and R.len or 960), 0, 1), 0
	elseif S.lastRaw and raw < S.lastRaw - 3 then
		ResetRun(now) -- the clock went back: a new run
	end
	S.lastRaw = raw
	if raw >= S.t then
		local gap = raw - S.t
		if gap > 1.5 then
			S.t = S.t + gap * (1 - math.exp(-dt * 6))
		else
			S.t = raw
		end
	elseif S.t - raw > 3 then
		S.t = raw
	end

	S.endless = R.endless and true or false
	if S.endless then
		local nb = R.nb
		if nb and nb >= 0 then
			local deadline = S.t + nb
			if not S.deadline or math.abs(deadline - S.deadline) > 1.5 then
				if S.deadline and deadline > S.deadline + 1.5 then
					S.cycle = math.max(nb, 1) -- a new countdown: a boss just came
					if S.endMark and now >= S.quietUntil then
						local t = S.pal.title
						S.endMark.burst, S.endMark.br, S.endMark.bg, S.endMark.bb = now, t[1], t[2], t[3]
						S.endMark.scaleV = S.endMark.scaleV + 5
					end
				end
				S.deadline = deadline
			elseif deadline < S.deadline then
				S.deadline = deadline
			end
			if not S.cycle or nb > S.cycle then S.cycle = math.max(nb, 1) end
			S.endLeft = math.max(0, S.deadline - S.t)
			S.fillTarget = Clamp(1 - S.endLeft / S.cycle, 0, 1)
		else
			S.endLeft = nil
			S.fillTarget = 1
		end
	else
		S.deadline, S.cycle, S.endLeft = nil, nil, nil
		S.fillTarget = Clamp(S.t / S.len, 0, 1)
	end
end

local function PickTheme()
	local key = db.theme
	if key == "auto" or not THEMES[key] then key = R.zone end
	local theme = key and THEMES[key]
	if not theme then
		theme, key = THEMES.default, "default"
	end
	SetTheme(theme, key)
end

local function Step(dt)
	local now = GetTime()

	-- what to show: the live run, the preview, or a still picture while placing the bar
	if P.on then
		local elapsed = now - P.start
		FillFake(P.zone, 0, now, elapsed)
		if elapsed > PREVIEW_RUN + PREVIEW_FIGHT + 3.5 then StopPreview() end
	else
		ReadLive()
		if R.ok then
			S.dataClock = S.dataClock - dt
			if S.dataClock <= 0 then
				S.dataClock = DATA_EVERY
				local z = AZS_ZONE_UPDATED
				if z ~= S.zoneStamp then
					if S.zoneStamp ~= nil then S.resetNext = true end
					S.zoneStamp = z
				end
				RefreshData(R.rawT)
			end
		elseif not db.locked or optionsOpen then
			local key = PreviewZone()
			local list = FALLBACK[key]
			FillFake(key, list[1] * 0.42, now)
			R.stopped = false
		end
	end
	if R.ok then
		S.len = R.len > 0 and R.len or 960
		StepTime(dt, now)
		if R.phase == "victory" and S.lastPhase ~= "victory" and now >= S.quietUntil then
			S.burstParts = 16
		end
		S.lastPhase = R.phase
	end

	PickTheme()
	if S.palMoving then StepPalette(dt) end

	-- fade in and out, with a small slide
	local want = 0
	if db.enabled and R.ok then
		want = (R.phase == "dead") and 0.5 or 1
	end
	local before = S.alpha
	S.alpha = Toward(S.alpha, want, want > S.alpha and 5 or 4, dt)
	if math.abs(S.alpha - want) < 0.002 then S.alpha = want end
	local root = W.root
	if S.alpha <= 0.001 and want == 0 then
		if root:IsShown() then
			root:Hide()
			if GameTooltip and S.hover then GameTooltip:Hide() end
			S.hover = nil
		end
		return
	end
	if not root:IsShown() then
		root:Show()
		SetLevels()
	end
	root:SetAlpha(Smooth(S.alpha))
	local slide = (1 - Smooth(math.min(1, S.alpha / math.max(want, 0.5)))) * 10
	if not S.dragging and (math.abs(slide - S.slide) > 0.01 or before ~= S.alpha) then
		S.slide = slide
		ApplyPosition()
	end

	LayoutTicks()
	local fw = StepFill(dt, now)
	StepMarkers(dt, now)
	StepCallout(dt, now)
	StepText(now, dt)
	StepParticles(dt, fw)
	if S.hover and now >= S.hoverNext then
		S.hoverNext = now + 0.25
		ShowMarkerTip(S.hover)
	end
end

------------------------------------------------------------------------ options
local options
local RefreshOptions

local function OptText(parent, size, r, g, b)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	CUI.SetFace(fs, FONT, size)
	fs:SetTextColor(r, g, b)
	fs:SetShadowColor(0, 0, 0, 1)
	fs:SetShadowOffset(1, -1)
	return fs
end

local function OptFill(parent, layer, r, g, b, a)
	local t = parent:CreateTexture(nil, layer)
	t:SetTexture(FLAT)
	t:SetVertexColor(r, g, b, a)
	return t
end

local function PaintButton(button)
	if button.selected then
		button:SetBackdropColor(0.50, 0.38, 0.07, 1)
		button:SetBackdropBorderColor(1, 0.82, 0.25, 1)
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
	SetSize(button, width, height)
	button:EnableMouse(true)
	button:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	button.text = OptText(button, 11, 1, 1, 1)
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

local function MakeCheck(parent, y, label, key, after)
	local check = CreateFrame("Button", nil, parent)
	SetSize(check, 272, 20)
	check:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, y)
	check:EnableMouse(true)
	check.edge = OptFill(check, "BORDER", 0.38, 0.38, 0.42, 1)
	SetSize(check.edge, 14, 14)
	check.edge:SetPoint("LEFT", check, "LEFT", 0, 0)
	check.box = OptFill(check, "ARTWORK", 0.06, 0.06, 0.08, 1)
	check.box:SetPoint("TOPLEFT", check.edge, "TOPLEFT", 1, -1)
	check.box:SetPoint("BOTTOMRIGHT", check.edge, "BOTTOMRIGHT", -1, 1)
	check.mark = OptFill(check, "OVERLAY", 1, 0.82, 0.25, 1)
	check.mark:SetPoint("TOPLEFT", check.edge, "TOPLEFT", 3, -3)
	check.mark:SetPoint("BOTTOMRIGHT", check.edge, "BOTTOMRIGHT", -3, 3)
	check.label = OptText(check, 11, 0.92, 0.92, 0.92)
	check.label:SetPoint("LEFT", check.edge, "RIGHT", 8, 0)
	CUI.LText(check.label, label)
	check.key = key
	check:SetScript("OnEnter", function()
		check.label:SetTextColor(1, 0.85, 0.35)
	end)
	check:SetScript("OnLeave", function()
		check.label:SetTextColor(0.92, 0.92, 0.92)
	end)
	check:SetScript("OnClick", function()
		db[key] = not db[key]
		if after then after() end
		RefreshOptions()
	end)
	return check
end

local THEME_CHOICES = { "auto" }
for i = 1, table.getn(ZONE_ORDER) do
	table.insert(THEME_CHOICES, ZONE_ORDER[i])
end

local function ThemeLabel(key)
	if key == "auto" then return L("Auto (matches the map)") end
	return THEMES[key] and L(THEMES[key].name) or key
end

local function SetEnabled(on)
	db.enabled = on and true or false
	if db.enabled then
		S.broken = false
		TakeClock()
	else
		ReleaseClock()
	end
	if RefreshOptions then RefreshOptions() end
end

local function CycleTheme(step)
	local index = 1
	for i = 1, table.getn(THEME_CHOICES) do
		if THEME_CHOICES[i] == db.theme then index = i end
	end
	index = index + step
	if index < 1 then index = table.getn(THEME_CHOICES) end
	if index > table.getn(THEME_CHOICES) then index = 1 end
	db.theme = THEME_CHOICES[index]
	S.callBuilt, S.titleKey = nil, nil
end

local function SetScale(v)
	db.scale = Clamp(math.floor(v * 20 + 0.5) / 20, 0.6, 1.6)
	ApplyPosition()
end

local function SetWidth(v)
	db.width = Clamp(math.floor(v / 10 + 0.5) * 10, 300, 760)
	Layout()
end

RefreshOptions = function()
	if not options or not db then return end
	local o = options
	o.toggle.selected = db.enabled
	if db.enabled then
		o.toggle.text:SetText(L("ON: replaces the game's boss timer"))
	else
		o.toggle.text:SetText(L("OFF: the game's own timer"))
	end
	PaintButton(o.toggle)
	o.themeText:SetText(ThemeLabel(db.theme))
	o.sizeText:SetText(string.format("%d%%", math.floor(db.scale * 100 + 0.5)))
	o.widthText:SetText(tostring(db.width))
	for i = 1, table.getn(o.checks) do
		local check = o.checks[i]
		if db[check.key] then check.mark:Show() else check.mark:Hide() end
	end
	if P.on then o.preview.text:SetText(L("Stop preview")) else o.preview.text:SetText(L("Preview")) end
end

local function BuildOptions()
	local o = CreateFrame("Frame", "CreedUITimerOptions", UIParent)
	options = o
	SetSize(o, 300, 420)
	o:SetPoint("CENTER", UIParent, "CENTER", 0, -40)
	if CUI.AboveHub then CUI.AboveHub(o) else o:SetFrameStrata("DIALOG") end
	o:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	o:SetBackdropColor(0.05, 0.05, 0.07, 0.96)
	o:SetBackdropBorderColor(0, 0, 0, 1)
	o:EnableMouse(true)
	o:SetMovable(true)
	o:SetClampedToScreen(true)
	o:RegisterForDrag("LeftButton")
	o:SetScript("OnDragStart", function() o:StartMoving() end)
	o:SetScript("OnDragStop", function() o:StopMovingOrSizing() end)
	o:SetScript("OnShow", function() optionsOpen = true end)
	o:SetScript("OnHide", function() optionsOpen = false end)
	o:Hide()
	if type(UISpecialFrames) == "table" then
		table.insert(UISpecialFrames, "CreedUITimerOptions") -- Escape closes it
	end

	local title = OptText(o, 16, 1, 0.82, 0.25)
	title:SetPoint("TOPLEFT", o, "TOPLEFT", 14, -14)
	title:SetText("Smooth Boss Timer")
	local version = OptText(o, 10, 0.55, 0.55, 0.6)
	version:SetPoint("LEFT", title, "RIGHT", 8, -1)
	version:SetText("v" .. VERSION)
	local close = MakeButton(o, 22, 22, "x", function() o:Hide() end)
	close:SetPoint("TOPRIGHT", o, "TOPRIGHT", -10, -10)

	o.toggle = MakeButton(o, 272, 28, "", function() SetEnabled(not db.enabled) end)
	o.toggle:SetPoint("TOPLEFT", o, "TOPLEFT", 14, -46)

	local function Row(y, label, onLess, onMore)
		local head = OptText(o, 12, 0.85, 0.85, 0.9)
		head:SetPoint("TOPLEFT", o, "TOPLEFT", 14, y - 4)
		CUI.LText(head, label)
		local less = MakeButton(o, 26, 22, "<", onLess)
		less:SetPoint("TOPLEFT", o, "TOPLEFT", 84, y)
		local value = OptText(o, 11, 1, 1, 1)
		value:SetPoint("LEFT", less, "RIGHT", 0, 0)
		value:SetWidth(150)
		value:SetJustifyH("CENTER")
		local more = MakeButton(o, 26, 22, ">", onMore)
		more:SetPoint("LEFT", less, "RIGHT", 150, 0)
		return value
	end
	o.themeText = Row(-88, "Theme", function()
		CycleTheme(-1)
		RefreshOptions()
	end, function()
		CycleTheme(1)
		RefreshOptions()
	end)
	o.sizeText = Row(-118, "Size", function()
		SetScale(db.scale - 0.05)
		RefreshOptions()
	end, function()
		SetScale(db.scale + 0.05)
		RefreshOptions()
	end)
	o.widthText = Row(-148, "Width", function()
		SetWidth(db.width - 20)
		RefreshOptions()
	end, function()
		SetWidth(db.width + 20)
		RefreshOptions()
	end)

	local divider = OptFill(o, "ARTWORK", 1, 1, 1, 0.08)
	divider:SetPoint("TOPLEFT", o, "TOPLEFT", 14, -182)
	SetSize(divider, 272, 1)

	o.checks = {
		MakeCheck(o, -192, "Zone name above the bar", "title", function() S.titleKey = nil end),
		MakeCheck(o, -216, "Next boss and countdown under the bar", "callout"),
		MakeCheck(o, -240, "Minute marks", "ticks"),
		MakeCheck(o, -264, "Particles (snow, embers, leaves...)", "particles"),
		MakeCheck(o, -288, "Flowing light in the bar", "flow"),
		MakeCheck(o, -312, "Lock position (unlock to drag the bar)", "locked", ApplyLock),
	}

	local note = OptText(o, 10, 0.6, 0.6, 0.65)
	note:SetPoint("TOPLEFT", o, "TOPLEFT", 14, -340)
	note:SetWidth(272)
	note:SetJustifyH("LEFT")
	CUI.LText(note, "Hover a gem for that boss's name and time.")

	o.preview = MakeButton(o, 132, 26, "Preview", function()
		if P.on then StopPreview() else StartPreview() end
		RefreshOptions()
	end)
	o.preview:SetPoint("TOPLEFT", o, "TOPLEFT", 14, -374)
	local reset = MakeButton(o, 132, 26, "Reset position", function()
		db.x, db.y, db.scale = DEFAULTS.x, DEFAULTS.y, DEFAULTS.scale
		SetWidth(DEFAULTS.width)
		RefreshOptions()
	end)
	reset:SetPoint("TOPLEFT", o, "TOPLEFT", 154, -374)
	CUI.LText(reset.text, "Reset position")
	CUI.OnLanguage(function() if o:IsShown() then RefreshOptions() end end)
end

local function ToggleOptions()
	if not options then BuildOptions() end
	if options:IsShown() then
		options:Hide()
	else
		if CUI.AboveHub then CUI.AboveHub(options) end
		RefreshOptions()
		options:Show()
	end
end

------------------------------------------------------------------------ slash command
local function Slash(msg)
	if not db then return end
	msg = string.lower(msg or "")
	local _, _, cmd, rest = string.find(msg, "^%s*(%S*)%s*(.-)%s*$")
	cmd = cmd or ""
	if cmd == "" or cmd == "options" or cmd == "config" then
		ToggleOptions()
	elseif cmd == "on" or cmd == "enable" then
		SetEnabled(true)
		Print(L("on. The game's own timer is hidden."))
	elseif cmd == "off" or cmd == "disable" then
		SetEnabled(false)
		Print(L("off. The game's own timer is back."))
	elseif cmd == "lock" then
		db.locked = true
		ApplyLock()
		Print(L("position locked."))
	elseif cmd == "unlock" or cmd == "move" then
		db.locked = false
		ApplyLock()
		Print(L("drag the bar to move it, then type /creed timer lock."))
	elseif cmd == "preview" or cmd == "test" then
		if P.on and rest == "" then
			StopPreview()
		else
			local key = rest ~= "" and rest or nil
			if key and not FALLBACK[key] then
				Print(L("zones: ") .. table.concat(ZONE_ORDER, ", "))
				key = nil
			end
			StartPreview(key)
		end
	elseif cmd == "theme" then
		if rest == "auto" or THEMES[rest] then
			db.theme = rest
			Print(L("theme: ") .. ThemeLabel(rest))
		else
			Print(L("themes: ") .. "auto, " .. table.concat(ZONE_ORDER, ", "))
		end
	elseif cmd == "scale" or cmd == "size" then
		local v = tonumber(rest)
		if v then
			if v > 5 then v = v / 100 end
			SetScale(v)
		end
		Print(F("size {1}%", math.floor(db.scale * 100 + 0.5)))
	elseif cmd == "width" then
		local v = tonumber(rest)
		if v then SetWidth(v) end
		Print(F("width {1}", db.width))
	elseif cmd == "reset" then
		db.x, db.y, db.scale = DEFAULTS.x, DEFAULTS.y, DEFAULTS.scale
		SetWidth(DEFAULTS.width)
		Print(L("position, size and width reset."))
	else
		Print(L("/creed timer (options), on, off, lock, unlock, preview [zone], theme <zone|auto>, scale <50-160>, width <300-760>, reset"))
	end
	if RefreshOptions then RefreshOptions() end
end

CUI.timerSlash = Slash
CUI.timerOptions = function()
	if db then ToggleOptions() end
end
SLASH_CREEDUITIMER1 = "/sbt"
SlashCmdList["CREEDUITIMER"] = Slash

------------------------------------------------------------------------ start up
local function InitDB()
	db = CUI.DB("timer", DEFAULTS)
	db.scale = Clamp(tonumber(db.scale) or 1, 0.6, 1.6)
	db.width = Clamp(math.floor(tonumber(db.width) or 440), 300, 760)
	db.x = tonumber(db.x) or DEFAULTS.x
	db.y = tonumber(db.y) or DEFAULTS.y
	if db.theme ~= "auto" and not THEMES[db.theme] then db.theme = "auto" end
end

CUI.RegisterPart({
	key = "timer", name = "Boss timer",
	note = "The themed bar with every boss, a countdown to the next one, and their health while up. Replaces the game's run clock.",
	get = function() return db and db.enabled and not S.broken end,
	set = function(on) if db and not CUI.OldAddon("SmoothBossTimer") then SetEnabled(on) end end,
	getScale = function() return db and db.scale or 1 end,
	setScale = function(v) if db then SetScale(v) end end,
})
CUI.timerLock = function(locked)
	if not db or not W.root then return end
	db.locked = locked and true or false
	ApplyLock()
end
CUI.timerReset = function()
	if not db or not W.root then return end
	db.x, db.y, db.scale = DEFAULTS.x, DEFAULTS.y, DEFAULTS.scale
	SetWidth(DEFAULTS.width)
end

local driver = CreateFrame("Frame", "CreedUITimerDriver")
local ready = false

local function Start()
	if ready then return end
	ready = true
	InitDB()
	if CUI.OldAddon("SmoothBossTimer") then
		S.broken = true -- the old addon draws the timer; Creed UI stays out of its way
		return
	end
	BuildBar()
	CUI.timerRoot = W.root
	CUI.THEMES = THEMES
	SetTheme(THEMES.default, "default", true)
	ApplyPalette()
	Layout()
	ApplyLock()
	SetLevels()
	if db.enabled then TakeClock() end
end

driver:RegisterEvent("ADDON_LOADED")
driver:RegisterEvent("VARIABLES_LOADED")
driver:RegisterEvent("PLAYER_ENTERING_WORLD")
driver:RegisterEvent("PLAYER_LOGOUT")
driver:SetScript("OnEvent", function()
	if event == "ADDON_LOADED" then
		return -- Start waits for VARIABLES_LOADED, when every addon has loaded
	elseif event == "VARIABLES_LOADED" then
		Start()
	elseif event == "PLAYER_ENTERING_WORLD" then
		Start()
		if S.broken then return end
		if db.enabled then TakeClock() end
		if type(AZS_SetOnTopOfScreens) == "function" then
			pcall(AZS_SetOnTopOfScreens, W.root, true)
			pcall(AZS_SetOnTopOfScreens, "GameTooltip", true)
		end
		S.resetNext = true
	elseif event == "PLAYER_LOGOUT" then
		-- leave the game's own setting as it was; it's hidden again next time
		if db then ReleaseClock() end
	end
end)

driver:SetScript("OnUpdate", function()
	if not ready or S.broken then return end
	local dt = arg1 or 0
	if dt < 0 then dt = 0 elseif dt > 0.1 then dt = 0.1 end
	local ok, err = pcall(Step, dt)
	if ok then
		-- keep the game's clock hidden while this one replaces it
		S.clockCheck = S.clockCheck - dt
		if S.clockCheck <= 0 then
			S.clockCheck = 2
			if db.enabled then TakeClock() end
		end
		return
	end
	local now = GetTime()
	if now - S.errorAt > 10 then S.errors = 0 end
	S.errorAt = now
	S.errors = S.errors + 1
	if S.errors == 1 then Print(L("error: ") .. tostring(err)) end
	if S.errors >= 5 then
		S.broken = true
		ReleaseClock()
		if W.root then W.root:Hide() end
		Print(L("stopped after repeated errors, so the game's own timer is back. Type /reload to try again."))
	end
end)
