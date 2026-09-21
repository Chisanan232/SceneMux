import AppKit
import Common

extension SceneCore {
    /// The one file in SceneMux that speaks both languages: Scenes on the way in, the inherited WinMux tree
    /// on the way out.
    ///
    /// Everything the engine knows about tiling stops here. `scene/domain/` and `scene/lifecycle/` name no
    /// engine type at all (invariant I12) and `script/test_scene_domain_layering.py` keeps them honest; this
    /// adapter is the deliberate exception, so that there is exactly one place to look when the engine
    /// changes underneath us and exactly one place to change.
    ///
    /// What it does is narrow on purpose. It binds windows into containers and it reads back what shape they
    /// ended up in. It computes no frames, picks no monitor, focuses nothing and closes nothing — the
    /// inherited engine is better at geometry than any Scene could be, and a Scene that started choosing
    /// rectangles would stop surviving a display change.
    ///
    /// Physically moving the windows is left to the engine's own layout pass, which runs after any tree
    /// change: this adapter mutates the tree and normalizes it, exactly as the inherited commands do, and the
    /// refresh that follows does the moving.
    @MainActor
    final class WinMuxSceneEngineAdapter: SceneEnginePort {
        /// The containers this projection built, by Slot, so `settle` can ask what became of them.
        ///
        /// Per-projection scratch, cleared by `prepareSubstrate`, and never a source of truth: Slot identity
        /// lives in Scene state, because a container can be flattened away and an empty Slot has no
        /// container to be identified by in the first place.
        private var builtContainers: [SlotId: TilingContainer] = [:]
        /// Slots whose windows went straight into the substrate root, and so are a single window by shape.
        private var flattenedSlots: Set<SlotId> = []

        /// Which window each `WindowRef` was minted for, for as long as this process runs.
        ///
        /// A `WindowRef` is a position — an application and an ordinal — and a position is not an identity: when
        /// a window closes, every window of that application behind it moves up one, and the ref that named the
        /// closed window now points at its neighbour. Resolving it would hand a Scene a window it never took.
        ///
        /// So the ordinal is remembered alongside the window id it meant at the moment the ref was made, and
        /// `resolve(_:)` refuses a window that disagrees. Deliberately *not* persisted: a window id means
        /// nothing after a restart, and invariant I11 keeps ids out of Scene state. Across a restart there is
        /// no claim to check against and resolution is positional again, which is the limitation
        /// `docs/design/scene-core-architecture.md` records rather than hides.
        private static var mintedIdentities: [WindowRef: UInt32] = [:]

        init() {}

        /// The focused workspace, which is where a Scene entered now would appear.
        ///
        /// The focused one rather than a Scene-specific one on purpose: entering a Scene lays its windows out
        /// in front of the person who asked, not on a workspace they would then have to go and find. A blank
        /// name is refused for the same reason `prepareSubstrate` refuses one.
        func currentSubstrate() -> SubstrateBinding? {
            let name = focus.workspace.name
            guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return SubstrateBinding(workspaceName: name)
        }

        /// The focused window, described the way Scene state describes windows.
        ///
        /// Nothing is focused, raised or activated to answer this — it reads the focus the engine already has,
        /// which is why "mount the window I am looking at" does not disturb the window it is about.
        func focusedWindow() -> WindowRef? {
            focus.windowOrNil.flatMap(Self.reference)
        }

        /// The workspace a window sits on, named the way a Scene can record it.
        ///
        /// A window with no workspace at all — floating, or in a tree the engine has not settled yet — has no
        /// surface to report, and a blank workspace name is refused exactly as `prepareSubstrate` refuses one:
        /// a recorded destination nobody can name is worse than none, because a restore would aim at it.
        func surface(of windowRef: WindowRef) -> SubstrateBinding? {
            resolve(windowRef).flatMap(Self.surface)
        }

        /// The same answer for a window the caller already has, which is the shape the detection hook needs.
        static func surface(of window: Window) -> SubstrateBinding? {
            guard let name = window.nodeWorkspace?.name,
                  !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { return nil }
            return SubstrateBinding(workspaceName: name)
        }

        /// What the window is on the surface it is on: tiled with its neighbours, or floating above them.
        ///
        /// Derived from the kind the engine already assigned rather than asked separately, so there is exactly
        /// one place in SceneMux that reads a window's parent to decide what the window is. A window macOS has
        /// put aside — minimized, natively fullscreen, hidden with its application — has no answer here, and
        /// nothing is recorded for it: see `AdmissionWindowKind.arrangement`.
        func arrangement(of windowRef: WindowRef) -> WindowArrangement? {
            resolve(windowRef).flatMap { Self.kind(of: $0).arrangement }
        }

        /// What the engine has already decided this window is, read off where it bound it.
        ///
        /// The mapping is one-to-one with the containers the engine has, which is the point: this cannot drift
        /// from the engine's own classification, because it *is* the engine's own classification. A window in
        /// the tiling tree is the work; a window the engine hung straight on the workspace is floating, which is
        /// what it does with dialogs and with anything the user's own float rules exclude; the popup container
        /// holds menus and completion lists; and the remaining three containers are macOS's business — a
        /// minimized window, a natively fullscreen one, or one hidden with its application.
        ///
        /// A window with no parent at all is nowhere the engine is holding it, so there is nothing to move and
        /// the answer is the same as for anything else SceneMux may not touch.
        static func kind(of window: Window) -> AdmissionWindowKind {
            switch window.parent?.kind {
                case .tilingContainer: .managed
                case .workspace: .floating
                case .macosPopupWindowsContainer: .popup
                case .macosMinimizedWindowsContainer,
                     .macosFullscreenWindowsContainer,
                     .macosHiddenAppsWindowsContainer,
                     nil: .setAside
            }
        }

        /// Resolves the Scene's workspace, creating it if the user has not used it yet.
        ///
        /// A blank name is refused rather than normalized into something plausible: the engine would happily
        /// register a workspace called `" "`, and a Scene bound to it would be projected somewhere the user
        /// can neither see nor name.
        func prepareSubstrate(_ binding: SubstrateBinding) -> Bool {
            builtContainers = [:]
            flattenedSlots = []
            guard !binding.workspaceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return false
            }
            _ = Workspace.get(byName: binding.workspaceName).rootTilingContainer
            return true
        }

        /// Moves one window onto one workspace, the way the inherited engine moves one.
        ///
        /// Built out of `workspaceAppendBindingData` and `bind`, which is what `MoveNodeToWorkspaceCommand`
        /// does — minus its focus handling. That omission is the point: a borrowed chat window going home at
        /// the end of a task must not pull the user onto the workspace it went to, and neither must a window
        /// arriving in a Slot pull them away from the one they are on.
        ///
        /// An unregistered workspace is `surfaceIsGone` rather than a workspace created on the spot. The
        /// engine would happily register any name, and a restore aimed at a workspace conjured up to receive
        /// it is the one thing invariant I8 is not allowed to do — the window would be "home" somewhere the
        /// user has never seen.
        ///
        /// A window already on that workspace *as what the caller asked for* answers `moved`, because the
        /// caller asked for a state and the state is true. Rebinding it anyway would reorder the windows
        /// already there for no reason. A window on the right workspace and the wrong side of the
        /// floating/tiled line is not in the asked-for state, so it is rebound — which is the whole of
        /// returning a borrowed window as what it was rather than merely to where it was.
        ///
        /// The arrangement is carried out by choosing what to bind the window to, because in this engine that
        /// *is* the difference: a window whose parent is the workspace floats above it, and one whose parent is
        /// a tiling container is laid out inside it. There is no second step that could fail on its own, and
        /// nothing here sets a size or a position — the arrangement is a mode, never a frame (invariant I11).
        func move(
            _ windowRef: WindowRef,
            to binding: SubstrateBinding,
            as arrangement: WindowArrangement?,
        ) -> SceneWindowMove {
            guard let window = resolve(windowRef) else { return .windowIsGone }
            guard let workspace = Workspace.existing(byName: binding.workspaceName) else {
                return .surfaceIsGone(reason: "workspace \"\(binding.workspaceName)\" does not exist any more")
            }
            let wanted = arrangement ?? Self.currentArrangement(of: window)
            guard window.nodeWorkspace != workspace || wanted != Self.currentArrangement(of: window) else {
                return .moved
            }

            switch wanted {
                case .floating:
                    window.bindAsFloatingWindow(to: workspace)
                case .tiled:
                    let target = workspaceAppendBindingData(targetWorkspace: workspace, index: INDEX_BIND_LAST)
                    window.bind(to: target.parent, adaptiveWeight: target.adaptiveWeight, index: target.index)
            }
            return window.nodeWorkspace == workspace
                ? .moved
                : .failed(reason: "the engine did not accept the window onto \"\(binding.workspaceName)\"")
        }

        /// What the inherited engine would call this window's arrangement right now.
        ///
        /// Deliberately the engine's own `isFloating` question rather than `kind(of:)`, and the difference is
        /// the point: `kind(of:)` answers nothing for a window macOS has minimized, fullscreened or hidden,
        /// whereas a move needs *some* answer for every window in order to leave one nobody recorded an
        /// arrangement for behaving exactly as it did before any of this was recorded.
        private static func currentArrangement(of window: Window) -> WindowArrangement {
            window.isFloating ? .floating : .tiled
        }

        /// Builds one Slot by binding its windows into the substrate, appending after whatever is already
        /// there.
        ///
        /// Appending is what keeps invariant I15 true: windows already in this workspace that the Scene never
        /// mentioned are not rebound, not reordered relative to each other and not moved out — they are
        /// simply passed over. The Scene's own Slots then arrive in call order, which is Slot order.
        func place(_ group: SceneLayoutGroup, on binding: SubstrateBinding) -> SceneSlotPlacement {
            var windows: [Window] = []
            var missing: [WindowRef] = []
            for windowRef in group.windows {
                if let window = resolve(windowRef) {
                    windows.append(window)
                } else {
                    missing.append(windowRef)
                }
            }
            guard !windows.isEmpty else { return .windowsMissing(missing) }

            let root = tilesRoot(of: Workspace.get(byName: binding.workspaceName))
            let composition: SlotComposition
            if group.needsContainer, windows.count > 1 {
                // Built the way `JoinWithCommand` builds one, which is the only mechanism the engine
                // actually has: `split` is a no-op while flatten-containers normalization is on, as
                // `docs/development/baseline-verification.md` measured on this machine.
                let container = TilingContainer(
                    parent: root,
                    adaptiveWeight: WEIGHT_AUTO,
                    orientation(for: group.composition, under: root),
                    layout(for: group.composition),
                    index: INDEX_BIND_LAST,
                )
                builtContainers[group.slotId] = container
                for window in windows {
                    window.bind(to: container, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
                }
                composition = self.composition(of: container)
            } else {
                // One window needs no container, and would not keep one: normalization flattens a container
                // down to its only child. A `.single` Slot holding several windows also lands here, because
                // a Slot that says it does not compose its windows gets them side by side.
                flattenedSlots.insert(group.slotId)
                for window in windows {
                    window.bind(to: root, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
                }
                composition = .single
            }
            return missing.isEmpty
                ? .realised(composition)
                : .partlyRealised(composition, missing: missing)
        }

        /// The container a Slot may be bound into: a tiles container, never a tab group.
        ///
        /// A workspace whose only occupied Slot is tabbed ends up with nothing but that tab group, and
        /// flatten-containers normalization then promotes it to *be* the root container. Everything bound to
        /// the root after that becomes another tab, which is how a Slot came to be built inside somebody
        /// else's tab group: on the real desktop the Scene's second window was left parked off-screen at the
        /// inactive-tab position, still listed by `slot list`, and re-entering the Scene did not bring it
        /// back. A Slot is a region of the screen, so it cannot be a tab of something else.
        ///
        /// The engine has the same problem with its own new windows and solves it the same way —
        /// `ensureTabGroupAnchorHasWorkspaceRootContainer` in `NewWindowBinding.swift` — except that the tab
        /// group is kept as the first tile of the new root here, because the windows in it are somebody's
        /// windows and dropping them out of the tree is the failure this is fixing.
        private func tilesRoot(of workspace: Workspace) -> TilingContainer {
            let root = workspace.rootTilingContainer
            guard root.layout == .tabGroup else { return root }
            root.unbindFromParent()
            let tiles = TilingContainer(
                parent: workspace,
                adaptiveWeight: WEIGHT_AUTO,
                root.orientation.opposite,
                .tiles,
                index: 0,
            )
            root.bind(to: tiles, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
            return tiles
        }

        /// Lets the engine normalize what was just built, then reports the shape each Slot really has.
        ///
        /// Normalization is run rather than avoided. The user's own settings decide whether a nested
        /// container keeps the orientation it was asked for — opposite-orientation normalization is on by
        /// default and flips a nested container that matches its parent — and a projection that fought that
        /// would only lose the argument on the next normalization pass, leaving the screen disagreeing with
        /// both the configuration and the report. So SceneMux normalizes, looks, and reports what it sees.
        ///
        /// Structure only: which Slots are split, tabbed or plain. Never geometry.
        func settle(_ binding: SubstrateBinding) -> [SlotId: SlotComposition] {
            guard let workspace = Workspace.existing(byName: binding.workspaceName) else { return [:] }
            workspace.normalizeContainers()

            var result: [SlotId: SlotComposition] = [:]
            for slotId in flattenedSlots {
                result[slotId] = .single
            }
            for (slotId, container) in builtContainers {
                // A container the engine dissolved leaves its windows where it was, side by side, so the
                // Slot really is a single-window Slot now however it was asked for.
                result[slotId] = container.parent == nil ? .single : composition(of: container)
            }
            return result
        }

        /// Finds the window a `WindowRef` means, or nothing.
        ///
        /// The ref is `bundleId` plus the window's ordinal within its application, so resolution has to pick
        /// an order for an app's windows and stick to it. Window id ascending is that order: it is stable
        /// across a projection, it is the same order the engine assigns as windows appear, and it does not
        /// depend on the tree — which is the thing being rebuilt.
        ///
        /// A ref this process made is checked against the window it was made for, and a different window at the
        /// same ordinal is treated as absence rather than as a target. That is the whole of it: a borrowed
        /// window whose lower-numbered sibling has closed is *gone*, and the sibling that inherited its ordinal
        /// is not sent to a Home it never came from. Restoring the wrong window is worse than restoring none.
        ///
        /// Nothing is created, launched or focused here. A window that is not there is simply not there, and
        /// invariant I10 has SceneMux leave it at that.
        private func resolve(_ windowRef: WindowRef) -> Window? {
            let candidates = Self.inventory
                .filter { $0.app.rawAppBundleId == windowRef.bundleId }
                .sorted { $0.windowId < $1.windowId }
            guard let window = candidates.getOrNil(atIndex: windowRef.ordinalWithinApp) else { return nil }
            if let minted = Self.mintedIdentities[windowRef], minted != window.windowId { return nil }
            return window
        }

        /// Describes an engine window as a `WindowRef`, the exact inverse of `resolve(_:)`.
        ///
        /// Both directions have to agree on one thing — the order an application's windows are in — or a ref
        /// made here would resolve back to a different window. So the ordinal is computed from the same
        /// window-id-ascending order, from the same inventory, in one place: this file.
        ///
        /// Nothing to describe it with means no ref. An application with no bundle id — a helper process, a
        /// system panel — cannot be named in a way that survives a restart, and inventing a name for it is
        /// how a Scene comes back pointing at whatever happens to be there next time.
        ///
        /// Static because the window-detection hook needs it and has no adapter to hand: it is called from the
        /// engine's own detection path, not from a projection. Nothing here reads the instance, and it must
        /// stay that way — a description that depended on which projection was running would not be the
        /// inverse of anything.
        static func reference(_ window: Window) -> WindowRef? {
            guard let bundleId = window.app.rawAppBundleId else { return nil }
            let ordinal = Self.inventory
                .filter { $0.app.rawAppBundleId == bundleId }
                .sorted { $0.windowId < $1.windowId }
                .firstIndex { $0.windowId == window.windowId }
            guard let ordinal else { return nil }
            guard let ref = try? WindowRef(bundleId: bundleId, ordinalWithinApp: ordinal) else { return nil }
            // The one moment this ordinal is known to mean this window. Recorded here so that `resolve(_:)`
            // can tell later that it no longer does.
            mintedIdentities[ref] = window.windowId
            return ref
        }

        /// Forgets which window every ref meant, so one test's windows cannot answer another test's refs.
        ///
        /// Test-only, and the reason the map is not reset anywhere in the product: within one run, forgetting
        /// is exactly the mistake — a forgotten ref resolves positionally again and can pick the wrong window.
        static func forgetWindowIdentitiesForTests() {
            mintedIdentities = [:]
        }

        /// Every window the engine currently knows about.
        ///
        /// Follows `Window.get(byId:)`: under test the tree is the only inventory there is, because no
        /// `MacWindow` was ever registered from the Accessibility API.
        static var inventory: [Window] {
            isUnitTest
                ? Workspace.all.flatMap { $0.allLeafWindowsRecursive }
                : MacWindow.allWindows
        }

        private func orientation(for composition: SlotComposition, under root: TilingContainer) -> Orientation {
            switch composition {
                case .split(let orientation): orientation == .horizontal ? .h : .v
                // A tab group stacks its members, so its orientation decides nothing the user can see. The
                // engine's own `join-with` picks the opposite of the parent, and matching that keeps
                // opposite-orientation normalization from having anything to correct.
                case .tabbed, .single: root.orientation.opposite
            }
        }

        private func layout(for composition: SlotComposition) -> Layout {
            switch composition {
                case .tabbed: .tabGroup
                case .split, .single: .tiles
            }
        }

        private func composition(of container: TilingContainer) -> SlotComposition {
            switch container.layout {
                case .tabGroup: .tabbed
                case .tiles: .split(container.orientation == .h ? .horizontal : .vertical)
            }
        }
    }
}

/// The engine's one call outward: a window has just been detected, so let SceneMux have a look at it.
///
/// The seam `docs/design/scene-core-architecture.md` describes, and it is one function taking one engine type
/// and returning nothing — the inherited engine calls it and learns no Scene vocabulary by doing so, which is
/// what keeps this hook mergeable with upstream and keeps a Scene out of the tiling code.
///
/// It lives in this file for the same reason everything else here does: it is the only file in SceneMux allowed
/// to know both `Window` and `SceneCore`, and `script/test_scene_domain_layering.py` holds every other file in
/// `scene/` to that.
///
/// *Describing* the window rather than passing it along is the security boundary, not a convenience. What
/// crosses is a bundle id, an ordinal, which container the engine chose and a workspace name. The window title
/// does not, the process does not, and neither can be reached from the other side.
///
/// Nothing here decides anything and nothing here can fail loudly. A window that cannot be described in a way
/// that survives a restart is left alone, and so is a window the rules decline — which is nearly all of them.
@MainActor
func sceneAdmitDetectedWindow(_ window: Window) {
    guard let windowRef = SceneCore.WinMuxSceneEngineAdapter.reference(window) else { return }
    SceneCore.SceneRuntime.shared.admit(SceneCore.AdmissionSubject(
        windowRef: windowRef,
        kind: SceneCore.WinMuxSceneEngineAdapter.kind(of: window),
        surface: SceneCore.WinMuxSceneEngineAdapter.surface(of: window),
        detectedDuringStartup: isStartup,
    ))
}
