-- MzxSpecBar 核心：配置窗 / 扁平 UI 助手 / 模块注册 / 小地图按钮 / 斜杠 / i18n / 存档
-- 业务功能一律写在 Modules\ 下，本文件只提供框架与共享封装。
local ADDON, ns = ...
local M = CreateFrame("Frame")
ns.M = M
local L = ns.L

M.version = "1.0.1"
M.moduleList = {}
M.modules = {}

local Print = function(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cffffd200MzxSpecBar|r " .. tostring(msg))
end
M.Print = Print

-- ------------------------------------------------------------------ 模块系统

function M:RegisterModule(mod)
	self.moduleList[#self.moduleList + 1] = mod
	self.modules[mod.key] = mod
	mod.owner = self
end

function M:IsModuleEnabled(key)
	local mod = self.modules[key]
	if mod and mod.alwaysOn then
		return true
	end
	return (self.db and self.db.modules and self.db.modules[key]) and true or false
end

function M:SetModuleEnabled(key, on)
	local mod = self.modules[key]
	if mod and mod.alwaysOn then
		return
	end
	if not self.db then
		return
	end
	on = on and true or false
	self.db.modules[key] = on
	if mod and mod.OnToggle then
		local ok, err = pcall(mod.OnToggle, mod, on)
		if not ok then
			Print(string.format(L["Module %s error: %s"], key, tostring(err)))
		end
	end
	self:RefreshConfigIfOpen()
end

-- 注册模块事件（同一事件只向框架注册一次；事件会转发给所有已启用模块）
function M:RegisterModuleEvent(event)
	self._modEvents = self._modEvents or {}
	if not self._modEvents[event] then
		self._modEvents[event] = true
		if not pcall(self.RegisterEvent, self, event) then
			self._modEvents[event] = nil
		end
	end
end

function M:OnEvent(event, ...)
	if event == "PLAYER_LOGIN" and not self._booted then
		self._booted = true
		self:InitDB()
		local loc = self.db.locale
		if not loc or not (ns.knownLocales and ns.knownLocales[loc]) then
			loc = GetLocale()
		end
		ns.ApplyLocale(loc)
		self:LocalizeModuleNames()
		self:ApplyModuleStates()
		if not self.minimapButton then
			self.minimapButton = self:CreateMinimapButton()
		end
	end
	for _, mod in ipairs(self.moduleList) do
		if mod.OnEvent and self:IsModuleEnabled(mod.key) then
			local ok, err = pcall(mod.OnEvent, mod, event, ...)
			if not ok then
				Print(string.format(L["Module %s error: %s"], mod.key, tostring(err)))
			end
		end
	end
end

M:SetScript("OnEvent", M.OnEvent)
M:RegisterEvent("PLAYER_LOGIN")

-- ------------------------------------------------------------------ 存档

local function EnsureDB()
	local db = MzxSpecBarDB
	if type(db) ~= "table" then
		db = {}
		MzxSpecBarDB = db
	end
	if type(db.modules) ~= "table" then
		db.modules = {}
	end
	if type(db.minimapPos) ~= "number" then
		db.minimapPos = 135
	end
	return db
end
M.EnsureDB = EnsureDB

local function EnsureCharDB()
	local cdb = MzxSpecBarCharDB
	if type(cdb) ~= "table" then
		cdb = {}
		MzxSpecBarCharDB = cdb
	end
	return cdb
end
M.EnsureCharDB = EnsureCharDB

function M:InitDB()
	self.db = EnsureDB()
	local charDb = EnsureCharDB()
	if self.db.locale and not (ns.knownLocales and ns.knownLocales[self.db.locale]) then
		self.db.locale = nil
	end
	for _, mod in ipairs(self.moduleList) do
		if not mod.alwaysOn and self.db.modules[mod.key] == nil then
			self.db.modules[mod.key] = mod.defaultEnabled and true or false
		end
		if mod.EnsureDB then
			pcall(mod.EnsureDB, mod, self.db, charDb)
		end
	end
end

function M:ApplyModuleStates()
	for _, mod in ipairs(self.moduleList) do
		if mod.OnToggle then
			pcall(mod.OnToggle, mod, self:IsModuleEnabled(mod.key))
		end
	end
end

function M:LocalizeModuleNames()
	for _, mod in ipairs(self.moduleList) do
		if mod.nameKey then
			mod.name = L[mod.nameKey]
		end
	end
end

-- ------------------------------------------------------------------ 通用 UI 皮肤

-- 扁平边框：内缩填充 + 四条独立 1px 边线；返回 setColors(borderR,G,B,A, fillR,G,B,A)
function M.MakeFlatSkin(frame, thickness)
	local t = thickness or 1
	local fill = frame:CreateTexture(nil, "BACKGROUND")
	fill:SetPoint("TOPLEFT", t, -t)
	fill:SetPoint("BOTTOMRIGHT", -t, t)
	local top = frame:CreateTexture(nil, "ARTWORK")
	top:SetPoint("TOPLEFT", 0, 0)
	top:SetPoint("TOPRIGHT", 0, 0)
	top:SetHeight(t)
	local bottom = frame:CreateTexture(nil, "ARTWORK")
	bottom:SetPoint("BOTTOMLEFT", 0, 0)
	bottom:SetPoint("BOTTOMRIGHT", 0, 0)
	bottom:SetHeight(t)
	local left = frame:CreateTexture(nil, "ARTWORK")
	left:SetPoint("TOPLEFT", 0, 0)
	left:SetPoint("BOTTOMLEFT", 0, 0)
	left:SetWidth(t)
	local right = frame:CreateTexture(nil, "ARTWORK")
	right:SetPoint("TOPRIGHT", 0, 0)
	right:SetPoint("BOTTOMRIGHT", 0, 0)
	right:SetWidth(t)

	local tr, tg, tb, ta = 1, 1, 1, 1
	local fr, fg, fb, fa = 1, 1, 1, 1
	local function setColors(borderR, borderG, borderB, borderA, fillR, fillG, fillB, fillA)
		tr, tg, tb, ta = borderR, borderG, borderB, borderA
		fr, fg, fb, fa = fillR, fillG, fillB, fillA
		top:SetColorTexture(tr, tg, tb, ta)
		bottom:SetColorTexture(tr, tg, tb, ta)
		left:SetColorTexture(tr, tg, tb, ta)
		right:SetColorTexture(tr, tg, tb, ta)
		fill:SetColorTexture(fr, fg, fb, fa)
	end
	return setColors
end

function M.SnapToPixelGrid(frame)
	local s = UIParent:GetEffectiveScale()
	local px, py = frame:GetCenter()
	if px and py then
		frame:ClearAllPoints()
		frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", math.floor(px * s + 0.5) / s, math.floor(py * s + 0.5) / s)
	end
end

local FLAT_BTN = {
	normal = { bg = { 0.16, 0.17, 0.20, 0.85 }, text = { 0.92, 0.92, 0.94 } },
	hover = { bg = { 0.24, 0.25, 0.29, 0.95 }, text = { 1, 1, 1 } },
	pushed = { bg = { 0.12, 0.13, 0.15, 0.95 }, text = { 1, 0.82, 0.2 } },
	selected = { bg = { 0.30, 0.25, 0.10, 0.95 }, text = { 1, 0.82, 0.2 } },
	disabled = { bg = { 0.12, 0.12, 0.14, 0.70 }, text = { 0.45, 0.45, 0.48 } },
}

local FLAT_BTN_DANGER = {
	normal = { bg = { 0.29, 0.08, 0.08, 0.92 }, text = { 1.00, 0.42, 0.38 } },
	hover = { bg = { 0.42, 0.12, 0.12, 0.95 }, text = { 1.00, 0.60, 0.55 } },
	pushed = { bg = { 0.22, 0.06, 0.06, 0.95 }, text = { 1.00, 0.33, 0.29 } },
	selected = { bg = { 0.36, 0.10, 0.10, 0.95 }, text = { 1.00, 0.70, 0.65 } },
	disabled = { bg = { 0.16, 0.07, 0.07, 0.70 }, text = { 0.45, 0.32, 0.30 } },
}

function M.ApplyFlatButtonVisual(b)
	local enabled = true
	if b.IsEnabled then
		enabled = b:IsEnabled()
	end
	local palette = b.danger and FLAT_BTN_DANGER or FLAT_BTN
	local style
	if not enabled then
		style = palette.disabled
	elseif b.selected then
		style = palette.selected
	elseif b._pushed then
		style = palette.pushed
	elseif b._hovered then
		style = palette.hover
	else
		style = palette.normal
	end
	if b._setSkin then
		b._setSkin(0, 0, 0, 0, style.bg[1], style.bg[2], style.bg[3], style.bg[4])
	end
	local fs = b:GetFontString()
	if fs then
		fs:SetTextColor(style.text[1], style.text[2], style.text[3])
	end
	if b.icon then
		b.icon:SetVertexColor(style.text[1], style.text[2], style.text[3])
	end
end

function M.MakeFlatButton(parent, w, h, text, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(w, h)
	b._setSkin = M.MakeFlatSkin(b, 1)
	local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	fs:SetPoint("CENTER", 0, 0)
	fs:SetText(text)
	b:SetFontString(fs)
	b._hovered, b._pushed = false, false
	b:SetScript("OnEnter", function(self)
		self._hovered = true
		M.ApplyFlatButtonVisual(self)
	end)
	b:SetScript("OnLeave", function(self)
		self._hovered = false
		self._pushed = false
		M.ApplyFlatButtonVisual(self)
	end)
	b:SetScript("OnMouseDown", function(self)
		self._pushed = true
		M.ApplyFlatButtonVisual(self)
	end)
	b:SetScript("OnMouseUp", function(self)
		self._pushed = false
		M.ApplyFlatButtonVisual(self)
	end)
	b:SetScript("OnEnable", function(self)
		M.ApplyFlatButtonVisual(self)
	end)
	b:SetScript("OnDisable", function(self)
		M.ApplyFlatButtonVisual(self)
	end)
	if onClick then
		b:SetScript("OnClick", onClick)
	end
	M.ApplyFlatButtonVisual(b)
	return b
end

-- 危险操作按钮（删除类）：深红底 + 亮红字
function M.MakeFlatDangerButton(parent, w, h, text, onClick)
	local b = M.MakeFlatButton(parent, w, h, text, onClick)
	b.danger = true
	M.ApplyFlatButtonVisual(b)
	return b
end

-- 给扁平按钮挂一个图标（无文字），原图按整数倍缩放居中显示
function M.SetButtonIcon(b, texPath, iconSize)
	local tex = b.icon
	if not tex then
		tex = b:CreateTexture(nil, "ARTWORK")
		b.icon = tex
	end
	tex:SetSize(iconSize, iconSize)
	tex:ClearAllPoints()
	tex:SetPoint("CENTER")
	tex:SetTexture(texPath)
	local fs = b:GetFontString()
	if fs then
		fs:SetText("")
	end
	M.ApplyFlatButtonVisual(b)
	return tex
end

function M.MakeCloseButton(parent)
	local btn = CreateFrame("Button", nil, parent)
	btn:SetSize(18, 18)
	local function bar(rot)
		local t = btn:CreateTexture(nil, "ARTWORK")
		t:SetSize(13, 2)
		t:SetPoint("CENTER")
		t:SetRotation(rot)
		t:SetColorTexture(0.62, 0.63, 0.66, 1)
		return t
	end
	local a = bar(math.rad(45))
	local b = bar(math.rad(-45))
	local function paint(r, g, bl, al)
		a:SetColorTexture(r, g, bl, al)
		b:SetColorTexture(r, g, bl, al)
	end
	btn:SetScript("OnEnter", function()
		paint(1, 0.40, 0.40, 1)
	end)
	btn:SetScript("OnLeave", function()
		paint(0.62, 0.63, 0.66, 1)
	end)
	return btn
end

function M.MakeFlatCheckbox(parent, text, onClick)
	local cb = CreateFrame("CheckButton", nil, parent)
	cb:SetSize(18, 18)
	local setSkin = M.MakeFlatSkin(cb, 1)
	setSkin(0, 0, 0, 0, 0.08, 0.09, 0.11, 0.95)
	local check = cb:CreateTexture(nil, "OVERLAY")
	check:SetPoint("CENTER", 0, 0)
	check:SetSize(10, 10)
	check:SetColorTexture(1, 0.82, 0.20, 1)
	cb:SetCheckedTexture(check)
	local hover = cb:CreateTexture(nil, "HIGHLIGHT")
	hover:SetAllPoints()
	hover:SetColorTexture(1, 1, 1, 0.08)
	cb:SetHighlightTexture(hover, "ADD")
	local fs = cb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	fs:SetPoint("LEFT", cb, "RIGHT", 6, 0)
	fs:SetJustifyH("LEFT")
	fs:SetText(text)
	cb.Text = fs
	cb:SetScript("OnEnter", function()
		hover:SetColorTexture(1, 1, 1, 0.14)
	end)
	cb:SetScript("OnLeave", function()
		hover:SetColorTexture(1, 1, 1, 0.08)
	end)
	if onClick then
		cb:SetScript("OnClick", onClick)
	end
	return cb
end

-- 列表行工厂：新列表一律用它，禁止手搓行
-- 返回 row：row.icon / row.name / row.sub / row.state
-- row:SetSelected(on) 金色调 + 2px 金色左强调条；row:SetStripe(on)
M.LIST_ROW_HEIGHT = 40
function M.MakeListRow(parent, opts)
	opts = opts or {}
	local row = CreateFrame("Button", nil, parent)
	row:SetHeight(opts.height or M.LIST_ROW_HEIGHT)

	local stripe = row:CreateTexture(nil, "BACKGROUND", nil, -6)
	stripe:SetAllPoints()
	stripe:SetColorTexture(1, 1, 1, 0.03)
	stripe:SetShown(opts.stripe and true or false)
	row.stripe = stripe

	local hl = row:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints()
	hl:SetColorTexture(1, 1, 1, 0.05)

	local sel = row:CreateTexture(nil, "BACKGROUND", nil, -4)
	sel:SetAllPoints()
	sel:SetColorTexture(1, 0.82, 0.2, 0.10)
	sel:Hide()

	local selBar = row:CreateTexture(nil, "BACKGROUND", nil, -3)
	selBar:SetPoint("TOPLEFT", 0, 0)
	selBar:SetPoint("BOTTOMLEFT", 0, 0)
	selBar:SetWidth(2)
	selBar:SetColorTexture(1, 0.82, 0.2, 1)
	selBar:Hide()

	local icon = row:CreateTexture(nil, "ARTWORK")
	icon:SetSize(opts.iconSize or 22, opts.iconSize or 22)
	icon:SetPoint("LEFT", 8, 0)
	row.icon = icon

	local textLeft = opts.textLeft or ((opts.iconSize or 22) + 16)
	local name = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	name:SetPoint("TOPLEFT", row, "TOPLEFT", textLeft, -6)
	name:SetJustifyH("LEFT")
	row.name = name

	if not opts.singleLine then
		local sub = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
		sub:SetPoint("TOPLEFT", row, "TOPLEFT", textLeft, -22)
		sub:SetJustifyH("LEFT")
		sub:SetTextColor(0.6, 0.6, 0.6)
		row.sub = sub
	end

	row.state = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	row.state:SetPoint("RIGHT", row, "RIGHT", -6, 0)
	row.state:SetJustifyH("RIGHT")

	function row:SetSelected(on)
		sel:SetShown(on and true or false)
		selBar:SetShown(on and true or false)
	end

	function row:SetStripe(on)
		stripe:SetShown(on and true or false)
	end

	if opts.onClick then
		row:SetScript("OnClick", opts.onClick)
	end
	return row
end

-- 列表右侧状态图标（主选 / 已选），替代状态文字
function M.SetStateIcon(row, on, texPath, iconSize)
	local tex = row.stateIcon
	if not tex then
		if row.state then
			row.state:Hide()
		end
		tex = row:CreateTexture(nil, "ARTWORK")
		tex:SetSize(iconSize or 16, iconSize or 16)
		tex:SetPoint("RIGHT", row, "RIGHT", -8, 0)
		tex:SetTexture(texPath or "Interface\\CheckMark")
		tex:Hide()
		row.stateIcon = tex
	end
	tex:SetShown(on and true or false)
	return tex
end

function M.MakeSectionLabel(parent, text)
	local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	fs:SetText("|cffffd200" .. text .. "|r")
	fs:SetJustifyH("LEFT")
	return fs
end

-- 现代扁平滚动条：细轨道 + 无箭头可拖拽滑块 + 滚轮（自绘，不套 UIPanelScrollFrameTemplate）
local SCROLLBAR_WIDTH = 6
local SCROLLBAR_GUTTER = 10

function M.MakeModernScrollbar(scroll)
	if type(scroll) ~= "table" or type(scroll.GetVerticalScroll) ~= "function" then
		return nil
	end
	local bar = CreateFrame("Frame", nil, scroll)
	bar:SetPoint("TOPRIGHT", 0, 0)
	bar:SetPoint("BOTTOMRIGHT", 0, 0)
	bar:SetWidth(SCROLLBAR_WIDTH)
	bar.gutter = SCROLLBAR_GUTTER

	local track = bar:CreateTexture(nil, "BACKGROUND")
	track:SetColorTexture(0, 0, 0, 0.30)
	track:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
	track:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
	track:SetWidth(2)

	local thumb = CreateFrame("Frame", nil, bar)
	thumb:SetWidth(4)
	thumb:SetHeight(40)

	local thumbTex = thumb:CreateTexture(nil, "ARTWORK")
	thumbTex:SetAllPoints()
	thumbTex:SetColorTexture(0.75, 0.75, 0.80, 0.55)

	local function place()
		local offset = bar.offset or 0
		thumb:ClearAllPoints()
		thumb:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, -offset)
	end

	local function update()
		local child = scroll:GetScrollChild()
		local view = math.max(scroll:GetHeight() or 0, 1)
		local content = (child and child:GetHeight()) or 0
		if child then
			child:SetWidth(math.max((scroll:GetWidth() or 0) - SCROLLBAR_GUTTER, 40))
		end
		local maxScroll = math.max(content - view, 0)
		bar.maxScroll = maxScroll
		local value = scroll:GetVerticalScroll() or 0
		if value > maxScroll then
			value = maxScroll
			scroll:SetVerticalScroll(value)
		elseif value < 0 then
			value = 0
			scroll:SetVerticalScroll(value)
		end
		bar:Show()
		local trackH = math.max(bar:GetHeight() or 0, 1)
		thumb:SetShown(maxScroll > 0 and content > 0)
		if maxScroll <= 0 or content <= 0 then
			bar.offset, bar.maxOffset = 0, 0
			return
		end
		local thumbH = math.min(math.max(math.floor(trackH * (view / content)), 24), trackH)
		thumb:SetHeight(thumbH)
		local maxOffset = math.max(trackH - thumbH, 0)
		local offset = 0
		if maxOffset > 0 then
			offset = (value / maxScroll) * maxOffset
		end
		bar.offset, bar.maxOffset = offset, maxOffset
		place()
	end

	thumb:SetScript("OnEnter", function()
		thumbTex:SetColorTexture(0.95, 0.95, 1, 0.90)
	end)
	thumb:SetScript("OnLeave", function()
		if not thumb.dragging then
			thumbTex:SetColorTexture(0.75, 0.75, 0.80, 0.55)
		end
	end)
	thumb:RegisterForDrag("LeftButton")
	thumb:SetScript("OnDragStart", function(self)
		self.dragging = true
		local startY = GetCursorPosition()
		self:SetScript("OnUpdate", function(self)
			local _, cy = GetCursorPosition()
			local scale = bar:GetEffectiveScale() or 1
			local delta = (startY - cy) / scale
			startY = GetCursorPosition()
			update()
			local maxOffset = bar.maxOffset or 0
			local maxScroll = bar.maxScroll or 0
			if maxOffset > 0 and maxScroll > 0 then
				local offset = math.max(0, math.min((bar.offset or 0) + delta, maxOffset))
				scroll:SetVerticalScroll((offset / maxOffset) * maxScroll)
			end
			update()
		end)
	end)
	thumb:SetScript("OnDragStop", function(self)
		self.dragging = false
		self:SetScript("OnUpdate", nil)
		thumbTex:SetColorTexture(0.75, 0.75, 0.80, 0.55)
		update()
	end)

	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		update()
		local maxScroll = bar.maxScroll or 0
		local step = math.max(math.floor((scroll:GetHeight() or 0) * 0.2), 24)
		local value = math.max(0, math.min((self:GetVerticalScroll() or 0) - delta * step, maxScroll))
		self:SetVerticalScroll(value)
		update()
	end)
	pcall(scroll.HookScript, scroll, "OnSizeChanged", update)

	update()
	return {
		frame = bar,
		Update = update,
	}
end

-- ------------------------------------------------------------------ 设置界面

local GUI_WIDTH = 470
local GUI_HEIGHT = 544
local CONFIG_STRATA = "FULLSCREEN_DIALOG"
local CONFIG_LEVEL = 9000
local CONFIG_LEVEL_MAX = 9999
local configRaiseStep = 0

function M:RaiseConfigFrame()
	local f = self.configFrame
	if not f then
		return
	end
	configRaiseStep = configRaiseStep + 1
	local base = CONFIG_LEVEL + configRaiseStep
	if base > CONFIG_LEVEL_MAX then
		configRaiseStep = 0
		base = CONFIG_LEVEL
	end
	f:SetFrameLevel(base)
	if f.content then
		f.content:SetFrameLevel(base + 1)
	end
	for _, tab in pairs(f.tabs or {}) do
		tab:SetFrameLevel(base + 3)
	end
end

function M:CreateConfigFrame()
	if self.configFrame then
		return self.configFrame
	end
	local f = CreateFrame("Frame", "MzxSpecBarConfigFrame", UIParent, "BackdropTemplate")
	f:SetSize(GUI_WIDTH, GUI_HEIGHT)
	f:SetPoint("CENTER")
	f:SetFrameStrata(CONFIG_STRATA)
	f:SetFrameLevel(CONFIG_LEVEL)
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", function()
		f:StopMovingOrSizing()
		M:RaiseConfigFrame()
		M.SnapToPixelGrid(f)
	end)
	f:SetScript("OnMouseDown", function()
		M:RaiseConfigFrame()
	end)
	f:SetScript("OnShow", function()
		if f.title then
			f.title:SetText(L["MzxSpecBar Settings"])
		end
		M:RaiseConfigFrame()
		M.SnapToPixelGrid(f)
	end)
	f:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		edgeSize = 1,
	})
	f:SetBackdropColor(0.05, 0.06, 0.07, 0.94)
	f:SetBackdropBorderColor(0.28, 0.30, 0.35, 1)
	f:Hide()

	local header = f:CreateTexture(nil, "BACKGROUND")
	header:SetPoint("TOPLEFT", 1, -1)
	header:SetPoint("TOPRIGHT", -1, -1)
	header:SetHeight(26)
	header:SetColorTexture(0.11, 0.12, 0.14, 0.92)

	local headerLine = f:CreateTexture(nil, "ARTWORK")
	headerLine:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
	headerLine:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, 0)
	headerLine:SetHeight(1)
	headerLine:SetColorTexture(1.0, 0.82, 0.20, 0.45)

	local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("LEFT", header, "LEFT", 12, 0)
	title:SetText(L["MzxSpecBar Settings"])
	f.title = title

	local close = M.MakeCloseButton(f)
	close:SetPoint("TOPRIGHT", -6, -6)
	close:SetScript("OnClick", function()
		f:Hide()
	end)
	pcall(tinsert, UISpecialFrames, "MzxSpecBarConfigFrame")

	f.tabs = {}
	local prev
	local n = #self.moduleList
	local gap = 4
	local avail = (f:GetWidth() or GUI_WIDTH) - 24
	local tabW = math.max(math.floor((avail - gap * (n - 1)) / math.max(n, 1)), 40)
	local lastTabWidth = tabW
	for i, mod in ipairs(self.moduleList) do
		local b = M.MakeFlatButton(f, tabW, 24, mod.name or mod.key, nil)
		b.selected = false
		b:SetFrameLevel(f:GetFrameLevel() + 3)
		local key = mod.key
		b:SetScript("OnClick", function()
			M:SelectTab(key)
		end)
		if i == 1 then
			b:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -36)
		else
			b:SetPoint("LEFT", prev, "RIGHT", gap, 0)
		end
		prev = b
		f.tabs[key] = b
	end
	f:SetScript("OnSizeChanged", function(self, w)
		if not w or w <= 0 then
			return
		end
		local count = math.max(#self.moduleList, 1)
		local inner = math.floor((w - 24 - 4 * (count - 1)) / count)
		if inner < 40 then
			inner = 40
		end
		if inner == lastTabWidth then
			return
		end
		lastTabWidth = inner
		for _, b in pairs(self.tabs) do
			b:SetWidth(inner)
		end
	end)
	f.lastTabWidth = lastTabWidth

	f.content = CreateFrame("Frame", nil, f)
	f.content:SetFrameLevel(f:GetFrameLevel() + 1)
	f.content:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -72)
	f.content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 14)

	self.configFrame = f
	return f
end

function M:GetModulePanel(mod)
	if mod.optionsFrame then
		return mod.optionsFrame
	end
	local f = self.configFrame
	local p = CreateFrame("Frame", nil, f.content)
	p:SetAllPoints(f.content)
	if not mod.alwaysOn then
		local cb = M.MakeFlatCheckbox(p, L["Enable this module"], function(cbSelf)
			self:SetModuleEnabled(mod.key, cbSelf:GetChecked())
		end)
		cb:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -2)
		cb:SetChecked(self:IsModuleEnabled(mod.key))
		p.enable = cb
	end
	mod.optionsFrame = p
	if mod.BuildOptions then
		local ok, err = pcall(mod.BuildOptions, mod, p)
		if not ok then
			Print(string.format(L["Module %s options error: %s"], mod.key, tostring(err)))
		end
	end
	if mod.RefreshOptions then
		pcall(mod.RefreshOptions, mod)
	end
	return p
end

function M:SelectTab(key)
	local f = self.configFrame
	if not f then
		return
	end
	for _, mod in ipairs(self.moduleList) do
		local selected = (mod.key == key)
		local p = self:GetModulePanel(mod)
		p:SetShown(selected)
		local tab = f.tabs[mod.key]
		if tab then
			tab.selected = selected
			M.ApplyFlatButtonVisual(tab)
		end
		if selected and mod.RefreshOptions then
			pcall(mod.RefreshOptions, mod)
		end
	end
end

function M:RefreshConfig()
	local f = self.configFrame
	if not f or not f:IsShown() then
		return
	end
	for _, mod in ipairs(self.moduleList) do
		local p = mod.optionsFrame
		if p and p:IsShown() then
			if p.enable then
				p.enable:SetChecked(self:IsModuleEnabled(mod.key))
			end
			if mod.RefreshOptions then
				pcall(mod.RefreshOptions, mod)
			end
		end
	end
end

function M:RefreshConfigIfOpen()
	self:RefreshConfig()
end

function M:OpenConfig()
	if not self.db then
		self:InitDB()
	end
	local f = self:CreateConfigFrame()
	f:Show()
	local first = self.moduleList[1]
	if first then
		self:SelectTab(first.key)
	else
		self:RefreshConfig()
	end
	return f
end

function M:ToggleConfig()
	if not self.db then
		self:InitDB()
	end
	if self._minimapContextHide then
		self._minimapContextHide()
	end
	if self.configFrame and self.configFrame:IsShown() then
		self.configFrame:Hide()
		return
	end
	self:OpenConfig()
end

-- ------------------------------------------------------------------ 小地图按钮

-- 模块可注册小地图右键处理器（快速专精列表）
function M:SetMinimapContextHandler(fn, hideFn)
	self._minimapContext = fn
	self._minimapContextHide = hideFn
end

local MINIMAP_ICON = "Interface\\AddOns\\MzxSpecBar\\Textures\\icon.tga"
local MINIMAP_BUTTON_SIZE = 31
local MINIMAP_DEFAULT_POS = 135

local MINIMAP_RADIUS = 5

local MINIMAP_SHAPES = {
	["ROUND"] = { true, true, true, true },
	["SQUARE"] = { false, false, false, false },
	["CORNER-TOPLEFT"] = { false, false, false, true },
	["CORNER-TOPRIGHT"] = { false, false, true, false },
	["CORNER-BOTTOMLEFT"] = { false, true, false, false },
	["CORNER-BOTTOMRIGHT"] = { true, false, false, false },
	["SIDE-LEFT"] = { false, true, false, true },
	["SIDE-RIGHT"] = { true, false, true, false },
	["SIDE-TOP"] = { false, false, true, true },
	["SIDE-BOTTOM"] = { true, true, false, false },
	["TRICORNER-TOPLEFT"] = { false, true, true, true },
	["TRICORNER-TOPRIGHT"] = { true, false, true, true },
	["TRICORNER-BOTTOMLEFT"] = { true, true, false, true },
	["TRICORNER-BOTTOMRIGHT"] = { true, true, true, false },
}

local function MinimapShape()
	if type(GetMinimapShape) == "function" then
		local ok, value = pcall(GetMinimapShape)
		if ok and value then
			return value
		end
	end
	if type(GetCVar) == "function" then
		local ok, value = pcall(GetCVar, "minimapShape")
		if ok and value then
			return value
		end
	end
	return "ROUND"
end

function M:UpdateMinimapButtonPosition(position)
	local b = self.minimapButton
	if not b then
		return
	end
	local angle = math.rad(position or MINIMAP_DEFAULT_POS)
	local x, y, q = math.cos(angle), math.sin(angle), 1
	if x < 0 then
		q = q + 1
	end
	if y > 0 then
		q = q + 2
	end
	local quads = MINIMAP_SHAPES[MinimapShape()] or MINIMAP_SHAPES["ROUND"]
	local w = (Minimap:GetWidth() / 2) + MINIMAP_RADIUS
	local h = (Minimap:GetHeight() / 2) + MINIMAP_RADIUS
	if quads[q] then
		x, y = x * w, y * h
	else
		local dw = math.sqrt(2 * w * w) - 10
		local dh = math.sqrt(2 * h * h) - 10
		x = math.max(-w, math.min(x * dw, w))
		y = math.max(-h, math.min(y * dh, h))
	end
	b:ClearAllPoints()
	b:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function M:PlaceMinimapButton()
	local db = self.db or EnsureDB()
	if type(db.minimapPos) ~= "number" then
		db.minimapPos = MINIMAP_DEFAULT_POS
	end
	self:UpdateMinimapButtonPosition(db.minimapPos)
end

function M:CreateMinimapButton()
	local b = CreateFrame("Button", "MzxSpecBarMinimapButton", Minimap)
	b:SetSize(MINIMAP_BUTTON_SIZE, MINIMAP_BUTTON_SIZE)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:RegisterForDrag("LeftButton")
	b:SetFrameStrata("MEDIUM")
	b:SetFrameLevel(8)

	local border = b:CreateTexture(nil, "OVERLAY")
	border:SetTexture(136430)
	border:SetSize(50, 50)
	border:SetPoint("TOPLEFT", 0, 0)
	b.border = border

	local background = b:CreateTexture(nil, "BACKGROUND")
	background:SetColorTexture(0.05, 0.06, 0.08, 0.97)
	background:SetSize(12, 12)
	background:SetPoint("CENTER", 0, 0)
	b.background = background

	local icon = b:CreateTexture(nil, "ARTWORK")
	icon:SetSize(18, 18)
	icon:SetPoint("CENTER", 0, 0)
	icon:SetTexture(MINIMAP_ICON)
	b.icon = icon

	b:SetHighlightTexture(136477)

	b:SetScript("OnEnter", function()
		GameTooltip:SetOwner(b, "ANCHOR_NONE")
		GameTooltip:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -4)
		GameTooltip:SetText(L["MzxSpecBar Settings"], 1, 1, 1)
		GameTooltip:AddLine(L["Left-click to open/close settings"], 0.8, 0.8, 0.8)
		GameTooltip:AddLine(L["Right-click for the quick list"], 0.8, 0.8, 0.8)
		GameTooltip:AddLine(L["Drag to move the button"], 0.6, 0.6, 0.6)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	b:SetScript("OnClick", function(_, button)
		if button == "RightButton" then
			if M._minimapContext then
				M._minimapContext()
			end
		else
			M:ToggleConfig()
		end
	end)
	b:SetScript("OnDragStart", function(self)
		self:LockHighlight()
		GameTooltip:Hide()
		local function onUpdate()
			local mx, my = Minimap:GetCenter()
			local px, py = GetCursorPosition()
			local scale = Minimap:GetEffectiveScale() or 1
			px, py = px / scale, py / scale
			local pos = math.deg(math.atan2(py - my, px - mx)) % 360
			if M.db then
				M.db.minimapPos = pos
			end
			M:UpdateMinimapButtonPosition(pos)
		end
		b:SetScript("OnUpdate", onUpdate)
	end)
	b:SetScript("OnDragStop", function(self)
		b:SetScript("OnUpdate", nil)
		self:UnlockHighlight()
		M:PlaceMinimapButton()
	end)

	self.minimapButton = b
	self:PlaceMinimapButton()
	return b
end

-- ------------------------------------------------------------------ 斜杠命令

function M:Slash(input)
	local cmd, rest = input:match("^(%S*)%s*(.-)$")
	cmd = (cmd or ""):lower()
	if cmd == "" then
		self:ToggleConfig()
		return
	end
	if cmd == "help" then
		Print(L["Commands:"])
		Print(L["  /msb                Open settings"])
		Print(L["  /msb list           List modules and their state"])
		Print(L["  /msb on <module>    Enable a module"])
		Print(L["  /msb off <module>   Disable a module"])
		local names = {}
		for _, mod in ipairs(self.moduleList) do
			names[#names + 1] = mod.key
		end
		Print(string.format(L["  Modules: %s"], table.concat(names, ", ")))
		return
	end
	if cmd == "list" then
		for _, mod in ipairs(self.moduleList) do
			local state = self:IsModuleEnabled(mod.key) and L["enabled"] or L["disabled"]
			Print(string.format(L["%s (%s): %s"], mod.key, mod.name or "", state))
		end
		return
	end
	local on
	if cmd == "on" then
		on = true
	elseif cmd == "off" then
		on = false
	else
		return
	end
	cmd = string.lower((rest:gsub("%s+$", "")))
	if self.modules[cmd] then
		self:SetModuleEnabled(cmd, on)
		Print(string.format(L["%s is now %s"], cmd, on and L["enabled"] or L["disabled"]))
	end
end

SLASH_MZXSPECBAR1 = "/msb"
SLASH_MZXSPECBAR2 = "/mzxspecbar"
SlashCmdList["MZXSPECBAR"] = function(input)
	M:Slash(input or "")
end