@testable import AppBundle
import Foundation
import XCTest

/// The restorer against a recording engine, because what is worth checking is which windows it asks to be
/// moved, where, and what it concludes from the answer — none of which needs a desktop.
///
/// The real engine's half of the same story is `WinMuxSceneEngineAdapterTest`.
@MainActor
final class SceneRestorerTest: XCTestCase {
    private typealias App = SceneCoreFixtures.App

    func testABorrowedWindowGoesBackToTheSurfaceItCameFrom() throws {
        let port = RecordingSceneEnginePort()
        let slot = SceneCoreFixtures.slot(role: .communication)
        let windowRef = try SceneCoreFixtures.windowRef(App.line)
        let step = SceneCore.SceneTeardownStep(SceneCoreFixtures.attachment(
            windowRef: windowRef,
            slotId: slot.id,
            ownership: .borrowed,
            homeAtAttachTime: .communication,
            originSurface: SceneCoreFixtures.communicationSurface,
        ))

        let outcome = SceneCore.SceneRestorer(port: port).restore(step)

        XCTAssertEqual(outcome, .restored)
        XCTAssertEqual(port.requestedMoves.map(\.windowRef), [windowRef])
        XCTAssertEqual(port.requestedMoves.map(\.binding), [SceneCoreFixtures.communicationSurface])
    }

    func testTheRestoreAsksForTheArrangementTheWindowWasRecordedAsHaving() throws {
        // A floating chat window returned to its own workspace as one more tile has been resized and shuffled
        // in among its neighbours. It is on the right surface and it is not what it was, which is not what
        // "it goes back where it came from" promised.
        let port = RecordingSceneEnginePort()
        let slot = SceneCoreFixtures.slot(role: .communication)
        let step = SceneCore.SceneTeardownStep(SceneCoreFixtures.attachment(
            windowRef: try SceneCoreFixtures.windowRef(App.line),
            slotId: slot.id,
            ownership: .borrowed,
            homeAtAttachTime: .communication,
            originSurface: SceneCoreFixtures.communicationSurface,
            originArrangement: .floating,
        ))

        let outcome = SceneCore.SceneRestorer(port: port).restore(step)

        XCTAssertEqual(outcome, .restored)
        XCTAssertEqual(port.requestedMoves.map(\.arrangement), [.floating])
    }

    func testAnAttachmentThatRecordedNoArrangementAsksForNone() throws {
        // State from a build that did not record one, or a window the engine could not describe. The
        // temptation is `.tiled`, since that is what most windows are — and it would quietly float-to-tile
        // somebody's window on the strength of a value nobody ever observed.
        let port = RecordingSceneEnginePort()
        let slot = SceneCoreFixtures.slot(role: .communication)
        let step = SceneCore.SceneTeardownStep(SceneCoreFixtures.attachment(
            windowRef: try SceneCoreFixtures.windowRef(App.slack),
            slotId: slot.id,
            ownership: .borrowed,
            homeAtAttachTime: .communication,
            originSurface: SceneCoreFixtures.communicationSurface,
        ))

        let outcome = SceneCore.SceneRestorer(port: port).restore(step)

        XCTAssertEqual(outcome, .restored)
        XCTAssertEqual(port.requestedMoves.count, 1)
        XCTAssertNil(port.requestedMoves[0].arrangement)
    }

    func testTheEnginesAnswerDecidesWhetherTheRestoreIsStillOwed() throws {
        // Spelled out as the whole table, because the difference between these rows is whether the attachment
        // survives — and an attachment that survives is a window SceneMux will move again later. A `failed`
        // silently treated as final is a borrowed window abandoned in a closed task's layout; a `windowIsGone`
        // treated as retryable is a Scene that never finishes closing.
        let expected: [(SceneCore.SceneWindowMove, SceneCore.SceneTeardownOutcome, isFinal: Bool)] = [
            (.moved, .restored, isFinal: true),
            (.windowIsGone, .windowIsGone, isFinal: true),
            (
                .surfaceIsGone(reason: "its workspace is gone"),
                .leftInPlace(reason: "its workspace is gone"),
                isFinal: true
            ),
            (.failed(reason: "the app is busy"), .failed(reason: "the app is busy"), isFinal: false),
        ]
        let slot = SceneCoreFixtures.slot(role: .communication)
        let windowRef = try SceneCoreFixtures.windowRef(App.slack)
        let step = SceneCore.SceneTeardownStep(SceneCoreFixtures.attachment(
            windowRef: windowRef,
            slotId: slot.id,
            ownership: .borrowed,
            homeAtAttachTime: .communication,
            originSurface: SceneCoreFixtures.communicationSurface,
        ))

        for (answer, outcome, isFinal) in expected {
            let port = RecordingSceneEnginePort()
            port.moveAnswers[windowRef] = answer

            XCTAssertEqual(SceneCore.SceneRestorer(port: port).restore(step), outcome, "\(answer)")
            XCTAssertEqual(outcome.isFinal, isFinal, "\(answer)")
        }
    }

    func testAWindowWithNoRecordedSurfaceIsLeftWhereItIsAndTheEngineIsNotAsked() throws {
        // State written by an earlier build, or by a build that could not see where the window was. The
        // temptation is to send it to the Home's usual workspace, and that is exactly the guess invariant I8
        // forbids: the user would find a borrowed window on a surface it had never been on.
        let port = RecordingSceneEnginePort()
        let slot = SceneCoreFixtures.slot(role: .communication)
        let step = SceneCore.SceneTeardownStep(SceneCoreFixtures.attachment(
            windowRef: try SceneCoreFixtures.windowRef(App.line),
            slotId: slot.id,
            ownership: .borrowed,
            homeAtAttachTime: .communication,
        ))

        let outcome = SceneCore.SceneRestorer(port: port).restore(step)

        XCTAssertEqual(outcome, .leftInPlace(reason: "SceneMux has no record of where it came from"))
        XCTAssertEqual(port.requestedMoves.count, 0)
    }

    func testAWindowTheSceneWasNeverAllowedToMoveIsNotMoved() throws {
        // Both non-borrowed ownerships, together, and with an origin surface recorded — because a recorded
        // surface is the one thing that could tempt an implementation into "well, we know where it goes".
        // A scene-owned editor and a shared music window are the user's to close and to keep respectively,
        // and neither is the restorer's to touch.
        for ownership in [SceneCore.Ownership.sceneOwned, .sharedPersistent] {
            let port = RecordingSceneEnginePort()
            let slot = SceneCoreFixtures.slot(role: .editor)
            let step = SceneCore.SceneTeardownStep(SceneCoreFixtures.attachment(
                windowRef: try SceneCoreFixtures.windowRef(App.ide),
                slotId: slot.id,
                ownership: ownership,
                homeAtAttachTime: .development,
                originSurface: SceneCoreFixtures.communicationSurface,
            ))

            let outcome = SceneCore.SceneRestorer(port: port).restore(step)

            XCTAssertEqual(outcome, .leftInPlace(reason: "the Scene was not allowed to move it"), "\(ownership)")
            XCTAssertEqual(port.requestedMoves.count, 0, "\(ownership)")
        }
    }
}
