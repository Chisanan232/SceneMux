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
                + "It is still a Communication window and goes back when the Scene closes.",
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
                + "This Scene owns it; it is still a Development window.",
        ])
        XCTAssertTrue(SceneCore.SceneRuntime.shared.snapshot.activeScene?.slots.first?.windows.first?.isMounted
            == false)
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
            "\(SceneCoreFixtures.App.line) went back to where it came from, a Communication window.",
        ])
        XCTAssertEqual(port.requestedMoves.map(\.binding), [SceneCoreFixtures.communicationSurface])
        XCTAssertEqual(SceneCore.SceneRuntime.shared.snapshot.activeScene?.slots.first?.windows, [])
    }

    @discardableResult
    private func exec(_ command: String) async throws -> CmdResult {
        try await parseCommand(command).cmdOrDie.run(.defaultEnv, .emptyStdin)
    }
}
