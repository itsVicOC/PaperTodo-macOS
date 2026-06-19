import Foundation

enum CapsuleSlotPolicy {
    static func shouldOccupySlot(
        paper: PaperData,
        occupiesWindowSlot: Bool,
        state: AppState,
        isLinkedNote: Bool
    ) -> Bool {
        guard state.useCapsuleMode, state.useDeepCapsuleMode else { return false }
        guard paper.isVisible, occupiesWindowSlot else { return false }
        if state.hideLinkedNotesFromCapsules && isLinkedNote {
            return false
        }
        return true
    }
}
