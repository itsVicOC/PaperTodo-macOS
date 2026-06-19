import AppKit
import XCTest
@testable import PaperTodoMac

final class MarkdownStylerTests: XCTestCase {
    func testTaskListMarkersAreMutedAndCompletedTextIsStruckThrough() {
        let text = "- [ ] open item\n- [x] done item"
        let styled = MarkdownStyler.attributedString(
            from: text,
            mode: MarkdownRenderMode.enhanced.rawValue,
            baseFontSize: 14,
            palette: PaperTheme.palette(for: "warm", dark: false)
        )

        XCTAssertNotNil(styled.attribute(.foregroundColor, at: location(of: "- [ ]", in: text), effectiveRange: nil))
        XCTAssertNotNil(styled.attribute(.foregroundColor, at: location(of: "- [x]", in: text), effectiveRange: nil))
        XCTAssertNil(styled.attribute(.strikethroughStyle, at: location(of: "open item", in: text), effectiveRange: nil))
        XCTAssertEqual(
            styled.attribute(.strikethroughStyle, at: location(of: "done item", in: text), effectiveRange: nil) as? Int,
            NSUnderlineStyle.single.rawValue
        )
    }

    func testOrderedTaskListIsRecognized() {
        let text = "1. [X] done"
        let styled = MarkdownStyler.attributedString(
            from: text,
            mode: MarkdownRenderMode.enhanced.rawValue,
            baseFontSize: 14,
            palette: PaperTheme.palette(for: "warm", dark: false)
        )

        XCTAssertNotNil(styled.attribute(.foregroundColor, at: location(of: "1. [X]", in: text), effectiveRange: nil))
        XCTAssertEqual(
            styled.attribute(.strikethroughStyle, at: location(of: "done", in: text), effectiveRange: nil) as? Int,
            NSUnderlineStyle.single.rawValue
        )
    }

    private func location(of needle: String, in text: String) -> Int {
        let range = (text as NSString).range(of: needle)
        XCTAssertNotEqual(range.location, NSNotFound)
        return range.location
    }
}
