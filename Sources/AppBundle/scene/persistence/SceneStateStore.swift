import Common
import Foundation

extension SceneCore {
    /// Where Scene state lives on disk, and the only thing in Scene Core that touches a file.
    ///
    /// The location is injected rather than looked up, so every test runs against its own temporary
    /// directory and no test can read — or overwrite — the state of the person running it.
    ///
    /// Scene state deliberately does **not** go in `~/.config/scenemux/scenemux.toml`. That file is a
    /// document someone writes by hand and keeps in version control; this one changes every time a window is
    /// attached, and a bug in a writer that runs that often must not be aimed at hand-written configuration.
    struct SceneStateStore: Sendable {
        /// The state file's name, beside the inherited `window-state.json` in the same directory.
        static let filename = "scene-state.json"
        /// Where a refused file is copied so that the next save cannot be the thing that loses it.
        static let preservedFilename = "scene-state.unreadable.json"

        let url: URL

        init(url: URL) {
            self.url = url
        }

        /// The real location: `~/Library/Application Support/SceneMux/scene-state.json`.
        ///
        /// The directory is `sceneMuxAppName`, which is `SceneMux-Debug` in a debug build — so developing
        /// SceneMux cannot corrupt the Scenes of the SceneMux someone is using to develop it.
        static func inApplicationSupport() throws -> SceneStateStore {
            let appSupport = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true,
            )
            let directory = appSupport.appendingPathComponent(sceneMuxAppName, isDirectory: true)
            return SceneStateStore(url: directory.appendingPathComponent(filename, isDirectory: false))
        }
    }
}
