import Foundation

extension SceneCore {
    /// A detected window together with the Scene context a rule needs to decide about it.
    ///
    /// Two halves from two places, on purpose. The subject is what the engine can say about the window; the
    /// rest is what SceneMux already knows about its own Scenes. Assembled by the composition root, which is
    /// the only layer that can see both — and once assembled, deciding is a pure function of a value, so every
    /// case below can be a test with no desktop in it.
    struct AdmissionCandidate: Equatable, Sendable {
        let subject: AdmissionSubject
        /// What the window's application is for, resolved from the Home rules — which read a bundle id and
        /// nothing else, and which admission never changes (invariant I1).
        let home: SemanticHome
        /// The Scene on screen, or nothing when there is none.
        ///
        /// The Scene itself rather than a copy of the parts a rule happens to need: which Slots it has, what is
        /// already in each of them and which workspace it is drawn on are all facts about the same thing, and
        /// three fields that could disagree would be three ways to route a window into a Slot that is not
        /// really there.
        let activeScene: Scene?
        /// Whether this window is already attached to a Scene — any Scene, not only the one on screen.
        ///
        /// Invariant I4: one attachment per window across all Scenes. A window that is already spoken for is
        /// left alone, which also makes admission idempotent — the engine detects a window again after it
        /// resolves a misclassified popup, and the second look must not produce a second decision.
        let isAlreadyInAScene: Bool

        init(
            subject: AdmissionSubject,
            home: SemanticHome,
            activeScene: Scene?,
            isAlreadyInAScene: Bool,
        ) {
            self.subject = subject
            self.home = home
            self.activeScene = activeScene
            self.isAlreadyInAScene = isAlreadyInAScene
        }
    }
}
