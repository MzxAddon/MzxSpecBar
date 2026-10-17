## MzxSpecBar — 项目说明与规范

### 项目状态
- World of Warcraft *retail*（Midnight，Interface 120105）插件 `MzxSpecBar`。功能：按**职业 + 专精**把技能以固定顺序放回玩家动作条，避免默认 UI 打乱。**独立项目**（独立目录 / 独立仓库），**与 MzxRiding 零共享**：不共用任何 Lua 文件、词库、UI 封装；同类封装各自在本插件内实现一份。
- **只面向 retail**。不做其它客户端（周年服/Vanilla/Classic 等）移植或兼容，不加多 flavor TOC、不做能力探测。
- **主项目内禁止测试代码 / 探针 / 诊断代码**。此类代码必须单独立项、放在本项目外部（独立文件夹或独立仓库），且对本项目零影响：不改动本项目任何文件。
- **不做未在真实客户端验证过的改动**；不得声称"零错误""零影响"。正式服改动必须在正式服实机验证。
- 文件夹：`D:\Program Files\World of Warcraft\_retail_\Interface\AddOns\MzxSpecBar\`
- TOC：`MzxSpecBar.toc`（Interface 120105，版本 1.0.0，`SavedVariables: MzxSpecBarDB` + `SavedVariablesPerCharacter: MzxSpecBarCharDB`，斜杠 `/msb`、`/mzxspecbar`）
- 加载顺序（按 TOC）：`Localization.lua` → `Locales\*.lua`（zhCN/zhTW）→ `Core.lua` → `Modules\*.lua`
- 模块（默认开启）：`actionbars`（`key = "actionbars"`, `nameKey = "ActionBars"`），由 `Core.lua` 的 `M:RegisterModule(mod)` 管理，`M:IsModuleEnabled(key)` / `M:SetModuleEnabled(key, on)` 开关。
- 全局：`_G.MzxSpecBar = M` 的等价物是 `ns.M`（`Core.lua` 里 `ns.M = M`）。

### 边界与红线（用户明确要求）
- 本插件与 MzxRiding 是**两个独立插件**：绝不 import / 共用文件；想复用就各自复制一份到本插件内（约定：同类封装各自实现，绝不共用）。
- 主项目内不写测试代码、探针、诊断代码。
- 只支持 retail；不做移植、不加兼容层。

### 核心（Core.lua）
- `local ADDON, ns = ...`；`ns.M = M`；`ns.L = L`（来自 `Localization.lua` 的词库回退）。
- 模块注册表 `self.modules` 与有序列表 `self.moduleList`。`InitDB()` 为每个模块写 `db.modules[mod.key] = defaultEnabled`，并调用 `mod:EnsureDB(db, charDb)`。
- `M:RegisterModuleEvent(event)`：同一事件只向框架注册一次；`M:OnEvent` 遍历所有已启用模块转发。**业务事件一律走这里，不要各自 RegisterEvent**。
- `mod.alwaysOn = true`：无运行时开关的模块（如未来的语言页）不建「启用本模块」勾选框、`IsModuleEnabled` 恒真、不写 `db.modules`。
- 配置窗 `MzxSpecBarConfigFrame`：`FULLSCREEN_DIALOG` + `frame level = UIParent+20`（同 strata 时比 level，高于暴雪插件列表/设置面板、低于 TOOLTIP），`GUI_WIDTH = 470`、`GUI_HEIGHT = 480`，扁平皮肤 + 金色 headerLine + `MakeCloseButton`，并注册进 `UISpecialFrames`（ESC 关闭）。标签页按模块分，子面板 = 模块面板。
- 共享 UI 助手（**新 UI 一律复用这些，禁止手搓**）：
  - `M.MakeFlatSkin(frame, thickness)`、`M.SnapToPixelGrid(frame)`（`OnShow` + `OnDragStop` 处理半像素缺线）
  - `M.MakeFlatButton(parent, w, h, text, onClick)`、`M.SetButtonIcon(b, texPath, size)`（无文字图标按钮）
  - `M.MakeCloseButton`、`M.MakeFlatCheckbox`、`M.MakeSectionLabel`
  - **`M.MakeListRow(parent, opts)`**（`M.LIST_ROW_HEIGHT = 40`；opts: `height, iconSize=22, stripe, singleLine, onClick`；`row.icon/name/sub/state`；`row:SetSelected(on)` 金色调 + 2px 金色左强调条；`row:SetStripe(on)`）
  - `M.SetStateIcon(row, on, texPath, size)`：列表右侧状态图标，替代状态文字（首次调用会隐藏 `row.state`）
- 小地图按钮（`M:CreateMinimapButton`）：31×31，父级 `Minimap`，`MEDIUM`/level 8，可拖动（位置存 `db.minimapPos` 角度），左键开关设置窗，悬停显示提示。
- 斜杠：`/msb` 空参数开关设置窗；`help`、`list`、`on <key>`、`off <key>`。`M:Slash(input)` 处理。
- 事件转发需要框架本身注册事件：`M:RegisterModuleEvent("PLAYER_ENTERING_WORLD")` 之类。

### 动作条模块契约（Modules\ActionBars.lua）
业务实现只写这个模块，遵守：
- `mod:EnsureDB(db, charDb)`：**账号级**（通用开关、默认顺序模板等）放 `db`；**角色级**（职业、专精、每条动作条的方案与顺序）放 `charDb`。
- `mod:OnToggle(on)`：启用时创建资源、禁用时清理。
- `mod:BuildOptions(p)`：构建设置面板（`p` 已带「启用本模块」勾选框，锚在 `TOPLEFT 12,-2`，所以内容从 `-26` 以下开始）；面板元素用 `M.MakeListRow` / `M.MakeFlatButton`。
- `mod:RefreshOptions()`：切标签、开关窗口、数据变化时刷新；**不要在这里重建框架**。
- `mod:OnEvent(event, ...)`：经 `M:RegisterModuleEvent` 注册（登录、专精切换、载入配置等）。
- 施放/排列技能时的注意事项：战斗中 `InCombatLockdown()` 要跳过；`C_Spell.PickupSpell`（或 `PickupSpell` 回退）+ `C_ActionBar.PutActionInSlot`（或 `PlaceAction` 回退）；所有外部 API 调用用 pcall 包裹。**技能 id / 动作槽 id 不要硬编码猜测，必须实机核对后再写。**

### i18n / 本地化
- `Localization.lua`：英文基准词库 + `ns.RegisterLocale(code, data)` + `ns.ApplyLocale(code)`（全量重置英文再套指定语言）；`ns.knownLocales` 为白名单，用于 DB 清洗。
- `Locales\*.lua` 各自只覆盖不同键。**enUS/enGB 不单独提供文件**，直接用基准。
- 新增文案流程：先在 `Localization.lua` 加英文基准串 → 需要的话在 `Locales/zhCN.lua`（及 `zhTW`）加覆盖 → 代码里 `L["English string"]`。缺键自动回退英文，永不返回 nil。
- 提示行里的鼠标图标等内联图形统一由 `M.MouseIcon` 之类助手提供，**禁止各模块自己写内联纹理字符串或改尺寸**（若该插件后续引入）。

### 代码风格与约定
- **不要添加任何注释，除非用户明确要求**。
- 修改文件前先 `read`/`grep` 理解上下文，严格模仿现有代码风格、命名与模式。
- **新增列表一律使用 `M.MakeListRow`，禁止手搓行**。
- 外观统一（扁平风格、间距、锚定一致），不得破坏原有 UI、不得破坏功能。
- 所有外部 API 调用优先用现代 `C_*` API，必要时 `pcall` 包裹。
- 文档字符串/注释用英文或中文均可，但保持与现有文件一致；PowerShell 处理文件时避免 `Get-Content`/`Set-Content`（CJK 会二次编码），用 `[System.IO.File]::ReadAllText/WriteAllText(..., [System.Text.UTF8Encoding]::new($false))` 或专用编辑工具。

### 发布
- `.github/workflows/release.yml`：推 `v*` 标签或 `workflow_dispatch`（version / game_version / changelog / release_type）→ 校验 TOC `## Version` 与标签一致 → 打包（排除 `.git/`、`.github/`、`*.md`、`*.zip`、图标源 PNG）→ GitHub Release → CurseForge 上传。
- 版本号改动必须三处同步：`MzxSpecBar.toc` 的 `## Version`、`Core.lua` 的 `M.version`、本文件。
- CF 上传的已知坑（已在工作流里处理，改动时勿回退）：**metadata 必须用 `--form-string` 发送**（`-F` 会把值里的 `;` 当分段符导致 JSON 被截断，CF 报 `Invalid JSON`）；metadata 用 Python `json.dumps` 生成；上传失败要打印 HTTP 码 + 响应体并重试。

### 校验
- 语法检查：`node C:\Users\huang\AppData\Local\Temp\opencode\check.js <目录>`（Lua 5.1 解析器，逐文件输出 OK/FAIL）。修改后必须跑一遍。
- 修改后自查关键逻辑（锚定、事件注册、combat guard、专精切换时序），然后简短汇报结果。
- 路径含空格（`Program Files`、`World of Warcraft`），处理文件路径务必加双引号。

### 环境说明
- Windows / PowerShell 5.1；`rg`、`gh` 不可用；GitHub API 用 `git credential fill` 取 token + `Invoke-RestMethod`。
- 控制台 CJK 可能乱码，需审查中文文案时导出 UTF-8 文件再看。