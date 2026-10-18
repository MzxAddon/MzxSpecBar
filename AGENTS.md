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
- `M` 本身是 Frame（`CreateFrame("Frame")`），`SetScript("OnEvent")` 后才能 `RegisterEvent`。`PLAYER_LOGIN` 由核心注册：InitDB、套语言、ApplyModuleStates、小地图按钮。
- 模块注册表 `self.modules` 与有序列表 `self.moduleList`。`InitDB()` 为每个模块写 `db.modules[mod.key] = defaultEnabled`，并调用 `mod:EnsureDB(db, charDb)`。
- `M:RegisterModuleEvent(event)`：同一事件只向框架注册一次；`M:OnEvent` 遍历所有已启用模块转发。**业务事件一律走这里，不要各自 RegisterEvent**。
- `mod.alwaysOn = true`：无运行时开关的模块（如未来的语言页）不建「启用本模块」勾选框、`IsModuleEnabled` 恒真、不写 `db.modules`。
- 配置窗 `MzxSpecBarConfigFrame`：窗口尺寸与标题栏**必须与已完工的 MzxRiding 一致**（`GUI_WIDTH = 470`、`GUI_HEIGHT = 544`、header 高 26、header 色 `0.11/0.12/0.14/0.92`、金线 `1.0/0.82/0.20/0.45` 贴 header 下沿）——三个 Mzx 系列插件要长得一模一样，未完工的插件不许自己另立标准。
- 配置窗置于 `FULLSCREEN_DIALOG` + **固定 `CONFIG_LEVEL = 9000`**（不要用 `UIParent:GetFrameLevel() + 20`，那只有 ~20，压不过 HIGH/DIALOG strata 上自定义 level 的插件窗口），扁平皮肤 + 金色 headerLine + `MakeCloseButton`，注册进 `UISpecialFrames`（ESC 关闭）。置顶用 `M:RaiseConfigFrame()`（level 阶梯递增并同步刷新 content/tabs 的相对 level）——**`Frame:RaiseFrame()` 在 retail 不存在，调用即崩**，置顶只能靠 `SetFrameLevel`。
- **小地图按钮的定位与拖动必须照抄 MzxRiding 的算法**（`M:UpdateMinimapButtonPosition` + `M:PlaceMinimapButton`）：半径用 `Minimap:GetWidth()/2 + MINIMAP_RADIUS(5)`，按象限查 `MINIMAP_SHAPES`（ROUND/SQUARE/SIDE-*/TRICORNER-*），非 ROUND 象限用 `sqrt(2*w*w)-10` 沿对角线推到边上。拖动时**必须用 `GetCursorPosition()` 算角度**（除以 `Minimap:GetEffectiveScale()`），**绝不能用 `button:GetCenter()`**——拖动过程里按钮自身的锚点还是旧角度、根本没跟着鼠标走，用 `GetCenter` 算出来的角度永远不变，结果就是按钮拖不动。
- **图标资源与 Mzx 系列一致**：`Textures/icon.tga`（**128×128 / 32 位 / imageType 2 / descriptor 0x28 顶左原点**，与 MzxRiding 的 icon.tga 同规格，游戏内用）+ `Textures/icon.png`（256×256 源图，网页/CurseForge 用）。内容与项目一致：黑圆底 + 金色「按顺序排好的动作条」+ 白色点缀。TOC 写 `## Icon: Interface\AddOns\MzxSpecBar\Textures\icon.tga`；小地图按钮的 `MINIMAP_ICON` 直接指向该 TGA（圆底已烘进图里，只需保留 12×12 纯色兜底）。专精图标仍用 `GetSpecializationInfoByID` 返回的 FileID，不要替换成自己的图。
- 小地图按钮必须照抄 MzxRiding / LibDBIcon 的标准写法，不搞个性化（那套是实机验证过的）：`border` 用 **FileID `136430`**（MiniMap-TrackingBorder，OVERLAY 层）且 **`SetSize(50, 50)` + `SetPoint("TOPLEFT", 0, 0)`**——贴图必须画到 50px 才能让圆环对上 31px 按钮，按 31px 画会被裁成方块；纯色兜底**只放 12×12 居中**（`SetAllPoints` 铺满会露出方框）；悬停一律 `b:SetHighlightTexture(136477)` 走标准圆形光晕，**不要换贴图、不要靠 SetVertexColor 造效果**。
- **任何子控件都不得越出窗口边界**（越界就会压到别的插件上，是禁忌）：标签页宽度按 `f:GetWidth()` 算而不是常量 `GUI_WIDTH`，并挂 `OnSizeChanged` 实时重算；滚动列表裁剪用 `pcall(scroll.SetClippingEnabled, scroll, true)`（`SetClippingEnabled` 不是通用 Frame 方法，不能裸调）。
- **面板元素纵向排布必须留足间距、任何元素不得越界压到别的元素上**：警告文字固定占底部 66px 条带（滚动区 `BOTTOMRIGHT -18, 66` 让开），条带内最多 3 行去重后的提示（`WARN_MAX_LINES`，超出显示「…另有 N 条提示」），字体串限宽 + `SetNonSpaceWrap(true)` 不允许横向溢出——早期版本警告字体串锚 `BOTTOMLEFT` 无上限生长，直接盖住整个面板，是要避免的重犯错误。
- 共享 UI 助手（**新 UI 一律复用这些，禁止手搓**）：
  - `M.MakeFlatSkin(frame, thickness)`、`M.SnapToPixelGrid(frame)`（`OnShow` + `OnDragStop` 处理半像素缺线）
  - `M.MakeFlatButton(parent, w, h, text, onClick)`、`M.SetButtonIcon(b, texPath, size)`（无文字图标按钮）
  - `M.MakeCloseButton`、`M.MakeFlatCheckbox`、`M.MakeSectionLabel`
  - ⚠️ **`CheckButton` 在 retail 只有 `GetChecked` / `SetChecked`，没有 `IsChecked`**（写 `cb:IsChecked()` 会 `attempt to call a nil value` 崩掉整个面板）。勾选状态由控件**自己翻转**，在 `OnClick` 里直接读 `GetChecked()` 就是新值，**绝对不要自己再 `SetChecked(not GetChecked())`**（双重翻转＝彻底点不动）。
  - ⚠️ **新建勾选框必须立刻从 DB 初始化状态**（`M:GetModulePanel` 里 `p.enable` 那行 `cb:SetChecked(self:IsModuleEnabled(mod.key))`）；`defaultEnabled = true` 的模块漏了这行，就会出现「打开显示未勾选 → 点了写入 true（本来就是 true，等于没变）→ 重载又显示未勾选」的假象，看着就像"没保存"。
  - **`M.MakeListRow(parent, opts)`**（`M.LIST_ROW_HEIGHT = 40`；opts: `height, iconSize=22, stripe, singleLine, onClick`；`row.icon/name/sub/state`；`row:SetSelected(on)` 金色调 + 2px 金色左强调条；`row:SetStripe(on)`）
  - `M.SetStateIcon(row, on, texPath, size)`：列表右侧状态图标，替代状态文字（首次调用会隐藏 `row.state`）
- 小地图按钮（`M:CreateMinimapButton`）：31×31，父级 `Minimap`，`MEDIUM`/level 8，可拖动（拖动时用 `OnUpdate` 贴边，位置存 `db.minimapPos` 角度），左键开关设置窗，悬停显示提示。
- 斜杠：`/msb` 空参数开关设置窗；`help`、`list`、`on <key>`、`off <key>`。`M:Slash(input)` 处理。
- 事件转发需要框架本身注册事件：`M:RegisterModuleEvent("PLAYER_ENTERING_WORLD")` 之类。

### 动作条模块契约（Modules\ActionBars.lua）
业务实现只写这个模块，遵守：
- `mod:EnsureDB(db, charDb)`：**账号级**（按职业共享的动作条方案 `db.actionbars.profiles`）放 `db`；**角色级**只放 `charDb.actionbars.autoApply`（布尔、正向语义：该角色参与登录自动应用，默认 `true`）。旧的 `db.actionbars.autoApply` / `charDb.actionbars.skipAutoApply` 在此处一次性迁移后清除。
- `mod:OnToggle(on)`：启用时创建资源、禁用时清理。
- `mod:BuildOptions(p)`：构建设置面板（`p` 已带「启用本模块」勾选框，锚在 `TOPLEFT 12,-2`，所以内容从 `-26` 以下开始）；面板元素用 `M.MakeListRow` / `M.MakeFlatButton`。
- `mod:RefreshOptions()`：切标签、开关窗口、数据变化时刷新；**不要在这里重建框架**。
- `mod:OnEvent(event, ...)`：经 `M:RegisterModuleEvent` 注册。**只注册 `PLAYER_ENTERING_WORLD`**，自动应用只处理本会话第一次。
- 已实现的保存/恢复（`Modules\ActionBars.lua`）：存**账号级** `db.actionbars.profiles[classFile][specID][heroSubTreeID] = { savedAt, bars }`，同职业角色共享。`bars` 含 `slots`（动作槽 1–180，覆盖主条/额外条/形态分页）和 `pet`（宠物技能 1–10）。槽位 `{ t="spell"|"item"|"pet", id, sub }`。空槽不写键，恢复时先清空再放置。
- 维度规则：等级 <10 直接不参与（保存时提示退出）；10-70 级 hero 键为 0；≥71 级用当前英雄天赋树 ID（`C_ClassTalents.GetActiveHeroTalentSpec()`）。
- **保存 = 一次性同步快照当前专精 + 当前英雄树，没有「保存所有专精」，不切专精、不碰天赋、不用任何 `C_Timer` 轮询**（`mod:StartSave()` 单函数跑完）。曾经的跨专精/跨天赋保存链因为天赋配置切换无法可靠判定完成而反复切换天赋，已整体删除，相关 API（`SetSpecialization`/`C_ClassTalents.LoadConfig`/`GetConfigIDsBySpecID`/`GetHeroTalentSpecsForClassSpec`/`TRAIT_CONFIG_UPDATED`）**一律不要再引入**；需要存别的专精就让玩家手动切过去再点保存。
- 因此模块里**没有 `mod.busy` 状态**（保存和应用都是同步的，不会重入）。
- **宏按名字保存与恢复**（Retail 无 `CreateMacro`/`EditMacro`，不创建宏）：快照存 `{t="macro", id=索引, name=宏名}`（`GetMacroInfo(id)` 取名，取不到名才跳过计数）；恢复时索引仍指向同名宏则按索引 `PickupMacro`，否则按名字 `PickupMacro`（通用宏全账号存在可跨角色恢复，角色宏仅本角色存在，找不到就跳过并如实计数）。预检把「按名能找到」的宏算作可用；`equipmentset`/`equipmacro` 仍跳过计数。已核对 wiki（12.1.5）：`PickupMacro(number|string)` 为 `#nocombat` 限制 API、`GetMacroInfo(index|name)`、`GetNumMacros() → global, perChar`；**不要硬编码 1/120/121 宏索引范围**，一律走索引快路径 + 按名回退。物品/技能若本角色不可用也计数（`C_Item.GetItemInfo` / `C_Spell.GetSpellInfo` 返回 nil）。恢复一律覆盖、不备份。
- 面板只有两个勾选框，语义不要搞混：**「启用本模块」= 全局开关**（框架的 `db.modules[key]`，由框架统一管理；禁用后连事件都不转发给模块）；**「登录后自动应用」= 角色级**（`charDb.actionbars.autoApply`，勾选=该角色参与，默认勾选）。不要再加「此角色不参与自动排列」这类反向的排除框。
- 自动应用**只在登录**：本会话第一次 `PLAYER_ENTERING_WORLD` 延迟 2s；进本/切图不再套用。条件是「模块已启用」+ `mod:IsAutoApplyAllowed()`；不参与自动应用只影响自动套用，保存与手动「应用当前专精」照常可用。
- 战斗中 `InCombatLockdown()` 要跳过。放置：`C_Spell.PickupSpell` / `C_Item.PickupItem` + `C_ActionBar.PutActionInSlot(slot)`（只传槽位，动作在光标上）；空槽用 `PickupAction` + `ClearCursor`；宠物条用 `PickupSpell` + `PickupPetAction(i)`（交换语义，战斗中被禁）。外部 API 一律 pcall。
- **恢复必须自证成功**：放置后回读 `GetActionInfo(slot)` / `GetPetActionInfo(i)` 校验，只统计真正落位的数量；动作条清空前先用 `C_Spell.GetSpellInfo` / `C_Item.GetItemInfo` 做可用性预检，**若整个方案一个都不可用则直接放弃、绝不清空动作条**（清空 180 槽后再放不回去＝玩家动作条全毁，是最严重的故障模式）。
- 提示要诚实：`Applied %d slots` / `Skipped %d slots` 用真实计数，一个都没放上时要明确告诉玩家，而不是报成功。
- **技能 id / 动作槽 id 不要硬编码猜测，必须实机核对后再写。**

### i18n / 本地化
- `Localization.lua`：英文基准词库 + `ns.RegisterLocale(code, data)` + `ns.ApplyLocale(code)`（全量重置英文再套指定语言）；`ns.knownLocales` 为白名单，用于 DB 清洗。登录时若 `db.locale` 为空则 `GetLocale()`。
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
- 语法检查：`node C:\Users\huang\AppData\Local\Temp\opencode\check.js <目录>`（Lua 5.1 解析器，**递归遍历子目录**，逐文件输出 OK/FAIL）。修改后必须跑一遍。
- i18n 体检：`node C:\Users\huang\AppData\Local\Temp\opencode\i18naudit.js`（列出代码里用到但未声明 / 声明但未使用 / 缺 zhCN、zhTW 覆盖的键）。改文案后跑一遍。
- 修改后自查关键逻辑（锚定、事件注册、combat guard、专精切换时序），然后简短汇报结果。
- 路径含空格（`Program Files`、`World of Warcraft`），处理文件路径务必加双引号。

### 环境说明
- Windows / PowerShell 5.1；`rg`、`gh` 不可用；GitHub API 用 `git credential fill` 取 token + `Invoke-RestMethod`。
- 控制台 CJK 可能乱码，需审查中文文案时导出 UTF-8 文件再看。