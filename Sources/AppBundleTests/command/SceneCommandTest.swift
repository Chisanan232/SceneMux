@testable import AppBundle
import Common
import XCTest

/// The `scene` command against a runtime pointed at a temporary state file: the same object the panels use, so
/// what these tests prove about the command is also true of the keystroke bound to it.
@MainActor
final class SceneCommandTest: XCTestCase {
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

    /// The grammar the default bindings send, and the combinations that are refused rather than guessed at.
    /// `ctrl-alt-1` sends a bare number, which is why a number is a target and not a flag.
    func testParseCommand() {
        XCTAssertTrue(parseCommand("scene 3").cmdOrNil is SceneCommand)
        XCTAssertTrue(parseCommand("scene next").cmdOrNil is SceneCommand)
        XCTAssertTrue(parseCommand("scene list --json").cmdOrNil is SceneCommand)
        XCTAssertTrue(parseCommand("scene new --title 'Debug PROD-123' --template empty").cmdOrNil is SceneCommand)
        XCTAssertTrue(parseCommand("scene close --scene 2 --yes").cmdOrNil is SceneCommand)

        XCTAssertEqual(parseCommand("scene rename").errorOrNil, "--title is mandatory for 'rename'")
        XCTAssertEqual(parseCommand("scene leave --title x").errorOrNil, "--title is only allowed for 'new' and 'rename'")
        XCTAssertEqual(parseCommand("scene 1 --json").errorOrNil, "--json is only allowed for 'list'")
        XCTAssertEqual(parseCommand("scene leave --yes").errorOrNil, "--yes is only allowed for 'close'")
        XCTAssertEqual(parseCommand("scene 1 --scene 2").errorOrNil, "--scene is only allowed for 'rename' and 'close'")
        XCTAssertEqual(
            parseCommand("scene 0").errorOrNil,
            "ERROR: Can't parse scene target '0'. Expected (<scene-number>|next|prev|list|new|rename|leave|close|switcher)",
        )
    }
}
