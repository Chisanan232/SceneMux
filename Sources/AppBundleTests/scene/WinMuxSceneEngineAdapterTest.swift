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

    /// One window per application of `SceneCoreFixtures.debugScene()`, in the order the Scene attaches them,
    /// so that window id `n` is the `n`th window the golden journey mentions.
    @discardableResult
    private func makeGoldenJourneyWindows() -> [TestWindow] {
        [App.terminal, App.ide, App.browser, App.grafana, App.line, App.slack].enumerated().map { id, bundleId in
            TestWindow.new(id: UInt32(id + 1), parent: elsewhere, app: TestApp(bundleId: bundleId))
        }
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

    /// The application quit, or the window is on another Space where the Accessibility API cannot see it. The
    /// Slot is built out of what is there, the rest of the Scene is unaffected, and the absence is named.
    func testAWindowThatIsNotThereIsReportedAndTheRestOfTheSlotIsBuilt() throws {
        config.enableNormalizationFlattenContainers = true
        let terminal = TestApp(bundleId: App.terminal)
        TestWindow.new(id: 1, parent: elsewhere, app: terminal)
        let terminals = SceneCoreFixtures.slot(role: .terminal, composition: .split(.vertical), order: 0)
        let observability = SceneCoreFixtures.slot(role: .observability, order: 1)
        let secondTerminal = try SceneCore.WindowRef(bundleId: App.terminal, ordinalWithinApp: 1)
        let grafana = try SceneCore.WindowRef(bundleId: App.grafana, ordinalWithinApp: 0)
        let scene = try SceneCoreFixtures.scene(slots: [terminals, observability])
            .attaching(SceneCoreFixtures.attachment(
                windowRef: try .init(bundleId: App.terminal, ordinalWithinApp: 0),
                slotId: terminals.id,
            ))
            .attaching(SceneCoreFixtures.attachment(windowRef: secondTerminal, slotId: terminals.id))
            .attaching(SceneCoreFixtures.attachment(windowRef: grafana, slotId: observability.id))

        let report = project(scene, onto: name)

        XCTAssertEqual(Workspace.get(byName: name).rootTilingContainer.layoutDescription, .h_tiles([.window(1)]))
        XCTAssertEqual(
            report.placement(for: terminals.id),
            .partlyRealised(.single, missing: [secondTerminal]),
        )
        XCTAssertEqual(report.placement(for: observability.id), .windowsMissing([grafana]))
        XCTAssertEqual(report.missingWindows, [secondTerminal, grafana])
    }

    /// A blank workspace name is refused rather than registered. The engine would happily create a workspace
    /// called `" "`, and a Scene projected onto it would be somewhere the user can neither see nor name.
    func testABlankSubstrateNameIsRefusedAndNothingIsBuilt() throws {
        let ide = TestApp(bundleId: App.ide)
        TestWindow.new(id: 1, parent: elsewhere, app: ide)
        let editor = SceneCoreFixtures.slot(role: .editor, order: 0)
        let scene = try SceneCoreFixtures.scene(slots: [editor])
            .attaching(SceneCoreFixtures.attachment(
                windowRef: try .init(bundleId: App.ide, ordinalWithinApp: 0),
                slotId: editor.id,
            ))

        let report = project(scene, onto: "   ")

        XCTAssertEqual(report.placement(for: editor.id)?.composition, nil)
        XCTAssertFalse(report.isFullyRealised)
        XCTAssertEqual(Workspace.all.map(\.name).contains("   "), false)
        XCTAssertEqual(elsewhere.layoutDescription, .h_tiles([.window(1)]))
    }

    /// The user's own normalization gets the last word, and SceneMux says so instead of fighting it.
    ///
    /// `enableNormalizationOppositeOrientationForNestedContainers` is on by default in production, and it flips
    /// a nested container whose orientation matches its parent's. A horizontal split under a horizontal root
    /// therefore comes out vertical. Reprojecting to force it back would lose the same argument again on the
    /// next normalization pass, so the honest outcome is a report the user can act on — by changing their
    /// configuration, or by asking for the other orientation.
    func testNormalizationFlippingASplitIsReportedRatherThanFought() throws {
        config.enableNormalizationFlattenContainers = true
        config.enableNormalizationOppositeOrientationForNestedContainers = true
        let ide = TestApp(bundleId: App.ide)
        let terminal = TestApp(bundleId: App.terminal)
        TestWindow.new(id: 1, parent: elsewhere, app: ide)
        TestWindow.new(id: 2, parent: elsewhere, app: terminal)
        TestWindow.new(id: 3, parent: elsewhere, app: terminal)
        let editor = SceneCoreFixtures.slot(role: .editor, order: 0)
        let terminals = SceneCoreFixtures.slot(role: .terminal, composition: .split(.horizontal), order: 1)
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

        XCTAssertEqual(report.placement(for: terminals.id), .realised(.split(.vertical)))
        XCTAssertEqual(report.adjustedSlots, [terminals.id])
        XCTAssertEqual(
            report.diagnostics,
            ["SceneMux composed the terminal Slot of \"Debug PROD-123\" as a vertical split instead of "
                + "a horizontal split, because the window engine normalized it."],
        )
    }

    /// The golden journey of `docs/design/scene-core-ux.md`, laid out for real: five Slots, six windows, and
    /// actual rectangles on an actual monitor.
    ///
    /// This is the test that would catch a Slot mapping that type-checks and reports success while putting
    /// nothing anywhere. It asks the engine for the geometry it really applied — the four solo Slots side by
    /// side across one band of the screen, the two lent chat windows sharing the fifth place as tabs — and
    /// deliberately asserts relations rather than pixel counts, because the numbers belong to whichever
    /// monitor is running the test.
    func testTheGoldenJourneyIsLaidOutAcrossTheSubstrate() async throws {
        config.enableNormalizationFlattenContainers = true
        // So that "side by side" is a matter of touching edges rather than of the inner gap's arithmetic.
        config.gaps = .zero
        makeGoldenJourneyWindows()
        let workspace = focus.workspace

        let report = project(try SceneCoreFixtures.debugScene(), onto: workspace.name)
        try await workspace.layoutWorkspace()

        XCTAssertTrue(report.isFullyRealised, report.diagnostics.joined(separator: " "))
        XCTAssertEqual(
            workspace.rootTilingContainer.layoutDescription,
            .h_tiles([
                .window(1),
                .window(2),
                .window(3),
                .window(4),
                .v_tab_group([
                    .window(5),
                    .window(6),
                ]),
            ]),
        )

        let solo = (1 ... 4).map { Window.get(byId: UInt32($0)).orDie().lastAppliedLayoutPhysicalRect.orDie() }
        XCTAssertEqual(solo.map(\.minX), solo.map(\.minX).sorted())
        XCTAssertEqual(Set(solo.map(\.minY)).count, 1)
        XCTAssertEqual(Set(solo.map(\.height)).count, 1)
        XCTAssertEqual(Set(solo.map(\.width)).count, 1)

        let tabs = workspace.rootTilingContainer.children.last as? TilingContainer
        let tabsRect = tabs?.lastAppliedLayoutPhysicalRect.orDie()
        XCTAssertEqual(tabsRect?.minX, solo[3].maxX)
        XCTAssertEqual(tabsRect?.minY, solo[3].minY)
    }

    /// A Scene laid out on a laptop screen is still that Scene on an ultrawide, because nothing SceneMux
    /// stores is a rectangle. A Slot is an order and a composition; the engine recomputes every frame from
    /// whichever monitor it finds. So a display change is a relayout, not a repair — and this is the test
    /// that would catch an adapter that had cached geometry somewhere to save itself work.
    func testTheLayoutIntentSurvivesADisplayChange() async throws {
        config.enableNormalizationFlattenContainers = true
        config.gaps = .zero
        makeGoldenJourneyWindows()
        let workspace = focus.workspace
        show(workspace, onDisplayOfWidth: 1920)

        _ = project(try SceneCoreFixtures.debugScene(), onto: workspace.name)
        try await workspace.layoutWorkspace()
        let laidOut = workspace.rootTilingContainer.layoutDescription
        let onTheLaptop = (1 ... 4).map { rect(ofWindowId: UInt32($0)) }

        show(workspace, onDisplayOfWidth: 3440)
        try await workspace.layoutWorkspace()

        XCTAssertEqual(workspace.rootTilingContainer.layoutDescription, laidOut)
        let onTheUltrawide = (1 ... 4).map { rect(ofWindowId: UInt32($0)) }
        for (narrow, wide) in zip(onTheLaptop, onTheUltrawide) {
            XCTAssertGreaterThan(wide.width, narrow.width)
        }
        let tabs = workspace.rootTilingContainer.children.last as? TilingContainer
        XCTAssertEqual(tabs?.lastAppliedLayoutPhysicalRect.orDie().maxX, 3440)
    }

    private func rect(ofWindowId id: UInt32) -> Rect {
        Window.get(byId: id).orDie().lastAppliedLayoutPhysicalRect.orDie()
    }

    /// The same display, resized. Keeping the monitor's id means the workspace stays on the monitor it was
    /// already on, so what changes between the two halves of the test is the geometry and nothing else.
    private func show(_ workspace: Workspace, onDisplayOfWidth width: CGFloat) {
        let rect = Rect(topLeftX: 0, topLeftY: 0, width: width, height: 1080)
        let display = TestMonitor(
            monitorAppKitNsScreenScreensId: 1,
            name: "Display",
            rect: rect,
            visibleRect: rect,
            isMain: true,
        )
        setMonitorsForTests([display])
        XCTAssertTrue(display.setActiveWorkspace(workspace))
        Workspace.reconcileWorkspaceState()
    }
}
