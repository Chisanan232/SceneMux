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

    /// The grammar, and what it refuses. Sending a window to a Slot is deliberately not part of it yet, so
    /// `slot 2` is not a command rather than a command that quietly does nothing.
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
}
