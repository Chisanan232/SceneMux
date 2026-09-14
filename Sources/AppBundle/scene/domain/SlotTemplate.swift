import Foundation

extension SceneCore {
    /// The Slots a Scene starts life with.
    ///
    /// Templates exist because the first thing a new Scene needs is somewhere to put windows, and asking
    /// someone to name four Slots before they can start working turns creating a Scene into filling in a
    /// form. `development` is the shape of the golden journey in `docs/design/scene-core-ux.md`; `empty`
    /// creates none, for a task whose shape is not known yet.
    ///
    /// Deliberately a short closed list rather than user-editable templates: a template is a starting point,
    /// and every Slot it makes can be renamed, recomposed, added to or removed afterwards. Note what a
    /// template does *not* do — it attaches no window and names no application, so creating a Scene from one
    /// still moves nothing on screen.
    enum SlotTemplate: String, CaseIterable, Sendable, CustomStringConvertible {
        case development
        case empty

        var description: String { rawValue }

        /// The roles this template lays out, in the order they are laid out in.
        ///
        /// Terminal first because the journey starts by running something, then the editor, then what the
        /// task is watched through. Order here is Slot order, which is layout order at the seam.
        var roles: [SlotRole] {
            switch self {
                case .development: [.terminal, .editor, .preview, .observability]
                case .empty: []
            }
        }

        /// Freshly identified, unlabelled, single-window Slots in template order.
        ///
        /// New identities every call, because two Scenes created from one template are two different Scenes
        /// and a shared `SlotId` would make an attachment ambiguous the moment either of them was persisted.
        func slots() -> [Slot] {
            roles.enumerated().map { order, role in
                Slot(id: .generate(), role: role, label: nil, composition: .single, order: order)
            }
        }
    }
}
