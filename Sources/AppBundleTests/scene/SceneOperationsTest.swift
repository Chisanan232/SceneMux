@testable import AppBundle
import Foundation
import XCTest

final class SceneOperationsTest: XCTestCase {
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
