-- Simulates an Azeroth Survivors run for the mock: the zone, the schedule's states, the alive
-- bosses with draining health, AZS_RUN's countdown fields, phases and endless mode.

SIM = {}
local M = MOCK

SIM.ZONES = {
	elwynn = { "Elwynn Forest", "The Defias Uprising", 960, { 180, "Hogger", 360, "Mother Fang", 540, "Rhahk'Zor", 720, "Mr. Smite", 960, "Edwin VanCleef" } },
	duskwood = { "Duskwood", "Night of the Nightbane", 960, { 180, "Naraxis", 360, "Mor'Ladim", 540, "Stitches", 720, "Lupos", 960, "Morbent Fel" } },
	wsg = { "Warsong Gulch", "The Burning Legion", 960, { 180, "Doomguard Commander", 360, "Mannoroth's Herald", 540, "Varimathras", 720, "Lord Hel'nurath", 960, "Lord Kazzak" } },
	ungoro = { "Un'Goro Crater", "The Primal Hunt", 960, { 180, "Ravasaur Matriarch", 360, "Uhk'loc", 540, "Lar'korwi", 720, "Tyrant Devilsaur", 960, "King Mosh" } },
	ab = { "Arathi Basin", "The Highlands Rise", 1080, { 240, "Kovork", 420, "Nimar the Slayer", 660, "Marez Cowl", 840, "Lord Falconcrest", 1080, "Lord Aliden Perenolde" } },
	feralas = { "Feralas", "The Gates of Dire Maul", 1080, { 240, "Zevrim Thornhoof", 420, "Alzzin the Wildshaper", 660, "Tendris Warpwood", 840, "Immol'thar", 1080, "King Gordok" } },
	arena = { "Gurubashi Arena", "The Blood God Wakes", 1080, { 240, "High Priestess Jeklik", 420, "High Priest Venoxis", 660, "Bloodlord Mandokir", 840, "Jin'do the Hexxer", 1080, "Hakkar the Soulflayer" } },
	sm = { "Scarlet Monastery", "The Crusade's Last Stand", 1080, { 240, "Houndmaster Loksey", 420, "Arcanist Doan", 660, "Herod", 840, "Scarlet Commander Mograine", 1080, "High Inquisitor Whitemane" } },
	av = { "Alterac Valley", "The Frozen Wilds", 1200, { 240, "Korrak the Bloodrager", 480, "Ivus the Forest Lord", 720, "Lokholar the Ice Lord", 960, "Glacius the Frozen Titan", 1200, "Azuregos" } },
	brm = { "Blackrock Mountain", "The Lord of Blackrock", 1200, { 240, "General Angerforge", 480, "Warchief Rend Blackhand", 720, "Emperor Dagran Thaurissan", 960, "Majordomo Executus", 1200, "Nefarian" } },
	aq = { "Gates of Ahn'Qiraj", "The Old God Stirs", 1200, { 240, "Kurinnaxx", 480, "General Rajaxx", 720, "Princess Huhuran", 960, "Ossirian the Unscarred", 1200, "C'Thun" } },
	scholomance = { "Scholomance", "The Great Ossuary", 1200, { 240, "Kirtonos the Herald", 480, "Ras Frostwhisper", 720, "Doctor Theolen Krastinov", 960, "Lord Alexei Barov", 1200, "Darkmaster Gandling" } },
	naxx = { "Naxxramas", "The Scourge Invasion", 1200, { 240, "Anub'Rekhan", 480, "Noth the Plaguebringer", 720, "Patchwerk", 960, "Sapphiron", 1200, "Kel'Thuzad" } },
}

local function Copy(list)
	local out = {}
	for i = 1, table.getn(list) do out[i] = list[i] end
	return out
end

-- killAfter: how long each boss lives; names: optional replacement names (another language)
function SIM.StartRun(key, opts)
	opts = opts or {}
	local z = SIM.ZONES[key]
	local info = { key = key, len = z[3], bosses = {}, kill = opts.killAfter or 25, t = opts.t or 0 }
	for i = 1, table.getn(z[4]), 2 do
		local name = z[4][i + 1]
		if opts.names then name = opts.names[(i + 1) / 2] end
		table.insert(info.bosses, { at = z[4][i], name = name, state = "due", hp = 1, hpm = 100000 })
	end
	SIM.run = info
	M.runId = (M.runId or 0) + 1
	AZS_ZONE = { zone = key, zname = z[1], zsub = z[2], len = z[3], bt = table.getn(info.bosses), heroic = opts.heroic or 0,
		affixes = opts.affixes or "", run = M.runId }
	AZS_ZONE_UPDATED = M.now
	M.phase = "playing"
	M.runTime = info.t
	M.runLength = z[3]
	SIM.Publish()
end

function SIM.Publish()
	local info = SIM.run
	local t = M.runTime
	local sched = {}
	M.bosses = {}
	local bs, bk, nb, nbn = 0, 0, -1, ""
	for i = 1, table.getn(info.bosses) do
		local b = info.bosses[i]
		sched[i] = { index = i, at = b.at, name = b.name, final = (i == table.getn(info.bosses)) and 1 or 0, state = b.state }
		if b.state ~= "due" then bs = bs + 1 end
		if b.state == "dead" then bk = bk + 1 end
		if b.state == "up" then
			table.insert(M.bosses, { name = b.name, hp = b.hp * b.hpm, hpm = b.hpm, final = i == table.getn(info.bosses), enraged = b.hp < 0.3 })
		end
		if b.state == "due" and nb < 0 then
			nb = math.max(0, math.floor(b.at - t))
			nbn = b.name
		end
	end
	if not SIM.hideSchedule then AZS_SCHEDULE = sched end
	AZS_RUN = { t = t, ph = M.phase, bs = bs, bt = table.getn(info.bosses), bk = bk, nb = nb, nbn = nbn, fin = info.len,
		left = math.max(-1, info.len - t), endl = info.endless and 1 or 0, won = info.won and 1 or 0 }
	if info.endless then
		AZS_RUN.nb = info.endNb and math.max(0, math.floor(info.endNb)) or -1
		AZS_RUN.nbn = ""
	end
end

-- advance the run: seconds of game time, in frames of dt
function SIM.Advance(seconds, dt, each)
	dt = dt or (1 / 60)
	local info = SIM.run
	local steps = math.floor(seconds / dt + 0.5)
	local acc = 0
	for s = 1, steps do
		if M.phase == "playing" then
			M.runTime = M.runTime + dt
			local t = M.runTime
			for i = 1, table.getn(info.bosses) do
				local b = info.bosses[i]
				if b.state == "due" and t >= b.at + 0.3 then
					b.state, b.hp, b.born = "up", 1, t
				elseif b.state == "up" then
					b.hp = math.max(0, 1 - (t - b.born) / info.kill)
					if b.hp <= 0 then
						b.state = "dead"
						if i == table.getn(info.bosses) then info.won = true end
					end
				end
			end
			if info.endless then
				info.endNb = (info.endNb or info.endEvery) - dt
				if info.endNb <= 0 then info.endNb = info.endEvery end
			end
		end
		acc = acc + dt
		if acc >= 0.2 then -- the server publishes five times a second
			acc = 0
			SIM.Publish()
		end
		M.Frame(dt)
		if each then each(s) end
	end
end

function SIM.Endless(every)
	local info = SIM.run
	info.endless = true
	info.endEvery = every or 60
	info.endNb = info.endEvery
	M.phase = "playing"
	SIM.Publish()
end
