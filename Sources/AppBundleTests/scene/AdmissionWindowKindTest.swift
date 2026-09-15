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
}
