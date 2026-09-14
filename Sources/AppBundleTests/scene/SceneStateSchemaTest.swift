@testable import AppBundle
import Foundation
import XCTest

final class SceneStateSchemaTest: XCTestCase {
    func testThisBuildReadsExactlyTheVersionsItClaimsTo() {
        let schema = SceneCore.SceneStateSchema.self

        // Including its own: a build that writes a version it would refuse to read back would lose someone's
        // Scenes on the next launch, and would do it on every machine at once.
        XCTAssertTrue(schema.canRead(schema.current))
        XCTAssertTrue(schema.canRead(schema.oldestReadable))
        XCTAssertFalse(schema.canRead(schema.current + 1))
        XCTAssertFalse(schema.canRead(schema.oldestReadable - 1))
    }
}
