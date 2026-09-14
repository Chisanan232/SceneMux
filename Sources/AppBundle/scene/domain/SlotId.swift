import Foundation

extension SceneCore {
    /// A Scene Slot's stable identity, unique within its Scene.
    ///
    /// Slot identity lives in Scene state and never in the engine tree: the engine flattens containers
    /// (`tree/normalizeContainers.swift`) and prunes empty workspaces
    /// (`Workspace.reconcileWorkspaceState()`), so an identity stored in a `TilingContainer` would not
    /// survive normalization, and an empty Slot would have no container to be.
    struct SlotId: RawRepresentable, Hashable, Identifiable, Sendable, Codable, CustomStringConvertible {
        let rawValue: String

        var id: String { rawValue }
        var description: String { rawValue }

        init(rawValue: String) {
            self.rawValue = rawValue
        }

        init(_ rawValue: String) {
            self.rawValue = rawValue
        }

        static func generate() -> SlotId {
            SlotId(UUID().uuidString)
        }

        init(from decoder: any Decoder) throws {
            rawValue = try decoder.singleValueContainer().decode(String.self)
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(rawValue)
        }
    }
}
