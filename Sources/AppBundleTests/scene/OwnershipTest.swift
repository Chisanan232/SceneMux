@testable import AppBundle
import Foundation
import XCTest

final class OwnershipTest: XCTestCase {
    func testEachOwnershipPermitsExactlyTheTeardownItsTableRowNames() {
        XCTAssertEqual(SceneCore.Ownership.borrowed.teardownEffect, .restoreToHome)
        XCTAssertEqual(SceneCore.Ownership.sceneOwned.teardownEffect, .leaveInPlace)
        XCTAssertEqual(SceneCore.Ownership.sharedPersistent.teardownEffect, .untouched)
    }

    func testAnUnrecognisedPersistedOwnershipDegradesToTheUntouchableOne() throws {
        let fromTheFuture = Data(#""quarantinedPendingReview""#.utf8)

        let decoded = try JSONDecoder().decode(SceneCore.Ownership.self, from: fromTheFuture)

        XCTAssertEqual(decoded, .sharedPersistent)
        XCTAssertEqual(decoded.teardownEffect, .untouched)
    }
}
