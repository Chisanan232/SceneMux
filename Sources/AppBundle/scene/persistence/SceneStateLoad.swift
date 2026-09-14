import Foundation

extension SceneCore {
    /// Everything that can come back from reading Scene state, as one value.
    ///
    /// Reading state has three honest outcomes and this type has exactly three cases, so a caller cannot
    /// write the bug that matters here: treating "I could not read your Scenes" as "you have no Scenes" and
    /// then saving an empty file over someone's state. First run and refusal look nothing alike.
    ///
    /// No case carries an error to be thrown at a caller. A loader that throws invites a `try?`, and a `try?`
    /// on this path is exactly invariant I9's failure mode — silent, with the diagnostic dropped on the way
    /// past.
    enum SceneStateLoad: Equatable, Sendable {
        /// There is no state file. A first run, or someone deleted it. Zero Scenes, nothing to report.
        case noStateFile(path: String)
        /// The file exists and this build declined it as a whole. Zero Scenes, and one thing to report.
        case refused(SceneStateRefusal)
        /// The file was read. Any attachments that could not be honoured are listed rather than dropped
        /// silently, and the Scenes are usable.
        case loaded(scenes: [Scene], quarantined: [SceneStateQuarantine])

        /// The Scenes to start with — empty for both of the outcomes that are not a successful read.
        var scenes: [Scene] {
            switch self {
                case .noStateFile, .refused: []
                case .loaded(let scenes, _): scenes
            }
        }

        /// Every line the UI is required to show the user, in the order they happened. Empty on a clean read.
        var diagnostics: [String] {
            switch self {
                case .noStateFile: []
                case .refused(let refusal): [refusal.diagnostic]
                case .loaded(_, let quarantined): quarantined.map(\.diagnostic)
            }
        }
    }
}
