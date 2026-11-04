-- Focused Tiny Plates regression tests.
-- usage: lua tests.lua <scratch> <addon dir>
MOCK_SCRATCH = arg[1]
local DIR = arg[2]
dofile(MOCK_SCRATCH .. "/cui/mock_creed_plates.lua")
dofile(MOCK_SCRATCH .. "/bt/sim.lua")
local M = MOCK

local failures, passes = {}, 0
local function check(condition, message)
	if condition then
		passes = passes + 1
	else
		table.insert(failures, message)
		print("FAIL: " .. message)
	end
end
local function frames(count, dt)
	for i = 1, count do M.Frame(dt or (1 / 30)) end
end
local function chatHas(pattern)
	for i = 1, table.getn(M.chat) do
		if string.find(M.chat[i], pattern) then return true end
	end
	return false
end
local function problems(label)
	local count = table.getn(M.problems)
	check(count == 0, label .. ": mock API reported " .. count .. " problem(s)")
	for i = 1, math.min(count, 3) do print("  " .. M.problems[i]) end
	M.problems = {}
end

M.InstallAPI()
M.phase = "ready"
M.hud.clock, M.hud.bosses, M.hud.build = true, true, true
M.Load(DIR)
frames(30)
problems("CreedUI load")
check(CreedUIMeterToggle == nil and CreedUILuckToggle == nil,
	"the separate Damage meter swords and Luck clover minimap buttons are not created")
check(CreedUIMinimapButton ~= nil, "the original Creed C minimap button remains")
CreedUI.ToggleHub()
local tinyPlatesSettingsButton
local hubChildren = { CreedUIOptions:GetChildren() }
for i = 1, table.getn(hubChildren) do
	local child = hubChildren[i]
	if child.text and child.text.GetText and child.text:GetText() == "Tiny Plates settings" then
		tinyPlatesSettingsButton = child
		break
	end
end
check(tinyPlatesSettingsButton ~= nil, "Creed UI Options exposes the Tiny Plates settings button")
if tinyPlatesSettingsButton then
	this = tinyPlatesSettingsButton
	tinyPlatesSettingsButton.__scripts.OnClick()
	check(CreedUITinyPlatesOptions and CreedUITinyPlatesOptions:IsShown(),
		"the Tiny Plates settings button opens its child settings panel")
end
CreedUI.ToggleHub()
check(CreedUIDB.nameplates.showHealthText == true,
	"health numbers are enabled by default without changing the bar presentation")

-- Regular enemy plates: half size, CreedUI bar art, shared font, optional name and V behavior.
M.cvars.nameplateShowEnemies = "1"
local tinyPlate, tinyBar, tinyName = M.MakeNameplate("Test Ghoul")
frames(30)
check(tinyPlate.creedPlatesOverlay and tinyPlate.creedPlatesOverlay:IsShown(),
	"V-visible regular plate receives its CreedUI overlay")
check(tinyPlate.creedPlatesOverlayWidth == tinyPlate.creedPlatesOverlayBaseWidth * 0.5,
	"regular plate remains half-size")
check(tinyPlate.creedPlatesHealthBar and tinyPlate.creedPlatesHealthBar.fillA
	and tinyPlate.creedPlatesHealthBar.rimL,
	"regular plate uses CreedUI's layered gradient health bar")
check(tinyPlate.creedPlatesHealthText and tinyPlate.creedPlatesHealthText:IsShown()
	and tinyPlate.creedPlatesHealthText:GetFont() == CreedUI.FONT
	and tinyPlate.creedPlatesHealthText:GetText() == "75 / 100",
	"regular plate health text uses CreedUI's shared font and number format")
check(not tinyBar:IsShown() and not tinyName:IsShown(),
	"regular plate replaces the game's native bar and name")
CreedUIDB.nameplates.showShrunkName = true
CreedUI.TinyPlatesRefresh(true)
frames(10)
local tinyLabel = tinyPlate.creedPlatesShrunkLabelHolder and tinyPlate.creedPlatesShrunkLabelHolder.text
check(tinyLabel and tinyLabel:IsShown() and tinyLabel:GetText() == "Test Ghoul"
	and tinyLabel:GetFont() == CreedUI.FONT,
	"optional tiny name uses CreedUI's shared FRIZQT typography")
CreedUIDB.nameplates.showShrunkName = false
CreedUI.TinyPlatesRefresh(true)
frames(5)
tinyPlate:Hide()
frames(5)
check(not tinyPlate:IsVisible(), "the game can still hide plates with V")
tinyPlate:Show()
frames(20)
check(tinyPlate.creedPlatesOverlay:IsShown(), "a plate shown again by V is restyled")
check(M.cvars.nameplateShowEnemies == "1", "Tiny Plates leaves V's nameplate CVar untouched")

-- Boss and guardian plates: same artwork at native size, name above and debuffs below.
SIM.StartRun("naxx", { killAfter = 40 })
local bosses = SIM.run.bosses
M.runTime = bosses[2].at + 4
bosses[1].state = "dead"
SIM.Publish()
M.guardians = { { id = 77, name = "Sir Zeliek", hp = 21500, hpm = 36000, awake = true } }
M.debuffs = { ["Sir Zeliek"] = {
	{ name = "Curse", icon = "Interface\\Icons\\Spell_Shadow_CurseOfMannoroth",
		stacks = 2, ends = (M.runTime or 0) + 12 }
} }
SIM.Advance(2, 1 / 30)
M.Fire("CHAT_MSG_ADDON", "AZSUNITS")
local bossPlate, bossBar, bossName = M.MakeNameplate("Sir Zeliek")
frames(30)
check(bossPlate.creedPlatesBossGuardian == true, "guardian name is recognized")
check(bossPlate.creedPlatesOverlay and bossPlate.creedPlatesOverlay:IsShown()
	and bossPlate.creedPlatesOverlayWidth == bossPlate.creedPlatesOverlayBaseWidth,
	"boss and guardian plates keep full size with CreedUI's bar")
check(bossPlate.creedPlatesHealthBar and bossPlate.creedPlatesHealthBar.fillA
	and bossPlate.creedPlatesHealthBar.rimL,
	"boss and guardian bars use CreedUI's layered health-bar artwork")
check(not bossBar:IsShown(), "boss native health bar is hidden behind the CreedUI replacement")
check(bossPlate.creedPlatesHealthText and bossPlate.creedPlatesHealthText:GetFont() == CreedUI.FONT,
	"boss and guardian health values use CreedUI's shared font")
check(bossPlate.creedPlatesBossGuardianLabel and bossPlate.creedPlatesBossGuardianLabel:IsShown()
	and bossPlate.creedPlatesBossGuardianLabel:GetFont() == CreedUI.FONT,
	"boss and guardian names use CreedUI's shared FRIZQT typography")
check(bossPlate.creedPlatesDebuffRow and bossPlate.creedPlatesDebuffRow:IsShown(),
	"guardian debuffs remain visible below the replacement bar")

-- Health numbers are independently toggleable; the colored health bars stay on.
CreedUI.tinyPlatesOptions()
local healthToggle
local optionChildren = { CreedUITinyPlatesOptions:GetChildren() }
for i = 1, table.getn(optionChildren) do
	if optionChildren[i].creedPlatesOptionKey == "showHealthText" then
		healthToggle = optionChildren[i]
		break
	end
end
check(healthToggle ~= nil and healthToggle:GetChecked(),
	"Tiny Plates settings expose Show health numbers, enabled by default")
if healthToggle then
	healthToggle:SetChecked(nil)
	healthToggle:Click()
	frames(10)
	check(CreedUIDB.nameplates.showHealthText == false
		and tinyPlate.creedPlatesHealthText and not tinyPlate.creedPlatesHealthText:IsShown()
		and bossPlate.creedPlatesHealthText and not bossPlate.creedPlatesHealthText:IsShown(),
	"turning health numbers off hides the text on regular and boss plates")
	check(tinyPlate.creedPlatesOverlay:IsShown() and bossPlate.creedPlatesOverlay:IsShown()
		and tinyPlate.creedPlatesHealthBar.fillA and bossPlate.creedPlatesHealthBar.fillA,
	"turning health numbers off leaves both colored health bars visible")
	healthToggle:SetChecked(1)
	healthToggle:Click()
	frames(10)
	check(CreedUIDB.nameplates.showHealthText == true
		and tinyPlate.creedPlatesHealthText:IsShown()
		and bossPlate.creedPlatesHealthText:IsShown(),
	"turning health numbers back on restores the text without rebuilding the bars")
	check(tinyPlate.creedPlatesOverlay:IsShown() and bossPlate.creedPlatesOverlay:IsShown(),
	"re-enabling health numbers does not alter bar visibility")
end

-- Native restore, including both original plate types.
local nameplatesPart
for i = 1, table.getn(CreedUI.parts) do
	if CreedUI.parts[i].key == "nameplates" then nameplatesPart = CreedUI.parts[i] end
end
check(nameplatesPart ~= nil, "Tiny Plates is registered as a Creed UI option")
if nameplatesPart then
	nameplatesPart.set(false)
	frames(3)
	check(tinyBar:IsShown() and tinyName:IsShown() and tinyPlate:GetWidth() == 120,
	"disabling Tiny Plates restores the regular game's native plate")
	check(bossBar:IsShown() and bossName:IsShown()
		and (not bossPlate.creedPlatesDebuffRow or not bossPlate.creedPlatesDebuffRow:IsShown()),
	"disabling Tiny Plates restores boss native parts and removes custom debuffs")
	check(M.cvars.nameplateShowEnemies == "1", "disabling Tiny Plates leaves V's CVar untouched")
	nameplatesPart.set(true)
	frames(30)
	check(tinyPlate.creedPlatesOverlay and tinyPlate.creedPlatesOverlay:IsShown()
		and not tinyBar:IsShown(), "re-enabling Tiny Plates reapplies the regular CreedUI plate")
	check(bossPlate.creedPlatesOverlay and bossPlate.creedPlatesOverlay:IsShown()
		and not bossBar:IsShown(), "re-enabling Tiny Plates reapplies the full-size boss bar")
end
check(not chatHas("nameplates stopped after an error"),
	"Tiny Plates does not stop its update loop with a runtime error")
problems("Tiny Plates run")

if table.getn(failures) > 0 then
	print("Tiny Plates regression tests: " .. passes .. " passed, " .. table.getn(failures) .. " failed")
	os.exit(1)
end
print("Tiny Plates regression tests: " .. passes .. " passed, 0 failed")
