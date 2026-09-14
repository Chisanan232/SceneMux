import Foundation

extension SceneCore {
    /// The one thing in SceneMux that changes a Scene.
    ///
    /// Everything above it — a menu item, a hotkey, the sidebar, a command — asks this object, and this object
    /// owns both the world and the file it lives in. That is the point: a lifecycle reachable from three places
    /// is a lifecycle with three slightly different ideas of what closing a task means, and the difference
    /// shows up as somebody's chat window left in the wrong place.
    ///
    /// It is deliberately not a window manager. No method here moves, resizes, focuses or closes anything; the
    /// closest it comes is handing back a plan of what the windows are owed. Executing that plan belongs to the
    /// Accessibility layer, which reports back through `resolve(_:for:in:)`.
    @MainActor
    final class SceneOrchestrator {
        private let store: SceneStateStore

        /// Every Scene, as it stands right now. Only this object may replace it.
        private(set) var world: SceneWorld

        /// The lines the UI is required to show, oldest first.
        ///
        /// Kept rather than logged, because every one of them is about state the user is missing or a window
        /// that did not move. Dropping them into a log file is how "SceneMux forgot my Scenes" becomes
        /// indistinguishable from "SceneMux is broken".
        private(set) var diagnostics: [String]

        /// Start from whatever is on disk, and start safe when that cannot be trusted.
        ///
        /// Three outcomes, and only one of them has Scenes in it. A file that cannot be read yields no Scenes
        /// and a diagnostic — invariant I9 — and so does a file that decodes perfectly but describes Scenes
        /// that cannot all be true, such as two saved as being on screen. The second case is discovered here
        /// rather than in the store, so it is refused here too: with a copy of the bytes kept out of the way of
        /// the next save, by the store's own copy-aside, so that starting safe never means starting destructive.
        init(store: SceneStateStore) {
            let load = store.load()
            var diagnostics = load.diagnostics
            let world: SceneWorld
            do {
                world = try SceneWorld(scenes: load.scenes)
            } catch {
                world = .empty
                let refusal = SceneStateRefusal(
                    reason: .impossibleWorld("\(error)"),
                    path: store.url.path,
                    preservedAt: nil,
                )
                diagnostics.append(store.preserving(refusal).diagnostic)
            }
            self.store = store
            self.world = world
            self.diagnostics = diagnostics
        }

        /// Define a new Scene: named, off screen, holding no windows.
        ///
        /// Returns the Scene rather than only its identity, so a caller that has just made one does not have to
        /// go looking in the world for it and cannot look in the wrong one.
        func createScene(title: String, slots: [Slot] = []) throws -> Scene {
            let created = try world.creating(title: title, slots: slots)
            try apply(created.world)
            return created.scene
        }

        /// Write this world, and only then believe in it.
        ///
        /// The order is the safety property. If the save fails, the change never happened as far as the rest of
        /// SceneMux is concerned: the caller gets the error, no plan is handed out, and no window is touched on
        /// the strength of a state change that is not on disk. The alternative — apply now, save if it works —
        /// is how a borrowed window gets moved into a Scene that will not exist after the next launch, with
        /// nothing left anywhere saying where it came from.
        private func apply(_ next: SceneWorld) throws {
            try store.save(next.scenes)
            world = next
        }
    }
}
