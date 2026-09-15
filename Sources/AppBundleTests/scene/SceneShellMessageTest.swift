@testable import AppBundle
import Foundation
import XCTest

final class SceneShellMessageTest: XCTestCase {
    private typealias App = SceneCoreFixtures.App

    /// Entering a Scene confirms which task owns the screen and how big it is, and says it once. Singulars are
    /// spelled correctly because this line is read every time someone switches tasks.
    func testEnteringASceneSaysWhichSceneAndHowBigItIs() {
        XCTAssertEqual(
            SceneCore.SceneShellMessage.entered(sceneTitle: "Debug PROD-123", slots: 4, windows: 6).text,
            "Debug PROD-123 · 4 slots, 6 windows",
        )
        XCTAssertEqual(
            SceneCore.SceneShellMessage.entered(sceneTitle: "Release notes", slots: 1, windows: 1).text,
            "Release notes · 1 slot, 1 window",
        )
    }

    /// A refusal comes first and carries its details behind a disclosure, and every Scene that lost windows is
    /// named separately — a merged count would leave the user opening each Scene to find out which one changed.
    func testStartupReportsTheRefusalFirstAndThenNamesEachSceneThatLostWindows() throws {
        let refusal = SceneCore.SceneStateRefusal(
            reason: .unreadable,
            path: "/tmp/scene-state.json",
            preservedAt: "/tmp/scene-state.unreadable.json",
        )
        let dropped = try [("Debug PROD-123", App.line), ("Debug PROD-123", App.slack), ("Notes", App.music)]
            .map { title, bundleId in
                SceneCore.SceneStateQuarantine(
                    sceneId: .generate(),
                    sceneTitle: title,
                    windowRef: try SceneCoreFixtures.windowRef(bundleId),
                    reason: .alreadyAttached,
                )
            }

        let messages = SceneCore.SceneShellMessage.onStartup(refusal: refusal, quarantined: dropped)

        XCTAssertEqual(messages.map(\.text), [
            "Scene state couldn’t be read — no windows were changed",
            "2 windows from “Debug PROD-123” are no longer open",
            "1 window from “Notes” is no longer open",
        ])
        XCTAssertEqual(messages.first?.details, refusal.diagnostic)
        XCTAssertEqual(messages.map(\.showsDetails), [true, false, false])
        XCTAssertEqual(messages.map(\.announces), [true, true, true])
    }

    /// The four lifecycle sentences, word for word from the table in `docs/design/scene-core-ux.md`. Asserted
    /// literally because the wording *is* the design here: "left in place" and "left untouched" are different
    /// promises, and a paraphrase would quietly change what SceneMux is telling people it did.
    func testTheLifecycleSentencesAreTheOnesTheDesignSpecifies() {
        XCTAssertEqual(
            SceneCore.SceneShellMessage
                .windowsRestored(home: .communication, applications: ["LINE", "Slack"]).text,
            "2 windows went back to Communication — LINE, Slack",
        )
        XCTAssertEqual(
            SceneCore.SceneShellMessage.restoreDeclined(applicationName: "Slack").text,
            "Slack could not be found — nothing was closed or moved",
        )
        XCTAssertEqual(
            SceneCore.SceneShellMessage.windowsLeftInPlace(windows: 4).text,
            "4 windows left in place",
        )
        XCTAssertEqual(
            SceneCore.SceneShellMessage.sharedWindowSkipped(applicationName: "Music").text,
            "Music is shared — left untouched",
        )
    }

    /// Closing the golden journey, with both chat windows going home: the restore is reported first and names
    /// them, and the four windows the Scene left alone are counted in a line of their own.
    func testClosingTheGoldenJourneySaysWhatWentHomeAndWhatWasLeftAlone() throws {
        let plan = SceneCore.SceneTeardownPlan(try SceneCoreFixtures.debugScene())
        let outcomes = Dictionary(
            uniqueKeysWithValues: plan.pending.map { ($0.windowRef, SceneCore.SceneTeardownOutcome.restored) },
        )

        let messages = SceneCore.SceneShellMessage.onClose(
            plan,
            outcomes: outcomes,
            naming: { [App.line: "LINE", App.slack: "Slack"][$0] },
        )

        XCTAssertEqual(messages.map(\.text), [
            "2 windows went back to Communication — LINE, Slack",
            "4 windows left in place",
        ])
    }

    /// One window went home, one could not, and one the user had already closed themselves. Only the first two
    /// are said: a window that is gone is not news, and a list that reported it would make the line about the
    /// window that really did not move harder to notice.
    func testAWindowTheUserAlreadyClosedIsNotReportedButARefusalIs() throws {
        let comms = SceneCoreFixtures.slot(role: .communication)
        let scene = try SceneCoreFixtures.scene(slots: [comms])
            .attaching(SceneCoreFixtures.attachment(
                windowRef: try SceneCoreFixtures.windowRef(App.line),
                slotId: comms.id,
                ownership: .borrowed,
                homeAtAttachTime: .communication,
                originSurface: SceneCoreFixtures.communicationSurface,
            ))
            .attaching(SceneCoreFixtures.attachment(
                windowRef: try SceneCoreFixtures.windowRef(App.slack),
                slotId: comms.id,
                ownership: .borrowed,
                homeAtAttachTime: .communication,
                originSurface: SceneCoreFixtures.communicationSurface,
            ))
            .attaching(SceneCoreFixtures.attachment(
                windowRef: try SceneCoreFixtures.windowRef(App.music),
                slotId: comms.id,
                ownership: .borrowed,
                homeAtAttachTime: .personal,
                originSurface: SceneCoreFixtures.communicationSurface,
            ))
        let plan = SceneCore.SceneTeardownPlan(scene)

        let messages = SceneCore.SceneShellMessage.onClose(
            plan,
            outcomes: [
                try SceneCoreFixtures.windowRef(App.line): .restored,
                try SceneCoreFixtures.windowRef(App.slack): .leftInPlace(reason: "its workspace is gone"),
                try SceneCoreFixtures.windowRef(App.music): .windowIsGone,
            ],
            naming: { [App.line: "LINE", App.slack: "Slack", App.music: "Music"][$0] },
        )

        XCTAssertEqual(messages.map(\.text), [
            "1 window went back to Communication — LINE",
            "Slack could not be found — nothing was closed or moved",
        ])
    }

    /// Re-homing an application while a Scene has borrowed one of its windows does not move the window: the
    /// restore replays the surface recorded when it was borrowed. So the line names *that* Home — Music is
    /// `personal` in the shipped rules and was borrowed as a Communication window, and saying "went back to
    /// Personal" would send somebody looking for it in a place nothing put it.
    func testARestoreIsReportedUnderTheHomeTheWindowWasBorrowedFrom() throws {
        let comms = SceneCoreFixtures.slot(role: .communication)
        let scene = try SceneCoreFixtures.scene(slots: [comms])
            .attaching(SceneCoreFixtures.attachment(
                windowRef: try SceneCoreFixtures.windowRef(App.music),
                slotId: comms.id,
                ownership: .borrowed,
                homeAtAttachTime: .communication,
                originSurface: SceneCoreFixtures.communicationSurface,
            ))
        let plan = SceneCore.SceneTeardownPlan(scene)

        let messages = SceneCore.SceneShellMessage.onClose(
            plan,
            outcomes: [try SceneCoreFixtures.windowRef(App.music): .restored],
            naming: { [App.music: "Music"][$0] },
        )

        XCTAssertEqual(messages.map(\.text), ["1 window went back to Communication — Music"])
    }
}
