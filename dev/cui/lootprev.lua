-- 1.19.0: the loot pop-up: a drop new to the collection, one already had, and marks. Writes out/loot.txt.
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
M.runTime = 300
SIM.Publish()
SIM.Advance(0.5, 1 / 30)
ChatFrame1:AddMessage("You receive loot: [Gravecaller's Signet] Already collected")
SIM.Advance(0.4, 1 / 30)
ChatFrame1:AddMessage("You earn 12 marks (356 in all).")
SIM.Advance(0.4, 1 / 30)
ChatFrame1:AddMessage("You receive loot: [Novice's Boots] New in your collection!")
SIM.Advance(0.6, 1 / 30)
M.Dump(OUT .. "/loot.txt")
print("problems: " .. table.getn(M.problems))
