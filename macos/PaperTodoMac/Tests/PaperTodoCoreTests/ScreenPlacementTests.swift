import CoreGraphics
import XCTest
@testable import PaperTodoCore

final class ScreenPlacementTests: XCTestCase {
    private let left = CGRect(x: -1440, y: 0, width: 1440, height: 900)
    private let main = CGRect(x: 0, y: 0, width: 1512, height: 982)
    private let right = CGRect(x: 1512, y: 0, width: 1280, height: 720)

    func testBestScreenUsesLargestIntersectionArea() {
        let frame = CGRect(x: -80, y: 120, width: 240, height: 220)

        XCTAssertEqual(ScreenPlacement.bestScreenIndex(for: frame, screens: [left, main, right]), 1)
    }

    func testBestScreenUsesNearestCenterWhenFrameIsOffscreen() {
        let frame = CGRect(x: 3000, y: 200, width: 240, height: 220)

        XCTAssertEqual(ScreenPlacement.bestScreenIndex(for: frame, screens: [left, main, right]), 2)
    }

    func testBestScreenReturnsNilWithoutScreens() {
        XCTAssertNil(ScreenPlacement.bestScreenIndex(for: .zero, screens: []))
    }
}
