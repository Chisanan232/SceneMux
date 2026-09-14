import Foundation

extension SceneCore {
    /// What became of one Slot when the engine was asked to build it.
    ///
    /// A projection is allowed to be partly successful, and saying so is the point of this type. Windows go
    /// missing for ordinary reasons — the user quit the app, the window is on another Space and the
    /// Accessibility API cannot see it (`docs/development/baseline-verification.md`) — and the honest
    /// answer is "four of the five, and here is the fifth". The alternative, failing the whole Scene because
    /// one window is gone, would make Scenes useless on exactly the desktop they are for.
    ///
    /// A Slot the engine could not build is reported, never silently dropped and never worked around by
    /// closing or moving something else.
    enum SceneSlotPlacement: Hashable, Sendable, CustomStringConvertible {
        /// Built, with every window the Slot asked for. The payload is the composition the engine *settled*
        /// on, which is not always the one requested — the user's own normalization rules get the last word,
        /// and hiding that would make the screen contradict the report.
        case realised(SlotComposition)
        /// Built, but some of the Slot's windows were nowhere to be found. The ones that were, were placed.
        case partlyRealised(SlotComposition, missing: [WindowRef])
        /// None of the Slot's windows could be found, so nothing was built.
        case windowsMissing([WindowRef])
        /// Nothing to build. An empty Slot is still a Slot.
        case empty
        /// The engine declined, in its own words. Reported to the human rather than retried.
        case refused(String)

        /// The composition the engine settled on, if anything was built at all.
        var composition: SlotComposition? {
            switch self {
                case .realised(let composition): composition
                case .partlyRealised(let composition, _): composition
                case .windowsMissing, .empty, .refused: nil
            }
        }

        /// The windows this Slot expected and did not get.
        var missingWindows: [WindowRef] {
            switch self {
                case .partlyRealised(_, let missing): missing
                case .windowsMissing(let missing): missing
                case .realised, .empty, .refused: []
            }
        }

        /// Whether the Slot ended up exactly as the Scene asked. An empty Slot did, by having asked for
        /// nothing.
        func isAsRequested(_ requested: SlotComposition) -> Bool {
            switch self {
                case .realised(let composition): composition == requested
                case .empty: true
                case .partlyRealised, .windowsMissing, .refused: false
            }
        }

        var description: String {
            switch self {
                case .realised(let composition): "realised as \(composition)"
                case .partlyRealised(let composition, let missing):
                    "realised as \(composition), missing \(missing.count)"
                case .windowsMissing(let missing): "missing all \(missing.count)"
                case .empty: "empty"
                case .refused(let reason): "refused: \(reason)"
            }
        }
    }
}
