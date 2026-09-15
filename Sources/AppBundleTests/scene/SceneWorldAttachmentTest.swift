@testable import AppBundle
import Foundation
import XCTest

final class SceneWorldAttachmentTest: XCTestCase {
    func testAttachingAddsTheWindowToTheNamedSceneAndLeavesTheOtherAlone() throws {
        let slot = SceneCoreFixtures.slot(role: .terminal)
        let debug = try SceneCoreFixtures.scene(title: "Debug PROD-123", slots: [slot])
        let review = try SceneCoreFixtures.scene(title: "Review the release", slots: [slot])
        let world = try SceneCore.SceneWorld(scenes: [debug, review])
        let window = try SceneCoreFixtures.windowRef(SceneCoreFixtures.App.terminal)

        let after = try world.attaching(
            SceneCoreFixtures.attachment(windowRef: window, slotId: slot.id),
            to: debug.id,
        )

        XCTAssertEqual(after.scene(debug.id)?.attachments.map(\.windowRef), [window])
        XCTAssertEqual(after.scene(review.id)?.attachments, [])
    }

    func testAWindowAnotherSceneAlreadyHoldsIsRefused() throws {
        // Invariant I4. Two Scenes each holding a promise about one window is how a window gets sent "home"
        // by a Scene that never borrowed it — to the Home the second Scene recorded, which is wherever the
        // first Scene had already put it.
        let slot = SceneCoreFixtures.slot(role: .communication)
        let window = try SceneCoreFixtures.windowRef(SceneCoreFixtures.App.line)
        let debug = try SceneCoreFixtures.scene(title: "Debug PROD-123", slots: [slot])
            .attaching(SceneCoreFixtures.attachment(
                windowRef: window,
                slotId: slot.id,
                ownership: .borrowed,
            ))
        let review = try SceneCoreFixtures.scene(title: "Review the release", slots: [slot])
        let world = try SceneCore.SceneWorld(scenes: [debug, review])

        XCTAssertThrowsError(try world.attaching(
            SceneCoreFixtures.attachment(windowRef: window, slotId: slot.id, ownership: .borrowed),
            to: review.id,
        )) { error in
            XCTAssertEqual(error as? SceneCore.SceneLifecycleError, .windowAlreadyAttached(debug.id))
        }
    }

    func testASceneBeingTornDownAcceptsNoMoreWindows() throws {
        // While `ending`, a Scene's attachments have stopped describing what is on screen and become the list
        // of restores it still owes. A window added to that list would be sent to a Home nobody took it from.
        let slot = SceneCoreFixtures.slot(role: .terminal)
        let closing = try SceneCoreFixtures.scene(slots: [slot], state: .ending)
        let world = try SceneCore.SceneWorld(scenes: [closing])

        XCTAssertThrowsError(try world.attaching(
            SceneCoreFixtures.attachment(
                windowRef: try SceneCoreFixtures.windowRef(SceneCoreFixtures.App.terminal),
                slotId: slot.id,
            ),
            to: closing.id,
        )) { error in
            XCTAssertEqual(error as? SceneCore.SceneLifecycleError, .sceneIsClosing(closing.id))
        }
    }

    func testDetachingForgetsTheWindowAndAskingTwiceIsHarmless() throws {
        // Idempotent because the paths that reach it include a window that has already gone and an unmount
        // the user clicked twice. Neither is a reason to fail — the state they asked for is the state there is.
        let slot = SceneCoreFixtures.slot(role: .communication)
        let window = try SceneCoreFixtures.windowRef(SceneCoreFixtures.App.slack)
        let scene = try SceneCoreFixtures.scene(slots: [slot])
            .attaching(SceneCoreFixtures.attachment(
                windowRef: window,
                slotId: slot.id,
                ownership: .borrowed,
            ))
        let world = try SceneCore.SceneWorld(scenes: [scene])

        let once = try world.detaching(window, from: scene.id)
        let twice = try once.detaching(window, from: scene.id)

        XCTAssertEqual(once.scene(scene.id)?.attachments, [])
        XCTAssertEqual(twice, once)
    }

    func testARestoreStillOwedCannotBeDetachedBehindTheTeardownsBack() throws {
        // The one way an `ending` Scene loses an attachment is `resolving(_:for:in:)`, which needs an outcome
        // saying the window was actually dealt with. Dropping it here instead would discharge the promise to
        // send a borrowed window home without keeping it — and nothing would ever notice.
        let slot = SceneCoreFixtures.slot(role: .communication)
        let window = try SceneCoreFixtures.windowRef(SceneCoreFixtures.App.line)
        let closing = try SceneCoreFixtures.scene(slots: [slot], state: .ending)
            .attaching(SceneCoreFixtures.attachment(
                windowRef: window,
                slotId: slot.id,
                ownership: .borrowed,
                originSurface: SceneCoreFixtures.communicationSurface,
            ))
        let world = try SceneCore.SceneWorld(scenes: [closing])

        XCTAssertThrowsError(try world.detaching(window, from: closing.id)) { error in
            XCTAssertEqual(error as? SceneCore.SceneLifecycleError, .sceneIsClosing(closing.id))
        }
    }
}
