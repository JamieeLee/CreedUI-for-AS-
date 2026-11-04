-- A mock 1.12 client for CreedUI UI, run under real Lua 5.0.
-- Widget methods are checked against the game's own method lists; frames are laid out with
-- real anchoring so a frame can be dumped and rendered.

local SCRATCH = MOCK_SCRATCH
dofile(SCRATCH .. "/engine_methods.lua")
dofile(SCRATCH .. "/bt/charw.lua")
dofile(SCRATCH .. "/engine_methods_chat.lua")

MOCK = { now = 1000.0, chat = {}, problems = {}, hud = { clock = true }, verbose = false }
local M = MOCK
local SW, SH = 1280, 720

function GetTime() return M.now end

local function Problem(msg)
	table.insert(M.problems, msg .. "\n" .. debug.traceback("", 3))
end
M.Problem = Problem

local function BadNumber(v)
	return type(v) ~= "number" or v ~= v or v == 1/0 or v == -1/0
end

------------------------------------------------------------------ objects
local IMPL = {}
local all = {}          -- every object, in creation order
local updaters, eventFrames = {}, {}
local texRank, nextRank = {}, 1
local created = 0

local function NewObject(kind, parent)
	created = created + 1
	local obj = { __kind = kind, __parent = parent, __points = {}, __shown = true, __alpha = 1, __scale = 1,
		__scripts = {}, __events = {}, __id = created }
	setmetatable(obj, { __index = function(t, k)
		local first = string.sub(k, 1, 1)
		if first == string.upper(first) and string.find(first, "%a") then
			local list = ENGINE_METHODS[kind]
			if not list or not list[k] then
				error("the game has no " .. kind .. ":" .. k, 2)
			end
			M.calls = (M.calls or 0) + 1
			if M.callNames then M.callNames[k] = (M.callNames[k] or 0) + 1 end
			return IMPL[k] or function() end
		end
		return nil
	end })
	table.insert(all, obj)
	return obj
end

local function CheckNums(name, ...)
	for i = 1, arg.n do
		if BadNumber(arg[i]) then Problem(name .. ": bad number #" .. i .. " " .. tostring(arg[i])) end
	end
end

function IMPL.SetPoint(self, point, rel, relPoint, x, y)
	if type(rel) == "number" then -- SetPoint(point, x, y)
		rel, relPoint, x, y = nil, nil, rel, relPoint
	end
	if type(rel) == "string" then rel = getglobal(rel) end
	CheckNums("SetPoint", x or 0, y or 0)
	self.__points[point] = { rel = rel, relPoint = relPoint or point, x = x or 0, y = y or 0 }
	self.__all = nil
end
function IMPL.ClearAllPoints(self) self.__points = {}; self.__all = nil end
function IMPL.GetPoint(self, wanted)
	local point = wanted
	local info = point and self.__points[point]
	if not info then
		point, info = next(self.__points)
	end
	if not info then return nil end
	return point, info.rel, info.relPoint, info.x, info.y
end
function IMPL.SetAllPoints(self, rel)
	if type(rel) == "string" then rel = getglobal(rel) end
	self.__points = {}
	self.__all = rel or self.__parent
end
-- as the game: hiding a shown frame runs OnHide on it and on each of its shown descendants
local hideWatch = {}
local function ShownChain(o)
	local f = o
	while f do
		if not f.__shown then return false end
		f = f.__parent
	end
	return true
end
local function Below(o, root)
	local p = o
	while p do
		if p == root then return true end
		p = p.__parent
	end
	return false
end
function IMPL.Show(self)
	local was = ShownChain(self)
	self.__shown = true
	if was or not ShownChain(self) then return end
	local fired = {}
	for i = 1, table.getn(hideWatch) do
		local o = hideWatch[i]
		if o.__scripts.OnShow and Below(o, self) and not fired[o] then
			local ok, f = true, o
			while f ~= self do
				if not f.__shown then ok = false break end
				f = f.__parent
			end
			if ok then
				fired[o] = true
				local saved = this
				this = o
				o.__scripts.OnShow()
				this = saved
			end
		end
	end
end
function IMPL.Hide(self)
	local was = self.__shown and ShownChain(self)
	self.__shown = false
	if not was then return end
	local fired = {}
	for i = 1, table.getn(hideWatch) do
		local o = hideWatch[i]
		if o.__scripts.OnHide and Below(o, self) and not fired[o] then
			-- shown itself and everything between it and the frame hidden
			local ok, f = true, o
			while f ~= self do
				if not f.__shown then ok = false break end
				f = f.__parent
			end
			if ok then
				fired[o] = true
				local saved = this
				this = o
				o.__scripts.OnHide()
				this = saved
			end
		end
	end
end
function IMPL.IsShown(self) return self.__shown end
function IMPL.IsVisible(self)
	local o = self
	while o do
		if not o.__shown then return false end
		o = o.__parent
	end
	return true
end
function IMPL.SetAlpha(self, a)
	CheckNums("SetAlpha", a)
	if a < -0.001 or a > 1.001 then Problem("SetAlpha out of range " .. a) end
	self.__alpha = a
end
function IMPL.GetAlpha(self) return self.__alpha end
function IMPL.SetScale(self, s)
	CheckNums("SetScale", s)
	if s <= 0 then Problem("SetScale <= 0") end
	self.__scale = s
end
function IMPL.GetScale(self) return self.__scale end
local function EffScale(f)
	local s = 1
	while f do
		s = s * (f.__scale or 1)
		f = f.__parent
	end
	return s
end
function IMPL.GetEffectiveScale(self) return EffScale(self) end
function IMPL.SetWidth(self, w)
	CheckNums("SetWidth", w)
	if w < 0 then Problem("SetWidth < 0: " .. w) end
	self.__w = w
end
function IMPL.SetHeight(self, h)
	CheckNums("SetHeight", h)
	if h < 0 then Problem("SetHeight < 0: " .. h) end
	self.__h = h
end
function IMPL.SetScript(self, name, fn)
	self.__scripts[name] = fn
	if name == "OnUpdate" then table.insert(updaters, self) end
	if (name == "OnHide" or name == "OnShow") and fn and not self.__hideWatched then
		self.__hideWatched = true
		table.insert(hideWatch, self)
	end
end
function IMPL.GetScript(self, name) return self.__scripts[name] end
function IMPL.RegisterEvent(self, name)
	self.__events[name] = true
	table.insert(eventFrames, self)
end
function IMPL.UnregisterEvent(self, name) self.__events[name] = nil end
function IMPL.RegisterForDrag(self) end
function IMPL.EnableMouse(self, on) self.__mouse = on and true or false end
function IMPL.SetMovable(self, on) self.__movable = on end
function IMPL.SetClampedToScreen(self) end
function IMPL.SetFrameStrata(self, s)
	local ok = { BACKGROUND = 1, LOW = 1, MEDIUM = 1, HIGH = 1, DIALOG = 1, FULLSCREEN = 1, FULLSCREEN_DIALOG = 1, TOOLTIP = 1 }
	if not ok[s] then Problem("bad strata " .. tostring(s)) end
	self.__strata = s
end
local function Strata(f)
	while f do
		if f.__strata then return f.__strata end
		f = f.__parent
	end
	return "MEDIUM"
end
function IMPL.GetFrameStrata(self) return Strata(self) end
function IMPL.SetFrameLevel(self, l)
	CheckNums("SetFrameLevel", l)
	self.__level = l
end
function IMPL.GetFrameLevel(self)
	if self.__level then return self.__level end
	if self.__parent and self.__parent.__kind ~= "UIParent" then return IMPL.GetFrameLevel(self.__parent) + 1 end
	return 1
end
function IMPL.SetBackdrop(self, b) self.__backdrop = b end
function IMPL.SetBackdropColor(self, r, g, b, a) CheckNums("SetBackdropColor", r, g, b, a or 1); self.__bdColor = { r, g, b, a or 1 } end
function IMPL.SetBackdropBorderColor(self, r, g, b, a) CheckNums("SetBackdropBorderColor", r, g, b, a or 1); self.__bdBorder = { r, g, b, a or 1 } end
function IMPL.GetParent(self) return self.__parent end
function IMPL.SetParent(self, p)
	if type(p) == "string" then p = getglobal(p) end
	self.__parent = p
end
function IMPL.UnregisterAllEvents(self) self.__events = {} end
function IMPL.GetName(self) return self.__name end
function IMPL.CreateTexture(self, name, layer)
	local t = NewObject("Texture", self)
	t.__layer = layer or "ARTWORK"
	return t
end
function IMPL.CreateFontString(self, name, layer)
	local fs = NewObject("FontString", self)
	fs.__layer = layer or "ARTWORK"
	return fs
end
function IMPL.StartMoving(self) self.__moving = true end
function IMPL.StopMovingOrSizing(self)
	if not self.__moving then return end
	self.__moving = false
	local l, b, r, t = M.Rect(self)
	local dx, dy = M.dragBy and M.dragBy[1] or 0, M.dragBy and M.dragBy[2] or 0
	local s = EffScale(self)
	self.__points = { TOPLEFT = { rel = UIParent, relPoint = "BOTTOMLEFT", x = (l + dx) / s, y = (t + dy) / s } }
	self.__all = nil
end
function IMPL.Click(self)
	local fn = self.__scripts.OnClick
	if fn then
		this = self
		fn()
	end
end

-- textures
local BLENDS = { DISABLE = 1, ALPHAKEY = 1, BLEND = 1, ADD = 1, MOD = 1 }
function IMPL.SetTexture(self, a, g, b, al)
	if type(a) == "number" then
		CheckNums("SetTexture", a, g, b, al or 1)
		self.__tex = nil
		self.__solid = { a, g, b, al or 1 }
		return 1
	end
	if a ~= nil and type(a) ~= "string" then Problem("bad texture " .. tostring(a)) end
	self.__tex, self.__solid = a, nil
	if a and not texRank[a] then
		texRank[a] = nextRank
		nextRank = nextRank + 1
	end
	if a and string.find(a, "AddOns\\SmoothBossTimer\\Art\\") then
		local name = string.gsub(a, ".*\\", "")
		M.artUsed = M.artUsed or {}
		M.artUsed[name] = true
	end
	return 1
end
function IMPL.GetTexture(self) return self.__tex end
-- StatusBar widget methods used by the TinyPlates regression fixture.
function IMPL.SetMinMaxValues(self, minimum, maximum)
	CheckNums("SetMinMaxValues", minimum, maximum)
	if maximum < minimum then Problem("StatusBar max below min") end
	self.__minimum, self.__maximum = minimum, maximum
end
function IMPL.GetMinMaxValues(self) return self.__minimum or 0, self.__maximum or 1 end
function IMPL.SetValue(self, value)
	CheckNums("SetValue", value)
	self.__value = value
end
function IMPL.GetValue(self) return self.__value or 0 end
function IMPL.SetStatusBarColor(self, r, g, b, a)
	CheckNums("SetStatusBarColor", r, g, b, a or 1)
	self.__barColor = { r, g, b, a == nil and 1 or a }
end
function IMPL.GetStatusBarColor(self)
	local c = self.__barColor or { 1, 0, 0, 1 }
	return c[1], c[2], c[3], c[4]
end
function IMPL.SetStatusBarTexture(self, path)
	if not self.__statusTexture then self.__statusTexture = self:CreateTexture(nil, "ARTWORK") end
	self.__statusTexture:SetTexture(path)
end
function IMPL.GetStatusBarTexture(self) return self.__statusTexture end
function IMPL.SetBlendMode(self, mode)
	if not BLENDS[mode] then Problem("bad blend mode " .. tostring(mode)) end
	self.__blend = mode
end
function IMPL.SetVertexColor(self, r, g, b, a)
	CheckNums("SetVertexColor", r, g, b, a or 1)
	if a == nil and self.__vc then a = self.__vc[4] end
	self.__vc = { r, g, b, a or 1 }
	self.__grad = nil
end
function IMPL.SetGradientAlpha(self, o, r1, g1, b1, a1, r2, g2, b2, a2)
	if o ~= "HORIZONTAL" and o ~= "VERTICAL" then Problem("bad gradient orientation " .. tostring(o)) end
	CheckNums("SetGradientAlpha", r1, g1, b1, a1, r2, g2, b2, a2)
	self.__grad = { o, { r1, g1, b1, a1 }, { r2, g2, b2, a2 } }
	self.__vc = nil
end
function IMPL.SetGradient(self, o, r1, g1, b1, r2, g2, b2)
	IMPL.SetGradientAlpha(self, o, r1, g1, b1, 1, r2, g2, b2, 1)
end
function IMPL.SetTexCoord(self, ...)
	if arg.n ~= 4 and arg.n ~= 8 then Problem("SetTexCoord with " .. arg.n .. " args") end
	for i = 1, arg.n do
		if BadNumber(arg[i]) then Problem("SetTexCoord bad number") end
	end
	local c = {}
	for i = 1, arg.n do c[i] = arg[i] end
	self.__tc = c
end
function IMPL.SetDesaturated(self, on) self.__desat = on end

-- font strings
function IMPL.SetFont(self, path, size, flags)
	if type(path) ~= "string" or BadNumber(size) then Problem("bad SetFont") end
	if flags ~= nil and type(flags) ~= "string" then Problem("bad font flags") end
	self.__font, self.__size, self.__flags = path, size, flags
	return 1
end
function IMPL.GetFont(self) return self.__font, self.__size, self.__flags end
function IMPL.SetText(self, t)
	if t ~= nil and type(t) ~= "string" and type(t) ~= "number" then Problem("bad text " .. type(t)) end
	self.__text = t and tostring(t) or nil
	M.setTextCount = (M.setTextCount or 0) + 1
end
function IMPL.GetText(self) return self.__text end
function IMPL.SetTextColor(self, r, g, b, a)
	CheckNums("SetTextColor", r, g, b, a or 1)
	self.__color = { r, g, b, a or 1 }
end
function IMPL.SetJustifyH(self, j)
	if j ~= "LEFT" and j ~= "RIGHT" and j ~= "CENTER" then Problem("bad justify " .. tostring(j)) end
	self.__justify = j
end
function IMPL.SetShadowColor(self, r, g, b, a) self.__shadow = { r, g, b, a or 1 } end
function IMPL.SetShadowOffset(self, x, y) self.__shadowOff = { x, y } end

local function Plain(text)
	text = string.gsub(text or "", "|c%x%x%x%x%x%x%x%x", "")
	return (string.gsub(text, "|r", ""))
end
M.Plain = Plain
local function TextWidth(fs)
	local w = 0
	local tab = CHAR_W[fs.__font or ""] or CHAR_W["Fonts\\FRIZQT__.TTF"]
	local text = Plain(fs.__text)
	for i = 1, string.len(text) do
		local c = string.byte(text, i)
		if c >= 32 and c <= 126 then
			w = w + tab[c - 31]
		elseif c >= 224 then
			w = w + 100 -- Chinese, Japanese, Korean: about a square
		elseif c >= 208 and c <= 211 then
			w = w + tab[string.byte("o") - 31] * 1.15 -- Cyrillic: a broad letter
		elseif c >= 192 then
			w = w + tab[string.byte("e") - 31] -- a letter with an accent: as wide as most letters
		elseif c < 128 or c >= 192 then
			w = w + 60
		end -- the rest of a UTF-8 letter adds nothing
	end
	return w * (fs.__size or 12) / 100
end
function IMPL.GetStringWidth(self) return TextWidth(self) end
M.TextWidth = TextWidth
function IMPL.GetWidth(self)
	if self.__w then return self.__w end
	local l, b, r, t = M.Rect(self)
	return (r - l) / EffScale(self.__kind == "Texture" and self.__parent or self.__kind == "FontString" and self.__parent or self)
end
function IMPL.GetHeight(self)
	if self.__h then return self.__h end
	local l, b, r, t = M.Rect(self)
	return (t - b) / EffScale(self.__kind == "Texture" and self.__parent or self.__kind == "FontString" and self.__parent or self)
end
function IMPL.GetLeft(self) local l = M.Rect(self) return l / EffScale(self) end
function IMPL.GetRight(self) local l, b, r = M.Rect(self) return r / EffScale(self) end
function IMPL.GetTop(self) local l, b, r, t = M.Rect(self) return t / EffScale(self) end
function IMPL.GetBottom(self) local l, b = M.Rect(self) return b / EffScale(self) end
function IMPL.GetCenter(self) local l, b, r, t = M.Rect(self) local s = EffScale(self) return (l + r) / 2 / s, (b + t) / 2 / s end

------------------------------------------------------------------ layout
local function Owner(o)
	if o.__kind == "Texture" or o.__kind == "FontString" then return o.__parent end
	return o
end
local function PointXY(l, b, r, t, p)
	local x, y = (l + r) * 0.5, (b + t) * 0.5
	if string.find(p, "LEFT") then x = l elseif string.find(p, "RIGHT") then x = r end
	if string.find(p, "TOP") then y = t elseif string.find(p, "BOTTOM") then y = b end
	return x, y
end
local depth = 0
function M.Rect(o)
	if o == UIParent or o == WorldFrame or o == nil then return 0, 0, SW, SH end
	depth = depth + 1
	if depth > 60 then
		depth = 0
		error("anchor loop")
	end
	local s = EffScale(Owner(o))
	local L, Rr, T, B, CX, CY
	if o.__all then
		L, B, Rr, T = M.Rect(o.__all)
	end
	for name, p in pairs(o.__points) do
		local rel = p.rel or o.__parent
		local rl, rb, rr, rt = M.Rect(rel)
		local ax, ay = PointXY(rl, rb, rr, rt, p.relPoint)
		ax, ay = ax + p.x * s, ay + p.y * s
		if string.find(name, "LEFT") then L = ax elseif string.find(name, "RIGHT") then Rr = ax else CX = ax end
		if string.find(name, "TOP") then T = ay elseif string.find(name, "BOTTOM") then B = ay else CY = ay end
	end
	local w = o.__w and o.__w * s
	local h = o.__h and o.__h * s
	if o.__kind == "FontString" then
		w = w or TextWidth(o) * s
		h = h or (o.__size or 12) * 1.2 * s
	end
	local l, r, b, t
	if L and Rr then l, r = L, Rr
	elseif L then l, r = L, L + (w or 0)
	elseif Rr then l, r = Rr - (w or 0), Rr
	elseif CX then l = CX - (w or 0) * 0.5; r = l + (w or 0)
	else l, r = 0, w or 0 end
	if T and B then b, t = B, T
	elseif T then b, t = T - (h or 0), T
	elseif B then b, t = B, B + (h or 0)
	elseif CY then b = CY - (h or 0) * 0.5; t = b + (h or 0)
	else b, t = 0, h or 0 end
	depth = depth - 1
	return l, b, r, t
end

------------------------------------------------------------------ globals
function setglobal(k, v) _G[k] = v end
function getglobal(k) return _G[k] end

UIParent = { __kind = "UIParent", __points = {}, __shown = true, __alpha = 1, __scale = 1, __scripts = {}, __events = {} }
function UIParent:GetWidth() return SW end
function UIParent:GetHeight() return SH end
function UIParent:GetEffectiveScale() return 1 end
function UIParent:GetFrameLevel() return 0 end
function UIParent:GetChildren() return IMPL.GetChildren(self) end
function UIParent:GetRegions() return IMPL.GetRegions(self) end
function UIParent:GetParent() return nil end
function UIParent:IsVisible() return 1 end
WorldFrame = UIParent

function CreateFrame(kind, name, parent)
	if kind ~= "Frame" and kind ~= "Button" and kind ~= "StatusBar" and kind ~= "CheckButton" then
		error("unexpected frame type " .. tostring(kind))
	end
	local f = NewObject(kind, parent)
	f.__name = name
	if name then setglobal(name, f) end
	return f
end

-- the Minimap is a widget type of its own
do
	local list = {}
	for k in pairs(ENGINE_METHODS["Frame"]) do list[k] = true end
	for _, k in ipairs({ "GetZoom", "GetZoomLevels", "SetZoom", "SetMaskTexture", "GetPingPosition", "PingLocation" }) do list[k] = true end
	ENGINE_METHODS["Minimap"] = list
end
function IMPL.GetZoom(self) return self.__zoom or 0 end
function IMPL.SetZoom(self, z)
	if type(z) ~= "number" or z < 0 or z > 5 then Problem("SetZoom out of range: " .. tostring(z)) end
	self.__zoom = z
end
function IMPL.GetZoomLevels(self) return 6 end
function M.MakeMinimap()
	local m = NewObject("Minimap", UIParent)
	m.__name = "Minimap"
	Minimap = m
	m:SetWidth(140)
	m:SetHeight(140)
	m:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -24, -30)
	for _, name in ipairs({ "MinimapBorder", "MinimapBorderTop", "MinimapZoomIn", "MinimapZoomOut", "MinimapToggleButton",
		"GameTimeFrame", "MinimapZoneTextButton", "MinimapNorthTag" }) do
		local f = CreateFrame("Frame", name, m)
		f:SetWidth(20)
		f:SetHeight(20)
	end
end
function GetMinimapZoneText() return M.zoneText end
function GetScreenWidth() return SW end
function GetScreenHeight() return SH end

-- the chat windows, their buttons and the typing box
function IMPL.ScrollUp(self) self.__scroll = (self.__scroll or 0) + 1 end
function IMPL.ScrollDown(self) self.__scroll = math.max(0, (self.__scroll or 0) - 1) end
function IMPL.ScrollToTop(self) self.__scroll = 99 end
function IMPL.ScrollToBottom(self) self.__scroll = 0 end
function IMPL.AtBottom(self) return (self.__scroll or 0) == 0 end
function IMPL.GetObjectType(self) return self.__kind end
function IMPL.GetChildren(self)
	local out = {}
	for i = 1, table.getn(all) do
		local o = all[i]
		if o.__parent == self and o.__kind ~= "Texture" and o.__kind ~= "FontString" then table.insert(out, o) end
	end
	return unpack(out)
end
function IMPL.IsMouseEnabled(self) return self.__mouse and 1 or nil end
function IMPL.SetID(self, id) self.__id_ = id end
function IMPL.GetID(self) return self.__id_ or 0 end
function IMPL.SetNormalTexture(self, path)
	if not self.__normal then self.__normal = self:CreateTexture(nil, "ARTWORK") end
	self.__normal:SetTexture(path)
end
function IMPL.GetNormalTexture(self) return self.__normal end
function IMPL.Disable(self) self.__disabled = true end
function IMPL.Enable(self) self.__disabled = nil end
function IMPL.IsEnabled(self) if self.__disabled then return nil end return 1 end
function IMPL.SetChecked(self, checked) self.__checked = checked and true or false end
function IMPL.GetChecked(self) return self.__checked and 1 or nil end
function IMPL.EnableMouseWheel(self, on) self.__wheel = on and true or false end
function IMPL.IsMouseWheelEnabled(self) return self.__wheel and 1 or nil end
function IMPL.GetBackdrop(self) return self.__backdrop end
function IMPL.GetRegions(self)
	local out = {}
	for i = 1, table.getn(all) do
		local o = all[i]
		if o.__parent == self and (o.__kind == "Texture" or o.__kind == "FontString") then table.insert(out, o) end
	end
	return unpack(out)
end
function M.MakeChat()
	NUM_CHAT_WINDOWS = 7
	for i = 1, 2 do
		local f = NewObject("ScrollingMessageFrame", UIParent)
		f.__name = "ChatFrame" .. i
		setglobal(f.__name, f)
		f:SetWidth(420)
		f:SetHeight(140)
		f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 32, 95)
		if i > 1 then f:Hide() end
		for _, suffix in ipairs({ "UpButton", "DownButton", "BottomButton" }) do
			local b = CreateFrame("Button", f.__name .. suffix, f)
			b:SetWidth(24)
			b:SetHeight(24)
		end
	end
	SELECTED_CHAT_FRAME = ChatFrame1
	local menu = CreateFrame("Button", "ChatFrameMenuButton", UIParent)
	menu:SetWidth(24)
	menu:SetHeight(24)
	local box = NewObject("EditBox", UIParent)
	box.__name = "ChatFrameEditBox"
	ChatFrameEditBox = box
	box:SetWidth(420)
	box:SetHeight(32)
	box:SetPoint("TOPLEFT", ChatFrame1, "BOTTOMLEFT", -5, -2)
	for _, part in ipairs({ "Left", "Right", "Mid" }) do
		local t = box:CreateTexture("ChatFrameEditBox" .. part, "BACKGROUND")
		t:SetTexture("Interface\\ChatFrame\\UI-ChatInputBorder-" .. part)
		t:SetAllPoints(box)
	end
	local header = box:CreateFontString("ChatFrameEditBoxHeader", "ARTWORK")
	header:SetFont("Fonts\\ARIALN.TTF", 14)
	header:SetText("Say:")
	header:SetPoint("LEFT", box, "LEFT", 15, 0)
	box:Hide()
end
M.cursorX, M.cursorY = 0, 0
function GetCursorPosition() return M.cursorX, M.cursorY end
function IsShiftKeyDown() return M.shift and 1 or nil end
M.localTime = { text = "10:42 PM", hour = 22, minute = 42, is24Hour = false }
function AZS_GetLocalTime()
	if not M.localTime then return nil end
	return { text = M.localTime.text, hour = M.localTime.hour, minute = M.localTime.minute, is24Hour = M.localTime.is24Hour }
end

-- the stock game menu, and the FrameXML panel helpers
function ShowUIPanel(f)
	if not f then return end
	local was = f:IsShown()
	f:Show()
	if not was and f.__scripts.OnShow then
		this = f
		f.__scripts.OnShow()
	end
end
function HideUIPanel(f)
	if f then f:Hide() end
end
-- Azeroth Survivors: the talent key and button open the run's own talent window (the game counts
-- the toggles in AZS_TALENT_TOGGLES)
M.talentToggles = 0
function ToggleTalentFrame()
	M.talentToggles = M.talentToggles + 1
	AZS_TALENT_TOGGLES = tostring(M.talentToggles)
end

-- the game's own font objects: its face, and CreateFont to try one
M.nativeFace = "Fonts\\NATIVE.TTF"
local function FontObject(name)
	local f = { __name = name }
	function f.SetFont(self, face, size, flags)
		if face == "DEFAULT" then return false end -- a newer client has no such alias
		self.__face, self.__size, self.__flags = face, size, flags
		return true
	end
	function f.GetFont(self) return self.__face, self.__size, self.__flags end
	return f
end
function CreateFont(name) return FontObject(name) end
GameFontNormal = FontObject("GameFontNormal")
GameFontNormal:SetFont(M.nativeFace, 12)
STANDARD_TEXT_FONT = M.nativeFace

M.tip = { lines = {}, shown = false }
-- Native 1.12 ColorSelect methods on the global ColorPickerFrame.
M.pickerColor = { 0.8, 0.8, 0.8 }
ColorPickerFrame = NewObject("ColorSelect", UIParent)
ColorPickerFrame.__name = "ColorPickerFrame"
setglobal("ColorPickerFrame", ColorPickerFrame)
ColorPickerFrame.__color = { 0.8, 0.8, 0.8 }
ColorPickerFrame.shown = false
function IMPL.SetColorRGB(self, r, g, b)
	self.__color = { r, g, b }
	if self.func then self.func() end -- 1.12 OnColorSelect invokes func
end
function IMPL.GetColorRGB(self)
	return self.__color[1], self.__color[2], self.__color[3]
end
function M.PickColor(r, g, b)
	ColorPickerFrame:SetColorRGB(r, g, b)
end
function M.CancelColor()
	if ColorPickerFrame.cancelFunc then
		ColorPickerFrame.cancelFunc(ColorPickerFrame.previousValues)
	end
	ColorPickerFrame.shown = false
	ColorPickerFrame:Hide()
end
GameTooltip = {
	SetOwner = function(self, owner, anchor) M.tip.owner, M.tip.anchor, M.tip.lines = owner, anchor, {} end,
	ClearAllPoints = function() end,
	SetPoint = function() end,
	AddLine = function(self, text, r, g, b)
		if type(text) ~= "string" then Problem("tooltip line not a string") end
		table.insert(M.tip.lines, text)
	end,
	Show = function() M.tip.shown = true end,
	-- the first line, as the client's SetText: the tooltip's lines start over
	SetText = function(self, text, r, g, b)
		if type(text) ~= "string" then Problem("tooltip text not a string") end
		M.tip.lines = { text }
	end,
	SetAction = function(self, slot) M.tip.lines = { "Action " .. tostring(slot) }; M.tip.action = slot end,
	SetInventoryItem = function(self, unit, slot) M.tip.lines = { "Item in slot " .. tostring(slot) }; M.tip.inv = slot end,
	SetUnit = function(self, unit) M.tip.lines = { "Unit " .. tostring(unit) }; M.tip.unit = unit end,
	SetTalent = function(self, tab, i) M.tip.lines = { "Talent " .. tostring(tab) .. "." .. tostring(i) } end,
	AddDoubleLine = function(self, l, r)
		if type(l) ~= "string" or type(r) ~= "string" then Problem("tooltip double line not strings") end
		table.insert(M.tip.lines, l .. " | " .. r)
	end,
	Hide = function() M.tip.shown = false end,
	IsShown = function() return M.tip.shown end,
}
DEFAULT_CHAT_FRAME = { AddMessage = function(self, msg)
	table.insert(M.chat, msg)
	if M.verbose then print("CHAT: " .. msg) end
end }
UISpecialFrames = {}
SlashCmdList = {}
M.zoneText = "Elwynn Forest"
function GetRealZoneText() return M.zoneText end
math.randomseed(1234)
random = math.random

------------------------------------------------------------------ the game's run API
M.api = true
local function InstallAPI()
	function AZS_GetPhase()
		if M.apiThrows then error("boom") end
		return M.phase
	end
	function AZS_GetRunTime() return M.runTime end
	function AZS_GetRunLength() return M.runLength or 0 end
	-- debuffs by unit name: { name, icon, ends (run second), duration, stacks, dispelType, permanent }
	function M.Debuffs(name)
		local out = {}
		local list = M.debuffs and M.debuffs[name]
		for i = 1, table.getn(list or {}) do
			local d = list[i]
			out[i] = { spell = i, name = d.name, icon = d.icon, stacks = d.stacks or 1, duration = d.duration,
				remaining = d.ends and math.max(0, d.ends - (M.runTime or 0)) or nil, permanent = d.permanent, dispelType = d.dispelType }
		end
		return out
	end
	function AZS_GetBosses()
		if M.apiThrows then error("boom") end
		local out = {}
		for i = 1, table.getn(M.bosses or {}) do
			local b = M.bosses[i]
			out[i] = { id = i, name = b.name, hp = b.hp, hpm = b.hpm, final = b.final, enraged = b.enraged, debuffs = M.Debuffs(b.name) }
		end
		return out
	end
	function AZS_GetUpcomingBosses() return {} end
	function AZS_GetGuardians()
		local out = {}
		for i = 1, table.getn(M.guardians or {}) do
			local g = M.guardians[i]
			out[i] = { id = g.id, name = g.name, hp = g.hp, hpm = g.hpm, awake = g.awake, debuffs = M.Debuffs(g.name) }
		end
		return out
	end
	function AZS_GetSummons()
		local out = {}
		for i = 1, table.getn(M.summons or {}) do
			local p = M.summons[i]
			out[i] = { id = p.id, entry = 1, key = p.key, kind = p.kind, name = p.name, icon = p.icon, permanent = p.permanent }
		end
		return out
	end
	function AZS_GetSummonGroups()
		local groups, byKey = {}, {}
		for i = 1, table.getn(M.summons or {}) do
			local p = M.summons[i]
			local g = byKey[p.key]
			if not g then
				g = { key = p.key, kind = p.kind, name = p.name, icon = p.icon, count = 0, permanent = 0, temporary = 0 }
				byKey[p.key] = g
				table.insert(groups, g)
			end
			g.count = g.count + 1
			if p.permanent then g.permanent = g.permanent + 1 else g.temporary = g.temporary + 1 end
		end
		return groups, table.getn(M.summons or {})
	end
	function AZS_GetTotems() return M.totems or {} end
	-- the meter API (version 1), from M.meter: { damage = {...}, healing = {...}, boss = {...}, party = {...} }
	-- strict, as the game's: a passed nil counts as an argument
	function AZS_GetMeterContext(...)
		if arg.n ~= 0 then M.Problem("AZS_GetMeterContext called with " .. arg.n .. " arguments"); return nil, { code = "INVALID_ARGUMENT", retryable = false } end
		if not M.meter then return nil, { code = "NO_RUN", retryable = true } end
		return { apiVersion = 1, runId = M.meterRun or "run1", phase = M.phase, localOwnerId = "H1" }
	end
	function AZS_GetMeterSnapshot(...)
		if arg.n ~= 1 then M.Problem("AZS_GetMeterSnapshot called with " .. arg.n .. " arguments"); return nil, { code = "INVALID_ARGUMENT", retryable = false } end
		local q = arg[1]
		local KEYS = { apiVersion = true, runId = true, metric = true, healingPerspective = true, scope = true, ownerId = true,
			period = true, groupBy = true, windowSeconds = true, checkpointId = true }
		if type(q) ~= "table" then return nil, { code = "INVALID_ARGUMENT" } end
		for k in pairs(q) do if not KEYS[k] then M.Problem("meter query: unknown key " .. tostring(k)); return nil, { code = "INVALID_ARGUMENT" } end end
		if q.apiVersion ~= 1 then return nil, { code = "UNSUPPORTED_VERSION" } end
		if not M.meter then return nil, { code = "NO_RUN", retryable = true } end
		if q.runId ~= (M.meterRun or "run1") then return nil, { code = "RUN_MISMATCH" } end
		local w = q.windowSeconds
		if type(w) ~= "number" or (w ~= 0 and (w < 5 or w > 120)) then M.Problem("meter query: bad window " .. tostring(w)) end
		local which = q.metric == "healing" and "healing" or (q.period == "encounter" and "boss") or (q.scope == "party" and "party") or "damage"
		if which == "party" and not M.meter.party then return nil, { code = "NO_PARTY", retryable = true, retryAfterSeconds = 1 } end
		if which == "boss" and not M.meter.boss then return nil, { code = "NO_ENCOUNTER", retryable = true, retryAfterSeconds = 0.2 } end
		local cp
		if q.checkpointId then
			cp = M.checkpoints and M.checkpoints[q.checkpointId]
			if not cp then return nil, { code = "CHECKPOINT_EXPIRED" } end
		end
		local list = M.meter[which] or {}
		local snap = { apiVersion = 1, status = "ready", complete = true, context = AZS_GetMeterContext(), rows = {}, sources = {},
			actors = {}, contributions = {}, totals = {} }
		local total = 0
		for i = 1, table.getn(list) do
			local l = list[i]
			local amount = l.amount - ((cp and cp[which .. ":" .. (l.key or l.name)]) or 0)
			if amount > 0 then
				total = total + amount
				local rowId = "r" .. i
				local row = { rowId = rowId, displayAmount = amount, periodAmount = l.amount, memberIds = { "c" .. i }, nativeProc = l.proc,
					periodAverage = { status = "ready", value = amount / 100 }, displayRate = { status = "ready", value = amount / 100 } }
				if cp then row.checkpointAverage = { status = "ready", value = amount / 50 } end
				if which == "party" then
					row.ownerId = l.key
					snap.actors[l.key] = { actorId = l.key, kind = "hero", name = l.name, classKey = l.class,
						portrait = { portraitKey = "pk" .. i, status = "ready" } }
				else
					row.ownerId = "H1"
					if q.groupBy == "actor_source" then
						local a = l.actor or { id = "H1", kind = "hero", name = "CreedUI" }
						row.actorId = a.id
						snap.actors[a.id] = { actorId = a.id, kind = a.kind, name = a.name, summonKey = a.summonKey,
							portrait = { portraitKey = "pk" .. a.id, status = "ready" } }
					end
					row.sourceKey = l.key
					snap.sources[l.key] = { sourceKey = l.key, name = l.name, abilityKey = l.ability, talentKey = l.talent,
						icon = l.icon and { status = "ready", path = l.icon } or { status = "missing" } }
					table.insert(snap.contributions, { rowId = "c" .. i, schoolState = l.school and "known" or "unknown", schoolMask = l.school, displayAmount = amount })
				end
				table.insert(snap.rows, row)
			end
		end
		table.sort(snap.rows, function(a, b) return a.displayAmount > b.displayAmount end)
		for i = 1, table.getn(snap.rows) do snap.rows[i].share = total > 0 and snap.rows[i].displayAmount / total or 0 end
		snap.totals = { displayAmount = total, displayRate = { status = "ready", value = total / 100 },
			recentRate = (w and w > 0) and { status = "ready", value = total / 80 } or { status = "not_requested" } }
		if table.getn(snap.rows) == 0 then snap.status = "ready_empty" end
		M.snapshots = (M.snapshots or 0) + 1
		return snap
	end
	-- the hero's loadout, from M.loadout: { abilities = { { key, rank, slotId, icon, passive, learned } } };
	-- as the game's: one plain query table with apiVersion, runId and ownerId only
	function AZS_GetMeterLoadout(...)
		if arg.n ~= 1 then M.Problem("AZS_GetMeterLoadout called with " .. arg.n .. " arguments"); return nil, { code = "INVALID_ARGUMENT" } end
		local q = arg[1]
		if type(q) ~= "table" then M.Problem("loadout query must be a plain table"); return nil, { code = "INVALID_ARGUMENT" } end
		for k in pairs(q) do
			if k ~= "apiVersion" and k ~= "runId" and k ~= "ownerId" then M.Problem("loadout query: unknown key " .. tostring(k)); return nil, { code = "INVALID_ARGUMENT" } end
		end
		if q.apiVersion ~= 1 then return nil, { code = "UNSUPPORTED_VERSION" } end
		if not M.meter then return nil, { code = "NO_RUN", retryable = true } end
		if q.runId ~= (M.meterRun or "run1") then return nil, { code = "RUN_MISMATCH" } end
		if not M.loadout then return nil, { code = "NOT_READY", retryable = true } end
		M.loadoutReads = (M.loadoutReads or 0) + 1
		local out = { apiVersion = 1, complete = true, context = AZS_GetMeterContext(), ownerId = "H1", loadoutRevision = "l1",
			equipment = {}, abilities = {}, talents = {}, runJewelry = {}, sources = {}, actors = {} }
		-- the run's talents: M.loadout.talents = { { key, rank, tree, name, icon } }
		for i = 1, table.getn(M.loadout.talents or {}) do
			local t = M.loadout.talents[i]
			table.insert(out.talents, { sourceKey = t.key, rank = t.rank, treeKey = t.tree, specKey = "spec1", effectSourceKeys = {}, modifiedSourceKeys = {} })
			out.sources[t.key] = { sourceKey = t.key, name = t.name or t.key, talentKey = t.key,
				icon = t.icon and { status = "ready", path = t.icon } or { status = "missing" } }
		end
		for i = 1, table.getn(M.loadout.abilities or {}) do
			local a = M.loadout.abilities[i]
			table.insert(out.abilities, { sourceKey = a.key, learned = a.learned ~= false, selected = true, passive = a.passive and true or false,
				rank = a.rank, slotId = a.slotId, effectSourceKeys = {} })
			out.sources[a.key] = { sourceKey = a.key, name = a.key, icon = a.icon and { status = "ready", path = a.icon } or { status = "missing" } }
		end
		return out, nil
	end
	function AZS_CreateMeterCheckpoint(runId)
		if runId ~= (M.meterRun or "run1") then return nil, { code = "RUN_MISMATCH" } end
		M.checkpoints = M.checkpoints or {}
		M.cpSerial = (M.cpSerial or 0) + 1
		local id = "cp" .. M.cpSerial
		local base = {}
		for which, list in pairs(M.meter or {}) do
			for i = 1, table.getn(list) do base[which .. ":" .. (list[i].key or list[i].name)] = list[i].amount end
		end
		M.checkpoints[id] = base
		return { checkpointId = id, runId = runId }
	end
	function AZS_ReleaseMeterCheckpoint(id)
		if M.checkpoints then M.checkpoints[id] = nil end
		M.released = (M.released or 0) + 1
		return true
	end
	function AZS_SetMeterPortrait(tex, runId, key)
		if type(tex) ~= "table" or tex.__kind ~= "Texture" then return nil, { code = "INVALID_ARGUMENT" } end
		tex.__tex = "Portrait:" .. tostring(key)
		return true
	end
	for name, fn in pairs(M.waAPI or {}) do setglobal(name, fn) end
	-- stored level-ups (the game's Store Level-Ups): M.storedLevels waiting, M.storing the setting
	function AZS_GetStoredLevels() return M.storedLevels or 0 end
	function AZS_IsStoringLevels() return M.storing and true or false end
	function AZS_OpenStoredLevels() M.openedLevels = (M.openedLevels or 0) + 1 end
	-- the run's end (M.runEnd as the game's AZS_END line) and the revive line (M.revive)
	function AZS_GetRunSummary()
		if type(M.runEnd) ~= "table" or not M.runEnd.result then return nil end
		return M.runEnd
	end
	function AZS_GetRevive() return M.revive or {} end
	function AZS_SetHudShown(part, shown) M.hud[part] = shown and true or false; M.hudWrites = (M.hudWrites or 0) + 1 end
	function AZS_IsHudShown(part) return M.hud[part] ~= false end
	function AZS_SetOnTopOfScreens(frame, on)
		if type(frame) == "table" and not frame.__name then error("frame needs a name") end
		M.onTop = M.onTop or {}
		M.onTop[type(frame) == "table" and frame.__name or frame] = on
	end
end
local function RemoveAPI()
	AZS_GetPhase, AZS_GetRunTime, AZS_GetRunLength, AZS_GetBosses, AZS_GetUpcomingBosses = nil, nil, nil, nil, nil
	AZS_SetHudShown, AZS_IsHudShown, AZS_SetOnTopOfScreens = nil, nil, nil
	AZS_GetMeterContext, AZS_GetMeterSnapshot, AZS_CreateMeterCheckpoint, AZS_ReleaseMeterCheckpoint, AZS_SetMeterPortrait = nil, nil, nil, nil, nil
	AZS_GetMeterLoadout = nil
	AZS_GetStoredLevels, AZS_IsStoringLevels, AZS_OpenStoredLevels, AZS_GetRunSummary, AZS_GetRevive = nil, nil, nil, nil, nil
	AZS_STATS = nil
	for name in pairs(M.waAPI or {}) do setglobal(name, nil) end
	AZS_ZONE, AZS_RUN, AZS_SCHEDULE, AZS_ZONE_UPDATED = nil, nil, nil, nil
end
M.InstallAPI, M.RemoveAPI = InstallAPI, RemoveAPI

------------------------------------------------------------------ driving
function M.Fire(ev, a1)
	for i = 1, table.getn(eventFrames) do
		local f = eventFrames[i]
		if f.__events[ev] and f.__scripts.OnEvent then
			this, event, arg1 = f, ev, a1
			f.__scripts.OnEvent()
		end
	end
end

function M.Frame(dt)
	M.now = M.now + dt
	for i = 1, table.getn(updaters) do
		local f = updaters[i]
		if f.__scripts.OnUpdate then
			this, arg1 = f, dt
			f.__scripts.OnUpdate()
		end
	end
end

M.files = { "Core.lua", "Locale.lua", "Locale_zh.lua", "Locale_ru.lua", "Locale_ja.lua", "Locale_ko.lua", "Locale_pl.lua", "Locale_tr.lua", "Timer.lua", "Numbers.lua", "Bosses.lua", "Skulls.lua", "Units.lua", "Party.lua", "Downed.lua", "Bar.lua", "Tally.lua", "LevelUps.lua", "Minimap.lua", "MinimapButton.lua",
	"TinyPlates.lua", "TinyPlatesOptions.lua", "Chests.lua", "Meter.lua", "Luck.lua", "Summary.lua", "Character.lua", "Talents.lua", "Chat.lua" }
function M.Load(dir)
	for i = 1, table.getn(M.files) do
		local chunk, err = loadfile(dir .. "/" .. M.files[i])
		if not chunk then error(err) end
		chunk()
	end
	M.Fire("ADDON_LOADED", "CreedUI")
	M.Fire("VARIABLES_LOADED")
	M.Fire("PLAYER_ENTERING_WORLD")
end

-- /reload: a new Lua VM keeps the saved variables and the game's settings
function M.Reload(dir, fireLogout)
	if fireLogout then M.Fire("PLAYER_LOGOUT") end
	local saved = CreedUIDB
	all, updaters, eventFrames = {}, {}, {}
	for _, name in ipairs({ "CreedUITimerFrame", "CreedUIOptions", "CreedUITimerOptions", "CreedUINumbersOptions",
		"CreedUIBosses", "CreedUISkulls", "CreedUISkullsDriver", "CreedUIDowned", "CreedUIDownedBanner", "CreedUIDownedDriver", "CreedUILevelUps", "CreedUILevelUpsDriver", "CreedUISummary", "CreedUISummaryDriver", "CreedUITalents", "CreedUIPlayer", "CreedUITarget", "CreedUIBar", "CreedUINumbersLayer", "CreedUIHidden",
		"CreedUIParty", "CreedUITally", "CreedUIMinimap", "CreedUIMenuGuard", "GameMenuFrame", "Minimap", "CreedUIMeter",
		"CreedUILuck", "CreedUIMeterToggle", "CreedUIChatGlass", "CreedUIChatDown", "ChatFrame1", "ChatFrame2", "CreedUIChests", "CreedUIMinimapClock", "CreedUIMeterSizer", "CreedUILuckSizer", "CreedUILuckToggle",
		"CreedUITinyPlatesDriver", "CreedUITinyPlatesOptions", "ChatFrameEditBox", "ChatFrameMenuButton" }) do
		setglobal(name, nil)
	end
	CreedUIDB = saved
	SlashCmdList = {}
	-- a new VM has fresh chat windows (no hooks of the last one's)
	DEFAULT_CHAT_FRAME = { AddMessage = function(self, msg)
		table.insert(M.chat, msg)
		if M.verbose then print("CHAT: " .. msg) end
	end }
	M.MakeStock()
	hideWatch = {}
	if M.MakeCharacter then
		M.MakeCharacter()
		CharacterFrame:Hide()
	end
	M.ctHandler, M.waHandler, M.waHandlers = nil, nil, {}
	M.Load(dir)
end

function M.Slash(msg)
	SlashCmdList["CREED"](msg)
end

function M.All() return all end

------------------------------------------------------------------ dump for rendering
local LAYERS = { BACKGROUND = 0, BORDER = 1, ARTWORK = 2, OVERLAY = 3, HIGHLIGHT = 4 }
local STRATA = { BACKGROUND = 0, LOW = 1, MEDIUM = 2, HIGH = 3, DIALOG = 4, FULLSCREEN = 5, FULLSCREEN_DIALOG = 6, TOOLTIP = 7 }

local function Visible(o)
	local f = o
	while f do
		if not f.__shown then return false end
		f = f.__parent
	end
	return true
end
local function FrameAlpha(f)
	local a = 1
	while f do
		a = a * (f.__alpha or 1)
		f = f.__parent
	end
	return a
end
M.FrameAlpha = FrameAlpha
M.Visible = Visible

local function fmt(v) return string.format("%.4f", v) end
local function list(t)
	if not t then return "-" end
	local out = {}
	for i = 1, table.getn(t) do out[i] = fmt(t[i]) end
	return table.concat(out, ",")
end

-- one line per drawn thing:  kind  l b r t  strata level layer rank id  ...
function M.Dump(path)
	local f = io.open(path, "w")
	for i = 1, table.getn(all) do
		local o = all[i]
		local kind = o.__kind
		if (kind == "Texture" or kind == "FontString") and Visible(o) then
			local owner = o.__parent
			local a = (o.__alpha or 1) * FrameAlpha(owner)
			if a > 0.003 then
				local l, b, r, t = M.Rect(o)
				local head = table.concat({ kind, fmt(l), fmt(b), fmt(r), fmt(t), STRATA[Strata(owner)] or 2,
					IMPL.GetFrameLevel(owner), LAYERS[o.__layer] or 2,
					kind == "Texture" and (o.__solid and 0 or texRank[o.__tex or ""] or 0) or 999, o.__id, fmt(a) }, "\t")
				if kind == "Texture" then
					local grad = "-"
					if o.__grad then grad = o.__grad[1] .. ":" .. list(o.__grad[2]) .. ":" .. list(o.__grad[3]) end
					f:write(head, "\t", o.__tex or "-", "\t", list(o.__solid), "\t", o.__blend or "BLEND", "\t",
						list(o.__vc), "\t", grad, "\t", list(o.__tc), "\n")
				else
					f:write(head, "\t", o.__font or "-", "\t", fmt(o.__size or 12), "\t", o.__flags or "-", "\t",
						list(o.__color or { 1, 1, 1, 1 }), "\t", o.__justify or "CENTER", "\t",
						o.__shadowOff and "1" or "0", "\t", (string.gsub(o.__text or "", "\n", "\\n")), "\n")
				end
			end
		elseif (kind == "Frame" or kind == "Button") and Visible(o) and o.__backdrop and o.__bdColor then
			local a = FrameAlpha(o)
			if a > 0.003 then
				local l, b, r, t = M.Rect(o)
				f:write(table.concat({ "Backdrop", fmt(l), fmt(b), fmt(r), fmt(t), STRATA[Strata(o)] or 2,
					IMPL.GetFrameLevel(o), -1, 0, o.__id, fmt(a) }, "\t"), "\t", list(o.__bdColor), "\t",
					list(o.__bdBorder or { 0, 0, 0, 0 }), "\n")
			end
		end
	end
	f:close()
end

------------------------------------------------------------------ CreedUI UI: units, actions, inventory, stock frames
M.unit = {
	player = { name = "CreedUI", hp = 1840, hpm = 2400, mp = 85, mpm = 100, power = 3, level = 20, exists = true, class = "Rogue" },
	target = { exists = false },
}
local function U(unit) return M.unit[unit] or {} end
function UnitExists(u) return U(u).exists and 1 or nil end
function UnitName(u) return U(u).name end
function UnitHealth(u) return U(u).hp or 0 end
function UnitHealthMax(u) return U(u).hpm or 0 end
function UnitMana(u) return U(u).mp or 0 end
function UnitManaMax(u) return U(u).mpm or 0 end
function UnitPowerType(u) return U(u).power or 0 end
function UnitLevel(u) return U(u).level or 1 end
function UnitIsDead(u) return U(u).dead and 1 or nil end
function UnitCanAttack(a, b) return U(b).hostile and 1 or nil end
function UnitClass(u) return U(u).class, string.upper(U(u).class or "") end
function UnitIsDeadOrGhost(u) return U(u).dead and 1 or nil end
function UnitIsConnected(u) return (U(u).exists and not U(u).offline) and 1 or nil end
function UnitIsUnit(a, b) return a == b and 1 or nil end
function GetNumPartyMembers()
	local n = 0
	for i = 1, 4 do if U("party" .. i).exists then n = n + 1 end end
	return n
end
function TargetUnit(u) M.targeted = u end
function UnitXP(u) return 120 end
function UnitXPMax(u) return 400 end
function SetPortraitTexture(tex, unit)
	if type(tex) ~= "table" or tex.__kind ~= "Texture" then M.Problem("SetPortraitTexture on a non-texture") end
	tex.__tex = "Portrait:" .. unit
end
RAID_CLASS_COLORS = { ROGUE = { r = 1, g = 0.96, b = 0.41 }, MAGE = { r = 0.41, g = 0.8, b = 0.94 }, PRIEST = { r = 1, g = 1, b = 1 },
	WARRIOR = { r = 0.78, g = 0.61, b = 0.43 }, HUNTER = { r = 0.67, g = 0.83, b = 0.45 }, WARLOCK = { r = 0.58, g = 0.51, b = 0.79 },
	DRUID = { r = 1, g = 0.49, b = 0.04 }, SHAMAN = { r = 0, g = 0.44, b = 0.87 }, PALADIN = { r = 0.96, g = 0.55, b = 0.73 } }

M.actions = {
	[1] = { tex = "Interface\\Icons\\Spell_Shadow_RitualOfSacrifice", start = 0, dur = 0 },
	[2] = { tex = "Interface\\Icons\\Ability_Warrior_PunishingBlow", start = 0, dur = 0 },
	[3] = { tex = "Interface\\Icons\\Ability_BackStab", start = 0, dur = 0 },
	[4] = { tex = "Interface\\Icons\\Ability_Warrior_Challange", start = 0, dur = 0 },
	[12] = { tex = "Interface\\Icons\\Ability_Ambush", start = 0, dur = 0 },
}
function HasAction(slot) return M.actions[slot] and 1 or nil end
function GetActionTexture(slot) return M.actions[slot] and M.actions[slot].tex or nil end
function GetActionCooldown(slot)
	local a = M.actions[slot]
	if not a then return 0, 0, 1 end
	return a.start, a.dur, 1
end
local SLOTS = { NeckSlot = 2, Finger0Slot = 11, Finger1Slot = 12, Trinket0Slot = 13, Trinket1Slot = 14, HeadSlot = 1,
	ShoulderSlot = 3, ChestSlot = 5, WaistSlot = 6, LegsSlot = 7, FeetSlot = 8, WristSlot = 9, HandsSlot = 10, MainHandSlot = 16,
	SecondaryHandSlot = 17 }
function GetInventorySlotInfo(name)
	local id = SLOTS[name]
	if not id then error("bad slot name " .. tostring(name)) end
	return id, "Interface\\Paperdoll\\UI-PaperDoll-Slot-" .. name
end
M.gear = {
	[2] = { tex = "Interface\\Icons\\INV_Jewelry_Necklace_07", q = 4 },
	[11] = { tex = "Interface\\Icons\\INV_Jewelry_Ring_03", q = 3 },
}
function GetInventoryItemTexture(unit, slot) return M.gear[slot] and M.gear[slot].tex or nil end
function GetInventoryItemQuality(unit, slot) return M.gear[slot] and M.gear[slot].q or nil end
function GetInventoryItemLink(unit, slot) return M.gear[slot] and M.gear[slot].link or nil end
function GetInventoryItemCooldown(unit, slot) return 0, 0, 1 end
M.loaded = {}
function IsAddOnLoaded(name) return M.loaded[name] and 1 or nil end
M.cvars = { CombatDamage = "1" }
function GetCVar(k) return M.cvars[k] end
function SetCVar(k, v) M.cvars[k] = v end

-- the game's own frames CreedUI UI tucks away
function M.MakeStock()
	for _, name in ipairs({ "PlayerFrame", "TargetFrame", "ComboFrame", "MainMenuBar", "PartyMemberFrame1",
		"PartyMemberFrame2", "PartyMemberFrame3", "PartyMemberFrame4", "PartyMemberBackground" }) do
		local f = CreateFrame("Frame", name, UIParent)
		f:SetWidth(200)
		f:SetHeight(60)
	end
	local menu = CreateFrame("Frame", "GameMenuFrame", UIParent)
	menu:SetWidth(200)
	menu:SetHeight(300)
	menu:Hide()
	M.MakeMinimap()
	M.MakeChat()
end
M.MakeStock()

-- A realistic, minimal nameplate fixture: the same border/name/statusbar shape the client exposes.
M.nameplateSerial = 0
function M.MakeNameplate(name)
	M.nameplateSerial = M.nameplateSerial + 1
	local plate = CreateFrame("Frame", "MockNameplate" .. M.nameplateSerial, WorldFrame)
	plate:SetWidth(120)
	plate:SetHeight(30)
	plate:SetPoint("CENTER", WorldFrame, "CENTER", 0, 80 - M.nameplateSerial * 42)
	local border = plate:CreateTexture(nil, "BACKGROUND")
	border:SetTexture("Interface\\Tooltips\\Nameplate-Border")
	border:SetAllPoints(plate)
	local label = plate:CreateFontString(nil, "OVERLAY")
	label:SetFont("Fonts\\FRIZQT__.TTF", 12)
	label:SetText(name)
	label:SetPoint("BOTTOM", plate, "TOP", 0, 2)
	local bar = CreateFrame("StatusBar", nil, plate)
	bar:SetWidth(100)
	bar:SetHeight(10)
	bar:SetPoint("CENTER", plate, "CENTER", 0, 0)
	bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	bar:SetMinMaxValues(0, 100)
	bar:SetValue(75)
	bar:SetStatusBarColor(0.8, 0.1, 0.1, 1)
	plate:Show()
	return plate, bar, label
end

------------------------------------------------------------------ the combat text API (from the Smooth Numbers harness)
local world = { events = {}, nEvents = 0, anchors = {}, nAnchor = 0, stream = 1, enemies = {} }
M.world = world
local YARD = 9
local function ScreenOf(x, y) return 640 + x * YARD, 330 + y * YARD end
function AZS_GetCombatTextCapabilities()
	return { apiVersion = 1, impactAnchors = true, followAnchors = true, frameProjection = true, frameHandler = true,
		maxEventsPerRead = 256, maxAnchorsPerRead = 256, eventRetentionSeconds = 5, anchorRetentionSeconds = 5 }
end
function AZS_GetCombatTextEvents(cursor, limit)
	if cursor == nil then
		return { apiVersion = 1, streamId = "s" .. world.stream, cursor = world.stream .. ":" .. world.nEvents, events = {}, hasMore = false }
	end
	local _, _, st, index = string.find(cursor, "^(%d+):(%d+)$")
	if tonumber(st) ~= world.stream then return nil, { code = "STREAM_CHANGED", message = "new stream" } end
	index = tonumber(index)
	local out, n = {}, 0
	limit = limit or 256
	while index < world.nEvents and n < limit do
		index = index + 1
		n = n + 1
		out[n] = world.events[index]
	end
	return { apiVersion = 1, cursor = world.stream .. ":" .. index, events = out, hasMore = index < world.nEvents }
end
function AZS_ProjectCombatTextAnchors(ids, mode)
	if type(ids) ~= "table" or table.getn(ids) > 256 then return nil, { code = "INVALID_ARGUMENT" } end
	M.projected = (M.projected or 0) + table.getn(ids)
	local entries = {}
	for i = 1, table.getn(ids) do
		local a = world.anchors[ids[i]]
		if type(ids[i]) ~= "string" then M.Problem("projected a non-string anchor id") end
		if not a then
			entries[i] = { anchorId = ids[i], state = "unknownAnchor" }
		elseif M.now - a.born > 5 then
			entries[i] = { anchorId = ids[i], state = "expired" }
		else
			local e = a.enemy
			local sx, sy = ScreenOf(e.x, e.y)
			entries[i] = { anchorId = ids[i], state = "onScreen", targetState = e.alive and "alive" or "dead", x = sx, y = sy }
		end
	end
	return { apiVersion = 1, frameCurrent = true, entries = entries }
end
function AZS_RegisterCombatTextFrameHandler(fn) M.ctHandler = fn return true end
function AZS_UnregisterCombatTextFrameHandler(fn) if M.ctHandler == fn then M.ctHandler = nil end return true end

local serial = 0
function M.Enemy(name, x, y)
	serial = serial + 1
	local e = { id = "t" .. serial, name = name, x = x, y = y, alive = true }
	table.insert(world.enemies, e)
	return e
end
M.SKILLS = {
	corruption = { spellId = 172, abilityName = "Corruption", icon = "Interface\\Icons\\Spell_Shadow_AbominationExplosion", schoolMask = 32, damageType = "spell" },
	strike = { spellId = 1752, abilityName = "Sinister Strike", icon = "Interface\\Icons\\Spell_Shadow_RitualOfSacrifice", schoolMask = 1, damageType = "melee" },
	flurry = { spellId = 13877, abilityName = "Blade Flurry", icon = "Interface\\Icons\\Ability_Warrior_PunishingBlow", schoolMask = 1, damageType = "melee" },
}
function M.Hit(e, amount, skill, periodic, crit)
	world.nAnchor = world.nAnchor + 1
	local anchorId = "a" .. world.nAnchor
	world.anchors[anchorId] = { enemy = e, born = M.now }
	world.nEvents = world.nEvents + 1
	local sk = M.SKILLS[skill]
	world.events[world.nEvents] = { eventId = "e" .. world.nEvents, presentedAt = M.now, targetId = e.id, targetName = e.name,
		sourceKind = "player", kind = "damage", amount = amount, critical = crit and true or false, periodic = periodic and true or false,
		anchorId = anchorId, anchorStatus = "ready", damageType = sk.damageType, schoolMask = sk.schoolMask,
		spellId = sk.spellId, abilityName = sk.abilityName, icon = sk.icon }
end

-- the game calls the combat text and world anchor handlers every frame, after the camera moves
local frameBase = M.Frame
function M.Frame(dt)
	frameBase(dt)
	if M.ctHandler then M.ctHandler() end
	-- over a copy, as the game: a handler may take itself off
	local list = {}
	for i = 1, table.getn(M.waHandlers) do list[i] = M.waHandlers[i] end
	for i = 1, table.getn(list) do list[i]() end
end

-- the game's sounds by kit name
M.sounds = {}
function PlaySound(name)
	if type(name) ~= "string" then Problem("PlaySound needs a kit name") end
	table.insert(M.sounds, name)
end

------------------------------------------------------------------ the world anchors API (the game's 0.139.2)
-- Checked as the game's client checks it (its own error messages): the catalog holds a handle on
-- each boss of M.bosses (finalBoss for the last) and guardian of M.guardians. Boss i stands at
-- world (i * 10 - 15, 6) unless M.waSpots[name] says else; M.waNear[name] scales its yards on
-- screen (nearer: more), M.waOff[name] puts it off the screen, M.waNoHead[name] has no overhead.
M.waSpots, M.waNear, M.waOff, M.waNoHead = {}, {}, {}, {}
M.waCalls = { list = 0, project = 0, requests = 0 }
local WA_KINDS = { enemy = true, elite = true, guardian = true, boss = true, finalBoss = true, cache = true,
	guardianLair = true, downedPartyMember = true }
local function WAErr(code, message) return nil, { code = code, message = message } end
local function WABad(message)
	Problem("world anchors: " .. message)
	return WAErr("INVALID_ARGUMENT", message)
end
local function WACatalog()
	local out = {}
	for i = 1, table.getn(M.bosses or {}) do
		local b = M.bosses[i]
		table.insert(out, { anchorId = "boss:" .. b.name, kind = b.final and "finalBoss" or "boss", name = b.name,
			entityState = (b.hp or 1) > 0 and "alive" or "dead", attachments = { "position", "overhead" },
			positionAvailable = true, x = i * 10 - 15, y = 6, z = 0, index = i })
	end
	for i = 1, table.getn(M.downed or {}) do
		local d = M.downed[i]
		if d.anchorId then
			table.insert(out, { anchorId = d.anchorId, kind = "downedPartyMember", name = d.name, entityState = "downed",
				attachments = { "position" }, positionAvailable = true, x = d.wx or 0, y = d.wy or 0, z = 0 })
		end
	end
	for i = 1, table.getn(M.guardians or {}) do
		local g = M.guardians[i]
		table.insert(out, { anchorId = "guardian:" .. g.id, kind = "guardian", name = g.name, entityState = g.awake == false and "asleep" or "awake",
			attachments = { "position", "overhead" }, positionAvailable = true, x = -20, y = -4, z = 0 })
	end
	return out
end
local function Finite(v) return type(v) == "number" and not BadNumber(v) end
M.waAPI = {}
M.waAPI.AZS_GetWorldAnchorCapabilities = function(...)
	if arg.n ~= 0 then return WABad("AZS_GetWorldAnchorCapabilities takes no arguments") end
	return { apiVersion = 1, kinds = { "enemy", "elite", "guardian", "boss", "finalBoss", "cache", "guardianLair", "downedPartyMember" },
		attachments = { "position", "overhead" }, frameProjection = true, frameHandler = true, playerDistanceMetrics = true,
		occlusion = false, worldOffsets = true, maxEntriesPerCall = 256, maxProjectionsPerCall = 256 }, nil
end
M.waAPI.AZS_GetWorldAnchors = function(...)
	if arg.n > 3 then return WABad("AZS_GetWorldAnchors takes a query, a cursor and a limit") end
	M.waCalls.list = M.waCalls.list + 1
	if M.waThrows then error("boom") end
	if M.waNotReady then return WAErr("NOT_READY", "the catalog starts with the first frame") end
	local q, cursor, limit = arg[1], arg[2], arg[3]
	if q ~= nil and type(q) ~= "table" then return WABad("query must be nil or a table") end
	local want
	if q then
		for k in pairs(q) do
			if k ~= "kinds" and k ~= "states" then return WABad("query takes kinds and states") end
		end
		if q.kinds ~= nil then
			if type(q.kinds) ~= "table" then return WABad("kinds must be an array") end
			want = {}
			for i = 1, table.getn(q.kinds) do
				if not WA_KINDS[q.kinds[i]] then return WABad("unknown kind " .. tostring(q.kinds[i])) end
				want[q.kinds[i]] = true
			end
		end
	end
	if cursor ~= nil and type(cursor) ~= "string" then return WABad("cursor must be nil or a string") end
	if limit ~= nil and (type(limit) ~= "number" or limit < 1 or limit > 256 or math.floor(limit) ~= limit) then
		return WABad("limit must be a whole number from 1 to 256")
	end
	local all = {}
	local catalog = WACatalog()
	for i = 1, table.getn(catalog) do
		if not want or want[catalog[i].kind] then table.insert(all, catalog[i]) end
	end
	local from = 1
	if cursor then
		local _, _, n = string.find(cursor, "^c(%d+)$")
		if not n then return WAErr("INVALID_ARGUMENT", "this cursor belongs to another query") end
		from = tonumber(n)
	end
	limit = limit or 64
	local entries = {}
	for i = from, math.min(table.getn(all), from + limit - 1) do table.insert(entries, all[i]) end
	local last = from + table.getn(entries) - 1
	local more = last < table.getn(all)
	return { apiVersion = 1, catalogId = "cat1", entries = entries, hasMore = more, nextCursor = more and ("c" .. (last + 1)) or nil,
		overflowed = false }, nil
end
M.waAPI.AZS_ProjectWorldAnchors = function(...)
	if arg.n ~= 1 then return WABad("AZS_ProjectWorldAnchors takes the requests") end
	local reqs = arg[1]
	if type(reqs) ~= "table" then return WABad("requests must be an array") end
	local n = table.getn(reqs)
	if n > 256 then return WABad("at most 256 requests a call") end
	M.waCalls.project = M.waCalls.project + 1
	M.waCalls.requests = M.waCalls.requests + n
	if M.waThrows then error("boom") end
	local byId = {}
	local catalog = WACatalog()
	for i = 1, table.getn(catalog) do byId[catalog[i].anchorId] = catalog[i] end
	local entries = {}
	for i = 1, n do
		local r = reqs[i]
		if type(r) ~= "table" then return WABad("every request must be a table") end
		if type(r.anchorId) ~= "string" then return WABad("every request needs an anchorId") end
		if r.attachment ~= nil and r.attachment ~= "position" and r.attachment ~= "overhead" then
			return WABad("attachment must be \"position\" or \"overhead\"")
		end
		if r.offset ~= nil and (type(r.offset) ~= "table" or not Finite(r.offset.x) or not Finite(r.offset.y) or not Finite(r.offset.z)) then
			return WABad("offset must be a table of finite x, y and z yards")
		end
		local a = byId[r.anchorId]
		M.waLast = M.waLast or {}
		M.waLast[r.anchorId] = r.attachment
		if not a then
			entries[i] = { anchorId = r.anchorId, state = "unknownAnchor" }
		elseif r.attachment == "overhead" and M.waNoHead[a.name] then
			entries[i] = { anchorId = r.anchorId, state = "unsupportedAttachment" }
		else
			local spot = M.waSpots[a.name] or a
			local upy = 9 * (M.waNear[a.name] or 1)
			local lift = (r.attachment == "overhead" and 3 or 0) + (r.offset and r.offset.z or 0)
			local sx, sy = ScreenOf(spot.x, spot.y)
			local off = M.waOff[a.name] or sx < 0 or sx > SW or sy < 0 or sy > SH
			if M.waBehind and M.waBehind[a.name] then off = "behindCamera" end
			local e = { anchorId = r.anchorId, state = (off == "behindCamera" and off) or (off and "offscreen") or "onScreen", targetState = a.entityState,
				x = sx, y = sy + lift * upy, cameraDepth = 20 / (M.waNear[a.name] or 1), uiUnitsPerYard = upy,
				playerDistance = 20 / (M.waNear[a.name] or 1) }
			entries[i] = e
		end
	end
	return { apiVersion = 1, cameraSampleId = M.now, frameCurrent = true, entries = entries }, nil
end
-- as the game: a list of handlers, each once; M.waHandler is the first, for the tests
M.waHandlers = {}
M.waAPI.AZS_RegisterWorldAnchorFrameHandler = function(fn)
	if type(fn) ~= "function" then return WABad("the handler must be a function") end
	M.waRegistered = (M.waRegistered or 0) + 1
	for i = 1, table.getn(M.waHandlers) do
		if M.waHandlers[i] == fn then return true, nil end
	end
	table.insert(M.waHandlers, fn)
	M.waHandler = M.waHandlers[1]
	return true, nil
end
M.waAPI.AZS_UnregisterWorldAnchorFrameHandler = function(fn)
	for i = table.getn(M.waHandlers), 1, -1 do
		if M.waHandlers[i] == fn then table.remove(M.waHandlers, i) end
	end
	M.waHandler = M.waHandlers[1]
	return true, nil
end
M.waAPI.AZS_GetDownedPartyMembers = function(...)
	if arg.n ~= 0 then return WABad("AZS_GetDownedPartyMembers takes no arguments") end
	return M.downed or {}, nil
end
for name, fn in pairs(M.waAPI) do setglobal(name, fn) end

-- Azeroth Survivors' character window (shut, as at login)
dofile(SCRATCH .. "/cui/mock_char.lua")
M.MakeCharacter()
CharacterFrame:Hide()
