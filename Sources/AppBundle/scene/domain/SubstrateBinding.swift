import Foundation

extension SceneCore {
    /// Where an active Scene is currently being drawn: the rendering substrate its Slots are projected onto.
    ///
    /// A binding, never an identity. A Scene outlives its substrate — if the engine prunes the workspace, the
    /// Scene loses this and nothing else. The engine tree is derived output of Scene state, so it can be
    /// thrown away and rebuilt; the Scene cannot.
    ///
    /// The workspace is named in plain text rather than as the engine's own identity type, because
    /// `scene/domain/` names no engine type (invariant I12). The adapter translates it at the seam. No
    /// monitor is recorded: monitors come and go, and the engine already knows which one a workspace is on.
    struct SubstrateBinding: Hashable, Sendable, Codable, CustomStringConvertible {
        /// The name of the engine workspace this Scene is projected onto.
        let workspaceName: String

        var description: String { workspaceName }
    }
}
