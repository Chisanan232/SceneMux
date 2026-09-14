@testable import AppBundle
import Foundation
import XCTest

/// The plan as a pure reading of a Scene: intent in, work out, no engine anywhere near it.
///
/// Everything here runs without a Mac, a workspace or a window, which is the point of deriving the plan
/// separately from realising it. What the engine then does with the plan is `SceneProjectorTest` and
/// `WinMuxSceneEngineAdapterTest`.
final class SceneLayoutPlanTest: XCTestCase {
    private typealias App = SceneCoreFixtures.App

    private let substrate = SceneCore.SubstrateBinding(workspaceName: "3")

    func testAPlanDescribesEverySlotOfTheSceneInSlotOrder() throws {
        let scene = try SceneCoreFixtures.debugScene()

        let plan = SceneCore.SceneLayoutPlan(scene, on: substrate)

        XCTAssertEqual(plan.sceneId, scene.id)
        XCTAssertEqual(plan.sceneTitle, "Debug PROD-123")
        XCTAssertEqual(plan.substrate, substrate)
        XCTAssertEqual(plan.groups.map(\.role), [.terminal, .editor, .preview, .observability, .communication])
    }

    func testSlotsStoredOutOfOrderAreLaidOutInTheirOwnOrder() throws {
        let last = SceneCoreFixtures.slot(role: .communication, order: 9)
        let first = SceneCoreFixtures.slot(role: .editor, order: 1)
        let scene = try SceneCoreFixtures.scene(slots: [last, first])

        let plan = SceneCore.SceneLayoutPlan(scene, on: substrate)

        XCTAssertEqual(plan.groups.map(\.slotId), [first.id, last.id])
    }
}
