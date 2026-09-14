@testable import AppBundle
import Foundation
import XCTest

/// The runtime against a real state file and a recording engine: what the surfaces would see, without a Mac.
@MainActor
final class SceneRuntimeTest: XCTestCase {
    private var port = RecordingSceneEnginePort()

    private func runtime() throws -> SceneCore.SceneRuntime {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "SceneMuxTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        port = RecordingSceneEnginePort()
        return SceneCore.SceneRuntime(
            store: SceneCore.SceneStateStore(url: directory.appending(path: "scene-state.json")),
            engine: port,
            naming: { _ in nil },
        )
    }

    /// Creating a Scene does not enter it, and it does not draw anything. The Scene arrives as a plan — its
    /// Slots exist and are empty — and the screen is untouched until the user asks for it.
    func testCreatingASceneDoesNotEnterItAndDrawsNothing() throws {
        let runtime = try runtime()

        let created = try runtime.createScene(title: "Debug PROD-123")

        XCTAssertEqual(runtime.snapshot.scenes.map(\.title), ["Debug PROD-123"])
        XCTAssertEqual(created.index, 1)
        XCTAssertEqual(created.slots.map(\.role), [.terminal, .editor, .preview, .observability])
        XCTAssertTrue(created.slots.allSatisfy(\.isEmpty))
        XCTAssertNil(runtime.snapshot.activeScene)
        XCTAssertEqual(runtime.snapshot.menuBarTitle, "No Scene")
        XCTAssertEqual(port.preparedSubstrates, [])
        XCTAssertNil(runtime.message)
    }
}
