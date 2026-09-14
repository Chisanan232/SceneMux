import Foundation

extension SceneCore {
    /// How *several* windows share one Slot.
    ///
    /// Realisation at the engine seam: `.single` binds the window at the Slot's ordinal position,
    /// `.split` joins siblings with `join-with` in that orientation — never with `split`, which is a
    /// no-op while flatten-containers normalization is on — and `.tabbed` is a container with
    /// `Layout.tabGroup`, the shape `docs/development/baseline-verification.md` measured.
    enum SlotComposition: Sendable, Hashable, Codable {
        case single
        case split(SlotOrientation)
        case tabbed
    }
}
