@testable import AppBundle
import Foundation
import XCTest

final class SceneShellCloseSummaryTest: XCTestCase {
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
}
