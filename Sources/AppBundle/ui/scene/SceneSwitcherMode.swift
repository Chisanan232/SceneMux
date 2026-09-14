import Foundation

/// What the Scene switcher is doing, and therefore what a keystroke means in it.
///
/// One value rather than three booleans, because the states are exclusive and the interesting bugs live in
/// the combinations that should not exist: a panel that is renaming *and* asking to close has to answer for
/// `⏎` twice. Esc is the other reason — it means "back to browsing" in every editing state and "dismiss" only
/// in `browsing`, which is a single `switch` here and an unreadable chain of `if`s if the state is scattered.
enum SceneSwitcherMode: Equatable {
    /// The list, filtered by whatever has been typed. Selection moves, `⏎` enters.
    case browsing
    /// A name is being typed for a Scene that does not exist yet. `⏎` creates it and does not enter it.
    case creating
    /// The selected Scene's title is being edited in place. `⏎` commits, Esc reverts.
    case renaming(SceneCore.SceneId)
    /// What closing this Scene will do, waiting to be confirmed. Nothing has moved yet.
    case confirmingClose(SceneCore.SceneId, SceneCore.SceneShellCloseSummary)

    /// Whether a text field owns the keyboard, so the list's own keys stay out of the way.
    var isEditingText: Bool {
        switch self {
            case .creating, .renaming: true
            case .browsing, .confirmingClose: false
        }
    }
}
