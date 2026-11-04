-- Creed UI: one round minimap-edge button. The Creed C opens the central options hub; Luck
-- and the damage meter are shown or hidden with their controls in that menu.

local C = CreedUI
local DEFAULTS = { enabled = true, angle = 315 }
local SIZE, HALO = 32, 46

------------------------------------------------------------------------ the buttons
-- on the rim: the game's border and Creed UI's ring both run about 75 px out on a 140 px map
local function Radius()
	local w = Minimap:GetWidth() or 140
	if w < 40 then w = 140 end
	return w * 0.5 + 10
end

-- spec: frame (its name), crest (its art), store (the table keeping its place) and field (the key there),
-- angle (its first place, in degrees: 0 the right, 90 the top), tint(pal) the crest's color,
-- glow(pal) the halo's (the tint by default), dim() true while what it stands for is hidden,
-- held() true to keep a faint halo, tip() the tooltip's lines (the drag's added), click() on a
-- click (arg1 the mouse button), stopped the words for an error
function C.EdgeButton(spec)
	if type(Minimap) ~= "table" then return nil end
	local field = spec.field or "angle"
	if type(spec.store[field]) ~= "number" then spec.store[field] = spec.angle end
	local S = { glow = 0, hot = 0, lit = 1, stamp = -1, hover = false, dragging = false, dragEnd = -1, placeClock = 0 }
	local b = CreateFrame("Button", spec.frame, Minimap)
	b:SetWidth(SIZE)
	b:SetHeight(SIZE)
	b:SetFrameLevel(Minimap:GetFrameLevel() + 10) -- over the ring (6), its clock (8) and the pins (4)
	local halo = C.Tex(b, "BACKGROUND", C.ART .. "Ring", "ADD")
	halo:SetWidth(HALO)
	halo:SetHeight(HALO)
	halo:SetPoint("CENTER", b, "CENTER", 0, 0)
	local bezel = C.Tex(b, "ARTWORK", C.ART .. "MapButton")
	bezel:SetAllPoints(b)
	local crest = C.Tex(b, "OVERLAY", C.ART .. spec.crest)
	crest:SetWidth(SIZE)
	crest:SetHeight(SIZE)
	C.Place(crest, "CENTER", b, "CENTER", 0, 0)
	b.halo, b.bezel, b.crest = halo, bezel, crest

	local function Place()
		local a = math.rad(spec.store[field] or spec.angle)
		local r = Radius()
		C.Place(b, "CENTER", Minimap, "CENTER", math.floor(math.cos(a) * r * 10 + 0.5) / 10,
			math.floor(math.sin(a) * r * 10 + 0.5) / 10)
	end
	b.Place = Place

	-- while dragged: the angle from the map's middle to the cursor, in whole degrees
	local function Follow()
		local mx, my = Minimap:GetCenter()
		local cx, cy = GetCursorPosition()
		if not (mx and cx) then return end
		local k = Minimap:GetEffectiveScale()
		local ang = math.deg(math.atan2(cy / k - my, cx / k - mx))
		spec.store[field] = math.mod(math.floor(ang + 0.5) + 360, 360)
		Place()
	end

	local function ShowTip()
		if not GameTooltip or S.dragging then return end
		GameTooltip:SetOwner(b, "ANCHOR_LEFT")
		spec.tip()
		GameTooltip:AddLine(C.L("Drag: slide it along the minimap's edge"), 0.65, 0.65, 0.7)
		C.ShowTip()
	end
	b.ShowTip = function() if S.hover then ShowTip() end end

	local function Step(dt)
		if S.dragging then Follow() end
		S.placeClock = S.placeClock - dt
		if S.placeClock <= 0 then
			S.placeClock = 1 -- the map's size can change under it
			Place()
		end
		local pal = C.Pal()
		if S.stamp ~= C.palStamp then
			S.stamp = C.palStamp
			local rim = pal.rim
			bezel:SetVertexColor(rim[1], rim[2], rim[3])
		end
		-- a halo while hovered or dragged (fainter while `held`); the crest lifts under the mouse and
		-- dims while what it stands for is hidden
		local want = (S.hover or S.dragging) and 1 or ((spec.held and spec.held()) and 0.55 or 0)
		S.glow = C.Toward(S.glow, want, 10, dt)
		S.hot = C.Toward(S.hot, (S.hover or S.dragging) and 1 or 0, 12, dt)
		S.lit = C.Toward(S.lit, (spec.dim and spec.dim()) and 0.42 or 1, 8, dt)
		local tr, tg, tb = spec.tint(pal)
		local gr, gg, gb = tr, tg, tb
		if spec.glow then gr, gg, gb = spec.glow(pal) end
		C.Color(halo, gr, gg, gb, 0.75 * S.glow)
		local k = (1 + 0.22 * S.hot) * S.lit
		C.Color(crest, math.min(1, tr * k), math.min(1, tg * k), math.min(1, tb * k), 1)
	end

	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:RegisterForDrag("LeftButton")
	b:SetScript("OnEnter", function()
		S.hover = true
		ShowTip()
	end)
	b:SetScript("OnLeave", function()
		S.hover = false
		if GameTooltip then GameTooltip:Hide() end
	end)
	-- pressed, the crest sinks a pixel
	b:SetScript("OnMouseDown", function() C.Place(crest, "CENTER", b, "CENTER", 1, -1) end)
	b:SetScript("OnMouseUp", function() C.Place(crest, "CENTER", b, "CENTER", 0, 0) end)
	b:SetScript("OnClick", function()
		-- the mouse let go at the end of a drag is no click
		if S.dragging or GetTime() - S.dragEnd < 0.2 then return end
		spec.click()
		if S.hover then ShowTip() end -- what it says may be another thing now
	end)
	b:SetScript("OnDragStart", function()
		S.dragging = true
		C.Place(crest, "CENTER", b, "CENTER", 0, 0)
		if GameTooltip then GameTooltip:Hide() end
	end)
	b:SetScript("OnDragStop", function()
		S.dragging = false
		S.dragEnd = GetTime()
		Follow()
		if S.hover then ShowTip() end
	end)
	b:SetScript("OnHide", function()
		S.dragging, S.hover = false, false
	end)
	local broken = false
	b:SetScript("OnUpdate", function()
		if broken then return end
		local dt = arg1 or 0
		if dt > 0.1 then dt = 0.1 end
		local ok, err = pcall(Step, dt)
		if not ok then
			broken = true
			C.Print(C.L("the minimap button stopped after an error: ") .. tostring(err))
		end
	end)
	Place()
	return b
end

------------------------------------------------------------------------ Creed's C: the options
local db, button

local function Click()
	if arg1 == "RightButton" then
		C.SetUnlocked(not C.unlocked)
		if C.unlocked then
			C.Print(C.L("drag the frames, then right-click the Creed button to lock them."))
		else
			C.Print(C.L("frames locked."))
		end
		if C.RefreshHub then C.RefreshHub() end
	else
		C.ToggleHub()
	end
end

local function Tip()
	GameTooltip:AddDoubleLine("Creed UI", "v" .. C.VERSION, 0.98, 0.85, 0.52, 0.55, 0.55, 0.6)
	GameTooltip:AddLine(C.L("Click: open or close the menu"), 1, 1, 1)
	GameTooltip:AddLine(C.L(C.unlocked and "Right-click: lock the frames" or "Right-click: move the frames"), 1, 1, 1)
end

local function Apply()
	if type(Minimap) ~= "table" then return end
	if not button then
		button = C.EdgeButton({
			frame = "CreedUIMinimapButton", crest = "MapCrest", store = db, field = "angle", angle = DEFAULTS.angle,
			tint = function(pal) return pal.title[1], pal.title[2], pal.title[3] end,
			held = function() return CreedUIOptions and CreedUIOptions:IsShown() end,
			tip = Tip, click = Click,
		})
		if not button then return end
	end
	if db.enabled then
		button.Place()
		button:Show()
	else
		button:Hide()
	end
end

C.OnInit(function()
	db = C.DB("minimapButton", DEFAULTS)
	if type(db.angle) ~= "number" then db.angle = DEFAULTS.angle end
end)

C.OnWorld(function()
	if not db then return end
	local ok, err = pcall(Apply)
	if not ok then C.Print(C.L("the minimap button stopped after an error: ") .. tostring(err)) end
end)

C.RegisterPart({
	key = "button", name = "Minimap button",
	note = "A round Creed button on the minimap's edge: click it for this menu, right-click it to move or lock the frames, drag it along the edge to place it. /creed opens the menu too.",
	get = function() return db and db.enabled end,
	set = function(on)
		if db then
			db.enabled = on and true or false
			Apply()
		end
	end,
})
