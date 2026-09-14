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
    private typealias App = SceneCoreFixtures.App

    private func teardownEffect(
        of bundleId: String,
        in scene: SceneCore.Scene,
    ) throws -> SceneCore.SceneTeardownEffect {
        let window = try SceneCoreFixtures.windowRef(bundleId)
        return try XCTUnwrap(scene.attachment(for: window)).ownership.teardownEffect
    }

    func testTheMusicPlayerIsNotInTheSceneAtAll() throws {
        // Invariant I7 at its source. A `.sharedPersistent` window has no attachment, so there is nothing
        // for teardown to resolve and no record that could give SceneMux permission to move it — which is
        // also why the sidebar lists it in its own Shared section rather than under a Scene.
        let scene = try SceneCoreFixtures.debugScene()

        let music = try SceneCoreFixtures.windowRef(App.music)

        XCTAssertNil(scene.attachment(for: music))
        XCTAssertEqual(scene.attachments.count, 6)
    }

    func testWhetherAWindowIsAMountDoesNotFollowFromComparingItsHome() throws {
        // Both directions of the correction recorded in the architecture doc, in one test. LINE's Home
        // *matches* its Slot's role and it is still a Mount; the browser's Home *differs* from its Slot's
        // role and it is still not one. A comparison would get both of these backwards, and getting the
        // browser wrong means promising to move a window the user asked SceneMux to leave in place.
        let scene = try SceneCoreFixtures.debugScene()

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
        let scene = try SceneCoreFixtures.debugScene()

        XCTAssertEqual(try teardownEffect(of: App.line, in: scene), .restoreToHome)
        XCTAssertEqual(try teardownEffect(of: App.slack, in: scene), .restoreToHome)
        XCTAssertEqual(try teardownEffect(of: App.terminal, in: scene), .leaveInPlace)
        XCTAssertEqual(try teardownEffect(of: App.ide, in: scene), .leaveInPlace)
        XCTAssertEqual(try teardownEffect(of: App.browser, in: scene), .leaveInPlace)
        XCTAssertEqual(try teardownEffect(of: App.grafana, in: scene), .leaveInPlace)
    }
}
