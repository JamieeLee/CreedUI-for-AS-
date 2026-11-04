-- Creed UI Tiny Plates
-- Based on Valorless's MIT-licensed ASTinyPlates implementation, adapted for Creed UI's
-- shared database, options hub, lifecycle and Lua 5.0 client. See TinyPlates-LICENSE.txt.
local C = CreedUI
local knownPlates = {}
local orderedPlates = {}
local active = true
local scanClock = 0
local SCAN_INTERVAL = 0.50
local OVERLAY_INTERVAL = 0.10
local DEBUFF_INTERVAL = 0.25
local overlayClock = 0
local debuffClock = 0
local refreshPending = true
local styleRevision = 0
local scanFrame

local function Opt(key)
	if type(C.TinyPlatesOption) == "function" then return C.TinyPlatesOption(key) end
	return false
end
local BORDER = "Interface\\Tooltips\\Nameplate-Border";
local PLATE_SCALE = 0.5;
local HORIZONTAL_OFFSET = 10;
local VERTICAL_OFFSET = 14;
local bossGuardianNames = {};
local bossGuardianUnitsByName = {};
local lastSpecialPhase;
local lastSpecialUnitsUpdate;
local lastSpecialDebuffsUpdate;
local lastSpecialRefreshTime = 0;

local function AddBossGuardianNames(units, requireKind)
	if ( type(units) ~= "table" ) then return; end
	for i = 1, table.getn(units) do
		local unit = units[i];
		if ( unit.name and ( not requireKind or unit.kind == "final"
				or unit.kind == "boss" or unit.kind == "guardian" ) ) then
			bossGuardianNames[unit.name] = true;
			if ( unit.id ) then
				local candidates = bossGuardianUnitsByName[unit.name];
				if ( not candidates ) then
					candidates = {};
					bossGuardianUnitsByName[unit.name] = candidates;
				end
				local replaced = false;
				for j = 1, table.getn(candidates) do
					if ( candidates[j].id == unit.id ) then
						candidates[j] = unit;
						replaced = true;
						break;
					end
				end
				if ( not replaced ) then table.insert(candidates, unit); end
			end
		end
	end
end

local function ClearBossGuardianPlateFlags()
	for i = 1, table.getn(orderedPlates) do
		local frame = orderedPlates[i]
		frame.creedPlatesBossGuardian = nil
		frame.creedPlatesBossGuardianName = nil
		frame.creedPlatesDebuffUnitID = nil
		frame.creedPlatesDebuffSignature = nil
		if frame.creedPlatesDebuffRow then frame.creedPlatesDebuffRow:Hide() end
	end
end

local function RefreshBossGuardianNames(force)
	local phase
	if type(AZS_GetPhase) == "function" then
		local ok, value = pcall(AZS_GetPhase)
		if ok then phase = value end
	end
	local unitsUpdate = AZS_UNITS_UPDATED or 0
	local debuffsUpdate = AZS_DEBUFFS_UPDATED or 0
	local newRun = phase == "playing" and (lastSpecialPhase == nil
		or lastSpecialPhase == "ready" or lastSpecialPhase == "dead"
		or lastSpecialPhase == "victory")
	local resetNames = (phase == "ready" and lastSpecialPhase ~= "ready") or newRun
	if resetNames then
		bossGuardianNames = {}
		bossGuardianUnitsByName = {}
		ClearBossGuardianPlateFlags()
	end
	local retryCache = phase ~= "ready" and GetTime() - lastSpecialRefreshTime >= 1
	if phase ~= "ready" and (force or retryCache or phase ~= lastSpecialPhase
			or unitsUpdate ~= lastSpecialUnitsUpdate
			or debuffsUpdate ~= lastSpecialDebuffsUpdate or newRun) then
		bossGuardianUnitsByName = {}
		AddBossGuardianNames(AZS_UNITS, true)
		if type(AZS_GetBosses) == "function" then
			local ok, units = pcall(AZS_GetBosses)
			if ok then AddBossGuardianNames(units, false) end
		end
		if type(AZS_GetGuardians) == "function" then
			local ok, units = pcall(AZS_GetGuardians)
			if ok then AddBossGuardianNames(units, false) end
		end
		lastSpecialRefreshTime = GetTime()
	end
	lastSpecialPhase = phase
	lastSpecialUnitsUpdate = unitsUpdate
	lastSpecialDebuffsUpdate = debuffsUpdate
end
local function NormalizeName(text)
	if ( not text ) then return nil; end
	text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "");
	text = string.gsub(text, "|r", "");
	text = string.gsub(text, "^%s+", "");
	text = string.gsub(text, "%s+$", "");
	if ( text == "" ) then return nil; end
	return text;
end

local function IsOwnObject(frame, object)
	return object == frame.creedPlatesOverlay
		or object == frame.creedPlatesDebuffRow
		or object == frame.creedPlatesShrunkLabelHolder
		or object == frame.creedPlatesBossGuardianLabelHolder
		or object == frame.creedPlatesBossGuardianLabel
end

-- Searches the plate and its descendants, because UI replacements such as SDUI
-- may move the name FontString into a child frame or blank the native one.
local function GetPlateName(frame, root)
	root = root or frame;
	local regions = { root:GetRegions() };
	for i = 1, table.getn(regions) do
		local region = regions[i];
		if ( region and region ~= frame.creedPlatesBossGuardianLabel
				and region:GetObjectType() == "FontString" ) then
			local name = NormalizeName(region:GetText());
			-- Purely numeric text is a level indicator, not a name.
			if ( name and not string.find(name, "^%d+$") ) then
				frame.creedPlatesNameRegion = region;
				return name;
			end
		end
	end
	local children = { root:GetChildren() };
	for i = 1, table.getn(children) do
		if ( not IsOwnObject(frame, children[i]) ) then
			local name = GetPlateName(frame, children[i]);
			if ( name ) then return name; end
		end
	end
	return nil;
end

local function IsBossOrGuardianName(name)
	return name and bossGuardianNames[name] or false
end

local function IsBossOrGuardianPlate(frame)
	local name = frame.creedPlatesPlateName
	if not name then
		frame.creedPlatesBossGuardian = false
		frame.creedPlatesBossGuardianName = nil
		return false
	end
	if frame.creedPlatesBossGuardianName ~= name then
		frame.creedPlatesDebuffUnitID = nil
		frame.creedPlatesDebuffSignature = nil
		if frame.creedPlatesDebuffRow then frame.creedPlatesDebuffRow:Hide() end
	end
	if IsBossOrGuardianName(name) then
		frame.creedPlatesBossGuardian = true
		frame.creedPlatesBossGuardianName = name
		return true
	end
	frame.creedPlatesBossGuardian = false
	frame.creedPlatesBossGuardianName = nil
	return false
end

local function SaveObjectState(object, states, plate)
	plate = plate or object
	-- Never snapshot Creed UI-owned overlays/labels/debuff rows as native plate UI.
	-- Their lifetime is independent and they must stay hidden when native state returns.
	if object ~= plate and IsOwnObject(plate, object) then return end
	local state = { object = object, shown = object:IsShown() }
	if object.GetAlpha then state.alpha = object:GetAlpha() end
	table.insert(states, state)
	local kind = object:GetObjectType()
	-- Regions (Texture/FontString) have visibility and alpha, but no child tree.
	if kind ~= "Texture" and kind ~= "FontString" then
		local regions = { object:GetRegions() }
		for i = 1, table.getn(regions) do SaveObjectState(regions[i], states, plate) end
		local children = { object:GetChildren() }
		for i = 1, table.getn(children) do SaveObjectState(children[i], states, plate) end
	end
end

local function CaptureNativeState(frame)
	if frame.creedPlatesNativeCaptured then return end
	local previouslyStyled = frame.creedPlatesStyledVisual or frame.creedPlatesOverlay;
	local point, relativeTo, relativePoint, x, y = frame:GetPoint();
	frame.creedPlatesNativeWidth = frame.creedPlatesStackOriginalWidth or frame:GetWidth();
	frame.creedPlatesNativeHeight = frame.creedPlatesStackOriginalHeight or frame:GetHeight();
	frame.creedPlatesNativeScale = frame.creedPlatesStackOriginalScale
		or frame.creedPlatesOriginalScale or frame:GetScale();
	frame.creedPlatesNativePoint = frame.creedPlatesStackPoint or point;
	frame.creedPlatesNativeRelativeTo = frame.creedPlatesStackRelativeTo or relativeTo;
	frame.creedPlatesNativeRelativePoint = frame.creedPlatesStackRelativePoint or relativePoint;
	frame.creedPlatesNativeX = frame.creedPlatesStackPoint and frame.creedPlatesStackX or x;
	frame.creedPlatesNativeY = frame.creedPlatesStackPoint and frame.creedPlatesStackY or y;
	local states = {};
	SaveObjectState(frame, states);
	-- A reload can leave our old custom visual attached while the native plate
	-- is already hidden; in that case restore all native children below.
	if not previouslyStyled then frame.creedPlatesNativeState = states end
	frame.creedPlatesNativeCaptured = true
end

local function RestoreNativeState(frame)
	-- Always reapply the captured native state: the boss-name path can hide name
	-- text after its first restore, and turning Tiny Plates off must undo that too.
	if frame.creedPlatesOverlay then frame.creedPlatesOverlay:Hide() end
	if frame.creedPlatesNativeState then
		for i = 1, table.getn(frame.creedPlatesNativeState) do
			local state = frame.creedPlatesNativeState[i]
			local object = state.object
			if object ~= frame.creedPlatesOverlay and object ~= frame.creedPlatesDebuffRow
					and object ~= frame.creedPlatesBossGuardianLabel
				and object ~= frame.creedPlatesShrunkLabelHolder then
				if object.SetAlpha and state.alpha ~= nil then object:SetAlpha(state.alpha) end
				if state.shown then object:Show() else object:Hide() end
			end
		end
	else
		-- Recover plates left modified by an older TinyPlates revision that did not
		-- store a native visibility snapshot.
		local regions = { frame:GetRegions() }
		for i = 1, table.getn(regions) do
			if not IsOwnObject(frame, regions[i]) then
				if regions[i]:GetObjectType() == "FontString" then regions[i]:SetAlpha(1) end
				regions[i]:Show()
			end
		end
		local children = { frame:GetChildren() }
		for i = 1, table.getn(children) do
			if not IsOwnObject(frame, children[i]) then children[i]:Show() end
		end
	end
	if frame.creedPlatesStyledVisual then
		local styled = frame.creedPlatesStyledVisual
		if frame.creedPlatesStyledOriginalScale then styled:SetScale(frame.creedPlatesStyledOriginalScale) end
		styled:ClearAllPoints()
		styled:SetPoint(frame.creedPlatesStyledPoint or "CENTER",
			frame.creedPlatesStyledRelativeTo or frame,
			frame.creedPlatesStyledRelativePoint or "CENTER",
			frame.creedPlatesStyledX or 0, frame.creedPlatesStyledY or 0)
	end
	if frame.creedPlatesSourceBar then
		if frame.creedPlatesSourceOriginalWidth then frame.creedPlatesSourceBar:SetWidth(frame.creedPlatesSourceOriginalWidth) end
		if frame.creedPlatesSourceOriginalHeight then frame.creedPlatesSourceBar:SetHeight(frame.creedPlatesSourceOriginalHeight) end
	end
	if frame.creedPlatesNativeWidth then frame:SetWidth(frame.creedPlatesNativeWidth) end
	if frame.creedPlatesNativeHeight then frame:SetHeight(frame.creedPlatesNativeHeight) end
	if frame.creedPlatesNativeScale then frame:SetScale(frame.creedPlatesNativeScale) end
	if frame.creedPlatesNativePoint then
		frame:ClearAllPoints()
		frame:SetPoint(frame.creedPlatesNativePoint,
			frame.creedPlatesNativeRelativeTo or frame:GetParent(),
			frame.creedPlatesNativeRelativePoint or frame.creedPlatesNativePoint,
			frame.creedPlatesNativeX or 0, frame.creedPlatesNativeY or 0)
	end
	if frame.creedPlatesBossGuardianLabel then frame.creedPlatesBossGuardianLabel:Hide() end
	if frame.creedPlatesBossGuardianLabelHolder then frame.creedPlatesBossGuardianLabelHolder:Hide() end
	if frame.creedPlatesShrunkLabelHolder then frame.creedPlatesShrunkLabelHolder:Hide() end
	if frame.creedPlatesDebuffRow then frame.creedPlatesDebuffRow:Hide() end
	frame.creedPlatesNativeRestored = true
end

local function HasStatusBar(frame)
	local children = { frame:GetChildren() }
	for i = 1, table.getn(children) do
		local child = children[i]
		if child:GetObjectType() == "StatusBar" or HasStatusBar(child) then return true end
	end
	return false
end

local function IdentifyNameplate(frame)
	local regions = { frame:GetRegions() }
	local hasBorder = false
	for i = 1, table.getn(regions) do
		local region = regions[i]
		if region and region:GetObjectType() == "Texture"
				and region:GetTexture() == BORDER then
			hasBorder = true
			break
		end
	end
	local hasName = GetPlateName(frame) ~= nil
	return hasName and (hasBorder or HasStatusBar(frame))
end

local function HideNameText(frame)
	local regions = { frame:GetRegions() };
	for i = 1, table.getn(regions) do
		local region = regions[i];
		if ( region and region ~= frame.creedPlatesBossGuardianLabel
				and region:GetObjectType() == "FontString" ) then
			region:SetAlpha(0);
			region:Hide();
		end
	end
end

local function HideMatchingNameText(frame, name, keep)
	if ( not name or name == "" or frame == keep ) then return; end
	local regions = { frame:GetRegions() };
	for i = 1, table.getn(regions) do
		local region = regions[i];
		if ( region and region ~= keep and region:GetObjectType() == "FontString"
				and region:GetText() == name ) then
			region:SetAlpha(0);
			region:Hide();
		end
	end
	local children = { frame:GetChildren() };
	for i = 1, table.getn(children) do
		HideMatchingNameText(children[i], name, keep);
	end
end

local function UpdateBossGuardianLabel(frame)
	local name = frame.creedPlatesPlateName;
	local holder = frame.creedPlatesBossGuardianLabelHolder;
	if ( not name or name == "" ) then
		if holder then holder:Hide() end
		return;
	end
	if ( not holder ) then
		holder = CreateFrame("Frame", nil, frame);
		holder:SetAllPoints(frame);
		holder:SetFrameLevel(frame:GetFrameLevel() + 12);
		local label = C.Text(holder, C.FONT, 11, "OUTLINE", "CENTER", 180);
		label:SetHeight(14);
		label:SetTextColor(1, 0.86, 0.78);
		frame.creedPlatesBossGuardianLabelHolder = holder;
		frame.creedPlatesBossGuardianLabel = label;
	end
	local label = frame.creedPlatesBossGuardianLabel;
	local bar = frame.creedPlatesOverlay or frame.creedPlatesSourceBar;
	frame.creedPlatesBossGuardianBar = bar;
	label:ClearAllPoints();
	if ( bar ) then
		label:SetPoint("BOTTOM", bar, "TOP", 0, 3);
	else
		label:SetPoint("BOTTOM", frame, "TOP", 0, 3);
	end
	label:SetText(name);
	label:SetAlpha(1);
	holder:Show();
end

local function ContainsStatusBar(frame)
	local children = { frame:GetChildren() };
	for i = 1, table.getn(children) do
		if ( children[i]:GetObjectType() == "StatusBar" or ContainsStatusBar(children[i]) ) then
			return true;
		end
	end
	return false;
end

local function FindStyledVisual(frame, source)
	local children = { frame:GetChildren() };
	for i = 1, table.getn(children) do
		local child = children[i];
		local width, height = child:GetWidth(), child:GetHeight();
		if ( child ~= source and child ~= frame.creedPlatesOverlay
				and child:GetObjectType() ~= "StatusBar"
				and width and height and width >= 30 and width <= 200
				and height >= 5 and height <= 60 and ContainsStatusBar(child) ) then
			return child;
		end
	end
	return nil;
end

local function FindNameFontString(frame, name)
	local fallback;
	local regions = { frame:GetRegions() };
	for i = 1, table.getn(regions) do
		local region = regions[i];
		if ( region and region:GetObjectType() == "FontString" ) then
			local text = region:GetText();
			if ( text == name ) then return region; end
			if ( not fallback and text and text ~= "" ) then fallback = region; end
		end
	end
	local children = { frame:GetChildren() };
	for i = 1, table.getn(children) do
		local found = FindNameFontString(children[i], name);
		if ( found and found:GetText() == name ) then return found; end
		if ( not fallback and found ) then fallback = found; end
	end
	return fallback;
end

local function ApplyBossGuardianLabelFont(frame)
	local label = frame.creedPlatesBossGuardianLabel;
	if not label then return end
	C.SetFace(label, C.FONT, 11, "OUTLINE");
	C.TextColor(label, 1, 0.86, 0.78);
end

local DEBUFF_ICON_SIZE = 16;
local DEBUFF_ICON_GAP = 2;
local MAX_DEBUFF_ICONS = 10;

local function CreateDebuffIcon(row, index)
	local icon = CreateFrame("Frame", nil, row);
	icon:SetWidth(DEBUFF_ICON_SIZE);
	icon:SetHeight(DEBUFF_ICON_SIZE);
	icon:SetPoint("LEFT", row, "LEFT", (index - 1) * (DEBUFF_ICON_SIZE + DEBUFF_ICON_GAP), 0);
	icon.texture = icon:CreateTexture(nil, "ARTWORK");
	icon.texture:SetAllPoints(icon);
	icon.texture:SetTexCoord(0.07, 0.93, 0.07, 0.93);
	icon.overlay = CreateFrame("Frame", nil, icon);
	icon.overlay:SetAllPoints(icon);
	icon.overlay:SetFrameLevel(icon:GetFrameLevel() + 1);
	local borderColor = { 0.05, 0.05, 0.05, 1 };
	icon.borderTop = icon.overlay:CreateTexture(nil, "OVERLAY");
	icon.borderTop:SetTexture("Interface\\Buttons\\WHITE8X8");
	icon.borderTop:SetVertexColor(unpack(borderColor));
	icon.borderTop:SetPoint("TOPLEFT", icon, "TOPLEFT", 0, 0);
	icon.borderTop:SetPoint("TOPRIGHT", icon, "TOPRIGHT", 0, 0);
	icon.borderTop:SetHeight(1);
	icon.borderBottom = icon.overlay:CreateTexture(nil, "OVERLAY");
	icon.borderBottom:SetTexture("Interface\\Buttons\\WHITE8X8");
	icon.borderBottom:SetVertexColor(unpack(borderColor));
	icon.borderBottom:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", 0, 0);
	icon.borderBottom:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 0);
	icon.borderBottom:SetHeight(1);
	icon.borderLeft = icon.overlay:CreateTexture(nil, "OVERLAY");
	icon.borderLeft:SetTexture("Interface\\Buttons\\WHITE8X8");
	icon.borderLeft:SetVertexColor(unpack(borderColor));
	icon.borderLeft:SetPoint("TOPLEFT", icon, "TOPLEFT", 0, 0);
	icon.borderLeft:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", 0, 0);
	icon.borderLeft:SetWidth(1);
	icon.borderRight = icon.overlay:CreateTexture(nil, "OVERLAY");
	icon.borderRight:SetTexture("Interface\\Buttons\\WHITE8X8");
	icon.borderRight:SetVertexColor(unpack(borderColor));
	icon.borderRight:SetPoint("TOPRIGHT", icon, "TOPRIGHT", 0, 0);
	icon.borderRight:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 0);
	icon.borderRight:SetWidth(1);
	icon.stacks = icon.overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	icon.stacks:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1);
	icon.stacks:SetTextColor(1, 1, 1, 1);
	icon.stacks:SetShadowColor(0, 0, 0, 1);
	icon.stacks:SetShadowOffset(1, -1);
	local stackFont, stackHeight = icon.stacks:GetFont();
	if ( stackFont and stackHeight ) then icon.stacks:SetFont(stackFont, stackHeight, "OUTLINE"); end
	icon.duration = icon.overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	icon.duration:SetPoint("TOPLEFT", icon, "TOPLEFT", 1, -1);
	icon.duration:SetTextColor(1, 1, 1, 1);
	icon.duration:SetShadowColor(0, 0, 0, 1);
	icon.duration:SetShadowOffset(1, -1);
	local durationFont, durationHeight = icon.duration:GetFont();
	if ( durationFont and durationHeight ) then
		icon.duration:SetFont(durationFont, durationHeight * 0.8, "OUTLINE");
	end
	return icon;
end

local function FindBossGuardianUnit(frame, name)
	local candidates = name and bossGuardianUnitsByName[name];
	if ( not candidates or table.getn(candidates) == 0 ) then return nil; end
	local bar = frame.creedPlatesSourceBar;
	local currentHealthRatio;
	if ( bar and bar.GetValue and bar.GetMinMaxValues ) then
		local value = bar:GetValue();
		local minimum, maximum = bar:GetMinMaxValues();
		if ( value and minimum and maximum and maximum > minimum ) then
			currentHealthRatio = (value - minimum) / (maximum - minimum);
		end
	end
	if ( not currentHealthRatio ) then return candidates[1]; end
	local best, bestDifference;
	for i = 1, table.getn(candidates) do
		local candidate = candidates[i];
		if ( candidate.hpm and candidate.hpm > 0 and candidate.hp ) then
			local difference = math.abs(candidate.hp / candidate.hpm - currentHealthRatio);
			if ( not bestDifference or difference < bestDifference ) then
				best, bestDifference = candidate, difference;
			end
		end
	end
	return best or candidates[1];
end

local function UpdateBossGuardianDebuffs(frame)
	local name = frame.creedPlatesPlateName
	local unit = FindBossGuardianUnit(frame, name)
	local row = frame.creedPlatesDebuffRow
	if not row then
		row = CreateFrame("Frame", nil, frame)
		row:SetHeight(DEBUFF_ICON_SIZE)
		row:SetFrameLevel(frame:GetFrameLevel() + 5)
		frame.creedPlatesDebuffRow = row
	end
	if unit and unit.id then frame.creedPlatesDebuffUnitID = unit.id end
	local unitID = frame.creedPlatesDebuffUnitID
	if not unitID then row:Hide(); return end
	-- Prefer the already cached boss/guardian unit snapshot to avoid an extra
	-- API call on every plate update. Query by ID only when the snapshot has no data.
	local debuffs = unit and unit.debuffs
	if type(debuffs) ~= "table" and type(AZS_GetDebuffs) == "function" then
		local ok, value = pcall(AZS_GetDebuffs, unitID)
		if ok and type(value) == "table" then debuffs = value end
	end
	if type(debuffs) ~= "table" then
		row:Hide()
		return
	end

	-- Debuff structure only changes when the game's revision changes. Reuse icons and
	-- skip texture/stack writes until the actual content changes; durations tick separately.
	local signatureParts = {}
	local count = math.min(table.getn(debuffs), MAX_DEBUFF_ICONS)
	for i = 1, count do
		local d = debuffs[i]
		if d then
			signatureParts[i] = tostring(d.icon or "") .. ":" .. tostring(d.stacks or 0)
				.. ":" .. tostring(d.permanent and 1 or 0) .. ":" .. tostring(d.ends or "")
		end
	end
	local signature = table.concat(signatureParts, "|")
	local changed = frame.creedPlatesDebuffSignature ~= signature
	frame.creedPlatesDebuffSignature = signature
	local iconIndex = 0
	for i = 1, count do
		local debuff = debuffs[i]
		if debuff then
			iconIndex = iconIndex + 1
			local icons = frame.creedPlatesDebuffIcons
			if not icons then icons = {}; frame.creedPlatesDebuffIcons = icons end
			local icon = icons[iconIndex]
			if not icon then
				icon = CreateDebuffIcon(row, iconIndex)
				icons[iconIndex] = icon
				changed = true
			end
			if changed then
				local texture = debuff.icon
				if not texture or texture == "" then texture = "Interface\\Icons\\INV_Misc_QuestionMark" end
				icon.texture:SetTexture(texture)
				if debuff.stacks and debuff.stacks > 1 then icon.stacks:SetText(debuff.stacks)
				else icon.stacks:SetText("") end
			end
			local remaining = debuff.remaining
			if not remaining and debuff.ends and type(AZS_GetRunTime) == "function" then
				local ok, runTime = pcall(AZS_GetRunTime)
				if ok and runTime and debuff.ends >= 0 then remaining = debuff.ends - runTime end
			end
			local durationText
			if debuff.permanent then durationText = "∞"
			elseif type(remaining) == "number" and remaining >= 0 then durationText = math.ceil(remaining)
			else durationText = "" end
			if icon.duration.arcaneText ~= durationText then
				icon.duration.arcaneText = durationText
				icon.duration:SetText(durationText)
			end
			if not icon:IsShown() then icon:Show() end
			if not icon.overlay:IsShown() then icon.overlay:Show() end
		end
	end
	local icons = frame.creedPlatesDebuffIcons or {}
	for i = iconIndex + 1, table.getn(icons) do if icons[i]:IsShown() then icons[i]:Hide() end end
	if iconIndex == 0 then row:Hide(); return end
	local width = iconIndex * DEBUFF_ICON_SIZE + (iconIndex - 1) * DEBUFF_ICON_GAP
	if row:GetWidth() ~= width then row:SetWidth(width) end
	local bar = frame.creedPlatesOverlay or frame.creedPlatesBossGuardianBar or frame.creedPlatesStyledVisual or frame
	local point, relativeTo, relativePoint, x, y = row:GetPoint()
	if point ~= "TOP" or relativeTo ~= bar or relativePoint ~= "BOTTOM" or x ~= 0 or y ~= -3 then
		row:ClearAllPoints()
		row:SetPoint("TOP", bar, "BOTTOM", 0, -3)
	end
	if not row:IsShown() then row:Show() end
end
local function HideNativePlate(frame, keep)
	local regions = { frame:GetRegions() };
	for i = 1, table.getn(regions) do
		local region = regions[i];
		if ( region and region:GetObjectType() == "Texture" ) then region:Hide(); end
	end
	local children = { frame:GetChildren() };
	for i = 1, table.getn(children) do
		if ( children[i] ~= keep and children[i] ~= frame.creedPlatesOverlay
				and children[i] ~= frame.creedPlatesShrunkLabelHolder ) then
			children[i]:Hide();
		end
	end
end

local function IsPlaceholderShrunk(frame)
	local visual = frame.creedPlatesStyledVisual;
	if ( visual and visual:IsShown() and frame.creedPlatesStyledOriginalScale ) then
		return visual:GetScale() < frame.creedPlatesStyledOriginalScale * 0.99;
	end
	local overlay = frame.creedPlatesOverlay;
	if ( overlay and overlay:IsShown() and frame.creedPlatesOverlayBaseWidth ) then
		return overlay:GetWidth() < frame.creedPlatesOverlayBaseWidth * 0.99;
	end
	local source = frame.creedPlatesSourceBar;
	if ( source and source:IsShown() and frame.creedPlatesSourceOriginalWidth ) then
		return source:GetWidth() < frame.creedPlatesSourceOriginalWidth * 0.99;
	end
	return false;
end

local function HideShrunkNameLabel(frame)
	if ( frame.creedPlatesShrunkLabelHolder ) then frame.creedPlatesShrunkLabelHolder:Hide(); end
end

-- Name above a shrunken plate; lives on its own child frame so the native-child hiding does not remove it.
local function UpdateShrunkNameLabel(frame)
	local name = frame.creedPlatesPlateName;
	if ( not Opt("showShrunkName") or frame.creedPlatesBossGuardian
			or not name or name == "" ) then
		HideShrunkNameLabel(frame);
		return;
	end
	local holder = frame.creedPlatesShrunkLabelHolder;
	if ( not holder ) then
		holder = CreateFrame("Frame", nil, frame);
		holder:SetAllPoints(frame);
		holder:SetFrameLevel(frame:GetFrameLevel() + 10);
		local text = C.Text(holder, C.FONT, 10, "OUTLINE", "CENTER", 160);
		text:SetHeight(12);
		text:SetTextColor(1, 0.86, 0.78);
		holder.text = text;
		frame.creedPlatesShrunkLabelHolder = holder;
	end
	local anchor = frame.creedPlatesOverlay or frame.creedPlatesSourceBar or frame;
	holder.text:ClearAllPoints();
	holder.text:SetPoint("BOTTOM", anchor, "TOP", 0, 2);
	holder.text:SetText(name);
	holder.text:SetAlpha(1);
	holder:Show();
end

local function UpdateNamePlaceholder(frame)
	local label = frame.creedPlatesBossGuardianLabel;
	if ( IsPlaceholderShrunk(frame) ) then
		if ( label ) then label:Hide(); end
		UpdateShrunkNameLabel(frame);
		return;
	end
	HideShrunkNameLabel(frame);
	if ( frame.creedPlatesBossGuardian and Opt("hideBossName") ) then
		if ( label ) then label:Hide(); end
		if ( frame.creedPlatesBossGuardianLabelHolder ) then frame.creedPlatesBossGuardianLabelHolder:Hide(); end
		local visual = frame.creedPlatesStyledVisual;
		local native = visual and FindNameFontString(visual, frame.creedPlatesPlateName);
		if ( native ) then native:SetAlpha(0); native:Hide(); end
		HideMatchingNameText(frame, frame.creedPlatesPlateName, nil);
		return;
	end
	local visual = frame.creedPlatesStyledVisual;
	local native = visual and FindNameFontString(visual, frame.creedPlatesPlateName);
	if ( native and NormalizeName(native:GetText()) == frame.creedPlatesPlateName ) then
		-- Let the replacement UI draw its own name where it expects it; our label
		-- sits behind its child frames and was not visible.
		native:SetAlpha(1);
		native:Show();
		if ( native:IsVisible() ) then
			if ( label ) then label:Hide(); end
			return;
		end
	end
	UpdateBossGuardianLabel(frame);
	ApplyBossGuardianLabelFont(frame);
	HideMatchingNameText(frame, frame.creedPlatesPlateName,
		frame.creedPlatesBossGuardianLabel);
end

-- The menu may replace the default enemy red with a saved three-stop color.
local function BarColor(category)
	if type(C.TinyPlatesBarColor) == "function" then return C.TinyPlatesBarColor(category) end
	return nil
end

local function CollectStatusBars(frame, list)
	local children = { frame:GetChildren() };
	for i = 1, table.getn(children) do
		if ( children[i]:GetObjectType() == "StatusBar" ) then table.insert(list, children[i]); end
		CollectStatusBars(children[i], list);
	end
	return list;
end

local function HideShrunkPlate(frame)
	if ( frame.creedPlatesBossGuardianLabel ) then frame.creedPlatesBossGuardianLabel:Hide(); end
	HideShrunkNameLabel(frame);
	HideNameText(frame);
	if ( frame.creedPlatesStyledVisual ) then frame.creedPlatesStyledVisual:Hide(); end
	if ( frame.creedPlatesOverlay ) then frame.creedPlatesOverlay:Hide(); end
	HideNativePlate(frame, nil);
end

local PLATE_ENEMY_COLORS = {
	{ 0.30, 0.02, 0.02 }, { 0.72, 0.05, 0.04 }, { 1.00, 0.30, 0.14 },
};

local function PlateColorStops(category)
	local color = BarColor(category);
	if not color then return PLATE_ENEMY_COLORS end
	return {
		{ color[1] * 0.32, color[2] * 0.32, color[3] * 0.32 },
		{ color[1] * 0.86, color[2] * 0.86, color[3] * 0.86 },
		{ C.Clamp(color[1] * 1.08, 0, 1), C.Clamp(color[2] * 1.08, 0, 1), C.Clamp(color[3] * 1.08, 0, 1) },
	};
end

local function PlateHealthText(value, maximum)
	local hp = math.floor((value or 0) + 0.5);
	local hpm = math.floor((maximum or 0) + 0.5);
	if hpm >= 100000 then return C.Short(hp) .. " / " .. C.Short(hpm) end
	return C.Commas(hp) .. " / " .. C.Commas(hpm);
end

local function UpdatePlateHealthText(frame, source)
	if not Opt("showHealthText") then
		if frame.creedPlatesHealthText and frame.creedPlatesHealthText:IsShown() then
			frame.creedPlatesHealthText:Hide();
		end
		return;
	end
	if not frame.creedPlatesHealthText then
		local special = frame.creedPlatesBossGuardian and true or false;
		local size = special and 10 or 8;
		local text = C.Text(frame.creedPlatesHealthBar.top, C.FONT, size, "OUTLINE",
			"CENTER", frame.creedPlatesOverlayWidth + 20);
		text:SetPoint("CENTER", frame.creedPlatesOverlay, "CENTER", 0, 0);
		frame.creedPlatesHealthText = text;
		frame.creedPlatesHealthTextSize = size;
		frame.creedPlatesHealthTextWidth = frame.creedPlatesOverlayWidth + 20;
	elseif frame.creedPlatesHealthTextSize ~= (frame.creedPlatesBossGuardian and 10 or 8) then
		local size = frame.creedPlatesBossGuardian and 10 or 8;
		C.SetFace(frame.creedPlatesHealthText, C.FONT, size, "OUTLINE");
		frame.creedPlatesHealthTextSize = size;
	end
	local width = frame.creedPlatesOverlayWidth + 20;
	if frame.creedPlatesHealthTextWidth ~= width then
		frame.creedPlatesHealthText:SetWidth(width);
		frame.creedPlatesHealthTextWidth = width;
	end
	local _, maximum = source:GetMinMaxValues();
	local value = source:GetValue();
	local text = PlateHealthText(value, maximum);
	C.SetText(frame.creedPlatesHealthText, text);
	if not frame.creedPlatesHealthText:IsShown() then frame.creedPlatesHealthText:Show() end;
end

local function ApplyPlateStyle(frame)
	local special = IsBossOrGuardianPlate(frame);
	local category = special and "boss" or "regular";
	if ( not special ) then
		if ( frame.creedPlatesBossGuardianLabel ) then frame.creedPlatesBossGuardianLabel:Hide(); end
		if ( frame.creedPlatesDebuffRow ) then frame.creedPlatesDebuffRow:Hide(); end
		if ( Opt("hideShrunkPlates") ) then
			HideShrunkPlate(frame);
			return;
		end
	end
	frame.creedPlatesNativeRestored = nil;
	HideNameText(frame);
	if ( frame.creedPlatesStyledVisual ) then frame.creedPlatesStyledVisual:Hide(); end
	local overlay = frame.creedPlatesOverlay;
	local bar = frame.creedPlatesHealthBar;
	local source = frame.creedPlatesSourceBar;
	if ( not overlay or not bar or not source ) then return; end
	local width = frame.creedPlatesOverlayWidth;
	local height = frame.creedPlatesOverlayHeight;
	if ( bar.w ~= width or bar.h ~= height ) then C.BarLayout(bar, width, height); end
	overlay:SetFrameLevel(math.max(frame:GetFrameLevel() + 2, source:GetFrameLevel() + 1));
	C.BarLevels(bar, overlay:GetFrameLevel());
	if ( frame.creedPlatesBarThemeStamp ~= C.palStamp ) then
		C.BarTheme(bar, C.Pal());
		frame.creedPlatesBarThemeStamp = C.palStamp;
	end
	local stops = PlateColorStops(category);
	C.BarColors(bar, stops[1], stops[2], stops[3]);
	UpdatePlateHealthText(frame, source);
	bar.snap = true;
	if ( not overlay:IsShown() ) then overlay:Show(); end
	HideNativePlate(frame, nil);
	UpdateNamePlaceholder(frame);
end

local function CreatePlateOverlay(frame)
	if ( not frame.creedPlatesStackOriginalWidth ) then frame.creedPlatesStackOriginalWidth = frame:GetWidth(); end
	if ( not frame.creedPlatesStackOriginalHeight ) then frame.creedPlatesStackOriginalHeight = frame:GetHeight(); end
	if ( not frame.creedPlatesStackOriginalScale ) then
		frame.creedPlatesStackOriginalScale = frame.creedPlatesOriginalScale or frame:GetScale();
	end
	if ( frame:GetWidth() ~= frame.creedPlatesStackOriginalWidth ) then frame:SetWidth(frame.creedPlatesStackOriginalWidth); end
	if ( frame:GetHeight() ~= frame.creedPlatesStackOriginalHeight ) then frame:SetHeight(frame.creedPlatesStackOriginalHeight); end
	if ( frame.creedPlatesStackPoint ) then
		frame:ClearAllPoints();
		frame:SetPoint(frame.creedPlatesStackPoint,
			frame.creedPlatesStackRelativeTo or frame:GetParent(),
			frame.creedPlatesStackRelativePoint,
			frame.creedPlatesStackX, frame.creedPlatesStackY);
		frame.creedPlatesStackPoint, frame.creedPlatesStackRelativeTo = nil, nil;
		frame.creedPlatesStackRelativePoint, frame.creedPlatesStackX, frame.creedPlatesStackY = nil, nil, nil;
	end
	if ( frame.creedPlatesStackNativePoint ) then
		frame:ClearAllPoints();
		frame:SetPoint(frame.creedPlatesStackNativePoint,
			frame.creedPlatesStackNativeRelativeTo or frame:GetParent(),
			frame.creedPlatesStackNativeRelativePoint,
			frame.creedPlatesStackNativeX, frame.creedPlatesStackNativeY);
		frame.creedPlatesStackNativePoint, frame.creedPlatesStackNativeRelativeTo = nil, nil;
		frame.creedPlatesStackNativeRelativePoint = nil;
		frame.creedPlatesStackNativeX, frame.creedPlatesStackNativeY = nil, nil;
	end
	frame.creedPlatesStackScaleApplied = nil;
	frame.creedPlatesStackCorrectionPending = nil;
	frame.creedPlatesVisualCorrectionX = nil;
	frame.creedPlatesVisualCorrectionY = nil;
	if ( frame:GetScale() ~= frame.creedPlatesStackOriginalScale ) then frame:SetScale(frame.creedPlatesStackOriginalScale); end

	if ( not frame.creedPlatesStyledVisual ) then
		frame.creedPlatesStyledVisual = FindStyledVisual(frame, frame.creedPlatesSourceBar);
	end
	if ( not frame.creedPlatesSourceBar ) then
		local children = { frame:GetChildren() };
		for i = 1, table.getn(children) do
			if ( children[i]:GetObjectType() == "StatusBar"
					and children[i]:GetWidth() > 0 and children[i]:GetHeight() > 0 ) then
				frame.creedPlatesSourceBar = children[i];
				break;
			end
		end
	end
	if ( not frame.creedPlatesSourceBar and frame.creedPlatesStyledVisual ) then
		local bars = {};
		CollectStatusBars(frame.creedPlatesStyledVisual, bars);
		for i = 1, table.getn(bars) do
			if ( bars[i]:GetWidth() > 0 and bars[i]:GetHeight() > 0 ) then
				frame.creedPlatesSourceBar = bars[i];
				break;
			end
		end
	end
	if ( not frame.creedPlatesSourceBar ) then
		local bars = {};
		CollectStatusBars(frame, bars);
		for i = 1, table.getn(bars) do
			if ( bars[i] ~= frame.creedPlatesOverlay
					and bars[i]:GetWidth() > 0 and bars[i]:GetHeight() > 0 ) then
				frame.creedPlatesSourceBar = bars[i];
				break;
			end
		end
	end
	if ( not frame.creedPlatesSourceBar ) then return false; end

	local source = frame.creedPlatesSourceBar;
	local originalWidth = frame.creedPlatesSourceOriginalWidth or source:GetWidth();
	local originalHeight = frame.creedPlatesSourceOriginalHeight or source:GetHeight();
	local point, relativeTo, relativePoint, x, y = source:GetPoint();
	local oldVisuals = frame.creedPlatesVisuals or {};
	for j = 1, table.getn(oldVisuals) do
		if ( oldVisuals[j].region == source ) then
			originalWidth, originalHeight = oldVisuals[j].width, oldVisuals[j].height;
			point, relativeTo, relativePoint = oldVisuals[j].point, oldVisuals[j].relativeTo, oldVisuals[j].relativePoint;
			x, y = oldVisuals[j].x, oldVisuals[j].y;
			break;
		end
	end
	if ( not point ) then return false; end
	frame.creedPlatesSourceOriginalWidth, frame.creedPlatesSourceOriginalHeight = originalWidth, originalHeight;
	local visualScale = IsBossOrGuardianPlate(frame) and 1 or PLATE_SCALE;
	local width, height = originalWidth * visualScale, originalHeight * visualScale;
	local adjustedX, adjustedY = x or 0, y or 0;
	if ( string.find(point, "LEFT") ) then adjustedX = adjustedX + width / 2; end
	if ( string.find(point, "BOTTOM") ) then adjustedY = adjustedY + height / 2; end
	local offsetX, offsetY = HORIZONTAL_OFFSET, VERTICAL_OFFSET;
	if ( visualScale == 1 ) then offsetX, offsetY = 0, 0; end

	if ( not frame.creedPlatesHealthBar ) then
		local bar = C.NewBar(frame, width, height, true);
		frame.creedPlatesHealthBar = bar;
		frame.creedPlatesOverlay = bar.frame;
	else
		local bar = frame.creedPlatesHealthBar;
		if ( bar.w ~= width or bar.h ~= height ) then C.BarLayout(bar, width, height); end
	end
	frame.creedPlatesOverlayPoint = point;
	frame.creedPlatesOverlayRelativeTo = relativeTo or frame;
	frame.creedPlatesOverlayRelativePoint = relativePoint or point;
	frame.creedPlatesOverlayX, frame.creedPlatesOverlayY = adjustedX, adjustedY;
	frame.creedPlatesOverlayWidth, frame.creedPlatesOverlayHeight = width, height;
	frame.creedPlatesOverlayBaseWidth, frame.creedPlatesOverlayBaseHeight = originalWidth, originalHeight;
	local overlay = frame.creedPlatesOverlay;
	overlay:ClearAllPoints();
	overlay:SetPoint(point, relativeTo or frame, relativePoint or point, adjustedX + offsetX, adjustedY + offsetY);
	return true;
end

local function RegisterPlate(frame)
	if not frame or not frame.IsVisible or not frame:IsVisible()
			or not frame.GetWidth or frame:GetWidth() <= 0
			or not frame.GetHeight or frame:GetHeight() <= 0 then return false end
	local known = knownPlates[frame] and true or false
	if not known and not IdentifyNameplate(frame) then return false end

	local currentName = GetPlateName(frame)
	local oldName = frame.creedPlatesPlateName
	if known and currentName ~= oldName and oldName ~= nil then
		-- Restore the previous unit before observing the new unit's native layout.
		RestoreNativeState(frame)
	end

	if not known then
		knownPlates[frame] = true
		table.insert(orderedPlates, frame)
		CaptureNativeState(frame)
		frame.creedPlatesOriginalScale = frame:GetScale() or 1
	elseif currentName ~= oldName then
		-- A recycled frame may have new regions or children. Capture them after
		-- old visuals are restored, so the new snapshot is genuinely native.
		local states = frame.creedPlatesNativeState or {}
		local seen = {}
		for i = 1, table.getn(states) do seen[states[i].object] = true end
		local fresh = {}
		SaveObjectState(frame, fresh)
		for i = 1, table.getn(fresh) do
			if not seen[fresh[i].object] then table.insert(states, fresh[i]) end
		end
		frame.creedPlatesNativeState = states
	end

	if currentName ~= oldName then
		frame.creedPlatesPlateName = currentName
		frame.creedPlatesDebuffUnitID = nil
		frame.creedPlatesDebuffSignature = nil
		frame.creedPlatesAppliedCategory = nil
		frame.creedPlatesStyleRevision = -1
		frame.creedPlatesNativeRestored = false
		if frame.creedPlatesHealthBar then frame.creedPlatesHealthBar.snap = true end
	end
	return true
end
local lastOverlaySyncTime;
local function SyncOverlayValues()
	local now = GetTime();
	local dt = lastOverlaySyncTime and math.min(now - lastOverlaySyncTime, 0.2) or OVERLAY_INTERVAL;
	if ( dt <= 0 ) then dt = OVERLAY_INTERVAL; end
	lastOverlaySyncTime = now;
	for i = 1, table.getn(orderedPlates) do
		local frame = orderedPlates[i];
		local bar = frame.creedPlatesHealthBar;
		local source = frame.creedPlatesSourceBar;
		if ( bar and source and frame:IsVisible() and frame.creedPlatesOverlay
				and frame.creedPlatesOverlay:IsShown() ) then
			local minimum, maximum = source:GetMinMaxValues();
			local range = ( maximum or 0 ) - ( minimum or 0 );
			local value = source:GetValue() or 0;
			local ratio = range > 0 and C.Clamp((value - minimum) / range, 0, 1) or 0;
			C.BarStep(bar, ratio, dt, now);
			UpdatePlateHealthText(frame, source);
			if ( frame.creedPlatesBarThemeStamp ~= C.palStamp ) then
				C.BarTheme(bar, C.Pal());
				frame.creedPlatesBarThemeStamp = C.palStamp;
			end
		end
	end
end

local function ApplyKnownPlate(frame, updateDebuffs)
	if not frame or not frame.GetObjectType then return end
	local objectType = frame:GetObjectType()
	-- Azeroth Survivors creates native nameplates as anonymous Buttons under WorldFrame.
	-- They expose the same frame API as ordinary Frames, but rejecting Button here means
	-- the scanner finds every plate and the styling pass silently skips every one.
	if objectType ~= "Frame" and objectType ~= "Button" then return end
	if not frame.IsVisible or not frame:IsVisible() then return end
	local special = IsBossOrGuardianPlate(frame)
	local category = special and "boss" or "regular"
	if frame.creedPlatesAppliedCategory ~= category
			or frame.creedPlatesStyleRevision ~= styleRevision then
		frame.creedPlatesAppliedCategory = category
		frame.creedPlatesStyleRevision = styleRevision
		if frame.creedPlatesNativeRestored then frame.creedPlatesNativeRestored = false end
		if CreatePlateOverlay(frame) then ApplyPlateStyle(frame) end
	end
	if special and updateDebuffs then
		if Opt("showDebuffs") then
			UpdateBossGuardianDebuffs(frame)
		elseif frame.creedPlatesDebuffRow and frame.creedPlatesDebuffRow:IsShown() then
			frame.creedPlatesDebuffRow:Hide()
		end
	end
end

local function StyleKnownPlates(updateDebuffs)
	RefreshBossGuardianNames()
	for i = 1, table.getn(orderedPlates) do ApplyKnownPlate(orderedPlates[i], updateDebuffs) end
end

local function ScanNameplates()
	if type(WorldFrame) ~= "table" or type(WorldFrame.GetChildren) ~= "function" then return end
	local children = { WorldFrame:GetChildren() }
	for i = 1, table.getn(children) do
		local frame = children[i]
		local objectType
		if frame then
			-- Some non-frame WorldFrame children do not expose the widget methods at all.
			local ok, value = pcall(function() return frame:GetObjectType() end)
			if ok then objectType = value end
		end
		-- WorldFrame can own other UI objects as well as nameplates. Restrict the
		-- scan to actual frames/buttons before calling visibility or geometry APIs.
		-- Azeroth Survivors' native plates are Buttons; hidden pooled plates can be 0x0.
		if (objectType == "Frame" or objectType == "Button")
				and frame.IsVisible and frame:IsVisible()
				and frame.GetWidth and frame:GetWidth() > 0
				and frame.GetHeight and frame:GetHeight() > 0 then
			RegisterPlate(frame)
		end
	end
end

local function RefreshAll()
	refreshPending = true
	if scanFrame then
		scanClock = 0
	end
end

local function RestoreAll()
	active = false
	for i = 1, table.getn(orderedPlates) do
		local frame = orderedPlates[i]
		if frame then
			RestoreNativeState(frame)
			if frame.creedPlatesOverlay then frame.creedPlatesOverlay:Hide() end
			if frame.creedPlatesDebuffRow then frame.creedPlatesDebuffRow:Hide() end
			if frame.creedPlatesBossGuardianLabel then frame.creedPlatesBossGuardianLabel:Hide() end
			if frame.creedPlatesBossGuardianLabelHolder then frame.creedPlatesBossGuardianLabelHolder:Hide() end
			if frame.creedPlatesShrunkLabelHolder then frame.creedPlatesShrunkLabelHolder:Hide() end
			frame.creedPlatesNativeRestored = true
		end
	end
end

local function SetEnabled(on)
	on = on and true or false
	if active == on then
		if active then RefreshAll() end
		return
	end
	active = on
	styleRevision = styleRevision + 1
	for i = 1, table.getn(orderedPlates) do
		orderedPlates[i].creedPlatesAppliedCategory = nil
		orderedPlates[i].creedPlatesStyleRevision = -1
	end
	if active then
		scanClock = 0
		refreshPending = true
		if scanFrame then scanFrame:Show() end
	else
		RestoreAll()
		if scanFrame then scanFrame:Hide() end
	end
end

C.TinyPlatesRefresh = function(force)
	styleRevision = styleRevision + 1
	if force then RefreshAll() else refreshPending = true end
end

C.OnInit(function()
	local d = C.DB("nameplates", {
		showDebuffs = true, hideShrunkPlates = false, hideBossName = false,
		showShrunkName = false, showHealthText = true, enabled = true,
	})
	active = d.enabled ~= false
	scanFrame = CreateFrame("Frame", "CreedUITinyPlatesDriver")
	scanFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	scanFrame:RegisterEvent("CHAT_MSG_ADDON")
	scanFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	scanFrame:SetScript("OnEvent", function()
		if event == "CHAT_MSG_ADDON" and arg1 ~= "AZSUNITS" then return end
		RefreshAll()
	end)
	scanFrame:SetScript("OnUpdate", function()
		if not active then return end
		local dt = arg1 or 0
		if dt > 0.1 then dt = 0.1 end
		scanClock = scanClock - dt
		if scanClock <= 0 then
			scanClock = SCAN_INTERVAL
			ScanNameplates()
			refreshPending = true
		end
		overlayClock = overlayClock - dt
		if overlayClock <= 0 then
			overlayClock = OVERLAY_INTERVAL
			SyncOverlayValues()
		end
		debuffClock = debuffClock - dt
		local updateDebuffs = false
		if debuffClock <= 0 then
			debuffClock = DEBUFF_INTERVAL
			updateDebuffs = true
		end
		if refreshPending then
			refreshPending = false
			local ok, err = pcall(StyleKnownPlates, updateDebuffs)
			if not ok then
				C.Print(C.L("Creed UI nameplates stopped after an error: ") .. tostring(err))
				SetEnabled(false)
			end
		elseif updateDebuffs then
			local ok, err = pcall(function()
				RefreshBossGuardianNames()
				for i = 1, table.getn(orderedPlates) do
					local frame = orderedPlates[i]
					if frame.creedPlatesBossGuardian and frame:IsVisible() and Opt("showDebuffs") then
						UpdateBossGuardianDebuffs(frame)
					end
				end
			end)
			if not ok then
				C.Print(C.L("Creed UI nameplate debuff update stopped after an error: ") .. tostring(err))
				SetEnabled(false)
			end
		end
	end)
	if not active then scanFrame:Hide() end
end)

C.OnWorld(function()
	if active and scanFrame then RefreshAll(); scanFrame:Show() end
end)

C.OnLogout(function() RestoreAll() end)

C.RegisterPart({
	key = "nameplates", name = "Tiny Plates",
	note = "Half-size regular nameplates, with full-size boss and guardian plates.",
	get = function() return active end,
	set = function(on)
		local d = C.DB("nameplates")
		d.enabled = on and true or false
		SetEnabled(on)
	end,
})

