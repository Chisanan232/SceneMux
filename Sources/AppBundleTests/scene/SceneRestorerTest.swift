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
}
