@testable import AppBundle
import Foundation
import XCTest

final class SceneValidationTest: XCTestCase {
    func testATitleIsStoredTheWayItWillBeShown() throws {
        let scene = try SceneCoreFixtures.scene(title: "  Debug PROD-123\n")

        XCTAssertEqual(scene.title, "Debug PROD-123")
    }

    func testTwoSlotsCannotShareAnIdentityEvenThoughTheyMayShareARole() {
        let shared = SceneCore.SlotId.generate()
        let first = SceneCoreFixtures.slot(id: shared, role: .terminal, order: 0)
        let second = SceneCoreFixtures.slot(id: shared, role: .terminal, order: 1)

        XCTAssertThrowsError(try SceneCoreFixtures.scene(slots: [first, second])) { error in
            XCTAssertEqual(error as? SceneCore.SceneCoreError, .duplicateSlotId(shared))
        }
    }

    func testOneWindowCannotHaveTwoAnswersAboutWhatMayHappenToIt() throws {
        // Invariant I4. Two attachments would mean two ownerships for one window, and therefore two
        // different answers to "what may ending this Scene do to it?" with nothing to choose between them.
        let window = try SceneCoreFixtures.windowRef()
        let editor = SceneCoreFixtures.slot(role: .editor, order: 0)
        let terminal = SceneCoreFixtures.slot(role: .terminal, order: 1)
        let borrowed = SceneCoreFixtures.attachment(
            windowRef: window,
            slotId: editor.id,
            ownership: .borrowed,
        )
        let owned = SceneCoreFixtures.attachment(
            windowRef: window,
            slotId: terminal.id,
            ownership: .sceneOwned,
        )

        XCTAssertThrowsError(
            try SceneCoreFixtures.scene(slots: [editor, terminal], attachments: [borrowed, owned]),
        ) { error in
            XCTAssertEqual(error as? SceneCore.SceneCoreError, .duplicateAttachment(window))
        }
    }

    func testAnAttachmentToASlotTheSceneDoesNotHaveIsRejected() throws {
        let elsewhere = SceneCore.SlotId.generate()
        let stray = SceneCoreFixtures.attachment(
            windowRef: try SceneCoreFixtures.windowRef(),
            slotId: elsewhere,
        )

        XCTAssertThrowsError(try SceneCoreFixtures.scene(slots: [], attachments: [stray])) { error in
            XCTAssertEqual(error as? SceneCore.SceneCoreError, .unknownSlot(elsewhere))
        }
    }

    func testTwoTerminalsAreAPerfectlyOrdinaryScene() throws {
        let first = SceneCoreFixtures.slot(role: .terminal, order: 0)
        let second = SceneCoreFixtures.slot(role: .terminal, order: 1)

        let scene = try SceneCoreFixtures.scene(slots: [first, second])

        XCTAssertEqual(scene.slots.map(\.role), [.terminal, .terminal])
        XCTAssertNotEqual(first.id, second.id)
    }

    func testASceneNobodyCouldNameIsRejected() {
        XCTAssertThrowsError(try SceneCoreFixtures.scene(title: " \t ")) { error in
            XCTAssertEqual(error as? SceneCore.SceneCoreError, .emptySceneTitle)
        }
    }
}
