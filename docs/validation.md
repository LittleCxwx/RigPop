# RigPop 0.1.0 验收记录

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
PSD、物理与其他未接入模块没有参与验收，其状态见 README 的未完成清单。
