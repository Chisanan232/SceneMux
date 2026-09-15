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

    func testRenamingAnActiveSceneChangesItsTitleAndNothingElse() throws {
        // A task that turns out to be something else is renamed while it is on screen, so the rename cannot be
        // gated on state — and must not disturb the projection it is part of.
        let orchestrator = SceneCore.SceneOrchestrator(store: store(in: try temporaryDirectory()))
        let scene = try orchestrator.createScene(title: "Debug PROD-123",
                                                 slots: SceneCore.SlotTemplate.development.slots())
        try orchestrator.enter(scene.id, on: substrate)

        try orchestrator.rename(scene.id, to: "Debug PROD-456")

        let renamed = try XCTUnwrap(orchestrator.world.scene(scene.id))
        XCTAssertEqual(renamed.title, "Debug PROD-456")
        XCTAssertEqual(renamed.state, .active(substrate))
        XCTAssertEqual(renamed.slots, scene.slots)
    }

    func testAnAddedSlotGoesAfterTheOnesTheSceneAlreadyHas() throws {
        // A new Slot is a new place, so it takes the next order rather than renumbering the Scene's existing
        // Slots — which are the layout the user is looking at.
        let orchestrator = SceneCore.SceneOrchestrator(store: store(in: try temporaryDirectory()))
        let scene = try orchestrator.createScene(title: "Debug PROD-123",
                                                 slots: SceneCore.SlotTemplate.development.slots())

        let added = try orchestrator.addSlot(role: .communication, label: "chat", to: scene.id)

        XCTAssertEqual(added.order, 4)
        XCTAssertEqual(added.composition, .single)
        XCTAssertEqual(added.displayName, "chat")
        let grown = try XCTUnwrap(orchestrator.world.scene(scene.id))
        XCTAssertEqual(grown.slots.map(\.role), [.terminal, .editor, .preview, .observability, .communication])
        XCTAssertEqual(grown.attachments, [])
    }

    func testASlotHoldingWindowsIsNotRemovedWhileAnEmptyOneIs() throws {
        // Removing a Slot must never be a way to lose an attachment: the attachment is what says SceneMux owes
        // that window a restore.
        let store = store(in: try temporaryDirectory())
        let occupied = SceneCoreFixtures.slot(role: .communication, order: 0)
        let spare = SceneCoreFixtures.slot(role: .preview, order: 1)
        let scene = try SceneCoreFixtures.scene(slots: [occupied, spare])
            .attaching(SceneCoreFixtures.attachment(
                windowRef: try SceneCoreFixtures.windowRef(App.line),
                slotId: occupied.id,
            ))
        try store.save([scene])
        let orchestrator = SceneCore.SceneOrchestrator(store: store)

        XCTAssertThrowsError(try orchestrator.removeSlot(occupied.id, from: scene.id)) { error in
            XCTAssertEqual(error as? SceneCore.SceneCoreError, .slotNotEmpty(occupied.id))
        }
        try orchestrator.removeSlot(spare.id, from: scene.id)
        XCTAssertEqual(orchestrator.world.scene(scene.id)?.slots.map(\.id), [occupied.id])
    }

    func testCyclingASlotsCompositionIsSavedAndKeepsItsWindows() throws {
        // Recomposing is the ordinary edit on a Slot that already has windows in it, and it has to survive a
        // relaunch — otherwise the shape on screen and the shape in state disagree after the next launch.
        let store = store(in: try temporaryDirectory())
        let comms = SceneCoreFixtures.slot(role: .communication, order: 0)
        let scene = try SceneCoreFixtures.scene(slots: [comms])
            .attaching(SceneCoreFixtures.attachment(
                windowRef: try SceneCoreFixtures.windowRef(App.line),
                slotId: comms.id,
            ))
        try store.save([scene])
        let orchestrator = SceneCore.SceneOrchestrator(store: store)

        let recomposed = try orchestrator.cycleComposition(of: comms.id, in: scene.id)

        XCTAssertEqual(recomposed.composition, .split(.vertical))
        XCTAssertEqual(SceneCore.SceneOrchestrator(store: store).world.scene(scene.id)?.slots, [recomposed])
        XCTAssertEqual(orchestrator.world.scene(scene.id)?.attachments, scene.attachments)
    }

    func testCyclingASlotTheSceneDoesNotHaveIsRefused() throws {
        let orchestrator = SceneCore.SceneOrchestrator(store: store(in: try temporaryDirectory()))
        let scene = try orchestrator.createScene(title: "Debug PROD-123")
        let elsewhere = SceneCore.SlotId.generate()

        XCTAssertThrowsError(try orchestrator.cycleComposition(of: elsewhere, in: scene.id)) { error in
            XCTAssertEqual(error as? SceneCore.SceneCoreError, .unknownSlot(elsewhere))
        }
    }

    func testRenamingASceneTheWorldDoesNotHaveIsRefused() throws {
        // The shell addresses Scenes by index, and an index can name a Scene a restart has already forgotten.
        let orchestrator = SceneCore.SceneOrchestrator(store: store(in: try temporaryDirectory()))
        let elsewhere = SceneCore.SceneId.generate()

        XCTAssertThrowsError(try orchestrator.rename(elsewhere, to: "Debug PROD-123")) { error in
            XCTAssertEqual(error as? SceneCore.SceneLifecycleError, .unknownScene(elsewhere))
        }
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

    func testANoOpDoesNotNeedToWriteAnything() throws {
        let directory = try temporaryDirectory()
        let orchestrator = SceneCore.SceneOrchestrator(store: store(in: directory))
        let scene = try orchestrator.createScene(title: "Debug PROD-123")
        try orchestrator.enter(scene.id, on: substrate)
        try makeUnwritable(directory)

        // The same shortcut pressed twice must not fail because the disk is full. A no-op that can throw is
        // not a no-op.
        XCTAssertNoThrow(try orchestrator.enter(scene.id, on: substrate))
        XCTAssertEqual(orchestrator.world.activeScene?.state, .active(substrate))
        // And the directory really is unwritable, so the assertion above is not green for the wrong reason.
        XCTAssertThrowsError(try orchestrator.leave(scene.id))
    }

    func testAWindowLeftBehindIsReportedToTheUser() throws {
        let store = store(in: try temporaryDirectory())
        let scene = try SceneCoreFixtures.debugScene(state: .active(substrate))
        try store.save([scene])
        let orchestrator = SceneCore.SceneOrchestrator(store: store)

        _ = try orchestrator.close(scene.id)
        try orchestrator.resolve(
            .leftInPlace(reason: "its Home has no workspace any more"),
            for: try SceneCoreFixtures.windowRef(App.line),
            in: scene.id,
        )

        let diagnostic = try XCTUnwrap(orchestrator.diagnostics.first)
        XCTAssertTrue(diagnostic.contains("com.linecorp.LINE#0"))
        XCTAssertTrue(diagnostic.contains("Debug PROD-123"))
        XCTAssertTrue(diagnostic.contains("its Home has no workspace any more"))
        // Reported once, and only for the window it happened to.
        XCTAssertEqual(orchestrator.diagnostics.count, 1)
    }

    func testTheGoldenJourneyEndsWithTheBorrowedWindowsSentHome() throws {
        let store = store(in: try temporaryDirectory())
        let scene = try SceneCoreFixtures.debugScene(state: .active(substrate))
        try store.save([scene])
        let orchestrator = SceneCore.SceneOrchestrator(store: store)

        let plan = try orchestrator.close(scene.id)
        for step in plan.pending {
            try orchestrator.resolve(.restored, for: step.windowRef, in: scene.id)
        }

        // LINE and Slack went home; the terminal, the IDE, the browser and the dashboard were left exactly
        // where they were for the user to close; nothing was reported, because nothing went wrong.
        XCTAssertEqual(plan.pending.count, 2)
        XCTAssertEqual(orchestrator.world.scene(scene.id)?.state, .ended)
        XCTAssertEqual(orchestrator.world.scene(scene.id)?.attachments, [])
        XCTAssertEqual(orchestrator.unfinishedTeardowns, [])
        XCTAssertEqual(orchestrator.diagnostics, [])
        // And the next launch agrees, without having to be told any of it again.
        XCTAssertEqual(SceneCore.SceneOrchestrator(store: store).world, orchestrator.world)
    }
    /// A refusal has to survive as a *value*, because the surfaces above have to behave differently for the
    /// two reasons a Scene list can be empty — and recovering "was this a refusal?" by reading English back
    /// out of a diagnostic string is not a thing a UI should have to do.
    func testARefusalIsAvailableAsAValueAndNotOnlyAsASentence() throws {
        let store = store(in: try temporaryDirectory())
        try Data(#"{ "version": 9000, "scenes": [] }"#.utf8).write(to: store.url)

        let orchestrator = SceneCore.SceneOrchestrator(store: store)

        let refusal = try XCTUnwrap(orchestrator.stateRefusal)
        XCTAssertEqual(
            refusal.reason,
            .unsupportedVersion(found: 9000, readable: SceneCore.SceneStateSchema.readable),
        )
        XCTAssertEqual(refusal.path, store.url.path)
        XCTAssertEqual(orchestrator.quarantined, [])
    }
    /// A Scene that came back smaller than it left is explainable only if the set-aside attachments are kept
    /// where a surface can name the Scene and count the windows. The Scene itself still loads: an attachment is
    /// permission to move a window, so dropping one makes SceneMux do less, never more.
    func testSetAsideAttachmentsAreKeptWhereASurfaceCanNameTheScene() throws {
        let store = store(in: try temporaryDirectory())
        let slot = SceneCoreFixtures.slot()
        let windowRef = try SceneCoreFixtures.windowRef(App.line)
        try store.save([try SceneCoreFixtures.scene(
            slots: [slot],
            attachments: [SceneCoreFixtures.attachment(windowRef: windowRef, slotId: slot.id)],
        )])
        var json = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: try Data(contentsOf: store.url)) as? [String: Any],
        )
        var scenes = try XCTUnwrap(json["scenes"] as? [[String: Any]])
        var attachments = try XCTUnwrap(scenes[0]["attachments"] as? [[String: Any]])
        attachments[0]["slotId"] = "a-slot-a-later-build-removed"
        scenes[0]["attachments"] = attachments
        json["scenes"] = scenes
        try JSONSerialization.data(withJSONObject: json).write(to: store.url)

        let orchestrator = SceneCore.SceneOrchestrator(store: store)

        XCTAssertNil(orchestrator.stateRefusal)
        XCTAssertEqual(orchestrator.world.scenes.map(\.title), ["Debug PROD-123"])
        XCTAssertEqual(orchestrator.quarantined.map(\.sceneTitle), ["Debug PROD-123"])
        XCTAssertEqual(orchestrator.quarantined.map(\.windowRef), [windowRef])
    }
    func testAMountedWindowSurvivesARelaunchWithItsTermsIntact() throws {
        // The whole point of recording an attachment rather than remembering it: the promise to send a borrowed
        // chat window home has to outlive the process that made it.
        let store = store(in: try temporaryDirectory())
        let orchestrator = SceneCore.SceneOrchestrator(store: store)
        let scene = try orchestrator.createScene(title: "Debug PROD-123")
        let slot = try orchestrator.addSlot(role: .communication, to: scene.id)
        let windowRef = try SceneCoreFixtures.windowRef(App.line)

        let attachment = try orchestrator.attach(
            windowRef,
            to: slot.id,
            of: scene.id,
            ownership: .borrowed,
            home: .communication,
            originSurface: SceneCoreFixtures.communicationSurface,
        )

        XCTAssertTrue(attachment.isMount)
        let relaunched = SceneCore.SceneOrchestrator(store: store)
        let holder = try XCTUnwrap(relaunched.world.holder(of: windowRef))
        XCTAssertEqual(holder.scene.id, scene.id)
        XCTAssertEqual(holder.attachment, attachment)
    }
    func testAFailedSaveLeavesTheWindowInNoSceneAtAll() throws {
        // A full disk during a mount. The attachment is what permits SceneMux to move the window later, so one
        // that exists only in memory is the dangerous case: the window would be in a Scene this run believes in
        // and the next run has never heard of, with nothing recording where it came from.
        let directory = try temporaryDirectory()
        let store = store(in: directory)
        let orchestrator = SceneCore.SceneOrchestrator(store: store)
        let scene = try orchestrator.createScene(title: "Debug PROD-123")
        let slot = try orchestrator.addSlot(role: .communication, to: scene.id)
        let windowRef = try SceneCoreFixtures.windowRef(App.line)
        try makeUnwritable(directory)

        XCTAssertThrowsError(try orchestrator.attach(
            windowRef,
            to: slot.id,
            of: scene.id,
            ownership: .borrowed,
            home: .communication,
            originSurface: SceneCoreFixtures.communicationSurface,
        ))

        XCTAssertNil(orchestrator.world.holder(of: windowRef))
    }
}
