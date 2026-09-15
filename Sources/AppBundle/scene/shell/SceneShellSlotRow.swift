import Foundation

extension SceneCore {
    /// One Slot's row: which role, how many windows are in it, and how they share it.
    ///
    /// What it deliberately does not carry is any geometry — no proportion, no orientation in degrees, no
    /// pixel count — because a Slot has none. `· tabs` and `· split ⬍` say *how these windows share a region*
    /// and stop there; resizing stays where it already works, on the windows themselves.
    ///
    /// An empty Slot is a row like any other, marked `empty` and dimmed rather than hidden. That is invariant
    /// I13 on screen: an empty `terminal` Slot is a statement about the task — this is where the terminal
    /// goes — and hiding it would turn a plan into a leftover.
    struct SceneShellSlotRow: Equatable, Sendable, Identifiable {
        let id: SlotId
        /// 1-based, and the number the user types: `slot compose --slot 2` means this row.
        let index: Int
        let role: SlotRole
        /// The user's label when they set one, the role otherwise.
        let title: String
        let composition: SlotComposition
        let windows: [SceneShellWindowRow]

        var isEmpty: Bool { windows.isEmpty }

        /// The role's glyph, as an SF Symbol name. Shape, so the row is not read by colour.
        var glyph: String {
            switch role {
                case .terminal: "terminal"
                case .editor: "pencil"
                case .preview: "rectangle.on.rectangle"
                case .observability: "waveform.path.ecg"
                case .communication: "bubble.left"
            }
        }

        /// `empty`, `1 window`, or `2 windows · tabs`.
        var trailing: String {
            guard !isEmpty else { return "empty" }
            let count = windows.count == 1 ? "1 window" : "\(windows.count) windows"
            guard let compositionChip else { return count }
            return "\(count) · \(compositionChip)"
        }

        /// How the windows share the Slot, when there is more than one way to read it.
        ///
        /// Nothing for a `.single` Slot: "1 window · single" would be noise, and a Slot holding one window
        /// looks the same on screen whatever it was asked for. The split orientation is offered as ⬍ or ⬌ and
        /// nothing finer, which is the whole vocabulary the design gives it.
        var compositionChip: String? {
            switch composition {
                case .single: nil
                case .split(.vertical): "split ⬍"
                case .split(.horizontal): "split ⬌"
                case .tabbed: "tabs"
            }
        }

        /// `"Communication slot, 2 windows, tabs"` — role, count, and the shape, in that order.
        var accessibilityLabel: String {
            let head = "\(title) slot"
            guard !isEmpty else { return "\(head), empty" }
            let count = windows.count == 1 ? "1 window" : "\(windows.count) windows"
            guard let compositionChip else { return "\(head), \(count)" }
            return "\(head), \(count), \(compositionChip)"
        }

        init(
            slot: Slot,
            index: Int,
            attachments: [Attachment],
            homes: HomeRules,
            naming: ApplicationNaming,
        ) {
            id = slot.id
            self.index = index
            role = slot.role
            title = slot.displayName
            composition = slot.composition
            windows = attachments.map {
                SceneShellWindowRow(attachment: $0, homes: homes, naming: naming)
            }
        }
    }
}
