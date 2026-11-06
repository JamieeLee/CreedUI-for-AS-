-- The stats window (1.22.0): a rogue's run (out/stats.txt), then with its list of stats open
-- (out/stats_menu.txt).
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
AZS_STATS = { dmg = 2.57, crit = 0.404, cm = 2.97, cd = 0.71, echo = 0.32, hp = 2480, arm = 0.39, reg = 4.5, lch = 0.015,
	spd = 1.58, luck = 0.2, area = 1.3, cnt = 2, xp = 1.2, gold = 1.27, pick = 9, heal = 12, thn = 0.1, liv = 1, bp = 0.3,
	dots = 1, doth = 0.1, big = 0.2, exe = 0.3, cc = 0, dotd = 0.15, shd = 0, auto = 0.1, pet = 0 }
M.phase = "playing"
SIM.Advance(2, 1 / 30)
AZS_STATS.crit = 0.452
SIM.Advance(0.6, 1 / 30)
M.Dump(OUT .. "/stats.txt")
for _, b in ipairs(CreedUIStatsMenu.items) do
	if b.name == "Area" or b.name == "Experience" or b.name == "Vs Elites" then this = b; b:Click() end
end
CreedUIStatsMenu:Show()
SIM.Advance(1, 1 / 30)
M.Dump(OUT .. "/stats_menu.txt")
local l, b, r, t = M.Rect(CreedUIStats)
print("stats", l, b, r, t)
print("problems: " .. table.getn(M.problems))
