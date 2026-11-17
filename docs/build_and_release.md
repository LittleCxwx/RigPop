# 构建与发布

## 下载程序与下载源码

普通用户到 [GitHub Releases](https://github.com/LittleCxwx/RigPop/releases) 的 Assets 下载
`RigPop-<版本>-win64.zip`，完整解压后双击 `RigPop.exe`。不需要安装 Godot、Python 或开发工具。
不要下载自动生成的 Source code ZIP 来运行程序，也不要只复制 EXE。

源码仓库只保存可编辑源文件。`build/`、`.godot/`、测试输出和 `portable_data/` 没有上传，
所以另一台电脑下载源码时不会看到这些本机生成文件，这是正常的。相同提交的受版本管理文件
应一致；资源缓存由 Godot 自动重建，Windows 程序需要重新构建。用户作品需单独迁移。

## 在另一台电脑打开源码

1. 克隆仓库，或者下载对应版本的 Source code ZIP 并解压。
2. 下载并完整解压 **Godot 4.7.2 stable Windows x86_64 标准版**。本工程不需要 .NET 版。
3. 在 Godot 项目管理器中导入根目录 `project.godot`，等待资源导入完成。
4. 按 F5 运行编辑器；主场景是 `editor/main.tscn`。

只编辑和运行源码不需要导出模板。要在源码模式下试演或导出桌宠，需先构建 `hosts/` 宿主。
Godot 主程序和同一 ZIP 内的 console 程序应放在一起，不要只拷贝 console 程序。

## 本机构建 Windows 便携包

构建者需安装 PowerShell 7、Godot 4.7.2 与 Python 3。Python 只用于首次下载模板，
不会成为最终用户的运行依赖。进入解压或克隆的仓库根目录，使用自己的 Godot 实际路径：

```powershell
$godot = 'C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe'

# 首次下载对应 Windows release 模板；以后可复用 build/templates/。
python ./tools/download_windows_template.py

# 构建创作应用和桌宠宿主。
./tools/build.ps1 -Godot $godot

# 打包并在源码目录之外解压、执行成品自检。
./tools/package.ps1
./tools/verify_package.ps1
```

当前产物为 `build/RigPop.exe`、`build/RigPop.pck`、`build/hosts/`、
`build/RigPop-0.1.0-win64.zip` 和 `build/SHA256SUMS.txt`。
ZIP 文件名从构建时读取的 `project.godot` 应用版本生成，不需要手动改打包脚本。
重新打包使用独立暂存目录和明确的文件清单，不会把旧发布目录中的用户作品带进去。

`verify_package.ps1` 会将 ZIP 解压到独立临时目录，只运行其中的成品程序；检查依赖、
保存重开、三种导出和导出的桌宠 EXE 启动。报告在 `build/release-verification.json`。
这属于同一台电脑上的独立目录验证，不能替代不同物理电脑的兼容性验收。

## 换成自己的图标

准备一张透明背景的正方形 PNG，推荐 256×256 或更大；也可以使用有效的多尺寸 ICO。

```powershell
./tools/build.ps1 -Godot $godot -Icon 'C:\MyArt\RigPop.png'
./tools/package.ps1
./tools/verify_package.ps1
```

脚本将图标复制到工程内 `assets/rigpop-icon.png` 或 `.ico`，并更新 `project.godot` 的图标设置。
Windows 导出会将图标写入 EXE，Godot 窗口也使用相应设置。无需另外安装 rcedit。
图标和项目设置一起提交后，另一台电脑及 GitHub 构建会沿用它，不依赖原始绝对路径。
后续普通构建无需反复传 `-Icon`，会沿用项目中配置的 `assets/rigpop-icon.png`。
像素图标在两个 Windows 导出预设中使用最近邻缩放，保持小尺寸图标的像素边缘。

图标只是应用外观，与代码签名不同。当前构建没有数字签名或安装器，使用完整解压的便携包。

## 上传到 GitHub Releases

已提供 `.github/workflows/windows-release.yml`。在 GitHub 的 Actions 页面选 **Windows Release**，
点击 **Run workflow** 可构建并下载测试产物；普通分支手动运行不会自动建立公开 Release。

需要发布版本时，先更新应用及相关文档版本并提交，再推送与 `config/version` 一致的版本标签：

```powershell
git push origin main
git tag -a v0.1.0 -m 'RigPop 0.1.0 Demo'
git push origin v0.1.0
```

标签示例仅在 `v0.1.0` 尚未存在时使用。后续版本使用新的版本号，不覆盖旧标签或已发布资源。
工作流在 Windows 上下载锁定版本的 Godot 和模板、构建、执行源码检查、打包、验证成品，
通过后建立标为预览版的 GitHub Release，并附上 ZIP 和 SHA-256 文件。
使用仓库自动提供的 `GITHUB_TOKEN`，不需要在源码中写入私人令牌。

也可手动在 Releases 中创建版本，把已验证的 ZIP 与 `SHA256SUMS.txt` 拖入 Assets 后发布。
`build/` 继续由 Git 忽略，程序包通过 Releases 分发，不放进源码提交。
