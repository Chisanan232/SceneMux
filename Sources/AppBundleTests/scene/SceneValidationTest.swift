@testable import AppBundle
import Foundation
import XCTest

final class SceneValidationTest: XCTestCase {
    func testATitleIsStoredTheWayItWillBeShown() throws {
        let scene = try SceneCoreFixtures.scene(title: "  Debug PROD-123\n")

        XCTAssertEqual(scene.title, "Debug PROD-123")
    }

    func testASceneNobodyCouldNameIsRejected() {
        XCTAssertThrowsError(try SceneCoreFixtures.scene(title: " \t ")) { error in
            XCTAssertEqual(error as? SceneCore.SceneCoreError, .emptySceneTitle)
        }
    }
}
