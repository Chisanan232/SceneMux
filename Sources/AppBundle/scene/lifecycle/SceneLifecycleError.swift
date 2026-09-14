import Foundation

extension SceneCore {
    /// A lifecycle operation someone asked for that the set of Scenes cannot allow.
    ///
    /// Separate from `SceneCoreError`, which is about one Scene making sense on its own. These are the rules
    /// that only exist *between* Scenes — two Scenes cannot share an identity, and in v0.1.0 only one Scene
    /// is on screen at a time. A caller that catches one of these has asked for something coherent about a
    /// world that is not in the right shape for it, which is a different conversation from a Scene that
    /// could not be built at all.
    ///
    /// Illegal state changes are deliberately *not* here: `SceneState.canTransition(to:)` already owns the
    /// transition table, and duplicating it would give two answers to "may this Scene close?".
    enum SceneLifecycleError: Error, Equatable, Sendable, CustomStringConvertible {
        /// Two Scenes with one identity. Nothing could then say which of them a window is attached to.
        case duplicateSceneId(SceneId)
        /// An operation named a Scene the world does not have — usually one already forgotten by a restart.
        case unknownScene(SceneId)
        /// v0.1.0 projects one Scene at a time, and this one is the Scene that is already on screen.
        case anotherSceneIsActive(SceneId)
        /// State that says two Scenes are on screen at once. A file this build will not act on, not a
        /// request it can refuse politely.
        case moreThanOneActiveScene

        var description: String {
            switch self {
                case .duplicateSceneId(let id): "two Scenes claim the same identity (\(id))"
                case .unknownScene(let id): "there is no Scene \(id)"
                case .anotherSceneIsActive(let id): "another Scene is already active (\(id))"
                case .moreThanOneActiveScene: "more than one Scene is active"
            }
        }
    }
}
