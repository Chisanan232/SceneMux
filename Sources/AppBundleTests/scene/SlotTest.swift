@testable import AppBundle
import Foundation
import XCTest

final class SlotTest: XCTestCase {
    func testAUsersOwnLabelIsWhatTheyGetBack() {
        let labelled = SceneCoreFixtures.slot(role: .terminal, label: "agent")

        XCTAssertEqual(labelled.displayName, "agent")
        XCTAssertEqual(labelled.role, .terminal)
    }

    func testASlotWithNoUsableLabelIsStillNamedAfterItsRole() {
        let unlabelled = SceneCoreFixtures.slot(role: .observability, label: nil)
        let blank = SceneCoreFixtures.slot(role: .observability, label: "   ")

        XCTAssertEqual(unlabelled.displayName, "observability")
        XCTAssertEqual(blank.displayName, "observability")
    }
}
