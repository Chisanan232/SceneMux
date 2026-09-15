import Foundation

extension SceneCore {
    /// The whole of what Scene Core asks of a window engine.
    ///
    /// Every question is in Scene vocabulary: *is there something to draw on*, *which window does the user
    /// mean*, *build this Slot here*, and *what did that actually become*. There is deliberately no way to
    /// ask for a container, an orientation, a frame or a monitor, because the moment the domain can ask for
    /// those it starts depending on how one particular engine spells them, and the seam stops being a seam.
    ///
    /// Only `WinMuxSceneEngineAdapter` implements this against the inherited tree. That file is the single
    /// place allowed to know both languages — see `docs/design/scene-core-architecture.md`. Tests implement
    /// it with a recorder, which is the other reason the port exists: a Slot mapping is worth testing
    /// without a Mac in the loop.
    ///
    /// The port is one-directional apart from `settle`. Scene state is projected onto the engine; the engine
    /// is asked only what a projection *became*, never what a Scene is.
    @MainActor
    protocol SceneEnginePort {
        /// Where a Scene entered right now would be drawn.
        ///
        /// Asked rather than assumed, because the answer is the engine's: which workspace is in front of the
        /// person depends on monitors, Spaces and what they last did, and a shell that worked it out for
        /// itself would have to name engine types to do it. This is the only way anything above the seam
        /// learns a substrate, which is what keeps `scene/shell/` free of the engine.
        ///
        /// - Returns: the substrate, or nothing when there is nothing usable to draw on — in which case
        ///   entering a Scene is refused rather than aimed at a guess.
        func currentSubstrate() -> SubstrateBinding?

        /// The window the user is looking at, as a reference a Scene can keep.
        ///
        /// What "mount this window" means: the person asking has one window in mind, and it is the one they
        /// just clicked or typed into. Asked of the engine because the engine is what knows, and returned as a
        /// `WindowRef` because that is the only window identity anything above the seam is allowed to hold —
        /// no window object escapes into Scene state, where it would go stale the moment the app quit.
        ///
        /// - Returns: the focused window, or nothing when the focus is an empty workspace or a window this
        ///   build cannot describe. Nothing means the request is refused rather than applied to a guess.
        func focusedWindow() -> WindowRef?

        /// Make sure the Scene has somewhere to be drawn, and start a fresh projection.
        ///
        /// Called exactly once per projection, before any placement, so an implementation may also use it to
        /// discard whatever it remembered about the previous one.
        ///
        /// - Returns: whether the substrate is usable. `false` refuses the whole projection rather than
        ///   letting it place windows somewhere the Scene did not ask for.
        func prepareSubstrate(_ binding: SubstrateBinding) -> Bool

        /// Build one Slot on the substrate.
        ///
        /// Called once per occupied Slot, in the Scene's own Slot order, and that order *is* the layout
        /// order — there is no positional argument, because an engine has no notion of "the Slot at index 2"
        /// to receive one. A Slot's place is simply where its windows ended up among the substrate's
        /// children, so an implementation that appends in call order produces the order the Scene asked for.
        /// Empty Slots are never placed, which is exactly why they cannot leave a gap in the tiling.
        func place(_ group: SceneLayoutGroup, on binding: SubstrateBinding) -> SceneSlotPlacement

        /// Let the engine finish — normalize, lay out — and report what each Slot's composition became.
        ///
        /// Read-back is structural on purpose: which Slots are split, tabbed or plain. Never geometry. A
        /// Scene that learned frames would start owning pixels, and pixels are the engine's business.
        ///
        /// - Returns: the effective composition of each Slot the projection built. A Slot absent from the
        ///   result is taken to have kept the composition it was placed with.
        func settle(_ binding: SubstrateBinding) -> [SlotId: SlotComposition]
    }
}
