@testable import AppBundle
import Foundation
import XCTest

final class SlotCompositionTest: XCTestCase {
    /// The cycle has to come back to where it started, or a Slot would have a shape the key that shaped it
    /// can no longer undo.
    func testCyclingACompositionVisitsEveryShapeAndReturns() {
        let start = SceneCore.SlotComposition.single

        let visited = (1 ... 4).reduce(into: [start]) { visited, _ in
            visited.append(visited.last!.cycled)
        }

        XCTAssertEqual(visited, [.single, .split(.vertical), .split(.horizontal), .tabbed, .single])
    }
}
