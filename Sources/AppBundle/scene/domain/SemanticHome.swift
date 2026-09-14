import Foundation

extension SceneCore {
    /// What a window is *for*, independent of where it currently is. A category, never a place.
    ///
    /// Four fixed cases in v0.1.0. A closed set is checkable, and the golden journey needs exactly these
    /// four; user-defined Homes would make every rule that reads a Home unbounded. Adding a case is a
    /// source change with a migration, which is the honest cost.
    ///
    /// The `rawValue` is the stable identifier persisted state and rule tables key on — it is the
    /// "Semantic Home id", so no separate wrapper type exists to drift from it.
    ///
    /// A Home is resolved from an application bundle id rule table plus an explicit user override, and
    /// from nothing else. Window titles are not an input: they are the most sensitive thing on a
    /// person's screen, `AGENTS.md` forbids logging them, and a rule that read them would make a
    /// window's category depend on what someone is currently typing. Process lineage is not an input
    /// either — that is admission gate G2, which does not exist in v0.1.0.
    ///
    /// The invariant that makes Home worth having: mounting a window into a Scene never changes it.
    enum SemanticHome: String, Codable, Sendable, Hashable, CaseIterable, CustomStringConvertible {
        /// Building software — editors, terminals, agents, local previews.
        case development
        /// Talking to people — chat, mail, calls.
        case communication
        /// Watching systems — dashboards, logs, traces, alerts.
        case observability
        /// The user's own — music, notes, browsing that is not work.
        case personal

        var description: String { rawValue }
    }
}
