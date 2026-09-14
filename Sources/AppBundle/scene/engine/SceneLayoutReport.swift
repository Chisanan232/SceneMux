import Foundation

extension SceneCore {
    /// What one projection actually did, Slot by Slot.
    ///
    /// The counterpart of `SceneTeardownPlan`'s honesty about endings: a projection reports rather than
    /// pretends. It carries the plan it was made from, so a caller can walk the outcomes in layout order
    /// without holding the Scene, and it carries diagnostics in the user's language, because "SceneMux laid
    /// the observability Slot out vertically" is something a person can act on and a flipped `Orientation`
    /// is not.
    ///
    /// Nothing here is persisted. A report describes one moment of one projection.
    struct SceneLayoutReport: Hashable, Sendable, CustomStringConvertible {
        /// The intent this report answers.
        let plan: SceneLayoutPlan
        /// What became of each Slot, keyed by Slot. Every Slot in the plan appears, empty ones included.
        let placements: [SlotId: SceneSlotPlacement]
        /// Sentences for the human, in the order they happened. Empty means nothing surprising occurred.
        let diagnostics: [String]

        /// The outcomes in layout order, paired with the intent they answer.
        var outcomes: [(group: SceneLayoutGroup, placement: SceneSlotPlacement)] {
            plan.groups.map { ($0, placements[$0.slotId] ?? .refused("SceneMux did not reach this Slot.")) }
        }

        func placement(for slotId: SlotId) -> SceneSlotPlacement? { placements[slotId] }

        /// Every window the Scene expected and the engine could not find, in layout order.
        var missingWindows: [WindowRef] { outcomes.flatMap(\.placement.missingWindows) }

        /// The Slots that ended up composed differently from the way they asked.
        var adjustedSlots: [SlotId] {
            outcomes.filter { !$0.placement.isAsRequested($0.group.composition) }.map(\.group.slotId)
        }

        /// Whether the screen now matches the Scene exactly. False is a normal, reportable outcome.
        var isFullyRealised: Bool { missingWindows.isEmpty && adjustedSlots.isEmpty }

        var description: String {
            "\(plan.sceneTitle): \(isFullyRealised ? "realised" : "partly realised") (\(placements.count) slots)"
        }
    }
}
