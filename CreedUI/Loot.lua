-- Creed UI: the loot pop-up.
-- When the game gives you loot, a gold-railed pop-up rises in over the skill bar in place of the
-- game's own: the item's icon in a metal slot, its name in its rarity's color, and
-- under it whether it's new to your collection (in green) or one you already had. Marks you earn
-- come the same way, on an Argent Dawn token. Up to three stack, the newest lowest; each stays a
-- few seconds and melts away. They hide behind the level-up cards. Turned off, the game's comes back.
-- Both are read from the game's own lines in the chat ("You receive loot: [Name] New in your
-- collection!", "You earn 5 marks (120 in all)."), in whichever of its languages it speaks; the line
-- doesn't say what the item looks like, so its icon is picked by a word in its name.

local C = CreedUI
local DEFAULTS = { enabled = true, scale = 1 }
local K = { w = 270, h = 52, gap = 6, max = 3, show = 4.5, fadeIn = 0.22, fadeOut = 0.6, icon = 36 }
local QUALITY = {
	[0] = { 0.62, 0.62, 0.62 }, [1] = { 0.92, 0.92, 0.92 }, [2] = { 0.12, 1.00, 0.00 },
	[3] = { 0.00, 0.44, 0.87 }, [4] = { 0.64, 0.21, 0.93 }, [5] = { 1.00, 0.50, 0.00 },
}

-- the game's two lines, in all its languages (from its own words)
local LOOT_LINES = { "Du erhältst Beute:", "Ganimet aldın:", "Otrzymujesz łup:", "Primești pradă:", "Recibes botín:", "Você recebe saque:", "Vous recevez du butin :", "You receive loot:", "Získáváš kořist:", "Ви отримуєте здобич:", "Вы получаете добычу:", "你获得了战利品：", "戦利品を入手：", "전리품을 받았습니다:" }
local MARK_LINES = { "Câștigi {n} însemne ({total} în total).", "Du erhältst {n} Marken (insgesamt {total}).", "Ganas {n} marcas ({total} en total).", "Você ganha {n} marcas ({total} no total).", "Vous gagnez {n} marques ({total} au total).", "You earn {n} marks ({total} in all).", "Zdobywasz znaki: {n} (łącznie {total}).", "Získáváš známky: {n} (celkem {total}).", "{n} nişan kazandın (toplam {total}).", "{n}マークを獲得（合計{total}）。", "Ви отримуєте знаки: {n} (усього {total}).", "Вы получаете знаки: {n} (всего {total}).", "你获得了{n}枚印记（共{total}枚）。", "징표 {n}개를 얻었습니다 (총 {total}개)." }
local MARK_ICON = "Interface\\Icons\\INV_Misc_Token_ArgentDawn"
-- what the line may say after the item: new to your collection, or had already
local NEW_LINES = { "Koleksiyonunda yeni!", "Neu in deiner Sammlung!", "New in your collection!", "Nou în colecția ta!", "Nouveau dans votre collection !", "Novinka ve tvé sbírce!", "Novo na sua coleção!", "Nowość w twojej kolekcji!", "¡Nuevo en tu colección!", "Нове у вашій колекції!", "Новое в вашей коллекции!", "コレクションに新しく追加！", "收藏新增！", "새로운 수집품!" }
local HAD_LINES = { "Already collected", "Bereits gesammelt", "Deja colecționat", "Déjà obtenu", "Już w kolekcji", "Já na coleção", "Už ve sbírce", "Ya en tu colección", "Zaten toplandı", "Уже в коллекции", "Уже є в колекції", "入手済み", "已收藏", "이미 수집함" }
-- The line names the item but not its look: an icon is picked by a word in its name (its slot or
-- its weapon), the first that matches winning. A real link's own icon always comes first.
local I = "Interface\\Icons\\"
local LOOKS = {
	{ { "crossbow" }, "INV_Weapon_Crossbow_01" }, { { "bow" }, "INV_Weapon_Bow_01" },
	{ { "gun", "rifle", "blunderbuss" }, "INV_Weapon_Rifle_01" }, { { "wand" }, "INV_Wand_01" },
	{ { "staff", "stave" }, "INV_Staff_01" }, { { "dagger", "dirk", "knife", "shiv", "kris" }, "INV_Weapon_ShortBlade_01" },
	{ { "sword", "blade", "saber", "scimitar", "claymore" }, "INV_Sword_04" }, { { "axe", "cleaver" }, "INV_Axe_01" },
	{ { "mace", "hammer", "maul", "club", "scepter" }, "INV_Mace_01" }, { { "polearm", "spear", "halberd", "glaive" }, "INV_Spear_01" },
	{ { "shield", "buckler", "aegis", "bulwark" }, "INV_Shield_01" }, { { "tome", "book", "orb", "lamp" }, "INV_Misc_Book_01" },
	{ { "boots", "sandals", "greaves", "treads", "footwraps", "slippers", "shoes", "sabatons" }, "INV_Boots_01" },
	{ { "helm", "hood", "cap", "crown", "circlet", "mask", "headband", "cowl", "hat", "headpiece" }, "INV_Helmet_01" },
	{ { "gloves", "gauntlets", "handwraps", "grips", "handguards", "mitts" }, "INV_Gauntlets_01" },
	{ { "belt", "girdle", "sash", "cord", "waistband", "waistguard" }, "INV_Belt_01" },
	{ { "leggings", "pants", "legguards", "legplates", "kilt", "trousers", "breeches", "legwraps" }, "INV_Pants_01" },
	{ { "robe", "gown", "vestments" }, "INV_Chest_Cloth_01" },
	{ { "vest", "tunic", "chestpiece", "breastplate", "jerkin", "harness", "hauberk", "chestguard", "shirt", "armor" }, "INV_Chest_Leather_01" },
	{ { "shoulders", "pauldrons", "mantle", "spaulders", "shoulderpads", "amice", "epaulets" }, "INV_Shoulder_01" },
	{ { "bracers", "wristguards", "bindings", "cuffs", "bracelets", "wristbands", "armguards" }, "INV_Bracer_01" },
	{ { "cloak", "cape", "drape", "shroud" }, "INV_Misc_Cape_01" },
	{ { "ring", "band", "signet", "loop", "seal" }, "INV_Jewelry_Ring_01" },
	{ { "necklace", "amulet", "pendant", "choker", "collar", "medallion", "chain" }, "INV_Jewelry_Necklace_01" },
	{ { "trinket", "idol", "charm", "talisman", "relic", "libram", "totem", "figurine", "insignia" }, "INV_Jewelry_Talisman_01" },
}

-- a drop's rarity by its name: a weapon by its whole name, a piece by its set's name in it (the
-- longest found), from the game's own words in LootSets.lua; as WoW's colors: the game's Common is
-- white, Uncommon green, Rare blue, Epic purple, Legendary orange, and its Tier 0.5 purple (as in game)
local TO_QUALITY = { [0] = 1, [1] = 2, [2] = 3, [3] = 4, [4] = 5, [7] = 4 }

local function RarityOfName(name)
	if type(name) ~= "string" then return nil end
	local r = C.lootWeapons and C.lootWeapons[name]
	if r then return TO_QUALITY[r] end
	if C.lootSets then
		local best = 0
		for set, rarity in pairs(C.lootSets) do
			local n = string.len(set)
			if n > best and string.find(name, set, 1, true) then
				best, r = n, rarity
			end
		end
	end
	-- the top sets (Ahn'Qiraj's, Naxxramas's) are epic in game: only their weapons are legendary
	if r == 4 then return 4 end
	return r and TO_QUALITY[r]
end

local function LookOf(name)
	local words = " " .. string.gsub(string.lower(name or ""), "[^%a]+", " ") .. " "
	for i = 1, table.getn(LOOKS) do
		local list = LOOKS[i][1]
		for k = 1, table.getn(list) do
			-- the word whole, or with an s (Boots, Bracer and Bracers alike)
			if string.find(words, " " .. list[k] .. "s? ") then return I .. LOOKS[i][2] end
		end
	end
	return I .. "INV_Misc_Bag_10"
end

local db
local root
local S = { live = {}, pool = {}, broken = false, patterns = nil, heard = {}, takeClock = 0 }
local Toast -- below: a new pop-up for a drop or for marks

------------------------------------------------------------------------ what came
-- an item from a loot line: its link, id, name, count; nil for a line without one
local function ParseLoot(msg)
	if type(msg) ~= "string" then return nil end
	local _, _, link, id, name = string.find(msg, "(|Hitem:(%d+)[^|]*|h%[([^%]]+)%]|h)")
	if not link then return nil end
	local _, _, count = string.find(msg, "|rx(%d+)")
	return { link = link, id = tonumber(id), name = name, count = tonumber(count) or 1 }
end

-- each marks line as a pattern: its two numbers caught, which comes first remembered
local function MarkPatterns()
	local out = {}
	for i = 1, table.getn(MARK_LINES) do
		local t = MARK_LINES[i]
		local nAt, totalAt = string.find(t, "{n}", 1, true), string.find(t, "{total}", 1, true)
		local pat = string.gsub(t, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
		pat = string.gsub(pat, "{n}", "([%%d,]+)")
		pat = string.gsub(pat, "{total}", "([%%d,]+)")
		table.insert(out, { pat = "^" .. pat, nFirst = (nAt or 0) < (totalAt or 0) })
	end
	return out
end

local function Number(s) return tonumber((string.gsub(s or "", ",", ""))) end

local function Plain(msg) return string.gsub(string.gsub(msg, "|c%x%x%x%x%x%x%x%x", ""), "|r", "") end

local function Rarity(hex)
	if not hex then return nil end
	for q, c in pairs(QUALITY) do
		local h = string.format("%02x%02x%02x", math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
		if string.lower(hex) == h then return q end
	end
	return nil
end

-- a line of the chat: a drop, or marks earned
local function Hear(msg)
	if type(msg) ~= "string" then return end
	local plain = Plain(msg)
	S.patterns = S.patterns or MarkPatterns()
	for i = 1, table.getn(S.patterns) do
		local p = S.patterns[i]
		local _, _, a, b = string.find(plain, p.pat)
		if a then
			local n, total = Number(a), Number(b)
			if not p.nFirst then n, total = total, n end
			Toast({ marks = n or 0, total = total })
			return
		end
	end
	for i = 1, table.getn(LOOT_LINES) do
		local start, stop = string.find(plain, LOOT_LINES[i], 1, true)
		if start == 1 then -- the game's own line, not someone saying it
			local item = ParseLoot(msg)
			if not item then
				-- a name with no link: the words after the line's start, its color its rarity
				local rest = string.gsub(string.gsub(string.sub(plain, stop + 1), "^%s+", ""), "%s+$", "")
				-- "New in your collection!" or "Already collected" after it: a tag, not its name
				local new
				for k = 1, table.getn(NEW_LINES) do
					local a = string.find(rest, NEW_LINES[k], 1, true)
					if a then rest, new = string.sub(rest, 1, a - 1), true end
				end
				for k = 1, table.getn(HAD_LINES) do
					local a = string.find(rest, HAD_LINES[k], 1, true)
					if a then rest, new = string.sub(rest, 1, a - 1), false end
				end
				rest = string.gsub(string.gsub(rest, "%s+$", ""), "[%.。]$", "")
				local _, _, name, count = string.find(rest, "^(.-)%s*x(%d+)$")
				name = name or rest
				local _, _, inside = string.find(name, "^%[(.-)%]$")
				item = { name = inside or name, count = tonumber(count) or 1, new = new }
				local _, _, hex = string.find(msg, "|c%x%x(%x%x%x%x%x%x)")
				item.quality = Rarity(hex)
			end
			if item.name == "" then return end
			if type(GetItemInfo) == "function" and item.id then
				local _, _, quality, _, _, _, _, _, icon = GetItemInfo(item.id)
				item.quality, item.icon = quality or item.quality, icon
			end
			if not item.icon then item.icon = LookOf(item.name) end
			if not item.quality then item.quality = RarityOfName(item.name) end
			if not item.quality then
				local _, _, hex = string.find(item.link or "", "^|c%x%x(%x%x%x%x%x%x)")
				item.quality = Rarity(hex)
			end
			Toast(item)
			return
		end
	end
end

-- every chat window's lines pass by here (a line shown in two windows counts once)
local function Listen()
	for i = 1, (tonumber(NUM_CHAT_WINDOWS) or 7) do
		local f = getglobal("ChatFrame" .. i)
		if type(f) == "table" and f.AddMessage and not f.creedLoot then
			local own = f.AddMessage
			f.creedLoot = own
			f.AddMessage = function(self, ...)
				local msg = arg[1]
				if db and db.enabled and not S.broken and type(msg) == "string" then
					local now = GetTime()
					if S.heard[msg] ~= now then
						S.heard[msg] = now
						pcall(Hear, msg)
					end
				end
				return own(self, unpack(arg))
			end
		end
	end
end

------------------------------------------------------------------------ the pop-ups
local function NewToast()
	local t = {}
	local f = CreateFrame("Frame", nil, root)
	t.frame = f
	f:SetWidth(K.w)
	f:SetHeight(K.h)
	t.deco = C.Panel(f, false)
	C.PanelTheme(t.deco, C.Pal())
	t.slot = C.Tex(f, "OVERLAY", C.ART .. "Slot")
	t.slot:SetWidth(K.icon + 6)
	t.slot:SetHeight(K.icon + 6)
	t.slot:SetPoint("LEFT", f, "LEFT", 7, 0)
	t.icon = f:CreateTexture(nil, "ARTWORK")
	t.icon:SetWidth(K.icon)
	t.icon:SetHeight(K.icon)
	t.icon:SetPoint("CENTER", t.slot, "CENTER", 0, 0)
	t.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	t.head = C.Text(f, C.FONT, 9, "OUTLINE", "LEFT", K.w - K.icon - 30)
	t.head:SetPoint("TOPLEFT", f, "TOPLEFT", K.icon + 20, -6)
	t.head:SetTextColor(0.98, 0.85, 0.52)
	t.name = C.Text(f, C.FONT, 13, "OUTLINE", "LEFT", K.w - K.icon - 30)
	t.name:SetPoint("LEFT", f, "LEFT", K.icon + 20, -1)
	t.sub = C.Text(f, C.FONT, 10, nil, "LEFT", K.w - K.icon - 30)
	t.sub:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", K.icon + 20, 6)
	return t
end

Toast = function(item)
	local t = table.remove(S.pool) or NewToast()
	t.born, t.y = GetTime(), nil
	if item.marks then
		t.icon:SetTexture(MARK_ICON)
		C.SetText(t.head, C.L("Marks"))
		C.SetText(t.name, C.F("+{1} marks", C.Commas(item.marks)))
		C.TextColor(t.name, 1, 0.86, 0.45)
		C.SetText(t.sub, item.total and C.F("{1} in all", C.Commas(item.total)) or "")
		C.TextColor(t.sub, 0.72, 0.70, 0.64)
	else
		t.icon:SetTexture(item.icon or LookOf(item.name))
		C.SetText(t.head, C.L("Loot"))
		local c = QUALITY[item.quality or 1] or QUALITY[1]
		C.SetText(t.name, item.name .. ((item.count or 1) > 1 and (" x" .. item.count) or ""))
		C.TextColor(t.name, c[1], c[2], c[3])
		if item.new then
			C.SetText(t.sub, C.L("New in your collection!"))
			C.TextColor(t.sub, 0.35, 1, 0.42)
		elseif item.new == false then
			C.SetText(t.sub, C.L("Already in your collection."))
			C.TextColor(t.sub, 0.65, 0.63, 0.58)
		else
			C.SetText(t.sub, "")
		end
	end
	table.insert(S.live, 1, t)
	-- more than three: the oldest goes at once
	while table.getn(S.live) > K.max do
		local old = table.remove(S.live)
		C.Vis(old.frame, false)
		table.insert(S.pool, old)
	end
end

local function Step(dt, now)
	local fade = 1 - C.cardsFade
	for i = table.getn(S.live), 1, -1 do
		local t = S.live[i]
		local age = now - t.born
		local a = C.Smooth(age / K.fadeIn) * (1 - C.Smooth((age - K.show) / K.fadeOut))
		if age > K.show + K.fadeOut then
			table.remove(S.live, i)
			C.Vis(t.frame, false)
			table.insert(S.pool, t)
		else
			-- each glides to its place in the stack, the newest lowest; a new one rises in from below
			local want = (i - 1) * (K.h + K.gap)
			t.y = t.y and (t.y + (want - t.y) * math.min(1, dt * 12)) or (want - 14)
			C.Place(t.frame, "BOTTOM", root, "BOTTOM", 0, math.floor(t.y + 0.5))
			C.Alpha(t.frame, a * fade)
			C.Vis(t.frame, a * fade > 0.01)
		end
	end
	S.takeClock = S.takeClock - dt
	if S.takeClock <= 0 then
		S.takeClock = 2
		C.TakeHud("loot") -- the game's own pop-up stays away while ours is on
	end
end

local function Apply()
	if db.enabled then
		C.TakeHud("loot")
	else
		C.ReleaseHud("loot")
		for i = table.getn(S.live), 1, -1 do
			local t = table.remove(S.live, i)
			C.Vis(t.frame, false)
			table.insert(S.pool, t)
		end
	end
end

C.OnInit(function()
	db = C.DB("loot", DEFAULTS)
	root = CreateFrame("Frame", "CreedUILoot", UIParent)
	root:SetWidth(K.w)
	root:SetHeight(K.max * (K.h + K.gap))
	root:SetFrameStrata("HIGH")
	root:SetScale(db.scale)
	C.Movable(root, "loot", "Loot", function(f)
		f:ClearAllPoints()
		f:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 160) -- over the skill bar and its Level Up! button
	end)
	Listen()
	local driver = CreateFrame("Frame", "CreedUILootDriver")
	driver:SetScript("OnUpdate", function()
		if S.broken or not db.enabled then return end
		local dt = arg1 or 0
		if dt > 0.1 then dt = 0.1 end
		local ok, err = pcall(Step, dt, GetTime())
		if not ok then
			S.broken = true
			db.enabled = false
			Apply()
			db.enabled = true
			C.Print(C.L("the loot pop-up stopped after an error, so the game's own is back: ") .. tostring(err))
		end
	end)
	Apply()
end)

C.OnWorld(function()
	if db then
		Listen() -- a chat window made since
		if db.enabled then C.TakeHud("loot") end
	end
end)

C.OnLogout(function()
	if db then C.ReleaseHud("loot") end
end)

C.RegisterPart({
	key = "loot", name = "Loot",
	note = "Your own loot pop-up in Creed UI's look: each drop with its icon, its name and whether it's new to your collection, and the marks you earn. Replaces the game's pop-up.",
	get = function() return db and db.enabled end,
	set = function(on)
		if db then
			db.enabled = on and true or false
			S.broken = false
			Apply()
		end
	end,
	getScale = function() return db and db.scale or 1 end,
	setScale = function(v)
		if db then
			db.scale = v
			root:SetScale(v)
		end
	end,
})
