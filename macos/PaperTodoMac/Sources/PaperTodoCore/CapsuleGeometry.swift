import CoreGraphics
import Foundation

public enum CapsuleGeometry {
    public static let gap: CGFloat = 6
    public static let topMargin: CGFloat = 18
    public static let restingVisibleWidth: CGFloat = 58
    public static let hoverOutsideOffset: CGFloat = -6
    public static let expandedPaperRightInset: CGFloat = 36
    public static let hoverRetainTolerance: CGFloat = 8

    public static func capsuleFrame(
        for index: Int,
        in visibleFrame: CGRect,
        size: CGSize,
        expanded: Bool
    ) -> CGRect {
        let x: CGFloat
        if expanded {
            x = visibleFrame.maxX - size.width + hoverOutsideOffset
        } else {
            x = visibleFrame.maxX - restingVisibleWidth
        }

        let top = visibleFrame.maxY - topMargin - size.height - (CGFloat(index) * (size.height + gap))
        let minY = visibleFrame.minY + topMargin
        return CGRect(
            x: x.rounded(),
            y: max(minY, top).rounded(),
            width: size.width,
            height: size.height
        )
    }

    public static func dropIndex(
        for screenY: CGFloat,
        count: Int,
        in visibleFrame: CGRect,
        capsuleSize: CGSize,
        startIndex: Int = 0
    ) -> Int {
        guard count > 0 else { return 0 }
        let firstCenterY = visibleFrame.maxY - topMargin - (capsuleSize.height / 2) - (CGFloat(startIndex) * (capsuleSize.height + gap))
        let slotHeight = capsuleSize.height + gap
        let raw = Int(round((firstCenterY - screenY) / slotHeight))
        return startIndex + min(max(raw, 0), count - 1)
    }

    public static func rightEdgeHoverRetainFrame(for expandedFrame: CGRect) -> CGRect {
        CGRect(
            x: expandedFrame.minX - hoverRetainTolerance,
            y: expandedFrame.minY - hoverRetainTolerance,
            width: expandedFrame.width + hoverRetainTolerance,
            height: expandedFrame.height + (hoverRetainTolerance * 2)
        )
    }

    public static func expandedPaperFrame(
        currentFrame: CGRect,
        normalSize: CGSize,
        minSize: CGSize,
        visibleFrame: CGRect,
        reservedCapsuleWidth: CGFloat,
        reservesEdgeCapsule: Bool
    ) -> CGRect {
        let width = max(normalSize.width, minSize.width)
        let height = max(normalSize.height, minSize.height)
        let minimumRightInset = reservesEdgeCapsule
            ? max(expandedPaperRightInset, reservedCapsuleWidth + gap)
            : expandedPaperRightInset
        let rightInset = min(minimumRightInset, max(0, visibleFrame.width - width))
        let minY = visibleFrame.minY + topMargin
        let maxY = max(minY, visibleFrame.maxY - height - topMargin)

        return CGRect(
            x: (visibleFrame.maxX - width - rightInset).rounded(),
            y: min(max(currentFrame.origin.y, minY), maxY).rounded(),
            width: width,
            height: height
        )
    }
}
