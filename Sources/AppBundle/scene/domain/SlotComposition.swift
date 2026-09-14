import Foundation

extension SceneCore {
    /// How *several* windows share one Slot.
    ///
    /// Realisation at the engine seam: `.single` binds the window at the Slot's ordinal position,
    /// `.split` joins siblings with `join-with` in that orientation — never with `split`, which is a
    /// no-op while flatten-containers normalization is on — and `.tabbed` is a container with
    /// `Layout.tabGroup`, the shape `docs/development/baseline-verification.md` measured.
    enum SlotComposition: Sendable, Hashable, Codable, CustomStringConvertible {
        case single
        case split(SlotOrientation)
        case tabbed

        /// Worded for the person reading a diagnostic, not for a log grep. When SceneMux has to explain that
        /// a Slot came out differently from the way it was asked for, "a vertical split" is a sentence and
        /// `split(SceneMux.SlotOrientation.vertical)` is not.
        var description: String {
            switch self {
                case .single: "a single window"
                case .split(let orientation): "a \(orientation) split"
                case .tabbed: "a tab group"
            }
        }

        /// The next composition when someone cycles a Slot through the shapes it can have.
        ///
        /// One key, four stops, back to the start: side by side, the other way round, stacked, plain. The
        /// order is the one the design spec cycles through (`docs/design/scene-core-ux.md`), and it is a total
        /// cycle rather than a menu because a Slot has only these shapes and reaching any of them in at most
        /// three presses is faster than reading a list.
        var cycled: Self {
            switch self {
                case .single: .split(.vertical)
                case .split(.vertical): .split(.horizontal)
                case .split(.horizontal): .tabbed
                case .tabbed: .single
            }
        }
    }
}
