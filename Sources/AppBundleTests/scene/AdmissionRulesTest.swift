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

    func testAWindowWithNowhereLeftToGoIsLeftWhereItIs() throws {
        // Both development Slots of the journey are full and neither is a tab group. There is no evidence about
        // what the person wants, so nothing happens: a second terminal stays wherever the engine put it rather
        // than being squeezed into a Slot that already has a window in it.
        let scene = try SceneCoreFixtures.debugScene(state: .active(SceneCoreFixtures.activeSubstrate))

        let decision = SceneCore.AdmissionRules.decide(
            try SceneCoreFixtures.admissionCandidate(App.terminal, ordinal: 1, in: scene),
        )

        XCTAssertEqual(decision, .ignore)
    }

    func testAnApplicationNobodyHasClassifiedIsDeclinedEvenWithAnEmptySlotWaiting() throws {
        // The explicit safe fallback, asserted together with the chain that produces it: an unknown application
        // resolves to `HomeRules.fallback`, that is `personal`, and `personal` is served by no Slot role. The
        // Slot is empty and eligible in every other way, so nothing but the fallback is stopping this.
        let stranger = "com.example.something-scenemux-has-never-heard-of"
        let terminal = SceneCoreFixtures.slot(role: .terminal, order: 0)
        let scene = try SceneCoreFixtures.scene(
            slots: [terminal],
            state: .active(SceneCoreFixtures.activeSubstrate),
        )

        let decision = SceneCore.AdmissionRules.decide(
            try SceneCoreFixtures.admissionCandidate(stranger, in: scene),
        )

        XCTAssertEqual(SceneCore.HomeRules.shippedOnly.home(of: stranger), .personal)
        XCTAssertEqual(SceneCore.HomeRules.shippedOnly.source(of: stranger), .fallback)
        XCTAssertEqual(SceneCore.AdmissionRules.roles(serving: .personal), [])
        XCTAssertEqual(decision, .ignore)
    }

    func testABrowserWindowIsNeverRoutedByARuleHoweverInvitingTheSceneLooks() throws {
        // "A Chrome window is not a Playwright window." A Scene with an empty preview Slot and an empty terminal
        // Slot is as inviting as a Scene gets, and a browser window still gets nothing: SceneMux has no
        // browser-session ownership in v0.1.0, so it must not infer from a bundle id that a browser window is
        // automation-owned, agent-owned or part of anybody's task. A person who wants it there mounts it.
        let preview = SceneCoreFixtures.slot(role: .preview, order: 0)
        let terminal = SceneCoreFixtures.slot(role: .terminal, order: 1)
        let scene = try SceneCoreFixtures.scene(
            slots: [preview, terminal],
            state: .active(SceneCoreFixtures.activeSubstrate),
        )

        let decision = SceneCore.AdmissionRules.decide(
            try SceneCoreFixtures.admissionCandidate(App.browser, in: scene),
        )

        XCTAssertEqual(decision, .ignore)
    }

    func testADialogAPopupAndAMinimizedWindowAreAllLeftAlone() throws {
        // The same terminal, with the same empty terminal Slot waiting, four times: only the kind differs. A save
        // sheet, a completion list and a window somebody minimized are not the work, and moving one of them
        // would break the interaction it belongs to.
        let terminal = SceneCoreFixtures.slot(role: .terminal, order: 0)
        let scene = try SceneCoreFixtures.scene(
            slots: [terminal],
            state: .active(SceneCoreFixtures.activeSubstrate),
        )

        for kind in SceneCore.AdmissionWindowKind.allCases where kind != .managed {
            let decision = SceneCore.AdmissionRules.decide(
                try SceneCoreFixtures.admissionCandidate(App.terminal, kind: kind, in: scene),
            )
            XCTAssertEqual(decision, .ignore, "a \(kind) window should be left alone")
        }
    }

    func testStartupDetectionsAreNotTreatedAsSomebodyOpeningAWindow() throws {
        // The worst thing admission could do, and the reason the flag exists. A Scene is still `active` after a
        // relaunch, and at startup the engine presents every window that already exists — so without this, one
        // restart would sweep the desktop into whichever task was open yesterday.
        let terminal = SceneCoreFixtures.slot(role: .terminal, order: 0)
        let scene = try SceneCoreFixtures.scene(
            slots: [terminal],
            state: .active(SceneCoreFixtures.activeSubstrate),
        )

        let decision = SceneCore.AdmissionRules.decide(
            try SceneCoreFixtures.admissionCandidate(App.terminal, detectedDuringStartup: true, in: scene),
        )

        XCTAssertEqual(decision, .ignore)
    }

    func testAWindowThatIsAlreadySpokenForIsNotDecidedAboutTwice() throws {
        // Invariant I4 — one attachment per window across all Scenes — and the reason a second look at the same
        // window is harmless. The engine really does detect a window twice: once when it appears, and again when
        // a window it had misread as a popup turns out to be an ordinary one. The second look must not produce a
        // second decision, and it must not matter which Scene the window is already in.
        let terminal = SceneCoreFixtures.slot(role: .terminal, order: 0)
        let scene = try SceneCoreFixtures.scene(
            slots: [terminal],
            state: .active(SceneCoreFixtures.activeSubstrate),
        )

        let decision = SceneCore.AdmissionRules.decide(
            try SceneCoreFixtures.admissionCandidate(App.terminal, in: scene, isAlreadyInAScene: true),
        )

        XCTAssertEqual(decision, .ignore)
    }
}
