import Foundation

extension SceneCore {
    /// The whole of one Scene's layout intent, in the order it should be built.
    ///
    /// Derived fresh from a Scene every time, exactly like `SceneTeardownPlan` is derived from a closing
    /// one, and for the same reason: a plan that is recomputed cannot drift from the state it describes.
    /// The Scene remains the source of truth and the engine tree remains derived output.
    ///
    /// A plan names windows and Slots and nothing else. It has no monitors, no frames and no containers,
    /// so reading one tells you what the user meant rather than what the screen will look like.
    struct SceneLayoutPlan: Hashable, Sendable, CustomStringConvertible {
        /// Which Scene this projects.
        let sceneId: SceneId
        /// What the human calls it, for diagnostics they can read.
        let sceneTitle: String
        /// What it is to be drawn on. A binding, never an identity.
        let substrate: SubstrateBinding
        /// Every Slot of the Scene in layout order, including the empty ones — invariant I13 means an empty
        /// Slot is still part of the plan, and a report that omitted it would be a report the shell cannot
        /// render.
        let groups: [SceneLayoutGroup]

        /// The Slots that actually give the engine work, in the order they should be built.
        ///
        /// This — not `groups` — is what a projection walks, and the position of a group in *this* list is
        /// its position among the substrate's children. Which is why an empty Slot cannot leave a hole in
        /// the tiling: it never takes a position.
        var occupiedGroups: [SceneLayoutGroup] { groups.filter(\.isOccupied) }

        /// Every window the projection may touch, and — because the adapter resolves windows only from
        /// here — the only ones it can. Invariant I15.
        var windows: [WindowRef] { groups.flatMap(\.windows) }

        var description: String { "\(sceneTitle) → \(substrate) [\(occupiedGroups.count)/\(groups.count)]" }

        /// Restates a Scene as the work of projecting it onto a substrate.
        ///
        /// Slots are ordered by their own `order`, and ties keep the order the Scene stored them in.
        /// `sorted(by:)` is not documented to be stable, so the stored index is part of the comparison
        /// rather than left to the sort: two Slots sharing an `order` is legal state, and a plan that
        /// shuffled them between runs would make the same Scene project differently each time.
        init(_ scene: Scene, on substrate: SubstrateBinding) {
            sceneId = scene.id
            sceneTitle = scene.title
            self.substrate = substrate
            groups = scene.slots.enumerated()
                .sorted { ($0.element.order, $0.offset) < ($1.element.order, $1.offset) }
                .map { _, slot in
                    SceneLayoutGroup(
                        slotId: slot.id,
                        role: slot.role,
                        composition: slot.composition,
                        order: slot.order,
                        windows: scene.attachments(in: slot.id).map(\.windowRef),
                    )
                }
        }
    }
}
