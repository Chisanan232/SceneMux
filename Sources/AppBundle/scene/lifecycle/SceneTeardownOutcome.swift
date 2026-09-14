import Foundation

extension SceneCore {
    /// What actually happened to one window when a teardown step was carried out.
    ///
    /// Reported back rather than assumed, because every one of these is an ordinary Tuesday: restoring a
    /// borrowed window is Accessibility work against somebody else's process, and it can succeed, find the
    /// window already gone, find nowhere to put it, or simply fail because the app is busy.
    ///
    /// The cases differ in exactly one way that matters — whether the promise is finished. `restored`,
    /// `windowIsGone` and `leftInPlace` are finished, so the attachment is dropped and the Scene moves on.
    /// `failed` is not, so the attachment stays and the restore is re-attempted, including after a restart.
    /// That is what makes teardown re-entrant without a retry counter to get wrong.
    enum SceneTeardownOutcome: Equatable, Sendable {
        /// The window is back on its Home surface. Done, once, per invariant I8.
        case restored
        /// There is no such window any more — its app quit, or the user closed it. A normal runtime event,
        /// not corruption, and nothing to report to anyone.
        case windowIsGone
        /// The window is still there and was deliberately left where it is, for a reason worth saying out
        /// loud: its Home surface could not be resolved, or the user declined the move.
        ///
        /// The explicit fallback. A window whose Home no longer exists must not be moved somewhere invented
        /// for it, and must not hold its Scene open forever either — so it stays put, the Scene finishes, and
        /// the person is told which window stayed and why.
        case leftInPlace(reason: String)
        /// The attempt failed and is worth trying again — a busy app, a timeout, a sleeping machine.
        case failed(reason: String)

        /// Whether this outcome finishes the promise the attachment represented.
        var isFinal: Bool {
            switch self {
                case .restored, .windowIsGone, .leftInPlace: true
                case .failed: false
            }
        }
    }
}
