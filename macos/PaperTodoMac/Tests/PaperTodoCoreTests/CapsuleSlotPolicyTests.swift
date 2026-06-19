import XCTest
@testable import PaperTodoMac

final class CapsuleSlotPolicyTests: XCTestCase {
    func testVisibleCollapsedPaperOccupiesSlotInDeepCapsuleMode() {
        XCTAssertTrue(CapsuleSlotPolicy.shouldOccupySlot(
            paper: paper(isVisible: true),
            occupiesWindowSlot: true,
            state: state(),
            isLinkedNote: false
        ))
    }

    func testHiddenPaperOrWindowWithoutSlotDoesNotOccupySlot() {
        XCTAssertFalse(CapsuleSlotPolicy.shouldOccupySlot(
            paper: paper(isVisible: false),
            occupiesWindowSlot: true,
            state: state(),
            isLinkedNote: false
        ))
        XCTAssertFalse(CapsuleSlotPolicy.shouldOccupySlot(
            paper: paper(isVisible: true),
            occupiesWindowSlot: false,
            state: state(),
            isLinkedNote: false
        ))
    }

    func testDeepCapsuleSettingsGateSlotOccupancy() {
        var noCapsule = state()
        noCapsule.useCapsuleMode = false
        XCTAssertFalse(CapsuleSlotPolicy.shouldOccupySlot(
            paper: paper(isVisible: true),
            occupiesWindowSlot: true,
            state: noCapsule,
            isLinkedNote: false
        ))

        var noDeepCapsule = state()
        noDeepCapsule.useDeepCapsuleMode = false
        XCTAssertFalse(CapsuleSlotPolicy.shouldOccupySlot(
            paper: paper(isVisible: true),
            occupiesWindowSlot: true,
            state: noDeepCapsule,
            isLinkedNote: false
        ))
    }

    func testLinkedNotesCanBeHiddenFromCapsuleSlots() {
        var hiddenLinkedNotes = state()
        hiddenLinkedNotes.hideLinkedNotesFromCapsules = true

        XCTAssertFalse(CapsuleSlotPolicy.shouldOccupySlot(
            paper: paper(isVisible: true),
            occupiesWindowSlot: true,
            state: hiddenLinkedNotes,
            isLinkedNote: true
        ))
        XCTAssertTrue(CapsuleSlotPolicy.shouldOccupySlot(
            paper: paper(isVisible: true),
            occupiesWindowSlot: true,
            state: hiddenLinkedNotes,
            isLinkedNote: false
        ))
    }

    private func paper(isVisible: Bool) -> PaperData {
        var paper = PaperData()
        paper.isVisible = isVisible
        paper.isCollapsed = true
        return paper
    }

    private func state() -> AppState {
        var state = AppState()
        state.useCapsuleMode = true
        state.useDeepCapsuleMode = true
        state.hideLinkedNotesFromCapsules = false
        return state
    }
}
