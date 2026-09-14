@testable import AppBundle
import Foundation
import XCTest

final class SceneShellCloseSummaryTest: XCTestCase {
    private typealias App = SceneCoreFixtures.App

    private let naming: SceneCore.ApplicationNaming = { bundleId in
        [SceneCoreFixtures.App.line: "LINE", SceneCoreFixtures.App.slack: "Slack"][bundleId]
    }

    /// The golden journey's Scene, asked what closing it will do. Grouped by ownership, because ownership is
    /// what decides the outcome — the panel shows the model's reasoning rather than a generic warning.
    func testTheConfirmationIsGroupedByOwnershipAndSaysTheOutcomePerGroup() throws {
        let summary = SceneCore.SceneShellCloseSummary(
            scene: try SceneCoreFixtures.debugScene(),
            naming: naming,
        )

        XCTAssertEqual(summary.title, "Close “Debug PROD-123”?")
        XCTAssertEqual(summary.groups.map(\.ownership), [.borrowed, .sceneOwned])
        XCTAssertEqual(summary.groups.map(\.headline), [
            "2 borrowed windows go back to their Home",
            "4 scene windows stay where they are",
        ])
        XCTAssertEqual(summary.groups.first?.windows.map(\.applicationName), ["LINE", "Slack"])
        XCTAssertTrue(summary.movesAnyWindow)
    }

    /// Cleanup is offered for the windows the Scene brought into existence and nowhere else: a borrowed window
    /// is going home and a shared one is not SceneMux's to touch, so offering to close either would be offering
    /// to break an invariant. And it is never the default — the caveat is on the checkbox because it is the
    /// reason the checkbox is safe.
    func testCleanupIsOfferedOnlyForSceneOwnedWindowsAndAlwaysAsksPerWindow() throws {
        let slot = SceneCoreFixtures.slot()
        let scene = try SceneCoreFixtures.scene(slots: [slot])
            .attaching(SceneCoreFixtures.attachment(
                windowRef: try SceneCoreFixtures.windowRef(App.line),
                slotId: slot.id,
                ownership: .borrowed,
                homeAtAttachTime: .communication,
            ))
            .attaching(SceneCoreFixtures.attachment(
                windowRef: try SceneCoreFixtures.windowRef(App.music),
                slotId: slot.id,
                ownership: .sharedPersistent,
                homeAtAttachTime: .personal,
            ))

        let summary = SceneCore.SceneShellCloseSummary(scene: scene, naming: naming)

        XCTAssertEqual(summary.groups.map(\.ownership), [.borrowed, .sharedPersistent])
        XCTAssertEqual(summary.groups.map(\.offersCleanup), [false, false])
        XCTAssertEqual(summary.groups.map(\.headline), [
            "1 borrowed window goes back to its Home",
            "1 shared window is not touched",
        ])
        XCTAssertEqual(SceneCore.SceneShellCloseSummary.cleanupCaveat, "asks for each")
    }
}
