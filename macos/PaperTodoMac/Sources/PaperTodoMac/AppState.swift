import Foundation

enum PaperKind: String, Codable {
    case todo
    case note
}

enum AppTheme: String, Codable {
    case system
    case light
    case dark
}

enum MarkdownRenderMode: String, Codable {
    case off
    case basic
    case enhanced
}

enum ColorSchemeName: String, Codable {
    case warm
    case ink
    case forest
    case sunset
}

struct AppState: Codable {
    var papers: [PaperData] = []
    var theme: String = AppTheme.system.rawValue
    var colorScheme: String = ColorSchemeName.warm.rawValue
    var markdownRenderMode: String = MarkdownRenderMode.enhanced.rawValue
    var externalMarkdownExtension: String = ".md"
    var zoom: Double = 1.0
    var useCapsuleMode: Bool = true
    var useDeepCapsuleMode: Bool = true
    var showTopBarNewTodoButton: Bool = true
    var showTopBarNewNoteButton: Bool = true
    var showTopBarExternalOpenButton: Bool = true
    var enableTodoNoteLinks: Bool = true
    var showLinkedNoteName: Bool = false
    var hideLinkedNotesFromCapsules: Bool = false
    var maxTitleLength: Int = 18
    var useCapsuleCollapseAll: Bool = false
    var capsuleCollapseAllActive: Bool = false
    var showDeepCapsuleWhileExpanded: Bool = false
    var enableAnimations: Bool = true
    var enableToolTips: Bool = true
    var showPapersOnAllSpaces: Bool = false

    enum CodingKeys: String, CodingKey {
        case papers
        case theme
        case colorScheme
        case markdownRenderMode
        case externalMarkdownExtension
        case zoom
        case useCapsuleMode
        case useDeepCapsuleMode
        case showTopBarNewTodoButton
        case showTopBarNewNoteButton
        case showTopBarExternalOpenButton
        case enableTodoNoteLinks
        case showLinkedNoteName
        case hideLinkedNotesFromCapsules
        case maxTitleLength
        case useCapsuleCollapseAll
        case capsuleCollapseAllActive
        case showDeepCapsuleWhileExpanded
        case enableAnimations
        case enableToolTips
        case showPapersOnAllSpaces
    }
}

struct PaperData: Codable, Identifiable {
    var id: String = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    var type: String = PaperKind.todo.rawValue
    var title: String = ""
    var x: Double = 120
    var y: Double = 120
    var width: Double = 280
    var height: Double = 360
    var isVisible: Bool = true
    var alwaysOnTop: Bool = false
    var isCollapsed: Bool = false
    var textZoom: Double = 1.0
    var items: [PaperItem] = []
    var content: String = ""

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case title
        case x
        case y
        case width
        case height
        case isVisible
        case alwaysOnTop
        case isCollapsed
        case textZoom
        case items
        case content
    }
}

struct PaperItem: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    var text: String = ""
    var done: Bool = false
    var order: Int = 0
    var linkedNoteId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case text
        case done
        case order
        case linkedNoteId
    }
}

struct LinkedNoteSummary: Equatable {
    let id: String
    let title: String
}

enum PaperDefaults {
    static let minWidth: Double = 220
    static let minHeight: Double = 160
    static let todoDefaultWidth: Double = 280
    static let todoDefaultHeight: Double = 340
    static let noteDefaultWidth: Double = 320
    static let noteDefaultHeight: Double = 360
    static let capsuleWidth: Double = 92
    static let capsuleHeight: Double = 46
}

enum PaperTitles {
    static func defaultTitle(type: String, number: Int) -> String {
        type == PaperKind.note.rawValue
            ? L10n.format(.defaultNoteTitle, number)
            : L10n.format(.defaultTodoTitle, number)
    }

    static func effectiveTitle(for paper: PaperData, number: Int) -> String {
        let clean = paper.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? defaultTitle(type: paper.type, number: number) : clean
    }
}

extension AppState {
    private enum LegacyCodingKeys: String, CodingKey {
        case showTopBarNewPaperButtons
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacyContainer = try decoder.container(keyedBy: LegacyCodingKeys.self)
        papers = try container.decodeIfPresent([PaperData].self, forKey: .papers) ?? []
        theme = try container.decodeIfPresent(String.self, forKey: .theme) ?? AppTheme.system.rawValue
        colorScheme = try container.decodeIfPresent(String.self, forKey: .colorScheme) ?? ColorSchemeName.warm.rawValue
        markdownRenderMode = try container.decodeIfPresent(String.self, forKey: .markdownRenderMode) ?? MarkdownRenderMode.enhanced.rawValue
        externalMarkdownExtension = try container.decodeIfPresent(String.self, forKey: .externalMarkdownExtension) ?? ".md"
        zoom = try container.decodeIfPresent(Double.self, forKey: .zoom) ?? 1.0
        useCapsuleMode = try container.decodeIfPresent(Bool.self, forKey: .useCapsuleMode) ?? true
        useDeepCapsuleMode = try container.decodeIfPresent(Bool.self, forKey: .useDeepCapsuleMode) ?? true
        let legacyNewPaperButtons = try legacyContainer.decodeIfPresent(Bool.self, forKey: .showTopBarNewPaperButtons)
        showTopBarNewTodoButton = try container.decodeIfPresent(Bool.self, forKey: .showTopBarNewTodoButton) ?? legacyNewPaperButtons ?? true
        showTopBarNewNoteButton = try container.decodeIfPresent(Bool.self, forKey: .showTopBarNewNoteButton) ?? legacyNewPaperButtons ?? true
        showTopBarExternalOpenButton = try container.decodeIfPresent(Bool.self, forKey: .showTopBarExternalOpenButton) ?? true
        enableTodoNoteLinks = try container.decodeIfPresent(Bool.self, forKey: .enableTodoNoteLinks) ?? true
        showLinkedNoteName = try container.decodeIfPresent(Bool.self, forKey: .showLinkedNoteName) ?? false
        hideLinkedNotesFromCapsules = try container.decodeIfPresent(Bool.self, forKey: .hideLinkedNotesFromCapsules) ?? false
        maxTitleLength = try container.decodeIfPresent(Int.self, forKey: .maxTitleLength) ?? 18
        useCapsuleCollapseAll = try container.decodeIfPresent(Bool.self, forKey: .useCapsuleCollapseAll) ?? false
        capsuleCollapseAllActive = try container.decodeIfPresent(Bool.self, forKey: .capsuleCollapseAllActive) ?? false
        showDeepCapsuleWhileExpanded = try container.decodeIfPresent(Bool.self, forKey: .showDeepCapsuleWhileExpanded) ?? false
        enableAnimations = try container.decodeIfPresent(Bool.self, forKey: .enableAnimations) ?? true
        enableToolTips = try container.decodeIfPresent(Bool.self, forKey: .enableToolTips) ?? true
        showPapersOnAllSpaces = try container.decodeIfPresent(Bool.self, forKey: .showPapersOnAllSpaces) ?? false
    }
}

extension PaperData {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? PaperKind.todo.rawValue
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        x = try container.decodeIfPresent(Double.self, forKey: .x) ?? 120
        y = try container.decodeIfPresent(Double.self, forKey: .y) ?? 120
        width = try container.decodeIfPresent(Double.self, forKey: .width) ?? 280
        height = try container.decodeIfPresent(Double.self, forKey: .height) ?? 360
        isVisible = try container.decodeIfPresent(Bool.self, forKey: .isVisible) ?? true
        alwaysOnTop = try container.decodeIfPresent(Bool.self, forKey: .alwaysOnTop) ?? false
        isCollapsed = try container.decodeIfPresent(Bool.self, forKey: .isCollapsed) ?? false
        textZoom = try container.decodeIfPresent(Double.self, forKey: .textZoom) ?? 1.0
        items = try container.decodeIfPresent([PaperItem].self, forKey: .items) ?? []
        content = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
    }
}

extension PaperItem {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        done = try container.decodeIfPresent(Bool.self, forKey: .done) ?? false
        order = try container.decodeIfPresent(Int.self, forKey: .order) ?? 0
        linkedNoteId = try container.decodeIfPresent(String.self, forKey: .linkedNoteId)
    }
}
