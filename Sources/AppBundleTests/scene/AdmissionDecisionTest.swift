@testable import AppBundle
import Foundation
import XCTest

final class AdmissionDecisionTest: XCTestCase {
    func testEachAttachingDecisionImpliesExactlyOneOwnership() {
        let slotId = SceneCore.SlotId.generate()

        // Routing and tabbing are two shapes of the same thing: a window the Scene brought into being, which
        // has no earlier place to be sent back to. Mounting borrows one that does.
        XCTAssertEqual(SceneCore.AdmissionDecision.route(slotId: slotId, ruleId: "r").attachment?.ownership,
                       .sceneOwned)
        XCTAssertEqual(SceneCore.AdmissionDecision.tab(slotId: slotId, ruleId: "r").attachment?.ownership,
                       .sceneOwned)
        XCTAssertEqual(SceneCore.AdmissionDecision.mount(slotId: slotId, ruleId: "r").attachment?.ownership,
                       .borrowed)
        XCTAssertEqual(SceneCore.AdmissionDecision.claim(slotId: slotId).attachment?.ownership, .sceneOwned)
    }
}
