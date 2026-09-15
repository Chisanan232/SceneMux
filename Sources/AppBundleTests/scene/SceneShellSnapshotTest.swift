@testable import AppBundle
import Foundation
import XCTest

final class SceneShellSnapshotTest: XCTestCase {
    private func snapshot(
        _ scenes: [SceneCore.Scene],
        diagnostics: [String] = [],
    ) throws -> SceneCore.SceneShellSnapshot {
        SceneCore.SceneShellSnapshot(
            world: try SceneCore.SceneWorld(scenes: scenes),
            diagnostics: diagnostics,
            homes: .shippedOnly,
            naming: { _ in nil },
        )
    }

    /// A number in this list is a key the user can press, so it may only ever address a Scene that can be
    /// entered. A closed Scene stays in state as a record and stays out of the rows, which is what stops
    /// `⌃⌥2` from meaning "enter the task I finished yesterday".
    func testAClosedSceneIsNeitherListedNorNumbered() throws {
        let snapshot = try snapshot([
            try SceneCoreFixtures.scene(title: "Finished", state: .ended),
            try SceneCoreFixtures.scene(title: "Debug PROD-123"),
            try SceneCoreFixtures.scene(title: "Release notes"),
        ])

        XCTAssertEqual(snapshot.scenes.map(\.title), ["Debug PROD-123", "Release notes"])
        XCTAssertEqual(snapshot.scenes.map(\.index), [1, 2])
        XCTAssertEqual(snapshot.scene(at: 1)?.title, "Debug PROD-123")
        XCTAssertNil(snapshot.scene(at: 3))
    }

    /// The menu bar item is the only always-visible piece of Scene state, so it has to be right in both
    /// directions: the active title when there is one, and an explicit *No Scene* when there is not. A long
    /// title loses its middle, because `Debug PROD-123` and `Debug PROD-987` differ only at the end.
    func testTheMenuBarSaysTheActiveSceneOrExplicitlySaysThereIsNone() throws {
        let substrate = SceneCore.SubstrateBinding(workspaceName: "3")

        XCTAssertEqual(try snapshot([try SceneCoreFixtures.scene()]).menuBarTitle, "No Scene")
        XCTAssertEqual(try snapshot([]).menuBarTitle, "No Scene")
        XCTAssertEqual(
            try snapshot([try SceneCoreFixtures.scene(state: .active(substrate))]).menuBarTitle,
            "Debug PROD-123",
        )
        XCTAssertEqual(
            try snapshot([try SceneCoreFixtures.scene(
                title: "Debug the release candidate PROD-123",
                state: .active(substrate),
            )]).menuBarTitle,
            "Debug the rele…date PROD-123",
        )
    }

    /// An empty list has two very different causes, and saying the wrong one is the failure this asserts
    /// against: inviting someone to create their first Scene when the real reason their Scenes are missing is
    /// that the state file could not be read would send them to make a new one on top of state SceneMux has
    /// deliberately refused to touch.
    func testAnEmptyListInvitesOnFirstRunButExplainsItselfAfterARefusal() throws {
        let refusal = SceneCore.SceneStateRefusal(
            reason: .unreadable,
            path: "/tmp/scene-state.json",
            preservedAt: nil,
        )

        XCTAssertNotNil(try snapshot([]).firstRunMessage)
        XCTAssertNil(try snapshot([try SceneCoreFixtures.scene()]).firstRunMessage)

        let refused = try snapshot([], diagnostics: [refusal.diagnostic])
        XCTAssertTrue(refused.isEmpty)
        XCTAssertNil(refused.firstRunMessage)
        XCTAssertEqual(refused.diagnostics, [refusal.diagnostic])
    }
}
