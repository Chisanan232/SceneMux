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
}
