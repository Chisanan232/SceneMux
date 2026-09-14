@testable import AppBundle
import Common
import XCTest

/// The seam against the real inherited tree: Slots in, containers and windows out.
///
/// These tests use the engine itself rather than a fake, because the interesting claims are all about what
/// the engine does with what the adapter builds — whether a container survives normalization, what a tab
/// group looks like once it exists, where a window actually ends up. A fake would agree with whatever the
/// adapter believed, which is the one thing worth doubting.
@MainActor
final class WinMuxSceneEngineAdapterTest: XCTestCase {
    private typealias App = SceneCoreFixtures.App

    override func setUp() async throws { setUpWorkspacesForTests() }

    /// Somewhere for windows to already be, so that a projection is a move rather than a creation.
    private var elsewhere: TilingContainer { Workspace.get(byName: "elsewhere").rootTilingContainer }

    private func project(_ scene: SceneCore.Scene, onto workspaceName: String) -> SceneCore.SceneLayoutReport {
        let plan = SceneCore.SceneLayoutPlan(
            scene,
            on: SceneCore.SubstrateBinding(workspaceName: workspaceName),
        )
        return SceneCore.SceneProjector(port: SceneCore.WinMuxSceneEngineAdapter()).project(plan)
    }

    /// A Slot holding one window is that window, not a container holding it. `normalizeContainers` flattens a
    /// container down to its only child, so anything else would be undone by the engine moments later.
    func testASingleWindowSlotBindsStraightIntoTheSubstrate() throws {
        config.enableNormalizationFlattenContainers = true
        let ide = TestApp(bundleId: App.ide)
        TestWindow.new(id: 1, parent: elsewhere, app: ide)
        let editor = SceneCoreFixtures.slot(role: .editor, order: 0)
        let scene = try SceneCoreFixtures.scene(slots: [editor])
            .attaching(SceneCoreFixtures.attachment(
                windowRef: try .init(bundleId: App.ide, ordinalWithinApp: 0),
                slotId: editor.id,
            ))

        let report = project(scene, onto: name)

        XCTAssertEqual(Workspace.get(byName: name).rootTilingContainer.layoutDescription, .h_tiles([.window(1)]))
        XCTAssertEqual(report.placement(for: editor.id), .realised(.single))
        XCTAssertTrue(report.isFullyRealised)
    }
}
