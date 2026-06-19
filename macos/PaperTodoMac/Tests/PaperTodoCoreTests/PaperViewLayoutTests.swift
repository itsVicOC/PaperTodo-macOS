import AppKit
import XCTest
@testable import PaperTodoMac

@MainActor
final class PaperViewLayoutTests: XCTestCase {
    func testCollapsedCapsuleSizeDoesNotGrowWithLongTitle() {
        let short = collapsedPaper(title: "Short")
        let long = collapsedPaper(title: String(repeating: "Very long capsule title ", count: 12))
        let shortView = PaperView(
            paper: short,
            appState: capsuleState(),
            linkedNotes: [],
            palette: PaperTheme.palette(for: "warm", dark: false)
        )
        let longView = PaperView(
            paper: long,
            appState: capsuleState(),
            linkedNotes: [],
            palette: PaperTheme.palette(for: "warm", dark: false)
        )

        shortView.frame = NSRect(origin: .zero, size: CapsuleLayout.compactSize)
        longView.frame = NSRect(origin: .zero, size: CapsuleLayout.compactSize)
        shortView.layoutSubtreeIfNeeded()
        longView.layoutSubtreeIfNeeded()

        XCTAssertEqual(shortView.fittingSize.width, CapsuleLayout.compactSize.width, accuracy: 0.5)
        XCTAssertEqual(longView.fittingSize.width, CapsuleLayout.compactSize.width, accuracy: 0.5)
        XCTAssertEqual(shortView.fittingSize.height, CapsuleLayout.compactSize.height, accuracy: 0.5)
        XCTAssertEqual(longView.fittingSize.height, CapsuleLayout.compactSize.height, accuracy: 0.5)
    }

    func testExpandingFromCollapsedCapsuleRemovesCapsuleSizeConstraints() {
        var collapsed = collapsedPaper(title: String(repeating: "Long title ", count: 16))
        collapsed.type = PaperKind.note.rawValue
        collapsed.content = "A note body"
        var expanded = collapsed
        expanded.isCollapsed = false
        expanded.width = 320
        expanded.height = 360

        let view = PaperView(
            paper: collapsed,
            appState: capsuleState(),
            linkedNotes: [],
            palette: PaperTheme.palette(for: "warm", dark: false)
        )
        view.frame = NSRect(origin: .zero, size: CapsuleLayout.compactSize)
        view.layoutSubtreeIfNeeded()

        view.updatePaper(expanded)
        view.frame = NSRect(x: 0, y: 0, width: expanded.width, height: expanded.height)
        view.layoutSubtreeIfNeeded()

        XCTAssertEqual(view.bounds.width, expanded.width, accuracy: 0.5)
        XCTAssertEqual(view.bounds.height, expanded.height, accuracy: 0.5)
        XCTAssertFalse(hasConstraint(in: view, constant: CapsuleLayout.compactSize.width))
        XCTAssertFalse(hasConstraint(in: view, constant: CapsuleLayout.compactSize.height))
    }

    private func collapsedPaper(title: String) -> PaperData {
        var paper = PaperData()
        paper.title = title
        paper.isCollapsed = true
        paper.isVisible = true
        return paper
    }

    private func capsuleState() -> AppState {
        var state = AppState()
        state.useCapsuleMode = true
        state.useDeepCapsuleMode = true
        return state
    }

    private func hasConstraint(in view: NSView, constant: CGFloat) -> Bool {
        allConstraints(in: view).contains { constraint in
            abs(constraint.constant - constant) <= 0.5
        }
    }

    private func allConstraints(in view: NSView) -> [NSLayoutConstraint] {
        view.constraints + view.subviews.flatMap(allConstraints)
    }
}
