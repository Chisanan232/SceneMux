import Foundation

extension SceneCore {
    /// What ending a Scene may do to a window.
    ///
    /// Ownership is *recorded from the action the user took* — an explicit mount is `.borrowed`, an explicit
    /// attach is `.sceneOwned` — and never deduced from where the window happens to sit. Comparing a
    /// window's Home against a Slot's role can only propose a verb in the UI; it cannot decide what SceneMux
    /// is allowed to move. `docs/design/scene-core-architecture.md` records why, under "Corrected on
    /// 2026-09-14".
    ///
    /// `.sceneOwned` does not mean "closed when the Scene ends". Nothing means that; see
    /// `SceneTeardownEffect`.
    enum Ownership: String, Codable, Sendable, Hashable, CaseIterable, CustomStringConvertible {
        /// Home is elsewhere; the window is lent to this Scene and goes back when the Scene ends.
        case borrowed
        /// The window exists because of this Scene. Left in place; cleanup is offered, never performed.
        case sceneOwned
        /// Belongs to the desktop rather than to any task. Not SceneMux's to touch at all.
        case sharedPersistent

        var description: String { rawValue }

        /// The value to fall back to whenever ownership cannot be determined: corrupt state, an
        /// unrecognised persisted case, a window that vanished and came back.
        ///
        /// It is the most conservative of the three on purpose. The failure mode of a bug in this area is
        /// then "SceneMux does nothing", which a person can recover from, rather than "SceneMux moved or
        /// closed a window", which they cannot.
        static let failSafe: Ownership = .sharedPersistent

        /// Decoding never throws on an unknown case — it degrades to `failSafe`.
        ///
        /// A thrown error here would fail the whole state file, and a state file that fails is a state file
        /// someone is tempted to delete. Degrading one attachment to "leave it completely alone" keeps the
        /// rest of the Scene readable while removing SceneMux's permission to act on the part it does not
        /// understand.
        init(from decoder: any Decoder) throws {
            let rawValue = try decoder.singleValueContainer().decode(String.self)
            self = Ownership(rawValue: rawValue) ?? .failSafe
        }
    }
}
