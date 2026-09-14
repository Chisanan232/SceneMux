@testable import AppBundle
import Foundation
import XCTest

final class SceneShellSlotRowTest: XCTestCase {
    private typealias App = SceneCoreFixtures.App

    private let naming: SceneCore.ApplicationNaming = { _ in nil }

    private func row(
        composition: SceneCore.SlotComposition,
        windows: Int,
        role: SceneCore.SlotRole = .communication,
        label: String? = nil,
    ) throws -> SceneCore.SceneShellSlotRow {
        let slot = SceneCoreFixtures.slot(role: role, label: label, composition: composition)
        return SceneCore.SceneShellSlotRow(
            slot: slot,
            index: 1,
            attachments: try (0 ..< windows).map { ordinal in
                SceneCoreFixtures.attachment(
                    windowRef: try SceneCoreFixtures.windowRef(App.line, ordinal: ordinal),
                    slotId: slot.id,
                )
            },
            naming: naming,
        )
    }

    /// The shape a Slot is in is said in words, so it survives greyscale and a compressed screenshot — and it
    /// is said as *how windows share a region*, never as geometry.
    func testACompositionIsShownAsWordsAndNeverAsGeometry() throws {
        XCTAssertEqual(try row(composition: .tabbed, windows: 2).trailing, "2 windows · tabs")
        XCTAssertEqual(try row(composition: .split(.vertical), windows: 2).trailing, "2 windows · split ⬍")
        XCTAssertEqual(try row(composition: .split(.horizontal), windows: 3).trailing, "3 windows · split ⬌")
        XCTAssertEqual(try row(composition: .single, windows: 1).trailing, "1 window")
        XCTAssertNil(try row(composition: .single, windows: 1).compositionChip)
    }

    /// An empty Slot is still a row, and says so: invariant I13 is what makes a Slot a plan rather than a
    /// leftover, and it is only visible if the row is.
    func testAnEmptySlotIsStillARowAndSaysItIsEmpty() throws {
        let empty = try row(composition: .tabbed, windows: 0, role: .terminal)

        XCTAssertTrue(empty.isEmpty)
        XCTAssertEqual(empty.title, "terminal")
        XCTAssertEqual(empty.trailing, "empty")
        XCTAssertEqual(empty.accessibilityLabel, "terminal slot, empty")
    }
}
