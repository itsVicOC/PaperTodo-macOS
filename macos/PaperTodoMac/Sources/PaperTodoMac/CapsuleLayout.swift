import AppKit
import PaperTodoCore

enum CapsuleLayout {
    static let gap = CapsuleGeometry.gap
    static let topMargin = CapsuleGeometry.topMargin
    static let restingVisibleWidth = CapsuleGeometry.restingVisibleWidth
    static let hoverOutsideOffset = CapsuleGeometry.hoverOutsideOffset
    static let expandedPaperRightInset = CapsuleGeometry.expandedPaperRightInset
    static let slideDuration: TimeInterval = 0.18

    static var fullSize: NSSize {
        NSSize(width: PaperDefaults.capsuleWidth + 12, height: PaperDefaults.capsuleHeight - 10)
    }

    static var compactSize: NSSize {
        NSSize(width: PaperDefaults.capsuleWidth + 12, height: PaperDefaults.capsuleHeight - 10)
    }

    static func frame(for index: Int, on screen: NSScreen?, expanded: Bool) -> NSRect {
        let visible = (screen ?? NSScreen.main)?.visibleFrame ?? NSRect(x: 0, y: 0, width: 900, height: 700)
        return CapsuleGeometry.capsuleFrame(
            for: index,
            in: visible,
            size: compactSize,
            expanded: expanded
        )
    }

    static func screen(forPaperFrame frame: NSRect, screens: [NSScreen] = NSScreen.screens) -> NSScreen? {
        let frames = screens.map(\.visibleFrame)
        guard let index = ScreenPlacement.bestScreenIndex(for: frame, screens: frames),
              screens.indices.contains(index) else {
            return NSScreen.main
        }
        return screens[index]
    }

    static func index(for screenY: CGFloat, count: Int, on screen: NSScreen?, startIndex: Int = 0) -> Int {
        let visible = (screen ?? NSScreen.main)?.visibleFrame ?? NSRect(x: 0, y: 0, width: 900, height: 700)
        return CapsuleGeometry.dropIndex(
            for: screenY,
            count: count,
            in: visible,
            capsuleSize: compactSize,
            startIndex: startIndex
        )
    }

    static func hoverRetainFrame(for expandedFrame: NSRect) -> NSRect {
        CapsuleGeometry.rightEdgeHoverRetainFrame(for: expandedFrame)
    }

    static func expandedPaperFrame(
        currentFrame: NSRect,
        normalSize: NSSize,
        minSize: NSSize,
        on screen: NSScreen?,
        reservedCapsuleWidth: CGFloat,
        reservesEdgeCapsule: Bool
    ) -> NSRect {
        let visible = (screen ?? NSScreen.main)?.visibleFrame ?? NSRect(x: 0, y: 0, width: 900, height: 700)
        return CapsuleGeometry.expandedPaperFrame(
            currentFrame: currentFrame,
            normalSize: normalSize,
            minSize: minSize,
            visibleFrame: visible,
            reservedCapsuleWidth: reservedCapsuleWidth,
            reservesEdgeCapsule: reservesEdgeCapsule
        )
    }
}
