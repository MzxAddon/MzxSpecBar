-- 模块：动作条（业务实现入口）
-- 目标：按当前职业 + 专精，把技能按固定顺序放回玩家动作条，避免默认 UI 打乱。
-- 约定（详见 AGENTS.md「动作条模块契约」）：
--   mod.key / nameKey / defaultEnabled
--   mod:EnsureDB(db, charDb)   账号级放 db，角色级（职业/专精/动作条方案）放 charDb
--   mod:OnToggle(on)           启用/禁用时创建与清理资源
--   mod:BuildOptions(p)        构建设置面板；p 是模块面板（已带「启用本模块」勾选框）
--   mod:RefreshOptions()       切标签 / 打开设置窗时刷新
--   mod:OnEvent(event, ...)    经 M:RegisterModuleEvent 注册的事件转发到这里
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

function mod:EnsureDB(db, charDb)
	local s = db.actionbars
	if type(s) ~= "table" then
		s = {}
		db.actionbars = s
	end
	self.db = s
	self.charDb = charDb
end

function mod:OnToggle(on)
end

function mod:BuildOptions(p)
	local hint = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	hint:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -34)
	hint:SetWidth((p:GetWidth() or 444) - 24)
	hint:SetJustifyH("LEFT")
	hint:SetNonSpaceWrap(true)
	hint:SetText(L["Auto arrange"])
end

function mod:RefreshOptions()
end