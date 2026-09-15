import Foundation

/// Attaching and detaching a window, as operations on *every* Scene rather than on one.
///
/// `Scene.attaching(_:)` already refuses the same window twice in the same Scene, and it cannot do better than
/// that: a Scene cannot see the other Scenes. Invariant I4 — a window has at most one attachment across all
/// Scenes — is a rule about the world, so it is enforced here, where the world is visible.
///
/// Nothing here touches a window either. These produce the world afterwards; moving the window into the Slot,
/// or sending it home, is the orchestrator's job.
extension SceneCore.SceneWorld {
    /// This world with one more window participating in one Scene.
    ///
    /// Refuses a window some *other* Scene already holds. Two attachments would mean two Scenes each holding
    /// a promise about the same window, and the one that ended second would move a window it had no claim on
    /// — into a Home it recorded before the first Scene ever borrowed it. The same window twice in the *same*
    /// Scene is refused one layer down, as `SceneCoreError.duplicateAttachment`, which says the more precise
    /// thing.
    ///
    /// Refuses a Scene that is closing, because that Scene's attachments have stopped being a description of
    /// what is on screen and become the list of restores it still owes. Adding to that list would tell the
    /// teardown to send home a window it never borrowed.
    func attaching(_ attachment: SceneCore.Attachment, to id: SceneCore.SceneId) throws -> Self {
        guard let scene = scene(id) else {
            throw SceneCore.SceneLifecycleError.unknownScene(id)
        }
        guard scene.state.label != .ending else {
            throw SceneCore.SceneLifecycleError.sceneIsClosing(id)
        }
        if let holder = scenes.first(where: { $0.id != id && $0.attachment(for: attachment.windowRef) != nil }) {
            throw SceneCore.SceneLifecycleError.windowAlreadyAttached(holder.id)
        }
        return try replacing(try scene.attaching(attachment))
    }
}
