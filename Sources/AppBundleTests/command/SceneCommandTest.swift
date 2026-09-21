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

    /// The scripted path: create, list, enter. The list is the numbering the bindings use, so the number in the
    /// table is the number `scene 1` takes.
    func testCreatingListingAndEnteringFromTheCommandLine() async throws {
        let created = try await parseCommand("scene new --title 'Debug PROD-123'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(created.exitCode, 0)
        XCTAssertEqual(created.stdout, ["Created Debug PROD-123 as Scene 1. Enter it with 'scene 1'."])

        let listed = try await parseCommand("scene list").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(listed.stdout, ["1   Debug PROD-123   defined   4 slots   empty"])

        let entered = try await parseCommand("scene 1").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(entered.stdout, ["Entered Debug PROD-123"])
        XCTAssertEqual(SceneCore.SceneRuntime.shared.snapshot.activeScene?.title, "Debug PROD-123")
    }

    /// Closing never happens on the strength of one word. With a surface listening, the command asks it to
    /// confirm and changes nothing itself; with nobody listening — a script — it prints what closing would do
    /// and refuses until `--yes` says so out loud.
    func testCloseAsksBeforeItMovesAnything() async throws {
        try await parseCommand("scene new --title 'Debug PROD-123'").cmdOrDie.run(.defaultEnv, .emptyStdin)
        try await parseCommand("scene 1").cmdOrDie.run(.defaultEnv, .emptyStdin)

        let scripted = try await parseCommand("scene close").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(scripted.exitCode, 1)
        XCTAssertEqual(scripted.stdout, ["Close “Debug PROD-123”?"])
        XCTAssertEqual(scripted.stderr, ["Pass --yes to close it."])
        XCTAssertEqual(SceneCore.SceneRuntime.shared.snapshot.scenes.map(\.state), [.active])

        var asked: [SceneCore.SceneShellRequest] = []
        SceneCore.SceneRuntime.shared.presenter = { asked.append($0) }
        let interactive = try await parseCommand("scene close").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(interactive.exitCode, 0)
        XCTAssertEqual(asked, [.confirmClose(SceneCore.SceneRuntime.shared.snapshot.scenes[0].id)])
        XCTAssertEqual(SceneCore.SceneRuntime.shared.snapshot.scenes.map(\.state), [.active])
    }

    /// What `--yes` reports afterwards is what happened, not what it set out to do. The HORO-1109 golden journey
    /// closed a Scene whose five borrowed windows all went home and was told that five windows were "still to be
    /// restored", because the count came from the plan rather than from what the plan achieved. A completed close
    /// reading like a failed one is the kind of report that teaches people to ignore reports.
    func testClosingReportsWhatIsStillOwedRatherThanWhatItSetOutToDo() async throws {
        try await exec("scene new --title 'Debug PROD-123' --template empty")
        try await exec("scene 1")
        try await exec("slot new --role communication")
        let line = try SceneCoreFixtures.windowRef(SceneCoreFixtures.App.line)
        port.focused = line
        port.surfaces[line] = SceneCoreFixtures.communicationSurface
        try await exec("mount --slot 1")

        let closed = try await exec("scene close --yes")

        XCTAssertEqual(closed.stdout, [
            "Closing Debug PROD-123.",
            "1 borrowed window goes back to its Home",
        ])
        XCTAssertEqual(SceneCore.SceneRuntime.shared.unfinishedTeardowns, [])
    }

    /// And the other direction, because a report that never says anything is no better: a restore the engine
    /// refused is still owed, so it is counted — once, from the attachment that is still there.
    func testClosingSaysSoWhenARestoreIsStillOwed() async throws {
        try await exec("scene new --title 'Debug PROD-123' --template empty")
        try await exec("scene 1")
        try await exec("slot new --role communication")
        let line = try SceneCoreFixtures.windowRef(SceneCoreFixtures.App.line)
        port.focused = line
        port.surfaces[line] = SceneCoreFixtures.communicationSurface
        try await exec("mount --slot 1")
        port.moveAnswers[line] = .failed(reason: "the application is not answering")

        let closed = try await exec("scene close --yes")

        XCTAssertEqual(closed.stdout, [
            "Closing Debug PROD-123.",
            "1 borrowed window goes back to its Home",
            "\(SceneCoreFixtures.App.line) did not go back — nothing was closed or moved",
            "1 window(s) could not be restored, and SceneMux will try again.",
        ])
        XCTAssertEqual(SceneCore.SceneRuntime.shared.unfinishedTeardowns.flatMap(\.pending).map(\.windowRef), [line])
    }

    /// A borrowed window whose Home surface is gone stays where it is — the Scene finishes anyway, so nothing
    /// will ever mention that window again. It is therefore the one outcome that has to be named in the reply
    /// itself: the headline above it says the window goes back to its Home, and it did not. Before HORO-1109
    /// only the HUD said so, which meant a Scene closed from a shell reported a restore that never happened.
    func testClosingNamesABorrowedWindowThatDidNotGoHome() async throws {
        try await exec("scene new --title 'Debug PROD-123' --template empty")
        try await exec("scene 1")
        try await exec("slot new --role communication")
        let line = try SceneCoreFixtures.windowRef(SceneCoreFixtures.App.line)
        port.focused = line
        port.surfaces[line] = SceneCoreFixtures.communicationSurface
        try await exec("mount --slot 1")
        port.moveAnswers[line] = .surfaceIsGone(reason: "the workspace it came from no longer exists")

        let closed = try await exec("scene close --yes")

        XCTAssertEqual(closed.stdout, [
            "Closing Debug PROD-123.",
            "1 borrowed window goes back to its Home",
            "\(SceneCoreFixtures.App.line) did not go back — nothing was closed or moved",
        ])
        // Final, not owed: the Scene is over and the attachment is gone, so nothing is going to retry it.
        XCTAssertEqual(SceneCore.SceneRuntime.shared.unfinishedTeardowns, [])
        XCTAssertEqual(SceneCore.SceneRuntime.shared.snapshot.scenes, [])
    }

    /// `scene next` walks the list and wraps, and it starts at the first Scene when none is on screen — so the
    /// binding is useful on a fresh desktop instead of refusing until a Scene has been entered by other means.
    func testNextAndPreviousWalkTheListAndWrap() async throws {
        try await parseCommand("scene new --title First --template empty").cmdOrDie.run(.defaultEnv, .emptyStdin)
        try await parseCommand("scene new --title Second --template empty").cmdOrDie.run(.defaultEnv, .emptyStdin)

        var entered: [String] = []
        for step in ["next", "next", "next", "prev"] {
            entered += try await parseCommand("scene \(step)").cmdOrDie.run(.defaultEnv, .emptyStdin).stdout
        }
        XCTAssertEqual(entered, ["Entered First", "Entered Second", "Entered First", "Entered Second"])

        let left = try await parseCommand("scene leave").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(left.stdout, ["Left Second. Nothing moved."])
        XCTAssertEqual(port.invisibleWindows, [])
    }

    /// A command that can only be carried out by a surface says so when there is no surface, rather than
    /// reporting success against a screen where nothing happened. `scene new` with no title is one of those:
    /// the name is typed into the switcher, so without one there is nowhere to type it.
    func testCommandsThatNeedASurfaceSayWhenThereIsNone() async throws {
        let refused = try await parseCommand("scene switcher").cmdOrDie.run(.defaultEnv, .emptyStdin)
        XCTAssertEqual(refused.exitCode, 1)
        XCTAssertEqual(refused.stderr, ["This needs the SceneMux app to be running with its interface available."])

        var asked: [SceneCore.SceneShellRequest] = []
        SceneCore.SceneRuntime.shared.presenter = { asked.append($0) }
        try await parseCommand("scene switcher").cmdOrDie.run(.defaultEnv, .emptyStdin)
        try await parseCommand("scene new").cmdOrDie.run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(asked, [.switcher, .newScene])
        XCTAssertEqual(SceneCore.SceneRuntime.shared.snapshot.scenes, [])
    }

    private func exec(_ command: String) async throws -> CmdResult {
        try await parseCommand(command).cmdOrDie.run(.defaultEnv, .emptyStdin)
    }
}
