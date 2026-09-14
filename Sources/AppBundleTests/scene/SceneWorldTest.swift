@testable import AppBundle
import Foundation
import XCTest

final class SceneWorldTest: XCTestCase {
    func testTwoScenesCannotClaimTheSameIdentity() throws {
        let id = SceneCore.SceneId.generate()
        let scenes = [
            try SceneCoreFixtures.scene(id: id, title: "Debug PROD-123"),
            try SceneCoreFixtures.scene(id: id, title: "Review the release"),
        ]

        XCTAssertThrowsError(try SceneCore.SceneWorld(scenes: scenes)) { error in
            XCTAssertEqual(error as? SceneCore.SceneLifecycleError, .duplicateSceneId(id))
        }
    }
}
