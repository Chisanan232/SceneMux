import Foundation

extension SceneCore.Scene {
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
}
