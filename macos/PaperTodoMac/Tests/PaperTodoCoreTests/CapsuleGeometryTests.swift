import CoreGraphics
import XCTest
@testable import PaperTodoCore

final class CapsuleGeometryTests: XCTestCase {
    private let visible = CGRect(x: 100, y: 80, width: 1200, height: 760)
    private let capsuleSize = CGSize(width: 110, height: 46)

    func testCapsuleFrameUsesRightEdgeRestingAndHoverPositions() {
        let resting = CapsuleGeometry.capsuleFrame(
            for: 0,
            in: visible,
            size: capsuleSize,
            expanded: false
        )
        let expanded = CapsuleGeometry.capsuleFrame(
            for: 0,
            in: visible,
            size: capsuleSize,
            expanded: true
        )

        XCTAssertEqual(resting.origin.x, visible.maxX - CapsuleGeometry.restingVisibleWidth)
        XCTAssertEqual(expanded.origin.x, visible.maxX - capsuleSize.width + CapsuleGeometry.hoverOutsideOffset)
        XCTAssertEqual(resting.origin.y, visible.maxY - CapsuleGeometry.topMargin - capsuleSize.height)
        XCTAssertEqual(expanded.origin.y, resting.origin.y)
    }

    func testCapsuleFrameStacksDownAndClampsToBottomMargin() {
        let first = CapsuleGeometry.capsuleFrame(
            for: 0,
            in: visible,
            size: capsuleSize,
            expanded: false
        )
        let second = CapsuleGeometry.capsuleFrame(
            for: 1,
            in: visible,
            size: capsuleSize,
            expanded: false
        )
        let veryLow = CapsuleGeometry.capsuleFrame(
            for: 99,
            in: visible,
            size: capsuleSize,
            expanded: false
        )

        XCTAssertEqual(first.origin.y - second.origin.y, capsuleSize.height + CapsuleGeometry.gap)
        XCTAssertEqual(veryLow.origin.y, visible.minY + CapsuleGeometry.topMargin)
    }

    func testDropIndexHonorsCollapseAllStartIndex() {
        let firstRealSlotCenterY = visible.maxY
            - CapsuleGeometry.topMargin
            - capsuleSize.height / 2
            - (capsuleSize.height + CapsuleGeometry.gap)
        let layoutIndex = CapsuleGeometry.dropIndex(
            for: firstRealSlotCenterY,
            count: 3,
            in: visible,
            capsuleSize: capsuleSize,
            startIndex: 1
        )

        XCTAssertEqual(layoutIndex, 1)
        XCTAssertEqual(layoutIndex - 1, 0)
    }

    func testDropIndexClampsOutsideStack() {
        let topIndex = CapsuleGeometry.dropIndex(
            for: visible.maxY + 200,
            count: 4,
            in: visible,
            capsuleSize: capsuleSize
        )
        let bottomIndex = CapsuleGeometry.dropIndex(
            for: visible.minY - 200,
            count: 4,
            in: visible,
            capsuleSize: capsuleSize
        )

        XCTAssertEqual(topIndex, 0)
        XCTAssertEqual(bottomIndex, 3)
    }

    func testHoverRetainFrameDoesNotExtendPastRightEdge() {
        let expanded = CapsuleGeometry.capsuleFrame(
            for: 0,
            in: visible,
            size: capsuleSize,
            expanded: true
        )
        let retain = CapsuleGeometry.rightEdgeHoverRetainFrame(for: expanded)

        XCTAssertEqual(retain.minX, expanded.minX - CapsuleGeometry.hoverRetainTolerance)
        XCTAssertEqual(retain.maxX, expanded.maxX)
        XCTAssertTrue(retain.contains(CGPoint(x: expanded.minX - 1, y: expanded.midY)))
        XCTAssertTrue(retain.contains(CGPoint(x: expanded.midX, y: expanded.minY - 1)))
        XCTAssertFalse(retain.contains(CGPoint(x: expanded.maxX + 1, y: expanded.midY)))
    }

    func testExpandedPaperFrameAvoidsReservedEdgeCapsuleWithoutChangingSize() {
        let frame = CapsuleGeometry.expandedPaperFrame(
            currentFrame: CGRect(x: 250, y: 200, width: 333, height: 222),
            normalSize: CGSize(width: 333, height: 222),
            minSize: CGSize(width: 220, height: 160),
            visibleFrame: visible,
            reservedCapsuleWidth: 110,
            reservesEdgeCapsule: true
        )

        XCTAssertEqual(frame.width, 333)
        XCTAssertEqual(frame.height, 222)
        XCTAssertEqual(frame.origin.x, visible.maxX - 333 - max(CapsuleGeometry.expandedPaperRightInset, 110 + CapsuleGeometry.gap))
        XCTAssertEqual(frame.origin.y, 200)
    }

    func testExpandedPaperFrameUsesDefaultInsetWithoutReservation() {
        let frame = CapsuleGeometry.expandedPaperFrame(
            currentFrame: CGRect(x: 250, y: 200, width: 333, height: 222),
            normalSize: CGSize(width: 333, height: 222),
            minSize: CGSize(width: 220, height: 160),
            visibleFrame: visible,
            reservedCapsuleWidth: 110,
            reservesEdgeCapsule: false
        )

        XCTAssertEqual(frame.origin.x, visible.maxX - 333 - CapsuleGeometry.expandedPaperRightInset)
    }

    func testExpandedPaperFrameClampsToVisibleHeightAndWidth() {
        let narrow = CGRect(x: 0, y: 0, width: 260, height: 220)
        let frame = CapsuleGeometry.expandedPaperFrame(
            currentFrame: CGRect(x: 10, y: -100, width: 400, height: 300),
            normalSize: CGSize(width: 400, height: 300),
            minSize: CGSize(width: 220, height: 160),
            visibleFrame: narrow,
            reservedCapsuleWidth: 110,
            reservesEdgeCapsule: true
        )

        XCTAssertEqual(frame.width, 400)
        XCTAssertEqual(frame.height, 300)
        XCTAssertEqual(frame.origin.x, narrow.maxX - 400)
        XCTAssertEqual(frame.origin.y, narrow.minY + CapsuleGeometry.topMargin)
    }
}
