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

    /// A split Slot is built the way `join-with` builds one — a nested container the windows are bound into —
    /// because `split` is a no-op on this engine while flatten-containers normalization is on, as
    /// `docs/development/baseline-verification.md` measured. Flattening is left on here for the same reason:
    /// a shape that only holds while normalization is disabled is not a shape SceneMux can promise.
    func testASplitSlotBuildsAContainerThatSurvivesNormalization() throws {
        config.enableNormalizationFlattenContainers = true
        let ide = TestApp(bundleId: App.ide)
        let terminal = TestApp(bundleId: App.terminal)
        TestWindow.new(id: 1, parent: elsewhere, app: ide)
        TestWindow.new(id: 2, parent: elsewhere, app: terminal)
        TestWindow.new(id: 3, parent: elsewhere, app: terminal)
        let editor = SceneCoreFixtures.slot(role: .editor, order: 0)
        let terminals = SceneCoreFixtures.slot(role: .terminal, composition: .split(.vertical), order: 1)
        let scene = try SceneCoreFixtures.scene(slots: [editor, terminals])
            .attaching(SceneCoreFixtures.attachment(
                windowRef: try .init(bundleId: App.ide, ordinalWithinApp: 0),
                slotId: editor.id,
            ))
            .attaching(SceneCoreFixtures.attachment(
                windowRef: try .init(bundleId: App.terminal, ordinalWithinApp: 0),
                slotId: terminals.id,
            ))
            .attaching(SceneCoreFixtures.attachment(
                windowRef: try .init(bundleId: App.terminal, ordinalWithinApp: 1),
                slotId: terminals.id,
            ))

        let report = project(scene, onto: name)

        XCTAssertEqual(
            Workspace.get(byName: name).rootTilingContainer.layoutDescription,
            .h_tiles([
                .window(1),
                .v_tiles([
                    .window(2),
                    .window(3),
                ]),
            ]),
        )
        XCTAssertEqual(report.placement(for: terminals.id), .realised(.split(.vertical)))
        XCTAssertTrue(report.isFullyRealised)
    }

    /// The communication Slot of the golden journey: LINE and Slack in one tab group, so that lending two chat
    /// windows to a Scene costs one slice of screen rather than two.
    func testATabbedSlotBuildsATabGroup() throws {
        config.enableNormalizationFlattenContainers = true
        let ide = TestApp(bundleId: App.ide)
        let line = TestApp(bundleId: App.line)
        let slack = TestApp(bundleId: App.slack)
        TestWindow.new(id: 1, parent: elsewhere, app: ide)
        TestWindow.new(id: 2, parent: elsewhere, app: line)
        TestWindow.new(id: 3, parent: elsewhere, app: slack)
        let editor = SceneCoreFixtures.slot(role: .editor, order: 0)
        let comms = SceneCoreFixtures.slot(role: .communication, composition: .tabbed, order: 1)
        let scene = try SceneCoreFixtures.scene(slots: [editor, comms])
            .attaching(SceneCoreFixtures.attachment(
                windowRef: try .init(bundleId: App.ide, ordinalWithinApp: 0),
                slotId: editor.id,
            ))
            .attaching(SceneCoreFixtures.attachment(
                windowRef: try .init(bundleId: App.line, ordinalWithinApp: 0),
                slotId: comms.id,
                ownership: .borrowed,
                homeAtAttachTime: .communication,
            ))
            .attaching(SceneCoreFixtures.attachment(
                windowRef: try .init(bundleId: App.slack, ordinalWithinApp: 0),
                slotId: comms.id,
                ownership: .borrowed,
                homeAtAttachTime: .communication,
            ))

        let report = project(scene, onto: name)

        XCTAssertEqual(
            Workspace.get(byName: name).rootTilingContainer.layoutDescription,
            .h_tiles([
                .window(1),
                .v_tab_group([
                    .window(2),
                    .window(3),
                ]),
            ]),
        )
        XCTAssertEqual(report.placement(for: comms.id), .realised(.tabbed))
        XCTAssertTrue(report.isFullyRealised)
    }

    /// Invariant I15: a projection touches the Scene's own windows and no others. The music player was already
    /// on this workspace and is not in the Scene, so it keeps its place and its parent — the Scene arrives
    /// after it instead of shouldering it aside.
    func testWindowsTheSceneDoesNotOwnAreLeftWhereTheyAre() throws {
        config.enableNormalizationFlattenContainers = true
        let music = TestApp(bundleId: App.music)
        let ide = TestApp(bundleId: App.ide)
        let root = Workspace.get(byName: name).rootTilingContainer
        let stranger = TestWindow.new(id: 99, parent: root, app: music)
        TestWindow.new(id: 1, parent: elsewhere, app: ide)
        let editor = SceneCoreFixtures.slot(role: .editor, order: 0)
        let scene = try SceneCoreFixtures.scene(slots: [editor])
            .attaching(SceneCoreFixtures.attachment(
                windowRef: try .init(bundleId: App.ide, ordinalWithinApp: 0),
                slotId: editor.id,
            ))

        _ = project(scene, onto: name)

        XCTAssertEqual(
            Workspace.get(byName: name).rootTilingContainer.layoutDescription,
            .h_tiles([.window(99), .window(1)]),
        )
        XCTAssertTrue(stranger.parent === Workspace.get(byName: name).rootTilingContainer)
    }
}
