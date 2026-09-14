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
}
