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

    /// Entering a Scene draws it and says so once. Entering a second one leaves the first — the lifecycle
    /// refuses to swap two Scenes in one step, so the shell makes that decision explicitly, here, where the
    /// keystroke happened.
    func testEnteringASceneDrawsItAndEnteringAnotherLeavesTheFirst() throws {
        let runtime = try runtime()
        let first = try runtime.createScene(title: "Debug PROD-123")
        let second = try runtime.createScene(title: "Release notes", template: .empty)

        try runtime.enter(first.id)
        XCTAssertEqual(runtime.snapshot.activeScene?.id, first.id)
        XCTAssertEqual(runtime.snapshot.menuBarTitle, "Debug PROD-123")
        XCTAssertEqual(runtime.message, .entered(sceneTitle: "Debug PROD-123", slots: 4, windows: 0))
        XCTAssertEqual(port.preparedSubstrates, [SceneCore.SubstrateBinding(workspaceName: "3")])

        try runtime.enter(second.id)
        XCTAssertEqual(runtime.snapshot.activeScene?.id, second.id)
        XCTAssertEqual(runtime.snapshot.scenes.map(\.state), [.defined, .active])
        XCTAssertEqual(runtime.message, .entered(sceneTitle: "Release notes", slots: 0, windows: 0))
    }

    /// Leaving is silent, and closing an empty Scene finishes it. No HUD for a leave is a design rule, not an
    /// omission: a toast on every task switch is how a user learns to ignore the toast that matters.
    func testLeavingSaysNothingAndClosingAnEmptySceneFinishesIt() throws {
        let runtime = try runtime()
        let scene = try runtime.createScene(title: "Debug PROD-123", template: .empty)
        try runtime.enter(scene.id)
        runtime.dismissMessage()

        try runtime.leave()
        XCTAssertNil(runtime.snapshot.activeScene)
        XCTAssertNil(runtime.message)
        XCTAssertEqual(runtime.snapshot.scenes.map(\.state), [.defined])

        let plan = try runtime.close(scene.id)
        XCTAssertEqual(plan.pending, [])
        XCTAssertEqual(runtime.snapshot.scenes, [])
        XCTAssertEqual(runtime.unfinishedTeardowns, [])
        XCTAssertNil(runtime.message)
    }
}
