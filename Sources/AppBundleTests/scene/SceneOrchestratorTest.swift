@testable import AppBundle
import Foundation
import XCTest

/// The orchestrator against a real file, because half of what it promises is about the file.
///
/// Every test gets its own directory: one that read the real state file would be flaky on the machine of
/// whoever is actually using SceneMux, and one that wrote it would take their Scenes away.
@MainActor
final class SceneOrchestratorTest: XCTestCase {
    private typealias App = SceneCoreFixtures.App

    private let substrate = SceneCore.SubstrateBinding(workspaceName: "3")

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "SceneMuxTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return directory
    }

    private func store(in directory: URL) -> SceneCore.SceneStateStore {
        SceneCore.SceneStateStore(url: directory.appending(path: SceneCore.SceneStateStore.filename))
    }

    func testAFirstRunHasNoScenesAndNothingToSay() throws {
        let orchestrator = SceneCore.SceneOrchestrator(store: store(in: try temporaryDirectory()))

        XCTAssertEqual(orchestrator.world, .empty)
        XCTAssertEqual(orchestrator.diagnostics, [])
        XCTAssertEqual(orchestrator.unfinishedTeardowns, [])
    }

    func testEveryChangeIsOnDiskBeforeItIsBelieved() throws {
        let store = store(in: try temporaryDirectory())
        let orchestrator = SceneCore.SceneOrchestrator(store: store)

        let scene = try orchestrator.createScene(title: "Debug PROD-123")
        try orchestrator.enter(scene.id, on: substrate)

        // A second orchestrator over the same file is what the next launch is.
        let relaunched = SceneCore.SceneOrchestrator(store: store)
        XCTAssertEqual(relaunched.world, orchestrator.world)
        XCTAssertEqual(relaunched.world.activeScene?.state, .active(substrate))
        XCTAssertEqual(relaunched.diagnostics, [])
    }
}
