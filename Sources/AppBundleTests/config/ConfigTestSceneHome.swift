@testable import AppBundle
import Common
import XCTest

extension ConfigTest {
    /// The user's half of the Home rule table, read from the file they hand-edit and keep in version control.
    func testParseSceneHome() {
        let (parsed, errors) = parseConfig(
            """
            [scene-home]
                'com.google.Chrome' = 'development'
                'com.apple.Music' = 'personal'
                'com.grafana.grafana' = 'observability'
                'com.tinyspeck.slackmacgap' = 'communication'
            """,
        )
        assertEquals(errors, [])
        assertEquals(parsed.sceneHome, [
            "com.google.Chrome": .development,
            "com.apple.Music": .personal,
            "com.grafana.grafana": .observability,
            "com.tinyspeck.slackmacgap": .communication,
        ])
    }

    /// A fifth Home is an error on the line that typed it, and the other lines still apply. One typo in a
    /// twenty-application table must not silently return every window to the shipped defaults.
    func testParseSceneHomeRejectsOneLineAndKeepsTheRest() {
        let (parsed, errors) = parseConfig(
            """
            [scene-home]
                'com.apple.Terminal' = 'development'
                'com.apple.Music' = 'entertainment'
            """,
        )
        assertEquals(errors.count, 1)
        XCTAssertTrue(
            errors.first?.description.contains("(development|communication|observability|personal)") == true,
            "the four Homes are listed back at the user: \(errors)",
        )
        assertEquals(parsed.sceneHome, ["com.apple.Terminal": .development])
    }
}
