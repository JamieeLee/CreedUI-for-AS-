-- The Level Up! button in each class's look (1.24.2): out/level_<class>.txt.
MOCK_SCRATCH = arg[1]
local DIR, OUT = arg[2], arg[3]
dofile(MOCK_SCRATCH .. "/cui/mock_cui.lua")
dofile(MOCK_SCRATCH .. "/bt/sim.lua")
local M = MOCK
M.InstallAPI()
M.phase = "ready"
M.Load(DIR)
for i = 1, 20 do M.Frame(1 / 30) end
SIM.StartRun("naxx", { killAfter = 120 })
M.runTime = 300
SIM.Publish()
M.phase = "playing"
M.storing, M.storedLevels = true, 6
SIM.Advance(1, 1 / 30)
for _, key in ipairs({ "warrior", "paladin", "hunter", "rogue", "mage", "druid", "shaman", "priest", "warlock" }) do
	CreedUI.SetTheme(key)
	SIM.Advance(0.5, 1 / 30)
	M.Dump(OUT .. "/level_" .. key .. ".txt")
end
local l, b, r, t = M.Rect(CreedUILevelUps)
print("button", l, b, r, t)
print("problems: " .. table.getn(M.problems))
