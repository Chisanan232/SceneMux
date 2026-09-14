import Foundation

extension SceneCore {
    /// A Scene's stable identity. Opaque and generated once, never derived from the title, so renaming a
    /// Scene is free and cannot orphan its attachments.
    ///
    /// Shaped like the identity types the engine already uses (`tree/WorkspaceIdentity.swift`) so the
    /// SceneMux layer stays legible to someone who knows the engine. Coded as a bare string rather than
    /// as `{"rawValue": …}`, following `WorkspaceProjectId`.
    struct SceneId: RawRepresentable, Hashable, Identifiable, Sendable, Codable, CustomStringConvertible {
        let rawValue: String

        var id: String { rawValue }
        var description: String { rawValue }

        init(rawValue: String) {
            self.rawValue = rawValue
        }

        init(_ rawValue: String) {
            self.rawValue = rawValue
        }

        static func generate() -> SceneId {
            SceneId(UUID().uuidString)
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
