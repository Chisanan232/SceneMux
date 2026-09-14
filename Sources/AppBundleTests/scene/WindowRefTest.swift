@testable import AppBundle
import Foundation
import XCTest

final class WindowRefTest: XCTestCase {
    func testABundleIdOfNothingButWhitespaceIsRejected() {
        XCTAssertThrowsError(try SceneCoreFixtures.windowRef("   \n ")) { error in
            XCTAssertEqual(error as? SceneCore.SceneCoreError, .emptyBundleId)
        }
    }

    func testDecodingRunsTheSameValidationAsConstruction() throws {
        let invalid = Data(#"{"bundleId":"","ordinalWithinApp":0}"#.utf8)

        XCTAssertThrowsError(try JSONDecoder().decode(SceneCore.WindowRef.self, from: invalid)) { error in
            XCTAssertEqual(error as? SceneCore.SceneCoreError, .emptyBundleId)
        }
    }

    func testASurroundingWhitespaceDoesNotMakeTwoWindowsLookDifferent() throws {
        let padded = try SceneCoreFixtures.windowRef("  com.apple.Terminal  ")
        let plain = try SceneCoreFixtures.windowRef("com.apple.Terminal")

        XCTAssertEqual(padded, plain)
        XCTAssertEqual(padded.hashValue, plain.hashValue)
    }

    func testANegativeOrdinalIsRejected() {
        XCTAssertThrowsError(try SceneCoreFixtures.windowRef(ordinal: -1)) { error in
            XCTAssertEqual(error as? SceneCore.SceneCoreError, .negativeWindowOrdinal(-1))
        }
    }
}
