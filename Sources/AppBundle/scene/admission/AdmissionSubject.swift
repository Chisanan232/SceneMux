import Foundation

extension SceneCore {
    /// Everything admission is allowed to know about a window the engine has just detected — and, because it
    /// is the only thing handed over, everything it *can* know.
    ///
    /// The point of this type is what is missing from it. `docs/design/scene-core-architecture.md` forbids two
    /// inputs to a G1 decision, and both are absent here rather than merely unused:
    ///
    /// - **the window title.** The most sensitive text on the screen, and a placement that depended on it
    ///   would change with whatever the person is typing;
    /// - **process lineage.** That is admission gate G2. SceneMux has no lineage evidence in v0.1.0, and a
    ///   rule that guessed would hand a window to the wrong owner.
    ///
    /// A rule cannot read them because the value it is given does not contain them. That is a stronger promise
    /// than a comment asking it not to, and it is why the seam builds this rather than passing a window along.
    struct AdmissionSubject: Equatable, Sendable {
        /// Which window, said the way Scene state says it: an application and an ordinal, never a window id.
        let windowRef: WindowRef
        /// What the engine already decided this window is.
        let kind: AdmissionWindowKind
        /// Where the engine has just put it, or nothing when it is nowhere a Scene could name.
        ///
        /// Admission compares this against the Scene's own substrate, which is how a window opened on the
        /// workspace someone has switched away to is left where it is instead of being pulled onto the Scene's.
        let surface: SubstrateBinding?
        /// Whether this arrived while SceneMux was starting up and taking stock of the windows that already
        /// existed.
        ///
        /// Not a detail: a Scene is still `active` after a relaunch, and without this every window on the
        /// desktop would be presented to admission at once, as though the person had just opened all of them
        /// for the task. Startup is the engine describing what is already there, not a person doing something.
        let detectedDuringStartup: Bool

        init(
            windowRef: WindowRef,
            kind: AdmissionWindowKind,
            surface: SubstrateBinding?,
            detectedDuringStartup: Bool,
        ) {
            self.windowRef = windowRef
            self.kind = kind
            self.surface = surface
            self.detectedDuringStartup = detectedDuringStartup
        }
    }
}
