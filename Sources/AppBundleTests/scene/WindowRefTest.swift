@testable import AppBundle
import Foundation
import XCTest

final class WindowRefTest: XCTestCase {
    func testABundleIdOfNothingButWhitespaceIsRejected() {
        XCTAssertThrowsError(try SceneCoreFixtures.windowRef("   \n ")) { error in
            XCTAssertEqual(error as? SceneCore.SceneCoreError, .emptyBundleId)
        }
    }

    func testANegativeOrdinalIsRejected() {
        XCTAssertThrowsError(try SceneCoreFixtures.windowRef(ordinal: -1)) { error in
            XCTAssertEqual(error as? SceneCore.SceneCoreError, .negativeWindowOrdinal(-1))
        }
    }
}
