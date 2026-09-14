@testable import AppBundle
import Foundation
import XCTest

final class SceneValidationTest: XCTestCase {
    func testASceneNobodyCouldNameIsRejected() {
        XCTAssertThrowsError(try SceneCoreFixtures.scene(title: " \t ")) { error in
            XCTAssertEqual(error as? SceneCore.SceneCoreError, .emptySceneTitle)
        }
    }
}
