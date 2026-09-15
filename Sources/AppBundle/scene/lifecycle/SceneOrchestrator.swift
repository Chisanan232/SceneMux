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

        /// Why this run started with no Scenes, when that is why it did.
        ///
        /// The same fact as the first diagnostic line, kept as a value as well, because a surface has to *do*
        /// different things for the two causes: a refusal offers to reveal the preserved file and says no
        /// windows were changed, where a first run invites the user to create a Scene. Recovering that
        /// distinction by reading English back out of a string is how a UI ends up inviting someone to build a
        /// new Scene on top of state SceneMux deliberately refused to touch.
        private(set) var stateRefusal: SceneStateRefusal?

        /// The attachments the load set aside, so a surface can say which Scene came back smaller.
        private(set) var quarantined: [SceneStateQuarantine]

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
            var stateRefusal: SceneStateRefusal? = switch load {
                case .refused(let refusal): refusal
                case .noStateFile, .loaded: nil
            }
            let world: SceneWorld
            do {
                world = try SceneWorld(scenes: load.scenes)
            } catch {
                world = .empty
                let refusal = store.preserving(SceneStateRefusal(
                    reason: .impossibleWorld("\(error)"),
                    path: store.url.path,
                    preservedAt: nil,
                ))
                stateRefusal = refusal
                diagnostics.append(refusal.diagnostic)
            }
            self.store = store
            self.world = world
            self.diagnostics = diagnostics
            self.stateRefusal = stateRefusal
            quarantined = switch load {
                case .loaded(_, let quarantined): quarantined
                case .noStateFile, .refused: []
            }
        }

        /// The teardowns a previous run did not finish, to be carried out again at startup.
        ///
        /// Read once the app is able to move windows, and not before. Each plan contains only the steps still
        /// owed, so re-running one cannot restore a window twice, and a machine that died mid-teardown ends up
        /// where it was going rather than half way there.
        var unfinishedTeardowns: [SceneTeardownPlan] {
            world.unfinishedTeardowns
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

        /// Give a Scene a different name.
        ///
        /// Available in every state, including while the Scene is on screen: the title is what a person reads
        /// and a task that turned out to be something else should be callable by its real name straight away.
        /// Nothing else changes — not the identity, not the Slots, and no window.
        func rename(_ id: SceneId, to title: String) throws {
            guard let scene = world.scene(id) else { throw SceneLifecycleError.unknownScene(id) }
            try apply(try world.replacing(try scene.renamed(to: title)))
        }

        /// Add a Slot to a Scene, and hand it back.
        ///
        /// Ordered last, because a Slot is added to the end of what the Scene already has — a new Slot is a
        /// new place, not a re-plan of the existing ones. It starts empty and `.single`: there is no geometry
        /// to ask for, and inventing a composition for a Slot with nothing in it would be a shape nobody
        /// chose. Adding a Slot moves no window, even while the Scene is on screen; what it changes is where
        /// the next window *can* go.
        func addSlot(role: SlotRole, label: String? = nil, to id: SceneId) throws -> Slot {
            guard let scene = world.scene(id) else { throw SceneLifecycleError.unknownScene(id) }
            let slot = Slot(
                id: .generate(),
                role: role,
                label: label,
                composition: .single,
                order: (scene.slots.map(\.order).max() ?? -1) + 1,
            )
            try apply(try world.replacing(try scene.addingSlot(slot)))
            return slot
        }

        /// Take an empty Slot out of a Scene.
        ///
        /// The undo for a Slot added by mistake, and no more than that: a Slot that still holds windows is
        /// refused by the domain rather than removed with their attachments, because an attachment is the
        /// record of what SceneMux may do to that window — including the promise to send a borrowed one home.
        /// Move the windows out first, which is a visible decision.
        func removeSlot(_ slotId: SlotId, from id: SceneId) throws {
            guard let scene = world.scene(id) else { throw SceneLifecycleError.unknownScene(id) }
            try apply(try world.replacing(try scene.removingSlot(slotId)))
        }

        /// Move a Slot on to the next shape it can have, and hand back the Slot as it now is.
        ///
        /// One operation rather than a setter, because that is what the shell offers: a single key that cycles
        /// a Slot through side by side, the other way round, stacked and plain. The returned Slot is what the
        /// caller tells the user about — and it is what the Scene asked for, not necessarily what the engine
        /// will settle on, which only a projection can report (`SceneLayoutReport`).
        func cycleComposition(of slotId: SlotId, in id: SceneId) throws -> Slot {
            guard let scene = world.scene(id) else { throw SceneLifecycleError.unknownScene(id) }
            guard let slot = scene.slot(slotId) else { throw SceneCoreError.unknownSlot(slotId) }
            let recomposed = slot.composed(as: slot.composition.cycled)
            try apply(try world.replacing(try scene.replacingSlot(recomposed)))
            return recomposed
        }

        /// Put a window into a Slot of a Scene, on stated terms, and hand back the attachment.
        ///
        /// The one way a window joins a Scene, whether the user called it mounting a chat window or claiming a
        /// terminal: the difference between those two is entirely `ownership`, which is what ending the Scene
        /// will be allowed to do about the window. Nothing here moves it — the caller has already decided where
        /// it came from and reports that as `originSurface`, and putting it into the Slot's layout is the
        /// projector's job.
        ///
        /// `home` and `originSurface` are asked of the caller rather than looked up, because this object cannot
        /// see either: the Home rule table is the user's configuration and the surface is a fact about the
        /// running engine. Both are recorded now because now is when they are still true — once the window is
        /// in the Scene, asking where it lives answers "in the Scene".
        func attach(
            _ windowRef: WindowRef,
            to slotId: SlotId,
            of id: SceneId,
            ownership: Ownership,
            home: SemanticHome,
            originSurface: SubstrateBinding?,
            origin: AttachmentOrigin = .userAction,
        ) throws -> Attachment {
            let attachment = Attachment(
                windowRef: windowRef,
                slotId: slotId,
                ownership: ownership,
                homeAtAttachTime: home,
                originSurface: originSurface,
                origin: origin,
            )
            try apply(try world.attaching(attachment, to: id))
            return attachment
        }

        /// Take a window out of a Scene, once whatever was owed to it has been done.
        ///
        /// Called *after* the window has been sent back, not before, which is the opposite order from `close`
        /// and for the same reason. A close writes its intent first because it has a plan to resume from; an
        /// unmount has none, so a state change written before the move would leave a window in the Scene's
        /// layout with nothing anywhere saying it belonged elsewhere. Detaching afterwards means the worst case
        /// is a window that is already home and still recorded as attached, and asking again puts it home
        /// again, which changes nothing.
        ///
        /// Read the attachment before calling this — through `SceneWorld.holder(of:)` — because the terms it
        /// carries are what said the restore was permitted, and they are gone once it is dropped.
        func detach(_ windowRef: WindowRef, from id: SceneId) throws {
            try apply(try world.detaching(windowRef, from: id))
        }

        /// Put a Scene on screen, projected onto this substrate.
        ///
        /// Pressing the same shortcut twice is not an error and does nothing the second time. Entering while a
        /// different Scene is on screen refuses, rather than switching tasks as a side effect nobody asked for.
        func enter(_ id: SceneId, on substrate: SubstrateBinding) throws {
            try apply(try world.entering(id, on: substrate))
        }

        /// Take a Scene off screen and leave every window exactly where it is.
        ///
        /// The cheap, common operation: switching away from a task and back again must not drag windows across
        /// the desktop and back. Nothing is restored, nothing is closed, and the Scene keeps every attachment.
        func leave(_ id: SceneId) throws {
            try apply(try world.leaving(id))
        }

        /// End a Scene, and hand back what its windows are owed.
        ///
        /// The plan is returned only once the intent to carry it out has been written. That order is the whole
        /// recovery story: a window is never moved on the strength of a decision a crash could erase, so at any
        /// moment the Scene either still owes a restore or has already had it, and never both or neither.
        ///
        /// Closing a Scene that is already closing hands back what is left to do rather than starting again,
        /// which is what makes retrying after a failure — or after a relaunch — safe to do as often as needed.
        func close(_ id: SceneId) throws -> SceneTeardownPlan {
            let closed = try world.closing(id)
            try apply(closed.world)
            return closed.plan
        }

        /// Record what actually happened to one window of a closing Scene.
        ///
        /// A `failed` outcome deliberately changes nothing: the attachment stays, so the restore is still owed
        /// and will be attempted again — after the app is less busy, or after a relaunch. Nothing here counts
        /// attempts, because the attachment is the count.
        ///
        /// A window deliberately left where it is produces a line for the user. It is the one teardown outcome
        /// that ends the Scene without keeping the promise the attachment stood for, and someone whose chat
        /// window stayed in a closed task's layout should be told that by SceneMux rather than find it later.
        func resolve(_ outcome: SceneTeardownOutcome, for windowRef: WindowRef, in id: SceneId) throws {
            let title = world.scene(id)?.title
            let before = world
            try apply(try world.resolving(outcome, for: windowRef, in: id))

            guard world != before, case .leftInPlace(let reason) = outcome, let title else { return }
            diagnostics.append(
                "SceneMux left \(windowRef) where it was when \"\(title)\" ended: \(reason).",
            )
        }

        /// Write this world, and only then believe in it.
        ///
        /// The order is the safety property. If the save fails, the change never happened as far as the rest of
        /// SceneMux is concerned: the caller gets the error, no plan is handed out, and no window is touched on
        /// the strength of a state change that is not on disk. The alternative — apply now, save if it works —
        /// is how a borrowed window gets moved into a Scene that will not exist after the next launch, with
        /// nothing left anywhere saying where it came from.
        ///
        /// A world identical to the current one is not written at all. Several operations here are deliberately
        /// no-ops — the same shortcut pressed twice, an outcome reported twice — and a no-op that can fail on a
        /// full disk is not a no-op.
        private func apply(_ next: SceneWorld) throws {
            guard next != world else { return }
            try store.save(next.scenes)
            world = next
        }
    }
}
