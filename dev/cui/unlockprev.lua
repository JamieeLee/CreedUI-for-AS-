-- 1.17.1: the frames unlocked: every part's box to drag, the chat's with its corner grip, and the
-- spot the hero's damage and heal numbers rise from. Writes out/unlock.txt.
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
M.runTime = 60
SIM.Publish()
M.summons = { { id = 1, key = "imp", kind = "imp", name = "Imp" } }
SIM.Advance(1, 1 / 30)
CreedUI.SetUnlocked(true)
SIM.Advance(0.3, 1 / 30)
M.Dump(OUT .. "/unlock.txt")
print("problems: " .. table.getn(M.problems))
