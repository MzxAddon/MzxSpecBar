## MzxSpecBar — 项目说明与规范

### 项目状态
- World of Warcraft *retail*（Midnight，Interface 120105）插件 `MzxSpecBar`。功能：按**职业 + 专精**把技能以固定顺序放回玩家动作条，避免默认 UI 打乱。**独立项目**（独立目录 / 独立仓库），**与 MzxRiding 零共享**：不共用任何 Lua 文件、词库、UI 封装；同类封装各自在本插件内实现一份。
- **只面向 retail**。不做其它客户端（周年服/Vanilla/Classic 等）移植或兼容，不加多 flavor TOC、不做能力探测。
- **主项目内禁止测试代码 / 探针 / 诊断代码**。此类代码必须单独立项、放在本项目外部（独立文件夹或独立仓库），且对本项目零影响：不改动本项目任何文件。
- **不做未在真实客户端验证过的改动**；不得声称"零错误""零影响"。正式服改动必须在正式服实机验证。
- 文件夹：`D:\Program Files\World of Warcraft\_retail_\Interface\AddOns\MzxSpecBar\`
- TOC：`MzxSpecBar.toc`（Interface 120105，版本 1.0.2，`SavedVariables: MzxSpecBarDB` + `SavedVariablesPerCharacter: MzxSpecBarCharDB`，斜杠 `/msb`、`/mzxspecbar`）
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
- **按钮一律整行等宽、纵向堆叠**：`FontString` 不会裁剪，固定窄按钮放长文案会直接压到右边控件上（早期 138px 的「Save current specialization」在英文下就出格，德/法语更长）。做法：按钮宽度取**内容宽**（`p:GetWidth() - 24`，与提示/状态行/列表标题左右对齐），每个按钮**独占一行**、行距 30px（26 高 + 4 间隙）。**不要做按文字测宽的自适应排版**——三个按钮宽窄不一既不好看也不省性能。`ActionBars` 面板纵向节奏：勾选框 -2 / 提示 -30 / 自动应用勾选 -52 / 三个按钮 -86、-116、-146 / 状态行 -186 / 列表标题 -220 / 滚动区 -242（底 66 让给警告条带）。
- 共享 UI 助手（**新 UI 一律复用这些，禁止手搓**）：
  - `M.MakeFlatSkin(frame, thickness)`、`M.SnapToPixelGrid(frame)`（`OnShow` + `OnDragStop` 处理半像素缺线）
  - `M.MakeFlatButton(parent, w, h, text, onClick)`、`M.SetButtonIcon(b, texPath, size)`（无文字图标按钮）
  - `M.MakeFlatDangerButton(parent, w, h, text, onClick)`：**危险/删除类按钮**（深红底 `0.29/0.08/0.08` + 亮红字 `1.00/0.42/0.38`，hover 更亮、按下更深；禁用态单独一档）；普通按钮仍是 `FLAT_BTN` 深灰底白字。按钮靠 `b.danger` 标记切换配色，**删除类控件一律用这个**。
  - `M.MakeCloseButton`、`M.MakeSectionLabel`
  - `M.MakeFlatCheckbox(parent, text, onClick)`：**与 MzxRiding 逐像素一致**——方框 18×18（`MakeFlatSkin(cb,1)` 配色 `0,0,0,0 / 0.08,0.09,0.11,0.95`，即只描一圈细边），**金色选中标记只有 10×10**（`SetCheckedTexture`），标签 `GameFontNormalSmall` 距框右 6px，悬停 HIGHLIGHT ADD `1,1,1,0.08`→`0.14`。**不许自己改成 16×16 框 + 12×12 实心方块**——三个 Mzx 插件的勾选框必须看起来一模一样。勾选状态用 `GetChecked()` 读（retail 没有 `IsChecked`）。
  - ⚠️ **`CheckButton` 在 retail 只有 `GetChecked` / `SetChecked`，没有 `IsChecked`**（写 `cb:IsChecked()` 会 `attempt to call a nil value` 崩掉整个面板）。勾选状态由控件**自己翻转**，在 `OnClick` 里直接读 `GetChecked()` 就是新值，**绝对不要自己再 `SetChecked(not GetChecked())`**（双重翻转＝彻底点不动）。
  - ⚠️ **新建勾选框必须立刻从 DB 初始化状态**（`M:GetModulePanel` 里 `p.enable` 那行 `cb:SetChecked(self:IsModuleEnabled(mod.key))`）；`defaultEnabled = true` 的模块漏了这行，就会出现「打开显示未勾选 → 点了写入 true（本来就是 true，等于没变）→ 重载又显示未勾选」的假象，看着就像"没保存"。
  - **`M.MakeListRow(parent, opts)`**（`M.LIST_ROW_HEIGHT = 40`；opts: `height, iconSize=22, stripe, singleLine, onClick`；`row.icon/name/sub/state`；`row:SetSelected(on)` 金色调 + 2px 金色左强调条；`row:SetStripe(on)`）——**两行文字的行内间距要统一**：第一行 `name` 距顶 -6、第二行 `sub` 距顶 -22（行高 40 时上下留白对称、行距 16px），图标 22×22 垂直居中；不要出现"上边距和下边距不一样"的排版。
  - `M.SetStateIcon(row, on, texPath, size)`：列表右侧状态图标，替代状态文字（首次调用会隐藏 `row.state`）
  - `M.MakeModernScrollbar(scroll)`：**现代自绘滚动条**（3px 暗轨道 + 6px 亮滑块、无上下箭头、可拖拽、滚轮翻页，悬停/拖动时提亮）。**禁止再用 `UIPanelScrollFrameTemplate`**。用法：`scroll = CreateFrame("ScrollFrame", nil, parent)`（不带模板）→ `p.scrollbar = M.MakeModernScrollbar(scroll)`；**列表内容高度变化后必须调 `p.scrollbar:Update()`**。要点（都是踩过坑的）：
    - **滚动条自己接管内容宽度**：`SCROLLBAR_WIDTH = 6` / `SCROLLBAR_GUTTER = 10`（滑块 6 + 留白 4；轨道 2px、滑块 4px），`Update()` 把 scroll child 宽度设成 `scroll:GetWidth() - 10`，**调用方不许再 `SetWidth` 内容帧**。**滑块就该是细条（≤6px），右侧留白总共不超过 16px——空白越宽越像没做完**。
    - **行不许 `SetWidth`，改用双锚点拉伸**：`row:SetPoint("TOPLEFT", rows, "TOPLEFT", 0, y)` + `row:SetPoint("TOPRIGHT", rows, "TOPRIGHT", 0, y)`，行宽就永远等于内容框宽——手算宽度会因为刷新时序算出 0/旧值，导致点击区只剩左边一小块。缩进只加在左边锚点（`TOPLEFT, 18`），右边锚点保持 0。
    - `Update()` 每次都会把滚动值夹到 `[0, maxScroll]`：滑块位置由**夹过的值**算，滑块永远不会飞出轨道；内容装得下时**只隐藏滑块、轨道照常显示**（用户明确要求轨道始终可见，否则设置页那种"只有一条方案"的列表看着像没有列表区），滚动值同时归零。
    - 滚轮/拖拽处理器里**先 `update()` 再读 `bar.maxScroll`/`bar.offset`**（这些值随时可能被刷新改动）；另外 `HookScript("OnSizeChanged", update)` 兜住几何变化。
    - **右键菜单尺寸是常量**：`QUICK_MENU_WIDTH = 236` / `QUICK_MENU_HEIGHT = 420`，**永远不按内容或屏幕高度动态调整**。行数不够菜单下面留白，行数多了在固定窗口里滚动。**轻量插件不要做"每次打开按屏幕尺寸重算布局"这种动态几何**——它既没有性能收益，又让菜单每次打开都在跳。定位方向判断用常量 `QUICK_MENU_HEIGHT` 即可。
  - **菜单里不写任何标题/说明文字**：顶部不留标题条（滚动区直接从 `-6` 开始），省掉一行没信息量的字。
  - **行左边距要小**：滚动区 `TOPLEFT 6 / BOTTOMRIGHT -4`（滑块离右边框只剩 4px）；专精行文字起点 38（图标 22 + 8 内边距），**配置行文字起点 26**——层级靠"比父行文字靠左一点"体现，**不要靠整行缩进 18px**，那会让左边空一大块。`MakeListRow` 的 `textLeft` 可覆盖，池化复用时要在 `addRow` 里重新锚定（`row.name:ClearAllPoints()` + `SetPoint`），否则新建行和复用行的文字位置会不一样。
    - 列表滚动必须**按行数线性缩放**：滑块高 = `clamp(轨道高 × 可视高/内容高, 24, 轨道高)`（行数上百时自动变短，但永不短于 24px、绝不长过轨道）；滚轮步长 = `max(可视高 × 0.2, 24)`（不能写死 40px，配置一多就变成"一格一行的爬行"）。
  - **面板左右边距统一 12px**：列表的 scroll `TOPLEFT 12 / BOTTOMRIGHT -12`，滚动条右边缘因此与上方整行按钮右边缘对齐；**不要再用 4/-18 这类错位值**，那会造成右边空一大块且参差不齐。
  - ⚠️ **Texture / FontString / Region 不能挂脚本**：`SetScript` 只在 Frame 系（Frame/Button/CheckButton/ScrollFrame）上有意义，给 Texture 挂 `OnMouseEnter`/`OnDragStart` 会直接抛 `bad argument #2 to SetScript`，**抛错会中断整个 `BuildOptions`** → 面板半残（列表空、控件错位）。**需要交互的部件一律 `CreateFrame("Frame")` + 内嵌纹理**（如滚动条滑块）。另外：**面板里"可能出错"的自定义部件要放在最后创建**（滚动条放在 `SetScrollChild` 之后），避免它一崩就把整个面板带走。
- 小地图按钮（`M:CreateMinimapButton`）：31×31，父级 `Minimap`，`MEDIUM`/level 8，可拖动（拖动时用 `OnUpdate` 贴边，位置存 `db.minimapPos` 角度），左键开关设置窗，悬停显示提示。**右键 = 快速列表**（`RegisterForClicks("LeftButtonUp", "RightButtonUp")`，`OnClick` 按 `button` 分派；具体内容由模块通过 `M:SetMinimapContextHandler(fn, hideFn)` 注册，没注册时右键无反应）。
- 斜杠：`/msb` 空参数开关设置窗；`help`、`list`、`on <key>`、`off <key>`。`M:Slash(input)` 处理。
- 事件转发需要框架本身注册事件：`M:RegisterModuleEvent("PLAYER_ENTERING_WORLD")` 之类。

### 动作条模块契约（Modules\ActionBars.lua）
业务实现只写这个模块，遵守：
- `mod:EnsureDB(db, charDb)`：**账号级**（按职业共享的动作条方案 `db.actionbars.profiles`）放 `db`；**角色级**只放 `charDb.actionbars.autoApply`（布尔、正向语义：该角色参与登录自动应用，默认 `true`）。旧的 `db.actionbars.autoApply` / `charDb.actionbars.skipAutoApply` 在此处一次性迁移后清除。
- `mod:OnToggle(on)`：启用时创建资源、禁用时清理。
- `mod:BuildOptions(p)`：构建设置面板（`p` 已带「启用本模块」勾选框，锚在 `TOPLEFT 12,-2`，所以内容从 `-26` 以下开始）；面板元素用 `M.MakeListRow` / `M.MakeFlatButton`。
- `mod:RefreshOptions()`：切标签、开关窗口、数据变化时刷新；**不要在这里重建框架**。
- `mod:OnEvent(event, ...)`：经 `M:RegisterModuleEvent` 注册。注册 `PLAYER_ENTERING_WORLD`（自动应用只处理本会话第一次）与 `TRAIT_CONFIG_UPDATED`（仅用于**用户主动切换专精配置**后落地排列动作条；`LoadConfig` 返回 `LoadInProgress` 时挂 `self.pendingLoadout` 等待它）。
- 已实现的保存/恢复（`Modules\ActionBars.lua`）：存**账号级** `db.actionbars.profiles[classFile][specID][heroSubTreeID] = { savedAt, bars }`，同职业角色共享。`bars` 含 `slots`（动作槽 1–180，覆盖主条/额外条/形态分页）和 `pet`（宠物技能 1–10）。槽位 `{ t="spell"|"item"|"pet", id, sub }`。空槽不写键，恢复时先清空再放置。
- 维度规则：等级 <10 直接不参与（保存时提示退出）；10-70 级 hero 键为 0；≥71 级用当前英雄天赋树 ID（`C_ClassTalents.GetActiveHeroTalentSpec()`）。
- **保存 = 一次性同步快照当前专精 + 当前英雄树，没有「保存所有专精」，不切专精、不碰天赋、不用任何 `C_Timer` 轮询**（`mod:StartSave()` 单函数跑完）。曾经的跨专精/跨天赋保存链因为天赋配置切换无法可靠判定完成而反复切换天赋，已整体删除。**禁令只针对保存链**：`C_ClassTalents.LoadConfig`/`GetConfigIDsBySpecID`/`GetHeroTalentSpecsForClassSpec`/`TRAIT_CONFIG_UPDATED` **一律不要出现在保存流程里**（保存必须一次性同步完成、不许反复切配置）；但**用户主动点击**导致的专精/专精配置切换（快速列表）是允许的，见下条。
- 因此模块里**没有 `mod.busy` 状态**（保存和应用都是同步的，不会重入）。
- **点击「已保存方案」行 = 先切到对应专精，再排列动作条**（`mod:ApplySpec`）：不再提示"专精不对"、也不在专精不符时直接排列。流程：若当前专精就是目标专精 → 直接 `mod:ApplyLayoutFor(specID, heroID)`；否则 `SwitchSpecialization(specID)` → 延迟 0.25s 检查 `SpecID()`，没切成功再等 0.35s 复查一次，仍失败才报 `Could not switch specialization` → 成功后应用**点击的那条**方案。**只切专精，绝不碰天赋配置 API**（天赋树不同导致的技能不可用由预检如实计入跳过数）。应用入口统一走 `mod:ApplyLayoutFor(specID, heroID, silent)`，`mod:ApplyCurrent(silent)` 只是它的"当前专精"特例。
- **小地图右键 = 快速列表**（`M:SetMinimapContextHandler(fn, hideFn)`，模块在 `mod:OnToggle` 里注册；左键仍是开关设置窗，打开设置窗会顺手关掉快速列表）：弹层**贴整个小地图展开**（`Minimap` 的左/右边缘，不压在小地图上；小地图按钮只用来判断往屏幕内侧哪边开），**按钮在屏幕下半部时改为向上展开**（`openDown = cy < menuH + 40` 判反），`FULLSCREEN_DIALOG` + level 9000，与配置窗同级。内容：
  1. **每个专精一行（暴雪天赋树）**，行下**缩进挂该专精自己的「专精配置」**（= 暴雪天赋面板左下角那个下拉里的东西：`C_ClassTalents.GetConfigIDsBySpecID(specID)` 取配置 ID → `C_Traits.GetConfigInfo(configID).name` 取**暴雪给的名字**；当前选中的用 `C_ClassTalents.GetLastSelectedSavedConfigID(specID)` 打勾）。**「切换专精」在暴雪模型里 = 挑一份专精配置**，所以配置才是可点的行，暴雪的专精名只是分组头。`configID <= 0`（入门天赋配置 `-2` 等特殊项）必须跳过，否则一点就把天赋重置成初始。
  - **右键菜单只干"切天赋"这一件事**：不显示本插件已保存的方案、不显示任何插件自造数据（那些只在设置窗里）。用户明确要求过。
  - **点任意处都能关闭 = 非阻塞外点关闭，照抄 MzxRiding 随机坐骑模块的做法**：**禁止铺全屏透明点击层**（会挡住角色操作：点地、点技能、打怪全被吞掉）。正确做法：菜单 `f:EnableMouse(true)`，注册 `GLOBAL_MOUSE_DOWN` → `mod:OnGlobalMouseDown()`，只在鼠标**既不在菜单上、也不在小地图按钮上**时才 `HideQuickMenu()`；`M:RegisterModuleEvent("GLOBAL_MOUSE_DOWN")` 走框架转发（菜单没开时函数第一行就 return，空闲开销为零）。
  - 点配置 = `mod:SwitchLoadout(specID, configID)`：专精不一致先 `SwitchSpecialization(specID)`（0.25s 复查、未到位再等 0.35s 复查一次）→ 专精到位后 `C_ClassTalents.LoadConfig(configID, true)`；返回 `2 (LoadInProgress)` 时挂 `self.pendingLoadout` 等 `TRAIT_CONFIG_UPDATED` 再落动作条，`3/1` 立即应用，`0/出错` 报 `Could not switch configuration`。
  - 列表行用 `M.MakeListRow`，专精行高 28、配置行高 26（次级：缩进 18px + 文字调暗 0.80/0.80/0.86）；**排版用像素游标 `y`（`y = y + 高 + 间距`），不要用"第几行 × 固定行距"**——那样分组和条目的间距必然混成一团（主次不清）。滚动条用 `M.MakeModernScrollbar`。
- **宏：保存存内容；恢复两阶段、顺序固定 = 先建宏 → 再排列动作条（宏没有"跳过"分支）**：
  - 保存：宏槽存 `{t="macro", id=宏本索引或nil, name, icon, body=宏内容, pc=是否角色宏}`；`pc` 由宏本索引 `> GetNumMacros()` 首返回值判定；`equipmentset`/`equipmacro`、宠物栏无技能 ID 的内置指令各自单独计数，**宏不进任何跳过计数**。
  - 恢复 ①（**在清空动作条之前**）：预扫描 plan 中所有宏条目 → `FindMacroByContent(book, action)` 按**内容**找已有宏（先同名同内容，再任意同内容宏）→ 找到就**不创建**，并用**实际存在的那个宏名/宏本索引**去放置（可能与存档名不同）；找不到 → `CreateMacro(name, icon, body, pc and true or nil)`，**通用宏也创建**（`perCharacter` 传 nil）；创建成功把记录写回 `book` → 同一宏占多个槽位只建一次。恢复 ②：清空 180 槽 → 按槽位拾取放位（宏按 宏本索引 → 实际宏名 → 存档宏名 依次尝试）；回读校验用**实际宏名**（`SlotActionText(slot)` 或 `MacroNameAt(GetActionInfo 的 id)` 比对）。
  - **绝不 `EditMacro`、绝不用旧内容改写已有宏**（同名但内容不同 → 按内容匹配到已有宏直接用它，不新建、不覆盖）；创建失败或放位/校验失败只如实计入"未能放置"，不虚报成功。
  - `ApplyLayout` 第 5 个返回值 = 本次创建数量（`Created %d macros`）。
  - **API 多源兜底，禁止单点依赖**（零售实机行为与文档不一致，必须逐环 2–3 条路径 + `type()`/`pcall` + 多源回读）：
    - 取名：`C_ActionBar.GetActionText(slot)` → `GetActionText(slot)` → `C_Macro.GetMacroName(GetActionInfo 的 id)` → `GetMacroInfo(id)`（`SlotMacroName`）。
    - 宏本：`MacroBook()` 线性扫 `1..MACRO_SCAN_LIMIT` 建 name→{id, icon, body}（**不硬编码 120/121**；空档跳过、重名取先出现者）。
    - 创建/拾取：`CreateMacro`/`C_Macro.CreateMacro`、`PickupMacro`/`C_Macro.PickupMacro`（均 `#nocombat` 受限 → pcall）。
  - 物品/技能若本角色不可用也计数（`C_Item.GetItemInfo` / `C_Spell.GetSpellInfo` 返回 nil）。恢复一律覆盖、不备份。
- 面板只有两个勾选框，语义不要搞混：**「启用本模块」= 全局开关**（框架的 `db.modules[key]`，由框架统一管理；禁用后连事件都不转发给模块）；**「登录后自动应用」= 角色级**（`charDb.actionbars.autoApply`，勾选=该角色参与，默认勾选）。不要再加「此角色不参与自动排列」这类反向的排除框。
- 自动应用**只在登录**：本会话第一次 `PLAYER_ENTERING_WORLD` 延迟 2s；进本/切图不再套用。条件是「模块已启用」+ `mod:IsAutoApplyAllowed()`；不参与自动应用只影响自动套用，保存与手动「应用当前专精」照常可用。
- 战斗中 `InCombatLockdown()` 要跳过。放置：`C_Spell.PickupSpell` / `C_Item.PickupItem` + `C_ActionBar.PutActionInSlot(slot)`（只传槽位，动作在光标上）；空槽用 `PickupAction` + `ClearCursor`；宠物条用 `PickupSpell` + `PickupPetAction(i)`（交换语义，战斗中被禁）。外部 API 一律 pcall。
- **恢复必须自证成功**：放置后回读 `GetActionInfo(slot)` / `GetPetActionInfo(i)` 校验，只统计真正落位的数量；动作条清空前先用 `C_Spell.GetSpellInfo` / `C_Item.GetItemInfo` 做可用性预检，**若整个方案一个都不可用则直接放弃、绝不清空动作条**（清空 180 槽后再放不回去＝玩家动作条全毁，是最严重的故障模式）。
- 提示要诚实且**可定位**：`Applied %d slots` 用真实计数，一个都没放上时要明确告诉玩家而不是报成功；**跳过必须按原因分桶**（`ApplyLayout` 第 3 个返回值是 `missed = {spell, item, macro, pet, other}`，每项是 `{slot, actionType, id, name}`）。
  - 面板底部条带只放**汇总行**（`WARN_MAX_LINES`=3 条，如「跳过 3 个槽位：技能不可用（12、45、78）」，槽位号最多列 `MISSED_SLOT_LIST_MAX`=8 个再加 `, ...`）。
  - **聊天框额外逐行输出明细列表**（`MissedDetailLines` → `mod:Warn(warnings, details)`，明细**不进面板**）：每条 `槽位 N：名字（技能/物品/宏 2050）`，名字取 `C_Spell.GetSpellInfo().name` / `C_Item.GetItemInfo()` / 宏名，取不到显示「未知」；最多 `DETAIL_LINE_MAX`=10 条，超出用 `and %d more` 收尾。
  - 分桶规则：`SpellKnown`/`ItemKnown` 为假归 spell/item 桶，宏一律进 macro 桶，其余落 other 桶。
- **技能 id / 动作槽 id 不要硬编码猜测，必须实机核对后再写。**

### i18n / 本地化（对标 MzxRiding）
- `Localization.lua`：英文基准词库 + `ns.RegisterLocale(code, data)` + `ns.ApplyLocale(code)`（全量重置英文再套指定语言）；`ns.knownLocales` 为白名单，用于 DB 清洗。登录时若 `db.locale` 为空或不在白名单 → `GetLocale()`（**自动跟随客户端**）。`L` 带 `__index` 兜底，未声明的键返回键文本，**永不返回 nil**。
- **语种集（与 MzxRiding 一致）**：`enUS` / `enGB` 直接用英文基准、**不单独提供文件**；其余 10 个语种各有文件：`Locales\zhCN.lua`、`zhTW.lua`、`koKR.lua`、`deDE.lua`、`frFR.lua`、`esES.lua`、`esMX.lua`、`ruRU.lua`、`ptBR.lua`、`itIT.lua`（`Locales\*.lua` 各自只覆盖不同键，缺键自动回退英文）。
- **语言页 `Modules\Language.lua`**：`alwaysOn = true`（无启用勾选框），内容 = 「跟随客户端」+ 12 个语种，用 `M.MakeListRow` 列表行 + `M.SetStateIcon` 标记当前项；点击写 `M.db.locale = code or nil` 后 `ReloadUI()`（重载时 `PLAYER_LOGIN` 重新 `ApplyLocale`）。**语言名一律用母语原名**（如 "简体中文"、"Deutsch"、"Русский"），写在模块的 `LOCALES` 表里，**不进词库、不翻译**。
- **新增语种流程（四处同步，缺一不可）**：① 新建 `Locales\<code>.lua`（`ns.RegisterLocale("<code>", { ... })`，覆盖全部英文键）；② TOC 里加 `Locales\<code>.lua` 一行；③ `Localization.lua` 的 `ns.knownLocales` 加一项；④ `Modules\Language.lua` 的 `LOCALES` 表加一项（母语名）。
- **新增文案流程**：先在 `Localization.lua` 加英文基准串 → **10 个语种文件全部补上覆盖**（不要只补 zhCN/zhTW）→ 代码里 `L["English string"]`。改完跑 `i18naudit.js` 确认无「used missing」。
- TOC 标题用 **MzxTool 的逐字母渐变配色**（品牌名 `MzxSpecBar` 逐字母上色 `8845EC → FF00D8`，与 MzxToolBox 同一条色带），各语种 `Title-xx` 只换描述文字、品牌名配色保持一致。
- 提示行里的鼠标图标等内联图形统一由 `M.MouseIcon` 之类助手提供，**禁止各模块自己写内联纹理字符串或改尺寸**。`M.MouseIcon("L"/"R")`（`Core.lua`，与 MzxRiding 同规格、纹理各存一份）：自有 `Textures\mouse-left.tga` / `mouse-right.tga`（28×28 紧裁剪、图案内缩为 0，才能与正文左边线对齐），统一按 12:9 显示。凡是提示里出现"左键/右键"的地方都用它拼前缀：`GameTooltip:AddLine(M.MouseIcon("L") .. L["..."], ...)`。**有图标就别再在文案里写"左键/右键"**（图标已经说明了，重复=偷懒）——词库里只能有 `Open/close settings` / `Open the quick list` 这种中性文案。

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
- **CurseForge 项目描述 = 仓库根目录的 `CurseForgeDescription.md`**（英文 Markdown，随仓库维护，打包时被 `*.md` 排除规则自动剔除）。**它是冻结契约：发版时一律不改**，目标是"发几个版本都不用动它、一直用到关服"。规矩：
  - CF API 改不了项目描述，所以**不要只说"需要用户手动粘贴"就收工**——必须**主动把完整 Markdown 内容给出来**（写文件 + 在回复里给出全文）。
  - **只写长期不变的用户可见行为**。禁止出现：插件版本号、Interface 号、游戏版本名（Midnight/12.x）、暴雪 API 名、精确 UI 文案（按钮/勾选框/面板标题原文）、魔数（动作槽 180、等级门槛 10）、模块内部 key（`actionbars`）。
  - **数字一律抹掉**："180 个动作槽"→"每个动作槽"，"10 级以下不参与"→"很新的角色还不能保存"。
  - **列举用"包括/e.g."，不要穷举**：新增语言、新增命令、新增模块都不会让描述失准；表格里只留 `/msb`、`help`、`list`、`on/off <module>` 这类长期稳定的入口。
  - **新功能必须落在描述已覆盖的能力范围内**（保存/应用/切天赋/报告/自动应用），**不要为新功能追加句子**；确实超出范围时，**先把描述里已有的那句抽象化或放宽**，而不是新增段落。
  - 描述里的"限制"是**承诺**：将来真实现了某条限制才算有理由改描述（那是有意的行为变更，值得改一次），其余一律不动。
  - 发版时提醒用户"整份复制替换 CF 描述页"——**通常内容与上一版完全相同**，不需要重写。
- CF 上传的已知坑（已在工作流里处理，改动时勿回退）：**metadata 必须用 `--form-string` 发送**（`-F` 会把值里的 `;` 当分段符导致 JSON 被截断，CF 报 `Invalid JSON`）；metadata 用 Python `json.dumps` 生成；上传失败要打印 HTTP 码 + 响应体并重试。
- **仓库 secret `CF_API_TOKEN` 已配置好。若发布日志出现「未配置 CF_API_TOKEN secret」，不要找用户要 token**：本机 git 凭据库里存着（`"protocol=https`nhost=api.curseforge.com`n`n" | git credential fill`），跑 `C:\Users\huang\AppData\Local\Temp\opencode\set_cf_secret.ps1` 即可用 libsodium sealed box 加密后 PUT 回仓库 secret（token 永不写进仓库、脚本或输出）。补完直接重新 dispatch 一次 `release_1xx.ps1`，GitHub Release 会原地更新，CF 那步会真的上传。

### 校验
- 语法检查：`node C:\Users\huang\AppData\Local\Temp\opencode\check.js <目录>`（Lua 5.1 解析器，**递归遍历子目录**，逐文件输出 OK/FAIL）。修改后必须跑一遍。
- i18n 体检：`node C:\Users\huang\AppData\Local\Temp\opencode\i18naudit.js`（列出代码里用到但未声明 / 声明但未使用 / 缺 zhCN、zhTW 覆盖的键）。改文案后跑一遍。
- 修改后自查关键逻辑（锚定、事件注册、combat guard、专精切换时序），然后简短汇报结果。
- 路径含空格（`Program Files`、`World of Warcraft`），处理文件路径务必加双引号。

### 环境说明
- Windows / PowerShell 5.1；`rg`、`gh` 不可用；GitHub API 用 `git credential fill` 取 token + `Invoke-RestMethod`。
- 控制台 CJK 可能乱码，需审查中文文案时导出 UTF-8 文件再看。