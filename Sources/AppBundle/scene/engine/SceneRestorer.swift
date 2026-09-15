import Foundation

extension SceneCore {
    /// Carries out one teardown step: sends one window back where it came from, and says what happened.
    ///
    /// The other half of the projector. A projection puts windows into a Scene; this takes one out again, and
    /// it is deliberately the *only* thing in SceneMux that acts on a teardown step. What it may do is decided
    /// entirely by the step — which was decided by the ownership the user recorded when they attached the
    /// window — so there is no path from "a Scene ended" to "a window moved" that skips that permission.
    ///
    /// It closes nothing. Not on any answer from the engine, not for a scene-owned window, not for a window
    /// whose destination has vanished: invariant I6. The worst thing that can happen to a window here is that
    /// it stays exactly where it is and the user is told.
    @MainActor
    struct SceneRestorer {
        private let port: SceneEnginePort

        init(port: SceneEnginePort) {
            self.port = port
        }

        /// Do what this step says, and report the outcome the orchestrator should record.
        ///
        /// Two things are refused before the engine is asked at all. A step SceneMux was never permitted to
        /// move is not moved — the ownership said `leaveInPlace` or `untouched`, and this is the last place
        /// that could get that wrong. A step with no recorded surface has nowhere to aim, and a restore with
        /// nowhere to aim does not become a guess: the window stays, the Scene finishes, and the person is
        /// told which window stayed and why.
        ///
        /// Every other answer is the engine's, translated rather than interpreted. The one distinction that
        /// carries weight is `failed`, which leaves the attachment in place so the restore is still owed and
        /// gets tried again — after the app stops being busy, or after the next launch.
        func restore(_ step: SceneTeardownStep) -> SceneTeardownOutcome {
            guard step.needsWork else {
                return .leftInPlace(reason: "the Scene was not allowed to move it")
            }
            guard let surface = step.homeSurface else {
                return .leftInPlace(reason: "SceneMux has no record of where it came from")
            }
            return switch port.move(step.windowRef, to: surface) {
                case .moved: .restored
                case .windowIsGone: .windowIsGone
                case .surfaceIsGone(let reason): .leftInPlace(reason: reason)
                case .failed(let reason): .failed(reason: reason)
            }
        }
    }
}
