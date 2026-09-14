@testable import AppBundle
import Common
import XCTest

/// The Scene switcher's behaviour, against a runtime pointed at a temporary state file.
///
/// The panel above the model is a thin layer that turns key codes into these calls, so what is asserted here
/// is what the keyboard does: this is the closest a test can get to pressing the keys without a window server.
@MainActor
final class SceneSwitcherModelTest: XCTestCase {
    private var port = RecordingSceneEnginePort()
    private var model = SceneSwitcherModel(runtime: SceneCore.SceneRuntime())

    override func setUp() async throws {
        setUpWorkspacesForTests()
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "SceneMuxTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        port = RecordingSceneEnginePort()
        model = SceneSwitcherModel(runtime: SceneCore.SceneRuntime(
            store: SceneCore.SceneStateStore(url: directory.appending(path: "scene-state.json")),
            engine: port,
            naming: { _ in nil },
        ))
    }

    /// Typing narrows the list and puts the selection back at the top, and the arrow keys stop at the ends
    /// rather than wrapping — nine number keys are the way to jump, and a list that wraps under the cursor
    /// loses the user's place.
    func testTypingNarrowsTheListAndTheArrowsStopAtTheEnds() throws {
        for title in ["Debug PROD-123", "Review release notes", "Onboarding"] {
            _ = try model.runtime.createScene(title: title, template: .empty)
        }

        XCTAssertEqual(model.results.map(\.title), ["Debug PROD-123", "Review release notes", "Onboarding"])

        model.moveSelection(-1)
        XCTAssertEqual(model.selection, 0)
        model.moveSelection(1)
        model.moveSelection(1)
        model.moveSelection(1)
        XCTAssertEqual(model.selectedScene?.title, "Onboarding")

        model.query = "rel"
        XCTAssertEqual(model.results.map(\.title), ["Review release notes"])
        XCTAssertEqual(model.selection, 0)
        XCTAssertEqual(model.selectedScene?.title, "Review release notes")

        model.query = "nothing here"
        XCTAssertEqual(model.results, [])
        XCTAssertNil(model.selectedScene)
    }

    /// A Scene is findable by what it holds, not only by what it is called: its Slot labels are part of the
    /// haystack, because a user who labelled a Slot *Review* will look for it by that word.
    func testASceneIsFoundByItsSlotLabelsToo() throws {
        let scene = try model.runtime.createScene(title: "Debug PROD-123", template: .empty)
        try model.runtime.enter(scene.id)
        try model.runtime.addSlot(role: .editor, label: "Release notes")

        model.query = "release"

        XCTAssertEqual(model.results.map(\.title), ["Debug PROD-123"])
    }
}
