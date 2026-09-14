@testable import AppBundle
import Foundation
import XCTest

final class SceneShellMessageTest: XCTestCase {
    /// Entering a Scene confirms which task owns the screen and how big it is, and says it once. Singulars are
    /// spelled correctly because this line is read every time someone switches tasks.
    func testEnteringASceneSaysWhichSceneAndHowBigItIs() {
        XCTAssertEqual(
            SceneCore.SceneShellMessage.entered(sceneTitle: "Debug PROD-123", slots: 4, windows: 6).text,
            "Debug PROD-123 · 4 slots, 6 windows",
        )
        XCTAssertEqual(
            SceneCore.SceneShellMessage.entered(sceneTitle: "Release notes", slots: 1, windows: 1).text,
            "Release notes · 1 slot, 1 window",
        )
    }
}
