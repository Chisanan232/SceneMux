import Foundation

extension SceneCore {
    /// The whole of what Scene Core asks of a window engine.
    ///
    /// Three questions, all of them in Scene vocabulary: *is there something to draw on*, *build this Slot
    /// here*, and *what did that actually become*. There is deliberately no way to ask for a container, an
    /// orientation, a frame or a monitor, because the moment the domain can ask for those it starts
    /// depending on how one particular engine spells them, and the seam stops being a seam.
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
        /// - Parameter position: the Slot's place among the substrate's children, counted over occupied
        ///   Slots only. Empty Slots take no position, so they cannot leave a gap in the tiling.
        func place(
            _ group: SceneLayoutGroup,
            at position: Int,
            on binding: SubstrateBinding,
        ) -> SceneSlotPlacement

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
