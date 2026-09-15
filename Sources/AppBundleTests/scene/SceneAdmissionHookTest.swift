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

    /// The whole feature in one assertion: a terminal window appears while a debugging Scene is open, and it is
    /// in the Scene's terminal Slot afterwards — without anybody dragging it there.
    ///
    /// The attachment is checked in the state file rather than in the snapshot, because the thing worth proving
    /// is the part a person later asks about: which rule moved their window. `AttachmentOrigin.admission` with
    /// the rule's own name in it is the answer, and it has to have survived being written to disk.
    func testATerminalWindowAppearingDuringADebuggingSceneEndsUpInItsTerminalSlot() throws {
        let (workspace, slotId) = try sceneOnScreen(with: .terminal)
        let window = TestWindow.new(
            id: 1,
            parent: workspace.rootTilingContainer,
            app: TestApp(bundleId: App.terminal),
        )

        sceneAdmitDetectedWindow(window)

        let slot = try XCTUnwrap(SceneCore.SceneRuntime.shared.snapshot.activeScene?.slots.first)
        XCTAssertEqual(slot.windows.map(\.windowRef), [try SceneCoreFixtures.windowRef(App.terminal)])
        // Scene-owned, not borrowed: nothing lent this window to the Scene, so there is no earlier place to
        // promise to send it back to.
        XCTAssertEqual(slot.windows.first?.isMounted, false)

        let attachment = try XCTUnwrap(store.load().scenes.first?.attachments.first)
        XCTAssertEqual(attachment.slotId, slotId)
        XCTAssertEqual(attachment.origin, .admission(ruleId: Rule.emptySlotServingHome))
    }

    /// The conservative half, at the level where it actually matters. A dialog is a real window the engine
    /// really detects; what makes it safe is that the engine floated it, the adapter says so, and no rule can
    /// route a window it is told is floating. Nothing about this test knows what a dialog looks like.
    func testAFloatingWindowIsDescribedAsFloatingAndSoIsLeftAlone() throws {
        let (workspace, _) = try sceneOnScreen(with: .terminal)
        // Bound straight onto the workspace rather than into its tiling tree, which is what the engine does
        // with a dialog and with anything the user's own float rules exclude.
        let window = TestWindow.new(id: 1, parent: workspace, app: TestApp(bundleId: App.terminal))

        XCTAssertEqual(SceneCore.WinMuxSceneEngineAdapter.kind(of: window), .floating)
        sceneAdmitDetectedWindow(window)

        XCTAssertEqual(SceneCore.SceneRuntime.shared.snapshot.activeScene?.slots.first?.windows, [])
        XCTAssertEqual(store.load().scenes.first?.attachments, [])
    }
}
