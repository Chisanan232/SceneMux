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
}
