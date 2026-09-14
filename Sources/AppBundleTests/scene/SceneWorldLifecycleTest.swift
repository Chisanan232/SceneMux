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

    func testEnteringASceneProjectsItOntoASubstrate() throws {
        let created = try SceneCore.SceneWorld.empty.creating(title: "Debug PROD-123")

        let world = try created.world.entering(created.scene.id, on: substrate)

        XCTAssertEqual(world.activeScene?.id, created.scene.id)
        XCTAssertEqual(world.scene(created.scene.id)?.state, .active(substrate))
    }

    func testEnteringTheSceneAlreadyOnScreenChangesNothing() throws {
        let scene = try SceneCoreFixtures.debugScene(state: .active(substrate))
        let world = try SceneCore.SceneWorld(scenes: [scene])

        // The same shortcut pressed twice, or a click on the Scene already showing. Anything other than
        // nothing here is a desktop rearranging itself for no reason.
        XCTAssertEqual(try world.entering(scene.id, on: substrate), world)
    }

    func testMovingAnActiveSceneToAnotherSubstrateKeepsEveryAttachment() throws {
        let scene = try SceneCoreFixtures.debugScene(state: .active(substrate))
        let world = try SceneCore.SceneWorld(scenes: [scene])

        let moved = try world.entering(scene.id, on: elsewhere)

        XCTAssertEqual(moved.scene(scene.id)?.state, .active(elsewhere))
        XCTAssertEqual(moved.scene(scene.id)?.attachments, scene.attachments)
    }

    func testASecondSceneCannotBeEnteredWhileOneIsOnScreen() throws {
        let showing = try SceneCoreFixtures.scene(title: "Debug PROD-123", state: .active(substrate))
        let other = try SceneCoreFixtures.scene(title: "Review the release")
        let world = try SceneCore.SceneWorld(scenes: [showing, other])

        // Refused rather than swapped. Quietly leaving somebody's current task as a side effect is a decision
        // they should make and see.
        XCTAssertThrowsError(try world.entering(other.id, on: elsewhere)) { error in
            XCTAssertEqual(error as? SceneCore.SceneLifecycleError, .anotherSceneIsActive(showing.id))
        }
    }

    func testLeavingASceneMovesNothingAndForgetsNothing() throws {
        let scene = try SceneCoreFixtures.debugScene(state: .active(substrate))
        let world = try SceneCore.SceneWorld(scenes: [scene])

        let left = try world.leaving(scene.id)

        XCTAssertEqual(left.scene(scene.id)?.state, .defined)
        XCTAssertNil(left.activeScene)
        // Still about the same six windows: leaving is not a small teardown, and switching tasks and back
        // must not send borrowed windows home twice.
        XCTAssertEqual(left.scene(scene.id)?.attachments, scene.attachments)
    }

    func testLeavingASceneThatIsNotOnScreenIsANoOp() throws {
        let world = try SceneCore.SceneWorld(scenes: [try SceneCoreFixtures.debugScene()])
        let id = try XCTUnwrap(world.scenes.first?.id)

        XCTAssertEqual(try world.leaving(id), world)
    }

    func testClosingTheGoldenJourneyOwesOnlyTheBorrowedWindows() throws {
        let scene = try SceneCoreFixtures.debugScene(state: .active(substrate))
        let world = try SceneCore.SceneWorld(scenes: [scene])

        let closed = try world.closing(scene.id)

        // The plan is the whole sentence, including the windows nothing happens to.
        XCTAssertEqual(closed.plan.sceneTitle, "Debug PROD-123")
        XCTAssertEqual(closed.plan.steps.count, 6)
        XCTAssertEqual(
            closed.plan.pending.map(\.windowRef),
            [try SceneCoreFixtures.windowRef(App.line), try SceneCoreFixtures.windowRef(App.slack)],
        )
        XCTAssertEqual(closed.plan.pending.map(\.recordedHome), [.communication, .communication])
        XCTAssertEqual(
            closed.plan.cleanupCandidates.map(\.windowRef),
            [
                try SceneCoreFixtures.windowRef(App.terminal),
                try SceneCoreFixtures.windowRef(App.ide),
                try SceneCoreFixtures.windowRef(App.browser),
                try SceneCoreFixtures.windowRef(App.grafana),
            ],
        )
        // What is left attached is what is left owed: the two borrowed windows, and nothing else.
        XCTAssertEqual(closed.world.scene(scene.id)?.state, .ending)
        XCTAssertEqual(closed.world.scene(scene.id)?.attachments.map(\.ownership), [.borrowed, .borrowed])
    }

    func testClosingASceneCannotTouchASharedApplication() throws {
        let slot = SceneCoreFixtures.slot(role: .communication)
        let music = try SceneCoreFixtures.windowRef(App.music)
        let scene = try SceneCoreFixtures.scene(
            title: "Debug PROD-123",
            slots: [slot],
            attachments: [
                SceneCoreFixtures.attachment(
                    windowRef: music,
                    slotId: slot.id,
                    ownership: .sharedPersistent,
                    homeAtAttachTime: .personal,
                ),
            ],
            state: .active(substrate),
        )

        let closed = try SceneCore.SceneWorld(scenes: [scene]).closing(scene.id)

        // Not restored, and not even offered for cleanup: a shared window belongs to the person's whole day,
        // and the Scene that borrowed the screen space it sat in has no say over it.
        XCTAssertEqual(closed.plan.steps.map(\.effect), [.untouched])
        XCTAssertEqual(closed.plan.pending, [])
        XCTAssertEqual(closed.plan.cleanupCandidates, [])
        XCTAssertEqual(closed.world.scene(scene.id)?.state, .ended)
    }
}
