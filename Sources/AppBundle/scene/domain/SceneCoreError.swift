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
        /// A Scene's title is the one field a person reads. Blank is not a name.
        case emptySceneTitle
        /// Two Slots in one Scene claimed the same `SlotId`, so an attachment could not say which it meant.
        case duplicateSlotId(SlotId)
        /// An attachment pointed at a Slot the Scene does not have.
        case unknownSlot(SlotId)
        /// One window, two attachments in the same Scene. Invariant I4 says at most one, everywhere.
        case duplicateAttachment(WindowRef)
        /// A Slot that still holds windows cannot be removed: removing it would silently orphan them.
        case slotNotEmpty(SlotId)
        /// An `ended` Scene is a record of a finished task, so it holds no attachments.
        case attachmentsInEndedScene
        /// The lifecycle has no edge from the Scene's current state to the requested one.
        case illegalTransition(from: SceneState.Label, to: SceneState.Label)
    }
}
