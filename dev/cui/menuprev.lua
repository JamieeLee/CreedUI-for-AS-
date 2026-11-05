-- 1.18.0: a right click on a friend's frame: Inspect, Follow, Whisper. Writes out/menu.txt.
MOCK_SCRATCH = arg[1]
local DIR, OUT = arg[2], arg[3]
dofile(MOCK_SCRATCH .. "/cui/mock_cui.lua")
dofile(MOCK_SCRATCH .. "/bt/sim.lua")
local M = MOCK
M.InstallAPI()
M.phase = "ready"
M.Load(DIR)
M.unit.party1 = { exists = true, name = "Melkor", class = "Mage", level = 20, hp = 1500, hpm = 2000, mp = 800, mpm = 1200, power = 0 }
M.unit.party2 = { exists = true, name = "Jaina", class = "Priest", level = 19, hp = 1800, hpm = 1800, mp = 900, mpm = 1200, power = 0 }
M.Fire("PARTY_MEMBERS_CHANGED")
for i = 1, 20 do M.Frame(1 / 30) end
SIM.StartRun("scholomance", { killAfter = 120 })
SIM.Advance(1, 1 / 30)
this, arg1 = CreedUIParty1, "RightButton"
CreedUIParty1.__scripts.OnClick()
SIM.Advance(0.2, 1 / 30)
M.Dump(OUT .. "/menu.txt")
print("problems: " .. table.getn(M.problems))
