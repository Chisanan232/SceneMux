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
        /// The running app's Scenes. Assignable so a test can point the commands at a temporary state file and a
        /// recording engine instead of the real ones — a test that wrote to Application Support would edit the
        /// Scenes of whoever ran it.
        static var shared = SceneRuntime()

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
        /// Home rules a test handed over, in place of the user's config.
        private let injectedHomes: HomeRules?
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
            homes: HomeRules? = nil,
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
            injectedHomes = homes
            self.naming = naming
            self.unavailability = unavailability
            projector = SceneProjector(port: engine)
            orchestrator = resolved.map { SceneOrchestrator(store: $0) }
            snapshot = SceneShellSnapshot(
                world: .empty,
                diagnostics: unavailability.map { [$0] } ?? [],
                homes: homes ?? HomeRules(overrides: config.sceneHome),
                naming: naming,
            )
            refresh()
        }

        /// Which Home each application belongs to.
        ///
        /// Read from the config on every use rather than captured once, so that editing `[scene-home]` and
        /// reloading takes effect on the next thing SceneMux says. Home policy lives in the user's own file and
        /// SceneMux never writes it back — a Home the app could change behind the user's editor is a Home
        /// neither of them owns.
        private var homes: HomeRules {
            injectedHomes ?? HomeRules(overrides: config.sceneHome)
        }

        /// The Home rules, for a surface that wants to *show* them. Read-only for the same reason `homes` is:
        /// there is one writer of Home policy and it is the person's config file.
        var homeRules: HomeRules { homes }

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
        /// Read, not executed: a Scene that was closing when the app stopped is `restoring…` until somebody
        /// carries the remaining steps out, and that is `resumeUnfinishedTeardowns()`.
        var unfinishedTeardowns: [SceneTeardownPlan] {
            orchestrator?.unfinishedTeardowns ?? []
        }

        /// Finish what a previous run left owed, and tell the user what happened to their windows.
        ///
        /// Called once, at startup, after the engine is up — a restore before the workspaces exist would aim a
        /// window at a surface the runtime has not seen yet. Nothing is decided here: the steps were derived from
        /// the attachments those Scenes still hold, so this only carries out promises that are already recorded
        /// and were already the user's decision.
        ///
        /// Safe to call when there is nothing owed, which is the ordinary case: it moves nothing and says
        /// nothing. A restore that fails again stays owed and will be attempted at the next launch, without
        /// anything having counted the attempts.
        @discardableResult
        func resumeUnfinishedTeardowns() -> [SceneShellMessage] {
            guard let orchestrator else { return [] }
            var messages: [SceneShellMessage] = []
            for plan in orchestrator.unfinishedTeardowns {
                let outcomes = carryOut(plan, with: orchestrator)
                messages += SceneShellMessage.onClose(plan, outcomes: outcomes, homes: homes, naming: naming)
            }
            guard !messages.isEmpty else { return [] }
            refresh()
            return messages
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
            return SceneShellCloseSummary(scene: scene, homes: homes, naming: naming)
        }

        /// End a Scene: send its borrowed windows home, leave everything else alone, and say what happened.
        ///
        /// The intent is written before anything moves and each outcome is recorded as it happens, so a crash
        /// half way through leaves a Scene that still owes exactly the restores it has not done. A window whose
        /// restore failed keeps its attachment, which is why closing again — or simply launching again — is the
        /// retry.
        ///
        /// Nothing is closed here, for any ownership, on any outcome (invariant I6). The windows the Scene owns
        /// stay open and the user is told so, in the same breath as being told which windows went home.
        @discardableResult
        func close(_ id: SceneId) throws -> SceneTeardownPlan {
            let orchestrator = try requireOrchestrator()
            let plan = try orchestrator.close(id)
            layoutDiagnostics = []
            let outcomes = carryOut(plan, with: orchestrator)
            refresh()
            post(SceneShellMessage.onClose(plan, outcomes: outcomes, homes: homes, naming: naming))
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

        /// Put the window the user is looking at into a Slot of the Scene on screen.
        ///
        /// Borrowed by default, because that is the reversible half of the bargain: the window goes back where
        /// it came from when the task ends. `.sceneOwned` is the explicit other branch — `--own`, or `⌥` on the
        /// drop — and it is a claim about the window, not a convenience, so it is never inferred from anything.
        ///
        /// Two facts are recorded now because now is the only time they are true: the Home the rules give the
        /// application, and the surface the window is on. Once the window is in the Scene, asking where it lives
        /// answers "in the Scene", and the way back would be gone.
        ///
        /// Nothing is focused or raised to do this. The window is already the one in front of the user; the
        /// projection that follows puts it in its Slot, and the user stays where they are.
        @discardableResult
        func mount(into slotId: SlotId, ownership: Ownership = .borrowed) throws -> SceneShellWindowRow {
            let orchestrator = try requireOrchestrator()
            let active = try requireActive()
            guard let windowRef = engine.focusedWindow() else { throw SceneRuntimeError.noFocusedWindow }
            let attachment = try orchestrator.attach(
                windowRef,
                to: slotId,
                of: active.id,
                ownership: ownership,
                home: homes.home(of: windowRef),
                originSurface: engine.surface(of: windowRef),
            )
            reproject()
            refresh()
            return SceneShellWindowRow(attachment: attachment, homes: homes, naming: naming)
        }

        /// Give a window back and take it out of its Scene.
        ///
        /// The move happens first and the state changes after, which is the opposite order from closing a Scene
        /// and deliberately so — see `SceneOrchestrator.detach`. A restore that is still owed leaves the
        /// attachment exactly where it was, so asking again later is the retry and there is no counter to lose.
        ///
        /// A `.sharedPersistent` window is refused out loud instead of being moved. That ownership means the
        /// user said this window is nobody's task, and invariant I7 makes it the one thing here that is not
        /// SceneMux's to touch — so the answer is the HUD line saying so, and no window moves.
        @discardableResult
        func unmount(_ windowRef: WindowRef) throws -> SceneTeardownOutcome {
            let orchestrator = try requireOrchestrator()
            guard let holder = orchestrator.world.holder(of: windowRef) else {
                throw SceneRuntimeError.windowNotInAScene
            }
            guard holder.attachment.ownership != .sharedPersistent else {
                post(.sharedWindowSkipped(applicationName: naming(windowRef.bundleId) ?? windowRef.bundleId))
                return .leftInPlace(reason: "it is shared")
            }
            let outcome = SceneRestorer(port: engine).restore(SceneTeardownStep(holder.attachment))
            guard outcome.isFinal else { return outcome }
            try orchestrator.detach(windowRef, from: holder.scene.id)
            reproject()
            refresh()
            return outcome
        }

        /// Give back the window the user is looking at.
        ///
        /// The counterpart of `mount`, and the same reason for existing: a surface that acts on "the focused
        /// window" must not have to construct a `WindowRef` of its own, because a `WindowRef` assembled by a
        /// caller is a caller that can name a window the engine never saw.
        ///
        /// The row is built *before* the window is given back, so the reply can name the application and the
        /// Home of an attachment that no longer exists a line later.
        @discardableResult
        func unmountFocusedWindow() throws -> (window: SceneShellWindowRow, outcome: SceneTeardownOutcome) {
            let orchestrator = try requireOrchestrator()
            guard let windowRef = engine.focusedWindow() else { throw SceneRuntimeError.noFocusedWindow }
            guard let holder = orchestrator.world.holder(of: windowRef) else {
                throw SceneRuntimeError.windowNotInAScene
            }
            let window = SceneShellWindowRow(attachment: holder.attachment, homes: homes, naming: naming)
            return (window, try unmount(windowRef))
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

        /// Show several things, in the order they matter.
        ///
        /// The HUD is what queues them — it shows one at a time and waits for each to go — so this publishes
        /// them one after another rather than deciding which of them the user gets to see. Nothing is merged:
        /// "your chat windows went home" and "your editor is still open" are two different reassurances.
        func post(_ messages: [SceneShellMessage]) {
            for message in messages { post(message) }
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

        /// Carry out every restore a plan still owes, recording each outcome before attempting the next.
        ///
        /// Recorded one at a time on purpose: the state on disk is the only thing that survives a crash, and a
        /// batch written at the end would leave a window already home and still recorded as owed — which the
        /// next run would "restore" a second time, moving a window the user had since put somewhere else.
        ///
        /// A failed record is not a failed restore. The window is where it should be either way, so the loop
        /// carries on to the other windows and the attachment simply stays, which means the same restore is
        /// attempted again later. Giving up on the rest of somebody's chat windows because one write failed
        /// would be the worse of the two outcomes.
        private func carryOut(
            _ plan: SceneTeardownPlan,
            with orchestrator: SceneOrchestrator,
        ) -> [WindowRef: SceneTeardownOutcome] {
            let restorer = SceneRestorer(port: engine)
            var outcomes: [WindowRef: SceneTeardownOutcome] = [:]
            for step in plan.pending {
                let outcome = restorer.restore(step)
                outcomes[step.windowRef] = outcome
                try? orchestrator.resolve(outcome, for: step.windowRef, in: plan.sceneId)
            }
            return outcomes
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
                homes: homes,
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
