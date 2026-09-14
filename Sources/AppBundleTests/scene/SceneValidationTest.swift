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
