@testable import AppBundle
import Common
import XCTest

/// `mount` and `unmount` against a runtime pointed at a temporary state file: the two commands are one story,
/// so they are tested as one — a window that can be borrowed and cannot be given back is not reversible.
@MainActor
final class MountCommandTest: XCTestCase {
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

    /// The grammar. `--slot` is mandatory because the alternative is choosing a Slot on the user's behalf, and
    /// `unmount` takes nothing because the window it gives back is the one they are looking at.
    func testParseCommand() {
        XCTAssertTrue(parseCommand("mount --slot 1").cmdOrNil is MountCommand)
        XCTAssertTrue(parseCommand("mount --slot 2 --own").cmdOrNil is MountCommand)
        XCTAssertTrue(parseCommand("unmount").cmdOrNil is UnmountCommand)

        XCTAssertEqual(parseCommand("mount").errorOrNil, "--slot is mandatory")
        XCTAssertEqual(parseCommand("unmount --slot 1").errorOrNil, "ERROR: Unknown flag '--slot'")
    }

    /// The golden journey's one sentence, from the command line: a chat window joins a debugging task and stays
    /// a Communication window. The reply says both halves, because the whole point of Phase 1 is that they are
    /// separate facts and a person has to be able to see that they are.
    func testMountingBorrowsTheFocusedWindowAndSaysItsHomeIsUnchanged() async throws {
        try await exec("scene new --title 'Debug PROD-123' --template empty")
        try await exec("scene 1")
        try await exec("slot new --role communication")
        port.focused = try SceneCoreFixtures.windowRef(SceneCoreFixtures.App.line)
        port.surfaces[port.focused!] = SceneCoreFixtures.communicationSurface

        let result = try await parseCommand("mount --slot 1").cmdOrDie.run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(result.stdout, [
            "Mounted \(SceneCoreFixtures.App.line) into the communication slot. "
                + "Its Home is still Communication, and it goes back when the Scene closes.",
        ])
        let window = SceneCore.SceneRuntime.shared.snapshot.activeScene?.slots.first?.windows.first
        XCTAssertEqual(window?.home, .communication)
        XCTAssertTrue(window?.isMounted == true)
    }

    /// `--own` is a real override, not a suggestion: the reply says which verb happened, and the recorded
    /// ownership is what teardown will obey. The Home is still the application's, which is why the sentence
    /// still names it — owning a window and deciding what it is for are different powers.
    func testOwningIsTheOtherVerbAndSaysSo() async throws {
        try await exec("scene new --title 'Debug PROD-123' --template empty")
        try await exec("scene 1")
        try await exec("slot new --role terminal")
        port.focused = try SceneCoreFixtures.windowRef(SceneCoreFixtures.App.terminal)

        let result = try await parseCommand("mount --slot 1 --own").cmdOrDie.run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(result.stdout, [
            "Attached \(SceneCoreFixtures.App.terminal) to the terminal slot. "
                + "This Scene owns it; its Home is still Development.",
        ])
        XCTAssertTrue(SceneCore.SceneRuntime.shared.snapshot.activeScene?.slots.first?.windows.first?.isMounted
            == false)
    }

    /// A mount reprojects the Scene, so whatever the engine had to say about the shape it settled on belongs
    /// with the sentence about the mount. HORO-1109 mounted a window into a Slot the substrate could not
    /// compose as described and was told only that the mount had happened: the screen and the reply disagreed,
    /// and nothing in the reply admitted it.
    func testMountingReportsWhatTheProjectionHadToSay() async throws {
        try await exec("scene new --title 'Debug PROD-123' --template empty")
        try await exec("scene 1")
        try await exec("slot new --role communication")
        let slot = try XCTUnwrap(SceneCore.SceneRuntime.shared.snapshot.activeScene?.slots.first?.id)
        // This substrate only ever comes out vertical, whatever the Slot is composed as.
        port.settledCompositions = [slot: .split(.vertical)]
        try await exec("slot compose --slot 1")
        try await exec("slot compose --slot 1") // now asked for horizontal, and the engine will not give it
        port.focused = try SceneCoreFixtures.windowRef(SceneCoreFixtures.App.line)
        port.surfaces[port.focused!] = SceneCoreFixtures.communicationSurface

        let result = try await exec("mount --slot 1")

        XCTAssertEqual(result.stdout, [
            "Mounted \(SceneCoreFixtures.App.line) into the communication slot. "
                + "Its Home is still Communication, and it goes back when the Scene closes.",
            "SceneMux composed the communication Slot of \"Debug PROD-123\" as a vertical split instead of "
                + "a horizontal split, because the window engine normalized it.",
        ])
    }

    /// Giving one window back, before the task ends. It goes to the workspace it was borrowed from — the
    /// recorded one, not a Home's usual place — and it leaves the Scene, so the Slot is empty again.
    func testUnmountingGivesTheWindowBackAndSaysWhereItWent() async throws {
        try await exec("scene new --title 'Debug PROD-123' --template empty")
        try await exec("scene 1")
        try await exec("slot new --role communication")
        port.focused = try SceneCoreFixtures.windowRef(SceneCoreFixtures.App.line)
        port.surfaces[port.focused!] = SceneCoreFixtures.communicationSurface
        try await exec("mount --slot 1")

        let result = try await parseCommand("unmount").cmdOrDie.run(.defaultEnv, .emptyStdin)

        XCTAssertEqual(result.stdout, [
            "\(SceneCoreFixtures.App.line) went back to where it came from. Its Home is still Communication.",
        ])
        XCTAssertEqual(port.requestedMoves.map(\.binding), [SceneCoreFixtures.communicationSurface])
        XCTAssertEqual(SceneCore.SceneRuntime.shared.snapshot.activeScene?.slots.first?.windows, [])
    }

    /// Every refusal, together, and every one of them says which of the three things was missing rather than
    /// reporting success against an unchanged screen. The last row is the one that matters most: a person who
    /// pressed the unmount binding over an ordinary window has to be told SceneMux is not holding it, because
    /// the alternative is believing it just moved something.
    func testEveryMissingPieceIsRefusedByName() async throws {
        let noScene = try await exec("mount --slot 1")
        XCTAssertEqual(noScene.stderr, ["No Scene is on screen, so there was nothing to do."])

        try await exec("scene new --title 'Debug PROD-123' --template empty")
        try await exec("scene 1")
        let noSlot = try await exec("mount --slot 1")
        XCTAssertEqual(noSlot.stderr, ["The Scene on screen has no Slot 1."])

        try await exec("slot new --role communication")
        let noWindow = try await exec("mount --slot 1")
        XCTAssertEqual(noWindow.stderr, ["SceneMux can’t tell which window you mean, so nothing was changed."])

        port.focused = try SceneCoreFixtures.windowRef(SceneCoreFixtures.App.music)
        let notHeld = try await exec("unmount")
        XCTAssertEqual(notHeld.stderr, ["That window isn’t in a Scene, so there was nothing to give back."])

        XCTAssertEqual(port.requestedMoves.count, 0)
        XCTAssertEqual(SceneCore.SceneRuntime.shared.snapshot.activeScene?.slots.first?.windows, [])
    }

    @discardableResult
    private func exec(_ command: String) async throws -> CmdResult {
        try await parseCommand(command).cmdOrDie.run(.defaultEnv, .emptyStdin)
    }
}
