import Foundation

extension SceneCore {
    /// Projects a Scene's layout intent onto whatever engine is behind the port, and reports what happened.
    ///
    /// The order of operations is the whole content of this type, and it is fixed: prepare the substrate,
    /// build each occupied Slot in layout order, then let the engine settle and read back what the Slots
    /// became. Nothing is built before the substrate is known to be usable, and nothing is reported before
    /// the engine has had its say — a report written before normalization runs would describe a screen that
    /// no longer exists.
    ///
    /// Deliberately not a window manager, in the same way `SceneOrchestrator` is deliberately not one. It
    /// closes nothing, focuses nothing, and touches no window the plan does not name. It also decides
    /// nothing about geometry: how wide the editor ends up is the engine's business.
    @MainActor
    struct SceneProjector {
        private let port: any SceneEnginePort

        init(port: any SceneEnginePort) {
            self.port = port
        }

        /// Realises a plan, as far as the engine allows, and says how far that was.
        ///
        /// Partial success is a normal outcome rather than an error: a window the user quit is missing, the
        /// remaining Slots are still worth building, and the report names what was lost. Nothing here
        /// throws, because there is no failure a caller could repair by retrying — only outcomes a human
        /// may want to read.
        func project(_ plan: SceneLayoutPlan) -> SceneLayoutReport {
            guard port.prepareSubstrate(plan.substrate) else {
                let reason = "SceneMux could not prepare workspace \"\(plan.substrate)\" "
                    + "for \"\(plan.sceneTitle)\", so it laid out nothing."
                return SceneLayoutReport(
                    plan: plan,
                    placements: plan.groups.reduce(into: [:]) { $0[$1.slotId] = .refused(reason) },
                    diagnostics: [reason],
                )
            }

            var placements: [SlotId: SceneSlotPlacement] = [:]
            // Empty Slots first, so that every Slot in the plan has an outcome even though only the occupied
            // ones are ever handed to the engine. Invariant I13: an empty Slot exists, it just has no work.
            for group in plan.groups where !group.isOccupied {
                placements[group.slotId] = .empty
            }
            for (position, group) in plan.occupiedGroups.enumerated() {
                placements[group.slotId] = port.place(group, at: position, on: plan.substrate)
            }

            for (slotId, composition) in port.settle(plan.substrate) {
                guard let placed = placements[slotId] else { continue }
                placements[slotId] = placed.recomposed(as: composition)
            }

            return SceneLayoutReport(
                plan: plan,
                placements: placements,
                diagnostics: diagnostics(for: plan, placements),
            )
        }

        /// Turns outcomes into sentences a person can act on, in layout order.
        ///
        /// The engine's vocabulary does not survive this step. "SceneMux composed the observability Slot
        /// vertically" is actionable; a flipped `Orientation` on a nested `TilingContainer` is not, even
        /// though it is the same event — the common cause being the inherited
        /// `enableNormalizationOppositeOrientationForNestedContainers`, which is the user's own setting and
        /// so is reported rather than fought.
        private func diagnostics(
            for plan: SceneLayoutPlan,
            _ placements: [SlotId: SceneSlotPlacement],
        ) -> [String] {
            var lines: [String] = []
            for group in plan.groups {
                guard let placement = placements[group.slotId] else { continue }
                let slot = "the \(group.role) Slot of \"\(plan.sceneTitle)\""
                switch placement {
                    case .refused(let reason):
                        lines.append(reason)
                    case .windowsMissing(let missing):
                        lines.append("SceneMux found none of the windows for \(slot) (\(list(missing))), "
                            + "and left it empty.")
                    case .partlyRealised(let composition, let missing):
                        lines.append("SceneMux could not find \(list(missing)) for \(slot), "
                            + "and composed what remained as \(composition).")
                        appendAdjustment(&lines, composition, group, slot)
                    case .realised(let composition):
                        appendAdjustment(&lines, composition, group, slot)
                    case .empty:
                        break
                }
            }
            return lines
        }

        private func appendAdjustment(
            _ lines: inout [String],
            _ composition: SlotComposition,
            _ group: SceneLayoutGroup,
            _ slot: String,
        ) {
            guard composition != group.composition else { return }
            lines.append("SceneMux composed \(slot) as \(composition) instead of \(group.composition), "
                + "because the window engine normalized it.")
        }

        private func list(_ windows: [WindowRef]) -> String {
            windows.map(\.description).joined(separator: ", ")
        }
    }
}
