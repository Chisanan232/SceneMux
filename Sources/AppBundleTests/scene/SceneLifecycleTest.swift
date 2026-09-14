@testable import AppBundle
import Foundation
import XCTest

final class SceneLifecycleTest: XCTestCase {
    func testASceneCarriesASubstrateWhileActiveAndNoneAfterLeaving() throws {
        // Invariant I3. Leaving does not hand `defined` a substrate to forget about, because `defined` has
        // nowhere to put one — the binding lives only in `active`'s payload.
        let binding = SceneCore.SubstrateBinding(workspaceName: "scenemux-1")
        let defined = try SceneCoreFixtures.scene()

        let active = try defined.transitioning(to: .active(binding))
        let left = try active.transitioning(to: .defined)

        XCTAssertEqual(active.state, .active(binding))
        XCTAssertEqual(left.state, .defined)
    }

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
