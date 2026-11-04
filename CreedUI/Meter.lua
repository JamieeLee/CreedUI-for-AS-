-- Creed UI: the damage meter, in the boss timer's style. The game's four views (Damage Done,
-- Healing Done, Boss Damage, Party DPS), and Damage Taken (what hit you, the most first), with
-- every line's icon, rank, amount, per second and
-- share, a blue "proc" tag on a talent's or amulet's own damage, the total per second up top,
-- and Reset (this window only, as the game's). Bars glide and lines slide when they swap places.
-- Drag it (title or lines) to move it, any edge or corner to size it (an arrow by the mouse shows
-- the way; it settles on whole lines), the wheel to scroll. While this part is on, the game's
-- meter window (and its minimap button) is hidden.

local C = CreedUI
local DEFAULTS = { enabled = true, shown = true, collapsed = false, tab = "damage", rows = 8, scale = 1, width = 236 }
local HEAD, ROW, PAD = 24, 18, 5
local MIN_W, MAX_W = 200, 440
local W = 236 -- the window's width: the luck window's by default, its edges drag it wider or narrower
local MIN_ROWS, MAX_ROWS = 3, 20
local READ_EVERY = 0.5
-- `short`: what the head calls the view when its whole name and the total don't both fit
local TABS = {
	{ key = "damage", name = "Damage Done", short = { "Damage", "Dmg" }, unit = "dps", empty = "No damage yet." },
	{ key = "healing", name = "Healing Done", short = { "Healing", "Heal" }, unit = "hps", empty = "No healing yet." },
	{ key = "boss", name = "Boss Damage", short = { "Boss Dmg", "Boss" }, unit = "dps", empty = "No boss fight yet." },
	{ key = "party", name = "Party DPS", short = { "Party" }, unit = "dps", empty = "No damage yet." },
	{ key = "taken", name = "Damage Taken", short = { "Taken" }, unit = "dtps", empty = "No damage taken yet." },
}
local TAKEN_ICON = C.ART .. "Skull" -- what hit you is a monster: a skull stands for its icon
local EMPTY_BY_CODE = { NO_PARTY = "Not in a party.", NO_ENCOUNTER = "No boss fight yet.", NO_RUN = "No run yet." }
-- by actor and source: each of your skills on its own line, and each summon's skills on theirs
local QUERIES = {
	damage = { metric = "damage", scope = "self", period = "run", groupBy = "actor_source", windowSeconds = 10 },
	healing = { metric = "healing", scope = "self", period = "run", groupBy = "actor_source", windowSeconds = 0 },
	boss = { metric = "damage", scope = "self", period = "encounter", groupBy = "actor_source", windowSeconds = 0 },
	party = { metric = "damage", scope = "party", period = "run", groupBy = "owner", windowSeconds = 0 },
}
-- answers that mean the API itself can't be used now: then the game's own meter lines are read
local HARD_ERRORS = { INVALID_ARGUMENT = true, UNSUPPORTED_VERSION = true, UNSUPPORTED_QUERY = true, INTERNAL_ERROR = true,
	INVALID_RESPONSE = true }
local SCHOOLS = {
	[1] = { 0.80, 0.30, 0.24 }, [2] = { 1.00, 0.84, 0.36 }, [4] = { 1.00, 0.46, 0.14 }, [8] = { 0.36, 0.82, 0.30 },
	[16] = { 0.40, 0.72, 1.00 }, [32] = { 0.62, 0.36, 0.95 }, [64] = { 0.95, 0.45, 0.90 },
}
-- Each line its own color, for good: the first skill seen takes the first color, the next the
-- next, and a skill keeps its color (by its name; a proc line apart) through ranks, views and
-- sessions.
local PALETTE = { -- 36 colors picked to be as far apart as can be, all dark enough for white numbers
	{ 0.84, 0.25, 0.21 }, { 0.08, 0.84, 0.08 }, { 0.44, 0.09, 0.95 }, { 0.09, 0.78, 0.95 }, { 0.95, 0.52, 0.89 }, { 0.58, 0.60, 0.33 },
	{ 0.09, 0.49, 0.95 }, { 0.95, 0.61, 0.09 }, { 0.60, 0.33, 0.40 }, { 0.07, 0.72, 0.59 }, { 0.95, 0.09, 0.89 }, { 0.95, 0.09, 0.49 },
	{ 0.33, 0.42, 0.60 }, { 0.55, 0.72, 0.07 }, { 0.95, 0.64, 0.52 }, { 0.61, 0.38, 0.95 }, { 0.60, 0.35, 0.06 }, { 0.07, 0.72, 0.33 },
	{ 0.60, 0.15, 0.57 }, { 0.72, 0.63, 0.07 }, { 0.33, 0.58, 0.60 }, { 0.53, 0.40, 0.72 }, { 0.95, 0.52, 0.67 }, { 0.52, 0.69, 0.95 },
	{ 0.60, 0.44, 0.33 }, { 0.72, 0.18, 0.32 }, { 0.95, 0.24, 0.71 }, { 0.95, 0.38, 0.09 }, { 0.84, 0.64, 0.34 }, { 0.33, 0.60, 0.33 },
	{ 0.72, 0.35, 0.29 }, { 0.09, 0.32, 0.95 }, { 0.59, 0.07, 0.72 }, { 0.95, 0.09, 0.09 }, { 0.72, 0.29, 0.52 }, { 0.95, 0.09, 0.32 },
}
local PROC = { 0.30, 0.55, 1.00 }
local HEAL = { 0.30, 0.86, 0.44 }
local CLASS_COLORS = {
	HUNTER = { 0.67, 0.83, 0.45 }, WARLOCK = { 0.58, 0.51, 0.79 }, PRIEST = { 0.86, 0.86, 0.86 },
	PALADIN = { 0.96, 0.55, 0.73 }, MAGE = { 0.41, 0.80, 0.94 }, ROGUE = { 1.00, 0.96, 0.41 },
	DRUID = { 1.00, 0.49, 0.04 }, SHAMAN = { 0.00, 0.44, 0.87 }, WARRIOR = { 0.78, 0.61, 0.43 },
}
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"

local db, root
local rows = {}          -- row widgets
local byKey = {}         -- line key -> row widget
local S = { list = {}, n = 0, total = 0, rate = nil, readClock = 0, offset = 0, alpha = 0, stamp = -1,
	checkpoint = nil, base = nil, baseAt = nil, status = nil, levelled = false, menuOpen = false }

local Call = C.Call -- no stray nil arguments (see Core)

-- 154, 1.5k, 13.2k, 2.3m: the game's meter's own way
local function Amount(n)
	n = tonumber(n) or 0
	if n < 1000 then return tostring(math.floor(n + 0.5)) end
	if n < 1e6 then return string.format("%.1fk", math.floor(n / 100) / 10) end
	if n < 1e9 then return string.format("%.1fm", math.floor(n / 1e5) / 10) end
	return string.format("%.1fb", math.floor(n / 1e8) / 10)
end

local function ColorFor(name)
	local colors = db.colors
	local i = colors[name or "?"]
	if not i then
		db.colorNext = (db.colorNext or 0) + 1
		i = math.mod(db.colorNext - 1, table.getn(PALETTE)) + 1
		colors[name or "?"] = i
	end
	return PALETTE[i] or PALETTE[1]
end

-- a line's color: a hero's class color in Party DPS, else its skill's own
local function ColorOf(e)
	if db.tab == "party" then return e.color or { 0.7, 0.7, 0.7 } end
	return ColorFor(e.proc and ((e.name or "?") .. " #proc") or e.name) -- a proc line apart from its skill's
end

local function TabOf(key)
	for i = 1, table.getn(TABS) do
		if TABS[i].key == key then return TABS[i] end
	end
	return TABS[1]
end

local function RateValue(r)
	if type(r) == "table" and r.status == "ready" and tonumber(r.value) then return r.value end
	return nil
end

------------------------------------------------------------------------ reading: the meter API
-- each line: key, name, icon, amount, rate, share, proc, color (and class, portrait for heroes)
local function Line(i)
	local e = S.list[i]
	if not e then
		e = {}
		S.list[i] = e
	end
	e.icon, e.portrait, e.classKey, e.color, e.proc, e.top, e.topRate, e.school = nil, nil, nil, nil, false, nil, nil, nil
	e.skill, e.pet = nil, nil
	return e
end

-- the school a source's line mostly dealt, from its credits
local function SchoolOf(snap, row)
	if type(snap.contributions) ~= "table" or type(row.memberIds) ~= "table" then return nil end
	if not S.contribs or S.contribsFor ~= snap then
		S.contribs, S.contribsFor = {}, snap
		for i = 1, table.getn(snap.contributions) do
			local c = snap.contributions[i]
			if type(c) == "table" and c.rowId then S.contribs[c.rowId] = c end
		end
	end
	local best, most = nil, -1
	for i = 1, table.getn(row.memberIds) do
		local c = S.contribs[row.memberIds[i]]
		if c and c.schoolState == "known" and SCHOOLS[c.schoolMask] and (tonumber(c.displayAmount) or 0) > most then
			best, most = c.schoolMask, tonumber(c.displayAmount) or 0
		end
	end
	return best
end

-- a source view: your own skills, each on its line, and each summon's skills on theirs
-- ("Infernal: Immolation"), all the summons of one kind counted together
local function SourceLines(snap, tab)
	local n, at = 0, {}
	local list = type(snap.rows) == "table" and snap.rows or {}
	local actors = type(snap.actors) == "table" and snap.actors or {}
	local sources = type(snap.sources) == "table" and snap.sources or {}
	for i = 1, table.getn(list) do
		local row = list[i]
		local amount = type(row) == "table" and tonumber(row.displayAmount) or 0
		if amount > 0 then
			local actor = actors[row.actorId] or {}
			local own = row.actorId == nil or actor.kind == "hero" or row.actorId == row.ownerId
			local who = own and "" or tostring(actor.summonKey or actor.totemKey or actor.name or row.actorId)
			local proc = row.nativeProc and true or false
			-- all of a skill's ranks are one line, by its name: the game counts each rank apart
			local src = sources[row.sourceKey] or {}
			local skill = (type(src.name) == "string" and src.name ~= "" and src.name) or src.abilityKey or src.talentKey
				or (string.gsub(tostring(row.sourceKey), ":r%d+.*$", ""))
			local key = "s" .. tostring(skill) .. "|" .. who .. (proc and "#p" or "")
			local rate = RateValue(S.checkpoint and row.checkpointAverage or row.periodAverage) or RateValue(row.displayRate) or 0
			local e = at[key] and S.list[at[key]]
			if e then
				e.amount = e.amount + amount
				e.rate = (e.rate or 0) + rate
				if e.recent or row.recentRate then e.recent = (e.recent or 0) + (RateValue(row.recentRate) or 0) end
				e.share = e.share + (tonumber(row.share) or 0)
			else
				n = n + 1
				at[key] = n
				e = Line(n)
				e.key, e.amount, e.rate, e.proc = key, amount, rate, proc
				e.recent = RateValue(row.recentRate)
				e.share = tonumber(row.share) or 0
				local name = type(src.name) == "string" and src.name or tostring(row.sourceKey)
				e.skill = name
				if not own and type(actor.name) == "string" and actor.name ~= "" and not string.find(name, actor.name, 1, true) then
					e.pet = actor.name -- shown in a tag after the skill (the tooltip has both)
					name = actor.name .. ": " .. name
				end
				e.name = name
				if type(src.icon) == "table" and src.icon.status == "ready" and type(src.icon.path) == "string" then
					e.icon = src.icon.path
				elseif not own and type(actor.portrait) == "table" and actor.portrait.status == "ready" then
					e.portrait = actor.portrait.portraitKey -- a summon's own swing: its face
				end
				local school = tab ~= "healing" and SchoolOf(snap, row) or nil
				e.school = school
			end
		end
	end
	return n
end

-- Party DPS: a line a hero, in its class's color, with its portrait
local function OwnerLines(snap)
	local n = 0
	local list = type(snap.rows) == "table" and snap.rows or {}
	local actors = type(snap.actors) == "table" and snap.actors or {}
	for i = 1, table.getn(list) do
		local row = list[i]
		local amount = type(row) == "table" and tonumber(row.displayAmount) or 0
		if amount > 0 then
			n = n + 1
			local e = Line(n)
			local actor = actors[row.ownerId] or {}
			e.key, e.amount = "o" .. tostring(row.ownerId), amount
			e.rate = RateValue(S.checkpoint and row.checkpointAverage or row.periodAverage) or RateValue(row.displayRate)
			e.recent, e.share = RateValue(row.recentRate), tonumber(row.share) or 0
			e.name = type(actor.name) == "string" and actor.name or "?"
			e.classKey = type(actor.classKey) == "string" and string.upper(actor.classKey) or nil
			e.color = CLASS_COLORS[e.classKey or ""]
			if type(actor.portrait) == "table" and actor.portrait.status == "ready" then e.portrait = actor.portrait.portraitKey end
		end
	end
	return n
end

local function FromSnapshot(snap, tab)
	local n
	if tab == "party" then n = OwnerLines(snap) else n = SourceLines(snap, tab) end
	S.n = n
	local totals = type(snap.totals) == "table" and snap.totals or {}
	S.total = tonumber(totals.displayAmount) or 0
	S.rate = RateValue(totals.recentRate) or RateValue(totals.displayRate)
	S.status = (n == 0) and "empty" or nil
	S.runId = type(snap.context) == "table" and snap.context.runId or S.runId
end

-- true when it read the API (or it answered "wait" or "nothing there"); false when the API can't
-- be used, and the game's own meter lines should be read instead
local function ReadSnapshot(tab)
	local context, cerr = Call(AZS_GetMeterContext)
	if type(context) ~= "table" or not context.runId then
		local code = type(cerr) == "table" and cerr.code or nil
		if code == "NOT_READY" or code == "NO_PLAYER" then return true end
		if code == "NO_RUN" or code == "NO_WORLD" then
			S.n, S.status, S.emptyText = 0, "empty", nil
			return true
		end
		return false
	end
	if S.checkpoint and S.checkpointRun ~= context.runId then S.checkpoint = nil end
	local q = QUERIES[tab]
	local query = { apiVersion = 1, runId = context.runId, metric = q.metric, scope = q.scope, period = q.period,
		groupBy = q.groupBy, windowSeconds = q.windowSeconds }
	if q.metric == "healing" then query.healingPerspective = "received" end
	if S.checkpoint then query.checkpointId = S.checkpoint end
	local snap, err = Call(AZS_GetMeterSnapshot, query)
	if type(snap) ~= "table" then
		local code = type(err) == "table" and err.code or nil
		if code == "CHECKPOINT_EXPIRED" or code == "CHECKPOINT_INVALIDATED" or code == "INVALID_CHECKPOINT" then
			S.checkpoint = nil
			S.readClock = 0
			return true
		end
		if not code or HARD_ERRORS[code] then return false end
		if code ~= "NOT_READY" and code ~= "ART_NOT_READY" and code ~= "RUN_MISMATCH" then
			S.n, S.status = 0, "empty" -- no boss fight, no party, no run: the empty line says so
			S.emptyText = EMPTY_BY_CODE[code]
		end
		return true
	end
	S.emptyText = nil
	FromSnapshot(snap, tab)
	C.NoteSources(snap.sources) -- for the damage numbers: each line's own icon
	return true
end

------------------------------------------------------------------------ reading: the older getters
-- Damage Taken: the game's list of what hit you ({ source, dmg }), as a meter's lines, per second
-- over the run's clock
local function TakenLines()
	local list = type(AZS_TAKEN) == "table" and AZS_TAKEN or {}
	local t = math.max(1, tonumber(Call(AZS_GetRunTime)) or 1)
	local lines, total = {}, 0
	for i = 1, table.getn(list) do
		local l = list[i]
		local dmg = type(l) == "table" and tonumber(l.dmg)
		if dmg and dmg > 0 and l.source ~= nil then
			table.insert(lines, { name = tostring(l.source), dmg = dmg, dps = dmg / t })
			total = total + dmg
		end
	end
	for i = 1, table.getn(lines) do lines[i].share = total > 0 and lines[i].dmg / total or 0 end
	return lines, total, total / t
end

local GETTERS = { damage = "AZS_GetMeter", healing = "AZS_GetHealing", boss = "AZS_GetBossMeter", party = "AZS_GetPartyMeter",
	taken = TakenLines }

local function ReadLines(tab)
	local getter = GETTERS[tab]
	if type(getter) == "string" then getter = getglobal(getter) end
	local lines, total, rate = Call(getter)
	local n = 0
	if type(lines) == "table" then
		-- Reset here keeps each line's amount at that moment and shows what came after
		local base, since = S.base, S.baseAt and (GetTime() - S.baseAt) or nil
		for i = 1, table.getn(lines) do
			local l = lines[i]
			if type(l) == "table" and type(l.name) == "string" then
				local amount = tonumber(l.dmg) or 0
				local key = (tab == "party" and "o" or "s") .. l.name .. ((tonumber(l.proc) == 1) and "#p" or "")
				if base then amount = amount - (base[key] or 0) end
				if amount > 0 then
					n = n + 1
					local e = Line(n)
					e.key, e.name, e.amount = key, l.name, amount
					e.rate = base and since and since > 1 and amount / since or tonumber(l.dps)
					e.recent, e.share = nil, tonumber(l.share) or 0
					e.proc = tonumber(l.proc) == 1
					if tab == "party" then
						e.classKey = type(l.class) == "string" and string.upper(l.class) or nil
						e.color = CLASS_COLORS[e.classKey or ""]
						if type(l.top) == "string" and l.top ~= "" then e.top, e.topRate = l.top, tonumber(l.topdps) end
					else
						e.icon = (tab == "taken") and TAKEN_ICON or C.icons[l.name]
						e.color = nil
					end
				end
			end
		end
	end
	S.n = n
	S.total = 0
	for i = 1, n do S.total = S.total + S.list[i].amount end
	if S.base then
		for i = 1, n do S.list[i].share = S.total > 0 and S.list[i].amount / S.total or 0 end
		local since = GetTime() - S.baseAt
		S.rate = since > 1 and S.total / since or nil
	else
		S.rate = tonumber(rate)
	end
	S.status = (n == 0) and "empty" or nil
	S.emptyText = (n == 0 and tab == "party") and EMPTY_BY_CODE.NO_PARTY or nil -- empty out of a party
end

-- the most first: only the lines read now (the list keeps older tables for reuse past them).
-- Two lines within 3% of each other keep the order they had, so they don't keep swapping.
local function Ahead(a, b)
	local x, y = a.amount or 0, b.amount or 0
	local was = S.rank
	local ra, rb = was and was[a.key], was and was[b.key]
	if ra and rb and math.abs(x - y) <= 0.03 * math.max(x, y) then return ra < rb end
	return x > y
end

local function SortLines()
	local list = S.list
	for i = 2, S.n do
		local e = list[i]
		local j = i - 1
		while j >= 1 and Ahead(e, list[j]) do
			list[j + 1] = list[j]
			j = j - 1
		end
		list[j + 1] = e
	end
	S.rank = {}
	for i = 1, S.n do S.rank[list[i].key] = i end
end

local function Read()
	local tab = db.tab
	local done = false
	if tab ~= "taken" and type(AZS_GetMeterSnapshot) == "function" and type(AZS_GetMeterContext) == "function" then
		done = ReadSnapshot(tab)
	end
	S.usedLines = not done
	if not done then ReadLines(tab) end
	SortLines() -- the game sorts already; after a Reset here the order can change
end

------------------------------------------------------------------------ Reset: this window only
local function Reset()
	S.base, S.baseAt = nil, nil
	if not S.usedLines and type(AZS_CreateMeterCheckpoint) == "function" and type(AZS_GetMeterContext) == "function" then
		local context = Call(AZS_GetMeterContext)
		if type(context) == "table" and context.runId then
			local cp = Call(AZS_CreateMeterCheckpoint, context.runId)
			if type(cp) == "table" and cp.checkpointId then
				if S.checkpoint then Call(AZS_ReleaseMeterCheckpoint, S.checkpoint) end
				S.checkpoint, S.checkpointRun = cp.checkpointId, context.runId
			end
		end
	else
		-- the older getters: remember where every line stood
		local base = {}
		for i = 1, S.n do
			local e = S.list[i]
			base[e.key] = (e.amount or 0) + ((S.base and S.base[e.key]) or 0)
		end
		S.base, S.baseAt = base, GetTime()
	end
	for key, r in pairs(byKey) do r.bar.snap = true end
	S.readClock = 0
end

------------------------------------------------------------------------ building
local function TextButton(parent, label, width, onClick, tip)
	local b = CreateFrame("Button", nil, parent)
	b:SetWidth(width)
	b:SetHeight(16)
	b.text = C.Text(b, C.FONT, 10, nil, "CENTER", width)
	b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
	C.LText(b.text, label)
	b.text:SetTextColor(0.78, 0.74, 0.66)
	b.hl = C.Tex(b, "BACKGROUND", C.FLAT)
	b.hl:SetAllPoints(b)
	b.hl:SetVertexColor(1, 0.85, 0.4, 0.14)
	b.hl:Hide()
	b:SetScript("OnEnter", function()
		b.hl:Show()
		b.text:SetTextColor(1, 0.9, 0.6)
		if tip and GameTooltip then
			GameTooltip:SetOwner(b, "ANCHOR_TOP")
			GameTooltip:AddLine(C.L(tip), 1, 1, 1)
			C.ShowTip()
		end
	end)
	b:SetScript("OnLeave", function()
		b.hl:Hide()
		b.text:SetTextColor(0.78, 0.74, 0.66)
		if GameTooltip then GameTooltip:Hide() end
	end)
	b:SetScript("OnClick", onClick)
	return b
end

local function NewRow()
	local r = { y = nil, yv = 0, alpha = 0, shown = 0, bar = { value = 0, vel = 0 } }
	local f = CreateFrame("Frame", nil, root.body)
	r.frame = f
	C.Width(f, W - 2 * PAD)
	f:SetHeight(ROW - 2)
	f:EnableMouse(true)
	r.track = C.Tex(f, "BACKGROUND", C.FLAT)
	r.track:SetPoint("TOPLEFT", f, "TOPLEFT", ROW, 0)
	r.track:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
	r.track:SetVertexColor(1, 1, 1, 0.05)
	r.fill = C.Tex(f, "BORDER", C.ART .. "Fill")
	r.fill:SetPoint("TOPLEFT", f, "TOPLEFT", ROW, 0)
	r.fill:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", ROW, 0)
	r.gloss = C.Tex(f, "ARTWORK", C.FLAT)
	r.gloss:SetPoint("TOPLEFT", r.fill, "TOPLEFT", 0, 0)
	r.gloss:SetPoint("TOPRIGHT", r.fill, "TOPRIGHT", 0, 0)
	r.gloss:SetHeight((ROW - 2) * 0.5)
	r.gloss:SetGradientAlpha("VERTICAL", 1, 1, 1, 0, 1, 1, 1, 0.12)
	r.iconBg = C.Tex(f, "BACKGROUND", C.FLAT)
	r.iconBg:SetWidth(ROW - 2)
	r.iconBg:SetHeight(ROW - 2)
	r.iconBg:SetPoint("LEFT", f, "LEFT", 0, 0)
	r.iconBg:SetVertexColor(0, 0, 0, 0.8)
	r.icon = f:CreateTexture(nil, "ARTWORK")
	r.icon:SetWidth(ROW - 4)
	r.icon:SetHeight(ROW - 4)
	r.icon:SetPoint("CENTER", r.iconBg, "CENTER", 0, 0)
	r.name = C.Text(f, C.FONT, 11, nil, "LEFT", W - 120)
	r.name:SetPoint("LEFT", f, "LEFT", ROW + 4, 0)
	r.value = C.Text(f, C.FONT, 10, nil, "RIGHT", 120)
	r.value:SetPoint("RIGHT", f, "RIGHT", -3, 0)
	r.procTag = C.Text(f, C.FONT, 8, nil, "LEFT", 30)
	r.procTag:SetText("proc")
	r.procTag:SetTextColor(0.55, 0.75, 1)
	r.procBox = C.Tex(f, "ARTWORK", C.FLAT)
	r.procBox:SetVertexColor(0.3, 0.55, 1, 0.28)
	r.procBox:SetPoint("TOPLEFT", r.procTag, "TOPLEFT", -2, 1)
	r.procBox:SetPoint("BOTTOMRIGHT", r.procTag, "BOTTOMRIGHT", 2, -1)
	-- a summon's name, in a tag of its own after the skill
	r.petTag = C.Text(f, C.FONT, 8, nil, "LEFT", 200)
	r.petTag:SetTextColor(1, 0.86, 0.55)
	r.petBox = C.Tex(f, "ARTWORK", C.FLAT)
	r.petBox:SetVertexColor(0.85, 0.62, 0.22, 0.24)
	r.petBox:SetPoint("TOPLEFT", r.petTag, "TOPLEFT", -2, 1)
	r.petBox:SetPoint("BOTTOMRIGHT", r.petTag, "BOTTOMRIGHT", 2, -1)
	C.Vis(r.petTag, false)
	C.Vis(r.petBox, false)
	f:SetScript("OnEnter", function()
		r.hovering = true
		if r.entry then S.tipRow = r end
	end)
	f:SetScript("OnLeave", function()
		r.hovering = false
		if S.tipRow == r then S.tipRow = nil end
		if GameTooltip then GameTooltip:Hide() end
	end)
	f:Hide()
	return r
end

local function ShowMenu(on)
	S.menuOpen = on and true or false
	if on then root.menu:Show() else root.menu:Hide() end
end

local function BuildMenu()
	local m = CreateFrame("Frame", nil, root)
	root.menu = m
	m:SetWidth(120)
	m:SetHeight(table.getn(TABS) * 18 + 8)
	m:SetPoint("TOPLEFT", root.title, "BOTTOMLEFT", -6, -4)
	m:SetFrameStrata("DIALOG")
	m:EnableMouse(true)
	m.bg = C.Tex(m, "BACKGROUND", C.FLAT)
	m.bg:SetAllPoints(m)
	m.bg:SetVertexColor(0.03, 0.03, 0.04, 0.95)
	m.edge = C.Tex(m, "BORDER", C.FLAT)
	m.edge:SetPoint("TOPLEFT", m, "TOPLEFT", 0, 0)
	m.edge:SetPoint("BOTTOMLEFT", m, "BOTTOMLEFT", 0, 0)
	m.edge:SetWidth(1)
	m.items = {}
	for i = 1, table.getn(TABS) do
		local tab = TABS[i]
		local b = TextButton(m, tab.name, 112, function()
			db.tab = tab.key
			ShowMenu(false)
			S.offset = 0
			S.readClock = 0
			for key, r in pairs(byKey) do
				r.key, r.entry = nil, nil
				C.Vis(r.frame, false)
				byKey[key] = nil
			end
		end)
		b.text:SetJustifyH("LEFT")
		b:SetPoint("TOPLEFT", m, "TOPLEFT", 4, -4 - (i - 1) * 18)
		m.items[i] = b
	end
	m:Hide()
end

------------------------------------------------------------------------ sizing by any edge
-- Every edge and corner can be dragged: the side under the mouse follows it, the other stays
-- put, the lines that fit show as it goes, and on letting go it settles on whole lines. A little
-- arrow by the mouse shows which way it goes.
local MIN_H, MAX_H = HEAD + MIN_ROWS * ROW + PAD * 2, HEAD + MAX_ROWS * ROW + PAD * 2
-- the sides an edge moves, and its arrow in the sheet (across, up and down, the two diagonals)
local EDGES = {
	LEFT = { l = true, cell = 1 }, RIGHT = { r = true, cell = 1 },
	TOP = { t = true, cell = 2 }, BOTTOM = { b = true, cell = 2 },
	TOPLEFT = { l = true, t = true, cell = 3 }, BOTTOMRIGHT = { r = true, b = true, cell = 3 },
	TOPRIGHT = { r = true, t = true, cell = 4 }, BOTTOMLEFT = { l = true, b = true, cell = 4 },
}
local CELLS = { { 0, 0.5, 0, 0.5 }, { 0.5, 1, 0, 0.5 }, { 0, 0.5, 0.5, 1 }, { 0.5, 1, 0.5, 1 } }
local EDGE, CORNER = 6, 12 -- a grab strip straddling each edge, a square on each corner

local function Cursor(frame)
	local x, y = GetCursorPosition()
	local s = frame:GetEffectiveScale() or 1
	return (x or 0) / s, (y or 0) / s
end

local function CanSize()
	return not db.collapsed and not (CreedUIDB and CreedUIDB.lockWindows)
end

local function StartSizing(edge)
	if not CanSize() then return end
	local l, r, t, b = root:GetLeft(), root:GetRight(), root:GetTop(), root:GetBottom()
	if not (l and r and t and b) then return end
	local x, y = Cursor(root)
	S.sizing = { edge = edge, x = x, y = y, l = l, r = r, t = t, b = b }
	S.settle = nil
	ShowMenu(false)
end

local function StopSizing()
	local z = S.sizing
	if not z then return end
	S.sizing = nil
	-- settle on whole lines: the dragged side moves, the other stays
	local l, t = root:GetLeft(), root:GetTop()
	local h = S.liveH or root:GetHeight()
	S.settle = { fromTop = EDGES[z.edge].t and true or false, l = l, t = t, b = t - h, h = h,
		target = HEAD + db.rows * ROW + PAD * 2 }
	db.rowsSet, db.widthSet = true, true
end

local function PlaceTop(l, t)
	if S.placedL ~= l or S.placedT ~= t then
		S.placedL, S.placedT = l, t
		root:ClearAllPoints()
		root:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l, t)
		root.mpx = nil -- moved under the memo's feet
	end
end

local function StepSizing(dt, mover)
	local z = S.sizing
	if z then
		local e = EDGES[z.edge]
		local x, y = Cursor(root)
		local dx, dy = x - z.x, y - z.y
		local l, r, t, b = z.l, z.r, z.t, z.b
		if e.l then l = C.Clamp(l + dx, r - MAX_W, r - MIN_W) end
		if e.r then r = C.Clamp(r + dx, l + MIN_W, l + MAX_W) end
		if e.t then t = C.Clamp(t + dy, b + MIN_H, b + MAX_H) end
		if e.b then b = C.Clamp(b + dy, t - MAX_H, t - MIN_H) end
		l, t = math.floor(l + 0.5), math.floor(t + 0.5)
		W = math.floor(r - l + 0.5)
		db.width = W
		S.liveH = math.floor(t - b + 0.5)
		db.rows = C.Clamp(math.floor((S.liveH - HEAD - PAD * 2) / ROW), MIN_ROWS, MAX_ROWS)
		PlaceTop(l, t)
		return
	end
	local s = S.settle
	if not s then return end
	s.h = C.Toward(s.h, s.target, 18, dt)
	if s.fromTop then PlaceTop(s.l, s.b + s.h) else PlaceTop(s.l, s.t) end
	S.liveH = s.h
	if s.h == s.target then
		S.settle, S.liveH = nil, nil
		root.mw, root.mh = nil, nil
		C.SavePos(mover)
		S.placedL, S.placedT = nil, nil
	end
end

-- the arrow (the cursor itself where the game lets it be, else drawn by the mouse), and the edges it moves lit
local function StepArrow(pal)
	local edge = (S.sizing and S.sizing.edge) or (CanSize() and S.hover) or nil
	local a = root.arrow
	if edge and C.SizeCursor(root, EDGES[edge].cell) then
		C.Vis(a, false) -- the cursor is the arrow
	elseif edge then
		local x, y = Cursor(UIParent)
		C.Place(a, "CENTER", UIParent, "BOTTOMLEFT", math.floor(x + 15), math.floor(y - 15))
		if a.cell ~= EDGES[edge].cell then
			a.cell = EDGES[edge].cell
			local c = CELLS[a.cell]
			a.tex:SetTexCoord(c[1], c[2], c[3], c[4])
		end
		C.Vis(a, true)
	else
		C.Vis(a, false)
		C.SizeCursorOff(root)
	end
	if S.litEdge ~= edge or S.litStamp ~= C.palStamp then
		S.litEdge, S.litStamp = edge, C.palStamp
		local e, rim = edge and EDGES[edge] or {}, pal.rim
		local lit = { e.t, e.b, e.l, e.r } -- the lines: top, bottom, left, right
		for i = 1, 4 do root.lines[i]:SetVertexColor(rim[1], rim[2], rim[3], lit[i] and 1 or 0.45) end
	end
end

local function NewSizer(edge)
	local h = CreateFrame("Frame", nil, root)
	h.edge = edge
	if edge == "LEFT" or edge == "RIGHT" then
		local x = edge == "LEFT" and "LEFT" or "RIGHT"
		h:SetPoint("TOPLEFT", root, "TOP" .. x, -EDGE / 2, -CORNER / 2)
		h:SetPoint("BOTTOMRIGHT", root, "BOTTOM" .. x, EDGE / 2, CORNER / 2)
	elseif edge == "TOP" or edge == "BOTTOM" then
		h:SetPoint("TOPLEFT", root, edge .. "LEFT", CORNER / 2, EDGE / 2)
		h:SetPoint("BOTTOMRIGHT", root, edge .. "RIGHT", -CORNER / 2, -EDGE / 2)
	else
		h:SetWidth(CORNER)
		h:SetHeight(CORNER)
		h:SetPoint("CENTER", root, edge, 0, 0)
	end
	h:EnableMouse(true)
	h:RegisterForDrag("LeftButton")
	h:SetScript("OnEnter", function() S.hover = this.edge end)
	h:SetScript("OnLeave", function()
		if S.hover == this.edge then S.hover = nil end
		if not S.sizing then C.SizeCursorOff(root) end
	end)
	h:SetScript("OnMouseDown", function() StartSizing(this.edge) end)
	local function Up()
		StopSizing()
		if not S.hover then C.SizeCursorOff(root) end
	end
	h:SetScript("OnMouseUp", Up)
	h:SetScript("OnDragStop", Up)
	-- hidden under the mouse (the window shut, locked, the cards came): the game's cursor back
	h:SetScript("OnHide", function()
		if S.hover == this.edge then S.hover = nil end
		if S.sizing and S.sizing.edge == this.edge then StopSizing() end
		if not S.sizing then C.SizeCursorOff(root) end
	end)
	return h
end

local function BuildSizers()
	root.sizers = {}
	for edge in pairs(EDGES) do root.sizers[edge] = NewSizer(edge) end
	-- the corner keeps its little mark, so the window shows it can be sized
	root.grip = root.sizers.BOTTOMRIGHT
	root.gripTex = C.Tex(root.grip, "OVERLAY", C.ART .. "Caret")
	root.gripTex:SetWidth(10)
	root.gripTex:SetHeight(10)
	root.gripTex:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -1, 1)
	root.gripTex:SetTexCoord(1, 1, 0, 1, 1, 0, 0, 0) -- turned to point into the corner
	local a = CreateFrame("Frame", "CreedUIMeterSizer", UIParent)
	a:SetFrameStrata("TOOLTIP")
	a:SetWidth(22)
	a:SetHeight(22)
	a.tex = C.Tex(a, "OVERLAY", C.ART .. "Resize")
	a.tex:SetAllPoints(a)
	a.tex:SetVertexColor(1, 0.92, 0.66)
	C.Vis(a, false)
	root.arrow = a
end

local function Build()
	root = CreateFrame("Frame", "CreedUIMeter", UIParent)
	root:SetFrameStrata("MEDIUM")
	root:SetWidth(W)
	root:SetHeight(HEAD + db.rows * ROW + PAD * 2)
	root:SetScale(db.scale)
	root:SetMovable(true)
	root:SetResizable(true)
	root:SetClampedToScreen(true)
	root:SetMinResize(MIN_W, HEAD + MIN_ROWS * ROW + PAD * 2)
	root:SetMaxResize(MAX_W, HEAD + MAX_ROWS * ROW + PAD * 2)
	root:EnableMouse(true)
	root:EnableMouseWheel(true)
	root:Hide()
	-- glass, a metal line round it, diamonds at the head's ends
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

	-- the head: the view's name (click for the four), the total per second and the buttons
	root.head = CreateFrame("Button", nil, root)
	root.head:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0)
	root.head:SetPoint("TOPRIGHT", root, "TOPRIGHT", -78, 0)
	root.head:SetHeight(HEAD)
	root.head:RegisterForDrag("LeftButton")
	root.title = C.Text(root.head, C.TITLE_FONT, 14, nil, "LEFT", 150)
	root.title:SetPoint("LEFT", root.head, "LEFT", 9, 0)
	root.caret = C.Tex(root.head, "ARTWORK", C.ART .. "Caret")
	root.caret:SetWidth(9)
	root.caret:SetHeight(9)
	root.caret:SetTexCoord(0, 1, 1, 0) -- pointing down
	root.rate = C.Text(root, C.FONT, 10, nil, "RIGHT", 90)
	root.close = TextButton(root, "x", 16, function()
		db.shown = false
		ShowMenu(false)
		if C.RefreshHub then C.RefreshHub() end
	end, "Click to show or hide it.")
	root.close:SetPoint("RIGHT", root, "TOPRIGHT", -4, -HEAD * 0.5)
	root.fold = TextButton(root, "^", 16, function()
		db.collapsed = not db.collapsed
		ShowMenu(false)
	end, "Fold to the title, or open again")
	root.fold:SetPoint("RIGHT", root.close, "LEFT", -1, 0)
	root.reset = TextButton(root, "Reset", 36, function() Reset() end, "Start this window's count again (the run's totals stay)")
	root.reset:SetPoint("RIGHT", root.fold, "LEFT", -1, 0)
	root.rate:SetPoint("RIGHT", root.reset, "LEFT", -5, 0)

	root.body = CreateFrame("Frame", nil, root)
	root.body:SetPoint("TOPLEFT", root, "TOPLEFT", PAD, -HEAD - 3)
	root.body:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -PAD, PAD)
	root.empty = C.Text(root.body, C.FONT, 10, nil, "CENTER", W - 20)
	root.empty:SetPoint("TOP", root.body, "TOP", 0, -10)
	root.empty:SetTextColor(0.6, 0.58, 0.54)
	root.more = C.Text(root, C.FONT, 9, nil, "RIGHT", 80)
	root.more:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -16, 2)
	root.more:SetTextColor(0.55, 0.53, 0.5)

	BuildSizers()
	BuildMenu()
end

------------------------------------------------------------------------ theme
local function Theme(pal)
	local rim, t = pal.rim, pal.title
	for i = 1, 4 do root.lines[i]:SetVertexColor(rim[1], rim[2], rim[3], 0.45) end
	root.lines[5]:SetVertexColor(rim[1], rim[2], rim[3], 0.3)
	root.gemL:SetVertexColor(rim[1], rim[2], rim[3])
	root.gemR:SetVertexColor(rim[1], rim[2], rim[3])
	root.headBg:SetGradientAlpha("VERTICAL", 0, 0, 0, 0.2, t[1] * 0.25, t[2] * 0.25, t[3] * 0.25, 0.35)
	root.title:SetTextColor(t[1], t[2], t[3])
	root.caret:SetVertexColor(t[1], t[2], t[3])
	root.gripTex:SetVertexColor(rim[1], rim[2], rim[3], 0.7)
	root.menu.edge:SetVertexColor(rim[1], rim[2], rim[3], 0.8)
end

------------------------------------------------------------------------ the tooltip of a line
local function ShowTip(r)
	local e, tab = r.entry, TabOf(db.tab)
	if not (e and GameTooltip) then return end
	GameTooltip:SetOwner(r.frame, "ANCHOR_LEFT")
	local col = ColorOf(e)
	GameTooltip:AddLine(e.name, 0.5 + col[1] * 0.5, 0.5 + col[2] * 0.5, 0.5 + col[3] * 0.5)
	local word = C.L((db.tab == "healing") and "Healing" or "Damage")
	GameTooltip:AddDoubleLine(word, C.Commas(math.floor((e.amount or 0) + 0.5)), 0.8, 0.8, 0.8, 1, 1, 1)
	if e.rate then
		GameTooltip:AddDoubleLine(C.L("Per second"), C.Commas(math.floor(e.rate + 0.5)), 0.8, 0.8, 0.8, 1, 1, 1)
	end
	if e.recent then
		GameTooltip:AddDoubleLine(C.L("Last 10 seconds"), C.Commas(math.floor(e.recent + 0.5)) .. " " .. tab.unit, 0.8, 0.8, 0.8, 1, 1, 1)
	end
	GameTooltip:AddDoubleLine(C.L("Share"), string.format("%.1f%%", (e.share or 0) * 100), 0.8, 0.8, 0.8, 1, 1, 1)
	if e.top then
		GameTooltip:AddDoubleLine(C.L("Best spell"), e.top .. (e.topRate and ("  " .. Amount(e.topRate) .. " dps") or ""), 0.8, 0.8, 0.8, 1, 1, 1)
	end
	if e.proc then GameTooltip:AddLine(C.L("A talent's or amulet's own damage."), 0.55, 0.75, 1, 1) end
	if S.checkpoint or S.base then GameTooltip:AddLine(C.L("Since you pressed Reset."), 0.6, 0.6, 0.6) end
	C.ShowTip()
end

------------------------------------------------------------------------ words that fit
-- `s` cut to its first `n` bytes, never inside a letter
local function CutTo(s, n)
	local t = string.sub(s, 1, n)
	local nextByte = string.byte(s, n + 1)
	if nextByte and nextByte >= 128 and nextByte < 192 then
		while string.len(t) > 0 do
			local b = string.byte(t, string.len(t))
			t = string.sub(t, 1, -2)
			if b < 128 or b >= 192 then break end
		end
	end
	return t
end

-- show `text` in `fs` cut short ("...") to fit `room`; its width, nil while the font isn't ready
local function Fit(fs, text, room)
	C.SetText(fs, text)
	local w = fs:GetStringWidth() or 0
	if w <= 0 then return text == "" and 0 or nil end
	if w <= room then return w end
	local keep = math.floor(string.len(text) * room / w)
	while keep > 0 do
		local t = string.gsub(CutTo(text, keep), "[%s%.:,]+$", "")
		if t == "" then break end
		C.SetText(fs, t .. "...")
		w = fs:GetStringWidth() or 0
		if w <= room then return w end
		keep = string.len(t) - 1
	end
	C.SetText(fs, "")
	return 0
end

-- a line's words on one line: the rank and skill, then a summon's name in a tag and the proc
-- tag. Short of room the summon goes by its last word, then cut short, then not at all; then
-- the skill is cut short. Each width set to its words', so nothing ever wraps.
local function FitWords(r, rank, e, room)
	local procW = 0
	if e.proc then procW = (C.TextWidth(r.procTag) or 18) + 9 end
	local nameW = Fit(r.name, rank .. ". " .. (e.skill or e.name or "?"), room - procW)
	if not nameW then return false end
	C.Width(r.name, nameW + 4)
	local x, petShown = nameW + 6, false
	if e.pet then
		local left = room - procW - x - 4
		local tagW
		if left >= 16 then
			C.SetText(r.petTag, e.pet)
			tagW = r.petTag:GetStringWidth() or 0
			if tagW > left then
				local last = string.gsub(e.pet, "^.*%s", "")
				tagW = Fit(r.petTag, last, left)
			end
		end
		if tagW and tagW > 0 then
			petShown = true
			C.Width(r.petTag, tagW + 4)
			C.Place(r.petTag, "LEFT", r.name, "LEFT", x, 0)
			x = x + tagW + 8
		end
	end
	C.Vis(r.petTag, petShown)
	C.Vis(r.petBox, petShown)
	if e.proc then C.Place(r.procTag, "LEFT", r.name, "LEFT", x, 0) end
	C.Vis(r.procTag, e.proc)
	C.Vis(r.procBox, e.proc)
	return true
end

-- The head on one line: the view's name and its caret on the left; the total per second, then
-- Reset, fold and close on the right. The total always shows whole, clear of the caret: short of
-- room the name goes by a shorter one, then is cut short. The room kept for the total only grows
-- (until the view changes or the total starts again), so the name doesn't flick between its forms
-- as the total ticks.
local HEAD_L, CARET_ROOM, HEAD_GAP = 9, 14, 8
local HEAD_R = 4 + 16 + 1 + 16 + 1 + 36 + 5 -- from the right edge to the total's end: x, ^ and Reset (Build)
local function FitHead(tab)
	if not S.rate or S.rateTab ~= tab.key then S.rateRoom = 0 end
	S.rateTab = tab.key
	local rateW = S.rate and C.TextWidth(root.rate) or 0
	if rateW > S.rateRoom then S.rateRoom = rateW end
	local room = math.floor(W - HEAD_L - CARET_ROOM - HEAD_GAP - S.rateRoom - HEAD_R)
	local key = tab.key .. "|" .. room .. "|" .. C.langStamp
	if S.headKey == key then return end
	local names = { C.L(tab.name) }
	for i = 1, table.getn(tab.short or {}) do names[i + 1] = C.L(tab.short[i]) end
	local w
	for i = 1, table.getn(names) do
		C.SetText(root.title, names[i])
		local tw = root.title:GetStringWidth() or 0
		if tw <= 0 then return end -- the font isn't ready: again next frame
		if tw <= room then
			w = tw
			break
		end
	end
	if not w then w = Fit(root.title, names[table.getn(names)], room) end
	if not w then return end
	S.headKey = key
	C.Place(root.caret, "LEFT", root.title, "LEFT", w > 0 and (w + 5) or 0, -1)
end

------------------------------------------------------------------------ drawing a line
local function StepRow(r, e, rank, slot, max, dt, now)
	local y = (slot - 1) * ROW
	C.Width(r.frame, W - 2 * PAD)
	if not r.y then r.y = y + 6 end
	r.y, r.yv = C.Spring(r.y, r.yv, y, 14, dt)
	if math.abs(r.y - y) < 0.05 and math.abs(r.yv) < 0.05 then r.y, r.yv = y, 0 end
	C.Place(r.frame, "TOPLEFT", root.body, "TOPLEFT", 0, -r.y)
	r.alpha = C.Toward(r.alpha, 1, 8, dt)
	if r.alpha > 0.995 then r.alpha = 1 end
	C.Alpha(r.frame, C.Smooth(r.alpha))
	C.Vis(r.frame, true)

	-- the bar, as far as its share of the top line, gliding there
	local target = max > 0 and C.Clamp((e.amount or 0) / max, 0, 1) or 0
	local b = r.bar
	if b.snap then b.value, b.vel, b.snap = target, 0, nil end
	b.value, b.vel = C.Spring(b.value, b.vel, target, 12, dt)
	if math.abs(b.value - target) < 0.001 and math.abs(b.vel) < 0.005 then b.value, b.vel = target, 0 end
	local full = W - 2 * PAD - ROW
	local fw = math.max(0, b.value * full)
	C.Width(r.fill, math.max(1, fw))
	C.Vis(r.fill, fw >= 1)
	C.Vis(r.gloss, fw >= 1)
	local col = ColorOf(e)
	if r.colR ~= col[1] or r.colG ~= col[2] or r.colB ~= col[3] then
		r.colR, r.colG, r.colB = col[1], col[2], col[3]
		r.fill:SetGradientAlpha("HORIZONTAL", col[1] * 0.45, col[2] * 0.45, col[3] * 0.45, 0.85, col[1], col[2], col[3], 0.85)
	end

	-- the icon: the spell's, or a hero's portrait
	local look = e.portrait and ("portrait:" .. e.portrait) or (e.icon or (db.tab ~= "party" and QUESTION) or "class")
	if r.look ~= look then
		r.look = look
		if e.portrait and S.runId then
			local ok, set = false, nil
			if type(AZS_SetMeterPortrait) == "function" then ok, set = pcall(AZS_SetMeterPortrait, r.icon, S.runId, e.portrait) end
			if not (ok and set) then r.icon:SetTexture(C.ART .. "Gem") end
			r.icon:SetTexCoord(0, 1, 0, 1)
			r.icon:SetVertexColor(1, 1, 1)
		elseif look == "class" then
			r.icon:SetTexture(C.ART .. "Gem")
			r.icon:SetTexCoord(0, 1, 0, 1)
			local cc = e.color or { 0.7, 0.7, 0.7 }
			r.icon:SetVertexColor(cc[1], cc[2], cc[3])
		else
			r.icon:SetTexture(look)
			r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
			r.icon:SetVertexColor(1, 1, 1)
		end
	end

	-- the words: rank and name, then amount (per second, share)
	r.shown = r.shown + ((e.amount or 0) - r.shown) * (1 - math.exp(-dt * 10))
	if math.abs((e.amount or 0) - r.shown) < 1 then r.shown = e.amount or 0 end
	local cc = (db.tab == "party" and e.color) or nil
	if cc then
		C.TextColor(r.name, 0.4 + cc[1] * 0.6, 0.4 + cc[2] * 0.6, 0.4 + cc[3] * 0.6)
	elseif e.pet then
		C.TextColor(r.name, 1, 0.86, 0.6) -- a summon's line in its tag's gold, even when the tag finds no room
	else
		C.TextColor(r.name, 1, 0.97, 0.92)
	end
	local shownR = math.floor(r.shown + 0.5)
	if r.tShown ~= shownR or r.tRate ~= e.rate or r.tShare ~= e.share then
		r.tShown, r.tRate, r.tShare = shownR, e.rate, e.share
		local detail = (e.rate and Amount(e.rate) .. ", " or "") .. string.format("%.0f%%", (e.share or 0) * 100)
		C.SetText(r.value, Amount(shownR) .. " |cffa59f94(" .. detail .. ")|r")
	end
	-- the words on one line, made again only when they or the room for them change
	local room = math.floor(((W - 2 * PAD) - (ROW + 4) - C.TextWidth(r.value) - 8) / 6) * 6
	local key = rank .. "|" .. (e.skill or e.name or "?") .. "|" .. (e.pet or "") .. (e.proc and "|p|" or "||") .. room
	if r.fitKey ~= key then
		r.fitKey = key
		if not FitWords(r, rank, e, room) then r.fitKey = nil end -- the font wasn't ready: again next frame
	end
end

------------------------------------------------------------------------ every frame
local function Layout()
	local h = db.collapsed and HEAD or (S.liveH or (HEAD + db.rows * ROW + PAD * 2))
	C.Size(root, W, h)
	C.Width(root.empty, W - 20)
	C.Vis(root.body, not db.collapsed)
	local sizable = CanSize()
	for _, z in pairs(root.sizers) do C.Vis(z, sizable) end
	if not sizable then S.hover = nil end
	C.Vis(root.lines[5], not db.collapsed)
	C.SetText(root.fold.text, db.collapsed and "v" or "^")
end

local function StepRows(dt, now)
	for key, r in pairs(byKey) do r.seen = false end
	local n, first = S.n, S.offset + 1
	local last = math.min(n, S.offset + db.rows)
	local max = n > 0 and (S.list[1].amount or 0) or 0
	for i = first, last do
		local e = S.list[i]
		local r = byKey[e.key]
		if not r then
			for j = 1, table.getn(rows) do
				if not rows[j].key then
					r = rows[j]
					break
				end
			end
			if not r then
				r = NewRow()
				table.insert(rows, r)
				S.levelled = false
				if S.drag then S.drag.handle(r.frame) end
			end
			r.key, r.y, r.yv, r.alpha, r.shown, r.look = e.key, nil, 0, 0, e.amount or 0, nil
			r.colR, r.tRank, r.tName, r.tShown, r.fitKey = nil, nil, nil, nil, nil
			r.bar.snap = true
			byKey[e.key] = r
		end
		r.seen, r.entry = true, e
		StepRow(r, e, i, i - S.offset, max, dt, now)
	end
	for key, r in pairs(byKey) do
		if not r.seen then
			byKey[key] = nil
			r.key, r.entry = nil, nil
			C.Vis(r.frame, false)
		end
	end
	local tab = TabOf(db.tab)
	C.SetText(root.empty, C.L(S.emptyText or tab.empty))
	C.Vis(root.empty, n == 0)
	local hidden = n - last
	if S.hiddenShown ~= hidden then
		S.hiddenShown = hidden
		C.SetText(root.more, hidden > 0 and C.F("+{1} more", hidden) or "")
	end
end

local function Step(dt)
	local now = GetTime()
	local phase = Call(AZS_GetPhase)
	local want = ((db.enabled and db.shown and phase ~= nil) or (db.enabled and C.unlocked)) and not C.cardsUp
	S.alpha = C.Toward(S.alpha, want and 1 or 0, 8, dt)
	if want and S.alpha > 0.995 then S.alpha = 1 end
	if S.alpha < 0.01 and not want then
		C.Vis(root, false)
		ShowMenu(false)
		return
	end
	C.Vis(root, true)
	C.Alpha(root, C.Smooth(S.alpha))
	if not S.levelled then
		S.levelled = true
		local base = root:GetFrameLevel()
		root.head:SetFrameLevel(base + 2)
		root.body:SetFrameLevel(base + 1)
		for i = 1, table.getn(rows) do rows[i].frame:SetFrameLevel(base + 2) end
		for _, z in pairs(root.sizers) do z:SetFrameLevel(base + 4) end
	end
	local pal = C.Pal()
	if S.stamp ~= C.palStamp then
		S.stamp = C.palStamp
		Theme(pal)
	end
	StepSizing(dt, S.mover)
	StepArrow(pal)
	Layout()
	local tab = TabOf(db.tab)

	S.readClock = S.readClock - dt
	if S.readClock <= 0 then
		S.readClock = READ_EVERY
		Read()
		if S.offset > math.max(0, S.n - db.rows) then S.offset = math.max(0, S.n - db.rows) end
	end
	if S.rateShown ~= S.rate or S.rateUnit ~= tab.unit then
		S.rateShown, S.rateUnit = S.rate, tab.unit
		C.SetText(root.rate, S.rate and (Amount(S.rate) .. " " .. tab.unit) or "")
	end
	C.TextColor(root.rate, 1, 0.9, 0.62)
	FitHead(tab)
	if not db.collapsed then StepRows(dt, now) end
	if S.tipRow then
		S.tipClock = (S.tipClock or 0) - dt
		if S.tipClock <= 0 then
			S.tipClock = 0.25
			ShowTip(S.tipRow)
		end
	end
end

------------------------------------------------------------------------ setup
local function Anchor(f)
	f:ClearAllPoints()
	if CreedUILuck then
		f:SetPoint("BOTTOMRIGHT", CreedUILuck, "TOPRIGHT", 0, 8)
	else
		f:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -58, 282)
	end
end

local function SetEnabled(on)
	db.enabled = on and true or false
	if db.enabled then
		db.shown = true
		C.TakeHud("meter")
	else
		C.ReleaseHud("meter")
	end
end

local function Scripts(mover)
	-- drag it by its title or anywhere on it (the lines too)
	local drag = C.Draggable(root, mover)
	drag.onStart = function() ShowMenu(false) end
	drag.handle(root.head)
	S.drag = drag
	for i = 1, table.getn(rows) do drag.handle(rows[i].frame) end
	root.head:SetScript("OnClick", function()
		if GetTime() - drag.endedAt < 0.25 then return end -- the end of a drag, not a click
		ShowMenu(not S.menuOpen)
	end)
	S.mover = mover -- the edges save the place they leave it in
	root:SetScript("OnMouseWheel", function()
		if not arg1 then return end
		local top = math.max(0, S.n - db.rows)
		S.offset = C.Clamp(S.offset - (arg1 > 0 and 1 or -1), 0, top)
	end)
end

C.OnInit(function()
	db = C.DB("meter", DEFAULTS)
	db.edgeAngle = nil -- the former minimap toggle now lives in Creed UI Options
	if type(db.colors) ~= "table" then db.colors = {} end
	local count = 0
	for _ in pairs(db.colors) do count = count + 1 end
	if count > 300 then db.colors, db.colorNext = {}, 0 end -- a fresh start once very many have been seen
	if not db.rowsSet then db.rows = DEFAULTS.rows end
	if not db.widthSet then db.width = DEFAULTS.width end
	W = C.Clamp(tonumber(db.width) or DEFAULTS.width, MIN_W, MAX_W)
	db.rows = C.Clamp(tonumber(db.rows) or DEFAULTS.rows, MIN_ROWS, MAX_ROWS)
	if not TabOf(db.tab) or TabOf(db.tab).key ~= db.tab then db.tab = "damage" end
	Build()
	local mover = C.Movable(root, "meter", "Damage meter", Anchor)
	C.OverCards(root) -- lit over the level-up cards' veil (Core)
	Scripts(mover)
	local driver = CreateFrame("Frame", "CreedUIMeterDriver")
	local broken = false
	driver:SetScript("OnUpdate", function()
		if broken then return end
		local dt = arg1 or 0
		if dt > 0.1 then dt = 0.1 end
		local ok, err = pcall(Step, dt)
		if not ok then
			broken = true
			C.ReleaseHud("meter")
			root:Hide()
			C.Print(C.L("the damage meter stopped after an error, so the game's own is back: ") .. tostring(err))
			return
		end
		S.takeClock = (S.takeClock or 0) - dt
		if S.takeClock <= 0 then
			S.takeClock = 2
			if db.enabled then C.TakeHud("meter") end
		end
	end)
end)

C.OnWorld(function()
	if not db then return end
	if db.enabled then C.TakeHud("meter") end
	S.checkpoint, S.base, S.baseAt = nil, nil, nil -- a new world ends the game's checkpoints
	for i = 1, table.getn(C.movers) do
		if C.movers[i].frame == root then C.ApplyPos(C.movers[i]) end
	end
end)

C.OnLogout(function()
	if db then C.ReleaseHud("meter") end
end)

C.meterToggle = function()
	if db then
		if not db.enabled then SetEnabled(true) else db.shown = not db.shown end
		if C.RefreshHub then C.RefreshHub() end
	end
end

C.RegisterPart({
	key = "meter", name = "Damage meter",
	note = "Damage Done, Healing Done, Boss Damage and Party DPS with icons, per second and shares; Reset counts again in this window only. Drag the title to move it, the corner to resize. Use the Damage meter toggle in Creed UI Options to show or hide it; while enabled, it replaces the game's meter window.",
	get = function() return db and db.enabled and db.shown end,
	set = function(on)
		if db then
			if on then SetEnabled(true) else db.shown = false end
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
