# RigPop

<img src="assets/rigpop-icon.png" alt="RigPop 图标" width="128" height="128">

[English](README.md) | 简体中文

面向像素角色、动画与桌宠创作的 Windows 桌面编辑器。
在同一个工程中制作角色，导出 Godot 角色包或可独立运行的 Windows 桌宠。

RigPop 当前为早期 Demo，应用界面使用简体中文。

## 功能

- 使用独立部件或完整精灵帧创建角色。
- 内置三头身 OC 底模，可单独绘制各段四肢并替换服装与配饰，也可选择立绘模板。
- 导入 PSD 分层素材，预览并调整骨骼匹配，保留原画位置与源文件。
- 编辑像素与色板，导入图片并切分规则图集。
- 使用位置、旋转关键帧、逐帧换图和叠加轨道制作动画。
- 配置键鼠绑定，分别进行游戏试演与桌宠试演。
- 桌宠可从系统托盘控制。普通模式支持后台动作和移动，前台应用可继续打字。聚焦模式接收桌宠控制，固定模式锁住位置并允许鼠标穿透。
- 用按键切换持续表情或姿势，为不同状态设置专属动作，或在坐下时限制移动和跳跃。一次性动作播完后再接收新指令。
- 将可编辑工程保存为可迁移的 JSON 与 PNG 文件。
- 导出可编辑工程、Godot 角色包和 Windows 桌宠目录包。

## 下载

下载 **0.1.2 Windows 便携版**。[RigPop-0.1.2-win64.zip](https://github.com/LittleCxwx/RigPop/releases/download/v0.1.2/RigPop-0.1.2-win64.zip) · [发布说明与校验值](https://github.com/LittleCxwx/RigPop/releases/tag/v0.1.2)

1. 将整个压缩包解压到可写文件夹。
2. 双击 `RigPop.exe`。
3. 保留程序旁的 `RigPop.pck`、`rigpop_windows.dll`、`platform/`、`hosts/`、`helpers/` 和许可证文件。

便携版不需要安装 Godot、Python 或开发工具。
页面自动生成的 **Source code** 压缩包用于源码开发。

**运行要求：** Windows 10/11 x64，显卡驱动支持 OpenGL 3.3。

## 开始使用

从模板创建角色或导入自己的图片，在工作区编辑部件与动作，再进行试演或导出。

工程默认保存在程序旁的 `portable_data/` 中。
迁移到其他电脑时，请将每个工程的 JSON 和 PNG 素材一起搬移。

详细的编辑与导出操作见 [使用说明](docs/user_guide.md)。

## 开发

使用 **Godot 4.7.2 stable 标准版**。

1. 克隆或下载本仓库。
2. 在 Godot 中导入根目录 `project.godot`，等待资源导入完成。
3. 按 **F5** 运行应用。

构建 Windows 程序还需要 PowerShell 7，以及供模板下载脚本使用的 Python 3。
构建命令与打包步骤见 [构建与发布](docs/build_and_release.md)。

## 文档

| 文档 | 内容 |
| --- | --- |
| [使用说明](docs/user_guide.md) | 角色编辑、动画、试演与导出 |
| [数据契约](docs/format.md) | 工程数据与导出格式 |
| [构建与发布](docs/build_and_release.md) | Windows 构建、应用图标与程序分发 |
| [开发指南](docs/development.md) | 架构、模块边界与验证 |

## 参与贡献

通过 [GitHub Issues](https://github.com/LittleCxwx/RigPop/issues) 报告问题或讨论改动。
提交代码前请阅读 [Agent.md](Agent.md) 和 [开发指南](docs/development.md)。

## 许可证

RigPop 的原创代码和文档采用 [MIT License](LICENSE)。
第三方组件及另有声明的素材保留各自的许可，详见 [第三方声明](THIRD_PARTY_NOTICES.md)。

用户导入或创作的图片与角色，其权利仍归相应权利人所有。
