import Foundation

extension SceneCore {
    /// Everything ending a Scene is allowed to do to one attached window.
    ///
    /// The whole list. There is deliberately **no** `close` case, and that absence is the mechanism rather
    /// than a coincidence: invariant I6 says no lifecycle transition closes a window, and the cheapest way
    /// to guarantee it is to make an automatic close *unrepresentable*. Cleanup of `.sceneOwned` windows is
    /// a separate, explicitly confirmed, per-window user action — it is not a teardown effect, so no bug in
    /// teardown can reach it.
    ///
    /// The three cases are the "On Scene end" column of the ownership table in
    /// `docs/design/scene-core-architecture.md`, in the same order.
    enum SceneTeardownEffect: String, Codable, Sendable, Hashable, CaseIterable, CustomStringConvertible {
        /// Put the window back on its Semantic Home surface. Runs exactly once per attachment (I8).
        case restoreToHome
        /// Leave the window exactly where it is; the Scene offers cleanup, and the user decides.
        case leaveInPlace
        /// Do not move, resize, focus or even read it (I7).
        case untouched

        var description: String { rawValue }
    }
}
