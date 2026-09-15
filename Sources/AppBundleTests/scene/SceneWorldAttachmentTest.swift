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
}
