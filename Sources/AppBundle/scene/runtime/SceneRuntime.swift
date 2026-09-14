import AppKit
import Common
import SwiftUI

extension SceneCore {
    /// The one place the running app keeps its Scenes, and the only thing the UI and the commands talk to.
    ///
    /// It is a composition root, not a layer: it is the single file allowed to hold the lifecycle, the engine
    /// adapter and the presentation models at the same time, which is what keeps `scene/shell/` free of the
    /// engine and `scene/lifecycle/` free of AppKit. A menu item, a hotkey and `scenemux scene 3` are three
    /// ways to reach these methods and not three implementations of them — that duplication is exactly how a
    /// product ends up with two different ideas of what closing a task means.
    ///
    /// Every method that changes something ends the same way: ask the orchestrator (which saves before it
    /// believes), re-project if the Scene on screen changed, then rebuild the snapshot. Nothing here moves a
    /// window itself; the projector and the engine do that, and only for windows the Scene names.
    @MainActor
    final class SceneRuntime: ObservableObject {
        static let shared = SceneRuntime()

        /// Everything the surfaces draw, rebuilt after every change. One value, so they cannot disagree.
        @Published private(set) var snapshot: SceneShellSnapshot
        /// The last thing worth telling the user, until the HUD takes it.
        @Published private(set) var message: SceneShellMessage?

        /// How a command asks for a panel, registered by the UI at startup.
        ///
        /// Nothing is registered in a test or in a run with no surfaces, which is why every command that needs
        /// one checks: a `scene switcher` that returned success without opening anything would be a lie the
        /// user only discovers by looking at an unchanged screen.
        var presenter: (@MainActor (SceneShellRequest) -> Void)?

        private let engine: any SceneEnginePort
        private let projector: SceneProjector
        private let naming: ApplicationNaming
        private let orchestrator: SceneOrchestrator?
        /// Why there are no Scenes at all, when the reason is that state could not even be reached.
        private let unavailability: String?
        /// What the most recent projection had to say. Replaced, not accumulated: it describes the screen as it
        /// is now, and yesterday's normalization notice is not news.
        private var layoutDiagnostics: [String] = []

        /// The real thing: state in Application Support, the inherited engine, and the desktop for names.
        ///
        /// A store that cannot be located does not become a store somewhere else. Scenes are reported
        /// unavailable and every action refuses, because the alternative — quietly keeping Scenes in a
        /// temporary directory — would lose someone's Scenes at the next restart and look like a bug in
        /// persistence rather than the missing directory it is.
        init(
            store: SceneStateStore? = nil,
            engine: any SceneEnginePort = WinMuxSceneEngineAdapter(),
            naming: @escaping ApplicationNaming = SceneRuntime.desktopNaming,
        ) {
            var resolved = store
            var unavailability: String?
            if resolved == nil {
                do {
                    resolved = try SceneStateStore.inApplicationSupport()
                } catch {
                    unavailability = "SceneMux could not open its Application Support directory "
                        + "(\(error.localizedDescription)), so Scenes are unavailable. No windows were changed."
                }
            }
            self.engine = engine
            self.naming = naming
            self.unavailability = unavailability
            projector = SceneProjector(port: engine)
            orchestrator = resolved.map { SceneOrchestrator(store: $0) }
            snapshot = SceneShellSnapshot(
                world: .empty,
                diagnostics: unavailability.map { [$0] } ?? [],
                naming: naming,
            )
            refresh()
        }

        /// What the user is owed as soon as the app is up: a refusal, or the Scenes that lost windows.
        ///
        /// Read once by whatever shows the HUD, at startup, rather than posted from `init` — a message posted
        /// before there is a surface to show it is a message nobody sees.
        var startupMessages: [SceneShellMessage] {
            var messages = SceneShellMessage.onStartup(
                refusal: orchestrator?.stateRefusal,
                quarantined: orchestrator?.quarantined ?? [],
            )
            if let unavailability { messages.insert(.stateUnreadable(details: unavailability), at: 0) }
            return messages
        }

        /// The teardowns a previous run did not finish.
        ///
        /// Surfaced rather than executed. Carrying a restore out means moving another application's window,
        /// which is the work of the ticket that implements mounting and teardown execution; until then a Scene
        /// that was closing stays `restoring…` and says so, which is true, instead of being quietly marked
        /// finished on a promise nobody kept.
        var unfinishedTeardowns: [SceneTeardownPlan] {
            orchestrator?.unfinishedTeardowns ?? []
        }

        /// Define a Scene and hand back its row. Creating does not enter it.
        func createScene(title: String, template: SlotTemplate = .development) throws -> SceneShellSceneRow {
            let orchestrator = try requireOrchestrator()
            let scene = try orchestrator.createScene(title: title, slots: template.slots())
            refresh()
            guard let row = snapshot.scenes.first(where: { $0.id == scene.id }) else {
                throw SceneRuntimeError.noSceneNumbered(snapshot.scenes.count + 1)
            }
            return row
        }

        func rename(_ id: SceneId, to title: String) throws {
            try requireOrchestrator().rename(id, to: title)
            refresh()
        }

        /// Put a Scene on screen, leaving the current one first if there is one.
        ///
        /// The lifecycle refuses to swap two Scenes in a single step, on purpose: switching tasks is a decision
        /// the user should see rather than a side effect of a keystroke. Here — in the shell, where the
        /// keystroke actually happened — that decision has been made, so the leave is explicit and its own
        /// operation, and the HUD then names the Scene that arrived.
        func enter(_ id: SceneId) throws {
            let orchestrator = try requireOrchestrator()
            guard let substrate = engine.currentSubstrate() else { throw SceneRuntimeError.noSubstrate }
            if let active = orchestrator.world.activeScene, active.id != id {
                try orchestrator.leave(active.id)
            }
            try orchestrator.enter(id, on: substrate)
            reproject()
            refresh()
            guard let row = snapshot.scenes.first(where: { $0.id == id }) else { return }
            post(.entered(sceneTitle: row.title, slots: row.slots.count, windows: row.windowCount))
        }

        /// Take the Scene on screen off screen. Nothing moves, and nothing is said.
        func leave() throws {
            let orchestrator = try requireOrchestrator()
            guard let active = orchestrator.world.activeScene else { throw SceneRuntimeError.noActiveScene }
            try orchestrator.leave(active.id)
            layoutDiagnostics = []
            refresh()
        }

        /// What closing this Scene will do, to be shown before it is done.
        func closeSummary(for id: SceneId) throws -> SceneShellCloseSummary {
            let orchestrator = try requireOrchestrator()
            guard let scene = orchestrator.world.scene(id) else {
                throw SceneLifecycleError.unknownScene(id)
            }
            return SceneShellCloseSummary(scene: scene, naming: naming)
        }

        /// End a Scene, and hand back what its windows are owed.
        ///
        /// A Scene holding no windows is finished by this call. One holding borrowed windows keeps its
        /// attachments and stays `restoring…` until something carries the plan out, which is the honest state
        /// of affairs in this build rather than an oversight.
        @discardableResult
        func close(_ id: SceneId) throws -> SceneTeardownPlan {
            let orchestrator = try requireOrchestrator()
            let plan = try orchestrator.close(id)
            layoutDiagnostics = []
            refresh()
            return plan
        }

        /// Add a Slot to the Scene on screen. Moves no window; changes where the next one can go.
        @discardableResult
        func addSlot(role: SlotRole, label: String? = nil) throws -> Slot {
            let orchestrator = try requireOrchestrator()
            let slot = try orchestrator.addSlot(role: role, label: label, to: try requireActive().id)
            reproject()
            refresh()
            return slot
        }

        /// Take an empty Slot out of the Scene on screen.
        func removeSlot(_ slotId: SlotId) throws {
            let orchestrator = try requireOrchestrator()
            try orchestrator.removeSlot(slotId, from: try requireActive().id)
            reproject()
            refresh()
        }

        /// Move a Slot of the Scene on screen to its next shape, and re-project so the screen agrees.
        @discardableResult
        func cycleComposition(of slotId: SlotId) throws -> Slot {
            let orchestrator = try requireOrchestrator()
            let slot = try orchestrator.cycleComposition(of: slotId, in: try requireActive().id)
            reproject()
            refresh()
            return slot
        }

        /// The Scene the user means by a number, or a refusal naming the number they typed.
        func scene(numbered index: Int) throws -> SceneShellSceneRow {
            guard let row = snapshot.scene(at: index) else {
                throw SceneRuntimeError.noSceneNumbered(index)
            }
            return row
        }

        /// The Slot of the Scene on screen that the user means by a number.
        func slot(numbered index: Int) throws -> SceneShellSlotRow {
            guard let active = snapshot.activeScene else { throw SceneRuntimeError.noActiveScene }
            guard let row = active.slots.first(where: { $0.index == index }) else {
                throw SceneRuntimeError.noSlotNumbered(index)
            }
            return row
        }

        /// Show something once. Replaces whatever was showing: the HUD never stacks.
        func post(_ message: SceneShellMessage) {
            self.message = message
        }

        /// Esc, or the HUD's own dwell running out.
        func dismissMessage() {
            message = nil
        }

        private func requireOrchestrator() throws -> SceneOrchestrator {
            guard let orchestrator else {
                throw SceneRuntimeError.scenesUnavailable(
                    unavailability ?? "Scenes are unavailable, so nothing was changed.",
                )
            }
            return orchestrator
        }

        private func requireActive() throws -> Scene {
            guard let active = try requireOrchestrator().world.activeScene else {
                throw SceneRuntimeError.noActiveScene
            }
            return active
        }

        /// Draw the Scene on screen again, if there is one.
        ///
        /// Called after anything that changes what the active Scene's layout should be, and never after a
        /// change to a Scene that is not on screen: projecting a `defined` Scene would move windows for a task
        /// the user is not looking at.
        private func reproject() {
            guard let active = orchestrator?.world.activeScene,
                  case .active(let substrate) = active.state else { return }
            layoutDiagnostics = projector.project(SceneLayoutPlan(active, on: substrate)).diagnostics
        }

        private func refresh() {
            var diagnostics = unavailability.map { [$0] } ?? []
            diagnostics += orchestrator?.diagnostics ?? []
            diagnostics += layoutDiagnostics
            snapshot = SceneShellSnapshot(
                world: orchestrator?.world ?? .empty,
                diagnostics: diagnostics,
                naming: naming,
            )
        }

        /// How the desktop names an application: the running instance if it is running, its bundle otherwise.
        ///
        /// Nothing here reads a window, and nothing here can fail loudly — an application SceneMux cannot name
        /// still gets a row, under its bundle id. Only ever called while a snapshot is being built on the main
        /// actor, which is where AppKit wants these two questions asked.
        nonisolated static let desktopNaming: ApplicationNaming = { bundleId in
            if let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first,
               let name = running.localizedName {
                return name
            }
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
                return nil
            }
            return FileManager.default.displayName(atPath: url.path)
        }
    }
}
