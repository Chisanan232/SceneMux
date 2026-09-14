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

    /// Creating a Scene does not enter it: nothing on the user's screen moves, which is what makes creating a
    /// Scene free. The new Scene is selected, so the next `⏎` enters the thing that was just named.
    func testCreatingASceneNamesItWithoutMovingAnything() throws {
        model.query = "Debug PROD-123"

        model.beginCreate()
        XCTAssertEqual(model.nameField, "Debug PROD-123", "the field starts as what was searched for")
        model.template = .empty
        model.commitName()

        XCTAssertEqual(model.mode, .browsing)
        XCTAssertEqual(model.query, "")
        XCTAssertEqual(model.selectedScene?.title, "Debug PROD-123")
        XCTAssertNil(model.snapshot.activeScene, "creating does not enter")
        XCTAssertEqual(port.preparedSubstrates, [])
    }

    /// Renaming edits in place and commits on `⏎`; Esc reverts. The `SceneId` never changes, so nothing that
    /// refers to a Scene depends on what it is called.
    func testRenamingCommitsOnReturnAndRevertsOnEscape() throws {
        let created = try model.runtime.createScene(title: "Debug PROD-12", template: .empty)

        model.beginRename()
        XCTAssertEqual(model.mode, .renaming(created.id))
        model.nameField = "Debug PROD-123"
        model.commitName()
        XCTAssertEqual(model.results.map(\.title), ["Debug PROD-123"])
        XCTAssertEqual(model.results.map(\.id), [created.id])

        model.beginRename()
        model.nameField = "Something else entirely"
        XCTAssertFalse(model.escape(), "Esc abandons the edit and keeps the panel up")
        XCTAssertEqual(model.mode, .browsing)
        XCTAssertEqual(model.results.map(\.title), ["Debug PROD-123"])
        XCTAssertTrue(model.escape(), "a second Esc, with nothing part-way through, dismisses")
    }

    /// `⌘⌫` shows the model's own reasoning about ownership and stops there. The Scene is still on screen after
    /// asking; only confirming ends it.
    func testClosingAsksWithTheOwnershipSummaryFirst() throws {
        let scene = try model.runtime.createScene(title: "Debug PROD-123", template: .empty)
        try model.runtime.enter(scene.id)

        model.beginClose()

        guard case .confirmingClose(let id, let summary) = model.mode else {
            return XCTFail("expected the confirmation, got \(model.mode)")
        }
        XCTAssertEqual(id, scene.id)
        XCTAssertEqual(summary.title, "Close “Debug PROD-123”?")
        XCTAssertEqual(model.snapshot.activeScene?.id, scene.id, "asking changes nothing")

        model.confirmClose()

        XCTAssertEqual(model.mode, .browsing)
        XCTAssertEqual(model.results, [], "an ended Scene is not a row")
        XCTAssertNil(model.errorText)
    }

    /// Composing a Slot from the panel cycles its shape and re-draws the Scene, so the chip in the row and the
    /// windows on screen cannot disagree.
    func testComposingASlotFromThePanelCyclesItsShape() throws {
        let scene = try model.runtime.createScene(title: "Debug PROD-123", template: .empty)
        try model.runtime.enter(scene.id)
        model.addSlot(role: .communication, label: "Chat")
        let slot = try XCTUnwrap(model.selectedScene?.slots.first)

        model.cycleComposition(of: slot.id)
        XCTAssertEqual(model.selectedScene?.slots.first?.compositionChip, "split ⬍")
        model.cycleComposition(of: slot.id)
        XCTAssertEqual(model.selectedScene?.slots.first?.compositionChip, "split ⬌")
        model.cycleComposition(of: slot.id)
        XCTAssertEqual(model.selectedScene?.slots.first?.compositionChip, "tabs")
        model.cycleComposition(of: slot.id)
        XCTAssertNil(model.selectedScene?.slots.first?.compositionChip, "back to a single window")

        model.removeSlot(slot.id)
        XCTAssertEqual(model.selectedScene?.slots, [])
        XCTAssertNil(model.errorText)
    }

    /// A command and a keystroke reach the panel as the same request, and one that names a Scene opens looking
    /// at that Scene rather than at whatever was selected last.
    func testACommandRequestOpensThePanelOnWhatItWasAbout() throws {
        _ = try model.runtime.createScene(title: "First", template: .empty)
        let second = try model.runtime.createScene(title: "Second", template: .empty)
        model.query = "First"

        model.apply(.confirmClose(second.id))

        XCTAssertEqual(model.query, "", "a filter that hid the Scene is cleared rather than left to lie")
        XCTAssertEqual(model.selectedScene?.id, second.id)
        guard case .confirmingClose(let id, _) = model.mode else {
            return XCTFail("expected the confirmation, got \(model.mode)")
        }
        XCTAssertEqual(id, second.id)

        model.apply(.newScene)
        XCTAssertEqual(model.mode, .creating)
        XCTAssertEqual(model.nameField, "")
    }

    /// Opening the switcher shows every Scene. The model outlives the panel's window, so a filter typed to find
    /// one task would otherwise still be narrowing the list the next time the user asks *what am I working on*.
    func testOpeningTheSwitcherStartsFromTheWholeList() throws {
        _ = try model.runtime.createScene(title: "Debug PROD-123", template: .empty)
        _ = try model.runtime.createScene(title: "Review release notes", template: .empty)
        model.query = "debug"
        XCTAssertEqual(model.results.map(\.title), ["Debug PROD-123"])

        model.apply(.switcher)

        XCTAssertEqual(model.query, "")
        XCTAssertEqual(model.results.map(\.title), ["Debug PROD-123", "Review release notes"])
        XCTAssertEqual(model.mode, .browsing)
    }

    /// A refusal is shown rather than swallowed, and the panel stays up carrying it: the user pressed a key
    /// expecting the screen to change, so silence would leave them with no idea why it did not.
    func testARefusalIsShownOnThePanelAndNothingIsEntered() throws {
        let scene = try model.runtime.createScene(title: "Debug PROD-123", template: .empty)
        port.substrate = nil

        XCTAssertFalse(model.enter(scene.id))

        XCTAssertEqual(model.errorText, "There is nowhere to put a Scene right now, so nothing was changed.")
        XCTAssertNil(model.snapshot.activeScene)
        XCTAssertEqual(port.preparedSubstrates, [])
    }

    /// Leaving a Scene takes it off screen and moves nothing, and leaving when there is no Scene on screen says
    /// so instead of quietly doing nothing — the menu item and `⌃⌥0` both land here.
    func testLeavingTakesTheSceneOffScreenWithoutMovingAnything() throws {
        let scene = try model.runtime.createScene(title: "Debug PROD-123", template: .empty)
        XCTAssertTrue(model.enter(scene.id))
        let placedWhileEntering = port.placedGroups.count

        XCTAssertTrue(model.leave())

        XCTAssertNil(model.snapshot.activeScene, "the Scene is no longer on screen")
        XCTAssertEqual(model.snapshot.scenes.map(\.title), ["Debug PROD-123"], "and it still exists")
        XCTAssertEqual(port.placedGroups.count, placedWhileEntering, "leaving places nothing")
        XCTAssertNil(model.errorText)

        XCTAssertFalse(model.leave())
        XCTAssertEqual(model.errorText, "No Scene is on screen, so there was nothing to do.")
    }
}
