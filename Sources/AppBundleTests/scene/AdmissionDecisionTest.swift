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

    func testEveryDecisionThatIsNotAnAttachmentMovesNoWindowAtAll() {
        // The safety property worth being able to state in one line: `ignore` is not "attach it somewhere
        // harmless", and neither is `quarantine`. Nothing happens, including to a window whose record is
        // broken — which is invariant I6 arriving by way of the decision rather than by way of a reminder.
        for decision: SceneCore.AdmissionDecision in [.float, .ignore, .quarantine(reason: "unreadable")] {
            XCTAssertNil(decision.attachment, "\(decision) should attach nothing")
            XCTAssertFalse(decision.movesAWindow, "\(decision) should move nothing")
        }
    }
}
