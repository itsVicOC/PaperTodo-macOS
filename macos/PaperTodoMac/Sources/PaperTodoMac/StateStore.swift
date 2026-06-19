import Foundation

final class StateStore {
    enum StoreError: Error {
        case applicationSupportUnavailable
    }

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    let directoryURL: URL
    let fileURL: URL
    let backupURL: URL

    init(fileManager: FileManager = .default) throws {
        if let overridePath = ProcessInfo.processInfo.environment["PAPERTODO_DATA_DIR"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !overridePath.isEmpty {
            directoryURL = URL(fileURLWithPath: overridePath, isDirectory: true)
        } else {
            guard let supportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
                throw StoreError.applicationSupportUnavailable
            }
            directoryURL = supportURL.appendingPathComponent("PaperTodo", isDirectory: true)
        }

        fileURL = directoryURL.appendingPathComponent("data.json")
        backupURL = directoryURL.appendingPathComponent("data.backup.json")

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

        decoder = JSONDecoder()
    }

    func load() throws -> AppState {
        let manager = FileManager.default
        let mainExists = manager.fileExists(atPath: fileURL.path)
        let backupExists = manager.fileExists(atPath: backupURL.path)

        if !mainExists && !backupExists {
            return AppState()
        }

        var mainError: Error?
        if mainExists {
            do {
                let data = try Data(contentsOf: fileURL)
                return normalize(try decoder.decode(AppState.self, from: data))
            } catch {
                mainError = error
            }
        }

        if backupExists {
            do {
                let data = try Data(contentsOf: backupURL)
                return normalize(try decoder.decode(AppState.self, from: data))
            } catch {
                throw mainError ?? error
            }
        }

        throw mainError ?? StoreError.applicationSupportUnavailable
    }

    func loadState(from url: URL) throws -> AppState {
        let data = try Data(contentsOf: url)
        return normalize(try decoder.decode(AppState.self, from: data))
    }

    func save(_ state: AppState) throws {
        let normalized = normalize(state)
        let data = try encoder.encode(normalized)
        let manager = FileManager.default
        try manager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let temporaryURL = fileURL.appendingPathExtension("tmp")
        try data.write(to: temporaryURL, options: .atomic)

        if manager.fileExists(atPath: fileURL.path) {
            do {
                if manager.fileExists(atPath: backupURL.path) {
                    try manager.removeItem(at: backupURL)
                }
                try manager.copyItem(at: fileURL, to: backupURL)
            } catch {
                // A backup failure should not block the primary save.
            }
        }

        if manager.fileExists(atPath: fileURL.path) {
            try manager.removeItem(at: fileURL)
        }
        try manager.moveItem(at: temporaryURL, to: fileURL)
    }

    func replace(with state: AppState) throws {
        try save(state)
    }

    private func normalize(_ state: AppState) -> AppState {
        var normalized = state
        normalized.theme = ["system", "light", "dark"].contains(normalized.theme) ? normalized.theme : "system"
        normalized.colorScheme = ["warm", "ink", "forest", "sunset"].contains(normalized.colorScheme) ? normalized.colorScheme : "warm"
        normalized.markdownRenderMode = ["off", "basic", "enhanced"].contains(normalized.markdownRenderMode) ? normalized.markdownRenderMode : "enhanced"
        normalized.externalMarkdownExtension = normalizeExtension(normalized.externalMarkdownExtension)
        normalized.zoom = min(max(normalized.zoom.isFinite ? normalized.zoom : 1.0, 0.5), 1.5)
        normalized.maxTitleLength = min(max(normalized.maxTitleLength, 8), 40)
        normalized.showDeepCapsuleWhileExpanded = false

        if !normalized.useCapsuleMode {
            normalized.useDeepCapsuleMode = false
            normalized.useCapsuleCollapseAll = false
            normalized.capsuleCollapseAllActive = false
        }

        var usedPaperIDs = Set<String>()
        normalized.papers = normalized.papers.enumerated().map { index, original in
            var paper = original
            if paper.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || usedPaperIDs.contains(paper.id) {
                paper.id = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
            }
            usedPaperIDs.insert(paper.id)
            paper.type = paper.type == PaperKind.note.rawValue ? PaperKind.note.rawValue : PaperKind.todo.rawValue
            paper.x = paper.x.isFinite ? paper.x : 120 + Double(index * 24)
            paper.y = paper.y.isFinite ? paper.y : 120 + Double(index * 24)
            paper.width = max(paper.width.isFinite ? paper.width : defaultWidth(for: paper), PaperDefaults.minWidth)
            paper.height = max(paper.height.isFinite ? paper.height : defaultHeight(for: paper), PaperDefaults.minHeight)
            paper.textZoom = min(max(paper.textZoom.isFinite ? paper.textZoom : 1.0, 0.5), 1.5)
            if !normalized.useCapsuleMode {
                paper.isCollapsed = false
            }
            paper.items = paper.items.enumerated().map { itemIndex, item in
                var normalizedItem = item
                if normalizedItem.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    normalizedItem.id = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
                }
                normalizedItem.order = itemIndex
                return normalizedItem
            }
            return paper
        }

        let noteIDs = Set(normalized.papers.filter { $0.type == PaperKind.note.rawValue }.map(\.id))
        normalized.papers = normalized.papers.map { paper in
            var updated = paper
            updated.items = updated.items.map { item in
                var updatedItem = item
                if let linked = updatedItem.linkedNoteId, !noteIDs.contains(linked) {
                    updatedItem.linkedNoteId = nil
                }
                return updatedItem
            }
            return updated
        }

        return normalized
    }

    private func normalizeExtension(_ extensionValue: String) -> String {
        var value = extensionValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty {
            return ".md"
        }
        if value.hasPrefix("*.") {
            value.removeFirst()
        }
        if !value.hasPrefix(".") {
            value = "." + value
        }
        if value.count < 2 || value.count > 32 || value.contains("..") || value.contains("/") || value.contains(":") {
            return ".md"
        }
        return value.lowercased()
    }

    private func defaultWidth(for paper: PaperData) -> Double {
        paper.type == PaperKind.note.rawValue ? PaperDefaults.noteDefaultWidth : PaperDefaults.todoDefaultWidth
    }

    private func defaultHeight(for paper: PaperData) -> Double {
        paper.type == PaperKind.note.rawValue ? PaperDefaults.noteDefaultHeight : PaperDefaults.todoDefaultHeight
    }
}
