local ADDON, ns = ...
local M = ns.M
local L = ns.L

local mod = {
	key = "language",
	name = L["Language"],
	nameKey = "Language",
	defaultEnabled = true,
	alwaysOn = true,
}

M:RegisterModule(mod)

local LOCALES = {
	{ code = "enUS", name = "English (US)" },
	{ code = "enGB", name = "English (GB)" },
	{ code = "zhCN", name = "简体中文" },
	{ code = "zhTW", name = "繁體中文" },
	{ code = "koKR", name = "한국어" },
	{ code = "deDE", name = "Deutsch" },
	{ code = "frFR", name = "Français" },
	{ code = "esES", name = "Español (España)" },
	{ code = "esMX", name = "Español (Latinoamérica)" },
	{ code = "ruRU", name = "Русский" },
	{ code = "ptBR", name = "Português (Brasil)" },
	{ code = "itIT", name = "Italiano" },
}

local ROW_H = 28
local TOP = -10

local rows = {}

local function ActiveCode()
	if M.db and M.db.locale then
		return M.db.locale
	end
	return GetLocale() or "enUS"
end

function mod:SetLocale(code)
	if not M.db then
		return
	end
	M.db.locale = code or nil
	ReloadUI()
end

function mod:RefreshOptions()
	local p = self.optionsFrame
	if not p then
		return
	end
	local override = M.db and M.db.locale
	local active = ActiveCode()
	for i = 1, #rows do
		local r = rows[i]
		local isCur
		if r.code == "AUTO" then
			isCur = not override
		elseif override then
			isCur = (r.code == override)
		else
			isCur = (r.code == active)
		end
		r:SetSelected(isCur)
		M.SetStateIcon(r, isCur)
	end
end

function mod:BuildOptions(p)
	rows = {}

	local defs = { { code = "AUTO", name = L["Client default"] } }
	for i = 1, #LOCALES do
		defs[#defs + 1] = LOCALES[i]
	end

	local prev
	for i = 1, #defs do
		local d = defs[i]
		local r = M.MakeListRow(p, {
			height = ROW_H,
			singleLine = true,
			stripe = (i % 2 == 0),
			onClick = function()
				if d.code == "AUTO" then
					mod:SetLocale(nil)
				else
					mod:SetLocale(d.code)
				end
			end,
		})
		r.code = d.code
		r.icon:Hide()
		r.name:ClearAllPoints()
		r.name:SetPoint("LEFT", 6, 0)
		r.name:SetText(d.name)
		if i == 1 then
			r:SetPoint("TOPLEFT", p, "TOPLEFT", 12, TOP)
		else
			r:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -2)
		end
		r:SetPoint("RIGHT", p, "RIGHT", -12, 0)
		rows[i] = r
		prev = r
	end
end
