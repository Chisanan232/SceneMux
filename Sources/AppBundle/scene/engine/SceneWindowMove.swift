import Foundation

extension SceneCore {
    /// What became of one window the engine was asked to move to a surface.
    ///
    /// The counterpart of `SceneSlotPlacement` for a single window rather than a Slot, and the only thing the
    /// engine says about sending one home. Distinguishing the reasons matters because they lead to different
    /// sentences and different promises: a window that has gone was never owed anything, a surface that no
    /// longer exists means the window stays exactly where it is and the user is told, and a refusal by a busy
    /// application means the work is still owed and will be tried again.
    ///
    /// There is no "moved it somewhere else instead". A window whose destination cannot be found is left
    /// alone; the engine is never asked to improvise a place for it.
    enum SceneWindowMove: Equatable, Sendable, CustomStringConvertible {
        /// The window is on that surface now.
        case moved
        /// The engine cannot see the window at all — the app quit, or the user closed it. An ordinary runtime
        /// event, and nothing is owed to a window that is not there.
        case windowIsGone
        /// The window is there, the surface is not, and so nothing was done. The reason is a clause with no
        /// trailing full stop, because the sentence it lands in is composed where the user is told.
        case surfaceIsGone(reason: String)
        /// The engine tried and could not, in its own words. Worth attempting again.
        case failed(reason: String)

        var description: String {
            switch self {
                case .moved: "moved"
                case .windowIsGone: "the window is gone"
                case .surfaceIsGone(let reason): "the surface is gone: \(reason)"
                case .failed(let reason): "failed: \(reason)"
            }
        }
    }
}
