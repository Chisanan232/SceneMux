@testable import AppBundle
import Foundation
import XCTest

final class SceneCorePersistenceTest: XCTestCase {
    func testPersistedSceneStateCanNotContainAnythingFromSomeonesScreen() throws {
        let slot = SceneCoreFixtures.slot()
        let attachment = SceneCoreFixtures.attachment(
            windowRef: try SceneCoreFixtures.windowRef(),
            slotId: slot.id,
        )
        let scene = try SceneCoreFixtures.scene(slots: [slot], attachments: [attachment])

        let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(scene))

        // Invariant I11, checked against the bytes rather than against intentions: no window title, no
        // frame, no monitor id, no CGWindowID anywhere in what SceneMux writes to disk.
        let json = try XCTUnwrap(encoded as? [String: Any])
        let attachments = try XCTUnwrap(json["attachments"] as? [[String: Any]])
        XCTAssertEqual(
            Set(try XCTUnwrap(attachments.first).keys),
            ["windowRef", "slotId", "ownership", "homeAtAttachTime", "origin"],
        )
        let windowRef = try XCTUnwrap(try XCTUnwrap(attachments.first)["windowRef"] as? [String: Any])
        XCTAssertEqual(Set(windowRef.keys), ["bundleId", "ordinalWithinApp"])
    }

    func testASplitSlotRemembersWhichWayItWasSplit() throws {
        let composition = SceneCore.SlotComposition.split(.vertical)

        let encoded = try JSONEncoder().encode(composition)
        let decoded = try JSONDecoder().decode(SceneCore.SlotComposition.self, from: encoded)

        XCTAssertEqual(decoded, composition)
        XCTAssertNotEqual(decoded, .split(.horizontal))
    }

    func testTheSemanticHomeIdsAreTheOnesPersistedStateAndRuleTablesKeyOn() {
        // The rawValue *is* the Semantic Home id, so renaming a case renames every user's persisted state
        // and every entry in their bundle-id rule table. Spelling them out here makes that a deliberate act.
        XCTAssertEqual(
            SceneCore.SemanticHome.allCases.map(\.rawValue),
            ["development", "communication", "observability", "personal"],
        )
    }
}
