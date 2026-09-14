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

    func testASceneThatIsClosingCannotBePutBackOnScreen() throws {
        let scene = try SceneCoreFixtures.debugScene(state: .active(substrate))
        let closing = try SceneCore.SceneWorld(scenes: [scene]).closing(scene.id).world

        // Its borrowed windows are on their way home. Re-entering it would mean racing the teardown for the
        // same windows, so the lifecycle simply has no such transition.
        XCTAssertThrowsError(try closing.entering(scene.id, on: substrate)) { error in
            XCTAssertEqual(
                error as? SceneCore.SceneCoreError,
                .illegalTransition(from: .ending, to: .active),
            )
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

    func testEnteringAndLeavingRepeatedlyLeavesTheSceneExactlyAsItWas() throws {
        let scene = try SceneCoreFixtures.debugScene()
        let world = try SceneCore.SceneWorld(scenes: [scene])

        var cycled = world
        for _ in 1...5 {
            cycled = try cycled.entering(scene.id, on: substrate).leaving(scene.id)
        }

        // Nothing accumulates: not a duplicate attachment, not a second binding, not a Slot that drifted.
        // Layout state that degrades a little each time somebody switches tasks is the failure this rules out.
        XCTAssertEqual(cycled, world)
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

    func testASceneOfWindowsItOpenedItselfEndsAsItCloses() throws {
        let slot = SceneCoreFixtures.slot(role: .terminal)
        let terminal = try SceneCoreFixtures.windowRef(App.terminal)
        let scene = try SceneCoreFixtures.scene(
            slots: [slot],
            attachments: [SceneCoreFixtures.attachment(windowRef: terminal, slotId: slot.id)],
            state: .active(substrate),
        )

        let closed = try SceneCore.SceneWorld(scenes: [scene]).closing(scene.id)

        // Nobody is going to report back about a Scene with nothing pending, so waiting for a report would
        // leave it closing forever. The window is still named in the plan, for a shell to offer closing it.
        XCTAssertEqual(closed.world.scene(scene.id)?.state, .ended)
        XCTAssertEqual(closed.world.scene(scene.id)?.attachments, [])
        XCTAssertEqual(closed.plan.cleanupCandidates.map(\.windowRef), [terminal])
    }

    func testARestoredWindowIsNotRestoredTwice() throws {
        let scene = try SceneCoreFixtures.debugScene(state: .active(substrate))
        let closed = try SceneCore.SceneWorld(scenes: [scene]).closing(scene.id)
        let line = try SceneCoreFixtures.windowRef(App.line)

        let once = try closed.world.resolving(.restored, for: line, in: scene.id)
        let twice = try once.resolving(.restored, for: line, in: scene.id)

        // Invariant I8: restored once per attachment. The report arriving twice — a retry that crossed with a
        // success — finds nothing left to do, because the attachment it was about is gone.
        XCTAssertEqual(once.scene(scene.id)?.attachments.map(\.windowRef), [
            try SceneCoreFixtures.windowRef(App.slack),
        ])
        XCTAssertEqual(twice, once)
    }

    func testAFailedRestoreStaysOwed() throws {
        let scene = try SceneCoreFixtures.debugScene(state: .active(substrate))
        let closed = try SceneCore.SceneWorld(scenes: [scene]).closing(scene.id)
        let line = try SceneCoreFixtures.windowRef(App.line)

        let failed = try closed.world.resolving(.failed(reason: "LINE is busy"), for: line, in: scene.id)

        // The attachment is the record that the restore is still owed and the instruction to try again. No
        // counter to get wrong, and a relaunch inherits the same answer.
        XCTAssertEqual(failed, closed.world)
        XCTAssertEqual(failed.unfinishedTeardowns.first?.pending.map(\.windowRef).first, line)
    }

    func testTheLastRestoreEndsTheScene() throws {
        let scene = try SceneCoreFixtures.debugScene(state: .active(substrate))
        let closed = try SceneCore.SceneWorld(scenes: [scene]).closing(scene.id)

        let world = try closed.world
            .resolving(.restored, for: try SceneCoreFixtures.windowRef(App.line), in: scene.id)
            .resolving(.restored, for: try SceneCoreFixtures.windowRef(App.slack), in: scene.id)

        XCTAssertEqual(world.scene(scene.id)?.state, .ended)
        XCTAssertEqual(world.scene(scene.id)?.attachments, [])
        XCTAssertEqual(world.unfinishedTeardowns, [])
    }

    func testAWindowThatIsAlreadyGoneIsNotSomethingToRestore() throws {
        let scene = try SceneCoreFixtures.debugScene(state: .active(substrate))
        let closed = try SceneCore.SceneWorld(scenes: [scene]).closing(scene.id)

        let world = try closed.world
            .resolving(.windowIsGone, for: try SceneCoreFixtures.windowRef(App.line), in: scene.id)
            .resolving(.windowIsGone, for: try SceneCoreFixtures.windowRef(App.slack), in: scene.id)

        // Someone quitting LINE while the Scene was open is an ordinary Tuesday, not a Scene that can never
        // finish closing.
        XCTAssertEqual(world.scene(scene.id)?.state, .ended)
    }

    func testAWindowDeliberatelyLeftBehindStillEndsTheScene() throws {
        let scene = try SceneCoreFixtures.debugScene(state: .active(substrate))
        let closed = try SceneCore.SceneWorld(scenes: [scene]).closing(scene.id)
        let noHome = SceneCore.SceneTeardownOutcome.leftInPlace(reason: "its Home has no workspace any more")

        let world = try closed.world
            .resolving(noHome, for: try SceneCoreFixtures.windowRef(App.line), in: scene.id)
            .resolving(noHome, for: try SceneCoreFixtures.windowRef(App.slack), in: scene.id)

        // The explicit fallback: a window whose Home cannot be resolved is left where it is rather than moved
        // somewhere invented for it, and it does not hold its Scene open forever either.
        XCTAssertEqual(world.scene(scene.id)?.state, .ended)
        XCTAssertEqual(world.scene(scene.id)?.attachments, [])
    }

    func testAnInterruptedTeardownComesBackAsTheWorkThatIsLeft() throws {
        let scene = try SceneCoreFixtures.debugScene(state: .active(substrate))
        let closed = try SceneCore.SceneWorld(scenes: [scene]).closing(scene.id)
        let line = try SceneCoreFixtures.windowRef(App.line)
        let halfway = try closed.world.resolving(.restored, for: line, in: scene.id)

        // Exactly what a relaunch reads: the Scenes as they were saved, re-derived into plans.
        let afterARestart = try SceneCore.SceneWorld(scenes: halfway.scenes)

        XCTAssertEqual(afterARestart.closingScenes.map(\.id), [scene.id])
        XCTAssertEqual(afterARestart.unfinishedTeardowns.count, 1)
        XCTAssertEqual(
            afterARestart.unfinishedTeardowns.first?.pending.map(\.windowRef),
            [try SceneCoreFixtures.windowRef(App.slack)],
        )
    }

    func testAnOutcomeForASceneThatIsNotClosingIsIgnored() throws {
        let scene = try SceneCoreFixtures.debugScene(state: .active(substrate))
        let world = try SceneCore.SceneWorld(scenes: [scene])
        let line = try SceneCoreFixtures.windowRef(App.line)

        // A report that arrives late must not detach a window from a Scene somebody is still using.
        XCTAssertEqual(try world.resolving(.restored, for: line, in: scene.id), world)
    }

    func testEveryOperationRefusesASceneTheWorldDoesNotHave() throws {
        let world = try SceneCore.SceneWorld(scenes: [try SceneCoreFixtures.debugScene()])
        let never = SceneCore.SceneId.generate()
        let unknown = SceneCore.SceneLifecycleError.unknownScene(never)

        XCTAssertThrowsError(try world.entering(never, on: substrate)) {
            XCTAssertEqual($0 as? SceneCore.SceneLifecycleError, unknown)
        }
        XCTAssertThrowsError(try world.leaving(never)) {
            XCTAssertEqual($0 as? SceneCore.SceneLifecycleError, unknown)
        }
        XCTAssertThrowsError(try world.closing(never)) {
            XCTAssertEqual($0 as? SceneCore.SceneLifecycleError, unknown)
        }
        XCTAssertThrowsError(try world.resolving(.restored, for: try SceneCoreFixtures.windowRef(), in: never)) {
            XCTAssertEqual($0 as? SceneCore.SceneLifecycleError, unknown)
        }
    }
}
