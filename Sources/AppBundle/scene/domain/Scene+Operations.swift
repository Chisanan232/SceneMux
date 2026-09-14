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
    /// constructor would have refused. Identity and title are not replaceable by design: an operation that
    /// changed which Scene this is would not be an operation on it.
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

    /// This Scene with one more Slot. Throws if the Slot's id is already taken.
    func addingSlot(_ slot: SceneCore.Slot) throws -> Self {
        try with(slots: slots + [slot])
    }
}
