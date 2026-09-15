@testable import AppBundle
import Common
import XCTest

/// `home` — the read-only view of Home policy.
///
/// What these tests are really guarding is the *absence* of a writer: there is no subcommand that assigns a
/// Home, so the grammar test is as much a specification as the behaviour ones.
@MainActor
final class HomeCommandTest: XCTestCase {
    private var port = RecordingSceneEnginePort()

    override func setUp() async throws {
        setUpWorkspacesForTests()
        port = RecordingSceneEnginePort()
        SceneCore.SceneRuntime.shared = SceneCore.SceneRuntime(
            engine: port,
            homes: SceneCore.HomeRules(overrides: [SceneCoreFixtures.App.browser: .development]),
            naming: { _ in nil },
        )
    }

    /// Two questions and no verbs. `home set` is not a command that is missing — it is a command that must not
    /// exist, because the config file is the one writer of Home policy.
    func testParseCommand() {
        XCTAssertTrue(parseCommand("home list").cmdOrNil is HomeCommand)
        XCTAssertTrue(parseCommand("home list --json").cmdOrNil is HomeCommand)
        XCTAssertTrue(parseCommand("home show").cmdOrNil is HomeCommand)
        XCTAssertTrue(parseCommand("home show --app com.apple.Music").cmdOrNil is HomeCommand)

        XCTAssertEqual(parseCommand("home list --app com.apple.Music").errorOrNil, "--app is only allowed for 'show'")
        XCTAssertEqual(parseCommand("home show --json").errorOrNil, "--json is only allowed for 'list'")
        XCTAssertEqual(
            parseCommand("home set --app com.apple.Music").errorOrNil,
            """
            ERROR: Can't parse 'set'.
                   Possible values: (list|show)
            """,
        )
    }
}
