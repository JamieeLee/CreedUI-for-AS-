-- 1.15.0 (1.16.1: each summon's own face, each skill what it hits for): the pet bar over the skill bar's left end (Spirit Wolves out, with the skills the meter saw
-- them use), and a gold chest over a cache on the field. Writes out/petbar.txt.
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
M.summons = { { id = 1, key = "spirit_wolf", kind = "pet", name = "Spirit Wolf", icon = I .. "Spell_Nature_SpiritWolf" },
	{ id = 2, key = "spirit_wolf", kind = "pet", name = "Spirit Wolf", icon = I .. "Spell_Nature_SpiritWolf" },
	{ id = 4, key = "raptor", kind = "pet", name = "Raptor", icon = I .. "INV_Misc_QuestionMark" },
	{ id = 5, key = "imp", kind = "imp", name = "Imp", icon = I .. "INV_Misc_QuestionMark" },
	{ id = 3, key = "infernal", kind = "infernal", name = "Infernal", icon = I .. "Spell_Shadow_SummonInfernal" } }
local wolf = { id = "P1", kind = "pet", name = "Spirit Wolf", summonKey = "spirit_wolf" }
M.meter = { damage = {
	{ key = "ls", name = "Lightning Bolt", icon = I .. "Spell_Nature_Lightning", amount = 15200 },
	{ key = "bite", name = "Bite", icon = I .. "Ability_Racial_Cannibalize", amount = 4100, actor = wolf },
	{ key = "howl", name = "Furious Howl", icon = I .. "Ability_Hunter_Pet_Wolf", amount = 2300, actor = wolf },
	{ key = "immo", name = "Immolation", icon = I .. "Spell_Shadow_RainOfFire", amount = 3100,
		actor = { id = "P3", kind = "infernal", name = "Infernal", summonKey = "infernal" } },
} }
AZS_CHESTS = { { id = 7, x = 100, y = 170, z = 0, mx = -1, my = -1 } }
AZS_CHESTS_UPDATED = M.now
local foe = M.Enemy("Ghoul", 2, 4)
for _, h in ipairs({ { 48712, "bite", "Bite" }, { 5868, "howl", "Furious Howl" }, { 9784, "immo", "Immolation" }, { 2204, "raptor_strike", "Raptor Strike" } }) do
	M.Hit(foe, h[1], "strike", false)
	local ev = M.world.events[M.world.nEvents]
	ev.meterSourceKey, ev.meterSource = h[2], h[3]
end
SIM.Advance(2, 1 / 30)
M.Dump(OUT .. "/petbar.txt")
print("problems: " .. table.getn(M.problems))
for i = 1, math.min(5, table.getn(M.problems)) do print(M.problems[i]) end
