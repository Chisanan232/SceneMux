@testable import AppBundle
import Foundation
import XCTest

/// The order of operations at the seam, and the honesty of the report that comes back.
///
/// No engine here on purpose: `RecordingSceneEnginePort` answers however the test needs, so that what is
/// under test is the projector's own behaviour rather than a Mac's mood. The real tree is
/// `WinMuxSceneEngineAdapterTest`.
@MainActor
final class SceneProjectorTest: XCTestCase {
    private typealias App = SceneCoreFixtures.App

    private let substrate = SceneCore.SubstrateBinding(workspaceName: "3")

    func testAProjectionOffersTheOccupiedSlotsInSlotOrderAfterPreparingTheSubstrate() throws {
        let port = RecordingSceneEnginePort()
        let plan = SceneCore.SceneLayoutPlan(try SceneCoreFixtures.debugScene(), on: substrate)

        let report = SceneCore.SceneProjector(port: port).project(plan)

        XCTAssertEqual(port.preparedSubstrates, [substrate])
        XCTAssertEqual(port.placedGroups.map(\.role), [.terminal, .editor, .preview, .observability, .communication])
        XCTAssertEqual(port.settledSubstrates, [substrate])
        XCTAssertTrue(report.isFullyRealised)
        XCTAssertEqual(report.diagnostics, [])
    }
}
