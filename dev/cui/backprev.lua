-- 1.20.0: crit numbers on each backdrop, each in one of Creed UI's own fonts. Writes out/back_<name>.txt.
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
SIM.Advance(1, 1 / 30)
local looks = { { "blood", "creepster" }, { "fire", "bangers" }, { "frost", "cinzel" }, { "arcane", "uncial" }, { "holy", "pirata" }, { "shadow", "black" } }
for i, look in ipairs(looks) do
	M.Slash("numbers backdrop " .. look[1])
	M.Slash("numbers font " .. look[2])
	local e = M.Enemy("Dummy " .. i, 0, 2)
	M.Hit(e, 12345 + i * 1111, "strike", false, true)
	SIM.Advance(0.3, 1 / 30)
	M.Dump(OUT .. "/back_" .. look[1] .. ".txt")
	SIM.Advance(4, 1 / 30)
end
print("problems: " .. table.getn(M.problems))
