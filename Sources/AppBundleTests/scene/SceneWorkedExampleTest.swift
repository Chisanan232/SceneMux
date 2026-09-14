@testable import AppBundle
import Foundation
import XCTest

/// The golden journey of `docs/design/scene-core-ux.md`, expressed in the domain model.
///
/// "Debug PROD-123": five Slots and six windows — the terminal and the IDE are part of the task, the
/// dashboard and the preview browser were opened for it, LINE and Slack were lent to it for the duration,
/// and the music player is not in the Scene at all. These tests exist because the journey is the product's
/// promise, and a model that cannot say it is the wrong model however well its parts test individually.
final class SceneWorkedExampleTest: XCTestCase {
    private enum App {
        static let terminal = "com.apple.Terminal"
        static let ide = "com.jetbrains.intellij"
        static let browser = "com.google.Chrome"
        static let grafana = "com.grafana.grafana"
        static let line = "com.linecorp.LINE"
        static let slack = "com.tinyspeck.slackmacgap"
        static let music = "com.apple.Music"
    }

    private func debugScene() throws -> SceneCore.Scene {
        let terminal = SceneCoreFixtures.slot(role: .terminal, order: 0)
        let editor = SceneCoreFixtures.slot(role: .editor, order: 1)
        let preview = SceneCoreFixtures.slot(role: .preview, order: 2)
        let observability = SceneCoreFixtures.slot(role: .observability, order: 3)
        let comms = SceneCoreFixtures.slot(role: .communication, composition: .tabbed, order: 4)

        return try SceneCoreFixtures.scene(slots: [terminal, editor, preview, observability, comms])
            .attaching(SceneCoreFixtures.attachment(
                windowRef: try SceneCoreFixtures.windowRef(App.terminal),
                slotId: terminal.id,
                ownership: .sceneOwned,
            ))
            .attaching(SceneCoreFixtures.attachment(
                windowRef: try SceneCoreFixtures.windowRef(App.ide),
                slotId: editor.id,
                ownership: .sceneOwned,
            ))
            .attaching(SceneCoreFixtures.attachment(
                windowRef: try SceneCoreFixtures.windowRef(App.browser),
                slotId: preview.id,
                ownership: .sceneOwned,
                homeAtAttachTime: .personal,
            ))
            .attaching(SceneCoreFixtures.attachment(
                windowRef: try SceneCoreFixtures.windowRef(App.grafana),
                slotId: observability.id,
                ownership: .sceneOwned,
                homeAtAttachTime: .observability,
            ))
            .attaching(SceneCoreFixtures.attachment(
                windowRef: try SceneCoreFixtures.windowRef(App.line),
                slotId: comms.id,
                ownership: .borrowed,
                homeAtAttachTime: .communication,
            ))
            .attaching(SceneCoreFixtures.attachment(
                windowRef: try SceneCoreFixtures.windowRef(App.slack),
                slotId: comms.id,
                ownership: .borrowed,
                homeAtAttachTime: .communication,
            ))
    }

    private func teardownEffect(
        of bundleId: String,
        in scene: SceneCore.Scene,
    ) throws -> SceneCore.SceneTeardownEffect {
        let window = try SceneCoreFixtures.windowRef(bundleId)
        return try XCTUnwrap(scene.attachment(for: window)).ownership.teardownEffect
    }

    func testWhetherAWindowIsAMountDoesNotFollowFromComparingItsHome() throws {
        // Both directions of the correction recorded in the architecture doc, in one test. LINE's Home
        // *matches* its Slot's role and it is still a Mount; the browser's Home *differs* from its Slot's
        // role and it is still not one. A comparison would get both of these backwards, and getting the
        // browser wrong means promising to move a window the user asked SceneMux to leave in place.
        let scene = try debugScene()

        let line = try XCTUnwrap(scene.attachment(for: try SceneCoreFixtures.windowRef(App.line)))
        let browser = try XCTUnwrap(scene.attachment(for: try SceneCoreFixtures.windowRef(App.browser)))

        XCTAssertEqual(line.homeAtAttachTime, .communication)
        XCTAssertTrue(line.isMount)
        XCTAssertEqual(browser.homeAtAttachTime, .personal)
        XCTAssertFalse(browser.isMount)
    }

    func testEndingTheDebugSceneTreatsEachWindowTheWayTheUserLentIt() throws {
        // Ownership alone decides this, which is why LINE goes home while Grafana — a window the user also
        // did not open for this task — stays where the Scene put it.
        let scene = try debugScene()

        XCTAssertEqual(try teardownEffect(of: App.line, in: scene), .restoreToHome)
        XCTAssertEqual(try teardownEffect(of: App.slack, in: scene), .restoreToHome)
        XCTAssertEqual(try teardownEffect(of: App.terminal, in: scene), .leaveInPlace)
        XCTAssertEqual(try teardownEffect(of: App.ide, in: scene), .leaveInPlace)
        XCTAssertEqual(try teardownEffect(of: App.browser, in: scene), .leaveInPlace)
        XCTAssertEqual(try teardownEffect(of: App.grafana, in: scene), .leaveInPlace)
    }
}
