@testable import AppBundle
import Foundation
import XCTest

final class SceneOperationsTest: XCTestCase {
    func testAddedSlotsKeepTheirOrderAndCannotReuseAnIdentity() throws {
        // Adding a Slot goes through the same validation as constructing the Scene, so the duplicate-identity
        // rule cannot be avoided by building a valid Scene first and then growing it.
        let editor = SceneCoreFixtures.slot(role: .editor, order: 0)
        let terminal = SceneCoreFixtures.slot(role: .terminal, order: 1)

        let scene = try SceneCoreFixtures.scene(slots: [editor]).addingSlot(terminal)

        XCTAssertEqual(scene.slots.map(\.id), [editor.id, terminal.id])
        XCTAssertThrowsError(try scene.addingSlot(SceneCoreFixtures.slot(id: editor.id))) { error in
            XCTAssertEqual(error as? SceneCore.SceneCoreError, .duplicateSlotId(editor.id))
        }
    }

    func testReplacingASlotKeepsItsWindowsAndRefusesAnUnknownSlot() throws {
        // Recomposing a Slot that holds windows is the ordinary case, so replacement must not behave like the
        // remove-then-add it would otherwise be — that one refuses a Slot with windows in it.
        let comms = SceneCoreFixtures.slot(role: .communication, order: 0)
        let scene = try SceneCoreFixtures.scene(slots: [comms])
            .attaching(SceneCoreFixtures.attachment(
                windowRef: try SceneCoreFixtures.windowRef(SceneCoreFixtures.App.line),
                slotId: comms.id,
            ))

        let recomposed = try scene.replacingSlot(comms.composed(as: .tabbed))

        XCTAssertEqual(recomposed.slots.map(\.composition), [.tabbed])
        XCTAssertEqual(recomposed.attachments, scene.attachments)
        let elsewhere = SceneCoreFixtures.slot(role: .editor)
        XCTAssertThrowsError(try scene.replacingSlot(elsewhere)) { error in
            XCTAssertEqual(error as? SceneCore.SceneCoreError, .unknownSlot(elsewhere.id))
        }
    }

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

    func testTwoWindowsSharingASlotAreListedInTheOrderTheyArrived() throws {
        // A `tabbed` Slot's tab order and a `split`'s pane order are this list's order, so it is part of what
        // the Scene means rather than an incidental detail of how the attachments are stored.
        let slot = SceneCoreFixtures.slot(role: .terminal, composition: .tabbed)
        let first = try SceneCoreFixtures.windowRef("com.apple.Terminal", ordinal: 0)
        let second = try SceneCoreFixtures.windowRef("com.apple.Terminal", ordinal: 1)

        let scene = try SceneCoreFixtures.scene(slots: [slot])
            .attaching(SceneCoreFixtures.attachment(windowRef: first, slotId: slot.id))
            .attaching(SceneCoreFixtures.attachment(windowRef: second, slotId: slot.id))

        XCTAssertEqual(scene.attachments(in: slot.id).map(\.windowRef), [first, second])
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
