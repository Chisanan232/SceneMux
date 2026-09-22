@testable import AppBundle
import Common
import XCTest

/// The `slot` command against a runtime pointed at a temporary state file.
@MainActor
final class SlotCommandTest: XCTestCase {
    private var port = RecordingSceneEnginePort()

    override func setUp() async throws {
        setUpWorkspacesForTests()
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "SceneMuxTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        port = RecordingSceneEnginePort()
        SceneCore.SceneRuntime.shared = SceneCore.SceneRuntime(
            store: SceneCore.SceneStateStore(url: directory.appending(path: "scene-state.json")),
            engine: port,
            naming: { _ in nil },
        )
    }

    /// The grammar, and what it refuses. Sending a window to a Slot is deliberately not part of it — that is
    /// `mount --slot <n>`, whose subject is the window — so `slot 2` is not a command at all.
    func testParseCommand() {
        XCTAssertTrue(parseCommand("slot list --json").cmdOrNil is SlotCommand)
        XCTAssertTrue(parseCommand("slot new --role editor --label Review").cmdOrNil is SlotCommand)
        XCTAssertTrue(parseCommand("slot compose --slot 2").cmdOrNil is SlotCommand)
        XCTAssertTrue(parseCommand("slot remove --slot 2").cmdOrNil is SlotCommand)

        XCTAssertEqual(parseCommand("slot new").errorOrNil, "--role is mandatory for 'new'")
        XCTAssertEqual(parseCommand("slot compose").errorOrNil, "--slot is mandatory for 'compose' and 'remove'")
        XCTAssertEqual(parseCommand("slot list --slot 1").errorOrNil, "--slot is only allowed for 'compose' and 'remove'")
        XCTAssertEqual(parseCommand("slot compose --slot 1 --role editor").errorOrNil, "--role and --label are only allowed for 'new'")
        XCTAssertEqual(
            parseCommand("slot 2").errorOrNil,
            """
            ERROR: Can't parse '2'.
                   Possible values: (list|new|compose|remove)
            """,
        )
    }

    /// Slots belong to the Scene on screen, so every subcommand refuses when there is none — including `list`,
    /// which has nothing to list rather than an empty list to show.
    func testEverySlotSubcommandNeedsASceneOnScreen() async throws {
        try await parseCommand("scene new --title 'Debug PROD-123' --template empty").cmdOrDie.run(.defaultEnv, .emptyStdin)

        for command in ["slot list", "slot new --role editor", "slot compose --slot 1", "slot remove --slot 1"] {
            let result = try await parseCommand(command).cmdOrDie.run(.defaultEnv, .emptyStdin)
            XCTAssertEqual(result.exitCode, 1, command)
            XCTAssertEqual(result.stderr, ["No Scene is on screen, so there was nothing to do."], command)
        }
    }

    /// Adding, listing, composing and removing, in the order a user would do them. Composing an empty Slot is
    /// allowed and is not a no-op: it records how the windows that arrive will share the region.
    func testAddingListingComposingAndRemovingASlot() async throws {
        try await parseCommand("scene new --title 'Debug PROD-123' --template empty").cmdOrDie.run(.defaultEnv, .emptyStdin)
        try await parseCommand("scene 1").cmdOrDie.run(.defaultEnv, .emptyStdin)

        let added = try await parseCommand("slot new --role editor --label Review").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(added.stdout, ["Added a Review slot to Debug PROD-123."])

        try await parseCommand("slot new --role terminal").cmdOrDie.run(.defaultEnv, .emptyStdin)
        let listed = try await parseCommand("slot list").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(listed.stdout, ["1   Review     empty", "2   terminal   empty"])

        let composed = try await parseCommand("slot compose --slot 1").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(composed.stdout, ["Review slot is now a vertical split."])

        let removed = try await parseCommand("slot remove --slot 2").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(removed.stdout, ["Removed the terminal slot. No window moved."])
        XCTAssertEqual(SceneCore.SceneRuntime.shared.snapshot.activeScene?.slots.map(\.title), ["Review"])
    }

    /// Composing says what the engine settled on, not only what was asked for. The HORO-1109 golden journey
    /// cycled a Slot from a vertical split to a horizontal one, was told it was "now a horizontal split", and
    /// watched nothing at all change on screen: the substrate's orientation normalization had turned the
    /// second one straight back into the first. `docs/design/scene-core-architecture.md` promises the person
    /// is told when the engine has the last word, and a reply that prints only the intent breaks that promise
    /// in the one case where the intent is wrong.
    func testComposingReportsWhatTheEngineSettledOnAndNotOnlyWhatWasAsked() async throws {
        try await exec("scene new --title 'Debug PROD-123' --template empty")
        try await exec("scene 1")
        try await exec("slot new --role communication")
        for app in [SceneCoreFixtures.App.line, SceneCoreFixtures.App.slack] {
            let window = try SceneCoreFixtures.windowRef(app)
            port.focused = window
            port.surfaces[window] = SceneCoreFixtures.communicationSurface
            try await exec("mount --slot 1")
        }
        let slot = try XCTUnwrap(SceneCore.SceneRuntime.shared.snapshot.activeScene?.slots.first?.id)
        // The substrate this Slot lives on only ever comes out vertical, whatever it is asked for.
        port.settledCompositions = [slot: .split(.vertical)]

        let vertical = try await exec("slot compose --slot 1")
        let horizontal = try await exec("slot compose --slot 1")

        // Asked for what it got: one sentence, and no noise about a normalization that changed nothing.
        XCTAssertEqual(vertical.stdout, ["communication slot is now a vertical split."])
        XCTAssertEqual(horizontal.stdout, [
            "communication slot is now a horizontal split.",
            "SceneMux composed the communication Slot of \"Debug PROD-123\" as a vertical split instead of "
                + "a horizontal split, because the window engine normalized it.",
        ])
    }

    /// A Slot counting a window the engine cannot see says so, instead of letting the number be read as the
    /// number of windows on the screen.
    ///
    /// The attachment staying is the persistence model working: Scene state is intent, and an attachment that
    /// outlives a window is what lets a Scene survive quitting the application — or quitting SceneMux. What
    /// HORO-1109 found is that nothing said so. An application was quit mid-Scene, `slot list` went on
    /// reporting its window, and the sentence that would have explained it is produced by a projection, which
    /// quitting an application does not cause.
    func testListingSaysWhenAnAttachedWindowCannotBeSeen() async throws {
        try await exec("scene new --title 'Debug PROD-123' --template empty")
        try await exec("scene 1")
        try await exec("slot new --role communication")
        for app in [SceneCoreFixtures.App.line, SceneCoreFixtures.App.slack] {
            let window = try SceneCoreFixtures.windowRef(app)
            port.focused = window
            port.surfaces[window] = SceneCoreFixtures.communicationSurface
            try await exec("mount --slot 1")
        }

        // LINE quits. The engine can no longer say where that window is; the Scene still holds the attachment.
        port.surfaces[try SceneCoreFixtures.windowRef(SceneCoreFixtures.App.line)] = nil
        let listed = try await exec("slot list")

        XCTAssertEqual(listed.stdout, [
            "1   communication   2 windows",
            "SceneMux cannot see 1 of the 2 windows in the communication slot (\(SceneCoreFixtures.App.line)) "
                + "— the application may have quit, or macOS may be holding it minimized or hidden. Nothing "
                + "was removed from the Scene, and nothing was moved.",
        ])
    }

    /// A role the domain does not have is refused with the roles it does have. The check is here and not in the
    /// argument parser because the role vocabulary belongs to the Scene domain, which the parser cannot see —
    /// and a user should not have to learn that to get a usable error.
    func testAnUnknownRoleIsRefusedWithTheRealRoles() async throws {
        try await parseCommand("scene new --title 'Debug PROD-123' --template empty").cmdOrDie.run(.defaultEnv, .emptyStdin)
        try await parseCommand("scene 1").cmdOrDie.run(.defaultEnv, .emptyStdin)

        let result = try await parseCommand("slot new --role browser").cmdOrDie.run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(result.exitCode, 1)
        XCTAssertEqual(result.stderr, ["""
            Can't parse role 'browser'.
            Possible values: editor|terminal|preview|observability|communication
            """])
        XCTAssertEqual(SceneCore.SceneRuntime.shared.snapshot.activeScene?.slots, [])
    }

    private func exec(_ command: String) async throws -> CmdResult {
        try await parseCommand(command).cmdOrDie.run(.defaultEnv, .emptyStdin)
    }
}
