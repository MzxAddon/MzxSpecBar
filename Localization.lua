-- MzxSpecBar 本地化 / Localization
-- 根据客户端语言（GetLocale）加载对应文本；英文为基准，其他语言只覆盖自身。
-- 用法：其他文件 `local L = ns.L`，再 `L["English string"]` 取当前语言文本。
-- 未翻译的键会回退为英文键文本（永不返回 nil）。
local ADDON, ns = ...

local L = {}
ns.L = L

-- 英文基准（同时也是所有缺失翻译的兜底）。键 = 值，故只列一次
local en = {
	-- 通用 / 配置窗
	"MzxSpecBar Settings",
	"Enable this module",
	"Module %s error: %s",
	"Module %s options error: %s",
	"Left-click to open/close settings",
	"Drag to move the button",
	-- 斜杠命令
	"Commands:",
	"  /msb                Open settings",
	"  /msb list           List modules and their state",
	"  /msb on <module>    Enable a module",
	"  /msb off <module>   Disable a module",
	"  Modules: %s",
	"%s (%s): %s",
	"%s is now %s",
	"enabled",
	"disabled",
	-- 动作条模块
	"ActionBars",
	"Auto arrange",
	"Specialization",
	"Save current specialization",
	"Apply current specialization",
	"Apply automatically",
	"Delete saved data",
	"Level %d is below the minimum (10)",
	"Saved %d slots",
	"Macro slots are restored by name; missing character macros are recreated",
	"Applied %d slots",
	"Applied %d pet actions",
	"Created %d macros",
	"Nothing saved for this class yet",
	"Nothing saved for this specialization",
	"Nothing to apply: no saved spell, item or macro is available on this character",
	"Nothing was applied - check the saved layouts list",
	"Skipped %d slots: macro, set or pet action not saved",
	"Skipped %d slots: item info not cached",
	"Skipped %d slots: spell, item or macro not placed",
	"Skipped %d slots: spell not available on this character",
	"and %d more",
	"Current: %s",
	"Saved",
	"Not saved",
	"Switch to that specialization first",
	"Action bars cannot be changed in combat",
	"Saved layouts",
	"Hero talent",
	-- 语言
	"Language",
	"Client default",
	"zhCN",
	"zhTW",
	"enUS",
	"enGB",
	"koKR",
	"deDE",
	"frFR",
	"esES",
	"esMX",
	"ruRU",
	"ptBR",
	"itIT",
}
for i = 1, #en do
	L[en[i]] = en[i]
end
ns.enKeys = en

-- 语言代码白名单（DB 清洗与语言页都以此为准）
ns.knownLocales = {
	zhCN = true,
	zhTW = true,
	enUS = true,
	enGB = true,
	koKR = true,
	deDE = true,
	frFR = true,
	esES = true,
	esMX = true,
	ruRU = true,
	ptBR = true,
	itIT = true,
}

ns.localeData = {}

function ns.RegisterLocale(code, data)
	ns.localeData[code] = data
end

-- 应用语言：先全量重置为英文基准，再套用指定语言
function ns.ApplyLocale(code)
	for i = 1, #en do
		L[en[i]] = en[i]
	end
	local data = code and ns.localeData[code]
	if data then
		for k, v in pairs(data) do
			L[k] = v
		end
	end
	ns.activeLocale = code
end