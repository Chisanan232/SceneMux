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

    /// Invariant I13, at the seam: the empty Slot is in the report, so a shell can draw it, and was never
    /// offered to the engine, so it cannot take a place in the tiling.
    func testAnEmptySlotIsReportedEmptyAndNeverOfferedToTheEngine() throws {
        let port = RecordingSceneEnginePort()
        let editor = SceneCoreFixtures.slot(role: .editor, order: 0)
        let empty = SceneCoreFixtures.slot(role: .observability, order: 1)
        let scene = try SceneCoreFixtures.scene(slots: [editor, empty])
            .attaching(SceneCoreFixtures.attachment(windowRef: try .init(bundleId: App.ide, ordinalWithinApp: 0),
                                                    slotId: editor.id))

        let report = SceneCore.SceneProjector(port: port)
            .project(SceneCore.SceneLayoutPlan(scene, on: substrate))

        XCTAssertEqual(port.placedGroups.map(\.slotId), [editor.id])
        XCTAssertEqual(report.placement(for: empty.id), .empty)
        XCTAssertTrue(report.isFullyRealised)
        XCTAssertEqual(report.diagnostics, [])
    }
}
