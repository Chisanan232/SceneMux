@testable import AppBundle
import Common
import XCTest

/// The seam, end to end: a window the *engine* has detected, described by the adapter, decided on by the rules
/// and attached by the runtime.
///
/// `AdmissionRulesTest` proves the decisions and needs no desktop for it. This proves the wiring, which is the
/// other half and the half that a pure test cannot reach: whether the window the engine bound is the window the
/// rules are told about, and whether saying yes actually puts it in the Slot. A real engine tree and a real
/// adapter, with only the state file and the application naming replaced.
@MainActor
final class SceneAdmissionHookTest: XCTestCase {
    private typealias App = SceneCoreFixtures.App
    private typealias Rule = SceneCore.AdmissionRules.Rule

    private var store: SceneCore.SceneStateStore!

    /// A runtime on a temporary state file, because `SceneRuntime.shared` otherwise opens the state of whoever
    /// is running the tests — and this is the one suite that reaches the hook the running app calls.
    override func setUp() async throws {
        setUpWorkspacesForTests()
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "SceneMuxTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        store = SceneCore.SceneStateStore(url: directory.appending(path: "scene-state.json"))
        SceneCore.SceneRuntime.shared = SceneCore.SceneRuntime(
            store: SceneCore.SceneStateStore(url: directory.appending(path: "scene-state.json")),
            engine: SceneCore.WinMuxSceneEngineAdapter(),
            naming: { _ in nil },
        )
    }

    /// A Scene on screen with one empty Slot of the given role, on the focused workspace — which is where the
    /// runtime puts a Scene, and so the workspace a window has to appear on to be admitted.
    private func sceneOnScreen(
        with role: SceneCore.SlotRole,
    ) throws -> (workspace: Workspace, slotId: SceneCore.SlotId) {
        let workspace = Workspace.get(byName: "on-screen")
        XCTAssertTrue(workspace.focusWorkspace())
        let runtime = SceneCore.SceneRuntime.shared
        let scene = try runtime.createScene(title: "Debug PROD-123", template: .empty)
        try runtime.enter(scene.id)
        return (workspace, try runtime.addSlot(role: role).id)
    }
}
