@testable import AppBundle
import Foundation
import XCTest

final class SceneCorePersistenceTest: XCTestCase {
    func testTheSemanticHomeIdsAreTheOnesPersistedStateAndRuleTablesKeyOn() {
        // The rawValue *is* the Semantic Home id, so renaming a case renames every user's persisted state
        // and every entry in their bundle-id rule table. Spelling them out here makes that a deliberate act.
        XCTAssertEqual(
            SceneCore.SemanticHome.allCases.map(\.rawValue),
            ["development", "communication", "observability", "personal"],
        )
    }
}
