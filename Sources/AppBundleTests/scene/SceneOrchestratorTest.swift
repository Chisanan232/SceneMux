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
}
