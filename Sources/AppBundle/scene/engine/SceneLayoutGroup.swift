import Foundation

extension SceneCore {
    /// One Slot, restated as the piece of work the engine is about to be asked to do.
    ///
    /// A group is derived from a Scene and then thrown away. It is intent, never state: the Scene remains
    /// the only thing that knows which window belongs to which Slot, and this value exists so that the
    /// engine seam can be spoken entirely in Scene vocabulary — "this Slot, these windows, composed like
    /// this" — instead of leaking `TilingContainer` into the domain.
    ///
    /// The windows arrive in attachment order, because that is the only order a Scene records. Nothing here
    /// is a coordinate, a monitor or a frame; a group says *what goes together*, and the adapter decides
    /// what that means in the tree.
    struct SceneLayoutGroup: Hashable, Sendable, CustomStringConvertible {
        /// Which Slot this realises. The key every outcome is reported against.
        let slotId: SlotId
        /// Carried so a report can be read by a human without the Scene in hand.
        let role: SlotRole
        /// How the Slot asked to be composed. What the engine settles on may differ — see
        /// `SceneSlotPlacement`.
        let composition: SlotComposition
        /// The Slot's own ordering within the Scene, so a report can be read in layout order.
        let order: Int
        /// The windows this Slot holds, in attachment order. Empty is legal and means an empty Slot.
        let windows: [WindowRef]

        /// Whether the engine has anything at all to do for this Slot.
        ///
        /// An empty Slot is not a mistake to be tidied away — invariant I13 keeps it in state and on screen
        /// — but it contributes nothing to a tiling tree, because there is nothing to tile.
        var isOccupied: Bool { !windows.isEmpty }

        /// Whether this Slot needs a container of its own, or is simply a window among its siblings.
        ///
        /// A single window is bound straight into the substrate even when its Slot asks for a split or a tab
        /// group, and that is a correctness requirement rather than a shortcut: `normalizeContainers` in
        /// `tree/normalizeContainers.swift` flattens a container down to its only child, so a container
        /// built to hold one window would evaporate on the very next normalization pass and the projection
        /// would not survive its own engine. One window, no container, nothing to flatten.
        ///
        /// `.single` never needs one either, at any count. A Slot that says it does not compose its windows
        /// gets them laid out beside each other, which is what the user asked for.
        var needsContainer: Bool { windows.count > 1 && composition != .single }

        var description: String { "\(role)#\(order) [\(windows.count)]" }
    }
}
