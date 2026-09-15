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

    /// A user's own `on-window-detected` callback that says it has dealt with the window is obeyed, and no rule
    /// gets a look at it afterwards.
    ///
    /// This is the precedence claim made everywhere else in Scene Core, at the one place where a rule and an
    /// explicit instruction actually meet: `check-further-callbacks = false` is the user saying "this window is
    /// handled", and admission is placed after the callbacks so that it is. Driven through
    /// `tryOnWindowDetected` — the engine's own entry point — because the ordering is the thing being tested,
    /// and calling the hook directly would test nothing about it.
    func testACallbackThatClaimsTheWindowStopsAdmissionFromSeeingIt() async throws {
        let (workspace, _) = try sceneOnScreen(with: .terminal)
        var callback = WindowDetectedCallback()
        callback.matcher.appId = App.terminal
        callback.checkFurtherCallbacks = false
        callback.rawRun = []
        config.onWindowDetected = [callback]
        let window = TestWindow.new(
            id: 1,
            parent: workspace.rootTilingContainer,
            app: TestApp(bundleId: App.terminal),
        )

        try await tryOnWindowDetected(window)

        XCTAssertEqual(SceneCore.SceneRuntime.shared.snapshot.activeScene?.slots.first?.windows, [])
        XCTAssertEqual(store.load().scenes.first?.attachments, [])
    }

    /// The lifecycle half of the same story: a window a rule brought in is the Scene's own, so ending the Scene
    /// leaves it exactly where it is.
    ///
    /// Asserted through `close` rather than by reading the ownership back off the attachment, because the thing
    /// worth proving is that admission hands the lifecycle an *ordinary* attachment — its teardown step is
    /// derived the usual way, from the ownership, by code that does not know a rule was involved. Nothing
    /// downstream of admission has a special case for it, and this is what says so.
    func testAWindowARuleBroughtInStaysWhereItIsWhenTheSceneEnds() throws {
        let (workspace, _) = try sceneOnScreen(with: .terminal)
        let window = TestWindow.new(
            id: 1,
            parent: workspace.rootTilingContainer,
            app: TestApp(bundleId: App.terminal),
        )
        let runtime = SceneCore.SceneRuntime.shared
        sceneAdmitDetectedWindow(window)
        let sceneId = try XCTUnwrap(runtime.snapshot.activeScene?.id)

        let plan = try runtime.close(sceneId)

        let step = try XCTUnwrap(plan.steps.first)
        XCTAssertEqual(step.windowRef, try SceneCoreFixtures.windowRef(App.terminal))
        // The Home the rules gave it at the time, recorded on the attachment by admission — which is how the
        // user is told which Home a window belonged to, and the reason `admit` passes one at all.
        XCTAssertEqual(step.recordedHome, .development)
        XCTAssertEqual(step.effect, .leaveInPlace)
        XCTAssertEqual(window.nodeWorkspace, workspace)
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

    /// Nothing happens when there is no Scene, which is the state SceneMux is in nearly all of the time. The
    /// inherited engine's own new-window behaviour is what remains, untouched — the window is still exactly
    /// where it bound it, and no Scene exists to have taken it.
    func testWithNoSceneOnScreenTheHookChangesNothing() throws {
        let workspace = Workspace.get(byName: "on-screen")
        XCTAssertTrue(workspace.focusWorkspace())
        let window = TestWindow.new(
            id: 1,
            parent: workspace.rootTilingContainer,
            app: TestApp(bundleId: App.terminal),
        )

        sceneAdmitDetectedWindow(window)

        XCTAssertEqual(workspace.rootTilingContainer.layoutDescription, .h_tiles([.window(1)]))
        XCTAssertNil(SceneCore.SceneRuntime.shared.snapshot.activeScene)
        XCTAssertEqual(store.load().scenes.flatMap(\.attachments), [])
    }
}
