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
        ///
        /// `.borrowed` and `.sceneOwned` are the two an attach action produces. `.sharedPersistent` reaches
        /// an attachment only by degradation — `Ownership.failSafe` — because a window the user shares with
        /// the whole desktop is not attached to any Scene in the first place. It stays representable here
        /// precisely so that state SceneMux cannot understand can be read as "leave this one alone".
        let ownership: Ownership
        /// The window's Home at the moment it was attached. Recorded, never rewritten.
        ///
        /// Not a destination: if the user re-homes the application while the Scene is open, the window is
        /// restored to the Home it has *now*, and this value only explains to them what changed. Evidence,
        /// not instruction — see `docs/design/scene-core-architecture.md`.
        let homeAtAttachTime: SemanticHome
        /// Where the window was when it was attached — the surface a restore aims at. Recorded, never
        /// rewritten.
        ///
        /// This is the Home surface of the architecture doc, resolved at the one moment it is knowable: a
        /// Home is a category and cannot receive a window, so restoring one means putting it back where it
        /// was living before the Scene borrowed it. Recorded rather than looked up later because by teardown
        /// time the answer is gone — the window is in the Scene's substrate, and asking where it is would
        /// answer "here".
        ///
        /// Optional because a build that could not tell is honest about it rather than inventing a
        /// destination: nothing to restore to means the window stays exactly where it is and the user is
        /// told, which is `SceneTeardownOutcome.leftInPlace`. A missing value is never a reason to move a
        /// window somewhere plausible.
        let originSurface: SubstrateBinding?
        /// How the attachment came about.
        let origin: AttachmentOrigin

        /// True when this attachment is a Mount: a window lent to the Scene, which goes home when the Scene
        /// ends. Reads the recorded ownership and nothing else — no Home comparison is involved.
        var isMount: Bool { ownership == .borrowed }

        var description: String { "\(windowRef) → \(slotId) (\(ownership))" }
    }
}
