import Foundation

extension SceneCore {
    /// Everything a Scene surface draws, at one instant: the rows, what the menu bar says, and anything the
    /// user is owed an explanation for.
    ///
    /// One value rather than several published properties, because the sidebar, the switcher, the menu bar item
    /// and the command output must never disagree about which Scene is active. They read the same snapshot, so
    /// a stale menu bar title is not a thing that can happen.
    ///
    /// Closed Scenes are not rows. An `ended` Scene is kept in state as a record of a task that finished, and
    /// listing it would put a dead task in the way of live ones — and, worse, would give it a number, so
    /// `⌃⌥3` could enter something that cannot be entered. The numbers here are the numbers the user presses,
    /// which means they must only ever address Scenes that can be entered.
    struct SceneShellSnapshot: Equatable, Sendable {
        /// The Scenes worth showing, in world order, numbered from one.
        let scenes: [SceneShellSceneRow]
        /// The lines the UI is required to show: state that could not be read, windows that were let go.
        ///
        /// Required rather than logged. A Scene list that is silently empty because a file would not parse is
        /// indistinguishable from a broken app, and the user's own explanation for it will be worse than the
        /// truth.
        let diagnostics: [String]

        /// What the menu bar says when no Scene is on screen.
        static let noActiveSceneTitle = "No Scene"

        /// How much of a Scene title the menu bar shows before it is truncated in the middle.
        ///
        /// Middle truncation rather than trailing, because the distinguishing part of a task name is usually
        /// its end — `Debug PROD-123` and `Debug PROD-987` differ only there.
        static let menuBarTitleBudget = 28

        /// The Scene on screen, if there is one. At most one, guaranteed by `SceneWorld`.
        var activeScene: SceneShellSceneRow? { scenes.first(where: \.isActive) }

        var isEmpty: Bool { scenes.isEmpty }

        /// The active Scene's title, or `No Scene` — the one piece of Scene state that is always visible.
        var menuBarTitle: String {
            guard let activeScene else { return Self.noActiveSceneTitle }
            return Self.middleTruncated(activeScene.title, to: Self.menuBarTitleBudget)
        }

        /// First run, and after state was discarded: one line, and the shortcut that starts a Scene.
        ///
        /// Absent as soon as there is a Scene, and absent when there are diagnostics to show instead — being
        /// invited to create a Scene is the wrong sentence when the reason the list is empty is that the state
        /// file could not be read.
        var firstRunMessage: String? {
            guard isEmpty, diagnostics.isEmpty else { return nil }
            return "No scenes yet. A scene is one task: “Debug PROD-123”, “Review the release notes”. ⌃⌥N"
        }

        /// The Scene the user means by `⌃⌥3` or `scene 3`, or nothing if there is no third Scene.
        ///
        /// Out-of-range is a normal answer rather than an error: the keys are fixed at nine and the Scene list
        /// is whatever the user has, so pressing `⌃⌥7` with four Scenes has to be a no-op and not a crash.
        func scene(at index: Int) -> SceneShellSceneRow? {
            scenes.first { $0.index == index }
        }

        init(
            world: SceneWorld,
            diagnostics: [String] = [],
            homes: HomeRules,
            naming: ApplicationNaming,
        ) {
            scenes = world.scenes
                .filter { $0.state.label != .ended }
                .enumerated()
                .map { offset, scene in
                    SceneShellSceneRow(scene: scene, index: offset + 1, homes: homes, naming: naming)
                }
            self.diagnostics = diagnostics
        }

        /// `Debug the release candidate now` at a budget of 20 → `Debug the …idate now`.
        private static func middleTruncated(_ title: String, to budget: Int) -> String {
            guard title.count > budget, budget > 1 else { return title }
            let keep = budget - 1
            let head = keep - keep / 2
            return title.prefix(head) + "…" + title.suffix(keep / 2)
        }
    }
}
