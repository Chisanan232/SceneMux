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
        /// Evidence, not a destination — what the step needs in order to *explain* itself. The place a
        /// restore aims at is `homeSurface`; this is how the user is told which Home that place stood for,
        /// including when they have re-homed the application since and the two no longer agree.
        let recordedHome: SemanticHome
        /// Where the window goes back to: the surface it was on before the Scene took it.
        ///
        /// `nil` when the attachment never recorded one — state from an older build, or a build that could
        /// not tell. Then the window stays exactly where it is and the user is told so, which is
        /// `SceneTeardownOutcome.leftInPlace`. A step with nowhere to aim never guesses.
        let homeSurface: SubstrateBinding?
        /// What the window was on that surface, so that it goes back as what it was and not merely to where it
        /// was.
        ///
        /// `nil` when the attachment recorded none — state from a build that did not record it, or a window the
        /// engine could not describe. Then the restore asks for the surface and says nothing about the
        /// arrangement, and the engine keeps doing whatever it does with a window it is handed. A restore never
        /// invents an arrangement for the same reason it never invents a surface.
        let homeArrangement: WindowArrangement?

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
            homeSurface = attachment.originSurface
            homeArrangement = attachment.originArrangement
        }
    }
}
