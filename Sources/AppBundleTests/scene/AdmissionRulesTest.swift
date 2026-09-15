@testable import AppBundle
import Foundation
import XCTest

/// The G1 rules, one claim at a time. No desktop, no engine and no window server: a decision is a value
/// computed from a value, which is the whole reason admission was built as a returned decision.
final class AdmissionRulesTest: XCTestCase {
    private typealias App = SceneCoreFixtures.App
    private typealias Rule = SceneCore.AdmissionRules.Rule

    func testAWindowGoesToAnEmptySlotWhoseRoleServesItsHome() throws {
        let terminal = SceneCoreFixtures.slot(role: .terminal, order: 0)
        let scene = try SceneCoreFixtures.scene(
            slots: [terminal],
            state: .active(SceneCoreFixtures.activeSubstrate),
        )

        let decision = SceneCore.AdmissionRules.decide(
            try SceneCoreFixtures.admissionCandidate(App.terminal, in: scene),
        )

        XCTAssertEqual(decision, .route(slotId: terminal.id, ruleId: Rule.emptySlotServingHome))
    }

    func testSlotOrderDecidesWhichOfTwoEmptyServingSlotsGetsTheWindow() throws {
        // Stored editor-first and ordered terminal-first, because "the first empty development Slot" has to
        // mean the first one the person sees rather than the first one the Scene happens to hold. A Home is
        // coarser than a Slot role — nothing SceneMux may read says whether an IDE window is an editor or a
        // terminal — so Slot order is the whole of the tie-break, and it has to be the visible order.
        let editor = SceneCoreFixtures.slot(role: .editor, order: 1)
        let terminal = SceneCoreFixtures.slot(role: .terminal, order: 0)
        let scene = try SceneCoreFixtures.scene(
            slots: [editor, terminal],
            state: .active(SceneCoreFixtures.activeSubstrate),
        )

        let decision = SceneCore.AdmissionRules.decide(
            try SceneCoreFixtures.admissionCandidate(App.ide, in: scene),
        )

        XCTAssertEqual(decision, .route(slotId: terminal.id, ruleId: Rule.emptySlotServingHome))
    }

    func testASecondChatWindowJoinsTheTabGroupThatIsAlreadyFull() throws {
        // The golden journey's communication Slot: two chat windows in it already, and it is a tab group, which
        // is the Scene saying more of these are welcome. A full Slot that is *not* a tab group has no such
        // thing to say, which is the next test.
        let scene = try SceneCoreFixtures.debugScene(state: .active(SceneCoreFixtures.activeSubstrate))
        let comms = try XCTUnwrap(scene.slots.first { $0.role == .communication })

        let decision = SceneCore.AdmissionRules.decide(
            try SceneCoreFixtures.admissionCandidate(App.line, ordinal: 1, in: scene),
        )

        XCTAssertEqual(decision, .tab(slotId: comms.id, ruleId: Rule.tabGroupServingHome))
    }
}
