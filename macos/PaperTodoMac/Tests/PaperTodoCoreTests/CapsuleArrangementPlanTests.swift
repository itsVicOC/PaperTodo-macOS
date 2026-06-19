import XCTest
@testable import PaperTodoMac

final class CapsuleArrangementPlanTests: XCTestCase {
    func testDisabledDeepCapsuleModeClearsMasterStateAndUsesNoSlots() {
        var state = baseState()
        state.useDeepCapsuleMode = false
        state.useCapsuleCollapseAll = true
        state.capsuleCollapseAllActive = true

        let plan = CapsuleArrangementPlan.make(state: state, slottedPaperCount: 3)

        XCTAssertFalse(plan.usesDeepCapsules)
        XCTAssertFalse(plan.showsMasterCapsule)
        XCTAssertTrue(plan.clearsCollapseAllActive)
        XCTAssertEqual(plan.firstPaperSlot, 0)
        XCTAssertFalse(plan.hidesPaperFaces)
    }

    func testMasterCapsuleNeedsAtLeastOneSlottedPaper() {
        var state = baseState()
        state.useCapsuleCollapseAll = true
        state.capsuleCollapseAllActive = true

        let plan = CapsuleArrangementPlan.make(state: state, slottedPaperCount: 0)

        XCTAssertTrue(plan.usesDeepCapsules)
        XCTAssertFalse(plan.showsMasterCapsule)
        XCTAssertTrue(plan.clearsCollapseAllActive)
        XCTAssertEqual(plan.firstPaperSlot, 0)
        XCTAssertFalse(plan.hidesPaperFaces)
    }

    func testMasterCapsuleReservesSlotZeroForRealCapsules() {
        var state = baseState()
        state.useCapsuleCollapseAll = true
        state.capsuleCollapseAllActive = false

        let plan = CapsuleArrangementPlan.make(state: state, slottedPaperCount: 2)

        XCTAssertTrue(plan.showsMasterCapsule)
        XCTAssertFalse(plan.clearsCollapseAllActive)
        XCTAssertEqual(plan.firstPaperSlot, 1)
        XCTAssertFalse(plan.hidesPaperFaces)
    }

    func testActiveMasterCapsuleHidesRealCapsuleFaces() {
        var state = baseState()
        state.useCapsuleCollapseAll = true
        state.capsuleCollapseAllActive = true

        let plan = CapsuleArrangementPlan.make(state: state, slottedPaperCount: 2)

        XCTAssertTrue(plan.showsMasterCapsule)
        XCTAssertEqual(plan.firstPaperSlot, 1)
        XCTAssertTrue(plan.hidesPaperFaces)
    }

    private func baseState() -> AppState {
        var state = AppState()
        state.useCapsuleMode = true
        state.useDeepCapsuleMode = true
        state.useCapsuleCollapseAll = false
        state.capsuleCollapseAllActive = false
        return state
    }
}
