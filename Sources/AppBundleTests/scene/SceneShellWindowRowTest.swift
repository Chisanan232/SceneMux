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
}
