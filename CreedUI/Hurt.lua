-- Creed UI: damage taken, by the hero.
-- What hits you rises beside your hero as red numbers: each new hit from the game's own
-- damage-taken list (the one the meter's Damage Taken tab reads), a few blows at a time gathered
-- into one number, bigger and brighter for a heavy one. They hide behind the level-up cards and
-- out of a run. The health you get back (heals, life drained) rises the same way in green on the
-- hero's other side. Off, nothing shows.

local C = CreedUI
local DEFAULTS = { enabled = true, scale = 1 }
local K = {
	gather = 0.15, -- seconds of blows gathered into one number
	life = 1.3, rise = 58, drift = -16, -- seconds shown, and how far it floats up and aside
	x = -64, y = 34, -- from the middle of the screen, where the camera keeps the hero
	size = 15, big = 24, max = 10,
}

local db
local root
local S = { seen = {}, healSeen = {}, healPending = 0, primed = false, gather = 0, pending = 0, pool = {}, live = {}, broken = false, maxHp = 1 }

local function Phase()
	if type(AZS_GetPhase) ~= "function" then return nil end
	local ok, phase = pcall(AZS_GetPhase)
	return ok and phase or nil
end

-- what is new on one of the game's lists since the last look: the damage taken ({ source, dmg })
-- or the healing got ({ name, dmg })
local function NewOn(list, field, seenKey)
	list = type(list) == "table" and list or {}
	local fresh, add, now = {}, 0, {}
	for i = 1, table.getn(list) do
		local l = list[i]
		local dmg = type(l) == "table" and tonumber(l.dmg)
		if dmg and l[field] ~= nil then
			local key = tostring(l[field])
			now[key] = (now[key] or 0) + dmg
		end
	end
	local seen = S[seenKey]
	for key, dmg in pairs(now) do
		local was = seen[key] or 0
		if dmg > was then add = add + (dmg - was) end
		fresh[key] = dmg
	end
	S[seenKey] = fresh
	return add
end

local function NewDamage() return NewOn(AZS_TAKEN, "source", "seen") end
local function NewHealing() return NewOn(AZS_HEALING, "name", "healSeen") end

local function Number()
	local n = table.remove(S.pool)
	if n then return n end
	n = C.Text(root, C.FONT, K.size, "OUTLINE", "CENTER", 120)
	return n
end

local function Spawn(amount, now, heal)
	if table.getn(S.live) >= K.max then
		local old = table.remove(S.live, 1)
		C.Vis(old.text, false)
		table.insert(S.pool, old.text)
	end
	local hp = math.max(1, S.maxHp)
	local heavy = math.min(1, amount / (hp * 0.15)) -- a fifth of your health or so is a heavy blow
	local text = Number()
	local n = table.getn(S.live)
	table.insert(S.live, { text = text, t0 = now, heavy = heavy, lane = math.mod(n, 3) - 1, side = heal and -1 or 1 })
	if heal then
		C.SetText(text, "+" .. C.Short(amount))
		C.TextColor(text, 0.36 - 0.1 * heavy, 1, 0.42 - 0.12 * heavy)
	else
		C.SetText(text, "-" .. C.Short(amount))
		C.TextColor(text, 1, 0.30 - 0.12 * heavy, 0.22 - 0.1 * heavy)
	end
	C.Vis(text, true)
end

local function Step(dt, now)
	local phase = Phase()
	if phase ~= "playing" and phase ~= "choosing" and phase ~= "paused" then
		-- out of a run: forget what was seen, so the next run starts clean
		S.seen, S.pending, S.primed = {}, 0, false
		S.healSeen, S.healPending = {}, 0
		for i = table.getn(S.live), 1, -1 do
			local l = table.remove(S.live, i)
			C.Vis(l.text, false)
			table.insert(S.pool, l.text)
		end
		C.Vis(root, false)
		return
	end
	if not S.primed then
		S.primed = true
		NewDamage() -- what was already there when the run (or a /reload) began is old news
		NewHealing()
		S.pending, S.healPending = 0, 0
	end
	S.maxHp = tonumber(UnitHealthMax and UnitHealthMax("player")) or S.maxHp
	S.pending = S.pending + NewDamage()
	S.healPending = S.healPending + NewHealing()
	S.gather = S.gather - dt
	if S.gather <= 0 then
		S.gather = K.gather
		if S.pending >= 1 then Spawn(S.pending, now) end
		if S.healPending >= 1 then Spawn(S.healPending, now, true) end
		S.pending, S.healPending = 0, 0
	end
	C.Vis(root, true)
	C.Alpha(root, 1 - C.cardsFade)
	for i = table.getn(S.live), 1, -1 do
		local l = S.live[i]
		local age = (now - l.t0) / K.life
		if age >= 1 then
			table.remove(S.live, i)
			C.Vis(l.text, false)
			table.insert(S.pool, l.text)
		else
			local pop = 1 + 0.5 * (1 - C.Smooth(age / 0.12))
			local size = math.floor((K.size + (K.big - K.size) * l.heavy) * pop + 0.5)
			if l.text.hurtSize ~= size then
				l.text.hurtSize = size
				C.SetFace(l.text, C.FONT, size, "OUTLINE")
			end
			-- damage on the hero's left, drifting left; healing on the right, drifting right
			C.Place(l.text, "CENTER", root.spot, "CENTER", l.side * (K.x + K.drift * age) + 14 * l.lane, K.rise * C.Smooth(age))
			C.Alpha(l.text, 1 - C.Smooth((age - 0.6) / 0.4))
		end
	end
end

local function Apply()
	if not db.enabled then
		for i = table.getn(S.live), 1, -1 do
			local l = table.remove(S.live, i)
			C.Vis(l.text, false)
			table.insert(S.pool, l.text)
		end
		C.Vis(root, false)
		S.primed = false
	end
end

C.OnInit(function()
	db = C.DB("hurt", DEFAULTS)
	root = CreateFrame("Frame", "CreedUIHurt", UIParent)
	root:SetAllPoints(UIParent)
	root:SetFrameStrata("LOW")
	root:SetScale(db.scale)
	C.Vis(root, false)
	-- where the numbers rise from: by the hero at first, and wherever it is dragged (frames unlocked)
	root.spot = CreateFrame("Frame", "CreedUIHurtSpot", UIParent)
	root.spot:SetWidth(-2 * K.x + 60)
	root.spot:SetHeight(40)
	root.spot:SetScale(db.scale)
	C.Movable(root.spot, "hurt", "Damage taken", function(f)
		f:ClearAllPoints()
		f:SetPoint("CENTER", UIParent, "CENTER", 0, K.y)
	end)
	local driver = CreateFrame("Frame", "CreedUIHurtDriver")
	driver:SetScript("OnUpdate", function()
		if S.broken or not db.enabled then return end
		local dt = arg1 or 0
		if dt > 0.1 then dt = 0.1 end
		local ok, err = pcall(Step, dt, GetTime())
		if not ok then
			S.broken = true
			db.enabled = false
			Apply()
			db.enabled = true
			C.Print(C.L("the damage you take stopped showing after an error: ") .. tostring(err))
		end
	end)
	Apply()
end)

C.RegisterPart({
	key = "hurt", name = "Damage taken",
	note = "What hits you rises beside your hero as red numbers, heavier blows bigger; the health you get back rises in green on the other side.",
	get = function() return db and db.enabled end,
	set = function(on)
		if db then
			db.enabled = on and true or false
			S.broken = false
			Apply()
		end
	end,
	getScale = function() return db and db.scale or 1 end,
	setScale = function(v)
		if db then
			db.scale = v
			root:SetScale(v)
			root.spot:SetScale(v)
		end
	end,
})
