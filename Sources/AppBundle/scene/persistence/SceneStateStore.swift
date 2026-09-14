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

        /// Write these Scenes, replacing whatever was there.
        ///
        /// `.atomic` is the whole point: it writes a temporary file and renames it into place, so a crash or a
        /// full disk part-way through leaves the previous state file intact rather than half a new one. Half a
        /// state file is the input that invariant I9 exists for, and not producing it is cheaper than
        /// surviving it.
        func save(_ scenes: [Scene]) throws {
            let data = try SceneStateFormat.encoded(scenes)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true,
            )
            try data.write(to: url, options: .atomic)
        }

        /// Read what is there, as an outcome. Never throws, and never guesses.
        ///
        /// A missing file and a file this build cannot read are different answers, and the difference is the
        /// one that matters: the first is a first run, the second is something the user has to be told about.
        /// Collapsing them — a `try?` that yields "no Scenes" either way — is how state gets silently
        /// replaced by an empty file on the next save.
        func load() -> SceneStateLoad {
            guard FileManager.default.fileExists(atPath: url.path) else {
                return .noStateFile(path: url.path)
            }
            guard let data = try? Data(contentsOf: url) else {
                let refusal = SceneStateRefusal(reason: .unreadable, path: url.path, preservedAt: nil)
                return .refused(preserving(refusal))
            }
            let outcome = SceneStateFormat.read(data, from: url.path)
            guard case .refused(let refusal) = outcome else { return outcome }
            return .refused(preserving(refusal))
        }

        /// Copy a refused file aside, and say so in the refusal when the copy worked.
        ///
        /// A copy and not a move: the original stays exactly where the user expects to find it, so a newer
        /// SceneMux that wrote a version this build cannot read still finds its own file when it next runs.
        /// The copy exists for the other direction — the next `save` overwrites the original, and without it
        /// that save would be the moment the state stopped existing. Recovering from a bad upgrade is then
        /// still possible from the copy, which is the difference between an inconvenience and a loss.
        ///
        /// An existing copy is **never** overwritten. A second refusal, of different bytes, means the first
        /// copy is the older state — and it is state SceneMux already promised a user it had kept. Breaking
        /// that promise is a loss; declining to make a second one is not, because the file being refused now
        /// is still sitting untouched at its own path. So the newer refusal simply makes no claim.
        ///
        /// Best effort by design. If it fails there is nothing useful to do about it and nothing to hide: the
        /// refusal is returned without a preservation claim rather than with a false one.
        private func preserving(_ refusal: SceneStateRefusal) -> SceneStateRefusal {
            let destination = url
                .deletingLastPathComponent()
                .appendingPathComponent(Self.preservedFilename, isDirectory: false)
            do {
                let refused = try Data(contentsOf: url)
                if let kept = try? Data(contentsOf: destination) {
                    // Relaunching with the same bad file is the ordinary case, and it is already preserved.
                    return kept == refused ? refusal.preserved(at: destination.path) : refusal
                }
                try refused.write(to: destination, options: .atomic)
            } catch {
                return refusal
            }
            return refusal.preserved(at: destination.path)
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
