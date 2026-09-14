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
}
