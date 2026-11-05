-- Creed UI: a skull floating over each boss and guardian.
-- Every boss of the run wears a fierce horned skull a little over its head, its eyes smouldering
-- red; every guardian out of its lair, a plainer bone skull in an amber glow. They show wherever the
-- unit is on the screen, without a target or a nameplate: the game's world anchors say where each
-- stands and where that spot falls on the screen this frame. A near one's skull is large, a far
-- one's small, within limits. It fades in when the unit comes and out when it falls; the final
-- boss's glow is gold. Every cache waiting on the field wears a gold chest in a gold glow, so one
-- that drops is easy to find.

local C = CreedUI
local DEFAULTS = { enabled = true, scale = 1 }
local QUERY = { kinds = { "boss", "finalBoss", "guardian", "cache" } }
local CACHE = { lift = 2.2, size = 0.62, glow = { 0.95, 0.79, 0.44 } } -- yards over the cache; its size against a boss skull's
local GUARD_SIZE = 0.68     -- a guardian's skull, against a boss's at the same distance (as it was)
local LIST_EVERY = 0.5      -- how often the list of bosses is read again
local LIFT = 1.2            -- yards over the head
local FEET_LIFT = 5         -- yards over the feet, for a boss the game can't find the head of
local WIDTH_YARDS = 1.92    -- the skull's width, in the world (a fifth bigger than at first, asked for)
local MIN_PX, MAX_PX = 26, 77
local MAX_SKULLS = 16
local GONE = { dead = true, removed = true, departed = true, collected = true, expired = true, unavailable = true }
local LOST = { unknownAnchor = true, expired = true, worldChanged = true }
local GLOW_BOSS, GLOW_FINAL, GLOW_GUARD = { 0.95, 0.12, 0.06 }, { 1.00, 0.72, 0.20 }, { 1.00, 0.55, 0.12 }
local ASLEEP = { asleep = true, empty = true } -- a guardian home in its lair has none

local db
local layer
local S = { list = {}, n = 0, listAt = -10, markers = {}, registered = false, handlerAt = -10, lastAt = nil,
	broken = false, requests = {}, pool = {} }

------------------------------------------------------------------------ the game's answers
local function ApiReady()
	return type(AZS_GetWorldAnchors) == "function" and type(AZS_ProjectWorldAnchors) == "function"
end

-- the boss anchors now: { id, final } each; nil when the game can't say yet (keep the last list)
local function ReadList()
	local out, cursor = {}, nil
	for page = 1, 4 do
		local ok, res, err = pcall(AZS_GetWorldAnchors, QUERY, cursor, 64)
		if not ok or type(res) ~= "table" then
			if type(err) == "table" and err.code == "CATALOG_CHANGED" and page == 1 then
				return {}
			end
			return nil
		end
		local entries = res.entries or res.anchors
		if type(entries) ~= "table" then return nil end
		for i = 1, table.getn(entries) do
			local e = entries[i]
			local state = e and (e.entityState or e.state) or "alive"
			if type(e) == "table" and type(e.anchorId) == "string" and not GONE[state] and table.getn(out) < MAX_SKULLS
				and (e.kind == "boss" or e.kind == "finalBoss" or e.kind == "cache" or (e.kind == "guardian" and not ASLEEP[state])) then
				table.insert(out, { id = e.anchorId, final = e.kind == "finalBoss", guardian = e.kind == "guardian", cache = e.kind == "cache" })
			end
		end
		if res.hasMore and type(res.nextCursor) == "string" then
			cursor = res.nextCursor
		else
			break
		end
	end
	return out
end

------------------------------------------------------------------------ the markers
local function NewMarker()
	local m = { alpha = 0, size = 0, x = nil, y = nil, seen = false, feet = false, bob = math.random() * 6 }
	local f = CreateFrame("Frame", nil, layer)
	m.frame = f
	f:SetWidth(40)
	f:SetHeight(40)
	f:EnableMouse(false)
	m.glow = C.Tex(f, "BACKGROUND", C.ART .. "Glow", "ADD")
	m.glow:SetPoint("CENTER", f, "CENTER", 0, 0)
	m.skull = C.Tex(f, "ARTWORK", C.ART .. "BossSkullFierce")
	m.skull:SetPoint("CENTER", f, "CENTER", 0, 0)
	-- a boss's eyes: their own light over the skull, smouldering like the dragons' on the skill bar
	m.eyes = C.Tex(f, "OVERLAY", C.ART .. "BossSkullEyes", "ADD")
	m.eyes:SetPoint("CENTER", f, "CENTER", 0, 0)
	m.eyes:SetVertexColor(1, 0.22, 0.06)
	f:Hide()
	return m
end

-- a marker for a boss, the one it has or one from the pool
local function Marker(id)
	local m = S.markers[id]
	if not m then
		if table.getn(S.pool) > 0 then
			-- table.remove, not [n] = nil: in Lua 5.0 that leaves the list's count as it was
			m = table.remove(S.pool)
			m.alpha, m.size, m.x, m.y, m.want, m.seen, m.feet = 0, 0, nil, nil, nil, false, false
		else
			m = NewMarker()
		end
		S.markers[id] = m
	end
	return m
end

local function HideAll()
	for _, m in pairs(S.markers) do
		m.alpha, m.seen, m.x = 0, false, nil
		C.Vis(m.frame, false)
	end
end

-- how big a skull is, in the layer's units: its width in the world at the boss's distance
local function SizeOf(entry, ratio)
	local scale = db.scale or 1
	local px
	if type(entry.uiUnitsPerYard) == "number" and entry.uiUnitsPerYard > 0 then
		px = WIDTH_YARDS * entry.uiUnitsPerYard * ratio
	elseif type(entry.playerDistance) == "number" then
		px = 40 * 20 / math.max(entry.playerDistance, 5)
	else
		px = 36
	end
	return C.Clamp(px, MIN_PX, MAX_PX) * scale
end

------------------------------------------------------------------------ each frame
local function Project(ratio)
	local n = S.n
	if n == 0 then return end
	local req = S.requests
	for i = 1, n do
		local item = S.list[i]
		local r = req[i]
		if not r then
			r = { offset = { x = 0, y = 0, z = 0 } }
			req[i] = r
		end
		local m = Marker(item.id)
		r.anchorId = item.id
		if item.cache then
			r.attachment, r.offset.z = "position", CACHE.lift
		elseif m.feet then
			r.attachment, r.offset.z = "position", FEET_LIFT
		else
			r.attachment, r.offset.z = "overhead", LIFT
		end
	end
	for i = n + 1, table.getn(req) do req[i] = nil end
	local ok, res = pcall(AZS_ProjectWorldAnchors, req)
	if not ok or type(res) ~= "table" or type(res.entries) ~= "table" then
		for i = 1, n do Marker(S.list[i].id).seen = false end
		return
	end
	for i = 1, n do
		local item = S.list[i]
		local m = Marker(item.id)
		local e = res.entries[i]
		m.seen = false
		if type(e) == "table" and (e.anchorId == nil or e.anchorId == item.id) then
			if e.state == "unsupportedAttachment" then
				m.feet = true
			elseif LOST[e.state or ""] then
				S.listAt = -10
			elseif e.state == "onScreen" and type(e.x) == "number" and type(e.y) == "number"
				and not GONE[e.targetState or e.entityState or "alive"] then
				m.seen = true
				m.x, m.y = e.x * ratio, e.y * ratio
				m.want = SizeOf(e, ratio)
			end
		end
	end
end

local function Draw(now, dt)
	local live = {}
	for i = 1, S.n do live[S.list[i].id] = S.list[i] end
	for id, m in pairs(S.markers) do
		local item = live[id]
		local target = (item and m.seen) and 1 or 0
		m.alpha = C.Toward(m.alpha, target, 5, dt)
		if m.alpha <= 0.01 then
			C.Vis(m.frame, false)
			if not item then
				S.markers[id] = nil
				table.insert(S.pool, m)
			end
		elseif m.x then
			if m.size <= 0 then m.size = m.want or 36 end
			m.size = m.size + ((m.want or m.size) - m.size) * math.min(1, dt * 10)
			local size = math.floor(m.size + 0.5)
			local bob = math.sin(now * 1.6 + m.bob) * 2
			local guardian = item and item.guardian
			local cache = item and item.cache
			local art = (cache and 3) or (guardian and 1) or 2
			if m.art ~= art then
				m.art = art
				m.skull:SetTexture(C.ART .. ((cache and "Chest") or (guardian and "BossSkull") or "BossSkullFierce"))
				if cache then
					m.skull:SetVertexColor(CACHE.glow[1], CACHE.glow[2], CACHE.glow[3])
				else
					m.skull:SetVertexColor(1, 1, 1)
				end
			end
			if guardian then size = math.floor(size * GUARD_SIZE + 0.5) end
			if cache then size = math.floor(size * CACHE.size + 0.5) end
			C.Size(m.skull, size, size)
			C.Size(m.eyes, size, size)
			C.Vis(m.eyes, art == 2)
			if art == 2 then C.Alpha(m.eyes, 0.88 + 0.12 * math.sin(now * 2.6 + m.bob)) end
			C.Size(m.glow, size * 2.1, size * 2.1)
			local tint = (cache and CACHE.glow) or (guardian and GLOW_GUARD) or (item and item.final and GLOW_FINAL) or GLOW_BOSS
			C.Color(m.glow, tint[1], tint[2], tint[3], 0.55 + 0.15 * math.sin(now * 2.2 + m.bob))
			C.Place(m.frame, "CENTER", WorldFrame, "BOTTOMLEFT", math.floor(m.x * 10 + 0.5) / 10,
				math.floor((m.y + size * 0.5 + bob) * 10 + 0.5) / 10)
			C.Alpha(m.frame, m.alpha)
			C.Vis(m.frame, true)
		end
	end
end

local function Ratio()
	local ws, ls = WorldFrame:GetEffectiveScale(), layer:GetEffectiveScale()
	if type(ws) == "number" and type(ls) == "number" and ls > 0 then return ws / ls end
	return 1
end

local function Step(now)
	local dt = S.lastAt and (now - S.lastAt) or 0
	if dt < 0 then dt = 0 elseif dt > 0.1 then dt = 0.1 end
	S.lastAt = now
	if now - S.listAt >= LIST_EVERY then
		S.listAt = now
		local list = ReadList()
		if list then
			S.list, S.n = list, table.getn(list)
		end
	end
	-- no boss and no skull still fading: nothing to move
	if S.n == 0 and next(S.markers) == nil then return end
	Project(Ratio())
	Draw(now, dt)
end

------------------------------------------------------------------------ on and off
local OnFrame

local function Fail(err)
	S.broken = true
	db.enabled = false
	HideAll()
	if S.registered and type(AZS_UnregisterWorldAnchorFrameHandler) == "function" then
		pcall(AZS_UnregisterWorldAnchorFrameHandler, OnFrame)
	end
	S.registered = false
	C.Print(C.L("the boss skulls stopped after an error: ") .. tostring(err))
end

local function Safe(now)
	if S.broken or not db or not db.enabled or not ApiReady() then return end
	local ok, err = pcall(Step, now)
	if not ok then Fail(err) end
end

OnFrame = function()
	local now = GetTime()
	S.handlerAt = now
	Safe(now)
end

local function Register()
	if S.registered or type(AZS_RegisterWorldAnchorFrameHandler) ~= "function" then return end
	local ok, result, failure = pcall(AZS_RegisterWorldAnchorFrameHandler, OnFrame)
	S.registered = ok and failure == nil and result ~= false
end

local function SetEnabled(on)
	db.enabled = on and true or false
	if on then
		S.broken = false
		S.listAt, S.lastAt = -10, nil
		if ApiReady() then Register() end
	else
		if S.registered and type(AZS_UnregisterWorldAnchorFrameHandler) == "function" then
			pcall(AZS_UnregisterWorldAnchorFrameHandler, OnFrame)
		end
		S.registered = false
		S.list, S.n = {}, 0
		HideAll()
	end
end

------------------------------------------------------------------------ what the game says (/creed probe)
local function Line(t)
	if type(t) ~= "table" then return tostring(t) end
	local keys = {}
	for k, v in pairs(t) do
		local s
		if type(v) == "table" then
			local parts, n = {}, 0
			for k2, v2 in pairs(v) do
				n = n + 1
				if n <= 6 then table.insert(parts, tostring(k2) .. "=" .. (type(v2) == "table" and "{..}" or tostring(v2))) end
			end
			s = "{" .. table.concat(parts, " ") .. (n > 6 and " .." or "") .. "}"
		else
			s = tostring(v)
		end
		table.insert(keys, tostring(k) .. "=" .. s)
	end
	table.sort(keys)
	return table.concat(keys, ", ")
end

function C.ProbeAnchors()
	if not ApiReady() then
		C.Print("AZS_GetWorldAnchors: -")
		return
	end
	if type(AZS_GetWorldAnchorCapabilities) == "function" then
		local ok, caps = pcall(AZS_GetWorldAnchorCapabilities)
		C.Print("anchors caps: " .. (ok and Line(caps) or tostring(caps)))
	end
	local ok, res, err = pcall(AZS_GetWorldAnchors, QUERY, nil, 8)
	if not ok or type(res) ~= "table" then
		C.Print("anchors: " .. Line(err or res))
		return
	end
	local entries = res.entries or res.anchors or {}
	local top = {}
	for k, v in pairs(res) do if type(v) ~= "table" then top[k] = v end end
	C.Print("anchors: " .. Line(top) .. ", entries=" .. table.getn(entries))
	for i = 1, math.min(table.getn(entries), 3) do C.Print("  " .. i .. ": " .. Line(entries[i])) end
	local e = entries[1]
	if type(e) == "table" and type(e.anchorId) == "string" then
		local ok2, proj, perr = pcall(AZS_ProjectWorldAnchors,
			{ { anchorId = e.anchorId, attachment = "overhead", offset = { x = 0, y = 0, z = LIFT } } })
		if ok2 and type(proj) == "table" and type(proj.entries) == "table" then
			local ptop = {}
			for k, v in pairs(proj) do if type(v) ~= "table" then ptop[k] = v end end
			C.Print("projected: " .. Line(ptop) .. " / " .. Line(proj.entries[1]))
		else
			C.Print("projected: " .. Line(perr or proj))
		end
	end
	if type(AZS_GetDownedPartyMembers) == "function" then
		local ok3, down, derr = pcall(AZS_GetDownedPartyMembers)
		if ok3 and type(down) == "table" then
			C.Print("downed: " .. table.getn(down) .. (down[1] and (" / " .. Line(down[1])) or ""))
		else
			C.Print("downed: " .. Line(derr or down))
		end
	end
end

------------------------------------------------------------------------ start up
C.OnInit(function()
	db = C.DB("skulls", DEFAULTS)
	layer = CreateFrame("Frame", "CreedUISkulls", WorldFrame)
	layer:SetAllPoints(WorldFrame)
	layer:SetFrameStrata("BACKGROUND")
	layer:EnableMouse(false)
	-- the game's handler moves the skulls with its camera; without it (or while it is quiet),
	-- they move from here, and the handler is asked for again now and then
	local driver = CreateFrame("Frame", "CreedUISkullsDriver")
	local nextTry = 0
	driver:SetScript("OnUpdate", function()
		if not db or not db.enabled or S.broken then return end
		local now = GetTime()
		if now - S.handlerAt > 0.25 then Safe(now) end
		if ApiReady() and now - S.handlerAt > 1 and now >= nextTry then
			nextTry = now + 5
			S.registered = false
			Register()
		end
	end)
end)

C.OnWorld(function()
	if not db then return end
	S.list, S.n, S.listAt = {}, 0, -10
	HideAll()
	if db.enabled and ApiReady() then Register() end
end)

C.RegisterPart({
	key = "skulls", name = "Boss skulls",
	note = "A skull over each boss and awake guardian, and a gold chest over each cache, wherever they are on the screen: large when near, small when far.",
	get = function() return db and db.enabled end,
	set = function(on) if db then SetEnabled(on) end end,
	getScale = function() return db and db.scale or 1 end,
	setScale = function(v) if db then db.scale = v end end,
})
