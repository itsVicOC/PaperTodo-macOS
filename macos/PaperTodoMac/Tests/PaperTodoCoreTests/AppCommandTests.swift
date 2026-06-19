import Foundation
import XCTest
@testable import PaperTodoMac

final class AppCommandTests: XCTestCase {
    func testLaunchArgumentsReturnFirstRecognizedCommand() {
        XCTAssertEqual(AppCommand.fromLaunchArguments(["PaperTodoMac", "--ignored", "--hide", "--show"]), .hide)
        XCTAssertEqual(AppCommand.fromLaunchArguments(["PaperTodoMac", "-toggle"]), .toggle)
        XCTAssertEqual(AppCommand.fromLaunchArguments(["PaperTodoMac", "--new-todo"]), .newTodo)
        XCTAssertEqual(AppCommand.fromLaunchArguments(["PaperTodoMac", "--new-note"]), .newNote)
    }

    func testNoLaunchCommandMeansImplicitShowForForwarding() throws {
        XCTAssertNil(AppCommand.fromLaunchArguments(["PaperTodoMac"]))

        let payload = AppCommandPayload.encode(nil)
        let forwarded = AppCommandPayload.decode(payload)

        XCTAssertEqual(forwarded, .show)
    }

    func testExitAliasesAreRecognized() {
        XCTAssertEqual(AppCommand(rawArgument: "--exit"), .exit)
        XCTAssertEqual(AppCommand(rawArgument: "quit"), .exit)
        XCTAssertTrue(AppCommand(rawArgument: "--quit")?.isExit == true)
    }

    func testImportConsumesFollowingPathAndStandardizesURL() {
        let command = AppCommand.fromLaunchArguments([
            "PaperTodoMac",
            "--import-data",
            "/tmp/../tmp/papertodo-data.json"
        ])

        guard case .importData(let url) = command else {
            return XCTFail("Expected import-data command")
        }
        XCTAssertEqual(url.path, "/tmp/papertodo-data.json")
    }

    func testImportWithoutPathIsIgnored() {
        XCTAssertNil(AppCommand.fromLaunchArguments(["PaperTodoMac", "--import"]))
        XCTAssertNil(AppCommand.fromLaunchArguments(["PaperTodoMac", "--import", "   "]))
    }

    func testCodableRoundTripPreservesCommands() throws {
        let commands: [AppCommand] = [
            .show,
            .hide,
            .toggle,
            .newTodo,
            .newNote,
            .importData(URL(fileURLWithPath: "/tmp/data.json")),
            .exit
        ]

        for command in commands {
            let data = try JSONEncoder().encode(command)
            let decoded = try JSONDecoder().decode(AppCommand.self, from: data)
            XCTAssertEqual(decoded, command)
        }
    }

    func testPayloadDecodeAcceptsJSONAndLegacyPlainText() {
        XCTAssertEqual(AppCommandPayload.decode(#"{"kind":"hide"}"#), .hide)
        XCTAssertEqual(AppCommandPayload.decode("  --new-note\n"), .newNote)
        XCTAssertEqual(AppCommandPayload.decode(""), nil)
        XCTAssertEqual(AppCommandPayload.decode(#"{"kind":"unknown"}"#), nil)
    }
}
