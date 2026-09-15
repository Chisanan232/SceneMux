import Foundation

extension SceneCore {
    /// What the engine has already decided a window *is* — the one thing admission asks it, and the reason
    /// admission needs no Accessibility round-trip of its own.
    ///
    /// The engine classifies every window it detects and then binds it accordingly: an ordinary window into
    /// the tiling tree, a dialog or a window the user's config keeps untiled straight onto the workspace, a
    /// menu or completion list into its popup container, and a minimized or native-fullscreen window into the
    /// container macOS's own behaviour requires. Reading *where it put the window* is strictly better than
    /// asking the same question again: it is free, it is synchronous, and it cannot disagree with the engine —
    /// whereas a second heuristic over window role and level eventually would, and the day it did, SceneMux
    /// would be moving a dialog into a Slot.
    ///
    /// Only `.managed` is eligible for a Slot. That is the whole of the conservative handling of dialogs and
    /// popups: they are not classified as ineligible by a rule that could be edited, they arrive as a kind no
    /// rule can route.
    enum AdmissionWindowKind: String, Equatable, Sendable, CaseIterable, CustomStringConvertible {
        /// An ordinary window, in the tiling tree. The only kind a Scene may take.
        case managed
        /// Floating: a dialog, or a window the engine was told not to tile. Left alone — a Slot is a place for
        /// the work, and a save sheet is not the work.
        case floating
        /// A popup: a menu, a completion list, a tooltip. Never a task's window, and moving one would break
        /// the interaction it belongs to.
        case popup
        /// Somewhere macOS put it and the engine is only keeping track: minimized, natively fullscreen, or
        /// hidden along with its application. Whatever the person did to it, they did not do it in order to
        /// have it pulled into a layout.
        case setAside

        /// Whether a Scene may take a window of this kind into a Slot at all.
        ///
        /// Expressed as a property of the kind rather than as a condition inside the rules, so that adding a
        /// kind forces an answer here instead of quietly inheriting `true`.
        var isEligibleForASlot: Bool {
            switch self {
                case .managed: true
                case .floating, .popup, .setAside: false
            }
        }

        var description: String { rawValue }
    }
}
