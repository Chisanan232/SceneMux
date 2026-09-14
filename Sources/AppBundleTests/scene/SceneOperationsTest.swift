@testable import AppBundle
import Foundation
import XCTest

final class SceneOperationsTest: XCTestCase {
    func testRemovingASlotTheSceneNeverHadIsNotSilentlyForgiven() throws {
        // Removing an empty Slot succeeds, so a caller that passes the wrong id would otherwise see the same
        // "nothing left to do" answer as a caller that succeeded.
        let slot = SceneCoreFixtures.slot(role: .preview)
        let scene = try SceneCoreFixtures.scene(slots: [slot])
        let elsewhere = SceneCore.SlotId.generate()

        XCTAssertEqual(try scene.removingSlot(slot.id).slots, [])
        XCTAssertThrowsError(try scene.removingSlot(elsewhere)) { error in
            XCTAssertEqual(error as? SceneCore.SceneCoreError, .unknownSlot(elsewhere))
        }
    }

    func testRemovingASlotThatStillHoldsWindowsIsRefused() throws {
        let slot = SceneCoreFixtures.slot(role: .communication)
        let scene = try SceneCoreFixtures.scene(slots: [slot])
            .attaching(SceneCoreFixtures.attachment(
                windowRef: try SceneCoreFixtures.windowRef("com.linecorp.LINE"),
                slotId: slot.id,
                ownership: .borrowed,
            ))

        XCTAssertThrowsError(try scene.removingSlot(slot.id)) { error in
            XCTAssertEqual(error as? SceneCore.SceneCoreError, .slotNotEmpty(slot.id))
        }
        // The promise to send that borrowed window home is recorded in its attachment, so dropping the Slot
        // would drop the promise.
        XCTAssertEqual(scene.attachments.count, 1)
    }

    func testDetachingAWindowTheSceneNeverHeldChangesNothing() throws {
        // Detach is what teardown and "the window closed while we were not looking" both call, and neither
        // knows whether the attachment is still there. Idempotence is what lets both call it unconditionally.
        let slot = SceneCoreFixtures.slot()
        let scene = try SceneCoreFixtures.scene(slots: [slot])
            .attaching(SceneCoreFixtures.attachment(
                windowRef: try SceneCoreFixtures.windowRef(),
                slotId: slot.id,
            ))

        let unchanged = try scene.detaching(try SceneCoreFixtures.windowRef("com.apple.Safari"))

        XCTAssertEqual(unchanged, scene)
    }

    func testASlotThatHasEmptiedStillExists() throws {
        // Invariant I13. The engine prunes a workspace when its last window leaves; a Scene must not, because
        // an empty `terminal` Slot is a statement about the task rather than an absence to tidy away.
        let slot = SceneCoreFixtures.slot(role: .terminal)
        let window = try SceneCoreFixtures.windowRef()
        let scene = try SceneCoreFixtures.scene(slots: [slot])
            .attaching(SceneCoreFixtures.attachment(windowRef: window, slotId: slot.id))

        let emptied = try scene.detaching(window)

        XCTAssertEqual(emptied.slots.map(\.id), [slot.id])
        XCTAssertEqual(emptied.attachments(in: slot.id), [])
    }
}
