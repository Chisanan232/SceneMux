import Foundation

extension SceneCore {
    /// One Scene's row: which task, where it is in its life, and what is in it.
    ///
    /// The hard part of this row is a distinction that is easy to lose: **a Scene that is not on screen but
    /// still holds windows must not look like an empty one.** That is the difference between "I have work
    /// parked here" and "there is nothing here", and it is exactly the state leaving a Scene produces. So every
    /// state differs in three ways at once — badge shape, row fill and trailing text — because opacity alone
    /// fails for someone using reduced contrast and fails completely in a screenshot attached to a ticket.
    ///
    /// Tokens are named, not resolved: a row says `.faint`, and the view maps that to `GlassToken`. That keeps
    /// this layer testable without a window server, and keeps the design tokens in one place.
    struct SceneShellSceneRow: Equatable, Sendable, Identifiable {
        /// The badge shape, which carries the state without any colour at all.
        enum Badge: String, Sendable {
            case filled
            case halfFilled
            case outline
            /// Filled, with a progress ring: the Scene is mid-teardown and is not frozen.
            case restoring
        }

        /// Which `GlassToken` fill the view should use. Named here, resolved there.
        enum Fill: String, Sendable {
            case active
            case resting
            case faint
        }

        /// Which `GlassToken` text opacity the title should use.
        enum TitleEmphasis: String, Sendable {
            case primary
            case secondary
        }

        let id: SceneId
        /// 1-based, and the number the user presses: `⌃⌥3` and `scene 3` mean this row.
        let index: Int
        let title: String
        let state: SceneState.Label
        let slots: [SceneShellSlotRow]
        /// How many windows are participating in this Scene, across all of its Slots.
        let windowCount: Int

        var isActive: Bool { state == .active }

        var badge: Badge {
            switch state {
                case .active: .filled
                case .defined: windowCount > 0 ? .halfFilled : .outline
                case .ending: .restoring
                case .ended: .outline
            }
        }

        var fill: Fill {
            switch state {
                case .active: .active
                case .defined: windowCount > 0 ? .resting : .faint
                case .ending: .resting
                case .ended: .faint
            }
        }

        var titleEmphasis: TitleEmphasis {
            state == .defined && windowCount == 0 ? .secondary : .primary
        }

        /// `active`, `6 windows`, `empty`, or `restoring…`.
        var trailing: String {
            switch state {
                case .active: "active"
                case .ending: "restoring…"
                case .ended: "closed"
                case .defined: windowCount == 0 ? "empty" : windowsPhrase
            }
        }

        /// Only the active Scene gets one, because it is the only Scene the screen is showing.
        var showsAccentBar: Bool { isActive }

        /// What an active Scene with nothing in it says instead of looking broken.
        ///
        /// An entered Scene with no windows is normal — it is what creating a Scene and entering it does — so
        /// the row reads as an invitation rather than a failure. Nothing is auto-populated and no application
        /// is launched to fill it.
        var invitation: String? {
            guard isActive, windowCount == 0 else { return nil }
            return "Nothing is in this Scene yet. Its slots are where its windows will go."
        }

        /// `"Debug PROD-123, scene, active, 6 windows"` — title, what it is, its state, and its size.
        var accessibilityLabel: String {
            "\(title), scene, \(stateWord), \(windowsPhrase)"
        }

        private var windowsPhrase: String {
            switch windowCount {
                case 0: "no windows"
                case 1: "1 window"
                default: "\(windowCount) windows"
            }
        }

        private var stateWord: String {
            switch state {
                case .active: "active"
                case .defined: "inactive"
                case .ending: "restoring"
                case .ended: "closed"
            }
        }

        init(scene: Scene, index: Int, homes: HomeRules, naming: ApplicationNaming) {
            id = scene.id
            self.index = index
            title = scene.title
            state = scene.state.label
            windowCount = scene.attachments.count
            slots = scene.slots
                .sorted { $0.order < $1.order }
                .enumerated()
                .map { offset, slot in
                    SceneShellSlotRow(
                        slot: slot,
                        index: offset + 1,
                        attachments: scene.attachments(in: slot.id),
                        homes: homes,
                        naming: naming,
                    )
                }
        }
    }
}
