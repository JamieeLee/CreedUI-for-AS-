-- 1.16.0: three Blizzards and two Searing Totems counted on their slots, Party DPS with each hero's
-- best skill, and the damage numbers' options with the new Motion row. Writes out/counts.txt.
MOCK_SCRATCH = arg[1]
local DIR, OUT = arg[2], arg[3]
dofile(MOCK_SCRATCH .. "/cui/mock_cui.lua")
dofile(MOCK_SCRATCH .. "/bt/sim.lua")
local M = MOCK
M.InstallAPI()
M.phase = "ready"
M.Load(DIR)
for i = 1, 20 do M.Frame(1 / 30) end
SIM.StartRun("scholomance", { killAfter = 120 })
M.runTime = 200
SIM.Publish()
local I = "Interface\\Icons\\"
M.actions[1] = { tex = I .. "Spell_Frost_IceStorm", start = 0, dur = 0 }
M.actions[2] = { tex = I .. "Spell_Fire_SearingTotem", start = 0, dur = 0 }
M.totems = { { key = "searing", icon = I .. "Spell_Fire_SearingTotem", count = 2, cap = 3 } }
M.meter = { damage = {}, party = { { key = "H1", name = "Creed", class = "mage", amount = 21000 }, { key = "H2", name = "Melkor", class = "shaman", amount = 15500 } },
	partySkills = { { owner = "H1", key = "bz", name = "Blizzard", amount = 12000 }, { owner = "H2", key = "ch", name = "Chain Lightning", amount = 9000 } } }
CreedUIDB.meter.tab = "party"
for k = 1, 3 do
	M.actions[1].start, M.actions[1].dur = M.now, 2
	SIM.Advance(2.1, 1 / 30)
end
M.Slash("numbers")
CreedUIDB.numbers.motion = "fountain"
SIM.Advance(0.3, 1 / 30)
M.Dump(OUT .. "/counts.txt")
print("problems: " .. table.getn(M.problems))
for i = 1, math.min(5, table.getn(M.problems)) do print(M.problems[i]) end
