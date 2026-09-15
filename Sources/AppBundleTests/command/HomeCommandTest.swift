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

    /// `show` answers for one application and names who decided, because "SceneMux thinks so" and "you said so"
    /// are different sentences and only one of them is worth arguing with. An application nobody has classified
    /// still gets an answer — every window has a Home — and the source says as much.
    func testShowNamesTheHomeAndWhoDecidedIt() async throws {
        let overridden = try await exec("home show --app \(SceneCoreFixtures.App.browser)")
        XCTAssertEqual(overridden.stdout, [
            "\(SceneCoreFixtures.App.browser) is Development, according to your config.",
        ])

        let shipped = try await exec("home show --app \(SceneCoreFixtures.App.line)")
        XCTAssertEqual(shipped.stdout, [
            "\(SceneCoreFixtures.App.line) is Communication, according to SceneMux’s defaults.",
        ])

        let stranger = try await exec("home show --app com.example.Unheard")
        XCTAssertEqual(stranger.stdout, [
            "com.example.Unheard is Personal, "
                + "according to the default for applications SceneMux does not know.",
        ])
    }

    /// `list` shows the rule that will actually apply, not the two halves it came from, and marks the ones the
    /// user wrote. Ordered by bundle id, so two runs — and two screenshots — say the same thing.
    func testListShowsTheEffectiveRuleAndMarksTheUsersOwn() async throws {
        let listed = try await exec("home list")

        // Lowercased, because that is how the rules are keyed: a bundle id typed with capitals in a config file
        // has to match one shipped without them.
        let browser = listed.stdout.filter { $0.hasPrefix(SceneCoreFixtures.App.browser.lowercased()) }
        XCTAssertEqual(browser.count, 1)
        XCTAssertTrue(browser[0].contains("Development"), browser[0])
        XCTAssertTrue(browser[0].trimmingCharacters(in: .whitespaces).hasSuffix("your config"), browser[0])
        XCTAssertEqual(listed.stdout, listed.stdout.sorted())
        XCTAssertFalse(listed.stdout.contains { $0.hasPrefix("com.example") })
    }

    @discardableResult
    private func exec(_ command: String) async throws -> CmdResult {
        try await parseCommand(command).cmdOrDie.run(.defaultEnv, .emptyStdin)
    }
}
