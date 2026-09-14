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

    func testOnlyOneSceneCanBeOnScreenAtOnce() throws {
        let scenes = [
            try SceneCoreFixtures.scene(title: "Debug PROD-123", state: .active(.init(workspaceName: "1"))),
            try SceneCoreFixtures.scene(title: "Review the release", state: .active(.init(workspaceName: "2"))),
        ]

        // v0.1.0 projects one task onto the screen at a time. Two Scenes both believing they are the one on
        // screen is how a window ends up claimed by both and moved by whichever asks last.
        XCTAssertThrowsError(try SceneCore.SceneWorld(scenes: scenes)) { error in
            XCTAssertEqual(error as? SceneCore.SceneLifecycleError, .moreThanOneActiveScene)
        }
    }

    func testASceneTheWorldDoesNotHaveCannotBeReplaced() throws {
        let outsider = try SceneCoreFixtures.scene(title: "Never created")
        let world = try SceneCore.SceneWorld(scenes: [try SceneCoreFixtures.scene()])

        XCTAssertThrowsError(try world.replacing(outsider)) { error in
            XCTAssertEqual(error as? SceneCore.SceneLifecycleError, .unknownScene(outsider.id))
        }
    }
}
