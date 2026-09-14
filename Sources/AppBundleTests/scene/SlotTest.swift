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

    /// Recomposing is the *same* Slot shaped differently. If it produced a new identity the attachments
    /// pointing at it would all be dangling, and the Scene would refuse to exist.
    func testRecomposingASlotChangesOnlyItsComposition() {
        let slot = SceneCoreFixtures.slot(role: .communication, label: "chat", composition: .single, order: 4)

        let tabbed = slot.composed(as: .tabbed)

        XCTAssertEqual(tabbed.composition, .tabbed)
        XCTAssertEqual(tabbed.id, slot.id)
        XCTAssertEqual(tabbed.role, .communication)
        XCTAssertEqual(tabbed.label, "chat")
        XCTAssertEqual(tabbed.order, 4)
    }
}
