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

extension SceneCore.SceneCoreError: CustomStringConvertible {
    /// One clause a person can read, for the diagnostics the UI is required to show when SceneMux declines
    /// to load part of someone's state. Never a type dump: `unknownSlot(SlotId(rawValue:))` tells a user
    /// nothing about their own file.
    ///
    /// A bundle id may appear here, because that is what the message is *about* and it is what the Scene
    /// sidebar already shows. A window title never can — no Scene Core value holds one.
    var description: String {
        switch self {
            case .emptyBundleId:
                "a window reference has no application"
            case .negativeWindowOrdinal(let ordinal):
                "a window ordinal is negative (\(ordinal))"
            case .emptySceneTitle:
                "the Scene has no title"
            case .duplicateSlotId(let id):
                "two Slots claim the same identity (\(id))"
            case .unknownSlot(let id):
                "a window is attached to a Slot the Scene does not have (\(id))"
            case .duplicateAttachment(let windowRef):
                "one window is attached twice (\(windowRef))"
            case .slotNotEmpty(let id):
                "the Slot still holds windows (\(id))"
            case .attachmentsInEndedScene:
                "the Scene has ended but still holds windows"
            case .illegalTransition(let from, let to):
                "a Scene cannot move from \(from) to \(to)"
        }
    }
}
