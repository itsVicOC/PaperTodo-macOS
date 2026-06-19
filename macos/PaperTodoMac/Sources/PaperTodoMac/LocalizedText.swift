import Foundation

enum L10n {
    static func text(_ key: Key) -> String {
        localizedValue(for: key)
    }

    static func format(_ key: Key, _ arguments: CVarArg...) -> String {
        String(format: text(key), arguments: arguments)
    }

    private static func localizedValue(for key: Key) -> String {
        let language = Locale.preferredLanguages.first?.lowercased() ?? ""
        if language.hasPrefix("ja"), let value = ja[key] {
            return value
        }
        if language.hasPrefix("ko"), let value = ko[key] {
            return value
        }
        if language.hasPrefix("en"), let value = en[key] {
            return value
        }
        return zh[key] ?? en[key] ?? key.rawValue
    }
}

extension L10n {
    enum Key: String, Hashable {
        case appMenuTitle
        case statusItemTitle
        case showAllPapers
        case hideAllPapers
        case newTodo
        case newNote
        case deletePaperMenu
        case settings
        case openDataDirectory
        case importData
        case quit
        case deletePaperTitle
        case deletePaperMessage
        case delete
        case cancel
        case ok
        case settingsTitle
        case appearance
        case theme
        case colorScheme
        case themeSystem
        case themeLight
        case themeDark
        case colorWarm
        case colorInk
        case colorForest
        case colorSunset
        case markdownEnhanced
        case markdownBasic
        case markdownOff
        case todoAndNotes
        case externalExtension
        case topBarButtons
        case capsule
        case experience
        case startup
        case maxTitleLength
        case capsuleMode
        case deepCapsuleMode
        case capsuleCollapseAll
        case topBarTodo
        case topBarNote
        case topBarExternal
        case enableTodoLinks
        case showLinkedNoteName
        case hideLinkedNotes
        case showDeepCapsuleWhileExpanded
        case enableAnimations
        case enableToolTips
        case showOnAllSpaces
        case launchAtLogin
        case openSystemSettings
        case loginDisabled
        case loginEnabled
        case loginRequiresApproval
        case loginUnavailable
        case importPanelTitle
        case importPrompt
        case importConfirmTitle
        case importConfirmMessage
        case importReplace
        case importSuccessTitle
        case importSuccessMessage
        case importFailureTitle
        case importFailureMessage
        case startupLoadFailureTitle
        case startupLoadFailureMessage
        case loginApprovalTitle
        case loginApprovalMessage
        case later
        case loginFailureTitle
        case loginFailureMessage
        case notePaperTitle
        case todoPaperTitle
        case defaultNoteTitle
        case defaultTodoTitle
        case todoPlaceholder
        case addTodo
        case clearCompleted
        case insertTodoBelow
        case markTodoDone
        case markTodoUndone
        case noLinkableNotes
        case openLinkedNote
        case clearLinkedNote
        case deleteTodoTooltip
        case linkedNoteLabel
        case linkNoteTooltip
        case linkedNoteTooltip
        case markdownLinkPlaceholder
        case markdownBoldPlaceholder
        case markdownItalicPlaceholder
        case edit
        case undo
        case redo
        case cut
        case copy
        case paste
        case selectAll
        case renamePaper
        case toggleTopmost
        case collapsePaper
        case externalOpen
        case markdownFormat
        case markdownBold
        case markdownItalic
        case markdownStrikethrough
        case markdownHeading
        case markdownQuote
        case markdownList
        case markdownOrderedList
        case markdownRule
        case markdownCodeBlock
        case markdownLink
        case openMarkdownLink
        case zoomIn
        case zoomOut
        case resetZoom
        case collapseCapsules
        case expandCapsules
        case collapseCapsulesShort
        case expandCapsulesShort
        case helpTheme
        case helpColorScheme
        case helpMaxTitleLength
        case helpMarkdownMode
        case helpExternalExtension
        case helpEnableTodoLinks
        case helpShowLinkedNoteName
        case helpHideLinkedNotes
        case helpTopBarButtons
        case helpCapsuleMode
        case helpDeepCapsuleMode
        case helpCapsuleCollapseAll
        case helpEnableAnimations
        case helpEnableToolTips
        case helpShowOnAllSpaces
        case helpLaunchAtLogin
    }
}

private extension L10n {
    static let zh: [Key: String] = [
        .appMenuTitle: "PaperTodo macOS 版",
        .statusItemTitle: "纸",
        .showAllPapers: "显示全部纸片",
        .hideAllPapers: "隐藏全部纸片",
        .newTodo: "新建待办",
        .newNote: "新建笔记",
        .deletePaperMenu: "删除纸片",
        .settings: "设置",
        .openDataDirectory: "打开数据目录",
        .importData: "导入 data.json...",
        .quit: "退出",
        .deletePaperTitle: "删除纸片？",
        .deletePaperMessage: "这个操作会从 data.json 中移除该纸片。",
        .delete: "删除",
        .cancel: "取消",
        .ok: "好",
        .settingsTitle: "PaperTodo 设置",
        .appearance: "外观",
        .theme: "主题",
        .colorScheme: "配色",
        .themeSystem: "跟随系统",
        .themeLight: "浅色",
        .themeDark: "深色",
        .colorWarm: "暖纸",
        .colorInk: "墨",
        .colorForest: "林",
        .colorSunset: "霞",
        .markdownEnhanced: "增强",
        .markdownBasic: "基础",
        .markdownOff: "关闭",
        .todoAndNotes: "待办与笔记",
        .externalExtension: "外部打开后缀",
        .topBarButtons: "顶栏按钮",
        .capsule: "胶囊",
        .experience: "体验",
        .startup: "启动",
        .maxTitleLength: "标题最大字数",
        .capsuleMode: "胶囊模式",
        .deepCapsuleMode: "胶囊自动贴边",
        .capsuleCollapseAll: "一键收纳主胶囊",
        .topBarTodo: "顶栏显示新建待办",
        .topBarNote: "顶栏显示新建笔记",
        .topBarExternal: "顶栏显示外部打开",
        .enableTodoLinks: "启用待办关联笔记",
        .showLinkedNoteName: "显示关联笔记名称",
        .hideLinkedNotes: "已关联笔记不显示为胶囊",
        .showDeepCapsuleWhileExpanded: "展开时保留边缘胶囊",
        .enableAnimations: "启用动画",
        .enableToolTips: "启用提示",
        .showOnAllSpaces: "在所有桌面显示纸片",
        .launchAtLogin: "开机自启动",
        .openSystemSettings: "系统设置...",
        .loginDisabled: "未启用",
        .loginEnabled: "已启用",
        .loginRequiresApproval: "需要在系统设置中允许",
        .loginUnavailable: "当前 App 包不可用",
        .importPanelTitle: "导入 PaperTodo data.json",
        .importPrompt: "导入",
        .importConfirmTitle: "导入 data.json？",
        .importConfirmMessage: "将用所选文件替换当前 PaperTodo 数据。当前数据会在保存前写入 data.backup.json。\n\n来源：%@\n纸片数量：%d",
        .importReplace: "导入并替换",
        .importSuccessTitle: "导入完成",
        .importSuccessMessage: "已导入 %d 张纸片。",
        .importFailureTitle: "导入失败",
        .importFailureMessage: "所选文件无法作为 PaperTodo data.json 读取，当前数据没有被修改。\n\n%@",
        .startupLoadFailureTitle: "启动失败",
        .startupLoadFailureMessage: "PaperTodo 无法读取 data.json。为了避免用空白状态覆盖原有数据，应用已停止启动。\n\n%@",
        .loginApprovalTitle: "需要允许开机自启动",
        .loginApprovalMessage: "PaperTodo 已请求加入登录项，但 macOS 还需要你在系统设置中允许它。",
        .later: "稍后",
        .loginFailureTitle: "设置开机自启动失败",
        .loginFailureMessage: "macOS 没有接受这次登录项更改。未公证或临时位置运行的 App 可能需要先移动到“应用程序”文件夹后再启用。\n\n%@",
        .notePaperTitle: "笔记",
        .todoPaperTitle: "待办",
        .defaultNoteTitle: "笔记%d",
        .defaultTodoTitle: "待办%d",
        .todoPlaceholder: "新增事项",
        .addTodo: "+ 新增事项",
        .clearCompleted: "清除已完成",
        .insertTodoBelow: "在下方插入事项",
        .markTodoDone: "标记为已完成",
        .markTodoUndone: "标记为未完成",
        .noLinkableNotes: "没有可关联的笔记",
        .openLinkedNote: "打开关联笔记",
        .clearLinkedNote: "取消关联",
        .deleteTodoTooltip: "删除事项",
        .linkedNoteLabel: "笔记",
        .linkNoteTooltip: "关联笔记",
        .linkedNoteTooltip: "打开或更换关联笔记",
        .markdownLinkPlaceholder: "链接",
        .markdownBoldPlaceholder: "加粗",
        .markdownItalicPlaceholder: "斜体",
        .edit: "编辑",
        .undo: "撤销",
        .redo: "重做",
        .cut: "剪切",
        .copy: "复制",
        .paste: "粘贴",
        .selectAll: "全选",
        .renamePaper: "重命名纸片",
        .toggleTopmost: "置顶纸片",
        .collapsePaper: "折叠为胶囊",
        .externalOpen: "外部打开",
        .markdownFormat: "Markdown 格式",
        .markdownBold: "加粗",
        .markdownItalic: "斜体",
        .markdownStrikethrough: "删除线",
        .markdownHeading: "标题",
        .markdownQuote: "引用",
        .markdownList: "列表",
        .markdownOrderedList: "有序列表",
        .markdownRule: "分割线",
        .markdownCodeBlock: "代码块",
        .markdownLink: "链接",
        .openMarkdownLink: "打开链接",
        .zoomIn: "放大",
        .zoomOut: "缩小",
        .resetZoom: "重置缩放",
        .collapseCapsules: "收起贴边胶囊",
        .expandCapsules: "展开贴边胶囊",
        .collapseCapsulesShort: "收起",
        .expandCapsulesShort: "展开",
        .helpTheme: "选择浅色、深色或跟随系统外观。",
        .helpColorScheme: "切换纸片、胶囊和强调色的整体配色。",
        .helpMaxTitleLength: "控制自动生成标题和菜单标题的最大显示字数。",
        .helpMarkdownMode: "增强模式会淡化 Markdown 标记并显示更多轻量格式；关闭则尽量保留纯文本。",
        .helpExternalExtension: "外部打开笔记时使用的临时文件后缀。仅校验文件名合法性，可使用系统已关联的后缀。",
        .helpEnableTodoLinks: "允许把笔记拖到待办项上建立关联，并从待办项快速打开关联笔记。",
        .helpShowLinkedNoteName: "开启后，已关联待办会显示笔记标题；关闭时只显示简短入口。",
        .helpHideLinkedNotes: "开启后，已被待办关联的笔记不会出现在胶囊列表中。",
        .helpTopBarButtons: "按使用习惯隐藏不常用的顶栏快捷按钮。",
        .helpCapsuleMode: "关闭纸片时折叠为胶囊，而不是直接隐藏窗口。",
        .helpDeepCapsuleMode: "折叠胶囊会自动停靠到屏幕右侧，悬停时滑出。",
        .helpCapsuleCollapseAll: "显示主胶囊，可一键收纳或展开当前贴边胶囊。",
        .helpEnableAnimations: "控制纸片折叠、胶囊滑出和状态切换动画。",
        .helpEnableToolTips: "控制普通按钮提示；设置页说明按钮始终保留。",
        .helpShowOnAllSpaces: "让纸片和胶囊在所有 macOS 桌面空间中显示。",
        .helpLaunchAtLogin: "登录 macOS 后自动启动 PaperTodo；未公证构建可能需要在系统设置中手动允许。"
    ]

    static let en: [Key: String] = [
        .appMenuTitle: "PaperTodo for macOS",
        .statusItemTitle: "Paper",
        .showAllPapers: "Show All Papers",
        .hideAllPapers: "Hide All Papers",
        .newTodo: "New Todo",
        .newNote: "New Note",
        .deletePaperMenu: "Delete Paper",
        .settings: "Settings",
        .openDataDirectory: "Open Data Folder",
        .importData: "Import data.json...",
        .quit: "Quit",
        .deletePaperTitle: "Delete paper?",
        .deletePaperMessage: "This removes the paper from data.json.",
        .delete: "Delete",
        .cancel: "Cancel",
        .ok: "OK",
        .settingsTitle: "PaperTodo Settings",
        .appearance: "Appearance",
        .theme: "Theme",
        .colorScheme: "Color",
        .themeSystem: "System",
        .themeLight: "Light",
        .themeDark: "Dark",
        .colorWarm: "Warm Paper",
        .colorInk: "Ink",
        .colorForest: "Forest",
        .colorSunset: "Sunset",
        .markdownEnhanced: "Enhanced",
        .markdownBasic: "Basic",
        .markdownOff: "Off",
        .todoAndNotes: "Todos & Notes",
        .externalExtension: "External Extension",
        .topBarButtons: "Top Bar Buttons",
        .capsule: "Capsules",
        .experience: "Experience",
        .startup: "Startup",
        .maxTitleLength: "Max Title Length",
        .capsuleMode: "Capsule Mode",
        .deepCapsuleMode: "Auto Edge Capsules",
        .capsuleCollapseAll: "Master Capsule",
        .topBarTodo: "Show New Todo Button",
        .topBarNote: "Show New Note Button",
        .topBarExternal: "Show External Open Button",
        .enableTodoLinks: "Enable Todo-Note Links",
        .showLinkedNoteName: "Show Linked Note Name",
        .hideLinkedNotes: "Hide Linked Notes from Capsules",
        .showDeepCapsuleWhileExpanded: "Keep Edge Capsule While Expanded",
        .enableAnimations: "Enable Animations",
        .enableToolTips: "Enable Tooltips",
        .showOnAllSpaces: "Show Papers on All Desktops",
        .launchAtLogin: "Launch at Login",
        .openSystemSettings: "System Settings...",
        .loginDisabled: "Disabled",
        .loginEnabled: "Enabled",
        .loginRequiresApproval: "Approval Required in System Settings",
        .loginUnavailable: "Current App Bundle Unavailable",
        .importPanelTitle: "Import PaperTodo data.json",
        .importPrompt: "Import",
        .importConfirmTitle: "Import data.json?",
        .importConfirmMessage: "This will replace the current PaperTodo data with the selected file. The current data will be written to data.backup.json first.\n\nSource: %@\nPapers: %d",
        .importReplace: "Import and Replace",
        .importSuccessTitle: "Import Complete",
        .importSuccessMessage: "Imported %d papers.",
        .importFailureTitle: "Import Failed",
        .importFailureMessage: "The selected file could not be read as PaperTodo data.json. Current data was not changed.\n\n%@",
        .startupLoadFailureTitle: "Startup Failed",
        .startupLoadFailureMessage: "PaperTodo could not read data.json. To avoid overwriting existing data with an empty state, the app stopped safely.\n\n%@",
        .loginApprovalTitle: "Launch at Login Needs Approval",
        .loginApprovalMessage: "PaperTodo requested a Login Item, but macOS still needs you to allow it in System Settings.",
        .later: "Later",
        .loginFailureTitle: "Launch at Login Failed",
        .loginFailureMessage: "macOS did not accept this Login Item change. An unnotarized app or app running from a temporary location may need to be moved to Applications first.\n\n%@",
        .notePaperTitle: "Note",
        .todoPaperTitle: "Todo",
        .defaultNoteTitle: "Note %d",
        .defaultTodoTitle: "Todo %d",
        .todoPlaceholder: "New item",
        .addTodo: "+ New Item",
        .clearCompleted: "Clear Completed",
        .insertTodoBelow: "Insert Item Below",
        .markTodoDone: "Mark Completed",
        .markTodoUndone: "Mark Incomplete",
        .noLinkableNotes: "No notes to link",
        .openLinkedNote: "Open Linked Note",
        .clearLinkedNote: "Clear Link",
        .deleteTodoTooltip: "Delete Item",
        .linkedNoteLabel: "Note",
        .linkNoteTooltip: "Link Note",
        .linkedNoteTooltip: "Open or Change Linked Note",
        .markdownLinkPlaceholder: "link",
        .markdownBoldPlaceholder: "bold",
        .markdownItalicPlaceholder: "italic",
        .edit: "Edit",
        .undo: "Undo",
        .redo: "Redo",
        .cut: "Cut",
        .copy: "Copy",
        .paste: "Paste",
        .selectAll: "Select All",
        .renamePaper: "Rename Paper",
        .toggleTopmost: "Keep on Top",
        .collapsePaper: "Collapse to Capsule",
        .externalOpen: "Open Externally",
        .markdownFormat: "Markdown Format",
        .markdownBold: "Bold",
        .markdownItalic: "Italic",
        .markdownStrikethrough: "Strikethrough",
        .markdownHeading: "Heading",
        .markdownQuote: "Quote",
        .markdownList: "List",
        .markdownOrderedList: "Numbered List",
        .markdownRule: "Divider",
        .markdownCodeBlock: "Code Block",
        .markdownLink: "Link",
        .openMarkdownLink: "Open Link",
        .zoomIn: "Zoom In",
        .zoomOut: "Zoom Out",
        .resetZoom: "Reset Zoom",
        .collapseCapsules: "Collapse Edge Capsules",
        .expandCapsules: "Expand Edge Capsules",
        .collapseCapsulesShort: "Collapse",
        .expandCapsulesShort: "Expand",
        .helpTheme: "Choose light, dark, or system appearance.",
        .helpColorScheme: "Switch the paper, capsule, and accent color palette.",
        .helpMaxTitleLength: "Controls the maximum displayed length for generated titles and menu labels.",
        .helpMarkdownMode: "Enhanced mode fades Markdown markers and shows more lightweight formatting; Off keeps text closer to plain text.",
        .helpExternalExtension: "Temporary file extension used when opening notes externally. Only filename safety is checked; any system-associated extension is allowed.",
        .helpEnableTodoLinks: "Allows dragging a note onto a todo item and opening the linked note from that item.",
        .helpShowLinkedNoteName: "Shows the linked note title on todo rows instead of a compact entry.",
        .helpHideLinkedNotes: "Hides notes already linked to todos from the capsule list.",
        .helpTopBarButtons: "Hide top-bar shortcuts you do not use often.",
        .helpCapsuleMode: "Closing a paper folds it into a capsule instead of hiding it outright.",
        .helpDeepCapsuleMode: "Collapsed capsules dock to the right edge and slide out on hover.",
        .helpCapsuleCollapseAll: "Shows a master capsule that can collect or reveal current edge capsules.",
        .helpEnableAnimations: "Controls paper folding, capsule slide, and state transition animations.",
        .helpEnableToolTips: "Controls regular button tips; settings help buttons always remain available.",
        .helpShowOnAllSpaces: "Shows papers and capsules across all macOS desktop spaces.",
        .helpLaunchAtLogin: "Starts PaperTodo after macOS login; unnotarized builds may need manual approval in System Settings."
    ]

    static let ja: [Key: String] = [
        .appMenuTitle: "PaperTodo for macOS",
        .statusItemTitle: "紙",
        .showAllPapers: "すべての紙を表示",
        .hideAllPapers: "すべての紙を隠す",
        .newTodo: "新規 ToDo",
        .newNote: "新規メモ",
        .deletePaperMenu: "紙を削除",
        .settings: "設定",
        .openDataDirectory: "データフォルダを開く",
        .importData: "data.json を読み込む...",
        .quit: "終了",
        .deletePaperTitle: "紙を削除しますか？",
        .deletePaperMessage: "この操作は data.json からこの紙を削除します。",
        .delete: "削除",
        .cancel: "キャンセル",
        .ok: "OK",
        .settingsTitle: "PaperTodo 設定",
        .appearance: "外観",
        .theme: "テーマ",
        .colorScheme: "配色",
        .themeSystem: "システム",
        .themeLight: "ライト",
        .themeDark: "ダーク",
        .colorWarm: "暖かい紙",
        .colorInk: "インク",
        .colorForest: "森",
        .colorSunset: "夕焼け",
        .markdownEnhanced: "拡張",
        .markdownBasic: "基本",
        .markdownOff: "オフ",
        .todoAndNotes: "ToDo とメモ",
        .externalExtension: "外部で開く拡張子",
        .topBarButtons: "上部ボタン",
        .capsule: "カプセル",
        .experience: "操作",
        .startup: "起動",
        .maxTitleLength: "タイトル最大文字数",
        .capsuleMode: "カプセルモード",
        .deepCapsuleMode: "端に自動配置",
        .capsuleCollapseAll: "マスターカプセル",
        .topBarTodo: "新規 ToDo ボタンを表示",
        .topBarNote: "新規メモボタンを表示",
        .topBarExternal: "外部で開くボタンを表示",
        .enableTodoLinks: "ToDo とメモのリンクを有効化",
        .showLinkedNoteName: "リンクしたメモ名を表示",
        .hideLinkedNotes: "リンク済みメモをカプセルに表示しない",
        .showDeepCapsuleWhileExpanded: "展開中も端のカプセルを残す",
        .enableAnimations: "アニメーションを有効化",
        .enableToolTips: "ヒントを有効化",
        .showOnAllSpaces: "すべてのデスクトップに表示",
        .launchAtLogin: "ログイン時に起動",
        .openSystemSettings: "システム設定...",
        .loginDisabled: "無効",
        .loginEnabled: "有効",
        .loginRequiresApproval: "システム設定で許可が必要",
        .loginUnavailable: "現在の App バンドルを利用できません",
        .importPanelTitle: "PaperTodo data.json を読み込む",
        .importPrompt: "読み込む",
        .importConfirmTitle: "data.json を読み込みますか？",
        .importConfirmMessage: "選択したファイルで現在の PaperTodo データを置き換えます。現在のデータは先に data.backup.json に保存されます。\n\nソース：%@\n紙の数：%d",
        .importReplace: "読み込んで置換",
        .importSuccessTitle: "読み込み完了",
        .importSuccessMessage: "%d 枚の紙を読み込みました。",
        .importFailureTitle: "読み込み失敗",
        .importFailureMessage: "選択したファイルを PaperTodo data.json として読み込めませんでした。現在のデータは変更されていません。\n\n%@",
        .startupLoadFailureTitle: "起動失敗",
        .startupLoadFailureMessage: "PaperTodo は data.json を読み込めませんでした。空の状態で既存データを上書きしないよう、アプリは安全に停止しました。\n\n%@",
        .loginApprovalTitle: "ログイン時起動の許可が必要です",
        .loginApprovalMessage: "PaperTodo はログイン項目への追加を要求しましたが、macOS のシステム設定で許可する必要があります。",
        .later: "後で",
        .loginFailureTitle: "ログイン時起動の設定に失敗",
        .loginFailureMessage: "macOS がこのログイン項目の変更を受け付けませんでした。未公証または一時的な場所から実行中の App は、先に「アプリケーション」フォルダへ移動する必要がある場合があります。\n\n%@",
        .notePaperTitle: "メモ",
        .todoPaperTitle: "ToDo",
        .defaultNoteTitle: "メモ%d",
        .defaultTodoTitle: "ToDo%d",
        .todoPlaceholder: "新規項目",
        .addTodo: "+ 新規項目",
        .clearCompleted: "完了を消去",
        .insertTodoBelow: "下に項目を挿入",
        .markTodoDone: "完了にする",
        .markTodoUndone: "未完了に戻す",
        .noLinkableNotes: "リンクできるメモがありません",
        .openLinkedNote: "リンクしたメモを開く",
        .clearLinkedNote: "リンクを解除",
        .deleteTodoTooltip: "項目を削除",
        .linkedNoteLabel: "メモ",
        .linkNoteTooltip: "メモをリンク",
        .linkedNoteTooltip: "リンクしたメモを開く/変更",
        .markdownLinkPlaceholder: "リンク",
        .markdownBoldPlaceholder: "太字",
        .markdownItalicPlaceholder: "斜体",
        .edit: "編集",
        .undo: "取り消す",
        .redo: "やり直す",
        .cut: "カット",
        .copy: "コピー",
        .paste: "ペースト",
        .selectAll: "すべて選択",
        .renamePaper: "紙の名前を変更",
        .toggleTopmost: "最前面に固定",
        .collapsePaper: "カプセルに畳む",
        .externalOpen: "外部で開く",
        .markdownFormat: "Markdown 書式",
        .markdownBold: "太字",
        .markdownItalic: "斜体",
        .markdownStrikethrough: "取り消し線",
        .markdownHeading: "見出し",
        .markdownQuote: "引用",
        .markdownList: "リスト",
        .markdownOrderedList: "番号付きリスト",
        .markdownRule: "区切り線",
        .markdownCodeBlock: "コードブロック",
        .markdownLink: "リンク",
        .openMarkdownLink: "リンクを開く",
        .zoomIn: "拡大",
        .zoomOut: "縮小",
        .resetZoom: "ズームをリセット",
        .collapseCapsules: "端のカプセルを畳む",
        .expandCapsules: "端のカプセルを展開",
        .collapseCapsulesShort: "畳む",
        .expandCapsulesShort: "展開",
        .helpTheme: "ライト、ダーク、システムに合わせる外観を選びます。",
        .helpColorScheme: "紙、カプセル、アクセント色の配色を切り替えます。",
        .helpMaxTitleLength: "自動タイトルとメニュー表示の最大文字数を調整します。",
        .helpMarkdownMode: "拡張では Markdown 記号を淡く表示し、軽量な書式を増やします。オフではプレーンテキストに近づけます。",
        .helpExternalExtension: "外部で開く一時ファイルの拡張子です。ファイル名の安全性のみ確認し、システム関連付けを利用します。",
        .helpEnableTodoLinks: "メモを ToDo 項目へドラッグしてリンクし、項目から開けるようにします。",
        .helpShowLinkedNoteName: "リンク済み ToDo にメモ名を表示します。",
        .helpHideLinkedNotes: "ToDo にリンク済みのメモをカプセル一覧から隠します。",
        .helpTopBarButtons: "使わない上部ショートカットボタンを隠します。",
        .helpCapsuleMode: "紙を閉じると非表示ではなくカプセルに畳みます。",
        .helpDeepCapsuleMode: "畳んだカプセルを画面右端へ配置し、ホバーでスライド表示します。",
        .helpCapsuleCollapseAll: "端のカプセルをまとめて畳む/表示するマスターカプセルを使います。",
        .helpEnableAnimations: "紙の折り畳み、カプセルのスライド、状態切り替えのアニメーションを制御します。",
        .helpEnableToolTips: "通常ボタンのヒントを制御します。設定の説明ボタンは常に表示されます。",
        .helpShowOnAllSpaces: "すべての macOS デスクトップスペースに紙とカプセルを表示します。",
        .helpLaunchAtLogin: "macOS ログイン後に PaperTodo を起動します。未公証ビルドではシステム設定での許可が必要になる場合があります。"
    ]

    static let ko: [Key: String] = [
        .appMenuTitle: "PaperTodo for macOS",
        .statusItemTitle: "종이",
        .showAllPapers: "모든 종이 보이기",
        .hideAllPapers: "모든 종이 숨기기",
        .newTodo: "새 할 일",
        .newNote: "새 노트",
        .deletePaperMenu: "종이 삭제",
        .settings: "설정",
        .openDataDirectory: "데이터 폴더 열기",
        .importData: "data.json 가져오기...",
        .quit: "종료",
        .deletePaperTitle: "종이를 삭제할까요?",
        .deletePaperMessage: "이 작업은 data.json 에서 이 종이를 제거합니다.",
        .delete: "삭제",
        .cancel: "취소",
        .ok: "확인",
        .settingsTitle: "PaperTodo 설정",
        .appearance: "모양",
        .theme: "테마",
        .colorScheme: "색상",
        .themeSystem: "시스템",
        .themeLight: "라이트",
        .themeDark: "다크",
        .colorWarm: "따뜻한 종이",
        .colorInk: "잉크",
        .colorForest: "숲",
        .colorSunset: "노을",
        .markdownEnhanced: "향상",
        .markdownBasic: "기본",
        .markdownOff: "끔",
        .todoAndNotes: "할 일과 노트",
        .externalExtension: "외부 열기 확장자",
        .topBarButtons: "상단 버튼",
        .capsule: "캡슐",
        .experience: "사용감",
        .startup: "시작",
        .maxTitleLength: "제목 최대 길이",
        .capsuleMode: "캡슐 모드",
        .deepCapsuleMode: "가장자리 자동 캡슐",
        .capsuleCollapseAll: "마스터 캡슐",
        .topBarTodo: "새 할 일 버튼 표시",
        .topBarNote: "새 노트 버튼 표시",
        .topBarExternal: "외부 열기 버튼 표시",
        .enableTodoLinks: "할 일-노트 연결 사용",
        .showLinkedNoteName: "연결된 노트 이름 표시",
        .hideLinkedNotes: "연결된 노트를 캡슐에서 숨김",
        .showDeepCapsuleWhileExpanded: "펼친 동안 가장자리 캡슐 유지",
        .enableAnimations: "애니메이션 사용",
        .enableToolTips: "도움말 사용",
        .showOnAllSpaces: "모든 데스크탑에 종이 표시",
        .launchAtLogin: "로그인 시 실행",
        .openSystemSettings: "시스템 설정...",
        .loginDisabled: "꺼짐",
        .loginEnabled: "켜짐",
        .loginRequiresApproval: "시스템 설정에서 허용 필요",
        .loginUnavailable: "현재 앱 번들을 사용할 수 없음",
        .importPanelTitle: "PaperTodo data.json 가져오기",
        .importPrompt: "가져오기",
        .importConfirmTitle: "data.json 을 가져올까요?",
        .importConfirmMessage: "선택한 파일로 현재 PaperTodo 데이터를 대체합니다. 현재 데이터는 먼저 data.backup.json 에 저장됩니다.\n\n원본: %@\n종이 수: %d",
        .importReplace: "가져와서 대체",
        .importSuccessTitle: "가져오기 완료",
        .importSuccessMessage: "%d장의 종이를 가져왔습니다.",
        .importFailureTitle: "가져오기 실패",
        .importFailureMessage: "선택한 파일을 PaperTodo data.json 으로 읽을 수 없습니다. 현재 데이터는 변경되지 않았습니다.\n\n%@",
        .startupLoadFailureTitle: "시작 실패",
        .startupLoadFailureMessage: "PaperTodo 가 data.json 을 읽을 수 없습니다. 빈 상태로 기존 데이터를 덮어쓰지 않도록 앱이 안전하게 중지되었습니다.\n\n%@",
        .loginApprovalTitle: "로그인 시 실행 허용 필요",
        .loginApprovalMessage: "PaperTodo 가 로그인 항목 추가를 요청했지만 macOS 시스템 설정에서 허용해야 합니다.",
        .later: "나중에",
        .loginFailureTitle: "로그인 시 실행 설정 실패",
        .loginFailureMessage: "macOS 가 이 로그인 항목 변경을 수락하지 않았습니다. 공증되지 않았거나 임시 위치에서 실행 중인 앱은 먼저 응용 프로그램 폴더로 이동해야 할 수 있습니다.\n\n%@",
        .notePaperTitle: "노트",
        .todoPaperTitle: "할 일",
        .defaultNoteTitle: "노트%d",
        .defaultTodoTitle: "할 일%d",
        .todoPlaceholder: "새 항목",
        .addTodo: "+ 새 항목",
        .clearCompleted: "완료 항목 지우기",
        .insertTodoBelow: "아래에 항목 삽입",
        .markTodoDone: "완료로 표시",
        .markTodoUndone: "미완료로 표시",
        .noLinkableNotes: "연결할 노트가 없습니다",
        .openLinkedNote: "연결된 노트 열기",
        .clearLinkedNote: "연결 해제",
        .deleteTodoTooltip: "항목 삭제",
        .linkedNoteLabel: "노트",
        .linkNoteTooltip: "노트 연결",
        .linkedNoteTooltip: "연결된 노트 열기 또는 변경",
        .markdownLinkPlaceholder: "링크",
        .markdownBoldPlaceholder: "굵게",
        .markdownItalicPlaceholder: "기울임",
        .edit: "편집",
        .undo: "실행 취소",
        .redo: "다시 실행",
        .cut: "오려두기",
        .copy: "복사",
        .paste: "붙여넣기",
        .selectAll: "전체 선택",
        .renamePaper: "종이 이름 변경",
        .toggleTopmost: "항상 위에 표시",
        .collapsePaper: "캡슐로 접기",
        .externalOpen: "외부에서 열기",
        .markdownFormat: "Markdown 서식",
        .markdownBold: "굵게",
        .markdownItalic: "기울임",
        .markdownStrikethrough: "취소선",
        .markdownHeading: "제목",
        .markdownQuote: "인용",
        .markdownList: "목록",
        .markdownOrderedList: "번호 목록",
        .markdownRule: "구분선",
        .markdownCodeBlock: "코드 블록",
        .markdownLink: "링크",
        .openMarkdownLink: "링크 열기",
        .zoomIn: "확대",
        .zoomOut: "축소",
        .resetZoom: "확대/축소 재설정",
        .collapseCapsules: "가장자리 캡슐 접기",
        .expandCapsules: "가장자리 캡슐 펼치기",
        .collapseCapsulesShort: "접기",
        .expandCapsulesShort: "펼치기",
        .helpTheme: "라이트, 다크 또는 시스템 외관을 선택합니다.",
        .helpColorScheme: "종이, 캡슐, 강조 색상 팔레트를 바꿉니다.",
        .helpMaxTitleLength: "자동 제목과 메뉴 제목의 최대 표시 길이를 조정합니다.",
        .helpMarkdownMode: "향상 모드는 Markdown 표시를 흐리게 하고 더 많은 가벼운 서식을 보여줍니다. 끔은 일반 텍스트에 가깝게 유지합니다.",
        .helpExternalExtension: "노트를 외부에서 열 때 사용하는 임시 파일 확장자입니다. 파일명 안전성만 확인하며 시스템 연결 앱을 사용합니다.",
        .helpEnableTodoLinks: "노트를 할 일 항목으로 드래그해 연결하고 항목에서 바로 열 수 있습니다.",
        .helpShowLinkedNoteName: "연결된 할 일에 노트 제목을 표시합니다.",
        .helpHideLinkedNotes: "할 일에 연결된 노트를 캡슐 목록에서 숨깁니다.",
        .helpTopBarButtons: "자주 쓰지 않는 상단 바로가기 버튼을 숨깁니다.",
        .helpCapsuleMode: "종이를 닫으면 바로 숨기지 않고 캡슐로 접습니다.",
        .helpDeepCapsuleMode: "접힌 캡슐을 화면 오른쪽 가장자리에 붙이고, 호버 시 슬라이드됩니다.",
        .helpCapsuleCollapseAll: "가장자리 캡슐을 한 번에 접거나 펼치는 마스터 캡슐을 표시합니다.",
        .helpEnableAnimations: "종이 접기, 캡슐 슬라이드, 상태 전환 애니메이션을 제어합니다.",
        .helpEnableToolTips: "일반 버튼 도움말을 제어합니다. 설정 설명 버튼은 항상 유지됩니다.",
        .helpShowOnAllSpaces: "모든 macOS 데스크탑 공간에 종이와 캡슐을 표시합니다.",
        .helpLaunchAtLogin: "macOS 로그인 후 PaperTodo 를 시작합니다. 공증되지 않은 빌드는 시스템 설정에서 수동 승인이 필요할 수 있습니다."
    ]
}
