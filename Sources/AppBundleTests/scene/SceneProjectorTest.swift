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

    /// An unusable substrate stops the projection dead rather than letting it place the Scene's windows
    /// somewhere the Scene never asked for.
    func testAnUnusableSubstrateRefusesEverySlotAndPlacesNothing() throws {
        let port = RecordingSceneEnginePort()
        port.substrateIsUsable = false
        let scene = try SceneCoreFixtures.debugScene()

        let report = SceneCore.SceneProjector(port: port)
            .project(SceneCore.SceneLayoutPlan(scene, on: substrate))

        XCTAssertEqual(port.placedGroups, [])
        XCTAssertEqual(port.settledSubstrates, [])
        XCTAssertEqual(report.placements.count, scene.slots.count)
        XCTAssertEqual(report.diagnostics.count, 1)
        XCTAssertEqual(
            report.diagnostics.first,
            "SceneMux could not prepare workspace \"3\" for \"Debug PROD-123\", so it laid out nothing.",
        )
        XCTAssertFalse(report.isFullyRealised)
    }

    /// The engine gets the last word on shape, and the user gets told. Reporting the requested composition
    /// while the screen shows another one would make the report worthless.
    func testTheCompositionTheEngineSettledOnIsWhatGetsReported() throws {
        let port = RecordingSceneEnginePort()
        let comms = SceneCoreFixtures.slot(role: .communication, composition: .split(.horizontal), order: 0)
        let scene = try SceneCoreFixtures.scene(slots: [comms])
            .attaching(SceneCoreFixtures.attachment(windowRef: try .init(bundleId: App.line, ordinalWithinApp: 0),
                                                    slotId: comms.id))
            .attaching(SceneCoreFixtures.attachment(windowRef: try .init(bundleId: App.slack, ordinalWithinApp: 0),
                                                    slotId: comms.id))
        port.settledCompositions = [comms.id: .split(.vertical)]

        let report = SceneCore.SceneProjector(port: port)
            .project(SceneCore.SceneLayoutPlan(scene, on: substrate))

        XCTAssertEqual(report.placement(for: comms.id), .realised(.split(.vertical)))
        XCTAssertEqual(report.adjustedSlots, [comms.id])
        XCTAssertFalse(report.isFullyRealised)
        XCTAssertEqual(
            report.diagnostics,
            ["SceneMux composed the communication Slot of \"Debug PROD-123\" as a vertical split instead of "
                + "a horizontal split, because the window engine normalized it."],
        )
    }

    /// A quit window is an ordinary event, not a failed Scene: the rest of the layout still happens, and the
    /// missing one is named. The diagnostic blames the window rather than normalization, because that is what
    /// actually happened.
    func testAMissingWindowIsNamedWhileTheRestOfTheSlotIsStillPlaced() throws {
        let port = RecordingSceneEnginePort()
        let comms = SceneCoreFixtures.slot(role: .communication, composition: .tabbed, order: 0)
        let line = try SceneCore.WindowRef(bundleId: App.line, ordinalWithinApp: 0)
        let slack = try SceneCore.WindowRef(bundleId: App.slack, ordinalWithinApp: 0)
        let scene = try SceneCoreFixtures.scene(slots: [comms])
            .attaching(SceneCoreFixtures.attachment(windowRef: line, slotId: comms.id))
            .attaching(SceneCoreFixtures.attachment(windowRef: slack, slotId: comms.id))
        port.invisibleWindows = [slack]

        let report = SceneCore.SceneProjector(port: port)
            .project(SceneCore.SceneLayoutPlan(scene, on: substrate))

        XCTAssertEqual(report.placement(for: comms.id), .partlyRealised(.tabbed, missing: [slack]))
        XCTAssertEqual(report.missingWindows, [slack])
        XCTAssertEqual(
            report.diagnostics,
            ["SceneMux could not find com.tinyspeck.slackmacgap#0 for the communication Slot of "
                + "\"Debug PROD-123\", and composed what remained as a tab group."],
        )
    }

    /// A Slot whose windows have all gone is left empty and said so. Nothing is substituted into it, and the
    /// Slots that still have their windows are unaffected.
    func testASlotThatLostEveryWindowIsLeftEmptyAndTheOthersAreStillPlaced() throws {
        let port = RecordingSceneEnginePort()
        let editor = SceneCoreFixtures.slot(role: .editor, order: 0)
        let observability = SceneCoreFixtures.slot(role: .observability, order: 1)
        let grafana = try SceneCore.WindowRef(bundleId: App.grafana, ordinalWithinApp: 0)
        let scene = try SceneCoreFixtures.scene(slots: [editor, observability])
            .attaching(SceneCoreFixtures.attachment(windowRef: try .init(bundleId: App.ide, ordinalWithinApp: 0),
                                                    slotId: editor.id))
            .attaching(SceneCoreFixtures.attachment(windowRef: grafana, slotId: observability.id))
        port.invisibleWindows = [grafana]

        let report = SceneCore.SceneProjector(port: port)
            .project(SceneCore.SceneLayoutPlan(scene, on: substrate))

        XCTAssertEqual(report.placement(for: observability.id), .windowsMissing([grafana]))
        XCTAssertEqual(report.placement(for: editor.id), .realised(.single))
        XCTAssertEqual(
            report.diagnostics,
            ["SceneMux found none of the windows for the observability Slot of \"Debug PROD-123\" "
                + "(com.grafana.grafana#0), and left it empty."],
        )
    }

}
