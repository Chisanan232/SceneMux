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

    /// Take away permission to write in this directory, and give it back before the directory is removed.
    ///
    /// The honest way to test a failed save: a full disk, a read-only home directory, a sandbox denial. All of
    /// them arrive as a write that throws, and none of them may be allowed to lose a window.
    private func makeUnwritable(_ directory: URL) throws {
        addTeardownBlock {
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: directory.path)
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

    func testStateThisBuildCannotReadYieldsNoScenesAndOneLine() throws {
        let store = store(in: try temporaryDirectory())
        try Data(#"{ "version": 9000, "scenes": [] }"#.utf8).write(to: store.url)

        let orchestrator = SceneCore.SceneOrchestrator(store: store)

        // Invariant I9: no Scenes, no window operations, and the user is told — not a log file.
        XCTAssertEqual(orchestrator.world, .empty)
        XCTAssertEqual(orchestrator.diagnostics.count, 1)
        XCTAssertTrue(try XCTUnwrap(orchestrator.diagnostics.first).contains("version 9000"))
    }

    func testScenesThatCannotAllBeTrueAreRefusedAndTheFileIsKept() throws {
        let store = store(in: try temporaryDirectory())
        try store.save([
            try SceneCoreFixtures.scene(title: "Debug PROD-123", state: .active(substrate)),
            try SceneCoreFixtures.scene(title: "Review the release", state: .active(.init(workspaceName: "7"))),
        ])
        let bytes = try Data(contentsOf: store.url)

        let orchestrator = SceneCore.SceneOrchestrator(store: store)

        // Each Scene decodes perfectly and they cannot both be on screen, so the file is refused as a whole —
        // and copied aside first, because the next save is what would otherwise destroy it.
        XCTAssertEqual(orchestrator.world, .empty)
        let diagnostic = try XCTUnwrap(orchestrator.diagnostics.first)
        XCTAssertTrue(diagnostic.contains("cannot use together"))
        XCTAssertTrue(diagnostic.contains("more than one Scene"))
        let preserved = store.url.deletingLastPathComponent()
            .appending(path: SceneCore.SceneStateStore.preservedFilename)
        XCTAssertEqual(try Data(contentsOf: preserved), bytes)
    }

    func testAChangeThatCannotBeSavedDoesNotHappen() throws {
        let directory = try temporaryDirectory()
        let orchestrator = SceneCore.SceneOrchestrator(store: store(in: directory))
        let scene = try orchestrator.createScene(title: "Debug PROD-123")
        try orchestrator.enter(scene.id, on: substrate)
        let before = orchestrator.world
        try makeUnwritable(directory)

        // No plan is handed out, so nothing above this can start moving windows on the strength of a decision
        // that is not on disk.
        XCTAssertThrowsError(try orchestrator.close(scene.id))
        XCTAssertEqual(orchestrator.world, before)
        XCTAssertEqual(orchestrator.world.activeScene?.id, scene.id)
    }
}
