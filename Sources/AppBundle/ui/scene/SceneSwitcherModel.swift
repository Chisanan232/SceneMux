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

    /// The name being typed, while a Scene is being created or renamed. Bound to the one inline field.
    @Published var nameField: String = ""

    /// Which Slots a Scene created here starts with. Two choices, because a template picker is Phase 2 work.
    @Published var template: SceneCore.SlotTemplate = .development

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

    /// `⏎`, a click on a row, or `⌘1…9`: put the selected Scene on screen.
    ///
    /// Returns whether the panel is finished — true when the Scene was entered, so the caller can dismiss.
    /// A refusal keeps the panel up with the reason on it: the user pressed a key expecting their screen to
    /// change, and a panel that vanished silently would leave them with no idea why it did not.
    @discardableResult
    func enterSelected() -> Bool {
        guard let row = selectedScene else { return false }
        return enter(row.id)
    }

    @discardableResult
    func enter(_ id: SceneCore.SceneId) -> Bool {
        act { try runtime.enter(id) }
    }

    /// `⌃⌥N`, `+ New Scene`, or typing a name that matches nothing.
    ///
    /// The field starts as whatever narrowed the list, because that is almost always the name the user was
    /// looking for and did not find — typing `Debug PROD-124`, seeing nothing, and pressing the create key
    /// should not mean typing it again.
    func beginCreate() {
        errorText = nil
        nameField = query.trimmingCharacters(in: .whitespaces)
        mode = .creating
    }

    /// `F2`, a second `⏎`, or a double-click on a title.
    func beginRename() {
        guard let row = selectedScene else { return }
        errorText = nil
        nameField = row.title
        mode = .renaming(row.id)
    }

    /// `⏎` in the field: create the Scene, or commit the new title.
    ///
    /// Creating does not enter — that is the design's word on it, and it is what makes creating a Scene free:
    /// nothing on the user's screen moves. An empty name is not an error, it is a change of mind, so it goes
    /// back to browsing without a complaint.
    func commitName() {
        let title = nameField.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return cancelEditing() }
        switch mode {
            case .creating:
                guard act({ _ = try runtime.createScene(title: title, template: template) }) else { return }
                query = ""
                mode = .browsing
                selectNewest(titled: title)
            case .renaming(let id):
                guard act({ try runtime.rename(id, to: title) }) else { return }
                mode = .browsing
            case .browsing, .confirmingClose:
                break
        }
    }

    /// `⌘⌫` on a row, or `⌃⌥⌫` for the Scene on screen: show what closing would do, and stop there.
    ///
    /// Nothing is closed by this call, and that is the point — the summary the panel then shows is the model's
    /// own reasoning about ownership, which is what lets the user predict the outcome instead of clicking
    /// through a warning.
    func beginClose(_ id: SceneCore.SceneId? = nil) {
        errorText = nil
        guard let target = id ?? selectedScene?.id else { return }
        var summary: SceneCore.SceneShellCloseSummary?
        guard act({ summary = try runtime.closeSummary(for: target) }), let summary else { return }
        mode = .confirmingClose(target, summary)
    }

    /// The confirmation's *Close Scene* button. The only call in this model that ends a task.
    ///
    /// The design's *also close these* checkbox is deliberately absent rather than present and inert. Closing
    /// another application's windows means asking that application, per window, and this build has no
    /// attachments to ask about — a checkbox that changed nothing would be worse than one that is not there.
    func confirmClose() {
        guard case .confirmingClose(let id, _) = mode else { return }
        guard act({ try runtime.close(id) }) else { return }
        mode = .browsing
        selection = min(selection, max(results.count - 1, 0))
    }

    /// Esc in an editing state: back to the list, with nothing changed. Reverting, not committing.
    func cancelEditing() {
        nameField = ""
        errorText = nil
        mode = .browsing
    }

    /// Esc. Returns whether the panel should dismiss.
    ///
    /// One key, two meanings, and the order matters: in any state that is part-way through something — a name
    /// being typed, a close being considered — Esc abandons *that* and leaves the panel up. Only a panel that
    /// is merely browsing is dismissed by it. A single Esc that both cancelled an edit and closed the panel
    /// would make the user reopen it to see whether the edit had been committed.
    func escape() -> Bool {
        switch mode {
            case .browsing:
                return true
            case .creating, .renaming, .confirmingClose:
                cancelEditing()
                return false
        }
    }

    /// Put the selection on a Scene that was just created, so the next `⏎` enters the thing that was named.
    private func selectNewest(titled title: String) {
        guard let index = results.lastIndex(where: { $0.title == title }) else { return }
        selection = index
    }

    /// Runs a Scene operation, and turns whatever it refuses into a line the panel can show.
    ///
    /// Every error the runtime raises is already written to be shown as it is — that is what
    /// `SceneRuntimeError` and its siblings are for — so there is nothing to translate here and nothing worth
    /// logging: the user is the one who needs to know.
    private func act(_ body: () throws -> Void) -> Bool {
        errorText = nil
        do {
            try body()
            return true
        } catch let error as SceneCore.SceneRuntimeError {
            errorText = error.description
        } catch let error as SceneCore.SceneLifecycleError {
            errorText = error.description
        } catch let error as SceneCore.SceneCoreError {
            errorText = error.description
        } catch {
            errorText = error.localizedDescription
        }
        return false
    }

    private func haystack(_ row: SceneCore.SceneShellSceneRow) -> String {
        ([row.title] + row.slots.map(\.title) + row.slots.flatMap { $0.windows.map(\.applicationName) })
            .joined(separator: " ")
            .lowercased()
    }
}
