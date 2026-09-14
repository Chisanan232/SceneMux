import Foundation

extension SceneCore {
    /// One Scene as it appears in the state file, before the domain has had its say.
    ///
    /// It exists because `Scene` refuses to be constructed from state that breaks its invariants, and that is
    /// the right behaviour for a live Scene but too blunt for a file someone has been running for weeks: an
    /// attachment to a Slot a later build removed would cost them the entire Scene. So the on-disk shape is
    /// read into this permissive twin, the entries the domain cannot accept are set aside as quarantine
    /// records, and the Scene is then constructed from what is left — validated exactly as strictly as one
    /// built at runtime.
    ///
    /// The keys are `Scene`'s own synthesised ones, so this reads what `Scene` writes. Only `attachments` is
    /// permissive; everything else decodes strictly, because a Scene with no title or two Slots of the same
    /// identity is not a stale attachment, it is a file this build does not understand.
    struct PersistedScene: Decodable {
        let id: SceneId
        let title: String
        let slots: [Slot]
        let attachments: [SceneStateLenient<Attachment>]
        let state: SceneState

        /// The Scene this entry describes, plus every attachment that had to be left out of it.
        ///
        /// Throws only when the *Scene* is unusable — an empty title, two Slots claiming one identity — which
        /// the caller turns into a whole-file refusal, per invariant I9.
        func resolved() throws -> (scene: Scene, quarantined: [SceneStateQuarantine]) {
            var honoured: [Attachment] = []
            var setAside: [(windowRef: WindowRef?, reason: SceneStateQuarantine.Reason)] = []
            let slotIds = Set(slots.map(\.id))
            var seenWindowRefs: Set<WindowRef> = []

            for entry in attachments {
                guard let attachment = entry.value else {
                    setAside.append((nil, .unreadable(at: entry.codingPath)))
                    continue
                }
                if state.label == .ended {
                    setAside.append((attachment.windowRef, .sceneHasEnded))
                } else if !slotIds.contains(attachment.slotId) {
                    setAside.append((attachment.windowRef, .unknownSlot(attachment.slotId)))
                } else if !seenWindowRefs.insert(attachment.windowRef).inserted {
                    setAside.append((attachment.windowRef, .alreadyAttached))
                } else {
                    honoured.append(attachment)
                }
            }

            let scene = try Scene(
                id: id,
                title: title,
                slots: slots,
                attachments: honoured,
                state: state,
            )
            return (
                scene,
                setAside.map {
                    SceneStateQuarantine(
                        sceneId: scene.id,
                        sceneTitle: scene.title,
                        windowRef: $0.windowRef,
                        reason: $0.reason,
                    )
                }
            )
        }
    }
}
