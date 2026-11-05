-- Creed UI: the caches and the guardians' lairs on the minimap. Every cache waiting on the field
-- (the game's AZS_CHESTS) is a gold chest on the minimap where it lies, or on the rim, pointing
-- the way, while it lies beyond the map's reach. A new one rings as it drops, and they glow while
-- your gold pays for the next one. Hover one for its price and how far it is.
-- Every guardian's lair (AZS_LAIRS) is a skull token: bronze while its guardian sleeps in it, red
-- and throbbing while it fights, grey once empty, with the time until the next guardian comes
-- under it. The one the game would flag (the nearest held, else the next to fill) rings slowly;
-- the game's own red flag is hidden while the lairs are on.

local C = CreedUI
local DEFAULTS = { enabled = true }
local LAIR_DEFAULTS = { enabled = true }
-- yards across the minimap at zoom 0 to 5, as the client draws it: outdoors 14 down to 4 chunks
-- of 33.33 yards; indoors (a building, most of an instance) closer, with a zoom of its own
local OUTDOOR = { [0] = 466.67, [1] = 400, [2] = 333.33, [3] = 266.67, [4] = 200, [5] = 133.33 }
local INDOOR = { [0] = 300, [1] = 240, [2] = 180, [3] = 120, [4] = 80, [5] = 50 }
local SIZE, EDGE_SIZE, INSET, MAX_PINS = 15, 12, 7, 24
local PING, PINGS = 0.9, 2 -- a new cache rings twice, 0.9 s each
local SHOWN = { playing = true, paused = true } -- not under the level-up cards' veil

local db
local W = { pins = {} }
local S = { seen = {}, ping = {}, primed = false, playing = 0, zoneStamp = false, listStamp = false,
	probe = {}, probedAt = -10, hx = nil, hy = nil }

local Call = C.Call -- no stray nil arguments (see Core)

------------------------------------------------------------------------ where you are
-- Your place in the world in yards (+x north, +y west) and the coordinate space a cache must
-- share: from the client each frame where it tells it, else from the run's packets (about twice
-- a second while running), eased so the pins glide rather than step.
local function Hero(dt)
	if type(AZS_GetPlayerPosition) == "function" then
		local ok, p = pcall(AZS_GetPlayerPosition)
		if ok and type(p) == "table" and type(p.x) == "number" and type(p.y) == "number" then
			S.hx, S.hy = p.x, p.y
			return p.x, p.y, p.spaceId
		end
	end
	local run = AZS_RUN
	if type(run) ~= "table" or type(run.px) ~= "number" or type(run.py) ~= "number" then return nil end
	if not S.hx or math.abs(run.px - S.hx) + math.abs(run.py - S.hy) > 40 then
		S.hx, S.hy = run.px, run.py
	else
		local k = 1 - math.exp(-12 * dt)
		S.hx, S.hy = S.hx + (run.px - S.hx) * k, S.hy + (run.py - S.hy) * k
	end
	return S.hx, S.hy, nil
end

------------------------------------------------------------------------ the minimap's reach
local function Setting(name)
	if type(GetCVar) ~= "function" then return nil end
	local ok, v = pcall(GetCVar, name)
	if ok then return tonumber(v) end
	return nil
end

-- Indoors or out, as the minimap draws: it keeps a zoom setting for each, so while the two differ
-- its zoom tells. While they match, a step of the zoom and back shows which one moves; the
-- answer holds until you go in or out.
local function Indoors(zoom)
	local out, ins = Setting("minimapZoom"), Setting("minimapInsideZoom")
	if out and ins and out ~= ins then return zoom == ins end
	local p = S.probe
	if p.zoom == zoom then return p.indoors end
	p.zoom, p.indoors = zoom, false
	local m = Minimap
	if not (out and ins) or type(m.SetZoom) ~= "function" then return false end
	local top = (type(m.GetZoomLevels) == "function" and m:GetZoomLevels() or 6) - 1
	local step = zoom + 1
	if step > top then step = zoom - 1 end
	S.probedAt = GetTime()
	m:SetZoom(step)
	local movedIn, movedOut = Setting("minimapInsideZoom") == step, Setting("minimapZoom") == step
	m:SetZoom(zoom)
	if type(SetCVar) == "function" then
		if Setting("minimapZoom") ~= out then pcall(SetCVar, "minimapZoom", out) end
		if Setting("minimapInsideZoom") ~= ins then pcall(SetCVar, "minimapInsideZoom", ins) end
	end
	p.indoors = movedIn and not movedOut
	return p.indoors
end

local function Across()
	if not W.zooms then return OUTDOOR[3] end
	local zoom = Minimap:GetZoom() or 0
	local t = OUTDOOR
	if Indoors(zoom) then t = INDOOR end
	return t[zoom] or t[0]
end

------------------------------------------------------------------------ the pins
local function Tip()
	if not GameTooltip then return end
	GameTooltip:SetOwner(this, "ANCHOR_LEFT")
	GameTooltip:SetText(C.L("Cache"), 0.98, 0.85, 0.52)
	local run = type(AZS_RUN) == "table" and AZS_RUN or {}
	local price, gold = tonumber(run.chest), tonumber(run.gold)
	if price then
		local line = gold and C.F("Opens for {1} gold (you have {2})", C.Commas(price), C.Commas(gold))
			or C.F("Opens for {1} gold", C.Commas(price))
		if gold and gold >= price then
			GameTooltip:AddLine(line, 0.55, 0.92, 0.45)
		else
			GameTooltip:AddLine(line, 1, 0.5, 0.38)
		end
	end
	if this.yards then
		GameTooltip:AddLine(C.F("{1} yards away", math.floor(this.yards + 0.5)), 0.75, 0.75, 0.75)
	end
	C.ShowTip()
end

local function NewPin(i)
	local p = CreateFrame("Frame", nil, W.layer)
	p:SetWidth(SIZE)
	p:SetHeight(SIZE)
	p.glow = C.Tex(p, "BACKGROUND", C.ART .. "Glow", "ADD")
	p.glow:SetPoint("CENTER", p, "CENTER", 0, 0)
	p.glow:SetVertexColor(1, 0.72, 0.2, 0.55)
	p.ring = C.Tex(p, "BORDER", C.ART .. "Ring", "ADD")
	p.ring:SetPoint("CENTER", p, "CENTER", 0, 0)
	p.ring:SetVertexColor(0.95, 0.79, 0.44)
	p.icon = C.Tex(p, "ARTWORK", C.ART .. "Chest")
	p.icon:SetAllPoints(p)
	p.icon:SetVertexColor(0.95, 0.79, 0.44)
	C.Vis(p.glow, false)
	C.Vis(p.ring, false)
	p:EnableMouse(true)
	p:SetScript("OnEnter", Tip)
	p:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
	C.Vis(p, false)
	W.pins[i] = p
	return p
end

local function HideFrom(first)
	for i = first, table.getn(W.pins) do C.Vis(W.pins[i], false) end
end

-- A pin over the middle of the map would hide the game's arrow (you): there it fades to a ghost.
local CLEAR_NEAR, CLEAR_FAR, CLEAR_ALPHA = 5, 14, 0.22
local function Clear(d)
	if d >= CLEAR_FAR then return 1 end
	return CLEAR_ALPHA + (1 - CLEAR_ALPHA) * C.Smooth((d - CLEAR_NEAR) / (CLEAR_FAR - CLEAR_NEAR))
end

-- a pin at its cache, or on the rim toward it; it glows while your gold pays, and rings as it drops
local function Place(p, c, hx, hy, ppy, reach, pays, now)
	local east, north = hy - c.y, c.x - hx
	p.yards = math.sqrt(east * east + north * north)
	local ox, oy, d = east * ppy, north * ppy, p.yards * ppy
	local size, alpha = SIZE, 1
	if d > reach then
		ox, oy = ox * reach / d, oy * reach / d
		size, alpha = EDGE_SIZE, 0.82
	end
	C.Place(p, "CENTER", W.layer, "CENTER", math.floor(ox * 10 + 0.5) / 10, math.floor(oy * 10 + 0.5) / 10)
	C.Size(p, size, size)
	C.Alpha(p, alpha * Clear(d))
	if pays then
		C.Size(p.glow, size * 2.4, size * 2.4)
		C.Vis(p.glow, true)
	else
		C.Vis(p.glow, false)
	end
	local t0 = c.id and S.ping[c.id]
	local age = t0 and now - t0
	if age and age >= 0 and age < PING * PINGS then
		local k = math.mod(age, PING) / PING
		C.Size(p.ring, size * (1 + 2.6 * k), size * (1 + 2.6 * k))
		C.Alpha(p.ring, 0.95 * (1 - k))
		C.Vis(p.ring, true)
	else
		C.Vis(p.ring, false)
	end
	C.Vis(p, true)
end

------------------------------------------------------------------------ the lairs
local LAIR_SIZE, LAIR_EDGE, MAX_LAIRS, FLAG_RING = 17, 13, 12, 2.2
local LAIR_LOOK = {
	asleep = { base = { 0.95, 0.66, 0.34 }, icon = { 1, 0.93, 0.82 }, alpha = 1 },
	awake = { base = { 1, 0.3, 0.22 }, icon = { 1, 0.62, 0.52 }, alpha = 1 },
	empty = { base = { 0.52, 0.52, 0.56 }, icon = { 0.72, 0.72, 0.74 }, alpha = 0.75 },
}
local ldb
local L = { pins = {}, ref = nil, stamp = false, since = 0, tip = nil }

-- seconds until an empty lair fills, from the last list, counted down while the run's clock runs
-- (it stops for the cards and pauses, as the game's own count does); nil when it doesn't say
local function LairLeft(c)
	local left = tonumber(c.left)
	if c.state ~= "empty" or not left or left < 0 then return nil end
	return math.max(0, left - L.since)
end

local function LairTip()
	local p = L.tip
	local c = p and p.lair
	if not (c and GameTooltip) then return end
	GameTooltip:SetOwner(p, "ANCHOR_LEFT")
	local name = type(c.name) == "string" and c.name ~= "" and c.name or C.L("Guardian")
	if c.state == "awake" then
		GameTooltip:SetText(name, 1, 0.42, 0.32)
		GameTooltip:AddLine(C.L("Awake and fighting"), 1, 0.6, 0.5)
	elseif c.state == "asleep" then
		GameTooltip:SetText(name, 1, 0.78, 0.5)
		GameTooltip:AddLine(C.L("Asleep in its lair: it wakes when you come near"), 0.85, 0.85, 0.85)
	else
		GameTooltip:SetText(C.L("Empty lair"), 0.75, 0.75, 0.78)
		local left = LairLeft(c)
		if left and left > 0.5 then
			GameTooltip:AddLine(C.F("{1} comes in {2}", name, C.Clock(math.ceil(left))), 0.98, 0.85, 0.52)
		elseif left then
			GameTooltip:AddLine(C.F("{1} comes any moment", name), 0.98, 0.85, 0.52)
		end
	end
	if tonumber(c.flag) == 1 then
		GameTooltip:AddLine(C.L("The one to head for: the nearest held, else the next to fill"), 0.7, 0.7, 0.7, 1)
	end
	if p.yards then GameTooltip:AddLine(C.F("{1} yards away", math.floor(p.yards + 0.5)), 0.75, 0.75, 0.75) end
	C.ShowTip()
end

local function NewLairPin(i)
	local p = CreateFrame("Frame", nil, W.layer)
	p:SetWidth(LAIR_SIZE)
	p:SetHeight(LAIR_SIZE)
	p.glow = C.Tex(p, "BACKGROUND", C.ART .. "Glow", "ADD")
	p.glow:SetPoint("CENTER", p, "CENTER", 0, 0)
	p.ring = C.Tex(p, "BORDER", C.ART .. "Ring", "ADD")
	p.ring:SetPoint("CENTER", p, "CENTER", 0, 0)
	p.base = C.Tex(p, "ARTWORK", C.ART .. "Badge")
	p.base:SetAllPoints(p)
	p.icon = C.Tex(p, "OVERLAY", C.ART .. "Skull")
	p.icon:SetPoint("CENTER", p, "CENTER", 0, 0)
	p.time = C.Text(p, C.FONT, 9, "OUTLINE", "CENTER", 40)
	p.time:SetTextColor(0.98, 0.85, 0.52)
	C.Vis(p.glow, false)
	C.Vis(p.ring, false)
	C.Vis(p.time, false)
	p:EnableMouse(true)
	p:SetScript("OnEnter", function()
		L.tip = this
		LairTip()
	end)
	p:SetScript("OnLeave", function()
		if L.tip == this then L.tip = nil end
		if GameTooltip then GameTooltip:Hide() end
	end)
	C.Vis(p, false)
	L.pins[i] = p
	return p
end

local function HideLairs(first)
	for i = first, table.getn(L.pins) do C.Vis(L.pins[i], false) end
end

-- the list: the game's table, or (an older game) its function, asked once a second
local function LairList(dt)
	if type(AZS_LAIRS) == "table" then return AZS_LAIRS end
	if type(AZS_GetLairs) ~= "function" then return nil end
	L.pollClock = (L.pollClock or 0) - dt
	if L.pollClock <= 0 then
		L.pollClock = 1
		local ok, list = pcall(AZS_GetLairs)
		L.polled = ok and type(list) == "table" and list or nil
	end
	return L.polled
end

-- a token at its lair, or on the rim toward it: its look by its state, its count under it
local function PlaceLair(p, c, hx, hy, ppy, reach, now)
	p.lair = c
	local east, north = hy - c.y, c.x - hx
	p.yards = math.sqrt(east * east + north * north)
	local ox, oy, d = east * ppy, north * ppy, p.yards * ppy
	local size, edge = LAIR_SIZE, false
	if d > reach then
		ox, oy = ox * reach / d, oy * reach / d
		size, edge = LAIR_EDGE, true
	end
	C.Place(p, "CENTER", W.layer, "CENTER", math.floor(ox * 10 + 0.5) / 10, math.floor(oy * 10 + 0.5) / 10)
	C.Size(p, size, size)
	C.Size(p.icon, size * 0.62, size * 0.62)
	local look = LAIR_LOOK[c.state] or LAIR_LOOK.empty
	C.Color(p.base, look.base[1], look.base[2], look.base[3], 1)
	C.Color(p.icon, look.icon[1], look.icon[2], look.icon[3], 1)
	C.Alpha(p, look.alpha * (edge and 0.85 or 1) * Clear(d))
	-- awake: a red throb
	if c.state == "awake" then
		C.Size(p.glow, size * 2.6, size * 2.6)
		C.Color(p.glow, 1, 0.22, 0.12, 0.4 + 0.25 * math.sin(now * 6))
		C.Vis(p.glow, true)
	else
		C.Vis(p.glow, false)
	end
	-- the flagged one rings slowly
	if tonumber(c.flag) == 1 then
		local k = math.mod(now, FLAG_RING) / FLAG_RING
		C.Size(p.ring, size * (1.1 + 1.6 * k), size * (1.1 + 1.6 * k))
		local col = look.base
		C.Color(p.ring, col[1], col[2], col[3], 0.75 * (1 - k))
		C.Vis(p.ring, true)
	else
		C.Vis(p.ring, false)
	end
	-- an empty one counts down to its next guardian, under it (over it, low on the map)
	local left = LairLeft(c)
	if left then
		C.SetText(p.time, left > 0.5 and C.Clock(math.ceil(left)) or C.L("soon"))
		if oy < -reach * 0.55 then
			C.Place(p.time, "BOTTOM", p, "TOP", 0, 0)
		else
			C.Place(p.time, "TOP", p, "BOTTOM", 0, 0)
		end
		C.Vis(p.time, true)
	else
		C.Vis(p.time, false)
	end
	C.Vis(p, true)
end

local function StepLairs(list, dt, phase, hx, hy, space, ppy, reach, now)
	-- the count from the last list goes on only while the run's clock does
	local stamp = AZS_LAIRS_UPDATED or 0
	if list ~= L.ref or stamp ~= L.stamp then
		L.ref, L.stamp, L.since = list, stamp, 0
	elseif phase == "playing" then
		L.since = L.since + dt
	end
	local n = 0
	if hx and type(list) == "table" then
		for i = 1, table.getn(list) do
			local c = list[i]
			if n < MAX_LAIRS and type(c) == "table" and type(c.x) == "number" and type(c.y) == "number"
				and (not space or not c.spaceId or c.spaceId == space) then
				n = n + 1
				PlaceLair(L.pins[n] or NewLairPin(n), c, hx, hy, ppy, reach, now)
			end
		end
	end
	HideLairs(n + 1)
	if L.tip then
		L.tipClock = (L.tipClock or 0) - dt
		if L.tipClock <= 0 then
			L.tipClock = 0.25
			if L.tip:IsVisible() then LairTip() end
		end
	end
end

------------------------------------------------------------------------ every frame
-- which caches are new: the ones already there as a run starts (or after a /reload) don't ring
local function Notice(list, now, dt, phase)
	local stamp = AZS_ZONE_UPDATED or 0
	if stamp ~= S.zoneStamp or phase == "ready" then
		S.zoneStamp = stamp
		S.seen, S.ping, S.primed, S.playing, S.listStamp, S.listRef = {}, {}, false, 0, false, nil
	end
	if phase == "playing" then S.playing = S.playing + dt end
	local listStamp = AZS_CHESTS_UPDATED or 0
	if S.primed and listStamp == S.listStamp and list == S.listRef then return end
	local n = type(list) == "table" and table.getn(list) or 0
	if not S.primed and n == 0 and S.playing < 3 then return end
	S.listStamp, S.listRef = listStamp, list
	for i = 1, n do
		local id = type(list[i]) == "table" and list[i].id
		if id and not S.seen[id] then
			S.seen[id] = true
			if S.primed then S.ping[id] = now end
		end
	end
	S.primed = true
end

-- the game's red flag stays hidden while the lairs are on (looked at now and then: a run's start
-- can bring it back)
local function Flag(dt)
	S.flagClock = (S.flagClock or 0) - dt
	if S.flagClock > 0 then return end
	S.flagClock = 2
	if ldb.enabled then C.TakeHud("flag") else C.ReleaseHud("flag") end
end

local function Step(dt)
	local now = GetTime()
	local phase = Call(AZS_GetPhase)
	local list = AZS_CHESTS
	Notice(list, now, dt, phase)
	Flag(dt)
	local lairs = ldb.enabled and LairList(dt) or nil
	local chests = db.enabled and type(list) == "table" and table.getn(list) > 0
	local held = type(lairs) == "table" and table.getn(lairs) > 0
	if not ((chests or held) and SHOWN[phase] and type(Minimap) == "table" and Minimap:IsVisible()) then
		HideFrom(1)
		StepLairs(lairs, dt, phase, nil)
		return
	end
	local hx, hy, space = Hero(dt)
	if not hx then
		HideFrom(1)
		StepLairs(lairs, dt, phase, nil)
		return
	end
	-- the minimap's size, looked at now and then: it hardly ever changes
	S.sizeClock = (S.sizeClock or 0) - dt
	if S.sizeClock <= 0 or not S.size then
		S.sizeClock = 0.5
		S.size = Minimap:GetWidth() or 140
		if S.size < 40 then S.size = 140 end
	end
	local size = S.size
	local ppy = size / Across()
	local run = type(AZS_RUN) == "table" and AZS_RUN or {}
	local price, gold = tonumber(run.chest), tonumber(run.gold)
	local pays = price and gold and gold >= price
	local n = 0
	if chests then
		for i = 1, table.getn(list) do
			local c = list[i]
			if n < MAX_PINS and type(c) == "table" and type(c.x) == "number" and type(c.y) == "number"
				and (not space or not c.spaceId or c.spaceId == space) then
				n = n + 1
				Place(W.pins[n] or NewPin(n), c, hx, hy, ppy, size / 2 - INSET, pays, now)
			end
		end
	end
	HideFrom(n + 1)
	StepLairs(lairs, dt, phase, hx, hy, space, ppy, size / 2 - INSET, now)
end

------------------------------------------------------------------------ on and off
local function Build()
	if W.layer or type(Minimap) ~= "table" then return end
	W.layer = CreateFrame("Frame", "CreedUIChests", Minimap)
	W.layer:SetAllPoints(Minimap)
	W.zooms = type(Minimap.GetZoom) == "function"
end

local function Levels()
	if not W.layer then return end
	-- over the map and its own marks, under the ring (Minimap.lua sits at +6)
	W.layer:SetFrameLevel(Minimap:GetFrameLevel() + 4)
end

local function ForgetIndoors()
	S.probe = {}
end

C.OnInit(function()
	db = C.DB("chests", DEFAULTS)
	ldb = C.DB("lairs", LAIR_DEFAULTS)
	Build()
	local driver = CreateFrame("Frame", "CreedUIChestsDriver")
	for _, e in ipairs({ "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "MINIMAP_UPDATE_ZOOM" }) do
		driver:RegisterEvent(e)
	end
	driver:SetScript("OnEvent", function()
		-- a step of our own to tell indoors from out sends a zoom event too
		if event == "MINIMAP_UPDATE_ZOOM" and GetTime() - S.probedAt < 1 then return end
		ForgetIndoors()
	end)
	local broken = false
	driver:SetScript("OnUpdate", function()
		if broken or not W.layer then return end
		local dt = arg1 or 0
		if dt > 0.1 then dt = 0.1 end
		local ok, err = pcall(Step, dt)
		if not ok then
			broken = true
			HideFrom(1)
			HideLairs(1)
			C.ReleaseHud("flag")
			C.Print(C.L("the caches and lairs on the minimap stopped after an error: ") .. tostring(err))
		end
	end)
end)

C.OnWorld(function()
	if not db then return end
	Build()
	Levels()
	ForgetIndoors()
	S.hx, S.hy = nil, nil
	S.flagClock = 0
end)

C.OnLogout(function()
	if ldb then C.ReleaseHud("flag") end
end)

C.RegisterPart({
	key = "chests", name = "Chests on the minimap",
	note = "Every cache on the field as a gold chest on the minimap, or on its rim pointing the way when it's farther. A new one rings as it drops; they glow while your gold pays for one.",
	get = function() return db and db.enabled end,
	set = function(on)
		if db then
			db.enabled = on and true or false
			if not db.enabled then HideFrom(1) end
		end
	end,
})

C.RegisterPart({
	key = "lairs", name = "Lairs on the minimap",
	note = "Every guardian's lair as a skull token on the minimap: bronze while its guardian sleeps, red while it fights, grey once empty with the time until the next guardian comes. The one to head for rings slowly. Hides the game's red flag.",
	get = function() return ldb and ldb.enabled end,
	set = function(on)
		if ldb then
			ldb.enabled = on and true or false
			S.flagClock = 0
			if not ldb.enabled then HideLairs(1) end
		end
	end,
})
