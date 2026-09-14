import Foundation

extension SceneCore {
    /// The role a Scene Slot plays — *the place where the editor goes*, not *the rectangle at x=848*.
    ///
    /// Two Slots in one Scene may share a role: "two terminals" is a legitimate layout, which is why a
    /// role is not an identity and `SlotId` exists separately.
    enum SlotRole: String, Codable, Sendable, Hashable, CaseIterable, CustomStringConvertible {
        case editor
        case terminal
        case preview
        case observability
        case communication

        var description: String { rawValue }
    }
}
