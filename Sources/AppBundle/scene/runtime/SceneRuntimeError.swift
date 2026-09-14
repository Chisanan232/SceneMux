import Foundation

extension SceneCore {
    /// Why a Scene action the user asked for could not be carried out, in words that can be shown as they are.
    ///
    /// Separate from `SceneLifecycleError` and `SceneCoreError` because these are failures of the *request*
    /// rather than of the model: a number that names no Scene, a keystroke that needs an active Scene when
    /// there is none, a desktop with nothing to draw on. None of them is a bug and all of them are things a
    /// person can act on, which is why each one carries its own sentence rather than being logged as an
    /// unexpected condition.
    enum SceneRuntimeError: Error, Equatable, CustomStringConvertible {
        /// Scene state could not be reached at all, so this build will not pretend to have Scenes.
        case scenesUnavailable(String)
        /// There is nothing to project a Scene onto — no usable workspace to draw on right now.
        case noSubstrate
        /// The action needs the Scene that is on screen, and no Scene is.
        case noActiveScene
        /// A Scene number that does not name a Scene. Nine keys, and the user may have four Scenes.
        case noSceneNumbered(Int)
        /// A Slot number that does not name a Slot of the active Scene.
        case noSlotNumbered(Int)

        var description: String {
            switch self {
                case .scenesUnavailable(let reason): reason
                case .noSubstrate: "There is nowhere to put a Scene right now, so nothing was changed."
                case .noActiveScene: "No Scene is on screen, so there was nothing to do."
                case .noSceneNumbered(let index): "There is no Scene \(index)."
                case .noSlotNumbered(let index): "The Scene on screen has no Slot \(index)."
            }
        }
    }
}
