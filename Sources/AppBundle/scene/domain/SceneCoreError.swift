import Foundation

extension SceneCore {
    /// Every way a Scene Core value can refuse to exist.
    ///
    /// The domain rejects invalid state at construction rather than tolerating it and hoping a later layer
    /// notices: a Scene with no title, an attachment pointing at a Slot that is not there, or two
    /// attachments for the same window are all unrepresentable, not merely discouraged.
    enum SceneCoreError: Error, Equatable, Sendable {
        /// A `WindowRef` needs an application to belong to.
        case emptyBundleId
        /// Window ordinals count from zero; a negative one cannot be resolved against anything.
        case negativeWindowOrdinal(Int)
    }
}
