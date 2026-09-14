import Foundation

extension SceneCore {
    /// What closing a Scene will do, grouped by the thing that decides it: ownership.
    ///
    /// Closing is the only Scene flow that touches windows, so it is the only one that asks first — and it asks
    /// by showing the model's actual reasoning rather than a generic "are you sure?". A user who can see that
    /// two windows go home, four stay where they are and one is not SceneMux's business can predict the
    /// outcome; a warning that says "this cannot be undone" teaches them nothing and gets clicked through.
    ///
    /// Groups with nothing in them are left out. A Scene of four owned windows should not have to read a line
    /// telling it that no windows are shared.
    struct SceneShellCloseSummary: Equatable, Sendable {
        /// One ownership's windows, and the sentence that says what happens to them.
        struct Group: Equatable, Sendable, Identifiable {
            let ownership: Ownership
            let windows: [SceneShellWindowRow]

            var id: Ownership { ownership }

            /// `2 borrowed windows go back to their Home`, `4 scene windows stay where they are`,
            /// `1 shared window is not touched`.
            var headline: String {
                let count = windows.count
                switch (ownership, count == 1) {
                    case (.borrowed, true): return "1 borrowed window goes back to its Home"
                    case (.borrowed, false): return "\(count) borrowed windows go back to their Home"
                    case (.sceneOwned, true): return "1 scene window stays where it is"
                    case (.sceneOwned, false): return "\(count) scene windows stay where they are"
                    case (.sharedPersistent, true): return "1 shared window is not touched"
                    case (.sharedPersistent, false): return "\(count) shared windows are not touched"
                }
            }

            /// Whether this group offers the optional cleanup, which only owned windows can.
            ///
            /// Borrowed windows are going home and shared windows are not SceneMux's to touch, so offering to
            /// close either would be offering to break an invariant.
            var offersCleanup: Bool { ownership == .sceneOwned }
        }

        let sceneTitle: String
        /// Borrowed first, then owned, then shared: what moves, what stays, what is none of our business.
        let groups: [Group]

        /// The optional extra, and it is never the default.
        static let cleanupLabel = "also close these"
        /// Said on the checkbox itself, because it is the reason the checkbox is safe.
        ///
        /// Checking it does not close four windows on one click: each one is still asked for, individually, by
        /// the application that owns it. No single click in this product closes another application's windows.
        static let cleanupCaveat = "asks for each"

        var title: String { "Close “\(sceneTitle)”?" }
        var confirmTitle: String { "Close Scene" }
        var cancelTitle: String { "Cancel" }

        /// Whether closing this Scene will move any window at all.
        ///
        /// Not used to skip the confirmation — closing is a decision worth confirming even when the answer is
        /// "nothing moves" — but it is what lets the panel lead with the truth.
        var movesAnyWindow: Bool {
            groups.contains { $0.ownership == .borrowed && !$0.windows.isEmpty }
        }

        init(scene: Scene, naming: ApplicationNaming) {
            sceneTitle = scene.title
            let rows = scene.attachments.map { SceneShellWindowRow(attachment: $0, naming: naming) }
            groups = [Ownership.borrowed, .sceneOwned, .sharedPersistent].compactMap { ownership in
                let held = scene.attachments.filter { $0.ownership == ownership }.map(\.windowRef)
                let windows = rows.filter { held.contains($0.windowRef) }
                return windows.isEmpty ? nil : Group(ownership: ownership, windows: windows)
            }
        }
    }
}
