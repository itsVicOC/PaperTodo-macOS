<div align="center">

# PaperTodo for macOS

**让桌面上有几张安静、可用、不打扰人的纸。**

PaperTodo 的原生 macOS/AppKit 版本。这个仓库只维护 macOS 版；Windows 版、Windows 下载和 Windows 源码请前往原作者仓库：[snownico0722/PaperTodo](https://github.com/snownico0722/PaperTodo)。

![version](https://img.shields.io/badge/version-v2.0rc2-3b82f6) ![platform](https://img.shields.io/badge/platform-macOS%2013%2B-555) ![UI](https://img.shields.io/badge/UI-AppKit-007aff) ![license](https://img.shields.io/badge/license-MIT-green)

</div>

---

## 定位

PaperTodo 是“桌面上的几张纸”，不是任务管理器、知识库或文档编辑器。它没有主窗口、没有账号、没有同步、没有分类和统计；每张纸都是一个独立的桌面窗口。

macOS 版追求的是原生体验：菜单栏入口、AppKit 无边框纸片、系统输入法、系统外观、Login Items、Spaces 策略和 ad-hoc 签名的开源分发路径。

## 功能

- **菜单栏应用**：默认无 Dock 图标，通过菜单栏显示全部、隐藏全部、新建纸片、打开设置和退出。
- **多张独立纸片**：待办纸和笔记纸都是独立窗口，自动保存内容、位置、尺寸、置顶和折叠状态。
- **待办纸**：支持勾选、编辑、删除、清理已完成、回车新增、空行退格删除、多行粘贴拆分、拖拽排序、拖到底部删除、撤销/重做。
- **笔记纸**：使用原生 `NSTextView`，支持轻量 Markdown 显示、格式快捷键、右键格式菜单、链接打开、正文缩放和外部编辑同步。
- **胶囊模式**：纸片可折叠为胶囊；贴边胶囊支持右侧自动排列、悬停滑出、拖拽重排和主胶囊一键收纳。
- **待办关联笔记**：可把笔记关联到待办项，并从待办行快速打开或取消关联。
- **主题和配色**：支持跟随系统、浅色、深色，以及暖纸、墨、林、霞四套配色。
- **多语言界面**：中文、英文、日文、韩文，默认跟随系统语言。
- **开机自启动**：使用 macOS Login Items，可在设置中启用。
- **数据导入**：支持导入原 Windows 版 `data.json`，导入失败不会覆盖当前数据。

## Markdown 范围

笔记纸只做轻量显示和编辑辅助，支持标题、加粗、斜体、删除线、无序列表、有序列表、任务列表、引用、分割线、行内代码、代码块、链接，以及少量单行内联 HTML 标签（`b/strong/i/em/s/del/u/code/a href`）。

不支持图片、表格、附件、嵌入内容、块级 HTML 或完整块编辑器。

## 数据位置

macOS 版默认把数据保存到：

```text
~/Library/Application Support/PaperTodo/
├─ data.json
└─ data.backup.json
```

`data.json` 是用户数据协议，不是内部缓存。发布版和开发版都会尽量兼容旧字段，并避免在加载失败时用空状态覆盖旧数据。

## 启动参数

打包后的可执行文件支持这些命令。应用已运行时，后续进程会把命令转发给主实例并退出：

```sh
PaperTodoMac --show
PaperTodoMac --hide
PaperTodoMac --toggle
PaperTodoMac --new-todo
PaperTodoMac --new-note
PaperTodoMac --import /path/to/data.json
PaperTodoMac --exit
```

别名包括 `open` = `show`、`todo` = `new-todo`、`note` = `new-note`、`quit` = `exit`。

## 下载与安装

这个仓库没有 Apple Developer ID。GitHub Release 提供的是开源分发用的未公证 macOS 包：

- `PaperTodo-v<version>-macos-<arch>-unnotarized.app.zip`
- `README-macOS-unnotarized.txt`
- `SHA256SUMS.txt`
- Sigstore keyless 签名文件（`.sig` / `.crt`）

首次打开可能被 Gatekeeper 拦截。确认下载来源可信后，可以在 Finder 中按住 Control 点击 `PaperTodo.app` 选择“打开”，或按发布包内 `README-macOS-unnotarized.txt` 的说明处理。建议把 `PaperTodo.app` 移到 `/Applications` 后再启用开机自启动。

Windows 版本不在本仓库发布；请使用原作者仓库：[snownico0722/PaperTodo](https://github.com/snownico0722/PaperTodo)。

## 构建

要求：

- macOS 13 或更高版本
- Xcode 或 Command Line Tools 提供的 Swift 工具链

从仓库根目录运行：

```sh
cd macos/PaperTodoMac
swift test
./scripts/build-app.sh
./scripts/package-release.sh
```

`build-app.sh` 会生成：

```text
macos/PaperTodoMac/.build/PaperTodo.app
```

`package-release.sh` 会生成：

```text
macos/PaperTodoMac/.build/release-assets/
├─ PaperTodo-v<version>-macos-<arch>-unnotarized.app.zip
├─ README-macOS-unnotarized.txt
└─ SHA256SUMS.txt
```

沙盒或 CI 环境中如果默认缓存目录不可写，可使用项目内缓存：

```sh
cd macos/PaperTodoMac
mkdir -p .build/cache .build/config .build/security .build/clang-module-cache .build/tmp .build/home
HOME="$PWD/.build/home" \
CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-module-cache" \
TMPDIR="$PWD/.build/tmp" \
swift test --disable-sandbox \
  --cache-path .build/cache \
  --config-path .build/config \
  --security-path .build/security \
  --manifest-cache local \
  -Xcc -fmodules-cache-path="$PWD/.build/clang-module-cache"
```

## 发布

Release workflow 只构建 macOS `.app.zip`。推送 `v*` tag 或手动运行 workflow 时，会：

1. 运行 Swift 测试。
2. 打包 ad-hoc signed、unnotarized 的 macOS `.app.zip`。
3. 生成 SHA256 校验文件。
4. 使用 Sigstore keyless 签名发布资产。
5. 从 `CHANGELOG.md` 中提取对应 `### v<tag>` 小节作为 Release notes。

## 许可证

本仓库 macOS 代码使用 [MIT License](LICENSE) 开源。

PaperTodo 原 Windows 版由 [snownico0722/PaperTodo](https://github.com/snownico0722/PaperTodo) 维护；Windows 相关源码、下载、截图和说明请以原作者仓库为准。
