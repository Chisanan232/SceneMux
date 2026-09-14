import Foundation

extension SceneCore {
    /// One attachment that was in the state file, parsed as far as its own shape, and then set aside.
    ///
    /// The narrower case the architecture document calls *quarantine*: state that parsed but describes
    /// something impossible — an attachment to a `SlotId` its Scene does not have, the same window attached
    /// twice, an attachment recorded against a Scene that has already ended. The Scene itself is fine, so
    /// the Scene loads without that attachment and the reason is surfaced once in the UI.
    ///
    /// Why the attachment and not the whole Scene: an attachment is only ever *permission* to move a window
    /// that is already on screen, so dropping one can never move, resize or close anything — it can only
    /// make SceneMux do less. Losing the whole Scene over one stale entry would throw away the Slots and
    /// the ownership records for every other window in it, which is strictly more destructive than the
    /// problem.
    ///
    /// An unrecognised `ownership` value never appears here: `Ownership.init(from:)` already degrades it to
    /// `.sharedPersistent`, which keeps the attachment and removes SceneMux's permission to act on it.
    struct SceneStateQuarantine: Equatable, Sendable {
        enum Reason: Equatable, Sendable {
            /// The attachment names a Slot the Scene does not have — a Slot removed by a later build, or a
            /// hand-edited file.
            case unknownSlot(SlotId)
            /// The same window is attached twice in one Scene. Invariant I4 allows one attachment; this is
            /// the second and later ones.
            case alreadyAttached
            /// An `ended` Scene is a record of a finished task, so an attachment in one is a leftover.
            case sceneHasEnded
            /// The entry is not a readable attachment at all, at this coding path when the decoder said.
            case unreadable(at: String?)
        }

        /// The Scene it was recorded against. The Scene loaded, so this identity is usable.
        let sceneId: SceneId
        /// The Scene's title, so the message names the task the way its owner does.
        let sceneTitle: String
        /// Which window, when the entry named one readably. `nil` only for `.unreadable`.
        let windowRef: WindowRef?
        let reason: Reason

        /// One line for the user: which window was left out of which Scene, and why.
        var diagnostic: String {
            "SceneMux left \(subject) out of \"\(sceneTitle)\": \(explanation) The window was not touched."
        }

        private var subject: String {
            windowRef.map { "\($0)" } ?? "one unreadable attachment"
        }

        private var explanation: String {
            switch reason {
                case .unknownSlot(let slotId):
                    "the Scene has no Slot \(slotId)."
                case .alreadyAttached:
                    "it is attached to that Scene more than once."
                case .sceneHasEnded:
                    "that Scene has already ended."
                case .unreadable(let codingPath):
                    codingPath.map { "the saved state at \($0) is not a readable attachment." }
                        ?? "the saved state is not a readable attachment."
            }
        }
    }
}
