@testable import AppBundle
import Foundation
import XCTest

final class SceneStateFormatTest: XCTestCase {
    private let path = "/tmp/scene-state.json"

    func testASceneSurvivesBeingWrittenAndReadBack() throws {
        let slot = SceneCoreFixtures.slot()
        let attachment = SceneCoreFixtures.attachment(
            windowRef: try SceneCoreFixtures.windowRef(),
            slotId: slot.id,
        )
        let scene = try SceneCoreFixtures.scene(slots: [slot], attachments: [attachment])

        let written = try SceneCore.SceneStateFormat.encoded([scene])

        XCTAssertEqual(
            SceneCore.SceneStateFormat.read(written, from: path),
            .loaded(scenes: [scene], quarantined: []),
        )
    }

    func testTheFileIsAVersionAndTheScenesAndNothingElse() throws {
        let written = try SceneCore.SceneStateFormat.encoded([])

        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: written) as? [String: Any])

        // The version has to be a sibling of the payload rather than inside it: a build that cannot read
        // this file still has to be able to read the number that says so.
        XCTAssertEqual(Set(json.keys), ["version", "scenes"])
        XCTAssertEqual(json["version"] as? Int, SceneCore.SceneStateSchema.current)
    }
}
