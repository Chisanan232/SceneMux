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
}
