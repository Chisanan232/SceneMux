import Foundation

extension SceneCore {
    /// How a window came to be attached. Evidence, for explaining a Scene to the person who owns it — and
    /// deliberately *not* an input to what SceneMux may do, which is `Ownership` alone.
    ///
    /// Keeping the two apart is what lets the UI say "SceneMux put this here, because Terminal is a
    /// development app" without that sentence also being the reason a window may be moved later.
    ///
    /// This is also where later phases put what they learn about *where a window came from* — process
    /// lineage, a coding agent's session, a browser broker — as further cases. None of that exists in
    /// v0.1.0 and none of it is required by anything here; the point is that `Attachment` already has the
    /// field, so gaining that knowledge later adds a case rather than changing the shape of the model.
    enum AttachmentOrigin: Sendable, Hashable, Codable {
        /// The user dragged, typed or picked a menu item. Always wins over any rule.
        case userAction
        /// A G1 admission rule matched. The identifier names the rule that fired, so a surprising placement
        /// can be traced to the line that caused it. Rules themselves belong to the admission ticket.
        case admission(ruleId: String)
        /// Re-created when reading persisted Scene state after a restart.
        case restoredFromState
    }
}
