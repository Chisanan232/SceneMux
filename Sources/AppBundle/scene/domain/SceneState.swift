import Foundation

extension SceneCore {
    /// Where a Scene is in its life: defined, active, ending or ended.
    ///
    /// The substrate binding is the *payload of* `.active` rather than a sibling field, so that "an active
    /// Scene has exactly one substrate, and no other state has one" — invariant I3 — cannot be written
    /// wrongly. A `defined` Scene with a stale workspace binding, the bug that invariant exists to catch,
    /// does not compile.
    ///
    /// `ending` is a state and not a function call for a reason worth keeping in mind here: restoring
    /// borrowed windows is asynchronous work against other applications, and any of it can fail or be
    /// interrupted by a quit. Persisting the *intent* to restore is what makes it survive a restart.
    enum SceneState: Sendable, Hashable, Codable {
        /// The Scene exists and holds its layout intent, but is not on screen. Attachments are kept.
        case defined
        /// Projected onto exactly one rendering substrate.
        case active(SubstrateBinding)
        /// Closing: every attachment is being resolved by its ownership. Re-entrant across restarts.
        case ending
        /// Closed. Kept in state as a record, with no attachments left.
        case ended

        /// A `SceneState` with its payload dropped: the name of the state, for the parts of the product that
        /// need to *say* which state a Scene is in — a sidebar badge, a log line, a transition rule — without
        /// caring where it is drawn.
        enum Label: String, Codable, Sendable, Hashable, CaseIterable, CustomStringConvertible {
            case defined
            case active
            case ending
            case ended

            var description: String { rawValue }
        }

        /// This state's name.
        var label: Label {
            switch self {
                case .defined: .defined
                case .active: .active
                case .ending: .ending
                case .ended: .ended
            }
        }
    }
}
