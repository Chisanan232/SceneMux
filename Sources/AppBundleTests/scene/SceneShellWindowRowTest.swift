@testable import AppBundle
import Foundation
import XCTest

/// The one assertion the Phase 1 UI exists to support: a borrowed window's row says what the window is *for*,
/// not which Scene it is currently sitting in.
final class SceneShellWindowRowTest: XCTestCase {
    private typealias App = SceneCoreFixtures.App

    private let naming: SceneCore.ApplicationNaming = { bundleId in
        [App.line: "LINE", App.ide: "IDE"][bundleId]
    }

    func testABorrowedWindowKeepsItsHomeAndIsMarkedMountedThreeWays() throws {
        let row = SceneCore.SceneShellWindowRow(
            attachment: SceneCoreFixtures.attachment(
                windowRef: try SceneCoreFixtures.windowRef(App.line),
                slotId: .generate(),
                ownership: .borrowed,
                homeAtAttachTime: .communication,
            ),
            homes: .shippedOnly,
            naming: naming,
        )

        XCTAssertEqual(row.applicationName, "LINE")
        XCTAssertEqual(row.trailing, "Communication · mounted")
        XCTAssertEqual(row.borrowGlyph, "◐")
        XCTAssertTrue(row.hasDashedLeadingEdge)
        XCTAssertEqual(
            row.reversibility,
            "Borrowed into this Scene. Goes back to Communication when the Scene closes.",
        )
        XCTAssertEqual(row.accessibilityLabel, "LINE, Communication, mounted")
    }

    func testASceneOwnedWindowHasNoBorrowSignalsAtAll() throws {
        let row = SceneCore.SceneShellWindowRow(
            attachment: SceneCoreFixtures.attachment(
                windowRef: try SceneCoreFixtures.windowRef(App.ide),
                slotId: .generate(),
                ownership: .sceneOwned,
                homeAtAttachTime: .development,
            ),
            homes: .shippedOnly,
            naming: naming,
        )

        XCTAssertEqual(row.trailing, "Development")
        XCTAssertNil(row.borrowGlyph)
        XCTAssertFalse(row.hasDashedLeadingEdge)
        XCTAssertNil(row.reversibility)
        XCTAssertEqual(row.accessibilityLabel, "IDE, Development")
    }

    /// A window whose application the desktop cannot name still gets a row. The bundle id is the honest
    /// fallback — and it is the only other thing a Scene knows about the window, since it holds no title.
    func testAnUnnameableApplicationFallsBackToItsBundleId() throws {
        let row = SceneCore.SceneShellWindowRow(
            attachment: SceneCoreFixtures.attachment(
                windowRef: try SceneCoreFixtures.windowRef(App.grafana),
                slotId: .generate(),
            ),
            homes: .shippedOnly,
            naming: naming,
        )

        XCTAssertEqual(row.applicationName, App.grafana)
    }

    /// The row shows the Home the window has *now*. The recorded one is kept only to explain the difference,
    /// which is exactly what the architecture says `homeAtAttachTime` is for: evidence, not a destination.
    func testARowFollowsTheUsersCurrentHomeRulesAndNotTheRecordedOne() throws {
        let row = SceneCore.SceneShellWindowRow(
            attachment: SceneCoreFixtures.attachment(
                windowRef: try SceneCoreFixtures.windowRef(App.slack),
                slotId: .generate(),
                ownership: .borrowed,
                homeAtAttachTime: .communication,
            ),
            homes: SceneCore.HomeRules(overrides: [App.slack: .development]),
            naming: naming,
        )

        XCTAssertEqual(row.home, .development)
        XCTAssertEqual(row.recordedHome, .communication)
        XCTAssertEqual(row.trailing, "Development · mounted")
        XCTAssertTrue(row.homeChangedWhileBorrowed)
    }

    /// And says so where the user is looking, without promising the window will follow the new Home: a restore
    /// replays the surface it was borrowed from, so the destination is the one thing the re-home did not change.
    func testTheReversibilityLineNamesTheHomeChangeAndBothHomes() throws {
        let row = SceneCore.SceneShellWindowRow(
            attachment: SceneCoreFixtures.attachment(
                windowRef: try SceneCoreFixtures.windowRef(App.slack),
                slotId: .generate(),
                ownership: .borrowed,
                homeAtAttachTime: .communication,
            ),
            homes: SceneCore.HomeRules(overrides: [App.slack: .development]),
            naming: naming,
        )

        XCTAssertEqual(
            row.reversibility,
            "Borrowed into this Scene. Its Home changed to Development while it was borrowed; "
                + "it still goes back where it came from, in Communication.",
        )
    }

    /// The same row, with nothing re-homed, must not acquire the note. A "Home changed" line on every borrowed
    /// window would make the one that matters unreadable.
    func testAnUnchangedHomeSaysNothingAboutHavingChanged() throws {
        let row = SceneCore.SceneShellWindowRow(
            attachment: SceneCoreFixtures.attachment(
                windowRef: try SceneCoreFixtures.windowRef(App.slack),
                slotId: .generate(),
                ownership: .borrowed,
                homeAtAttachTime: .communication,
            ),
            homes: .shippedOnly,
            naming: naming,
        )

        XCTAssertFalse(row.homeChangedWhileBorrowed)
        XCTAssertEqual(
            row.reversibility,
            "Borrowed into this Scene. Goes back to Communication when the Scene closes.",
        )
    }
}
