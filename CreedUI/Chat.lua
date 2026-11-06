-- Creed UI: the chat, cleaned up. The scroll buttons and the speech bubble go: the mouse wheel
-- scrolls (Shift jumps to the top or the bottom), and a small arrow shows while you're scrolled up
-- (click it to come back down). A soft glass fades in behind the lines while the mouse is over
-- them or you type, and the typing box gets the boss timer's glass and metal lines. A window that
-- would reach under the skill bar's left emblem stops short of it. Turning this part off puts the
-- game's chat back as it was. With the frames unlocked (a right click on the C), a "Chat" box
-- lies over it: drag it to move the chat, drag its corner grip to size it; both are kept.

local C = CreedUI
local DEFAULTS = { enabled = true }
local BUTTONS = { "UpButton", "DownButton", "BottomButton", "ButtonFrame" }
local WHEEL_LINES = 2

local db
local W = {}
local S = { applied = false, wheel = {}, inputRegions = nil, inputBackdrop = nil, glassA = 0, arrowA = 0, stamp = -1,
	keepClock = 0 }
local Call = C.Call

local function ChatFrames()
	local out = {}
	for i = 1, (tonumber(NUM_CHAT_WINDOWS) or 7) do
		local f = getglobal("ChatFrame" .. i)
		if type(f) == "table" and f.AddMessage then table.insert(out, f) end
	end
	return out
end

local function Selected()
	local f = SELECTED_CHAT_FRAME
	if type(f) ~= "table" or not f.AtBottom then f = getglobal("ChatFrame1") end
	if type(f) ~= "table" or not f.AtBottom then return nil end
	return f
end

-- is the mouse over this frame? (the cursor against its corners, in its own scale)
local function IsOver(f)
	if type(f) ~= "table" or not f.GetLeft or type(GetCursorPosition) ~= "function" then return false end
	if f.IsVisible and not f:IsVisible() then return false end
	local l, r, t, b = f:GetLeft(), f:GetRight(), f:GetTop(), f:GetBottom()
	if not (l and r and t and b) then return false end
	local x, y = GetCursorPosition()
	local s = f:GetEffectiveScale() or 1
	if not (x and y) or s <= 0 then return false end
	x, y = x / s, y / s
	return x >= l - 8 and x <= r + 8 and y >= b - 8 and y <= t + 8
end

-- the wheel: two lines a notch; with Shift, all the way
local function Wheel()
	local f = this
	if not (f and arg1) then return end
	local jump = type(IsShiftKeyDown) == "function" and IsShiftKeyDown()
	if arg1 > 0 then
		if jump then f:ScrollToTop() else for i = 1, WHEEL_LINES do f:ScrollUp() end end
	else
		if jump then f:ScrollToBottom() else for i = 1, WHEEL_LINES do f:ScrollDown() end end
	end
end

------------------------------------------------------------------------ building
local function Build()
	local chat = getglobal("ChatFrame1")
	if type(chat) ~= "table" or W.glass then return end
	-- the glass behind the lines: dark at the bottom, fading out to the top
	local g = CreateFrame("Frame", "CreedUIChatGlass", UIParent)
	W.glass = g
	g:SetFrameStrata(chat:GetFrameStrata() or "LOW")
	g:SetFrameLevel(math.max(0, (chat:GetFrameLevel() or 1) - 1))
	g:SetPoint("TOPLEFT", chat, "TOPLEFT", -8, 8)
	g:SetPoint("BOTTOMRIGHT", chat, "BOTTOMRIGHT", 8, -6)
	g.fill = C.Tex(g, "BACKGROUND", C.FLAT)
	g.fill:SetAllPoints(g)
	g.fill:SetGradientAlpha("VERTICAL", 0.02, 0.02, 0.03, 0.70, 0.02, 0.02, 0.03, 0.10)
	g.edge = C.Tex(g, "BORDER", C.FLAT)
	g.edge:SetPoint("TOPLEFT", g, "TOPLEFT", 0, 0)
	g.edge:SetPoint("BOTTOMLEFT", g, "BOTTOMLEFT", 0, 0)
	g.edge:SetWidth(1)
	g.base = C.Tex(g, "BORDER", C.FLAT)
	g.base:SetPoint("BOTTOMLEFT", g, "BOTTOMLEFT", 0, 0)
	g.base:SetPoint("BOTTOMRIGHT", g, "BOTTOMRIGHT", 0, 0)
	g.base:SetHeight(1)
	g:SetAlpha(0)
	g:Hide()

	-- the arrow back down to the newest lines
	local a = CreateFrame("Button", "CreedUIChatDown", UIParent)
	W.arrow = a
	a:SetWidth(18)
	a:SetHeight(18)
	a:SetFrameStrata(chat:GetFrameStrata() or "LOW")
	a:SetFrameLevel((chat:GetFrameLevel() or 1) + 6)
	a:SetPoint("BOTTOMRIGHT", chat, "BOTTOMRIGHT", 6, -4)
	a.glow = C.Tex(a, "BACKGROUND", C.ART .. "Glow", "ADD")
	a.glow:SetWidth(34)
	a.glow:SetHeight(34)
	a.glow:SetPoint("CENTER", a, "CENTER", 0, 0)
	a.tex = C.Tex(a, "ARTWORK", C.ART .. "Caret")
	a.tex:SetAllPoints(a)
	a.tex:SetTexCoord(0, 1, 1, 0) -- pointing down
	a:SetScript("OnClick", function()
		local f = Selected()
		if f then f:ScrollToBottom() end
	end)
	a:SetScript("OnEnter", function()
		if GameTooltip then
			GameTooltip:SetOwner(a, "ANCHOR_RIGHT")
			GameTooltip:AddLine(C.L("Back to the newest lines"), 1, 1, 1)
			C.ShowTip()
		end
	end)
	a:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
	a:SetAlpha(0)
	a:Hide()
end

-- the typing box: the game's border goes, the timer's glass and lines come
local function DressInput(on)
	local box = ChatFrameEditBox
	if type(box) ~= "table" or not box.GetRegions then return end
	if on then
		if S.inputRegions then return end
		S.inputRegions = {}
		local regions = { box:GetRegions() }
		for i = 1, table.getn(regions) do
			local r = regions[i]
			if type(r) == "table" and r.GetObjectType and r:GetObjectType() == "Texture" and r:IsShown() then
				r:Hide()
				table.insert(S.inputRegions, r)
			end
		end
		if box.GetBackdrop and box:GetBackdrop() then
			S.inputBackdrop = box:GetBackdrop()
			box:SetBackdrop(nil)
		end
		if not W.inputFill then
			W.inputFill = box:CreateTexture(nil, "BACKGROUND")
			W.inputFill:SetTexture(C.FLAT)
			W.inputFill:SetPoint("TOPLEFT", box, "TOPLEFT", 4, -3)
			W.inputFill:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -4, 3)
			W.inputFill:SetGradientAlpha("VERTICAL", 0.02, 0.02, 0.03, 0.88, 0.07, 0.07, 0.09, 0.80)
			W.inputTop = box:CreateTexture(nil, "BACKGROUND")
			W.inputTop:SetTexture(C.FLAT)
			W.inputTop:SetPoint("TOPLEFT", W.inputFill, "TOPLEFT", 0, 0)
			W.inputTop:SetPoint("TOPRIGHT", W.inputFill, "TOPRIGHT", 0, 0)
			W.inputTop:SetHeight(1)
			W.inputBottom = box:CreateTexture(nil, "BACKGROUND")
			W.inputBottom:SetTexture(C.FLAT)
			W.inputBottom:SetPoint("BOTTOMLEFT", W.inputFill, "BOTTOMLEFT", 0, 0)
			W.inputBottom:SetPoint("BOTTOMRIGHT", W.inputFill, "BOTTOMRIGHT", 0, 0)
			W.inputBottom:SetHeight(1)
			W.inputGemL = box:CreateTexture(nil, "BORDER")
			W.inputGemL:SetTexture(C.ART .. "Diamond")
			W.inputGemL:SetWidth(9)
			W.inputGemL:SetHeight(9)
			W.inputGemL:SetPoint("CENTER", W.inputFill, "LEFT", 0, 0)
			W.inputGemR = box:CreateTexture(nil, "BORDER")
			W.inputGemR:SetTexture(C.ART .. "Diamond")
			W.inputGemR:SetWidth(9)
			W.inputGemR:SetHeight(9)
			W.inputGemR:SetPoint("CENTER", W.inputFill, "RIGHT", 0, 0)
			S.stamp = -1
		end
		for _, t in ipairs({ W.inputFill, W.inputTop, W.inputBottom, W.inputGemL, W.inputGemR }) do t:Show() end
	else
		if S.inputRegions then
			for i = 1, table.getn(S.inputRegions) do S.inputRegions[i]:Show() end
			S.inputRegions = nil
		end
		if S.inputBackdrop then
			box:SetBackdrop(S.inputBackdrop)
			S.inputBackdrop = nil
		end
		if W.inputFill then
			for _, t in ipairs({ W.inputFill, W.inputTop, W.inputBottom, W.inputGemL, W.inputGemR }) do t:Hide() end
		end
	end
end

------------------------------------------------------------------------ clear of the emblem
-- A chat window reaching under the skill bar's left emblem (the hero's class's) gives up the end of
-- its width, enough to keep its glass clear of the emblem's paint; it gets it back when the bar moves away, the part
-- is turned off, or you size the window yourself (then that width is the one it keeps clear with).
local CLEAR_GAP, CLEAR_MIN = 6, 200

local function Emblem()
	local bar = CreedUIBar
	local d = bar and bar.deco and bar.deco.emblems and bar.deco.emblems[1]
	if not (d and bar:IsShown() and d.GetLeft and d:GetLeft()) then return nil end
	return d, bar
end

local function Clear(f, d, bar)
	if not (f.GetWidth and f:IsShown() and f:GetLeft()) then return end
	local own = f:GetWidth()
	if f.creedSetW and math.abs(own - f.creedSetW) > 1 then f.creedW, f.creedSetW = nil, nil end -- sized by hand
	local natural = f.creedW or own
	local want = natural
	if d then
		local k = bar:GetEffectiveScale() / f:GetEffectiveScale() -- a texture is in its frame's scale
		local el, et = bar.deco.LeftEnd() -- the emblem's paint, not the picture's edge
		local dl, dt = (el or d:GetLeft()) * k, (et or d:GetTop()) * k
		local l, b = f:GetLeft(), f:GetBottom()
		if b - 6 < dt and l + natural + 8 > dl - CLEAR_GAP then
			want = math.max(CLEAR_MIN, math.min(natural, dl - CLEAR_GAP - 8 - l))
		end
	end
	if math.abs(want - natural) < 0.5 then
		if f.creedW then
			f:SetWidth(f.creedW)
			f.creedW, f.creedSetW = nil, nil
		end
	elseif not f.creedSetW or math.abs(f.creedSetW - want) > 0.5 then
		f.creedW = natural
		f.creedSetW = want
		f:SetWidth(want)
	end
end

local function ClearAll(on)
	local d, bar = nil, nil
	if on then d, bar = Emblem() end
	local frames = ChatFrames()
	for i = 1, table.getn(frames) do
		local f = frames[i]
		if on then
			Clear(f, d, bar)
		elseif f.creedW then
			f:SetWidth(f.creedW)
			f.creedW, f.creedSetW = nil, nil
		end
	end
end

------------------------------------------------------------------------ moved and sized by hand
-- The chat's place and size as you left them ({ x, y, w, h }, its bottom left in UIParent), and
-- where the game had it, kept too, so turning the part off or resetting the frames gives it back.
local function Home(f)
	if db.home then return end
	db.home = { x = f:GetLeft(), y = f:GetBottom(), w = f:GetWidth(), h = f:GetHeight() }
end

local function Place(f, p)
	f:ClearAllPoints()
	f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", p.x, p.y)
	f:SetWidth(p.w)
	f:SetHeight(p.h)
	f.creedW, f.creedSetW = nil, nil -- sized by hand: that's the width it keeps clear with
end

local function GoHome(f)
	if type(f) ~= "table" or not db.home then return end
	Place(f, db.home)
	db.home = nil
end

local function SavePlace(f)
	f:StopMovingOrSizing()
	db.place = { x = f:GetLeft(), y = f:GetBottom(), w = f:GetWidth(), h = f:GetHeight() }
	Place(f, db.place) -- held by one point from now on, as it was left
end

local function BuildMover()
	local chat = getglobal("ChatFrame1")
	if W.mover or type(chat) ~= "table" then return end
	local m = CreateFrame("Frame", "CreedUIChatMover", UIParent)
	W.mover = m
	m:SetAllPoints(chat)
	m:SetFrameStrata("DIALOG")
	m:SetBackdrop({ bgFile = C.FLAT, edgeFile = C.FLAT, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	m:SetBackdropColor(0.1, 0.2, 0.4, 0.35)
	m:SetBackdropBorderColor(0.91, 0.70, 0.30, 0.8)
	m:EnableMouse(true)
	m:RegisterForDrag("LeftButton")
	m:SetScript("OnDragStart", function()
		Home(chat)
		chat:SetMovable(true)
		chat:StartMoving()
	end)
	m:SetScript("OnDragStop", function() SavePlace(chat) end)
	m.text = C.Text(m, C.FONT, 11, "OUTLINE", "CENTER", 200)
	m.text:SetPoint("CENTER", m, "CENTER", 0, 0)
	m.text:SetTextColor(0.98, 0.85, 0.52)
	C.LText(m.text, "Chat")
	-- the corner grip: drag it to size the window
	local g = CreateFrame("Button", "CreedUIChatGrip", m)
	m.grip = g
	g:SetWidth(16)
	g:SetHeight(16)
	g:SetPoint("BOTTOMRIGHT", m, "BOTTOMRIGHT", 0, 0)
	g.tex = C.Tex(g, "OVERLAY", "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	g.tex:SetAllPoints(g)
	g:SetScript("OnMouseDown", function()
		Home(chat)
		chat:SetResizable(true)
		chat:SetMinResize(200, 80)
		chat:StartSizing("BOTTOMRIGHT")
	end)
	g:SetScript("OnMouseUp", function() SavePlace(chat) end)
	m:Hide()
end

------------------------------------------------------------------------ on and off
local function Apply()
	Build()
	local on = db.enabled and true or false
	local frames = ChatFrames()
	for i = 1, table.getn(frames) do
		local f = frames[i]
		local name = f:GetName() or ("ChatFrame" .. i)
		for j = 1, table.getn(BUTTONS) do
			if on then C.HideStock(name .. BUTTONS[j]) else C.RestoreStock(name .. BUTTONS[j]) end
		end
		if on and not S.wheel[f] and f.EnableMouseWheel then
			S.wheel[f] = { script = f:GetScript("OnMouseWheel"), enabled = f.IsMouseWheelEnabled and f:IsMouseWheelEnabled() }
			f:EnableMouseWheel(true)
			f:SetScript("OnMouseWheel", Wheel)
		elseif not on and S.wheel[f] then
			f:SetScript("OnMouseWheel", S.wheel[f].script)
			f:EnableMouseWheel(S.wheel[f].enabled and true or false)
			S.wheel[f] = nil
		end
	end
	if on then C.HideStock("ChatFrameMenuButton") else C.RestoreStock("ChatFrameMenuButton") end
	DressInput(on)
	BuildMover()
	local chat = getglobal("ChatFrame1")
	if type(chat) == "table" then
		if on and db.place then
			Home(chat)
			Place(chat, db.place)
		elseif not on then
			GoHome(chat)
		end
	end
	ClearAll(on)
	S.applied = on
	if not on then
		if W.glass then W.glass:Hide() end
		if W.arrow then W.arrow:Hide() end
		S.glassA, S.arrowA = 0, 0
	end
end

local function Theme(pal)
	local rim = pal.rim
	if W.glass then
		W.glass.edge:SetVertexColor(rim[1], rim[2], rim[3], 0.35)
		W.glass.base:SetVertexColor(rim[1], rim[2], rim[3], 0.25)
		W.arrow.tex:SetVertexColor(pal.title[1], pal.title[2], pal.title[3])
		W.arrow.glow:SetVertexColor(pal.glow[1], pal.glow[2], pal.glow[3], 0.35)
	end
	if W.inputFill then
		W.inputTop:SetVertexColor(rim[1], rim[2], rim[3], 0.6)
		W.inputBottom:SetVertexColor(rim[1], rim[2], rim[3], 0.4)
		W.inputGemL:SetVertexColor(rim[1], rim[2], rim[3])
		W.inputGemR:SetVertexColor(rim[1], rim[2], rim[3])
	end
end

------------------------------------------------------------------------ every frame
local function Step(dt)
	if W.mover then
		local want = (db.enabled and C.unlocked) and true or false
		if want ~= (W.mover:IsShown() and true or false) then
			if want then W.mover:Show() else W.mover:Hide() end
		end
	end
	-- the frames' places reset: the chat goes back to the game's
	if S.resetSeen ~= C.resetStamp then
		if S.resetSeen ~= nil and db.place then
			db.place = nil
			GoHome(getglobal("ChatFrame1"))
		end
		S.resetSeen = C.resetStamp
	end
	if not (db.enabled and S.applied and W.glass) then return end
	local pal = C.Pal()
	if S.stamp ~= C.palStamp then
		S.stamp = C.palStamp
		Theme(pal)
	end
	-- look ten times a second: the mouse over the lines, typing, scrolled up
	S.lookClock = (S.lookClock or 0) - dt
	if S.lookClock <= 0 then
		S.lookClock = 0.1
		local chat = Selected()
		local box = ChatFrameEditBox
		local typing = type(box) == "table" and box.IsVisible and box:IsVisible()
		S.wantGlass = (typing or IsOver(chat) or IsOver(box)) and 1 or 0
		S.scrolledUp = chat and chat.AtBottom and not chat:AtBottom()
	end
	-- the glass while you read (mouse over) or type
	local want = S.wantGlass or 0
	S.glassA = C.Toward(S.glassA, want, want > S.glassA and 8 or 3, dt)
	if S.glassA < 0.01 then
		C.Vis(W.glass, false)
	else
		C.Vis(W.glass, true)
		C.Alpha(W.glass, C.Smooth(S.glassA))
	end
	-- the arrow while scrolled up
	S.arrowA = C.Toward(S.arrowA, S.scrolledUp and 1 or 0, 8, dt)
	if S.arrowA < 0.01 then
		C.Vis(W.arrow, false)
	else
		C.Vis(W.arrow, true)
		C.Alpha(W.arrow, C.Smooth(S.arrowA) * (0.75 + 0.25 * math.sin(GetTime() * 3)))
	end
	-- clear of the skill bar's emblem, looked at twice a second (the bar can move or be sized)
	S.clearClock = (S.clearClock or 0) - dt
	if S.clearClock <= 0 then
		S.clearClock = 0.5
		if Emblem() then ClearAll(true) end -- while the bar steps aside for the cards, as it was
	end
	-- the game can show its own pieces again (a chat window made later, a reloaded border)
	S.keepClock = S.keepClock - dt
	if S.keepClock <= 0 then
		S.keepClock = 2
		local n = 0
		for f in pairs(S.wheel) do n = n + 1 end
		if n < table.getn(ChatFrames()) then Apply() end
		if S.inputRegions then
			for i = 1, table.getn(S.inputRegions) do
				if S.inputRegions[i]:IsShown() then S.inputRegions[i]:Hide() end
			end
		end
	end
end

------------------------------------------------------------------------ setup
C.OnInit(function()
	db = C.DB("chat", DEFAULTS)
	local driver = CreateFrame("Frame", "CreedUIChatDriver")
	local broken = false
	driver:SetScript("OnUpdate", function()
		if broken then return end
		local dt = arg1 or 0
		if dt > 0.1 then dt = 0.1 end
		local ok, err = pcall(Step, dt)
		if not ok then
			broken = true
			db.enabled = false
			pcall(Apply)
			db.enabled = true
			C.Print(C.L("the chat's dress came off after an error, so it's the game's own again: ") .. tostring(err))
		end
	end)
end)

C.OnWorld(function()
	if not db then return end
	local ok, err = pcall(Apply)
	if not ok then C.Print(C.L("couldn't dress the chat: ") .. tostring(err)) end
end)

C.RegisterPart({
	key = "chat", name = "Chat",
	note = "No scroll buttons: the mouse wheel scrolls (Shift for the top or bottom), an arrow brings you back down. A glass behind the lines while you read or type, and a typing box in the timer's style.",
	get = function() return db and db.enabled end,
	set = function(on)
		if db then
			db.enabled = on and true or false
			Apply()
		end
	end,
})
