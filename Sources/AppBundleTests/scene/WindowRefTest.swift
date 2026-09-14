@testable import AppBundle
import Foundation
import XCTest

final class WindowRefTest: XCTestCase {
    func testABundleIdOfNothingButWhitespaceIsRejected() {
        XCTAssertThrowsError(try SceneCoreFixtures.windowRef("   \n ")) { error in
            XCTAssertEqual(error as? SceneCore.SceneCoreError, .emptyBundleId)
        }
    }
}
