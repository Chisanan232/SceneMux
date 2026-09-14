@testable import AppBundle
import Foundation
import XCTest

final class SlotTest: XCTestCase {
    func testASlotWithNoUsableLabelIsStillNamedAfterItsRole() {
        let unlabelled = SceneCoreFixtures.slot(role: .observability, label: nil)
        let blank = SceneCoreFixtures.slot(role: .observability, label: "   ")

        XCTAssertEqual(unlabelled.displayName, "observability")
        XCTAssertEqual(blank.displayName, "observability")
    }
}
