@testable import AppBundle
import AppKit
import XCTest

@MainActor
final class DoubleSidedWindowsTest: XCTestCase {
    func testPairReturnsToTabsWhenThirdWindowJoins() {
        setUpWorkspacesForTests()
        let saved = UserDefaults.standard.object(forKey: "doubleSidedWindows")
        defer { UserDefaults.standard.set(saved, forKey: "doubleSidedWindows") }
        var settings = ExperimentalUISettings()
        settings.doubleSidedWindows = true
        config.windowTabs.enabled = true
        let group = Workspace.get(byName: "pair").rootTilingContainer
        group.layout = .tabGroup
        _ = TestWindow.new(id: 1, parent: group)
        _ = TestWindow.new(id: 2, parent: group)
        XCTAssertTrue(group.usesDoubleSidedWindows)
        XCTAssertTrue(group.usesWindowTabBehavior)
        XCTAssertFalse(group.showsWindowTabs)
        XCTAssertEqual(group.windowTabBarHeight, 0)
        XCTAssertNil(group.windowTabGroupFrameRect)

        let third = TestWindow.new(id: 3, parent: group)
        XCTAssertFalse(group.usesDoubleSidedWindows)
        XCTAssertTrue(group.showsWindowTabs)
        third.unbindFromParent()
        XCTAssertTrue(group.usesDoubleSidedWindows)

        settings.doubleSidedWindows = false
        XCTAssertFalse(group.usesDoubleSidedWindows)
        XCTAssertTrue(group.showsWindowTabs)
        XCTAssertEqual(group.children.count, 2)
    }

    func testDefaultAndFullscreenKeepExistingBehavior() {
        setUpWorkspacesForTests()
        let saved = UserDefaults.standard.object(forKey: "doubleSidedWindows")
        defer { UserDefaults.standard.set(saved, forKey: "doubleSidedWindows") }
        UserDefaults.standard.removeObject(forKey: "doubleSidedWindows")
        XCTAssertFalse(ExperimentalUISettings().doubleSidedWindows)
        config.windowTabs.enabled = true
        let group = Workspace.get(byName: "pair").rootTilingContainer
        group.layout = .tabGroup
        let front = TestWindow.new(id: 1, parent: group)
        _ = TestWindow.new(id: 2, parent: group)
        XCTAssertTrue(group.showsWindowTabs)
        var settings = ExperimentalUISettings()
        settings.doubleSidedWindows = true
        front.isFullscreen = true
        XCTAssertFalse(group.usesDoubleSidedWindows)
        XCTAssertFalse(group.showsWindowTabs)
        front.isFullscreen = false
        config.windowTabs.enabled = false
        XCTAssertFalse(group.usesDoubleSidedWindows)
    }
}
