@testable import AppBundle
import Foundation
import XCTest

final class SceneShellMessageTest: XCTestCase {
    private typealias App = SceneCoreFixtures.App

    /// Entering a Scene confirms which task owns the screen and how big it is, and says it once. Singulars are
    /// spelled correctly because this line is read every time someone switches tasks.
    func testEnteringASceneSaysWhichSceneAndHowBigItIs() {
        XCTAssertEqual(
            SceneCore.SceneShellMessage.entered(sceneTitle: "Debug PROD-123", slots: 4, windows: 6).text,
            "Debug PROD-123 · 4 slots, 6 windows",
        )
        XCTAssertEqual(
            SceneCore.SceneShellMessage.entered(sceneTitle: "Release notes", slots: 1, windows: 1).text,
            "Release notes · 1 slot, 1 window",
        )
    }

    /// A refusal comes first and carries its details behind a disclosure, and every Scene that lost windows is
    /// named separately — a merged count would leave the user opening each Scene to find out which one changed.
    func testStartupReportsTheRefusalFirstAndThenNamesEachSceneThatLostWindows() throws {
        let refusal = SceneCore.SceneStateRefusal(
            reason: .unreadable,
            path: "/tmp/scene-state.json",
            preservedAt: "/tmp/scene-state.unreadable.json",
        )
        let dropped = try [("Debug PROD-123", App.line), ("Debug PROD-123", App.slack), ("Notes", App.music)]
            .map { title, bundleId in
                SceneCore.SceneStateQuarantine(
                    sceneId: .generate(),
                    sceneTitle: title,
                    windowRef: try SceneCoreFixtures.windowRef(bundleId),
                    reason: .alreadyAttached,
                )
            }

        let messages = SceneCore.SceneShellMessage.onStartup(refusal: refusal, quarantined: dropped)

        XCTAssertEqual(messages.map(\.text), [
            "Scene state couldn’t be read — no windows were changed",
            "2 windows from “Debug PROD-123” are no longer open",
            "1 window from “Notes” is no longer open",
        ])
        XCTAssertEqual(messages.first?.details, refusal.diagnostic)
        XCTAssertEqual(messages.map(\.showsDetails), [true, false, false])
        XCTAssertEqual(messages.map(\.announces), [true, true, true])
    }
}
