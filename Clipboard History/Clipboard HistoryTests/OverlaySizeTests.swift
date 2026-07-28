import Foundation
import XCTest
@testable import Clipboard_History

@MainActor
final class OverlaySizeTests: XCTestCase {
    func testClampKeepsAnInBoundsSizeIntact() {
        let size = CGSize(width: 900, height: 620)
        XCTAssertEqual(AppSettings.clampOverlaySize(size), size)
    }

    func testClampRaisesSizesBelowTheUsableMinimum() {
        // A stored size this small would leave no room for the list, and a
        // borderless panel gives the user no obvious way to grow it back.
        let clamped = AppSettings.clampOverlaySize(CGSize(width: 120, height: 60))
        XCTAssertEqual(clamped, AppSettings.minOverlaySize)
    }

    func testClampLowersSizesAboveTheMaximum() {
        let clamped = AppSettings.clampOverlaySize(CGSize(width: 9_000, height: 9_000))
        XCTAssertEqual(clamped, AppSettings.maxOverlaySize)
    }

    func testClampRoundsFractionalSizesToWholePoints() {
        let clamped = AppSettings.clampOverlaySize(CGSize(width: 800.4, height: 600.6))
        XCTAssertEqual(clamped, CGSize(width: 800, height: 601))
    }

    func testClampHandlesEachAxisIndependently() {
        let clamped = AppSettings.clampOverlaySize(CGSize(width: 10, height: 9_000))
        XCTAssertEqual(
            clamped,
            CGSize(
                width: AppSettings.minOverlaySize.width,
                height: AppSettings.maxOverlaySize.height
            )
        )
    }

    func testDefaultsSitInsideTheClampRange() {
        XCTAssertEqual(
            AppSettings.clampOverlaySize(AppSettings.defaultOverlaySize),
            AppSettings.defaultOverlaySize
        )
    }
}
