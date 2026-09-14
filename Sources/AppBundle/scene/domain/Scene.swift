import Foundation

extension SceneCore {
    /// A task someone is doing: "Debug PROD-123", "Review the release", "Answer messages".
    ///
    /// Not a workspace and not the inherited project. A workspace is a place windows are laid out and is
    /// pruned when it empties; a project is a folder of workspaces in a sidebar. A Scene is the *why* — it
    /// knows which windows are participating and on what terms, and unlike either engine concept it has an
    /// end, which is the interesting operation.
    ///
    /// A Scene outlives whatever it is drawn on. While `defined` it has no substrate at all; while `active`
    /// it is projected onto one, and if the engine prunes that workspace the Scene loses a binding rather
    /// than an identity. The engine tree is derived output of this value, never the source of truth for it.
    ///
    /// Constructing one validates the cross-object rules, so a Scene that exists is a Scene that makes
    /// sense: an attachment pointing at a Slot that is not there, two Slots sharing an id, one window
    /// attached twice, or an `ended` Scene still holding windows are all rejected rather than tolerated.
    struct Scene: Hashable, Sendable, Codable, Identifiable, CustomStringConvertible {
        /// Stable, opaque, generated once. Never derived from the title, so renaming is free.
        let id: SceneId
        /// What the human calls the task. Free text, and the only field they read.
        let title: String
        /// The semantic layout intent, in order.
        let slots: [Slot]
        /// Which windows are participating, and on what terms.
        let attachments: [Attachment]
        /// Where the Scene is in its life, and — while `active` — what it is drawn on.
        let state: SceneState

        var description: String { "\(title) [\(state.label)]" }

        init(
            id: SceneId,
            title: String,
            slots: [Slot],
            attachments: [Attachment],
            state: SceneState,
        ) throws {
            let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedTitle.isEmpty {
                throw SceneCoreError.emptySceneTitle
            }

            var seenSlotIds: Set<SlotId> = []
            for slot in slots {
                if !seenSlotIds.insert(slot.id).inserted {
                    throw SceneCoreError.duplicateSlotId(slot.id)
                }
            }

            var seenWindowRefs: Set<WindowRef> = []
            for attachment in attachments {
                if !seenSlotIds.contains(attachment.slotId) {
                    throw SceneCoreError.unknownSlot(attachment.slotId)
                }
                if !seenWindowRefs.insert(attachment.windowRef).inserted {
                    throw SceneCoreError.duplicateAttachment(attachment.windowRef)
                }
            }

            if state.label == .ended, !attachments.isEmpty {
                throw SceneCoreError.attachmentsInEndedScene
            }

            self.id = id
            self.title = trimmedTitle
            self.slots = slots
            self.attachments = attachments
            self.state = state
        }

        /// Decoding re-runs every validation rule, so persisted state cannot smuggle in a Scene that the
        /// constructor would have refused. A state file written by an older or buggier build fails here
        /// rather than becoming a live Scene nobody can explain — and a Scene that fails to decode yields
        /// zero Scenes and zero window operations, which is invariant I9.
        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            try self.init(
                id: container.decode(SceneId.self, forKey: .id),
                title: container.decode(String.self, forKey: .title),
                slots: container.decode([Slot].self, forKey: .slots),
                attachments: container.decode([Attachment].self, forKey: .attachments),
                state: container.decode(SceneState.self, forKey: .state),
            )
        }
    }
}
