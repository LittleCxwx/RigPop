# RigPop 0.1.0 验收记录

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

## 验证边界

Windows Computer Use 原生连接不可用，已重试一次；截图和交互状态验证由 Godot 内部测试驱动完成。
桌宠画面来自实际窗口的渲染缓冲，并检查透明 alpha；未以编辑器中的缩略预览代替它。

尚未完成：人工真实鼠标跨窗口拖放、对下层应用的点击穿透、多显示器切换、不同物理电脑、
真实系统 DPI 切换、全新未安装 Godot 的机器、长时间运行与大素材性能测试。
当前验证证明便携文件齐全和同机独立执行，不声称覆盖全部 Windows 环境。

受限执行环境中的无窗口 Godot 会报告无法读取系统证书，构建编辑器可能报告无法写入全局
编辑器设置。这些环境消息未造成脚本检查、构建或应用自检失败；实际 OpenGL 验收日志不含脚本错误。
PSD、物理与其他未接入模块没有参与验收，其状态见 docs/roadmap.md 的未完成清单。
