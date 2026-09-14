import Foundation

/// The Scene switcher's own state, and the only place in the UI where a keystroke becomes a Scene operation.
///
/// It owns a `SceneRuntime` rather than reaching for the shared one, which is what lets these behaviours be
/// tested against a temporary state file: everything the panel can do, a test can do, in the same order, and
/// assert on the same snapshot the panel draws.
///
/// It holds no window, no `NSPanel` and no AppKit type at all. The panel above it turns key codes into calls
/// on this object and draws what it publishes; the decisions — what `⏎` means, whether Esc reverts or
/// dismisses, whether a name creates or renames — are all here, where they can be proven.
@MainActor
final class SceneSwitcherModel: ObservableObject {
    /// What has been typed to narrow the list. Changing it puts the selection back at the top, because the
    /// row that was selected is usually not the row that is now first.
    @Published var query: String = "" {
        didSet { if query != oldValue { selection = 0 } }
    }

    /// Which row of `results` is selected, 0-based. Clamped by `moveSelection`, never set past the end.
    @Published private(set) var selection: Int = 0

    /// What the panel is doing, and so what `⏎` and Esc mean.
    @Published private(set) var mode: SceneSwitcherMode = .browsing

    /// The last thing that could not be done, in the words the model uses. Cleared by the next action.
    @Published private(set) var errorText: String?

    /// The Scenes this panel reads and changes. Injected so a test can point it at a temporary state file.
    let runtime: SceneCore.SceneRuntime

    init(runtime: SceneCore.SceneRuntime) {
        self.runtime = runtime
    }

    /// Everything the panel draws, as of the last change. The runtime is the publisher; this is the read.
    var snapshot: SceneCore.SceneShellSnapshot { runtime.snapshot }

    /// The rows to show, in Scene order, narrowed by `query`.
    ///
    /// A Scene matches on its title, on its Slot labels and on the applications in it — the three things a
    /// user might remember about a task. Never on a window title: those are not in the snapshot at all, which
    /// is invariant I11 held one layer further out than the model.
    var results: [SceneCore.SceneShellSceneRow] {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return snapshot.scenes }
        return snapshot.scenes
            .compactMap { row in
                switcherPaletteFuzzyScore(needle, in: haystack(row)).map { (row, $0) }
            }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }

    /// The row a keystroke applies to, or nothing when the list is empty or filtered down to nothing.
    var selectedScene: SceneCore.SceneShellSceneRow? {
        results.indices.contains(selection) ? results[selection] : nil
    }

    /// `↑` and `↓`. Stops at the ends rather than wrapping: a list that wraps under the cursor loses the
    /// user's place, and there are nine numbers for jumping.
    func moveSelection(_ delta: Int) {
        let count = results.count
        guard count > 0 else { return }
        selection = min(max(selection + delta, 0), count - 1)
    }

    /// Clicking a row, or `⌘1…9`.
    func select(at index: Int) {
        guard results.indices.contains(index) else { return }
        selection = index
    }

    private func haystack(_ row: SceneCore.SceneShellSceneRow) -> String {
        ([row.title] + row.slots.map(\.title) + row.slots.flatMap { $0.windows.map(\.applicationName) })
            .joined(separator: " ")
            .lowercased()
    }
}
