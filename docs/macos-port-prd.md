# PaperTodo macOS 移植 PRD

状态：Implemented baseline / 继续迭代
日期：2026-06-16，2026-06-19 更新
目标平台：macOS 13 Ventura 及以上，优先适配 Apple Silicon，兼容 Intel
前提约束：无 Apple Developer ID，项目继续开源

## 1. 背景

PaperTodo 当前是 Windows 桌面便签工具，产品形态是“桌面上的几张纸”：没有主窗口、没有账号、没有管理器，每张纸是独立窗口。当前实现基于 .NET 10 / WPF，并使用 AvalonEdit、Hardcodet.NotifyIcon.Wpf、Windows 注册表和 Win32 API。

移植到 macOS 的目标不是把现有 WPF 工程直接编译到 macOS，而是保留产品理念、功能和视觉设计，用 macOS 原生技术重建客户端。现有数据协议、状态模型、交互规则和部分文本处理逻辑可以作为规格来源。

当前仓库已收敛为只维护 macOS 版。Windows 版、Windows 下载和 Windows 源码说明统一指向原作者仓库：https://github.com/snownico0722/PaperTodo

## 2. 结论

macOS 移植可行，但属于“原生重写”，不是小规模平台适配。

推荐技术路线：

- 使用 Swift + AppKit 作为主技术栈。
- 使用 SwiftUI 承载设置页、简单弹窗和局部表单。
- 使用 AppKit 的 `NSStatusItem` 实现菜单栏入口。
- 使用 `NSPanel` / `NSWindow` 实现独立纸片、胶囊和无 Dock 主窗口体验。
- 使用 `NSTextView` + TextKit 2 或 TextKit 1 自定义轻量 Markdown 伪渲染。
- 仓库维护面只保留 macOS 原生工程；Windows 版作为兼容参考和数据导入来源。

不推荐路线：

- 继续 C# WPF：WPF 是 Windows 桌面框架，不能在 macOS 原生运行。
- Avalonia / .NET MAUI：可提高 C# 复用，但难以做到最高等级的 macOS 原生窗口、菜单栏、Space、文本编辑和系统行为融合。
- Electron / Tauri：与原项目“原生、轻、不打扰”的产品约束冲突，且窗口层级和桌面贴边体验仍需平台原生桥接。

## 3. 产品目标

### 3.1 核心目标

1. 保留 PaperTodo 的产品边界：桌面纸片优先，无账号、无同步、无主管理页。
2. 保留 Windows 版全部核心功能、设计语言和数据语义。
3. 提供 macOS 原生体验：菜单栏入口、系统外观跟随、原生文本输入、原生窗口行为、原生开机启动。
4. 支持从 Windows 版 `data.json` 导入并尽量保持兼容。
5. 保持开源，可由用户从源码构建。
6. 在没有 Developer ID 的前提下提供清晰、诚实、可验证的安装和运行路径。

### 3.2 非目标

1. 不做 Mac App Store 发布。
2. 不做账号、云同步、分类、标签、搜索、归档、提醒、统计、日历。
3. 不把 macOS 版做成通用跨平台 UI 壳。
4. 不承诺未签名/未公证二进制获得与 Developer ID 公证应用相同的首次运行体验。
5. 不改变 Windows 版既有数据协议，除非以兼容迁移方式演进。

## 4. 用户与场景

### 4.1 目标用户

- 使用 macOS 工作、希望在桌面保留临时待办和轻量笔记的用户。
- 偏好本地、离线、无账号、无同步工具的用户。
- 能接受开源软件手动安装流程的用户。
- 需要在多显示器、外接屏和不同 Space 中保持小型桌面纸片的用户。

### 4.2 核心使用场景

1. 用户启动应用后，只在菜单栏看到 PaperTodo 图标，没有主窗口打扰。
2. 用户新建待办纸，直接在桌面写下当天任务。
3. 用户新建笔记纸，记录普通文本或轻量 Markdown。
4. 用户将纸片折叠成胶囊，保持桌面整洁。
5. 用户启用高级胶囊，让折叠纸片贴到屏幕右侧，悬浮时滑出。
6. 用户把某张笔记关联到待办项，并能从待办项打开关联笔记。
7. 用户重启应用后，纸片内容、位置、尺寸、折叠、置顶和设置完整恢复。
8. 用户通过菜单栏菜单隐藏全部、显示全部、新建纸片、打开设置或退出。

## 5. 当前项目事实

### 5.1 不能直接移植的依据

- `PaperTodo.csproj` 使用 `net10.0-windows` 和 `UseWPF=true`。
- 窗口、控件、动画和资源大量依赖 `System.Windows.*`。
- 托盘入口依赖 `Hardcodet.NotifyIcon.Wpf`。
- Markdown 编辑器继承 AvalonEdit 的 WPF `TextEditor`。
- 开机启动依赖 Windows 注册表。
- 全屏检测、置顶刷新、非激活点击、鼠标钩子和工作区计算依赖 `user32.dll` / `kernel32.dll`。
- GitHub Actions 当前只构建和发布 macOS 未公证 `.app.zip`。

### 5.2 可复用资产

- 产品理念、信息架构、功能定义。
- `data.json` 协议和字段语义。
- `AppState` / `PaperData` / `PaperItem` 模型。
- 保存策略：主文件、备份文件、临时文件替换、崩溃恢复。
- 启动命令语义：show、hide、toggle、new-todo、new-note、exit。
- Markdown 支持范围和伪渲染规则。
- 四套配色方案和浅色/深色/系统主题概念。
- 多语言资源内容。
- 原 Windows 版演示图和动图作为外部视觉参考，来源以原作者仓库为准。

## 6. macOS 产品形态

### 6.1 应用形态

PaperTodo for macOS 是菜单栏应用。默认不显示 Dock 图标，不提供传统主窗口。全局入口是菜单栏图标。

实现要求：

- `Info.plist` 设置为 Agent 类应用，避免默认 Dock 图标。
- 菜单栏图标常驻，可打开上下文菜单。
- 双击/点击行为按 macOS 习惯调整：菜单栏单击打开菜单，菜单项提供显示全部、新建、设置等动作。
- 如未来需要调试或辅助访问，可提供隐藏偏好项“显示 Dock 图标”，但不作为首版功能。

### 6.2 纸片窗口

每张纸是独立的无边框透明窗口，保留原项目“桌面纸片”的核心体验。

窗口要求：

- 使用 `NSPanel` 或自定义 `NSWindow`。
- 无标题栏、无标准红黄绿按钮。
- 支持拖动、缩放、置顶、隐藏、关闭即隐藏。
- 支持保存和恢复位置、尺寸、显示状态、折叠状态。
- 支持多显示器和工作区边界修正。
- 支持浅色/深色/系统主题。
- 支持动画开关。

macOS 特别约束：

- macOS 的全屏应用处在独立 Space 中，普通窗口不能无条件覆盖所有全屏 Space。
- “置顶”在 macOS 上应定义为：在当前 Space 内保持浮动层级；是否跨 Space 展示需要明确策略。
- 首版建议默认不跨所有 Space，避免用户在全屏演示、视频、会议中被纸片打扰。
- 设置中可提供“在所有桌面显示纸片”选项，对应 `canJoinAllSpaces`，并提示该行为可能影响全屏体验。

### 6.3 胶囊模式

保留普通胶囊和高级贴边胶囊。

普通胶囊：

- 折叠后变为小型浮动胶囊。
- 胶囊显示纸片类型和短标题。
- 点击或悬浮按现有交互展开。
- 保留置顶状态和可见状态语义。

高级贴边胶囊：

- 胶囊自动排列到当前屏幕右侧。
- 悬浮时滑出，离开时缩回。
- 支持重排。
- 支持“展开时保留边缘胶囊”。
- 支持“收起全部主胶囊”。
- 支持“已关联笔记不显示为胶囊”。

macOS 风险：

- 屏幕右侧可能与 Stage Manager、外接屏边界、菜单栏、Dock 自动隐藏区域冲突。
- 需要按 `NSScreen.visibleFrame` 和实际鼠标屏幕坐标计算。
- 多屏场景下应以纸片当前所在屏幕为胶囊归属屏幕，不能统一塞到主屏幕。

## 7. 功能需求

### FR-001 菜单栏入口

优先级：P0

需求：

- 应用启动后显示菜单栏图标。
- 菜单展示版本、显示全部、隐藏全部、新建待办、新建笔记、设置、纸片列表、退出。
- 菜单打开时动态重建，反映当前纸片状态。
- 支持自定义图标：若应用支持用户替换图标，应优先使用用户指定资源，否则使用内置图标。

验收：

- 无主窗口、无 Dock 图标。
- 应用运行时菜单栏图标可用。
- 菜单中的纸片列表可定位/显示对应纸片。

### FR-002 多张独立纸片

优先级：P0

需求：

- 支持创建多张待办纸和笔记纸。
- 每张纸独立窗口、独立位置、独立尺寸、独立置顶状态。
- 纸片关闭仅隐藏，不删除。
- 删除需二次确认。
- 首次启动无数据时创建默认待办纸。

验收：

- 创建、隐藏、显示、删除、恢复流程与 Windows 版语义一致。
- 重启后恢复全部未删除纸片。

### FR-003 待办纸

优先级：P0

需求：

- 一行一个事项。
- 支持新增、编辑、勾选、删除、清理已完成。
- 支持拖动排序。
- 支持拖拽到底部删除。
- 支持多行粘贴并拆成多条事项。
- 支持撤销/重做。
- 支持待办关联笔记。

实现建议：

- 首版使用 `NSTableView` / SwiftUI List 均可，但拖拽排序、稳定行高、原生文本编辑和复杂 hover 操作更适合 AppKit。
- 每条待办项内部使用 `NSTextField` 或轻量自定义 row view。

验收：

- 多行粘贴只产生一次撤销快照。
- 拖动排序后保存顺序。
- 重启后勾选、文本和关联笔记恢复。

### FR-004 笔记纸与 Markdown 轻量显示

优先级：P0

需求：

- 支持普通文本编辑。
- 支持三档 Markdown 显示模式：off、basic、enhanced。
- 支持标题、加粗、斜体、删除线、无序列表、有序列表、引用、分割线、行内代码、代码块、链接。
- 支持少量单行内联 HTML 标签：b/strong/i/em/s/del/u/code/a href。
- 不支持图片、表格、附件、嵌入内容、块级 HTML 或完整块编辑器。
- 支持 Ctrl/Cmd+B、Cmd+I、Cmd+K、撤销/重做。
- 支持正文缩放。
- 支持点击链接用默认浏览器打开。
- 支持外部默认编辑器打开临时文件。

macOS 快捷键调整：

- Windows `Ctrl+B/I/K/Z/Y` 对应 macOS `Cmd+B/I/K/Z/Shift+Cmd+Z`。
- 保留 Ctrl + 滚轮缩放的等价能力；建议 macOS 使用 `Cmd + 滚轮` 或触控板 pinch 后续评估。

实现建议：

- 使用 `NSTextView` + attributed string。
- 自定义 Markdown 增量解析器，只做当前项目支持范围。
- 对代码块、引用、列表符号和链接做绘制层/属性层处理。
- 避免 WebView，保持原生文本输入和低开销。

验收：

- Markdown 支持范围的测试样例展示效果接近 Windows 版。
- 输入法、选区、撤销、滚动、链接点击稳定。
- 大文本达到长度保护阈值时不造成布局卡死。

### FR-005 待办关联笔记

优先级：P0

需求：

- 可将笔记拖到待办项上建立关联。
- 待办项显示打开关联笔记入口。
- 设置项控制是否显示关联笔记名称。
- 删除笔记时清理待办中的无效关联。
- 关闭关联功能时保留或清理行为需与 Windows 版兼容。

验收：

- 拖拽关联、打开关联、删除关联笔记后的状态一致。
- `HideLinkedNotesFromCapsules` 生效。

### FR-006 主题和配色

优先级：P0

需求：

- 支持跟随系统、浅色、深色。
- 保留暖纸、墨、林、霞四套配色。
- 主题变化时刷新纸片、胶囊、菜单、设置窗口和 Markdown 文本。

实现建议：

- 监听 `effectiveAppearance` 变化。
- 配色保存在状态文件中。

验收：

- 系统主题切换后，已打开窗口实时更新。
- 菜单栏菜单重新打开后反映当前主题。

### FR-007 开机启动

优先级：P0

需求：

- 设置页提供随 macOS 登录启动。
- 不使用 Windows 注册表。
- 使用 macOS 原生 Login Item 能力。

实现建议：

- macOS 13+ 使用 `SMAppService`。
- 无 Developer ID 场景下，开发构建和用户本地构建需要单独验证登录项注册行为。
- 若未公证发行版在某些系统版本上无法稳定注册登录项，设置页应展示失败原因并建议用户手动添加到 Login Items。

验收：

- 开关能正确反映当前登录项状态。
- 启用后重新登录能自动启动。
- 失败时不崩溃，给出可理解错误。

### FR-008 单实例与启动命令

优先级：P1

需求：

- 不允许同时运行多个主实例。
- 后续启动带参数时转发给主实例。
- 支持 show、hide、toggle、new-todo、new-note、exit。

实现建议：

- 使用本地 Unix domain socket、Distributed Notification 或 XPC helper。
- 对命令行启动，可提供 `papertodo` CLI shim，但首版可只支持 `.app` 内部命令处理。

验收：

- 重复打开 `.app` 不产生第二个状态写入进程。
- 命令转发失败时不破坏数据。

### FR-009 数据存储与迁移

优先级：P0

需求：

- macOS 原生数据目录：`~/Library/Application Support/PaperTodo/`。
- 主数据文件仍为 `data.json`。
- 保留 `data.backup.json`。
- 崩溃恢复写入 `data.crash_recovery.json`。
- 首次启动可从应用目录、Downloads 或用户选择的 Windows 版 `data.json` 导入。
- 字段名和语义尽量兼容 Windows 版 camelCase JSON。

验收：

- Windows 版数据文件可导入。
- 解析失败不会用空状态覆盖旧数据。
- 保存使用临时文件替换，异常时保留备份。

### FR-010 设置页

优先级：P0

需求：

- 原有设置全部保留：外观、待办与笔记、顶栏按钮、外部打开、胶囊、启动项、提示、动画。
- macOS 设置页使用原生窗口和表单控件。
- 设置变更实时作用于已打开窗口。

验收：

- 设置内容与 Windows 版功能等价。
- 所有用户可见文案支持本地化。

### FR-011 多语言

优先级：P1

需求：

- 保留中文、英文、日文、韩文。
- 默认跟随系统语言。
- 所有新增 macOS 专属文案也需要四语同步。

验收：

- 切换系统语言或应用语言后，菜单、设置、弹窗和工具提示可正确显示。

### FR-012 外部打开

优先级：P1

需求：

- 笔记纸可写入临时文件并用系统默认应用打开。
- 文件后缀由用户设置，默认 `.md`。
- 后缀只做文件名合法性校验，允许用户选择系统已关联的任意后缀。

验收：

- 默认 `.md` 使用系统关联应用打开。
- 自定义后缀后按新后缀打开。
- 打开失败不影响当前笔记。

## 8. 设计要求

### 8.1 视觉继承

macOS 版应继承 PaperTodo 的“纸片”设计，而不是变成标准 macOS Notes。

要求：

- 纸张质感、轻边框、轻阴影、柔和配色保留。
- 交互按钮保持低存在感。
- 胶囊尺寸、圆角、标题策略和右侧贴边体验尽量与 Windows 版一致。
- 不增加主列表页，不增加复杂侧边栏。

### 8.2 macOS 原生化

要求：

- 快捷键使用 Command 体系。
- 菜单栏入口符合 macOS 用户预期。
- 文本输入、光标、选区、输入法、拼写检查按 macOS 原生习惯处理。
- 设置窗口使用 macOS 风格控件。
- 系统外观、屏幕缩放、多显示器和 Space 变化时行为稳定。

### 8.3 行为边界

需要明确告知并测试：

- 全屏 Space 中是否显示纸片。
- 是否跨所有桌面显示。
- Stage Manager 开启时胶囊贴边是否仍可用。
- Dock 位于左/右/底部时贴边区域如何避让。
- 菜单栏自动隐藏时工作区计算如何处理。

## 9. 技术架构

### 9.1 推荐模块

```text
PaperTodoMac/
├─ App/
│  ├─ PaperTodoApp.swift
│  ├─ AppDelegate.swift
│  └─ Info.plist
├─ Core/
│  ├─ AppState.swift
│  ├─ PaperData.swift
│  ├─ StateStore.swift
│  ├─ StartupCommand.swift
│  └─ PaperTitles.swift
├─ SystemIntegration/
│  ├─ StatusBarController.swift
│  ├─ LoginItemService.swift
│  ├─ SingleInstanceService.swift
│  ├─ WorkspaceObserver.swift
│  └─ ExternalOpenService.swift
├─ PaperUI/
│  ├─ PaperPanel.swift
│  ├─ PaperWindowController.swift
│  ├─ TodoPaperView.swift
│  ├─ NotePaperView.swift
│  ├─ CapsulePanel.swift
│  └─ DeepCapsuleCoordinator.swift
├─ Markdown/
│  ├─ MarkdownTextView.swift
│  ├─ MarkdownParser.swift
│  ├─ MarkdownRenderer.swift
│  └─ MarkdownLinkDetector.swift
├─ Settings/
│  ├─ SettingsWindow.swift
│  └─ SettingsView.swift
└─ Resources/
   ├─ Localizable.strings
   ├─ Assets.xcassets
   └─ ColorSchemes.swift
```

### 9.2 核心设计

Core 层不依赖 AppKit。窗口、菜单栏、登录项、Space 观察和外部打开全部放在 SystemIntegration / PaperUI。

状态流：

1. `AppDelegate` 初始化单实例服务。
2. `StateStore` 加载状态。
3. `StatusBarController` 创建菜单栏图标。
4. `PaperWindowController` 根据状态恢复纸片。
5. 用户操作更新内存状态。
6. `StateStore` 防抖保存，退出时同步保存。

### 9.3 数据兼容

Swift 模型必须使用与 Windows 版一致的 JSON key：

- `papers`
- `theme`
- `colorScheme`
- `markdownRenderMode`
- `externalMarkdownExtension`
- `zoom`
- `useCapsuleMode`
- `useDeepCapsuleMode`
- `showTopBarNewTodoButton`
- `showTopBarNewNoteButton`
- `showTopBarExternalOpenButton`
- `enableTodoNoteLinks`
- `showLinkedNoteName`
- `hideLinkedNotesFromCapsules`
- `maxTitleLength`
- `useCapsuleCollapseAll`
- `capsuleCollapseAllActive`
- `showDeepCapsuleWhileExpanded`
- `enableAnimations`
- `enableToolTips`

Paper 字段：

- `id`
- `type`
- `title`
- `x`
- `y`
- `width`
- `height`
- `isVisible`
- `alwaysOnTop`
- `isCollapsed`
- `textZoom`
- `items`
- `content`

Item 字段：

- `id`
- `text`
- `done`
- `order`
- `linkedNoteId`

## 10. 无 Developer ID 分发策略

### 10.1 事实约束

没有 Apple Developer ID 意味着：

- 不能使用 Developer ID Application 证书完成面向普通用户的标准 macOS 分发签名。
- 不能完成 Apple notarization 的常规外部分发流程。
- GitHub Release 中的预编译 `.app` / `.dmg` 即使经过 ad-hoc 签名，也会在用户首次运行时触发 Gatekeeper 拦截或警告。
- 用户需要通过右键 Open、系统设置中的 Open Anyway，或从源码本地构建来运行。

这不是开源项目独有问题，而是 macOS 平台分发安全模型带来的约束。

### 10.2 首版分发渠道

P0 渠道：源码构建

- 仓库提供完整 Xcode project / Swift Package。
- README 提供 `xcodebuild` 和 Xcode GUI 构建步骤。
- 用户从源码构建的本地产物可直接运行，适合开发者和开源用户。

P1 渠道：GitHub Release 未公证构建

- GitHub Actions 构建 `.app.zip` 和可选 `.dmg`。
- 使用 ad-hoc codesign：`codesign --force --deep --sign - PaperTodo.app`。
- 发布 SHA256SUMS。
- 可继续使用 Sigstore/cosign 对发布资产做透明签名，证明资产来自 GitHub Actions，而不是 Apple 代码签名。
- Release notes 必须明确写明“未使用 Apple Developer ID，未 notarized”。
- README 提供官方支持页面对应的手动放行说明链接。

P2 渠道：Homebrew

- 首选 Homebrew Formula 从源码构建，降低下载未公证二进制的疑虑。
- 若发布 Cask，仍会遇到未公证二进制的 Gatekeeper 体验问题，需要在说明中明确。

P3 渠道：未来 Developer ID

- 如果后续获得 Developer ID，可增加签名、公证和 Sparkle 更新。
- 该路径不应成为首版上线的前置条件。

### 10.3 安全与信任

要求：

- 所有发布资产必须有 SHA256。
- GitHub Actions workflow 固定 macOS runner 和 Xcode 版本。
- Release 页面写清楚构建来源、签名状态、校验方式。
- 不诱导用户关闭 Gatekeeper。
- 不使用绕过安全策略的安装脚本。
- 不把未公证状态包装成“已安全认证”。

## 11. 开源计划

### 11.1 License

当前仓库已添加 MIT `LICENSE`。仅公开代码不等于具备开源授权；发布前仍需确认对原项目素材、名称和派生代码的使用满足原作者授权。

决策项：

- 如果希望最大化传播和二次开发，建议 MIT 或 Apache-2.0。
- 如果希望派生版本也必须开源，建议 GPL-3.0。
- 如果你不是原作者，需要获得原作者授权后再移植和发布。

当前决策：

- macOS 仓库采用 MIT License。
- Windows 版维护、下载、源码和历史说明指向原作者仓库。

### 11.2 仓库组织

当前仓库组织：

```text
/
├─ macos/                  # macOS 原生工程
├─ docs/
│  └─ macos-port-prd.md
├─ .github/workflows/
│  └─ release.yml          # macOS-only Release
├─ README.md
├─ CHANGELOG.md
├─ AGENTS.md
└─ LICENSE
```

Windows 相关内容不在本仓库继续维护；README 和 Release notes 只提供原作者仓库链接。

### 11.3 贡献规范

需要新增：

- `CONTRIBUTING.md`
- `CODE_OF_CONDUCT.md`
- `SECURITY.md`
- Issue templates：bug、feature、macOS compatibility。
- PR 模板：是否影响数据协议、是否影响本地化、是否影响发布。

## 12. 实施计划

### Phase 0：授权、规格和原型验证

目标：

- 明确 License。
- 固化数据协议文档。
- 验证无 Dock 菜单栏应用、独立透明纸片、置顶和胶囊贴边在 macOS 的可行性。
- 验证无 Developer ID 的构建、ad-hoc 签名和首次运行说明。

产出：

- `LICENSE`
- `docs/data-schema.md`
- macOS prototype：菜单栏图标 + 一张可拖动纸片 + 保存恢复位置。

验收：

- 可以从源码构建并运行。
- 纸片窗口不显示 Dock 图标。
- 重启后纸片位置恢复。

### Phase 1：macOS 骨架

目标：

- 建立 Xcode 工程。
- 完成 AppDelegate、状态加载、菜单栏、设置窗口、保存层。
- 支持创建/显示/隐藏/删除纸片。

产出：

- `macos/PaperTodoMac.xcodeproj` 或 Swift Package + Xcode project。
- `StateStore` Swift 版本。
- 状态迁移和备份机制。

验收：

- 可以创建多张空纸片。
- 菜单栏菜单可控制纸片。
- 数据写入 `~/Library/Application Support/PaperTodo/data.json`。

### Phase 2：待办纸功能

目标：

- 完成待办项增删改查、勾选、排序、多行粘贴、撤销/重做。
- 完成清理已完成。

验收：

- 待办纸达到 Windows 版核心体验。
- 数据兼容 Windows 字段。

### Phase 3：笔记纸和 Markdown

目标：

- 完成 `NSTextView` 笔记编辑。
- 完成 Markdown 三档显示模式。
- 完成链接点击、格式快捷键、文字缩放、外部打开。

验收：

- Markdown 支持范围的样例渲染正确。
- 中文输入法、日文/韩文输入、撤销、选区稳定。

### Phase 4：胶囊和高级胶囊

目标：

- 完成普通胶囊。
- 完成右侧贴边高级胶囊。
- 完成展开保留边缘胶囊、收起全部主胶囊、关联笔记隐藏胶囊。

验收：

- 多屏、Dock 左/右/底部、菜单栏自动隐藏、Stage Manager 基础场景通过。
- 胶囊动画可关闭。

### Phase 5：系统集成和本地化

目标：

- 完成开机启动。
- 完成单实例与启动命令。
- 完成四语本地化。
- 完成系统主题跟随。

验收：

- 重新登录后可自动启动。
- 重复打开不产生多实例。
- 中文、英文、日文、韩文资源齐全。

### Phase 6：开源发布

目标：

- 完成 GitHub Actions macOS 构建。
- 发布源码构建说明。
- 发布未公证构建和校验文件。
- 明确 Gatekeeper 手动打开说明。

验收：

- Release 包含 `.app.zip`、SHA256SUMS、构建说明。
- README 明确“无 Developer ID / 未 notarized”状态。
- 用户可以从源码构建，也可以手动放行 Release 构建。

## 13. 优先级

P0 必须首版完成：

- 菜单栏入口。
- 多张独立纸片。
- 待办纸核心功能。
- 笔记纸核心编辑。
- 数据保存、备份、导入。
- 主题和配色。
- 设置页。
- 胶囊模式基础能力。
- 源码构建。

P1 首版候选：

- 高级贴边胶囊完整行为。
- Markdown enhanced 伪渲染完整一致。
- 开机启动。
- 单实例命令转发。
- 多语言完整覆盖。
- GitHub Release 未公证构建。

P2 可延后：

- Homebrew。
- 更高级的 Space / Stage Manager 策略。
- 可选 Dock 图标。
- 未来 Developer ID 签名、公证和自动更新。

说明：用户要求“保留所有功能”，因此 P1 不是可永久删除，而是允许在开发排期上晚于 P0 集成；正式 1.0 应全部完成。

## 14. 风险

### R1：macOS 全屏和 Space 行为无法 100% 复刻 Windows

影响：高
概率：高
应对：

- 产品定义上明确“置顶”的 macOS 语义。
- 提供“在所有桌面显示”设置。
- 默认避免打扰全屏应用。
- 针对全屏、Stage Manager、多桌面做验收矩阵。

### R2：无 Developer ID 导致安装体验不顺滑

影响：高
概率：必然
应对：

- 首选源码构建。
- GitHub Release 明确未公证。
- 提供 SHA256 和 Sigstore 校验。
- 提供 Apple 官方“打开未识别开发者应用”说明链接。
- 不承诺一键安装体验。

### R3：Markdown 原生伪渲染工作量高

影响：中高
概率：高
应对：

- 限定支持范围，不扩展图片/表格/完整编辑器。
- 先完成 basic，再完成 enhanced。
- 使用测试样本文档和截图回归。

### R4：胶囊高级交互与 macOS 边界冲突

影响：高
概率：中高
应对：

- 独立做 DeepCapsule prototype。
- 多屏和 Dock 位置作为早期验收条件。
- 胶囊状态机从 UI 中拆出，降低回归风险。

### R5：当前仓库缺少开源许可证

影响：高
概率：已存在
应对：

- Phase 0 必须补 License。
- 如非原作者，先拿授权再发布 macOS 移植。

### R6：Windows 代码和 macOS 代码长期分叉

影响：中
概率：中
应对：

- 用 `shared-spec` 管数据协议、Markdown 行为和产品约束。
- 不强行共享 UI 代码。
- 需要变更数据协议时同时更新两端规范。

## 15. 验收矩阵

### 15.1 设备

- Apple Silicon MacBook。
- Intel Mac。
- 外接显示器。
- Retina 和非 Retina 缩放。

### 15.2 系统

- macOS 13 Ventura。
- macOS 14 Sonoma。
- macOS 15 Sequoia。
- 发布前增加当时最新 macOS 版本验证。

### 15.3 场景

- 单桌面。
- 多桌面 Space。
- 全屏应用 Space。
- Stage Manager 开启/关闭。
- Dock 底部/左侧/右侧。
- 自动隐藏 Dock。
- 自动隐藏菜单栏。
- 浅色/深色/自动外观。
- 中英日韩输入法。
- 从 Windows `data.json` 导入。
- Release 未公证构建首次打开。
- 源码构建首次打开。

## 16. 成功指标

功能指标：

- Windows 版核心功能 100% 有 macOS 对应实现。
- `data.json` 兼容导入成功率达到 100% 针对已知样本。
- 关键用户路径无崩溃：新建、编辑、折叠、恢复、保存、退出。

体验指标：

- 应用常驻时 CPU 空闲占用接近 0。
- 普通纸片操作无明显掉帧。
- 菜单栏和设置体验符合 macOS 习惯。
- 无主窗口、低打扰的产品感保持一致。

开源指标：

- 可从干净 macOS 环境按 README 构建。
- Release 资产可校验。
- 未公证限制有清晰说明，无误导。

## 17. 决策清单

必须在编码前确认：

1. 许可证选择：MIT、Apache-2.0、GPL-3.0 或其他。
2. macOS 最低版本：建议 13.0。
3. 是否默认隐藏 Dock 图标：建议是。
4. 置顶是否跨所有 Space：建议默认否，提供设置。
5. 首版是否发布未公证二进制：建议发布，但明确提示。
6. 是否提供 Homebrew：建议 1.0 后再做。
7. 是否保留 Windows 和 macOS 单仓：建议是。

## 18. 官方参考

- Apple Developer Documentation: Notarizing macOS software before distribution
  https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution
- Apple Developer Documentation: NSStatusItem
  https://developer.apple.com/documentation/appkit/nsstatusitem
- Apple Developer Documentation: NSWindow.Level
  https://developer.apple.com/documentation/appkit/nswindow/level
- Apple Developer Documentation: SMAppService
  https://developer.apple.com/documentation/servicemanagement/smappservice
- Apple Developer Documentation: LSUIElement
  https://developer.apple.com/documentation/bundleresources/information_property_list/lsuielement
- Apple Support: Open a Mac app from an unidentified developer
  https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unidentified-developer-mh40616/mac
