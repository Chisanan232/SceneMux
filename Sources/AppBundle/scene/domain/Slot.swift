import Foundation

extension SceneCore {
    /// A named role inside a Scene: *the place where the editor goes*, not *the rectangle at x=848*.
    ///
    /// There is no frame, no origin, no size and no monitor id here, and that absence is the point. Geometry
    /// is the tiling engine's business — it already computes rectangles from weights and orientations, on
    /// whatever monitors exist at the time — so a Slot that recorded pixels would be wrong the moment someone
    /// unplugged a display. A Slot records *which role* and *in what order*, and stays true.
    ///
    /// A Slot with nothing in it is still a Slot: it exists in state and is still shown (invariant I13). An
    /// empty `terminal` Slot is a statement about the task, not an absence to be tidied away — which is one of
    /// the differences between a Scene and the engine's workspaces, since those are pruned when they empty.
    struct Slot: Hashable, Sendable, Codable, Identifiable, CustomStringConvertible {
        /// Stable identity, generated once, unique within the Scene.
        let id: SlotId
        /// One of the five roles. Two Slots may share a role — "two terminals" is a normal thing to want.
        let role: SlotRole
        /// Optional user text, shown instead of the role name when set.
        let label: String?
        /// How several windows share this Slot.
        let composition: SlotComposition
        /// Where the Slot sits relative to its siblings. An ordering, not a coordinate.
        let order: Int

        var description: String { "\(role)#\(order)" }
    }
}
