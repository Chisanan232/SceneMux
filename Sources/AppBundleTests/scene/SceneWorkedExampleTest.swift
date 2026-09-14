@testable import AppBundle
import Foundation
import XCTest

/// The golden journey of `docs/design/scene-core-ux.md`, expressed in the domain model.
///
/// "Debug PROD-123": the agent's terminal and the IDE belong to the task, the dashboard and the preview
/// browser were opened for it, LINE was lent to it for the duration, and the music player was never part of
/// it at all. These tests exist because the journey is the product's promise, and a model that cannot say it
/// is the wrong model however well its parts test individually.
final class SceneWorkedExampleTest: XCTestCase {
    private enum App {
        static let agent = "com.anthropic.claude-code"
        static let ide = "com.jetbrains.intellij"
        static let browser = "com.google.Chrome"
        static let line = "com.linecorp.LINE"
        static let music = "com.spotify.client"
    }

    private func debugScene() throws -> SceneCore.Scene {
        let terminal = SceneCoreFixtures.slot(role: .terminal, label: "agent", order: 0)
        let editor = SceneCoreFixtures.slot(role: .editor, order: 1)
        let observability = SceneCoreFixtures.slot(role: .observability, order: 2)
        let preview = SceneCoreFixtures.slot(role: .preview, order: 3)
        let comms = SceneCoreFixtures.slot(role: .communication, order: 4)

        return try SceneCoreFixtures.scene(slots: [terminal, editor, observability, preview, comms])
            .attaching(SceneCoreFixtures.attachment(
                windowRef: try SceneCoreFixtures.windowRef(App.agent),
                slotId: terminal.id,
                ownership: .sceneOwned,
            ))
            .attaching(SceneCoreFixtures.attachment(
                windowRef: try SceneCoreFixtures.windowRef(App.ide),
                slotId: editor.id,
                ownership: .sceneOwned,
            ))
            .attaching(SceneCoreFixtures.attachment(
                windowRef: try SceneCoreFixtures.windowRef(App.browser, ordinal: 0),
                slotId: observability.id,
                ownership: .sceneOwned,
                homeAtAttachTime: .observability,
            ))
            .attaching(SceneCoreFixtures.attachment(
                windowRef: try SceneCoreFixtures.windowRef(App.browser, ordinal: 1),
                slotId: preview.id,
                ownership: .sceneOwned,
            ))
            .attaching(SceneCoreFixtures.attachment(
                windowRef: try SceneCoreFixtures.windowRef(App.line),
                slotId: comms.id,
                ownership: .borrowed,
                homeAtAttachTime: .communication,
            ))
            .attaching(SceneCoreFixtures.attachment(
                windowRef: try SceneCoreFixtures.windowRef(App.music),
                slotId: comms.id,
                ownership: .sharedPersistent,
                homeAtAttachTime: .personal,
            ))
    }

    func testBorrowingLineIsAMountEvenThoughItLandsInACommunicationSlot() throws {
        // The recorded ownership is the test for a Mount, not a comparison of the Slot's role against the
        // window's Home. LINE's Home stays `communication` while it is lent out — a Scene borrows a window,
        // it does not move house for it — so a role comparison would call this a plain attachment and quietly
        // drop the promise to send it back.
        let scene = try debugScene()
        let line = try SceneCoreFixtures.windowRef(App.line)
        let music = try SceneCoreFixtures.windowRef(App.music)

        let borrowed = try XCTUnwrap(scene.attachment(for: line))

        XCTAssertEqual(borrowed.homeAtAttachTime, .communication)
        XCTAssertTrue(borrowed.isMount)
        XCTAssertFalse(try XCTUnwrap(scene.attachment(for: music)).isMount)
    }

    func testEndingTheDebugSceneTreatsEachWindowTheWayTheUserLentIt() throws {
        // Ownership alone decides this, which is why LINE goes home while the dashboard — a window the user
        // also did not open for this task — stays where the Scene put it.
        let scene = try debugScene()

        func effect(_ bundleId: String) throws -> SceneCore.SceneTeardownEffect {
            let window = try SceneCoreFixtures.windowRef(bundleId)
            return try XCTUnwrap(scene.attachment(for: window)).ownership.teardownEffect
        }

        XCTAssertEqual(try effect(App.line), .restoreToHome)
        XCTAssertEqual(try effect(App.agent), .leaveInPlace)
        XCTAssertEqual(try effect(App.browser), .leaveInPlace)
        XCTAssertEqual(try effect(App.music), .untouched)
    }
}
