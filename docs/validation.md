# RigPop 验收记录

## 2026-11-23 Q 版蓝衣冒险家适配

- 默认新角色改为 Kenney Toon Characters 的 Female adventurer（CC0-1.0），使用原始分部件
  PNG；来源、原始 SVG、装配脚本与许可证均保留。美术来源为 existing，不是 AI 生成或代码绘画。
- 通过原始 SVG 的变换信息对齐 9 个部件，后发跟随头部、手掌跟随手臂，脚底原点一致。
  六个骨架动作和两种原画表情可编辑、保存重开，并随角色包导出。
- 为人形预设调整行走、奔跑、招手与跳跃：交替踏步、控制正面摆臂幅度、招手避开头部，
  跳跃时双手抬过肩部。其他骨架仍使用各自的动作数据，不修改旧角色工程。
- `tests/adventurer_test.gd` 实际 OpenGL 窗口 29 项通过、0 失败，检查部件挂接、脚底原点、
  招手与跳跃姿势、换图恢复、保存回读、两种运行导出、三种工作区尺寸，以及 8 个动作的
  全部 68 帧均有实际绘制且未裁切。动作逐帧检查板在 `build/previews/adventurer-actions-*.png`，
  动图在 `build/previews/adventurer-motion.gif`。
- `tests/run_tests.gd` 无窗口 75 项通过，`tests/rig_import_test.gd` 无窗口 28 项通过。
  新人物执行实际桌宠窗口测试，托盘、显隐、置顶、拖动、缩放和透明渲染均通过，0 失败。
- 新人物导出的 Godot 工程完成全新导入，`tests/export_probe.gd` 实例化、加载贴图、保留
  放置坐标并调用动作通过。独立桌宠样例位于 `build/examples/blue-adventurer-pet/`，可编辑
  样例位于 `build/examples/blue-adventurer/`。
- 重新构建编辑器和宿主、生成最终 ZIP，并在源码目录之外独立解压验证保存、重开、三种
  导出和桌宠启动。`build/release-verification.json` 中 `errors: []`。源码的 `git diff --check` 通过。
- 动作仍是正面刚性 FK 样例，不是逐方向行走动画或网格蒙皮。没有新增系统鼠标自动操作；
  本轮实际窗口检查由 Godot 测试驱动，未扩展多屏和真实系统 DPI 验收范围。

## 2026-11-23 灵犀、骨架预设、PSD 与托盘

版本：0.1.1；Windows x86_64；Godot 4.7.2 stable；实际窗口使用 OpenGL Compatibility。

| 验证 | 结果与证据 |
| --- | --- |
| 核心、创作与导出回归 | `tests/run_tests.gd`：75 项通过，0 失败 |
| 部件交互回归 | `tests/part_interaction_test.gd`：98 项通过，0 失败 |
| 逐帧像素回归 | `tests/pixel_frames_test.gd`：50 项通过，0 失败 |
| 动作与关节回归 | `tests/animation_interaction_test.gd`：58 项通过，0 失败 |
| 骨架、预设与 PSD 集成 | `tests/rig_import_test.gd`：无窗口 28 项通过，0 失败 |
| PSD 解析 | `tools/psd/test_import.py`：2 个测试方法通过，覆盖 raw、RLE、ZIP、ZIP prediction 四种压缩及中文分组、偏移、透明度和隐藏图层 |
| 实际窗口与托盘 | `tests/desktop_test.gd`：0 失败，涵盖透明渲染、工具窗口样式、托盘显隐、关闭到托盘、菜单恢复、拖动、缩放与退出清理 |
| 工作区尺寸 | 960×640、1280×800、1920×1080 实际窗口截图中完整角色处于画布内，窗口改变尺寸后重新适配 |
| Windows 构建与便携包 | 编辑器、桌宠宿主、原生 DLL 与冻结的 PSD 辅助程序均已构建；最终 ZIP 独立解压检查通过 |
| 成品保存和导出 | 只使用解压后的 EXE 保存、重开并导出工程、Godot 包、桌宠；导出桌宠独立启动，`build/release-verification.json` 中 `errors: []` |
| Godot 包集成 | 从成品生成的 Godot 工程完成首次资源导入；`tests/export_probe.gd` 实例化入口、保留放置坐标、加载贴图并调用招手，退出码 0 |

骨架与导入检查包含：灵犀 11 部件与 9 个动作、自由结构不误判为人形、显式未分配部位
不自动回退、中文左右侧识别、缺少父部位时保持装配位置、导入撤销重做、原始 PSD 随
可编辑工程保存重开、运行包不携带原始 PSD，以及自定义预设按部位映射到不同部件 ID。
导入映射弹窗的骨架切换与重复部位校验也通过测试。

独立成品检查发现并修正了桌宠宿主遗漏 `taskbar.gd` 的导出清单问题，修正后重新导出、
打包并重跑成品检查。PSD 辅助程序在源码目录外解析实际生成的 PSD，不依赖系统 Python。
便携包同时包含编辑器和宿主所需的 `rigpop_windows.dll`，原生接口只接受本进程窗口句柄。

主要复现命令：

```powershell
& './build/psd-venv/Scripts/python.exe' tools/psd/test_import.py
& '<Godot 4.7.2 console>' --headless --path . --script tests/rig_import_test.gd
& '<Godot 4.7.2 console>' --path . --script tests/desktop_test.gd -- --character '<已保存灵犀目录>/character.rigpop.json'
& './tools/verify_package.ps1'
```

本轮日志为 `build/rig-import-regression.log`、`build/desktop-test.log`、
`build/verify-current.log` 和 `build/exported-project-probe.log`。角色工作区和导入映射截图
保存在 `tests/output/rig_410611/`，生成文件不纳入源码或发布包。

本轮 Computer Use 已观察到实际角色工作区；用户按 Esc 中止后没有继续操作窗口。
未把中止的界面操作记为完整人工验收。自动窗口测试通过不代表已覆盖多显示器、真实
系统 DPI、其他物理电脑或长期运行。PSD 当前仅支持 8 位 RGB/RGBA；复杂混合、剪贴、
组蒙版和效果按报告提示处理，尚无重导入合并。网格蒙皮、IK 和二级物理未参与本轮验收。

## 2026-11-18 交互、动作组合与多关节绑定

- 控制绑定改用现有主题的 Control 模态弹窗，设备选择、三种鼠标键选择和实际键盘捕获
  替代键名输入。Viewport 鼠标事件验证捕获、应用、重复拒绝与撤销；960×640、1280×800、
  1920×1080 实际窗口截图检查弹窗和列宽，无溢出或灰色原生标题栏。
- 桌宠试演保存受管理 PID，重复启动复用当前进程并禁用启动按钮，停止后恢复按钮。
  右键按下等待点按/拖动判定，松开点按打开菜单，拖动按 30 屏幕像素一级调整 1～8 倍。
  重算窗口包围盒并保留世界锚点；动作换图、子关节与镜像也参与轮廓计算。
  右键在桌宠适配层截留，游戏的右键与中键绑定仍可执行。菜单强制为独立原生窗口，
  避免嵌入菜单被角色的小窗口裁切或被轮廓点击穿透排除。
- 时间轴通过 Viewport 鼠标事件验证连续拖动选帧和关键帧拖移；目标已有关键帧时交换
  完整姿势与贴图，一次拖动一个历史操作，撤销和重做通过。
- `core/action_player.gd` 为游戏和桌宠提供独立动作时钟、轨道/子节点冲突判断、优先级、
  拒绝或替换规则，以及移动锁定。测试覆盖移动加招手加头部动作、同部位替换、较低
  优先级拒绝、动作完成清理、锁定结束后按住方向继续移动。
- 关节使用透明的 `kind=joint` 节点，支持添加子关节、父节点绑定、画布手柄、位置/旋转
  关键帧与 FK 联动。验证三段链、绑定保留世界变换、循环拒绝、旋转父节点下的拖动换算、
  中间关节删除、撤销、保存重开和导出。没有实现网格蒙皮、IK 或自动重绘像素。
- 新增 `tests/animation_interaction_test.gd`：无窗口 58 项通过，实际窗口加受管理进程检查
  61 项通过；新编译编辑器 PCK 运行 58 项通过。已纳入 Windows 发布工作流。
  原有基础套件及新编辑器 PCK 均为 73 项通过，部件交互 98 项、逐帧像素 50 项通过。
- 扩展 `tests/desktop_test.gd`，实际 OpenGL 窗口中验证透明/置顶、原生菜单、右键隔离、
  放大缩小上下限、锚点、动画边界变化时左拖抓取位置、图像不裁切、失焦清理与菜单退出，
  0 失败。该套件的透明/置顶
  断言需要真实显示服务器，不适用于 `--headless`。
- 用成品导出包含关节和多个动作的 Godot 工程，完成全新资源导入；`tests/export_probe.gd`
  实例化入口、检查贴图和坐标、并发动作层及父关节转动传播，退出码 0。
- 最终重新构建编辑器和桌宠宿主；以桌宠成品 PCK 在实际窗口重跑扩展套件，0 失败。
  重新生成 `build/RigPop-0.1.0-win64.zip` 后独立解压，只使用成品验证启动、保存重开、
  三种导出和导出桌宠运行，`build/release-verification.json` 中 `errors: []`。
- 实际窗口截图与样本工程在 `tests/output/animation_<时间>/`，桌宠菜单和透明渲染截图为
  `tests/output/desktop_menu.png`、`desktop_window.png`；生成文件不纳入源码。
- 原生系统鼠标补测使用 computer-use 技能启动，物理 Esc 中止后停止了窗口自动操作，
  并清理本次启动的桌宠进程。没有把这次中止的补测记为完整的系统鼠标验收；菜单及缩放
  结论来自 Godot 实际窗口事件和渲染检查。跨窗口右键拖动、多显示器及真实 DPI 仍需人工验收。

## 2026-11-17 调色与逐帧像素编辑

- 补齐 `PopupPanel` 与 ColorPicker 所用 TabContainer 页签样式，调色弹窗采用不透明浅色
  底板；内部工具图标采用现有墨色。1280×800、960×640 实际鼠标打开弹窗并截图检查，
  RGB、HSV、Linear 文本与底色的对比度均不低于 4.5:1，工作区原有视觉风格保留。
- 像素绘制新增“当前帧 / 共用图片”范围，默认只编辑当前帧。首次实际修改像素时才建立
  独立图片，并在必要时恢复下一帧原有图片，防止保持采样导致相邻帧或其他动作被连带修改。
  图片独立化与整个笔画作为一次撤销；同一帧后续笔画复用图片，空笔画不增加历史或素材。
- 新增复制上一帧图片、空白帧和当前帧图片导入入口，支持整张人物图或局部部件的逐帧
  像素变化。“当前帧”范围的画布调整与最近邻重采样也独立处理；工程格式保持版本 1。
- 画布点击判定和选框使用当前帧实际贴图与可见性；适合画布范围包含当前动作引用的所有
  图片尺寸，避免大图被按基础图尺寸处理，以及切帧时因图片尺寸不同而来回改变取景。
- 新增 `tests/pixel_frames_test.gd`：实际 OpenGL 窗口 51 项通过，无窗口 50 项通过，
  覆盖铅笔、橡皮、填充、复制帧、帧隔离、撤销重做、全图换帧、扩画布、命中判定、实际
  渲染像素、存取回读、Godot 导出和弹窗对比度。已纳入 Windows 发布前的源码检查。
- 原有套件实际窗口 73 项通过，部件鼠标回归无窗口 98 项通过。重新构建 Windows 编辑器
  和桌宠宿主，新 PCK 的逐帧测试 50 项通过；重新打包后独立解压成品启动、保存重开、
  三种导出和导出桌宠启动均通过，`build/release-verification.json` 中 `errors: []`。
- 截图为 `tests/output/color-picker-1280x800.png` 和 `color-picker-960x640.png`；
  完全换图的实际渲染截图与样本工程在 `tests/output/pixel_<时间>/`，生成文件不纳入源码。
- 边界：图片仍由作者手绘或导入；逐帧独立枢轴与透明裁边未实现，基础图裁边只在
  “共用图片”范围开放。保持统一画布和锚点可避免整帧切换时的对齐偏差。

## 2026-11-17 部件选择与添加修复

- 通过 `Viewport.push_input()` 发送鼠标事件，复现左侧部件选择过程中同步重建 Tree 的错误：
  Godot 拒绝在鼠标选择事件期间清空或创建条目，后续空条目访问使 `building` 未能复位，
  导致继续切换和添加时状态异常。原有直接调用编辑函数的测试没有覆盖此事件时序。
- 选择事件中立即读取部件 ID，再以 `call_deferred()` 执行选择和界面刷新，避免在事件处理
  期间释放正在使用的 TreeItem。主题、布局、图标及控件样式未改动。
- 新增 `tests/part_interaction_test.gd`，覆盖连续鼠标选择、编辑名称后切换、连续添加子部件、
  空角色的左栏和检查器添加入口、撤销重做，以及树、画布、时间轴选择状态一致性。
  无窗口运行 98 项通过，实际 OpenGL 窗口运行 103 项通过，均无脚本或树操作错误。
- 原有 `tests/run_tests.gd` 在实际窗口运行：73 项通过、0 失败，包含三种窗口尺寸与两档
  UI 缩放。新增点击测试已接入 Windows 发布工作流的源码检查步骤。
- 重新构建 Windows 编辑器与桌宠宿主，生成 `build/RigPop-0.1.0-win64.zip`。
  用新成品 PCK 运行点击回归，98 项通过；`tools/verify_package.ps1` 在独立解压目录验证
  EXE 启动、保存重开、三种导出及导出桌宠启动，报告 `errors: []`。
- 点击回归由 Godot 分别加载源码和成品 PCK 执行；发布 EXE 不执行外部 `--script` 测试。
  实际窗口截图为 `tests/output/part-interaction-editor.png`，上述生成日志与截图不纳入源码。

## 2026-11-16 发布检查

- 从当前源码重新导出 Windows 编辑器和桌宠宿主，EXE 产品信息为 RigPop / 0.1.0.0。
- 修正 `editor/stage.gd` 中阻止全新导入的 `parent_pos` 类型推断错误；原有 73 项检查全部通过。
- 在没有 `.godot/` 缓存的独立源码副本中完成首次导入和构建。
- 在独立副本中验证 PNG 与 ICO 自定义图标写入 EXE；正式发布包沿用默认图标。
- 生成只含程序、PCK、宿主、说明和许可证的 ZIP，并生成 SHA-256 校验文件。
- 只解压最终 ZIP 到独立临时目录，不复制源码；成品保存、重开与三种导出通过，导出桌宠 EXE
  独立启动并正常退出。报告为 `build/release-verification.json`，`errors: []`。
- 新增版本标签触发的 GitHub Windows 构建与发布工作流；本地成品验证不等于工作流已经执行成功。

以上仍属于同机不同目录的发布验证；不同物理电脑和未安装开发环境的系统仍需实际验收。

## 2026-11-13 功能检查

日期：2026-11-13。平台：Windows x86_64；引擎：Godot 4.7.2 stable；渲染：OpenGL Compatibility。
实际渲染设备为 Intel UHD Graphics 730。所有结果来自 RigPop 独立工程。

## 已执行

| 验证 | 结果与证据 |
| --- | --- |
| 核心、创作与导出套件 | `tests/run_tests.gd`：73 项通过，0 失败 |
| 实际窗口布局 | 960×640、1280×800、1920×1080，画布不被检查器覆盖，完整角色处于视野内 |
| UI 缩放 | 125% 与 150% 模拟缩放，主要画布仍可用，面板滚动不覆盖画布 |
| 像素与图集 | 2×2 图集经真实导入预览确认，生成 4 帧动作；整体导入可一次撤销；笔画与独立帧回归通过 |
| 输入与碰撞 | 点按等待、双击优先、长按互斥、失焦释放、实际移动和石块阻挡通过 |
| 存取 | 保存重开像素一致、独立素材身份保留、旧 JSON 备份、拒绝覆盖其他角色、失败打开保留当前文档 |
| 原生桌宠场景 | `tests/desktop_test.gd`：11 项通过，包含透明窗口属性、置顶切换、菜单、拖动状态和透明像素输出 |
| Windows 编辑器构建 | `tools/build.ps1` 成功导出 `RigPop.exe` 与 PCK |
| Windows 桌宠宿主构建 | 只导出桌宠、公共组件、工程读取与字体，不携带编辑界面或游戏控制器 |
| 成品自检 | 发布 exe 执行 `-- --verify-install`，保存、回读与三种导出均通过，报告 `errors: []` |
| Godot 包集成 | 在全新的生成项目中完成无窗口资源导入与 20 帧运行；另由 `tests/export_probe.gd` 实例化导出入口、验证位置和贴图、调用招手叠加，无脚本或资源依赖错误 |
| 桌宠成品启动 | 导出的 `RigPopPet.exe` 读取旁边角色数据，独立运行后自动退出，无脚本或资源依赖错误 |
| 跨目录便携 | 仅复制干净发布目录到另一可写工作区，执行 exe 自检，三种导出仍通过；没有复制源码或 `.godot/` |
| 父目录依赖 | 对 core/editor/runtime/services/exporters/tools 的源文件检索，未发现父 Demo 运行引用或作者机器路径 |
| 分发包 | `tools/package.ps1` 生成干净目录与 ZIP；ZIP 逐项 CRC 检查通过 |

源码套件运行命令：

```powershell
& '<Godot 4.7.2 console>' --headless --path . --script tests/run_tests.gd

# 去掉 --headless 会在 tests/output/ 中保存实际 OpenGL 截图。
& '<Godot 4.7.2 console>' --path . --script tests/run_tests.gd

& '<Godot 4.7.2 console>' --path . --script tests/desktop_test.gd -- --character '<角色目录>/character.rigpop.json'

& './build/RigPop.exe' --headless -- --verify-install
```

结果 JSON 在 `tests/output/latest.json`，每次运行另存独立输出目录。发布版自检报告在
`portable_data/verification_<时间>/verification.json`。这些生成数据不纳入源码或发布 ZIP。

## 截图

- [1280×800 工作区](screenshots/editor_1280x800.png)
- [960×640 工作区](screenshots/editor_960x640.png)
- [1920×1080 工作区](screenshots/editor_1920x1080.png)
- [像素绘制](screenshots/workspace_1.png)
- [游戏试演](screenshots/workspace_2.png)
- [桌宠设置](screenshots/workspace_3.png)
- [125% UI 缩放](screenshots/dpi_125.png)
- [150% UI 缩放](screenshots/dpi_150.png)
- [桌宠透明帧缓冲](screenshots/desktop_window.png)

## 2026-11-13 验证边界

Windows Computer Use 原生连接不可用，已重试一次；截图和交互状态验证由 Godot 内部测试驱动完成。
桌宠画面来自实际窗口的渲染缓冲，并检查透明 alpha；未以编辑器中的缩略预览代替它。

尚未完成：人工真实鼠标跨窗口拖放、对下层应用的点击穿透、多显示器切换、不同物理电脑、
真实系统 DPI 切换、全新未安装 Godot 的机器、长时间运行与大素材性能测试。
当前验证证明便携文件齐全和同机独立执行，不声称覆盖全部 Windows 环境。

受限执行环境中的无窗口 Godot 会报告无法读取系统证书，构建编辑器可能报告无法写入全局
编辑器设置。这些环境消息未造成脚本检查、构建或应用自检失败；实际 OpenGL 验收日志不含脚本错误。
截至当日，PSD、物理与其他未接入模块没有参与验收；后续状态以本文较新的日期记录和
docs/roadmap.md 为准。

## 2026-11-23 Kiki 兽人立绘适配

- 美术使用 Tyson Tan 的 Chibi Kiki II（Krita 吉祥物，CC BY-SA 4.0），保留原始透明 PNG、
  来源摘要与许可。以完整立绘适配，不含独立四肢、耳朵和尾巴的骨骼动画。
- `tests/kiki_test.gd` 实际 OpenGL 窗口：41 项通过，0 失败。覆盖默认角色、200×240 透明
  素材、六个动作逐帧非空与不裁切、实际画面变化、三个编辑器尺寸、存取和三种导出的署名/许可。
- 验证插画的平滑采样、切回像素角色的最近邻采样；游戏显示倍率为 0.75，不缩放碰撞体。
  非数值、零和过大的倍率会被工程校验拒绝。未声明倍率的旧角色继续使用 2 倍。
- 核心套件 `tests/run_tests.gd`：75 项通过；骨骼与 PSD 套件 `tests/rig_import_test.gd`：
  28 项通过。`tests/desktop_test.gd` 使用 Kiki 的真实透明窗口：0 失败，包含托盘、拖动、
  右键缩放、置顶、失焦释放与透明像素检查。
- 本机报告：`build/kiki-verification.json`；实际渲染帧、编辑器与游戏截图在报告的 `output`
  目录。`tools/art/review_kiki.py` 从这些实际帧生成 `build/previews/kiki-motion.gif`。
- 修复独立桌宠从项目外工作目录启动时的原生库加载路径：构建、分发和用户导出保留
  `platform/windows/bin/rigpop_windows.dll`。发布包验证增加真实窗口启动，避免无窗口模式
  跳过托盘集成而漏检此问题。

本次没有可用的图片生成工具；交付采用上述已有授权原画，不声称是 AI 生成或 RigPop 原创角色。
悬浮和问候使用整体位移/旋转，不代表逐帧踏步或分部件动作已经完成。
