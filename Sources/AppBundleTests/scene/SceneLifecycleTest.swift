@testable import AppBundle
import Foundation
import XCTest

final class SceneLifecycleTest: XCTestCase {
    func testTheLifecyclePermitsExactlyTheTransitionsTheDesignNames() {
        // Spelled out as the whole table rather than as the legal edges alone, so that widening the lifecycle
        // has to be written down here too. A transition nobody meant to allow is how a closed Scene starts
        // moving windows again.
        let legal: Set<[SceneCore.SceneState.Label]> = [
            [.defined, .active], [.defined, .ending],
            [.active, .defined], [.active, .ending],
            [.ending, .ending], [.ending, .ended],
        ]
        let states: [SceneCore.SceneState] = [
            .defined,
            .active(SceneCore.SubstrateBinding(workspaceName: "scenemux-1")),
            .ending,
            .ended,
        ]

        for state in states {
            for target in SceneCore.SceneState.Label.allCases {
                XCTAssertEqual(
                    state.canTransition(to: target),
                    legal.contains([state.label, target]),
                    "\(state.label) → \(target)",
                )
            }
        }
    }
}
