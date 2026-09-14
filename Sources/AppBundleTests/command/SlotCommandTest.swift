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
}
