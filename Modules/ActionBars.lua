local ADDON, ns = ...
local M = ns.M
local L = ns.L

local mod = {
	key = "actionbars",
	name = L["ActionBars"],
	nameKey = "ActionBars",
	defaultEnabled = true,
}

M:RegisterModule(mod)

M:RegisterModuleEvent("PLAYER_ENTERING_WORLD")

local MIN_LEVEL = 10
local HERO_TALENT_LEVEL = 71
local APPLY_ON_LOGIN_DELAY = 2
local ACTION_SLOT_MAX = 180
local PET_SLOT_MAX = 10
local WARN_MAX_LINES = 3
local MACRO_SCAN_LIMIT = 300
local MISSED_SLOT_LIST_MAX = 8

local function ClassKey()
	local _, classFile = UnitClass("player")
	return classFile or "UNKNOWN"
end

local function AsID(value)
	return tonumber(value) or value
end

local function SortIDs(list)
	table.sort(list, function(a, b)
		if type(a) == "number" and type(b) == "number" then
			return a < b
		end
		return tostring(a) < tostring(b)
	end)
end

local function MapGet(map, id)
	if type(map) ~= "table" then
		return nil
	end
	local v = map[id]
	if v ~= nil then
		return v
	end
	v = map[tostring(id)]
	if v ~= nil then
		return v
	end
	local n = tonumber(id)
	if n ~= nil then
		return map[n]
	end
	return nil
end

function mod:EnsureDB(db, charDb)
	local s = db.actionbars
	if type(s) ~= "table" then
		s = {}
		db.actionbars = s
	end
	if type(s.profiles) ~= "table" then
		s.profiles = {}
	end
	if s.schemaVersion ~= 1 then
		s.schemaVersion = 1
	end
	local legacyAutoApply = s.autoApply
	s.autoApply = nil
	self.db = s
	self.charDb = charDb
	local c = charDb.actionbars
	if type(c) ~= "table" then
		c = {}
		charDb.actionbars = c
	end
	if c.autoApply == nil then
		local auto = true
		if type(c.skipAutoApply) == "table" then
			for _, v in pairs(c.skipAutoApply) do
				if v then
					auto = false
					break
				end
			end
		elseif c.skipAutoApply == true or legacyAutoApply == false then
			auto = false
		end
		c.autoApply = auto
	end
	c.skipAutoApply = nil
	self.charSettings = c
end

function mod:IsAutoApplyAllowed()
	return (self.charSettings and self.charSettings.autoApply) and true or false
end

function mod:OnToggle(on)
end

local function CurrentSpecIndex()
	if type(C_SpecializationInfo) == "table" and type(C_SpecializationInfo.GetSpecialization) == "function" then
		local ok, index = pcall(C_SpecializationInfo.GetSpecialization)
		if ok then
			return index or 0
		end
	end
	if type(GetSpecialization) == "function" then
		return GetSpecialization() or 0
	end
	return 0
end

local function CallGetSpecInfo(index)
	if type(C_SpecializationInfo) == "table" and type(C_SpecializationInfo.GetSpecializationInfo) == "function" then
		local results = { pcall(C_SpecializationInfo.GetSpecializationInfo, index) }
		if results[1] then
			return results[2], results[3], results[4], results[5]
		end
	end
	if type(GetSpecializationInfo) == "function" then
		local results = { pcall(GetSpecializationInfo, index) }
		if results[1] then
			return results[2], results[3], results[4], results[5]
		end
	end
	return nil, nil, nil, nil
end

local function SpecID()
	local index = CurrentSpecIndex()
	if index ~= 0 then
		local result = CallGetSpecInfo(index)
		if type(result) == "table" then
			return result.specID or result[1] or 0
		end
		if type(result) == "number" then
			return result
		end
	end
	if type(C_ClassTalents) == "table" and C_ClassTalents.GetActiveSpecID then
		local ok, id = pcall(C_ClassTalents.GetActiveSpecID)
		if ok and type(id) == "number" then
			return id
		end
	end
	return 0
end

local function HeroTreeID()
	if UnitLevel("player") < HERO_TALENT_LEVEL then
		return 0
	end
	if type(C_ClassTalents) ~= "table" or type(C_ClassTalents.GetActiveHeroTalentSpec) ~= "function" then
		return 0
	end
	local ok, subTreeID = pcall(C_ClassTalents.GetActiveHeroTalentSpec)
	if not ok then
		return 0
	end
	return subTreeID or 0
end

local function ActiveConfigID()
	if type(C_ClassTalents) == "table" and type(C_ClassTalents.GetActiveConfigID) == "function" then
		local ok, id = pcall(C_ClassTalents.GetActiveConfigID)
		if ok then
			return id
		end
	end
	return nil
end

local function LastSelectedConfig(specID)
	if type(C_ClassTalents) == "table" and type(C_ClassTalents.GetLastSelectedSavedConfigID) == "function" then
		local ok, id = pcall(C_ClassTalents.GetLastSelectedSavedConfigID, specID)
		if ok then
			return id
		end
	end
	return nil
end

function mod:ProfilesForClass(classKey)
	local profiles = self.db.profiles
	local c = profiles[classKey]
	if type(c) ~= "table" then
		c = {}
		profiles[classKey] = c
	end
	return c
end

function mod:LayoutFor(classKey, specID, heroTreeID)
	local specs = self.db.profiles[classKey]
	if type(specs) ~= "table" then
		return nil
	end
	local heroMap = MapGet(specs, specID)
	if type(heroMap) ~= "table" then
		return nil
	end
	local layout = MapGet(heroMap, heroTreeID)
	if type(layout) ~= "table" then
		return nil
	end
	return layout
end

local function NumSpecializations()
	if type(C_SpecializationInfo) == "table" and type(C_SpecializationInfo.GetNumSpecializations) == "function" then
		local ok, n = pcall(C_SpecializationInfo.GetNumSpecializations)
		if ok and type(n) == "number" then
			return n
		end
	end
	if type(GetNumSpecializations) == "function" then
		return GetNumSpecializations() or 0
	end
	return 0
end

local function SpecInfoByIndex(index)
	local id, name, _, icon = CallGetSpecInfo(index)
	if type(id) == "table" then
		return id.specID or id[1], id.name, id.icon
	end
	return id, name, icon
end

local function SpecInfo(specID)
	if type(GetSpecializationInfoByID) == "function" then
		local results = { pcall(GetSpecializationInfoByID, specID) }
		if results[1] then
			local id, name, icon = results[2], results[3], results[5]
			if type(id) == "table" and id.name then
				name, icon = id.name, id.icon
			elseif type(id) == "string" and type(name) ~= "string" then
				name = id
			end
			if type(name) == "string" then
				if type(icon) ~= "number" and type(icon) ~= "string" then
					icon = nil
				end
				return name, icon
			end
		end
	end
	for i = 1, NumSpecializations() do
		local id, name, icon = SpecInfoByIndex(i)
		if id == specID then
			if type(icon) ~= "number" and type(icon) ~= "string" then
				icon = nil
			end
			return name or (L["Specialization"] .. " " .. tostring(specID)), icon
		end
	end
	return L["Specialization"] .. " " .. tostring(specID), nil
end

local function SpecName(specID)
	local name = SpecInfo(specID)
	return name
end

local function HeroName(heroID, specID)
	if not heroID or heroID == 0 then
		return L["Specialization"]
	end
	if type(C_Traits) == "table" and type(C_Traits.GetSubTreeInfo) == "function" then
		local configs = { ActiveConfigID(), specID and LastSelectedConfig(specID) or nil }
		for _, configID in ipairs(configs) do
			if configID then
				local ok, info = pcall(C_Traits.GetSubTreeInfo, configID, heroID)
				if ok and type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
					return info.name
				end
			end
		end
	end
	return L["Hero talent"] .. " " .. tostring(heroID)
end

local function PositiveID(id)
	if type(id) ~= "number" then
		return nil
	end
	if id > 0 then
		return id
	end
	return nil
end

local function SlotActionInfo(slot)
	local actionType, id, subType
	if type(GetActionInfo) == "function" then
		local ok
		ok, actionType, id, subType = pcall(GetActionInfo, slot)
		if not ok then
			actionType, id, subType = nil, nil, nil
		end
	end
	if actionType == "spell" and type(C_ActionBar) == "table" and type(C_ActionBar.GetSpell) == "function" then
		local ok, spellID = pcall(C_ActionBar.GetSpell, slot)
		if ok and PositiveID(spellID) then
			id = spellID
		end
	end
	return actionType, id, subType
end

local function MacroInfo(macroRef)
	if type(GetMacroInfo) ~= "function" then
		return nil
	end
	local ok, name, icon, body = pcall(GetMacroInfo, macroRef)
	if ok and type(name) == "string" and name ~= "" then
		return name, icon, body
	end
	return nil
end

local function MacroGlobalCount()
	if type(GetNumMacros) ~= "function" then
		return 0
	end
	local ok, globalCount = pcall(GetNumMacros)
	if ok and type(globalCount) == "number" then
		return globalCount
	end
	return 0
end

local function SlotActionText(slot)
	local text
	if type(C_ActionBar) == "table" and type(C_ActionBar.GetActionText) == "function" then
		local ok, value = pcall(C_ActionBar.GetActionText, slot)
		if ok and type(value) == "string" and value ~= "" then
			text = value
		end
	end
	if not text and type(GetActionText) == "function" then
		local ok, value = pcall(GetActionText, slot)
		if ok and type(value) == "string" and value ~= "" then
			text = value
		end
	end
	return text
end

local function MacroNameAt(actionID)
	if type(C_Macro) == "table" and type(C_Macro.GetMacroName) == "function" then
		local ok, name = pcall(C_Macro.GetMacroName, actionID)
		if ok and type(name) == "string" and name ~= "" then
			return name
		end
	end
	local name = MacroInfo(actionID)
	return name
end

local function SlotMacroName(slot, actionID)
	return SlotActionText(slot) or MacroNameAt(actionID)
end

local function MacroBook()
	local book = {}
	for index = 1, MACRO_SCAN_LIMIT do
		local name, icon, body = MacroInfo(index)
		if name and not book[name] then
			book[name] = { id = index, icon = icon, body = body }
		end
	end
	return book
end

local function CreateMacroFunc()
	if type(CreateMacro) == "function" then
		return CreateMacro
	end
	if type(C_Macro) == "table" and type(C_Macro.CreateMacro) == "function" then
		return C_Macro.CreateMacro
	end
	return nil
end

local function PickupMacroFunc()
	if type(PickupMacro) == "function" then
		return PickupMacro
	end
	if type(C_Macro) == "table" and type(C_Macro.PickupMacro) == "function" then
		return C_Macro.PickupMacro
	end
	return nil
end

local function MacroCreatable(action)
	return type(action.name) == "string" and action.name ~= ""
		and type(action.body) == "string"
		and CreateMacroFunc() ~= nil
end

local function FindMacroByContent(book, action)
	local record = book[action.name]
	if record and (type(action.body) ~= "string" or record.body == action.body) then
		return { name = action.name, id = record.id }
	end
	if type(action.body) == "string" then
		local names = {}
		for name in pairs(book) do
			names[#names + 1] = name
		end
		table.sort(names)
		for i = 1, #names do
			local other = book[names[i]]
			if other.body == action.body then
				return { name = names[i], id = other.id }
			end
		end
	end
	return nil
end

local function EnsureMacro(action, book)
	local existing = FindMacroByContent(book, action)
	if existing then
		return existing, false
	end
	local create = CreateMacroFunc()
	if type(create) ~= "function" or not MacroCreatable(action) then
		return nil, false
	end
	local ok, macroID = pcall(create, action.name, action.icon or "INV_Misc_QuestionMark", action.body, action.pc and true or nil)
	if not ok or not PositiveID(macroID) then
		return nil, false
	end
	book[action.name] = { id = macroID, icon = action.icon, body = action.body }
	return { name = action.name, id = macroID }, true
end

local function SpellKnown(spellID)
	if type(C_Spell) ~= "table" or type(C_Spell.GetSpellInfo) ~= "function" then
		return true
	end
	local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
	return (ok and info ~= nil) and true or false
end

local function ItemKnown(itemID)
	if type(C_Item) ~= "table" or type(C_Item.GetItemInfo) ~= "function" then
		return true
	end
	local ok, info = pcall(C_Item.GetItemInfo, itemID)
	return (ok and info ~= nil) and true or false
end

local function ActionAvailable(action, book)
	if not action then
		return false
	end
	if action.t == "spell" or action.t == "item" then
		if not PositiveID(action.id) then
			return false
		end
		if action.t == "spell" then
			return SpellKnown(action.id)
		end
		return ItemKnown(action.id)
	end
	if action.t == "macro" then
		return FindMacroByContent(book, action) ~= nil or MacroCreatable(action)
	end
	return false
end

local function SlotMatches(slot, action, macroName)
	local actionType, id = SlotActionInfo(slot)
	if action.t == "spell" then
		return actionType == "spell" and id == action.id
	end
	if action.t == "item" then
		return actionType == "item" and id == action.id
	end
	if action.t == "macro" then
		if actionType ~= "macro" then
			return false
		end
		local wanted = macroName or action.name
		return SlotActionText(slot) == wanted or MacroNameAt(id) == wanted
	end
	return false
end

local function PetBarActive()
	if type(PetHasActionBar) == "function" then
		local ok, active = pcall(PetHasActionBar)
		if ok then
			return active and true or false
		end
	end
	return type(GetPetActionInfo) == "function"
end

local function PetSlotMatches(slot, spellID)
	if type(GetPetActionInfo) ~= "function" then
		return false
	end
	local ok, _, _, _, _, _, _, id = pcall(GetPetActionInfo, slot)
	return ok and id == spellID
end

local function Snapshot(skipped)
	local slots = {}
	local book = MacroBook()
	local globalCount = MacroGlobalCount()
	for slot = 1, ACTION_SLOT_MAX do
		local actionType, id, subType = SlotActionInfo(slot)
		if actionType == "spell" and PositiveID(id) then
			slots[slot] = { t = "spell", id = id, sub = subType or 0 }
			if not SpellKnown(id) then
				skipped.unusable = skipped.unusable + 1
			end
		elseif actionType == "item" and PositiveID(id) then
			slots[slot] = { t = "item", id = id, sub = subType or 0 }
			if not ItemKnown(id) then
				skipped.items = skipped.items + 1
			end
		elseif actionType == "macro" then
			local name = SlotMacroName(slot, id)
			if name then
				local record = book[name] or {}
				slots[slot] = { t = "macro", id = record.id, name = name, icon = record.icon, body = record.body, pc = not record.id or record.id > globalCount, sub = 0 }
			end
		elseif actionType == "equipmentset" or actionType == "equipmacro" then
			skipped.sets = skipped.sets + 1
		end
	end
	local petSlots = {}
	if type(GetPetActionInfo) == "function" and PetBarActive() then
		for i = 1, PET_SLOT_MAX do
			local ok, name, _, _, _, _, _, spellID = pcall(GetPetActionInfo, i)
			if ok and PositiveID(spellID) then
				petSlots[i] = { t = "pet", id = spellID, sub = 0 }
			elseif ok and type(name) == "string" and name ~= "" then
				skipped.petActions = skipped.petActions + 1
			end
		end
	end
	return {
		{ key = "slots", name = "ActionSlots", count = ACTION_SLOT_MAX, slots = slots },
		{ key = "pet", name = "Pet", count = PET_SLOT_MAX, slots = petSlots },
	}
end

local function StoreSnapshot(classKey, specID, heroTreeID, snapshot)
	local specs = mod:ProfilesForClass(classKey)
	local heroMap = MapGet(specs, specID)
	if type(heroMap) ~= "table" then
		heroMap = {}
		specs[specID] = heroMap
	end
	heroMap[heroTreeID] = {
		savedAt = time(),
		bars = snapshot,
	}
end

local function CursorHasSomething()
	if type(GetCursorInfo) ~= "function" then
		return false
	end
	local ok, cursorType = pcall(GetCursorInfo)
	return ok and cursorType ~= nil
end

local function ClearCursorSafe()
	if type(ClearCursor) == "function" then
		pcall(ClearCursor)
	end
end

local function PickupSpellID(spellID)
	local ok = false
	if type(C_Spell) == "table" and type(C_Spell.PickupSpell) == "function" then
		ok = pcall(C_Spell.PickupSpell, spellID)
	elseif type(PickupSpell) == "function" then
		ok = pcall(PickupSpell, spellID)
	end
	return ok and CursorHasSomething()
end

local function PickupItemID(itemID)
	local ok = false
	if type(C_Item) == "table" and type(C_Item.PickupItem) == "function" then
		ok = pcall(C_Item.PickupItem, itemID)
	elseif type(PickupItem) == "function" then
		ok = pcall(PickupItem, itemID)
	end
	return ok and CursorHasSomething()
end

local function PickupMacroLive(action, live)
	local pickup = PickupMacroFunc()
	if type(pickup) ~= "function" then
		return false
	end
	local ok = false
	if live and PositiveID(live.id) then
		ok = pcall(pickup, live.id)
	end
	if not ok and live and type(live.name) == "string" and live.name ~= "" then
		ok = pcall(pickup, live.name)
	end
	if not ok and type(action.name) == "string" and action.name ~= "" then
		ok = pcall(pickup, action.name)
	end
	return ok and CursorHasSomething()
end

local function PutCursorInSlot(slot)
	if type(C_ActionBar) == "table" and type(C_ActionBar.PutActionInSlot) == "function" then
		local ok = pcall(C_ActionBar.PutActionInSlot, slot)
		if ok then
			return true
		end
	end
	if type(PlaceAction) == "function" then
		return pcall(PlaceAction, slot)
	end
	return false
end

local function ClearActionSlot(slot)
	if type(PickupAction) == "function" then
		pcall(PickupAction, slot)
	end
	ClearCursorSafe()
end

local function FindBar(layout, key)
	for _, entry in ipairs(layout.bars or {}) do
		if entry.key == key then
			return entry
		end
	end
	return nil
end

local function CollectSlotActions(slotBar)
	local actions = {}
	for key, action in pairs(slotBar.slots or {}) do
		local slot = tonumber(key)
		if slot and slot >= 1 and slot <= ACTION_SLOT_MAX and action and action.t ~= "pet" then
			actions[#actions + 1] = { slot = slot, action = action }
		end
	end
	table.sort(actions, function(a, b)
		return a.slot < b.slot
	end)
	return actions
end

function mod:ApplyLayout(layout)
	if not layout then
		return 0, 0, {}, false, 0
	end
	local placed, petPlaced, created = 0, 0, 0
	local missed = { spell = {}, item = {}, macro = {}, pet = {}, other = {} }
	ClearCursorSafe()
	local slotBar = FindBar(layout, "slots")
	if not slotBar and layout.bars and layout.bars[1] then
		for _, entry in ipairs(layout.bars) do
			for slot, action in pairs(entry.slots or {}) do
				local num = tonumber(slot)
				if num and num >= 1 and num <= ACTION_SLOT_MAX and action and action.t ~= "pet" then
					if not slotBar then
						slotBar = { slots = {} }
					end
					slotBar.slots[num] = action
				end
			end
		end
	end
	local plan = slotBar and CollectSlotActions(slotBar) or {}
	local macroBook = MacroBook()
	local usable = 0
	for _, entry in ipairs(plan) do
		if ActionAvailable(entry.action, macroBook) then
			usable = usable + 1
		end
	end
	if #plan > 0 and usable == 0 then
		return 0, 0, missed, true, 0
	end
	if slotBar then
		local macroLive = {}
		for _, entry in ipairs(plan) do
			if entry.action.t == "macro" then
				local live, made = EnsureMacro(entry.action, macroBook)
				if live then
					macroLive[entry.slot] = live
				end
				if made then
					created = created + 1
				end
			end
		end
		for slot = 1, ACTION_SLOT_MAX do
			ClearActionSlot(slot)
		end
		for _, entry in ipairs(plan) do
			local live = macroLive[entry.slot]
			local picked = false
			if entry.action.t == "spell" then
				picked = PickupSpellID(entry.action.id)
			elseif entry.action.t == "item" then
				picked = PickupItemID(entry.action.id)
			elseif entry.action.t == "macro" then
				picked = PickupMacroLive(entry.action, live)
			end
			local landed = false
			if picked then
				landed = PutCursorInSlot(entry.slot) and SlotMatches(entry.slot, entry.action, live and live.name)
			end
			ClearCursorSafe()
			if landed then
				placed = placed + 1
			else
				local bucket = "other"
				if entry.action.t == "macro" then
					bucket = "macro"
				elseif entry.action.t == "spell" and not SpellKnown(entry.action.id) then
					bucket = "spell"
				elseif entry.action.t == "item" and not ItemKnown(entry.action.id) then
					bucket = "item"
				end
				local list = missed[bucket]
				list[#list + 1] = entry.slot
			end
		end
	end
	local petBar = FindBar(layout, "pet")
	if petBar and type(PickupPetAction) == "function" and PetBarActive() then
		for i = 1, PET_SLOT_MAX do
			pcall(PickupPetAction, i)
			ClearCursorSafe()
		end
		for i = 1, PET_SLOT_MAX do
			local action = MapGet(petBar.slots, i)
			if action and PositiveID(action.id) then
				local landed = false
				if PickupSpellID(action.id) then
					pcall(PickupPetAction, i)
					landed = PetSlotMatches(i, action.id)
				end
				ClearCursorSafe()
				if landed then
					petPlaced = petPlaced + 1
				else
					missed.pet[#missed.pet + 1] = i
				end
			end
		end
	end
	ClearCursorSafe()
	return placed, petPlaced, missed, false, created
end

function mod:Warn(warnings)
	local order, counts = {}, {}
	for _, msg in ipairs(warnings or {}) do
		if counts[msg] then
			counts[msg] = counts[msg] + 1
		else
			counts[msg] = 1
			order[#order + 1] = msg
		end
	end
	local out, rest = {}, 0
	for i, msg in ipairs(order) do
		if i > WARN_MAX_LINES then
			rest = rest + 1
		elseif counts[msg] > 1 then
			out[#out + 1] = string.format("%s (%d)", msg, counts[msg])
		else
			out[#out + 1] = msg
		end
	end
	if rest > 0 then
		out[#out + 1] = L["and %d more"]:format(rest)
	end
	self.warnings = out
	for i = #out, 1, -1 do
		M.Print("|cffffd200!|r " .. out[i])
	end
	self:RefreshOptions()
end

local function SlotListText(slots)
	local out = {}
	local shown = math.min(#slots, MISSED_SLOT_LIST_MAX)
	for i = 1, shown do
		out[i] = tostring(slots[i])
	end
	local text = table.concat(out, ", ")
	if #slots > shown then
		text = text .. ", ..."
	end
	return text
end

local function SkipCountWarn(skipped)
	local out = {}
	if skipped.sets > 0 then
		out[#out + 1] = L["Skipped %d slots: equipment sets are not saved"]:format(skipped.sets)
	end
	if skipped.petActions > 0 then
		out[#out + 1] = L["Skipped %d slots: built-in pet bar controls not saved"]:format(skipped.petActions)
	end
	if skipped.items > 0 then
		out[#out + 1] = L["Skipped %d slots: item info not cached"]:format(skipped.items)
	end
	if skipped.unusable > 0 then
		out[#out + 1] = L["Skipped %d slots: spell not available on this character"]:format(skipped.unusable)
	end
	return out
end

function mod:StartSave()
	if InCombatLockdown() then
		M.Print(L["Action bars cannot be changed in combat"])
		return
	end
	local level = UnitLevel("player")
	if level < MIN_LEVEL then
		M.Print(L["Level %d is below the minimum (10)"]:format(level))
		return
	end
	local skipped = { sets = 0, petActions = 0, items = 0, unusable = 0 }
	local snapshot = Snapshot(skipped)
	local slotBar = snapshot[1]
	local count = 0
	for _ in pairs(slotBar.slots) do
		count = count + 1
	end
	StoreSnapshot(ClassKey(), SpecID(), HeroTreeID(), snapshot)
	local macroCount = 0
	for _, action in pairs(slotBar.slots) do
		if action.t == "macro" then
			macroCount = macroCount + 1
		end
	end
	local warnings = SkipCountWarn(skipped)
	if #warnings > 0 then
		self:Warn(warnings)
	else
		self.warnings = nil
	end
	M.Print(L["Saved %d slots"]:format(count))
	if macroCount > 0 then
		M.Print(L["Macro slots are restored by content; missing macros are created first"])
	end
	self:RefreshOptions()
end

function mod:ApplyCurrent(silent)
	if InCombatLockdown() then
		if not silent then
			M.Print(L["Action bars cannot be changed in combat"])
		end
		return
	end
	local layout = self:LayoutFor(ClassKey(), SpecID(), HeroTreeID())
	if not layout then
		if not silent then
			M.Print(L["Nothing saved for this specialization"])
		end
		return
	end
	local placed, petPlaced, missed, aborted, created = self:ApplyLayout(layout)
	if aborted then
		M.Print(L["Nothing to apply: no saved spell, item or macro is available on this character"])
		self:Warn({})
		return
	end
	if not silent then
		if placed > 0 then
			M.Print(L["Applied %d slots"]:format(placed))
		end
		if petPlaced > 0 then
			M.Print(L["Applied %d pet actions"]:format(petPlaced))
		end
		if created > 0 then
			M.Print(L["Created %d macros"]:format(created))
		end
		if placed == 0 and petPlaced == 0 and created == 0 then
			M.Print(L["Nothing was applied - check the saved layouts list"])
		end
	end
	local warnings = {}
	if #missed.spell > 0 then
		warnings[#warnings + 1] = L["Skipped %d slots: spell not available (%s)"]:format(#missed.spell, SlotListText(missed.spell))
	end
	if #missed.item > 0 then
		warnings[#warnings + 1] = L["Skipped %d slots: item not available (%s)"]:format(#missed.item, SlotListText(missed.item))
	end
	if #missed.macro > 0 then
		warnings[#warnings + 1] = L["Skipped %d slots: macro not placed (%s)"]:format(#missed.macro, SlotListText(missed.macro))
	end
	if #missed.pet > 0 then
		warnings[#warnings + 1] = L["Skipped %d pet actions: not placed (%s)"]:format(#missed.pet, SlotListText(missed.pet))
	end
	if #missed.other > 0 then
		warnings[#warnings + 1] = L["Skipped %d slots: not placed (%s)"]:format(#missed.other, SlotListText(missed.other))
	end
	if #warnings > 0 then
		self:Warn(warnings)
	else
		self.warnings = nil
		self:RefreshOptions()
	end
end

function mod:DeleteCurrentClass()
	local classKey = ClassKey()
	self.db.profiles[classKey] = nil
	self:RefreshOptions()
end

function mod:BuildOptions(p)
	local hint = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	hint:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -30)
	hint:SetWidth((p:GetWidth() or 444) - 24)
	hint:SetJustifyH("LEFT")
	hint:SetNonSpaceWrap(true)
	hint:SetText(L["Auto arrange"])
	p.hint = hint

	local auto = M.MakeFlatCheckbox(p, L["Apply automatically"], function(cb)
		self.charSettings.autoApply = cb:GetChecked() and true or false
	end)
	auto:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -52)
	auto:SetChecked(self:IsAutoApplyAllowed())
	p.autoApply = auto

	local saveOne = M.MakeFlatButton(p, 138, 26, L["Save current specialization"], function()
		self:StartSave()
	end)
	saveOne:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -86)

	local apply = M.MakeFlatButton(p, 138, 26, L["Apply current specialization"], function()
		self:ApplyCurrent(false)
	end)
	apply:SetPoint("LEFT", saveOne, "RIGHT", 6, 0)

	local del = M.MakeFlatButton(p, 138, 26, L["Delete saved data"], function()
		self:DeleteCurrentClass()
	end)
	del:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -118)

	local status = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	status:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -158)
	status:SetPoint("TOPRIGHT", p, "TOPRIGHT", -12, 0)
	status:SetJustifyH("LEFT")
	status:SetNonSpaceWrap(true)
	status:SetTextColor(0.6, 0.6, 0.6)
	p.status = status

	local listLabel = M.MakeSectionLabel(p, L["Saved layouts"])
	listLabel:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -192)
	p.listLabel = listLabel

	local scroll = CreateFrame("ScrollFrame", nil, p, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", p, "TOPLEFT", 4, -214)
	scroll:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -18, 66)
	pcall(scroll.SetClippingEnabled, scroll, true)
	p.scroll = scroll

	local rows = CreateFrame("Frame", nil, scroll)
	rows:SetSize(1, 1)
	scroll:SetScrollChild(rows)
	p.rows = rows
end

function mod:RefreshOptions()
	local p = self.optionsFrame
	if not p then
		return
	end
	if p.autoApply then
		p.autoApply:SetChecked(self:IsAutoApplyAllowed())
	end
	local hero = HeroTreeID()
	local spec = SpecID()
	local has = self:LayoutFor(ClassKey(), spec, hero) and true or false
	local state = has and L["Saved"] or L["Not saved"]
	local dim = hero > 0 and HeroName(hero, spec) or L["Specialization"]
	local statusText = string.format("%s / %s - %s", string.format(L["Current: %s"], SpecName(spec)), dim, state)
	if p.status then
		p.status:SetText(statusText)
	end

	local classKey = ClassKey()
	local specs = self.db.profiles[classKey]
	local rows = p.rows
	if not rows then
		return
	end
	rows.pool = rows.pool or {}
	rows:SetWidth(math.max((p:GetWidth() or 444) - 28, 100))
	local used = 0

	local function takeRow()
		used = used + 1
		local row = rows.pool[used]
		if not row then
			row = M.MakeListRow(rows, {})
			rows.pool[used] = row
		end
		return row
	end

	local function fill(row, icon, name, sub, selected, onClick)
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", rows, "TOPLEFT", 8, -(used - 1) * (M.LIST_ROW_HEIGHT + 2))
		row:SetWidth(rows:GetWidth())
		row.icon:SetTexture(icon or nil)
		row.name:SetText(name)
		if row.sub then
			row.sub:SetText(sub or "")
		end
		row:SetSelected(selected and true or false)
		row:SetStripe(used % 2 == 0)
		row:SetScript("OnClick", onClick)
		row:Show()
	end

	if type(specs) == "table" then
		local specIDs = {}
		for specID in pairs(specs) do
			specIDs[#specIDs + 1] = AsID(specID)
		end
		SortIDs(specIDs)
		local currentSpec = SpecID()
		local currentHero = HeroTreeID()
		for _, specID in ipairs(specIDs) do
			local heroMap = MapGet(specs, specID)
			local heroIDs = {}
			if type(heroMap) == "table" then
				for heroID in pairs(heroMap) do
					heroIDs[#heroIDs + 1] = AsID(heroID)
				end
			end
			SortIDs(heroIDs)
			local specActive = currentSpec == specID
			local name, icon = SpecInfo(specID)
			for _, heroID in ipairs(heroIDs) do
				local row = takeRow()
				local isActive = specActive and currentHero == heroID
				local label = HeroName(heroID, specID)
				fill(row, icon, name, label, isActive, function()
					self:ApplySpec(specID, heroID)
				end)
			end
		end
	end
	for i = used + 1, #rows.pool do
		rows.pool[i]:Hide()
	end
	rows:SetHeight(math.max(used, 1) * (M.LIST_ROW_HEIGHT + 2))
	if used == 0 and p.status then
		p.status:SetText(L["Nothing saved for this class yet"])
	end

	local warnings = self.warnings
	if p.warning then
		p.warning:Hide()
	end
	if warnings and #warnings > 0 then
		if not p.warning then
			local w = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
			w:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 12, 6)
			w:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -30, 6)
			w:SetWidth((p:GetWidth() or 444) - 42)
			w:SetJustifyH("LEFT")
			w:SetNonSpaceWrap(true)
			w:SetTextColor(1, 0.72, 0.3)
			p.warning = w
		end
		p.warning:SetText(table.concat(warnings, "\n"))
		p.warning:Show()
	end
end

function mod:ApplySpec(specID, heroID)
	if InCombatLockdown() then
		M.Print(L["Action bars cannot be changed in combat"])
		return
	end
	specID = AsID(specID)
	heroID = AsID(heroID)
	local layout = self:LayoutFor(ClassKey(), specID, heroID)
	if not layout then
		M.Print(L["Nothing saved for this specialization"])
		return
	end
	if specID ~= SpecID() or heroID ~= HeroTreeID() then
		M.Print(L["Switch to that specialization first"])
		return
	end
	self:ApplyCurrent(false)
end

function mod:OnEvent(event, ...)
	if event == "PLAYER_ENTERING_WORLD" then
		if self.didLoginApply then
			return
		end
		self.didLoginApply = true
		if self:IsAutoApplyAllowed() then
			C_Timer.After(APPLY_ON_LOGIN_DELAY, function()
				self:ApplyCurrent(true)
			end)
		end
	end
end
