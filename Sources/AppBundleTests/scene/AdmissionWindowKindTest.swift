@testable import AppBundle
import Foundation
import XCTest

final class AdmissionWindowKindTest: XCTestCase {
    func testOnlyAnOrdinaryManagedWindowIsEligibleForASlot() {
        // Written over `allCases` rather than as three assertions, so that a fifth kind cannot arrive with an
        // unexamined answer: whoever adds it has to come here and say which side of the line it falls on.
        XCTAssertEqual(
            SceneCore.AdmissionWindowKind.allCases.filter(\.isEligibleForASlot),
            [.managed],
        )
    }

    func testOnlyTheTwoKindsThatSayHowAWindowSitsHaveAnArrangement() {
        // Over `allCases` for the same reason, and because this mapping is what a restore replays: a kind that
        // arrived with an unexamined `.tiled` would send a window home as something it never was.
        XCTAssertEqual(
            SceneCore.AdmissionWindowKind.allCases.map(\.arrangement),
            [.tiled, .floating, nil, nil],
        )
        XCTAssertEqual(SceneCore.AdmissionWindowKind.allCases, [.managed, .floating, .popup, .setAside])
    }
}
