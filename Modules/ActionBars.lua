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
M:RegisterModuleEvent("TRAIT_CONFIG_UPDATED")
M:RegisterModuleEvent("GLOBAL_MOUSE_DOWN")

local MIN_LEVEL = 10
local HERO_TALENT_LEVEL = 71
local APPLY_ON_LOGIN_DELAY = 2
local ACTION_SLOT_MAX = 180
local PET_SLOT_MAX = 10
local MACRO_SCAN_LIMIT = 300
local MISSED_SLOT_LIST_MAX = 8
local DETAIL_LINE_MAX = 10

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
	if on then
		M:SetMinimapContextHandler(function(anchorTo)
			local ok, err = pcall(self.ToggleQuickMenu, self, anchorTo)
			if not ok then
				M.Print(string.format(L["Module %s error: %s"], "actionbars", tostring(err)))
			end
		end, function()
			self:HideQuickMenu()
		end)
	else
		M:SetMinimapContextHandler(nil, nil)
	end
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

local function SelectedLoadoutID(specID)
	if type(C_ClassTalents) ~= "table" or type(C_ClassTalents.GetLastSelectedSavedConfigID) ~= "function" then
		return nil
	end
	local ok, id = pcall(C_ClassTalents.GetLastSelectedSavedConfigID, specID)
	if ok and type(id) == "number" then
		return id
	end
	return nil
end

local function BlizzardLoadouts(specID)
	local list = {}
	if type(C_ClassTalents) ~= "table" or type(C_ClassTalents.GetConfigIDsBySpecID) ~= "function" then
		return list
	end
	local ok, ids = pcall(C_ClassTalents.GetConfigIDsBySpecID, specID)
	if not ok or type(ids) ~= "table" then
		return list
	end
	for i = 1, #ids do
		local configID = ids[i]
		if type(configID) == "number" and configID > 0 then
			local name
			if type(C_Traits) == "table" and type(C_Traits.GetConfigInfo) == "function" then
				local okInfo, info = pcall(C_Traits.GetConfigInfo, configID)
				if okInfo and type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
					name = info.name
				end
			end
			list[#list + 1] = { id = configID, name = name }
		end
	end
	return list
end

local function SpecIndexByID(specID)
	for i = 1, NumSpecializations() do
		local id = SpecInfoByIndex(i)
		if id == specID then
			return i
		end
	end
	return nil
end

local function SwitchSpecialization(specID)
	local index = SpecIndexByID(specID)
	if index and type(C_ClassTalents) == "table" and type(C_ClassTalents.SwitchToSpecializationByIndex) == "function" then
		local ok = pcall(C_ClassTalents.SwitchToSpecializationByIndex, index)
		if ok then
			return true
		end
	end
	if type(SetSpecialization) == "function" then
		local ok = pcall(SetSpecialization, specID)
		return ok
	end
	return false
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

local function SpellName(spellID)
	if type(C_Spell) == "table" and type(C_Spell.GetSpellInfo) == "function" then
		local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
		if ok and type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
			return info.name
		end
	end
	return nil
end

local function ItemName(itemID)
	if type(C_Item) == "table" and type(C_Item.GetItemInfo) == "function" then
		local ok, name = pcall(C_Item.GetItemInfo, itemID)
		if ok and type(name) == "string" and name ~= "" then
			return name
		end
	end
	return nil
end

local function MissedEntry(slot, actionType, id, macroName)
	local label
	if actionType == "macro" then
		label = macroName
	elseif actionType == "item" then
		label = ItemName(id)
	else
		label = SpellName(id)
	end
	return { slot = slot, actionType = actionType, id = PositiveID(id), name = label }
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
				local actionType = entry.action.t
				local bucket = "other"
				if actionType == "macro" then
					bucket = "macro"
				elseif actionType == "spell" and not SpellKnown(entry.action.id) then
					bucket = "spell"
				elseif actionType == "item" and not ItemKnown(entry.action.id) then
					bucket = "item"
				end
				local list = missed[bucket]
				list[#list + 1] = MissedEntry(entry.slot, actionType, entry.action.id, entry.action.name)
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
					missed.pet[#missed.pet + 1] = MissedEntry(i, "pet", action.id)
				end
			end
		end
	end
	ClearCursorSafe()
	return placed, petPlaced, missed, false, created
end

function mod:Warn(warnings, details)
	local order, counts = {}, {}
	for _, msg in ipairs(warnings or {}) do
		if counts[msg] then
			counts[msg] = counts[msg] + 1
		else
			counts[msg] = 1
			order[#order + 1] = msg
		end
	end
	local out = {}
	for _, msg in ipairs(order) do
		if counts[msg] > 1 then
			out[#out + 1] = string.format("%s (%d)", msg, counts[msg])
		else
			out[#out + 1] = msg
		end
	end
	for i = #out, 1, -1 do
		M.Print("|cffffd200!|r " .. out[i])
	end
	for i = 1, #(details or {}) do
		M.Print("|cffffd200!|r " .. details[i])
	end
	self:RefreshOptions()
end

local function SlotListText(entries)
	local out = {}
	local shown = math.min(#entries, MISSED_SLOT_LIST_MAX)
	for i = 1, shown do
		out[i] = tostring(entries[i].slot)
	end
	local text = table.concat(out, ", ")
	if #entries > shown then
		text = text .. ", ..."
	end
	return text
end

local function MissedDetailLines(missed)
	local kinds = { "spell", "item", "macro", "pet", "other" }
	local total = 0
	for i = 1, #kinds do
		total = total + #(missed[kinds[i]] or {})
	end
	local lines = {}
	for i = 1, #kinds do
		for _, entry in ipairs(missed[kinds[i]] or {}) do
			if #lines >= DETAIL_LINE_MAX then
				return lines, total - #lines
			end
			local kindText
			if entry.actionType == "item" then
				kindText = L["Item"]
			elseif entry.actionType == "macro" then
				kindText = L["Macro"]
			elseif entry.actionType == "pet" then
				kindText = L["Pet action"]
			else
				kindText = L["Skill"]
			end
			local label = entry.name or L["Unknown"]
			if entry.id then
				lines[#lines + 1] = L["Slot %d: %s (%s %d)"]:format(entry.slot, label, kindText, entry.id)
			else
				lines[#lines + 1] = L["Slot %d: %s (%s)"]:format(entry.slot, label, kindText)
			end
		end
	end
	return lines, total - #lines
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
	M.Print(L["Saved %d slots"]:format(count))
	local warnings = SkipCountWarn(skipped)
	if #warnings > 0 then
		self:Warn(warnings)
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
	self:ApplyLayoutFor(SpecID(), HeroTreeID(), silent)
end

function mod:ApplyLayoutFor(specID, heroID, silent)
	local layout = self:LayoutFor(ClassKey(), specID, heroID)
	if not layout then
		if not silent then
			M.Print(L["Nothing saved for this specialization"])
		end
		return
	end
	local placed, petPlaced, missed, aborted, created = self:ApplyLayout(layout)
	if aborted then
		M.Print(L["Nothing to apply: no saved spell, item or macro is available on this character"])
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
		local details, rest = MissedDetailLines(missed)
		if rest > 0 then
			details[#details + 1] = L["and %d more"]:format(rest)
		end
		self:Warn(warnings, details)
	else
		self:RefreshOptions()
	end
end

local QUICK_MENU_MIN_WIDTH = 236
local QUICK_MENU_MAX_WIDTH = 560
local QUICK_MENU_HEIGHT = 420
local QUICK_MENU_PAD = 22
local QUICK_SPEC_TEXT_LEFT = 38
local QUICK_CONFIG_MARK_LEFT = 10
local QUICK_CONFIG_MARK_SIZE = 5
local QUICK_CONFIG_TEXT_LEFT = 22
local QUICK_ROW_HEIGHT = 28
local QUICK_CONFIG_ROW_HEIGHT = 26

local measureFs

local function MeasureText(text)
	if not measureFs then
		measureFs = UIParent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	end
	measureFs:SetText(text or "")
	return measureFs:GetStringWidth() or 0
end

function mod:GetQuickMenu()
	if self.quickMenu then
		return self.quickMenu
	end
	local f = CreateFrame("Frame", "MzxSpecBarQuickMenu", UIParent)
	f:SetFrameStrata("FULLSCREEN_DIALOG")
	f:SetFrameLevel(9000)
	f:SetSize(QUICK_MENU_MIN_WIDTH, QUICK_MENU_HEIGHT)
	f.menuHeight = QUICK_MENU_HEIGHT
	local setColors = M.MakeFlatSkin(f, 1)
	setColors(0.42, 0.40, 0.36, 0.95, 0.07, 0.08, 0.10, 0.97)
	pcall(tinsert, UISpecialFrames, "MzxSpecBarQuickMenu")

	local scroll = CreateFrame("ScrollFrame", nil, f)
	scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -6)
	scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, 6)
	pcall(scroll.SetClippingEnabled, scroll, true)

	local rows = CreateFrame("Frame", nil, scroll)
	rows:SetSize(1, 1)
	scroll:SetScrollChild(rows)
	f.scroll = scroll
	f.rows = rows
	f.scrollbar = M.MakeModernScrollbar(scroll)
	f:EnableMouse(true)

	f:Hide()
	self.quickMenu = f
	return f
end

function mod:RefreshQuickMenu()
	local f = self:GetQuickMenu()
	local rows = f.rows
	rows.rowPool = rows.rowPool or {}

	local entries = {}
	local maxText = 0
	for i = 1, NumSpecializations() do
		local id, name, icon = SpecInfoByIndex(i)
		if id then
			local label = name or (L["Specialization"] .. " " .. tostring(id))
			entries[#entries + 1] = { spec = true, id = id, name = label, icon = icon }
			maxText = math.max(maxText, MeasureText(label) + QUICK_SPEC_TEXT_LEFT)
			for _, cfg in ipairs(BlizzardLoadouts(id)) do
				local label2 = cfg.name or (L["Specialization configurations"] .. " " .. tostring(cfg.id))
				entries[#entries + 1] = { id = id, configID = cfg.id, name = label2 }
				maxText = math.max(maxText, MeasureText(label2) + QUICK_CONFIG_TEXT_LEFT)
			end
		end
	end

	f:SetWidth(math.min(math.max(maxText + QUICK_MENU_PAD, QUICK_MENU_MIN_WIDTH), QUICK_MENU_MAX_WIDTH))
	if f.scrollbar then
		f.scrollbar:Update()
	end
	local rowIndex = 0
	local y = 0

	local function addRow(icon, name, selected, onClick, opts)
		opts = opts or {}
		local height = opts.height or QUICK_ROW_HEIGHT
		local textLeft = opts.textLeft or 38
		rowIndex = rowIndex + 1
		local row = rows.rowPool[rowIndex]
		if not row then
			row = M.MakeListRow(rows, { height = height, singleLine = true, textLeft = textLeft })
			rows.rowPool[rowIndex] = row
		end
		row:SetHeight(height)
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", rows, "TOPLEFT", 0, -y)
		row:SetPoint("TOPRIGHT", rows, "TOPRIGHT", 0, -y)
		if icon then
			row.icon:Show()
			row.icon:SetSize(22, 22)
			row.icon:ClearAllPoints()
			row.icon:SetPoint("LEFT", 8, 0)
			row.icon:SetTexture(icon)
		else
			row.icon:Show()
			row.icon:SetSize(QUICK_CONFIG_MARK_SIZE, QUICK_CONFIG_MARK_SIZE)
			row.icon:ClearAllPoints()
			row.icon:SetPoint("LEFT", QUICK_CONFIG_MARK_LEFT, 0)
			row.icon:SetColorTexture(0.88, 0.74, 0.32, 0.85)
		end
		row.name:ClearAllPoints()
		row.name:SetJustifyV("MIDDLE")
		row.name:SetPoint("LEFT", row, "LEFT", textLeft, 0)
		row.name:SetText(name or "")
		if opts.dim then
			row.name:SetTextColor(0.80, 0.80, 0.86)
		else
			row.name:SetTextColor(0.95, 0.95, 0.98)
		end
		row:SetSelected(selected and true or false)
		M.SetStateIcon(row, selected and true or false)
		row:SetScript("OnClick", onClick)
		row:Show()
		y = y + height + (opts.gapAfter or 0)
	end

	local currentSpec = SpecID()
	local lastSpec
	for _, e in ipairs(entries) do
		if e.spec then
			if lastSpec ~= nil then
				y = y + 7
			end
			lastSpec = e.id
			addRow(e.icon, e.name, e.id == currentSpec, function()
				self:HideQuickMenu()
				if e.id ~= currentSpec and not SwitchSpecialization(e.id) then
					M.Print(L["Could not switch specialization"])
				end
			end, { height = QUICK_ROW_HEIGHT, textLeft = QUICK_SPEC_TEXT_LEFT, gapAfter = 2 })
		else
			addRow(nil, e.name, e.configID == SelectedLoadoutID(e.id), function()
				self:HideQuickMenu()
				self:SwitchLoadout(e.id, e.configID)
			end, { height = QUICK_CONFIG_ROW_HEIGHT, textLeft = QUICK_CONFIG_TEXT_LEFT, dim = true, gapAfter = 1 })
		end
	end

	for i = rowIndex + 1, #rows.rowPool do
		rows.rowPool[i]:Hide()
	end
	rows:SetHeight(math.max(y, 1))
	if f.scrollbar then
		f.scrollbar:Update()
	end
end

function mod:SwitchLoadout(specID, configID)
	if InCombatLockdown() then
		M.Print(L["Action bars cannot be changed in combat"])
		return
	end
	self.pendingLoadout = { specID = specID, configID = configID }
	self:ContinueLoadout()
end

function mod:ContinueLoadout()
	local pending = self.pendingLoadout
	if not pending then
		return
	end
	if SpecID() ~= pending.specID then
		if not SwitchSpecialization(pending.specID) then
			self.pendingLoadout = nil
			M.Print(L["Could not switch specialization"])
			return
		end
		local function waitSpec(delay)
			C_Timer.After(delay, function()
				if self.pendingLoadout ~= pending then
					return
				end
				if SpecID() ~= pending.specID then
					if delay > 0.3 then
						waitSpec(0.35)
						return
					end
					self.pendingLoadout = nil
					M.Print(L["Could not switch specialization"])
					return
				end
				self:ContinueLoadout()
			end)
		end
		waitSpec(0.25)
		return
	end
	if type(C_ClassTalents) == "table" and type(C_ClassTalents.LoadConfig) == "function" then
		local ok, result = pcall(C_ClassTalents.LoadConfig, pending.configID, true)
		if not ok or result == 0 then
			self.pendingLoadout = nil
			M.Print(L["Could not switch configuration"])
			return
		end
		if result == 2 then
			return
		end
	end
	self.pendingLoadout = nil
	self:ApplyLayoutFor(SpecID(), HeroTreeID(), false)
end

function mod:ShowQuickMenu(anchorTo)
	local f = self:GetQuickMenu()
	self:RefreshQuickMenu()
	f.anchorSource = anchorTo
	M:PlaceQuickMenu(f, anchorTo)
	if f:IsShown() and f.scrollbar then
		f.scrollbar:Update()
	end
end

function mod:HideQuickMenu()
	if self.quickMenu then
		self.quickMenu:Hide()
	end
end

function mod:OnGlobalMouseDown()
	local f = self.quickMenu
	if not f or not f:IsShown() then
		return
	end
	if f.anchorSource == "panel" then
		return
	end
	if f:IsMouseOver() then
		return
	end
	local button = M.minimapButton
	if button and button:IsMouseOver() then
		return
	end
	self:HideQuickMenu()
end

function mod:ToggleQuickMenu(anchorTo)
	local f = self.quickMenu
	if f and f:IsShown() then
		self:HideQuickMenu()
		return
	end
	self:ShowQuickMenu(anchorTo)
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

	local buttonWidth = (p:GetWidth() or 444) - 24
	local switcherWidth = math.floor((p:GetWidth() or 446) / 4)

	local saveOne = M.MakeFlatButton(p, buttonWidth, 26, L["Save current specialization"], function()
		self:StartSave()
	end)
	saveOne:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -86)
	saveOne:SetPoint("TOPRIGHT", p, "TOPRIGHT", -12, -86)
	M.SetRowButtonIcon(saveOne, "Interface\\AddOns\\MzxSpecBar\\Textures\\icon-save.tga", 18)

	local apply = M.MakeFlatButton(p, buttonWidth, 26, L["Apply current specialization"], function()
		self:ApplyCurrent(false)
	end)
	apply:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -116)
	apply:SetPoint("TOPRIGHT", p, "TOPRIGHT", -12, -116)
	M.SetRowButtonIcon(apply, "Interface\\AddOns\\MzxSpecBar\\Textures\\icon-apply.tga", 18)

	local del = M.MakeFlatDangerButton(p, buttonWidth, 26, L["Delete saved data"], function()
		self:DeleteCurrentClass()
	end)
	del:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -146)
	del:SetPoint("TOPRIGHT", p, "TOPRIGHT", -12, -146)
	M.SetRowButtonIcon(del, "Interface\\AddOns\\MzxSpecBar\\Textures\\icon-delete.tga", 18)

	local status = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	status:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -190)
	status:SetPoint("TOPRIGHT", p, "TOPRIGHT", -(12 + switcherWidth + 8), 0)
	status:SetJustifyH("LEFT")
	status:SetNonSpaceWrap(true)
	status:SetTextColor(0.6, 0.6, 0.6)
	p.status = status

	local listLabel = M.MakeSectionLabel(p, L["Saved layouts"])
	listLabel:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -206)
	p.listLabel = listLabel

	local specName, specIcon = SpecInfo(SpecID())
	local switcherHeight = M.LIST_ROW_TEXT_BLOCK_HEIGHT
	local iconPad, iconBorder = 2, 2
	local iconH = switcherHeight - iconPad * 2
	local switcher = M.MakeFlatIconTextButton(p, switcherWidth, switcherHeight, specName, iconH, function()
		if M._minimapContext then
			M._minimapContext("panel")
		end
	end, { dock = true, alt = true, iconBorder = iconBorder, gradient = { from = { 1.00, 0.00, 0.85 }, to = { 0.53, 0.27, 0.93 } } })
	switcher:SetPoint("RIGHT", p, "TOPRIGHT", -13, -204)
	p.switcher = switcher
	M.SetIconTextButton(switcher, specName, specIcon)
	switcher:SetScript("OnEnter", function(b)
		b._hovered = true
		M.ApplyFlatButtonVisual(b)
		GameTooltip:SetOwner(b, "ANCHOR_NONE")
		GameTooltip:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -4)
		GameTooltip:SetText(M.BrandTitle(L["Switch talents"]), 1, 1, 1)
		GameTooltip:Show()
	end)
	switcher:SetScript("OnLeave", function(b)
		b._hovered = false
		b._pushed = false
		M.ApplyFlatButtonVisual(b)
		GameTooltip:Hide()
	end)

	local scroll = CreateFrame("ScrollFrame", nil, p)
	scroll:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -236)
	scroll:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -12, 12)
	pcall(scroll.SetClippingEnabled, scroll, true)
	p.scroll = scroll

	local rows = CreateFrame("Frame", nil, scroll)
	rows:SetSize(1, 1)
	scroll:SetScrollChild(rows)
	p.rows = rows
	p.scrollbar = M.MakeModernScrollbar(scroll)
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
	if p.switcher then
		p.switcher:SetShown(M._minimapContext ~= nil)
		local name, icon = SpecInfo(spec)
		M.SetIconTextButton(p.switcher, name, icon)
	end
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
	if p.scrollbar then
		p.scrollbar:Update()
	end
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
		row:SetPoint("TOPLEFT", rows, "TOPLEFT", 0, -(used - 1) * (M.LIST_ROW_HEIGHT + 2))
		row:SetPoint("TOPRIGHT", rows, "TOPRIGHT", 0, -(used - 1) * (M.LIST_ROW_HEIGHT + 2))
		row.icon:SetTexture(icon or nil)
		row.name:SetText(name or "")
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
	if p.scrollbar then
		p.scrollbar:Update()
	end
	if used == 0 and p.status then
		p.status:SetText(L["Nothing saved for this class yet"])
	end
end

function mod:ApplySpec(specID, heroID)
	specID = AsID(specID)
	heroID = AsID(heroID)
	if not self:LayoutFor(ClassKey(), specID, heroID) then
		M.Print(L["Nothing saved for this specialization"])
		return
	end
	if SpecID() == specID then
		return
	end
	if self.pendingSpec then
		return
	end
	self.pendingSpec = specID
	if not SwitchSpecialization(specID) then
		self.pendingSpec = nil
		M.Print(L["Could not switch specialization"])
		return
	end
	local function waitForSwitch(delay)
		C_Timer.After(delay, function()
			local pending = self.pendingSpec
			if not pending then
				return
			end
			if SpecID() ~= pending then
				if delay > 0.3 then
					self.pendingSpec = nil
					M.Print(L["Could not switch specialization"])
					return
				end
				waitForSwitch(0.35)
				return
			end
			self.pendingSpec = nil
			self:RefreshOptions()
		end)
	end
	waitForSwitch(0.25)
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
	elseif event == "TRAIT_CONFIG_UPDATED" then
		if self.pendingLoadout then
			self.pendingLoadout = nil
			self:ApplyLayoutFor(SpecID(), HeroTreeID(), false)
		end
	elseif event == "GLOBAL_MOUSE_DOWN" then
		self:OnGlobalMouseDown()
	end
end
