-- Creed UI: the pet bar.
-- Just over the skill bar on its left, a small gold-railed bar for your pets. When the game gives
-- the pet its own buttons (a hunter's beast, a warlock's demon), they are here: click one to use
-- it, right-click to switch its autocast, point at it for the game's tooltip, a dark veil while it
-- cools down. Otherwise each kind of summon you have out (Spirit Wolves, Treants, an Infernal...)
-- shows its face, how many there are and the seconds the first one has left, followed by the
-- skills it has (what the game says each summon does, and any more the meter sees it use), each
-- with what it hits for under it.
-- Nothing out, nothing shows; it hides behind the level-up cards.

local C = CreedUI
local DEFAULTS = { enabled = true, scale = 1 }
local K = { slot = 30, skill = 22, gap = 4, pad = 7, under = 9, actions = 10, skills = 4, groups = 4 }

-- Each summon's own face, by a word in its name: the first that matches wins (the Spirit Wolf
-- before the wolf). One the list doesn't know keeps the game's icon.
local FACES = {
	{ "spirit wolf", "Spell_Nature_SpiritWolf" }, { "wolf", "Ability_Hunter_Pet_Wolf" },
	{ "raptor", "Ability_Hunter_Pet_Raptor" }, { "water elemental", "Spell_Frost_SummonWaterElemental" },
	{ "imp", "Spell_Shadow_SummonImp" }, { "voidwalker", "Spell_Shadow_SummonVoidWalker" },
	{ "succubus", "Spell_Shadow_SummonSuccubus" }, { "felhunter", "Spell_Shadow_SummonFelHunter" },
	{ "infernal", "Spell_Shadow_SummonInfernal" }, { "doomguard", "Spell_Shadow_AntiMagicShell" },
	{ "treant", "Spell_Nature_ProtectionformNature" },
	{ "cat", "Ability_Hunter_Pet_Cat" }, { "lion", "Ability_Hunter_Pet_Cat" }, { "tiger", "Ability_Hunter_Pet_Cat" },
	{ "panther", "Ability_Hunter_Pet_Cat" }, { "bear", "Ability_Hunter_Pet_Bear" }, { "boar", "Ability_Hunter_Pet_Boar" },
	{ "gorilla", "Ability_Hunter_Pet_Gorilla" }, { "spider", "Ability_Hunter_Pet_Spider" },
	{ "scorpid", "Ability_Hunter_Pet_Scorpid" }, { "crab", "Ability_Hunter_Pet_Crab" },
	{ "crocolisk", "Ability_Hunter_Pet_Crocolisk" }, { "owl", "Ability_Hunter_Pet_Owl" }, { "bat", "Ability_Hunter_Pet_Bat" },
	{ "hyena", "Ability_Hunter_Pet_Hyena" }, { "serpent", "Ability_Hunter_Pet_WindSerpent" },
	{ "strider", "Ability_Hunter_Pet_TallStrider" }, { "turtle", "Ability_Hunter_Pet_Turtle" },
	{ "vulture", "Ability_Hunter_Pet_Vulture" }, { "carrion", "Ability_Hunter_Pet_Vulture" },
}

-- What each kind of summon can do, as the game's own words tell it: its skills in the order they
-- show, each with its icon. Found by the same words as its face; a skill the meter sees it use that
-- isn't here comes after them.
local I = "Interface\\Icons\\"
local MELEE = { "Melee", I .. "Ability_MeleeDamage", "Its own swings at the enemy in front of it." }
local BITE = { "Bite", I .. "Ability_Racial_Cannibalize", "Bites the enemy you attack." }
local BEAST = { { "Kill Command", I .. "Ability_Hunter_BeastCall", "Sends each pet charging at its own target, bosses and elites first." },
	{ "Bestial Wrath", I .. "Ability_Druid_FerociousBite", "Its bites strike 5 more enemies for 150% damage each." } }
local KNOWS = {
	{ "spirit wolf", { BITE, MELEE } },
	{ "devilsaur", { BITE, BEAST[1], BEAST[2] } },
	{ "wolf", { BITE, BEAST[1], BEAST[2] } },
	{ "raptor", { { "Raptor Strike", I .. "Ability_MeleeDamage", "Strikes three times in quick succession." }, BEAST[1], BEAST[2] } },
	{ "water elemental", { { "Frostbolt", I .. "Spell_Frost_FrostBolt02", "Hurls Frostbolts at your enemies." } } },
	{ "imp", { { "Firebolt", I .. "Spell_Fire_FireBolt", "Hurls bolts of fire at your enemies." } } },
	{ "voidwalker", { { "Shadow Cleave", I .. "Ability_Warrior_Cleave", "Hits 2 enemies at once." }, MELEE } },
	{ "felguard", { { "Cleave", I .. "Ability_Warrior_Cleave", "Cleaves up to 10 enemies; every third swing deals double damage." }, MELEE } },
	{ "infernal", { { "Hellfire", I .. "Spell_Fire_Incinerate", "Burns the enemies around it." }, MELEE } },
	{ "doomguard", { { "Shadow Bolt", I .. "Spell_Shadow_ShadowBolt", "Hurls Shadow Bolts at your enemies." }, MELEE } },
	{ "treant", { MELEE } },
}

local function Words(grp)
	-- its words, each after a space (Lua 5.0 has no word edges in its patterns)
	return " " .. string.gsub(string.lower(tostring(grp.key or "") .. " " .. tostring(grp.name or "")), "[^%a]+", " ")
end

-- its skills: the known ones, then the ones the meter saw it use; { name, icon, key } each
local function SkillsOf(grp, seen)
	local out, has = {}, {}
	local words = Words(grp)
	for i = 1, table.getn(KNOWS) do
		if string.find(words, " " .. KNOWS[i][1]) then
			local list = KNOWS[i][2]
			for k = 1, table.getn(list) do
				table.insert(out, { name = list[k][1], icon = list[k][2], does = list[k][3] })
				has[list[k][1]] = true
			end
			break
		end
	end
	seen = seen or {}
	for k = 1, table.getn(seen) do
		if not has[seen[k].name or ""] then
			table.insert(out, { name = seen[k].name, icon = seen[k].icon, key = seen[k].key })
			has[seen[k].name or ""] = true
		end
	end
	return out
end

local function Face(grp)
	local words = Words(grp)
	for i = 1, table.getn(FACES) do
		if string.find(words, " " .. FACES[i][1]) then return "Interface\\Icons\\" .. FACES[i][2] end
	end
	return grp.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local db
local root
local S = { slots = {}, alpha = 0, broken = false, mode = nil }

------------------------------------------------------------------------ what there is
-- the game's pet buttons: { index, name, icon, active, auto, autoAllowed } each, or nil for none
local function Actions()
	if type(GetPetActionInfo) ~= "function" then return nil end
	if type(PetHasActionBar) == "function" and not PetHasActionBar() then return nil end
	local out
	for i = 1, K.actions do
		local name, _, tex, isToken, active, autoAllowed, auto = GetPetActionInfo(i)
		if name then
			out = out or {}
			if isToken and type(tex) == "string" then tex = getglobal(tex) or tex end
			if isToken and type(name) == "string" then name = getglobal(name) or name end
			table.insert(out, { index = i, name = name, icon = tex, active = active, auto = auto, autoAllowed = autoAllowed })
		end
	end
	return out
end

-- your summons by kind, each with the skills the meter saw it use
local function Groups()
	if type(AZS_GetSummonGroups) ~= "function" then return nil end
	local ok, groups = pcall(AZS_GetSummonGroups)
	if not ok or type(groups) ~= "table" or table.getn(groups) == 0 then return nil end
	return groups
end

------------------------------------------------------------------------ a skill's tooltip
-- What it does, then its damage as it is now, read off its own hits: they carry your stats (your
-- pets' damage bonus, gear, buffs) as they stand, so a change shows at its next hit.
local function Num(n) return C.Commas(math.floor(n + 0.5)) end

local function SkillTip(s)
	if s.does then GameTooltip:AddLine(C.L(s.does), 1, 1, 1, 1) end
	local v = s.hv
	if v and (v.last or v.crit) then
		if v.last then
			GameTooltip:AddDoubleLine(C.L("Hits for"), Num(v.last), 0.8, 0.8, 0.8, 1, 1, 1)
			GameTooltip:AddDoubleLine(C.L("Usually"), Num(v.avg), 0.8, 0.8, 0.8, 1, 1, 1)
			if v.high and v.high > v.low then
				GameTooltip:AddDoubleLine(C.L("Range"), Num(v.low) .. " - " .. Num(v.high), 0.8, 0.8, 0.8, 1, 1, 1)
			end
		end
		if v.crit then GameTooltip:AddDoubleLine(C.L("Crits for"), Num(v.crit), 0.8, 0.8, 0.8, 1, 0.82, 0.3) end
		local rate = C.HitRate(v)
		if rate > 0 then GameTooltip:AddDoubleLine(C.L("Hits per second"), string.format("%.1f", rate), 0.8, 0.8, 0.8, 1, 1, 1) end
	else
		GameTooltip:AddLine(C.L("Its value shows once it hits."), 0.7, 0.7, 0.7, 1)
	end
	local bonus = type(AZS_STATS) == "table" and tonumber(AZS_STATS.pet)
	if bonus and bonus ~= 0 then
		GameTooltip:AddDoubleLine(C.L("Pet Damage"), string.format("%+.0f%%", bonus * 100), 0.8, 0.8, 0.8, 0.4, 1, 0.4)
	end
end

------------------------------------------------------------------------ the slots
local function NewSlot(i)
	local s = { cool = 0 }
	local b = CreateFrame("Button", nil, root)
	s.button = b
	b:EnableMouse(true)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	s.bg = C.Tex(b, "BACKGROUND", C.FLAT)
	s.bg:SetPoint("TOPLEFT", b, "TOPLEFT", 3, -3)
	s.bg:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
	s.bg:SetVertexColor(0.03, 0.03, 0.04, 0.92)
	s.icon = b:CreateTexture(nil, "BORDER")
	s.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 3, -3)
	s.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
	s.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	s.shade = C.Tex(b, "ARTWORK", C.FLAT)
	s.shade:SetPoint("TOP", b, "TOP", 0, -3)
	s.shade:SetVertexColor(0, 0, 0, 0.66)
	s.bezel = C.Tex(b, "OVERLAY", C.ART .. "Slot")
	s.bezel:SetAllPoints(b)
	s.top = CreateFrame("Frame", nil, b)
	s.top:SetAllPoints(b)
	s.top:SetFrameLevel(b:GetFrameLevel() + 2)
	-- autocast on, or the pet's stance in use: a gold glow round the slot
	s.glow = C.Tex(s.top, "OVERLAY", C.ART .. "Glow", "ADD")
	s.glow:SetPoint("CENTER", b, "CENTER", 0, 0)
	s.glow:SetVertexColor(1, 0.80, 0.40)
	s.count = C.Text(s.top, C.FONT, 11, "OUTLINE", "RIGHT", 30)
	s.count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
	s.time = C.Text(s.top, C.FONT, 9, "OUTLINE", "CENTER", 40)
	s.time:SetPoint("TOP", b, "BOTTOM", 0, -1)
	s.time:SetTextColor(1, 0.86, 0.6)
	C.Vis(s.shade, false)
	C.Vis(s.glow, false)
	b:SetScript("OnClick", function()
		if s.kind ~= "action" then return end
		if arg1 == "RightButton" then
			if type(TogglePetAutocast) == "function" then C.Call(TogglePetAutocast, s.index) end
		elseif type(CastPetAction) == "function" then
			C.Call(CastPetAction, s.index)
		end
	end)
	b:SetScript("OnEnter", function()
		if not GameTooltip or C.unlocked then return end
		GameTooltip:SetOwner(b, "ANCHOR_TOP")
		if s.kind == "action" and GameTooltip.SetPetAction then
			GameTooltip:SetPetAction(s.index)
			GameTooltip:Show()
			return
		end
		GameTooltip:AddLine(s.name or "?", 0.98, 0.85, 0.52)
		if s.kind == "summon" then
			if (s.n or 1) > 1 then GameTooltip:AddLine(C.F("{1} out", s.n), 1, 1, 1) end
			if s.left then GameTooltip:AddLine(C.F("{1} s left", math.ceil(s.left)), 1, 1, 1) end
			if not s.hasSkills then GameTooltip:AddLine(C.L("Its skills show here once it uses them."), 0.7, 0.7, 0.7, 1) end
		elseif s.kind == "skill" then
			SkillTip(s)
		end
		C.ShowTip()
	end)
	b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
	S.slots[i] = s
	return s
end

local function Put(i, x, size, kind)
	local s = S.slots[i] or NewSlot(i)
	s.kind = kind
	C.Size(s.button, size, size)
	C.Place(s.button, "BOTTOMLEFT", root, "BOTTOMLEFT", x, K.pad + K.under) -- room under it for its numbers
	C.Size(s.glow, size * 1.9, size * 1.9)
	C.Vis(s.button, true)
	return s
end

local function Cooldown(s, size)
	local start, dur, enable = 0, 0, 1
	if type(GetPetActionCooldown) == "function" then start, dur, enable = GetPetActionCooldown(s.index) end
	local left = (enable ~= 0 and (dur or 0) > 1.5) and (start + dur - GetTime()) or 0
	if left > 0 then
		C.Size(s.shade, size - 6, math.max(1, (size - 6) * left / dur))
		C.Vis(s.shade, true)
	else
		C.Vis(s.shade, false)
	end
end

------------------------------------------------------------------------ each frame
local function Step(dt, now)
	local n, x = 0, K.pad
	local actions = Actions()
	if actions then
		for i = 1, table.getn(actions) do
			local a = actions[i]
			n = n + 1
			local s = Put(n, x, K.slot, "action")
			s.index, s.name = a.index, a.name
			s.icon:SetTexture(a.icon)
			Cooldown(s, K.slot)
			C.Vis(s.glow, (a.auto or a.active) and true or false)
			C.SetText(s.count, "")
			C.SetText(s.time, "")
			x = x + K.slot + K.gap
		end
	else
		local groups = Groups() or {}
		local skills = C.petSkills or {}
		for g = 1, math.min(table.getn(groups), K.groups) do
			local grp = groups[g]
			n = n + 1
			local s = Put(n, x, K.slot, "summon")
			s.name, s.n, s.left = grp.name, tonumber(grp.count) or 1, tonumber(grp.remaining)
			s.icon:SetTexture(Face(grp))
			C.Vis(s.shade, false)
			C.Vis(s.glow, false)
			C.SetText(s.count, (s.n > 1) and tostring(s.n) or "")
			C.SetText(s.time, s.left and tostring(math.ceil(s.left)) or "")
			x = x + K.slot + K.gap
			-- only the skills whose hits have been seen: a value we can't read isn't shown (a buff such
			-- as Bestial Wrath deals none of its own; one the game reports apart never shows up here)
			local all = SkillsOf(grp, skills[grp.key] or skills[grp.name])
			local list = {}
			for k = 1, table.getn(all) do
				local hv = C.hitValues and (C.hitValues[all[k].key or ""] or C.hitValues[all[k].name or ""]
					or C.hitValues[C.SkillKey(all[k].name) or ""])
				if hv and hv.last then
					all[k].hv = hv
					table.insert(list, all[k])
				end
			end
			s.hasSkills = table.getn(list) > 0
			for k = 1, math.min(table.getn(list), K.skills) do
				n = n + 1
				local sk = Put(n, x, K.skill, "skill")
				local hv = list[k].hv
				sk.name, sk.value, sk.hv, sk.does = C.L(list[k].name), hv.last, hv, list[k].does
				sk.icon:SetTexture(list[k].icon or "Interface\\Icons\\INV_Misc_QuestionMark")
				C.Vis(sk.shade, false)
				C.Vis(sk.glow, false)
				C.SetText(sk.count, "")
				C.SetText(sk.time, C.Short(sk.value))
				x = x + K.skill + K.gap
			end
			x = x + K.gap * 2
		end
	end
	for i = n + 1, table.getn(S.slots) do C.Vis(S.slots[i].button, false) end
	local want = (n > 0) and (1 - C.cardsFade) or 0
	S.alpha = C.Toward(S.alpha, want, 8, dt)
	if S.alpha < 0.01 then
		C.Vis(root, false)
		return
	end
	C.Width(root, math.max(x - K.gap + K.pad, K.slot + 2 * K.pad))
	C.Alpha(root, S.alpha)
	C.Vis(root, true)
end

local function Apply()
	if not db.enabled then
		C.Vis(root, false)
		S.alpha = 0
	end
end

C.OnInit(function()
	db = C.DB("pets", DEFAULTS)
	root = CreateFrame("Frame", "CreedUIPetBar", UIParent)
	root:SetWidth(K.slot + 2 * K.pad)
	root:SetHeight(K.slot + 2 * K.pad + K.under)
	root:SetFrameStrata("MEDIUM")
	root:SetScale(db.scale)
	root.deco = C.Panel(root, false)
	C.PanelTheme(root.deco, C.Pal())
	C.Vis(root, false)
	C.Movable(root, "pets", "Pet bar", function(f)
		f:ClearAllPoints()
		if CreedUIBar then
			f:SetPoint("BOTTOMLEFT", CreedUIBar, "TOPLEFT", 0, 30) -- over the skill bar, on its left
		else
			f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOM", -260, 110)
		end
	end)
	local driver = CreateFrame("Frame", "CreedUIPetBarDriver")
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
			C.Print(C.L("the pet bar stopped after an error: ") .. tostring(err))
		end
	end)
	Apply()
end)

C.RegisterPart({
	key = "pets", name = "Pet bar",
	note = "Over the skill bar on the left: your pet's own buttons (click to use, right-click for autocast), or each kind of summon you have out with its count, time left and the skills it has used.",
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
