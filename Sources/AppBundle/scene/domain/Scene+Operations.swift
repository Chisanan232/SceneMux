import Foundation

extension SceneCore.Scene {
    /// The Slot with this id, if the Scene has one.
    func slot(_ id: SceneCore.SlotId) -> SceneCore.Slot? {
        slots.first { $0.id == id }
    }

    /// The attachments participating in this Slot, in the order they were attached.
    ///
    /// An empty result is an ordinary answer, not a problem: a Slot with nothing in it still exists and is
    /// still shown (invariant I13), because an empty `terminal` Slot says something about the task.
    func attachments(in slotId: SceneCore.SlotId) -> [SceneCore.Attachment] {
        attachments.filter { $0.slotId == slotId }
    }

    /// This window's attachment to this Scene, if it has one.
    func attachment(for windowRef: SceneCore.WindowRef) -> SceneCore.Attachment? {
        attachments.first { $0.windowRef == windowRef }
    }

    /// A copy of this Scene with some parts replaced, re-validated on the way through.
    ///
    /// Every operation below funnels through here, which is why none of them can produce a Scene the
    /// constructor would have refused. Identity is not replaceable by design: an operation that changed which
    /// Scene this is would not be an operation on it. Title is not replaceable *here* — renaming is its own
    /// operation, so that the one field a person reads cannot be changed as a side effect of something else.
    private func with(
        slots: [SceneCore.Slot]? = nil,
        attachments: [SceneCore.Attachment]? = nil,
        state: SceneCore.SceneState? = nil,
    ) throws -> Self {
        try SceneCore.Scene(
            id: id,
            title: title,
            slots: slots ?? self.slots,
            attachments: attachments ?? self.attachments,
            state: state ?? self.state,
        )
    }

    /// This Scene under a new name.
    ///
    /// Renaming is free and changes nothing else: `SceneId` is generated once and every Slot, attachment and
    /// persisted record points at the id, never at the title. The new title is validated exactly like the
    /// original — blank is not a name — so a rename someone abandoned by emptying the field is refused rather
    /// than stored, and the caller still has the Scene it started with.
    func renamed(to newTitle: String) throws -> Self {
        try SceneCore.Scene(
            id: id,
            title: newTitle,
            slots: slots,
            attachments: attachments,
            state: state,
        )
    }

    /// This Scene with one more Slot. Throws if the Slot's id is already taken.
    func addingSlot(_ slot: SceneCore.Slot) throws -> Self {
        try with(slots: slots + [slot])
    }

    /// This Scene with that Slot replaced by a changed version of itself, matched by id.
    ///
    /// The *same* Slot changed, not a different one added, which is why composing or relabelling a Slot goes
    /// through here rather than through a remove-then-add: removal refuses a Slot that still holds windows,
    /// and recomposing a Slot full of windows is precisely the ordinary case. Refuses a Slot this Scene does
    /// not have, rather than quietly adding it — a caller passing the wrong id has a bug, not an intention.
    func replacingSlot(_ slot: SceneCore.Slot) throws -> Self {
        guard self.slot(slot.id) != nil else {
            throw SceneCore.SceneCoreError.unknownSlot(slot.id)
        }
        return try with(slots: slots.map { $0.id == slot.id ? slot : $0 })
    }

    /// This Scene without that Slot.
    ///
    /// Refuses a Slot that still holds windows, rather than dropping their attachments with it. Silently
    /// discarding an attachment would silently discard the *reason* SceneMux may act on a window — including
    /// the promise to send a borrowed one home — so removal is only ever available on an empty Slot, and the
    /// user is asked to move the windows out first.
    func removingSlot(_ id: SceneCore.SlotId) throws -> Self {
        guard slot(id) != nil else {
            throw SceneCore.SceneCoreError.unknownSlot(id)
        }
        if !attachments(in: id).isEmpty {
            throw SceneCore.SceneCoreError.slotNotEmpty(id)
        }
        return try with(slots: slots.filter { $0.id != id })
    }

    /// This Scene with one more window participating.
    ///
    /// Throws if the Slot is not this Scene's, or if the window is already attached here — an attachment
    /// carries permission, so a second one would mean two answers to "what may ending this Scene do to that
    /// window?" and no way to choose between them. Re-placing an attached window is a detach and an attach,
    /// which is two visible decisions rather than one silent overwrite.
    func attaching(_ attachment: SceneCore.Attachment) throws -> Self {
        try with(attachments: attachments + [attachment])
    }

    /// This Scene without that window.
    ///
    /// Detaching a window that is not attached is not an error — it is the state the caller asked for, and
    /// the operation has to be idempotent because the paths that reach it include a window that has
    /// disappeared and a `close` re-attempted after a restart. It changes the model only: what to *do* with
    /// the window it forgot is the teardown effect its ownership already named, decided before the
    /// attachment goes away.
    func detaching(_ windowRef: SceneCore.WindowRef) throws -> Self {
        try with(attachments: attachments.filter { $0.windowRef != windowRef })
    }

    /// This Scene in a new lifecycle state, if the lifecycle allows the move.
    ///
    /// The only way state changes, so the transition table is not advice. Note what it does *not* do: no
    /// window is moved, restored or closed here, because this is the model and not the orchestration.
    /// Reaching `ending` records the intent to resolve every attachment — durably, so it survives a quit —
    /// and the layer that acts on that intent reads each attachment's ownership to learn what it is allowed
    /// to do.
    func transitioning(to newState: SceneCore.SceneState) throws -> Self {
        guard state.canTransition(to: newState.label) else {
            throw SceneCore.SceneCoreError.illegalTransition(from: state.label, to: newState.label)
        }
        return try with(state: newState)
    }
}
