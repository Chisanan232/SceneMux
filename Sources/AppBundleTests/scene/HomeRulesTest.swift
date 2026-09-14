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
}
