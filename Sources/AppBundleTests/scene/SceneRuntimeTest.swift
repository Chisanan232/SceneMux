@testable import AppBundle
import Combine
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

    /// A desktop with nowhere to draw refuses the whole operation rather than aiming a Scene at a guess. The
    /// Scene stays exactly as it was, which is what makes the refusal safe to retry.
    func testASceneIsNotEnteredWhenThereIsNowhereToDrawIt() throws {
        let runtime = try runtime()
        let scene = try runtime.createScene(title: "Debug PROD-123")
        port.substrate = nil

        XCTAssertThrowsError(try runtime.enter(scene.id)) { error in
            XCTAssertEqual(error as? SceneCore.SceneRuntimeError, .noSubstrate)
        }
        XCTAssertNil(runtime.snapshot.activeScene)
        XCTAssertEqual(port.preparedSubstrates, [])
        XCTAssertNil(runtime.message)
    }

    /// Nine number keys and one Scene: most of those keys name nothing, and each refusal says which number was
    /// meant. A Slot number is only ever read against the Scene on screen, so asking for one with no Scene up is
    /// a different refusal from asking for one that does not exist.
    func testANumberThatNamesNothingIsRefusedByThatNumber() throws {
        let runtime = try runtime()
        let scene = try runtime.createScene(title: "Debug PROD-123")

        XCTAssertEqual(try runtime.scene(numbered: 1).id, scene.id)
        XCTAssertThrowsError(try runtime.scene(numbered: 4)) { error in
            XCTAssertEqual(error as? SceneCore.SceneRuntimeError, .noSceneNumbered(4))
        }
        XCTAssertThrowsError(try runtime.slot(numbered: 1)) { error in
            XCTAssertEqual(error as? SceneCore.SceneRuntimeError, .noActiveScene)
        }

        try runtime.enter(scene.id)
        XCTAssertEqual(try runtime.slot(numbered: 2).role, .editor)
        XCTAssertThrowsError(try runtime.slot(numbered: 9)) { error in
            XCTAssertEqual(error as? SceneCore.SceneRuntimeError, .noSlotNumbered(9))
        }
    }

    /// Composing a Slot goes round a fixed cycle and the row says the new shape. The Slot is empty here, so the
    /// screen has nothing to redraw — which is the point: the shape is a property of the Scene's plan, kept
    /// whether or not a window has arrived to be shaped by it yet.
    func testComposingASlotCyclesItsShapeAndTheRowSaysSo() throws {
        let runtime = try runtime()
        let scene = try runtime.createScene(title: "Debug PROD-123", template: .empty)
        try runtime.enter(scene.id)
        let slot = try runtime.addSlot(role: .editor)

        XCTAssertEqual(try runtime.slot(numbered: 1).compositionChip, nil)
        XCTAssertEqual(try runtime.cycleComposition(of: slot.id).composition, .split(.vertical))
        XCTAssertEqual(try runtime.slot(numbered: 1).compositionChip, "split ⬍")
        XCTAssertEqual(try runtime.cycleComposition(of: slot.id).composition, .split(.horizontal))
        XCTAssertEqual(try runtime.cycleComposition(of: slot.id).composition, .tabbed)
        XCTAssertEqual(try runtime.cycleComposition(of: slot.id).composition, .single)
        XCTAssertEqual(try runtime.slot(numbered: 1).trailing, "empty")
    }

    /// Mounting borrows the window the user is looking at, and records the two things that will be gone a moment
    /// later: what the application is for, and which surface it was on. Without the second one there is no way
    /// home.
    func testMountingBorrowsTheFocusedWindowAndRecordsWhereItCameFrom() throws {
        let runtime = try runtime()
        let windowRef = try SceneCoreFixtures.windowRef(SceneCoreFixtures.App.line)
        port.focused = windowRef
        port.surfaces[windowRef] = SceneCoreFixtures.communicationSurface
        let scene = try runtime.createScene(title: "Debug PROD-123")
        try runtime.enter(scene.id)
        let slot = try runtime.slot(numbered: 1)

        let row = try runtime.mount(into: slot.id)

        XCTAssertEqual(row.windowRef, windowRef)
        XCTAssertEqual(row.home, .communication)
        XCTAssertTrue(row.isMounted)
        XCTAssertEqual(runtime.snapshot.activeScene?.windowCount, 1)
        XCTAssertEqual(
            runtime.snapshot.activeScene?.slots.first?.windows.map(\.windowRef),
            [windowRef],
        )
    }

    /// No focused window means no guess. The alternative — mounting whichever window the engine mentions first —
    /// would put a stranger's window into somebody's task, and they would find out by closing the Scene.
    func testMountingWithNothingFocusedIsRefusedAndTheSceneIsUnchanged() throws {
        let runtime = try runtime()
        let scene = try runtime.createScene(title: "Debug PROD-123")
        try runtime.enter(scene.id)
        let slot = try runtime.slot(numbered: 1)

        XCTAssertThrowsError(try runtime.mount(into: slot.id)) { error in
            XCTAssertEqual(error as? SceneCore.SceneRuntimeError, .noFocusedWindow)
        }
        XCTAssertEqual(runtime.snapshot.activeScene?.windowCount, 0)
        XCTAssertEqual(port.requestedMoves.count, 0)
    }

    /// Unmounting is the reverse of mounting, in the other order: the window goes back first, and only then is it
    /// taken out of the Scene. What the user sees is a chat window on the workspace it came from and a Scene that
    /// no longer mentions it.
    func testUnmountingSendsTheWindowBackAndTakesItOutOfTheScene() throws {
        let runtime = try runtime()
        let windowRef = try SceneCoreFixtures.windowRef(SceneCoreFixtures.App.line)
        port.focused = windowRef
        port.surfaces[windowRef] = SceneCoreFixtures.communicationSurface
        let scene = try runtime.createScene(title: "Debug PROD-123")
        try runtime.enter(scene.id)
        try runtime.mount(into: try runtime.slot(numbered: 1).id)

        let outcome = try runtime.unmount(windowRef)

        XCTAssertEqual(outcome, .restored)
        XCTAssertEqual(port.requestedMoves.map(\.binding), [SceneCoreFixtures.communicationSurface])
        XCTAssertEqual(runtime.snapshot.activeScene?.windowCount, 0)
    }

    /// Closing a Scene, both halves at once: the borrowed window goes back to the workspace it was borrowed
    /// from, the scene-owned one is left exactly where it is rather than closed, and the user is told both —
    /// which is the whole reversibility promise, and the reason a Scene is safe to end.
    func testClosingASceneSendsTheBorrowedWindowsHomeAndSaysWhatStayed() throws {
        let runtime = try runtime()
        var said: [SceneCore.SceneShellMessage] = []
        let subscription = runtime.$message.sink { if let message = $0 { said.append(message) } }
        defer { subscription.cancel() }
        let scene = try runtime.createScene(title: "Debug PROD-123", template: .empty)
        try runtime.enter(scene.id)
        let terminal = try runtime.addSlot(role: .terminal)
        let comms = try runtime.addSlot(role: .communication)
        for (bundleId, slotId, ownership) in [
            (SceneCoreFixtures.App.terminal, terminal.id, SceneCore.Ownership.sceneOwned),
            (SceneCoreFixtures.App.line, comms.id, .borrowed),
        ] {
            let windowRef = try SceneCoreFixtures.windowRef(bundleId)
            port.focused = windowRef
            port.surfaces[windowRef] = SceneCoreFixtures.communicationSurface
            try runtime.mount(into: slotId, ownership: ownership)
        }
        said.removeAll()

        let plan = try runtime.close(scene.id)

        XCTAssertEqual(plan.pending.map(\.windowRef.bundleId), [SceneCoreFixtures.App.line])
        XCTAssertEqual(said.map(\.text), [
            "1 window went back to Communication — \(SceneCoreFixtures.App.line)",
            "1 window left in place",
        ])
        XCTAssertEqual(runtime.snapshot.scenes, [])
        XCTAssertEqual(runtime.unfinishedTeardowns, [])
    }

    /// Asking for a window back that no Scene is holding is a mistake worth naming, not a silent no-op: the
    /// caller is a person who believes SceneMux borrowed something, and "there was nothing to give back" is the
    /// only answer that tells them it did not.
    func testUnmountingAWindowNoSceneIsHoldingIsRefusedByThatName() throws {
        let runtime = try runtime()
        let scene = try runtime.createScene(title: "Debug PROD-123", template: .empty)
        try runtime.enter(scene.id)
        let windowRef = try SceneCoreFixtures.windowRef(SceneCoreFixtures.App.music)

        XCTAssertThrowsError(try runtime.unmount(windowRef)) { error in
            XCTAssertEqual(error as? SceneCore.SceneRuntimeError, .windowNotInAScene)
        }
        XCTAssertEqual(port.requestedMoves.count, 0)
    }
}
