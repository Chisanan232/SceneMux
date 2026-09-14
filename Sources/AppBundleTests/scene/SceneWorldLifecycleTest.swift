@testable import AppBundle
import Foundation
import XCTest

/// The lifecycle as the world sees it: which Scene is on screen, and what ending one owes its windows.
///
/// Nothing here touches a window, because nothing in `SceneWorld` can. These tests are about the decisions —
/// the layer that carries them out is verified against a real desktop in HORO-1105 and HORO-1106.
final class SceneWorldLifecycleTest: XCTestCase {
    private typealias App = SceneCoreFixtures.App

    private let substrate = SceneCore.SubstrateBinding(workspaceName: "3")
    private let elsewhere = SceneCore.SubstrateBinding(workspaceName: "7")

    func testANewSceneArrivesDefinedAndEmpty() throws {
        let created = try SceneCore.SceneWorld.empty.creating(title: "Debug PROD-123")

        XCTAssertEqual(created.scene.title, "Debug PROD-123")
        XCTAssertEqual(created.scene.state, .defined)
        XCTAssertEqual(created.scene.attachments, [])
        XCTAssertEqual(created.world.scenes, [created.scene])
        XCTAssertNil(created.world.activeScene)
    }
}
