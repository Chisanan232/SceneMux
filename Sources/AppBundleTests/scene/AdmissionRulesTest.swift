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
}
