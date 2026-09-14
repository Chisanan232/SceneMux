import Foundation

extension SceneCore {
    /// Which way a split Slot divides. An orientation, not a fraction: weights and resize handles are the
    /// tiling engine's business, and a stored rectangle would not survive a display change.
    ///
    /// Deliberately a SceneMux type rather than the engine's own orientation, because `scene/domain/`
    /// names no engine type. The adapter translates it at the seam.
    enum SlotOrientation: String, Codable, Sendable, Hashable, CaseIterable, CustomStringConvertible {
        case horizontal
        case vertical

        var description: String { rawValue }
    }
}
