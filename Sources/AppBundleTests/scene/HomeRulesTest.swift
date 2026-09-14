@testable import AppBundle
import Foundation
import XCTest

/// How an application's Semantic Home is decided: the shipped table, the user's overrides, and nothing else.
final class HomeRulesTest: XCTestCase {
    private typealias App = SceneCoreFixtures.App

    /// The table shipped with SceneMux has to produce the golden journey's Homes on a real Mac, or the
    /// journey only works for someone who has written a config file first. This is that assertion, on the
    /// six applications `docs/design/scene-core-architecture.md` names.
    func testTheShippedTableProducesTheGoldenJourneysHomes() {
        let rules = SceneCore.HomeRules.shippedOnly

        XCTAssertEqual(rules.home(of: App.terminal), .development)
        XCTAssertEqual(rules.home(of: App.ide), .development)
        XCTAssertEqual(rules.home(of: App.grafana), .observability)
        XCTAssertEqual(rules.home(of: App.line), .communication)
        XCTAssertEqual(rules.home(of: App.slack), .communication)
        // A browser is whatever its user is doing at the time, and the journey's preview browser is
        // `personal` precisely because SceneMux must not guess that a browser is part of the work.
        XCTAssertEqual(rules.home(of: App.browser), .personal)
        XCTAssertEqual(rules.home(of: App.music), .personal)
    }

    /// The user's own rule wins, and the resolution says so. Two sentences the UI has to be able to tell
    /// apart: "SceneMux thinks your browser is personal" is worth arguing with, "you told SceneMux your
    /// browser is development work" is not.
    func testAUserOverrideWinsAndIsAttributedToTheUser() {
        let rules = SceneCore.HomeRules(overrides: [App.browser: .development])

        XCTAssertEqual(rules.home(of: App.browser), .development)
        XCTAssertEqual(rules.source(of: App.browser), .userOverride)
        XCTAssertEqual(rules.home(of: App.terminal), .development)
        XCTAssertEqual(rules.source(of: App.terminal), .shippedDefault)
    }

    /// An application nobody has classified still gets an answer, and the answer claims nothing: it is the
    /// user's own. A resolution that could fail would have every caller inventing a Home of its own.
    func testAnApplicationNobodyClassifiedIsThePersonalFallback() {
        let rules = SceneCore.HomeRules(overrides: [App.terminal: .development])

        XCTAssertEqual(rules.home(of: "com.example.SomethingNobodyHasHeardOf"), .personal)
        XCTAssertEqual(rules.source(of: "com.example.SomethingNobodyHasHeardOf"), .fallback)
        XCTAssertEqual(SceneCore.HomeRules.fallback, .personal)
    }
}
