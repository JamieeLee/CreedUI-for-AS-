-- Creed UI Tiny Plates settings. All state lives under CreedUIDB.nameplates.
-- The settings are embedded in Creed UI's options hub; no extra minimap button or second menu.

local C = CreedUI
local db
local controls = {}
local colorRows = {}
local panel

local DEFAULTS = {
	showDebuffs = true,
	hideShrunkPlates = false,
	hideBossName = false,
	showShrunkName = false,
	showHealthText = true,
	bossBarColorOn = false,
	regularBarColorOn = false,
	bossBarColor = { 0, 0.64, 1 },
	regularBarColor = { 0, 0.64, 1 },
}

local PRESETS = {
	{ name = "Blue", 0, 0.64, 1 },
	{ name = "Orange", 1, 0.69, 0 },
	{ name = "Sky blue", 0.37, 0.78, 1 },
	{ name = "Vermillion", 1, 0.44, 0 },
	{ name = "Yellow", 1, 0.95, 0.28 },
	{ name = "Pink", 1, 0.59, 0.81 },
}

local function DB()
	if not db then db = C.DB("nameplates", DEFAULTS) end
	return db
end

local function Color(category)
	local d = DB()
	if not d[category .. "BarColorOn"] then return nil end
	local c = d[category .. "BarColor"] or PRESETS[1]
	return { tonumber(c[1]) or 1, tonumber(c[2]) or 1, tonumber(c[3]) or 1 }
end

function C.TinyPlatesOption(key)
	local d = DB()
	if d[key] == nil then return DEFAULTS[key] end
	return d[key] and true or false
end

function C.TinyPlatesBarColor(category)
	return Color(category)
end

local function PanelText(parent, text, x, y, width, size, color)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	C.SetFace(fs, C.FONT, size or 11)
	fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	if width then fs:SetWidth(width) end
	fs:SetTextColor(color and color[1] or 0.92, color and color[2] or 0.92, color and color[3] or 0.92)
	fs:SetShadowColor(0, 0, 0, 1)
	fs:SetShadowOffset(1, -1)
	fs:SetText(text)
	return fs
end

local function Checkbox(parent, key, label, note, x, y)
	local b = CreateFrame("CheckButton", nil, parent)
	b.creedPlatesOptionKey = key
	b:SetWidth(20)
	b:SetHeight(20)
	b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	b:SetHitRectInsets(0, -210, 0, 0)
	local edge = b:CreateTexture(nil, "BORDER")
	edge:SetTexture(C.FLAT)
	edge:SetVertexColor(0.45, 0.39, 0.27, 1)
	edge:SetAllPoints(b)
	local fill = b:CreateTexture(nil, "ARTWORK")
	fill:SetTexture(C.FLAT)
	fill:SetVertexColor(0.06, 0.06, 0.08, 1)
	fill:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
	fill:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
	local tick = b:CreateTexture(nil, "OVERLAY")
	tick:SetTexture(C.FLAT)
	tick:SetVertexColor(0.98, 0.78, 0.32, 1)
	tick:SetPoint("TOPLEFT", b, "TOPLEFT", 4, -4)
	tick:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -4, 4)
	b.tick = tick
	b.label = PanelText(parent, label, x + 27, y - 1, 250, 11)
	b.note = note
	b:SetScript("OnClick", function()
		DB()[key] = this:GetChecked() and true or false
		if C.TinyPlatesRefresh then C.TinyPlatesRefresh(true) end
		C.TinyPlatesRefreshOptions()
	end)
	b:SetScript("OnEnter", function()
		if not note or not GameTooltip then return end
		GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
		GameTooltip:AddLine(label, 0.98, 0.85, 0.52)
		GameTooltip:AddLine(note, 1, 1, 1, 1)
		C.ShowTip()
	end)
	b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
	controls[key] = b
	return b
end

local function Swatch(parent, category, color, x, y, primary)
	local b = CreateFrame("Button", nil, parent)
	if primary then b.creedPlatesPrimarySwatch = category end
	b:SetWidth(16)
	b:SetHeight(16)
	b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	b.fill = C.Tex(b, "BACKGROUND", C.FLAT)
	b.fill:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
	b.fill:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
	b.fill:SetVertexColor(color[1], color[2], color[3], 1)
	b:SetScript("OnClick", function()
		local d = DB()
		local old = d[category .. "BarColor"]
		local oldEnabled = d[category .. "BarColorOn"] and true or false
		local picker = ColorPickerFrame
		local r, g, blue = color[1], color[2], color[3]
		if d[category .. "BarColor"] then
			r, g, blue = d[category .. "BarColor"][1], d[category .. "BarColor"][2], d[category .. "BarColor"][3]
		end
		local function Apply()
			local cr, cg, cb = picker:GetColorRGB()
			d[category .. "BarColor"] = { cr, cg, cb }
			d[category .. "BarColorOn"] = true
			C.TinyPlatesRefresh(true)
			C.TinyPlatesRefreshOptions()
		end
		local function Cancel(previous)
			if type(previous) == "table" then
				d[category .. "BarColor"] = { previous[1], previous[2], previous[3] }
			else
				d[category .. "BarColor"] = old
			end
			d[category .. "BarColorOn"] = oldEnabled
			C.TinyPlatesRefresh(true)
			C.TinyPlatesRefreshOptions()
		end
		picker:Hide()
		picker.hasOpacity = nil
		picker.opacityFunc = nil
		picker.func = Apply
		picker.cancelFunc = Cancel
		picker.previousValues = { r, g, blue }
		picker:SetColorRGB(r, g, blue)
		picker:Show()
	end)
	return b
end

local function MakeColorRow(parent, category, title, y)
	PanelText(parent, title, 18, y, 160, 11, { 0.98, 0.85, 0.52 })
	local enabled = Checkbox(parent, category .. "BarColorOn", "Custom bar color", "Use your own color instead of the game's health-bar color.", 18, y - 19)
	local swatch = Swatch(parent, category, PRESETS[1], 210, y - 18, true)
	local reset = C.Button(parent, 48, 18, "Reset", function()
		DB()[category .. "BarColorOn"] = false
		DB()[category .. "BarColor"] = { PRESETS[1][1], PRESETS[1][2], PRESETS[1][3] }
		C.TinyPlatesRefresh(true)
		C.TinyPlatesRefreshOptions()
	end)
	reset:SetPoint("TOPLEFT", parent, "TOPLEFT", 232, y - 19)
	local picks = {}
	local function PresetAction(cat, preset)
		return function()
			DB()[cat .. "BarColor"] = { preset[1], preset[2], preset[3] }
			DB()[cat .. "BarColorOn"] = true
			C.TinyPlatesRefresh(true)
			C.TinyPlatesRefreshOptions()
		end
	end
	for i = 1, table.getn(PRESETS) do
		local preset = PRESETS[i]
		local p = Swatch(parent, category, preset, 18 + (i - 1) * 21, y - 43)
		p.fill:SetVertexColor(preset[1], preset[2], preset[3], 1)
		picks[i] = p
		p:SetScript("OnClick", PresetAction(category, preset))
	end
	colorRows[category] = { swatch = swatch, picks = picks, enabled = enabled }
end

local function UpdateControls()
	if not panel then return end
	local d = DB()
	for key, b in pairs(controls) do
		b:SetChecked(d[key] and 1 or nil)
		C.Vis(b.tick, d[key] and true or false)
	end
	for category, row in pairs(colorRows) do
		local on = d[category .. "BarColorOn"] and true or false
		local c = d[category .. "BarColor"] or PRESETS[1]
		row.swatch.fill:SetVertexColor(c[1], c[2], c[3], on and 1 or 0.4)
		row.enabled:SetChecked(on and 1 or nil)
		C.Vis(row.enabled.tick, on)
	end
end

local function BuildPanel(parent)
	if panel then return end
	panel = CreateFrame("Frame", "CreedUITinyPlatesOptions", parent or UIParent)
	panel:SetWidth(310)
	panel:SetHeight(430)
	panel:SetPoint("TOPLEFT", parent or UIParent, "TOPLEFT", 324, -62)
	panel:SetBackdrop({ bgFile = C.FLAT, edgeFile = C.FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	panel:SetBackdropColor(0.05, 0.05, 0.07, 0.98)
	panel:SetBackdropBorderColor(0.91, 0.70, 0.30, 0.8)
	panel:EnableMouse(true)
	panel:SetFrameStrata(parent and parent:GetFrameStrata() or "DIALOG")
	panel:Hide()
	if parent then
		parent:SetScript("OnHide", function()
			if panel then panel:Hide() end
		end)
	end
	C.AboveHub(panel)
	if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "CreedUITinyPlatesOptions") end

	local title = PanelText(panel, "Tiny Plates", 16, -14, 280, 16, { 0.98, 0.85, 0.52 })
	C.SetFace(title, C.TITLE_FONT, 17)
	local close = C.Button(panel, 22, 20, "x", function() panel:Hide() end)
	close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -10, -10)

	PanelText(panel, "Boss & guardian plates", 16, -46, 280, 10, { 0.72, 0.68, 0.58 })
	Checkbox(panel, "showDebuffs", "Show debuffs", "Show boss and guardian debuffs, stack counts and remaining time.", 18, -62)
	Checkbox(panel, "hideBossName", "Hide boss / guardian names", "Hide the name label above special plates.", 18, -87)

	PanelText(panel, "Regular plates", 16, -121, 280, 10, { 0.72, 0.68, 0.58 })
	Checkbox(panel, "hideShrunkPlates", "Hide regular plates", "Hide ordinary mob plates entirely. Requires overlapping nameplates.", 18, -137)
	Checkbox(panel, "showShrunkName", "Show names on nameplates", "Show each regular mob name above its shrunken plate.", 18, -162)

	PanelText(panel, "Health display", 16, -198, 280, 10, { 0.72, 0.68, 0.58 })
	Checkbox(panel, "showHealthText", "Show health numbers", "Show current / maximum health numbers inside each plate. The colored health bars remain visible either way.", 18, -214)

	MakeColorRow(panel, "boss", "Boss / guardian health color", -250)
	MakeColorRow(panel, "regular", "Regular health color", -326)
	UpdateControls()
end

function C.TinyPlatesRefreshOptions()
	UpdateControls()
end

function C.TinyPlatesToggleOptions(parent)
	if not panel then BuildPanel(parent) end
	if panel:IsShown() then panel:Hide() else
		if parent and panel:GetParent() ~= parent then panel:SetParent(parent) end
		C.AboveHub(panel)
		UpdateControls()
		panel:Show()
	end
end

C.tinyPlatesOptions = C.TinyPlatesToggleOptions

C.OnInit(function() DB() end)
