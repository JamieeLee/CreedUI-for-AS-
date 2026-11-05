-- 1.14.3: a Scholomance run: the timer in its new look, the meter with every pet's skills on one
-- Pet line, and red numbers by the hero for the blows just taken. Writes out/pet.txt.
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
M.runTime = 330
SIM.Publish()
local I = "Interface\\Icons\\"
M.meter = { damage = {
	{ key = "arcane", name = "Arcane Shot", icon = I .. "Ability_ImpalingBolt", amount = 18400 },
	{ key = "multi", name = "Multi-Shot", icon = I .. "Ability_UpgradeMoonGlaive", amount = 12100 },
	{ key = "auto", name = "Auto Shot", icon = I .. "Ability_Whirlwind", amount = 7300 },
	{ key = "bite", name = "Bite", amount = 6200, actor = { id = "P1", kind = "pet", name = "Wolf", summonKey = "wolf" } },
	{ key = "kc", name = "Kill Command", amount = 4100, actor = { id = "P1", kind = "pet", name = "Wolf", summonKey = "wolf" } },
	{ key = "melee", name = "Melee", amount = 2600, actor = { id = "P1", kind = "pet", name = "Wolf", summonKey = "wolf" } },
} }
AZS_TAKEN = {}
AZS_HEALING = {}
SIM.Advance(2, 1 / 30)
AZS_TAKEN = { { source = "Risen Construct", dmg = 420 } }
SIM.Advance(0.5, 1 / 30)
AZS_TAKEN = { { source = "Risen Construct", dmg = 420 }, { source = "Kirtonos the Herald", dmg = 1650 } }
SIM.Advance(0.35, 1 / 30)
AZS_TAKEN[1].dmg = 610
AZS_HEALING = { { name = "Lifesteal", dmg = 380 } }
SIM.Advance(0.25, 1 / 30)
M.Dump(OUT .. "/pet.txt")
print("problems: " .. table.getn(M.problems))
for i = 1, math.min(5, table.getn(M.problems)) do print(M.problems[i]) end
