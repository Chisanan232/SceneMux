import Foundation

extension SceneCore {
    /// One window, and what ending its Scene is allowed to do about it.
    ///
    /// A step is derived from an attachment and nothing else: the effect comes from the recorded ownership,
    /// so nothing between the user's decision and the window can change what SceneMux may do. Whoever
    /// executes a step reads `effect` and never re-derives it from where the window sits.
    struct SceneTeardownStep: Equatable, Sendable {
        /// The window this step is about.
        let windowRef: WindowRef
        /// The terms it was attached on — the source of the effect, kept so a diagnostic can name them.
        let ownership: Ownership
        /// The Home recorded when the window was attached.
        ///
        /// A *fallback*, not the destination. A restore aims at the Home the window has **now**, because the
        /// user may have re-homed the application since; this is what to use when it has no Home now. The
        /// resolution itself belongs to the Home surface (HORO-1107), which is why a step carries the record
        /// rather than a resolved place.
        let recordedHome: SemanticHome

        /// What may be done to the window. Ownership decides, always.
        var effect: SceneTeardownEffect {
            ownership.teardownEffect
        }

        /// Whether this step needs anybody to do anything.
        ///
        /// Only a `.restoreToHome` does. `.leaveInPlace` and `.untouched` are complete the moment they are
        /// stated, which is why a Scene of nothing but scene-owned and shared windows closes in one step and
        /// nothing is left pending for a restart to re-attempt.
        var needsWork: Bool {
            effect == .restoreToHome
        }

        init(_ attachment: Attachment) {
            windowRef = attachment.windowRef
            ownership = attachment.ownership
            recordedHome = attachment.homeAtAttachTime
        }
    }
}
