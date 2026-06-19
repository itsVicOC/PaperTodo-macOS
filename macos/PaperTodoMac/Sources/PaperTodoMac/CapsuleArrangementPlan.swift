import Foundation

struct CapsuleArrangementPlan: Equatable {
    let usesDeepCapsules: Bool
    let showsMasterCapsule: Bool
    let clearsCollapseAllActive: Bool
    let firstPaperSlot: Int
    let hidesPaperFaces: Bool

    static func make(state: AppState, slottedPaperCount: Int) -> CapsuleArrangementPlan {
        let usesDeepCapsules = state.useCapsuleMode && state.useDeepCapsuleMode
        guard usesDeepCapsules else {
            return CapsuleArrangementPlan(
                usesDeepCapsules: false,
                showsMasterCapsule: false,
                clearsCollapseAllActive: true,
                firstPaperSlot: 0,
                hidesPaperFaces: false
            )
        }

        let showsMaster = state.useCapsuleCollapseAll && slottedPaperCount > 0
        return CapsuleArrangementPlan(
            usesDeepCapsules: true,
            showsMasterCapsule: showsMaster,
            clearsCollapseAllActive: !showsMaster,
            firstPaperSlot: showsMaster ? 1 : 0,
            hidesPaperFaces: showsMaster && state.capsuleCollapseAllActive
        )
    }
}
