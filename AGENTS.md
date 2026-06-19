# PaperTodo macOS Agent 备忘

本文件只记录“不通读历史和全量代码很难知道”的项目约束。代码是真相；普通文件职责、字段含义、AppKit/Swift 常识不要写进来。

## 仓库边界

这个仓库只维护 PaperTodo 的 macOS 版。Windows 版、Windows 下载和 Windows 源码说明统一指向原作者仓库：https://github.com/snownico0722/PaperTodo

不要在本仓库新增 Windows 构建、Windows Release 产物或 .NET/WPF 维护入口。需要说明 Windows 行为时，只把它当作兼容参考和导入来源。

## 产品边界

PaperTodo 是“桌面上的几张纸”，不是任务管理器、知识库或文档编辑器。默认不做账号、同步、分类、标签、搜索、归档、统计、提醒、日历、主管理页和集中列表页。

Markdown 只做轻量显示和编辑辅助。可兼容少量单行内联 HTML 标签（`b/strong/i/em/s/del/u/code/a href`）；不扩展图片、表格、附件、嵌入内容、块级 HTML 或完整块编辑器。

## 数据和保存

- `data.json` 是用户数据协议，不是内部缓存。新增字段要兼容旧数据；删除 / 改名字段要特别谨慎。
- 启动失败时不能用空状态覆盖旧文件。严格解析失败的数据不要“修好后覆盖”，否则可能破坏可恢复数据。
- 保留 `StateStore` 的写入顺序、备份文件和退出同步保存，避免旧异步保存覆盖新状态。
- 删除、隐藏、折叠是三种语义：删除才从 `papers` 移除；隐藏仍保留纸片；折叠仍是可见纸片，只是胶囊形态。
- `paper.x/y/width/height` 是普通纸片几何。胶囊尺寸和贴边半隐藏坐标不能写回普通几何。
- 外部打开笔记的临时文件后缀只做文件名合法性校验；允许用户选择系统已关联的任意后缀。
- macOS 默认数据目录是 `~/Library/Application Support/PaperTodo/`。测试可用 `PAPERTODO_DATA_DIR` 覆盖。

## 单实例

主实例负责持有本地监听通道并处理后续启动命令。后续进程只转发启动参数并退出。

`exit` / `quit` 在没有主实例时也应保存并退出；不要恢复窗口，也不要因为空数据目录创建默认待办纸。无参数的后续实例按 `show` 处理。

## 菜单栏

macOS 版是菜单栏应用，默认不显示 Dock 图标。菜单栏菜单打开时重建，确保纸片列表、设置状态和版本信息实时。

不要把 Windows 托盘行为一比一搬到 macOS。菜单栏单击打开菜单；显示全部、隐藏全部、新建、导入、设置、退出都应在菜单中可达。

## 胶囊和贴边胶囊

这是最高风险区，问题通常来自“窗口几何、动画状态、隐藏状态、持久化状态”混在一起。

- 普通胶囊和贴边胶囊共用度量来源：`PaperDefaults` / `CapsuleLayout`。
- 折叠胶囊、贴边胶囊、展开后的边缘激发态应复用同一套胶囊 UI。激发态只是持久外移、外描边和状态变化，不应再重绘一套 UI。
- `showDeepCapsuleWhileExpanded` 旧字段只做兼容；macOS 贴边胶囊展开纸片后，边缘胶囊应消失并释放槽位。
- `useCapsuleCollapseAll` 使用 slot 0 的主胶囊；真实纸片槽位从后面开始。`capsuleCollapseAllActive` 为真时，真实胶囊收向主胶囊并隐藏可点击面。
- `hideLinkedNotesFromCapsules` 开启时，已被待办关联的笔记不应显示为胶囊。
- 隐藏全部、关闭胶囊模式、关闭贴边模式、从边缘展开后再隐藏，都要清理临时 slot / 激发态 / 动画状态，避免下次显示错位或残留占位。
- 多显示器场景下，贴边胶囊归属应优先跟随纸片普通几何所在屏幕，不能统一塞到主屏幕。

## 待办和笔记

- 多行粘贴待办只能形成一次撤销快照。
- `PaperItem.linkedNoteId` 会影响删除笔记、关闭关联功能、显示关联笔记名称、以及“已关联笔记不显示为胶囊”。
- 笔记编辑和 Markdown 轻量显示共用同一个原生文本控件路径。不要拆成两套正文控件，否则滚动、换行、选区和测量容易漂。
- 中文、日文、韩文等组合输入必须走 marked text 语义，不能把拼音/假名组合阶段文本提前提交到模型。

## 主题、资源、提示

用户可见文本同步四种语言：中文、英文、日文、韩文。

主题变化要主动刷新动态生成控件、菜单栏菜单、纸片窗口、胶囊、文本背景 / 文本 / 光标 / 覆盖层；不要只依赖启动时初始化。

`enableToolTips` 只控制普通操作提示，不应关闭设置页说明图标和扩展说明。

## 用户态更新日志

改动完成后，如果影响用户可见行为，必须更新 `CHANGELOG.md` 的 `### Unreleased` 小节。

只写用户能感知的修复、新增和优化，不写文件名、状态机、重构方式等实现细节。

纯内部整理、文档、构建流程变化可不写，并在最终回复说明 `### Unreleased`。

## 构建和发布

版本号显式维护在 `macos/PaperTodoMac/Resources/Info.plist` 的 `CFBundleShortVersionString`。

常用验证：

```sh
cd macos/PaperTodoMac
swift test
./scripts/build-app.sh
./scripts/package-release.sh
codesign --verify --deep --strict --verbose=2 .build/PaperTodo.app
```

发布产物只包含 macOS 未公证 `.app.zip`、首次运行说明、SHA256 校验和 Sigstore 签名。没有 Developer ID 时不要宣称已公证；README 和 Release notes 必须保留 unnotarized 提示。

## 更新本文

只有仓库边界、产品边界、持久化兼容、保存 / 单实例 / 菜单栏 / 胶囊 / 发布流程发生变化时才更新本文。普通 UI 微调、文案、颜色、间距、动画参数不需要同步。
