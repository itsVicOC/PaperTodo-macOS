import Foundation
import XCTest
@testable import PaperTodoMac

final class StateStoreTests: XCTestCase {
    private var previousDataDir: String?

    override func setUp() {
        super.setUp()
        previousDataDir = ProcessInfo.processInfo.environment["PAPERTODO_DATA_DIR"]
    }

    override func tearDownWithError() throws {
        if let previousDataDir {
            setenv("PAPERTODO_DATA_DIR", previousDataDir, 1)
        } else {
            unsetenv("PAPERTODO_DATA_DIR")
        }
        try super.tearDownWithError()
    }

    func testLoadUsesBackupWhenPrimaryDataIsInvalid() throws {
        let directory = try makeTemporaryDirectory()
        let store = try StateStore()
        try FileManager.default.createDirectory(at: store.directoryURL, withIntermediateDirectories: true)
        try Data("{ definitely not json".utf8).write(to: store.fileURL)
        try Data(validStateJSON(title: "Backup Paper").utf8).write(to: store.backupURL)

        let loaded = try store.load()

        XCTAssertEqual(loaded.papers.count, 1)
        XCTAssertEqual(loaded.papers.first?.title, "Backup Paper")
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("data.json").path))
    }

    func testLoadThrowsWithoutOverwritingWhenPrimaryAndBackupAreInvalid() throws {
        _ = try makeTemporaryDirectory()
        let store = try StateStore()
        try FileManager.default.createDirectory(at: store.directoryURL, withIntermediateDirectories: true)
        try Data("{ broken primary".utf8).write(to: store.fileURL)
        try Data("{ broken backup".utf8).write(to: store.backupURL)

        XCTAssertThrowsError(try store.load())

        let primary = try String(contentsOf: store.fileURL, encoding: .utf8)
        let backup = try String(contentsOf: store.backupURL, encoding: .utf8)
        XCTAssertEqual(primary, "{ broken primary")
        XCTAssertEqual(backup, "{ broken backup")
    }

    func testLoadNormalizesLegacyAndUnsafeValues() throws {
        _ = try makeTemporaryDirectory()
        let store = try StateStore()
        try FileManager.default.createDirectory(at: store.directoryURL, withIntermediateDirectories: true)
        try Data("""
        {
          "theme": "neon",
          "colorScheme": "unknown",
          "markdownRenderMode": "wild",
          "externalMarkdownExtension": "../bad",
          "zoom": 42,
          "useCapsuleMode": false,
          "useDeepCapsuleMode": true,
          "useCapsuleCollapseAll": true,
          "capsuleCollapseAllActive": true,
          "showTopBarNewPaperButtons": false,
          "showTopBarExternalOpenButton": false,
          "maxTitleLength": 99,
          "papers": [
            {
              "id": "",
              "type": "mystery",
              "x": 120,
              "y": 130,
              "width": 1,
              "height": 1,
              "isCollapsed": true,
              "textZoom": 99,
              "items": [
                { "id": "", "text": "A", "done": false, "order": 99, "linkedNoteId": "missing-note" },
                { "text": "B", "done": true, "order": -20 }
              ]
            }
          ]
        }
        """.utf8).write(to: store.fileURL)

        let loaded = try store.load()
        let paper = try XCTUnwrap(loaded.papers.first)

        XCTAssertEqual(loaded.theme, "system")
        XCTAssertEqual(loaded.colorScheme, "warm")
        XCTAssertEqual(loaded.markdownRenderMode, "enhanced")
        XCTAssertEqual(loaded.externalMarkdownExtension, ".md")
        XCTAssertEqual(loaded.zoom, 1.5)
        XCTAssertEqual(loaded.maxTitleLength, 40)
        XCTAssertFalse(loaded.useDeepCapsuleMode)
        XCTAssertFalse(loaded.useCapsuleCollapseAll)
        XCTAssertFalse(loaded.capsuleCollapseAllActive)
        XCTAssertFalse(loaded.showTopBarNewTodoButton)
        XCTAssertFalse(loaded.showTopBarNewNoteButton)
        XCTAssertFalse(loaded.showTopBarExternalOpenButton)

        XCTAssertFalse(paper.id.isEmpty)
        XCTAssertEqual(paper.type, PaperKind.todo.rawValue)
        XCTAssertEqual(paper.width, PaperDefaults.minWidth)
        XCTAssertEqual(paper.height, PaperDefaults.minHeight)
        XCTAssertFalse(paper.isCollapsed)
        XCTAssertEqual(paper.textZoom, 1.5)
        XCTAssertEqual(paper.items.map(\.order), [0, 1])
        XCTAssertNil(paper.items.first?.linkedNoteId)
        XCTAssertTrue(paper.items.allSatisfy { !$0.id.isEmpty })
    }

    func testSaveCreatesBackupBeforeReplacingPrimaryData() throws {
        _ = try makeTemporaryDirectory()
        let store = try StateStore()
        try FileManager.default.createDirectory(at: store.directoryURL, withIntermediateDirectories: true)
        try Data(validStateJSON(title: "Old Paper").utf8).write(to: store.fileURL)

        var state = AppState()
        state.papers = [PaperData(title: "New Paper")]
        try store.save(state)

        let current = try String(contentsOf: store.fileURL, encoding: .utf8)
        let backup = try String(contentsOf: store.backupURL, encoding: .utf8)
        XCTAssertTrue(current.contains("New Paper"))
        XCTAssertTrue(backup.contains("Old Paper"))
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperTodoStateStoreTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        setenv("PAPERTODO_DATA_DIR", directory.path, 1)
        return directory
    }

    private func validStateJSON(title: String) -> String {
        """
        {
          "papers": [
            {
              "id": "paper-1",
              "type": "todo",
              "title": "\(title)",
              "x": 120,
              "y": 130,
              "width": 280,
              "height": 340,
              "items": []
            }
          ]
        }
        """
    }
}
