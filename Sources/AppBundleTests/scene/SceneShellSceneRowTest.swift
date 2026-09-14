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

    /// Exactly one Scene is on screen, so exactly one row gets the accent bar. A Scene mid-teardown says
    /// `restoring…` rather than freezing silently, because restoring borrowed windows takes real time against
    /// other applications and a row that looked unchanged would read as a hang.
    func testOnlyTheActiveSceneIsAccentedAndAnEndingSceneSaysItIsRestoring() throws {
        let active = row(try SceneCoreFixtures.debugScene(
            state: .active(SceneCore.SubstrateBinding(workspaceName: "3")),
        ))
        let ending = row(try SceneCoreFixtures.debugScene(state: .ending))

        XCTAssertTrue(active.isActive)
        XCTAssertTrue(active.showsAccentBar)
        XCTAssertEqual(active.badge, .filled)
        XCTAssertEqual(active.trailing, "active")

        XCTAssertFalse(ending.showsAccentBar)
        XCTAssertEqual(ending.badge, .restoring)
        XCTAssertEqual(ending.trailing, "restoring…")
    }

    /// Entering a Scene you just created shows an empty one, which is correct and must not read as a failure.
    /// The invitation belongs to that case alone: a Scene nobody is looking at has nothing to invite.
    func testAnEmptyActiveSceneInvitesInsteadOfLookingBroken() throws {
        let entered = row(try SceneCoreFixtures.scene(
            slots: [SceneCoreFixtures.slot()],
            state: .active(SceneCore.SubstrateBinding(workspaceName: "3")),
        ))

        XCTAssertNotNil(entered.invitation)
        XCTAssertNil(row(try SceneCoreFixtures.scene(slots: [SceneCoreFixtures.slot()])).invitation)
        XCTAssertNil(row(try SceneCoreFixtures.debugScene(
            state: .active(SceneCore.SubstrateBinding(workspaceName: "3")),
        )).invitation)
    }

    /// A Scene row carries its Slots in the order the Scene defines, numbered from one — the numbers `⌃⌥3` and
    /// `scene 3` are addressed to — and describes itself to a screen reader without ever naming a window.
    func testTheRowNumbersItsSlotsInOrderAndDescribesItselfWithoutWindowTitles() throws {
        let scene = row(try SceneCoreFixtures.debugScene(), index: 3)

        XCTAssertEqual(scene.index, 3)
        XCTAssertEqual(scene.slots.map(\.index), [1, 2, 3, 4, 5])
        XCTAssertEqual(scene.slots.map(\.role),
                       [.terminal, .editor, .preview, .observability, .communication])
        XCTAssertEqual(scene.accessibilityLabel, "Debug PROD-123, scene, inactive, 6 windows")
    }
}
