@testable import AppBundle
import Foundation
import XCTest

final class OwnershipTest: XCTestCase {
    func testEachOwnershipPermitsExactlyTheTeardownItsTableRowNames() {
        XCTAssertEqual(SceneCore.Ownership.borrowed.teardownEffect, .restoreToHome)
        XCTAssertEqual(SceneCore.Ownership.sceneOwned.teardownEffect, .leaveInPlace)
        XCTAssertEqual(SceneCore.Ownership.sharedPersistent.teardownEffect, .untouched)
    }

    func testNoOwnershipCanEverAskForAWindowToBeClosed() {
        // The point of `SceneTeardownEffect` having no `close` case: invariant I6 holds because an automatic
        // close is unrepresentable, not because every code path remembers not to do it. If someone adds a
        // fourth effect, this test is where they have to argue for it.
        XCTAssertEqual(
            SceneCore.SceneTeardownEffect.allCases,
            [.restoreToHome, .leaveInPlace, .untouched],
        )
    }

    func testAnUnrecognisedPersistedOwnershipDegradesToTheUntouchableOne() throws {
        let fromTheFuture = Data(#""quarantinedPendingReview""#.utf8)

        let decoded = try JSONDecoder().decode(SceneCore.Ownership.self, from: fromTheFuture)

        XCTAssertEqual(decoded, .sharedPersistent)
        XCTAssertEqual(decoded.teardownEffect, .untouched)
    }
}
