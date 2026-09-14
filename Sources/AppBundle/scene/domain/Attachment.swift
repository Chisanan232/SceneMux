import Foundation

extension SceneCore {
    /// One window participating in one Slot of one Scene.
    ///
    /// The only value in the model that knows *why* a window is on screen, which is why it is also the only
    /// one that carries permission. A **Mount** is not a separate type: it is an attachment whose
    /// `ownership` is `.borrowed`, and the distinction is the recorded action rather than any comparison
    /// against the window's Home.
    struct Attachment: Hashable, Sendable, Codable, CustomStringConvertible {
        /// Which window, in a form that survives a restart.
        let windowRef: WindowRef
        /// Which Slot of the owning Scene it participates in.
        let slotId: SlotId
        /// What ending the Scene may do to it.
        let ownership: Ownership
        /// The window's Home at the moment it was attached. Recorded, never rewritten.
        ///
        /// Not a destination: if the user re-homes the application while the Scene is open, the window is
        /// restored to the Home it has *now*, and this value only explains to them what changed. Evidence,
        /// not instruction — see `docs/design/scene-core-architecture.md`.
        let homeAtAttachTime: SemanticHome
        /// How the attachment came about.
        let origin: AttachmentOrigin

        var description: String { "\(windowRef) → \(slotId) (\(ownership))" }
    }
}
