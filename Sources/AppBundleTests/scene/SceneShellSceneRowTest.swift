@testable import AppBundle
import Foundation
import XCTest

final class SceneShellSceneRowTest: XCTestCase {
    private func row(_ scene: SceneCore.Scene, index: Int = 1) -> SceneCore.SceneShellSceneRow {
        SceneCore.SceneShellSceneRow(scene: scene, index: index, naming: { _ in nil })
    }

    /// The distinction the sidebar exists to make: a Scene that was left still holds its work, and must not be
    /// mistaken for one that holds nothing. Badge, fill, emphasis and trailing text all differ, so the
    /// difference survives greyscale, reduced transparency and a screenshot.
    func testAParkedSceneWithWindowsNeverLooksLikeAnEmptyOne() throws {
        let parked = row(try SceneCoreFixtures.debugScene())
        let empty = row(try SceneCoreFixtures.scene(slots: [SceneCoreFixtures.slot()]))

        XCTAssertEqual(parked.badge, .halfFilled)
        XCTAssertEqual(parked.fill, .resting)
        XCTAssertEqual(parked.titleEmphasis, .primary)
        XCTAssertEqual(parked.trailing, "6 windows")

        XCTAssertEqual(empty.badge, .outline)
        XCTAssertEqual(empty.fill, .faint)
        XCTAssertEqual(empty.titleEmphasis, .secondary)
        XCTAssertEqual(empty.trailing, "empty")
    }
}
