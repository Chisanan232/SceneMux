# Scene Core architecture

**Status:** canonical for Phase 1 (`v0.1.0`). Written under HORO-1101, before any Scene code exists.
**Companion:** [`scene-core-ux.md`](scene-core-ux.md) — the native UX specification for everything
described here. Neither document is complete without the other: this one owns *meaning*, that one owns
*presentation*. Where they disagree about a term, this document wins; where they disagree about a
surface, that one wins.

## Why this document exists

Phase 1 is implemented by nine tickets after this one. Every one of them touches the same five words —
Scene, Semantic Home, Mount, Slot, ownership — and each word has an obvious wrong reading that would
quietly turn SceneMux back into the window manager it is derived from:

| Word | The wrong reading | What that would cost |
| --- | --- | --- |
| Scene | "a renamed workspace" | The product becomes a skin over WinMux and the North Star is gone |
| Semantic Home | "the workspace a window is in" | Borrowing a window would silently redefine what it is *for* |
| Mount | "moved into this Scene" | Ending a Scene would strand or destroy someone's chat window |
| Slot | "a rectangle at x/y" | Layout stops being intent and starts being pixels, per monitor, forever |
| Ownership | "SceneMux manages it" | SceneMux would close windows it does not own |

So the meanings are fixed here, once, with the invariants that make them checkable, and the
implementation tickets refer back to this file rather than re-deciding.

**North Star:** *Stop managing windows. Start managing work.* / *Every task has a scene. Every window
has a place.* Native apps stay native — see [Non-goals](#non-goals) for what that rules out.

## How to read this with the rest of the repository

- [`../../AGENTS.md`](../../AGENTS.md) sets document precedence; a Jira ticket outranks this file, this
  file outranks an implementer's judgement about what "Scene" ought to mean.
- [`../development/baseline-verification.md`](../development/baseline-verification.md) records how the
  inherited engine actually behaves, measured. This document only relies on behaviour recorded there or
  cited to a source file.
- [`../development/ui-verification.md`](../development/ui-verification.md) sets how the UX in the
  companion document is verified — natively, never with browser automation.
- [`../legal/ORIGIN.md`](../legal/ORIGIN.md) records what is inherited. The layering rules below exist
  partly so that inherited code stays mergeable from upstream.

## What already exists: the inherited engine, as surveyed

Everything below is a real primitive in this repository at `13d6ee1a`, cited so that a reviewer can
check that the design is implementable rather than aspirational.

| Inherited primitive | Where | What Scene Core uses it for |
| --- | --- | --- |
| `Workspace` — a monitor-bound container with a root tiling tree | `Sources/AppBundle/tree/WorkspaceType.swift` | The *rendering substrate* an active Scene is projected onto |
| `WorkspaceProject` — a named grouping of workspaces for the sidebar | `Sources/AppBundle/tree/Workspace.swift`, `WorkspaceProjects.swift` | Nothing. See [Scene is not the inherited project](#scene-is-not-a-workspace-and-not-the-inherited-project) |
| `TilingContainer` with `Layout.tiles` / `Layout.tabGroup`, and `Orientation` | `Sources/AppBundle/tree/TilingContainer.swift` | How a Slot's composition is *realised* |
| `TreeNode` binding (`bind(to:adaptiveWeight:index:)`) | `Sources/AppBundle/tree/TreeNode.swift` | Placing a window into the tree a Slot resolves to |
| `join-with`, `layout`, `move-node-to-workspace`, `focus` commands | `Sources/AppBundle/command/impl/` | The composition and placement verbs Scene Core drives |
| `unbindAndGetBindingDataForNewWindow` — the placement decision for a new window | `Sources/AppBundle/tree/NewWindowBinding.swift` | The seam admission attaches to |
| `tryOnWindowDetected` and `broadcastEvent(.windowDetected(...))` | `Sources/AppBundle/tree/WindowDetectedCallbacks.swift` | The event that starts an admission decision |
| A versioned, atomically written JSON envelope in Application Support | `Sources/AppBundle/tree/frozen/persistedFrozenWorld.swift` | The precedent Scene persistence copies |
| `WorkspaceSidebarPanel` — an `NSPanel` sidebar with rows, drag/drop, search | `Sources/AppBundle/ui/sidebar/` | The surface the Scene sidebar is built on |
| `SwitcherPalettePanel`, toggled by the `palette` command | `Sources/AppBundle/ui/hud/SwitcherPalette.swift`, `command/impl/PaletteCommand.swift` | The surface the keyboard-first Scene switcher is built on |
| `NSPanelHud` / `MessageView` transient panels | `Sources/AppBundle/ui/hud/` | Lifecycle feedback (restored / left alone / refused) |
| `DesignTokens.swift`, `MattePanelMaterial.swift` | `Sources/AppBundle/ui/core/` | The visual vocabulary the UX spec is written in |

Three findings from that survey constrain the design more than anything else, so they are stated here
rather than buried:

1. **The engine normalizes its own tree.** `normalizeContainers.swift` flattens containers that end up
   with a single child, and `Workspace.reconcileWorkspaceState()` prunes empty workspaces. A
   `TilingContainer` is therefore *not* a durable identity — which is exactly why a Slot cannot be one.
2. **`split` is a no-op in this engine** — recorded in `baseline-verification.md`. Composition is built
   with `join-with` and `layout tab-group`, so the design never speaks of "splitting a container".
3. **The inherited sidebar persists user-visible state back into the user's TOML config**
   (`ui/sidebar/WorkspaceSidebarConfigEdits.swift` rewrites `~/.config/scenemux/scenemux.toml`). Scene
   Core deliberately does not follow that precedent; see [Persistence](#persistence-intent-not-window-identity).

## Scene

A **Scene** is a named unit of *work* — a task a person is doing, with a beginning and an end. "Debug
PROD-123", "Review the release notes", "Onboard the new contractor". It is the object the product is
about: the user manages Scenes, and windows follow.

A Scene owns, as its own state:

| Field | Meaning |
| --- | --- |
| `id: SceneId` | Stable, opaque, generated once. Never derived from the name, so renaming is free. |
| `title: String` | What the human calls the task. Free text; the only field the user reads. |
| `slots: [Slot]` | The semantic layout intent, ordered. See [Slot](#slot). |
| `attachments: [Attachment]` | Which windows are participating, and on what terms. See [Attachment and Mount](#attachment-and-mount). |
| `state: SceneState` | `defined`, `active(SubstrateBinding)`, `ending` or `ended`. See [Lifecycle](#lifecycle). |

The substrate — which engine `Workspace` an active Scene is currently projected onto, an adapter detail and
never an identity — is carried *inside* `SceneState.active` rather than as a sixth field.

> **Clarified on 2026-09-14, during HORO-1102.** An earlier version of this table listed
> `substrate: SubstrateBinding?` beside `state`. Two fields make invariant I3 — an active Scene has exactly
> one binding, and no other state has one — something a reviewer has to check, and something a `leave` that
> forgets one line can break: a `defined` Scene left holding a stale workspace binding. As the payload of
> `.active` the invariant is structural, the illegal combination does not compile, and `leave` cannot half
> happen. Nothing else about the model changes; the projection is still one-directional and still derived.

`SceneId` and `SlotId` follow the shape the engine already uses for identity — `RawRepresentable`,
`Codable`, `Hashable` value types, as `WorkspaceId` and `WorkspaceProjectId` are in
`Sources/AppBundle/tree/WorkspaceIdentity.swift`. Consistency with inherited style is deliberate: it
makes the SceneMux layer legible to someone who already knows the engine.

### Scene is not a Workspace, and not the inherited project

The engine already has two grouping concepts, and Scene is neither of them.

| | Engine `Workspace` | Engine `WorkspaceProject` | SceneMux `Scene` |
| --- | --- | --- | --- |
| What it is | A place windows are laid out | A folder of workspaces for the sidebar | A task someone is doing |
| Identity means | "screenful #3 on this monitor" | "this group of screenfuls" | "PROD-123, the thing I am debugging" |
| Bound to a monitor | Yes, by construction | Indirectly, through its workspaces | No |
| Has an end | No. It is pruned when empty | No | **Yes.** Ending it is the interesting operation |
| Knows *why* a window is present | No | No | Yes — that is what `Attachment` records |
| Persisted where | Runtime state; names may appear in config | `config.workspaceSidebar.projectLabels`, in the user's TOML | Its own versioned state file |

Two consequences are load-bearing:

- **A Scene is not stored as a `WorkspaceProject`.** Reusing the inherited project layer would inherit
  its semantics wholesale — persistence into the user's hand-edited config, a mandatory `"default"`
  project that cannot be deleted, and a deletion policy that can *close windows*
  (`projectDeletionAction == .closeWindows` in `WorkspaceProjects.swift`). None of those are things a
  task should do. The inherited project layer keeps working exactly as it does today, untouched.
- **A Scene outlives its substrate.** A `defined` Scene has no workspace at all. When it becomes
  `active` it is projected onto one, and if the engine prunes or deletes that workspace the Scene is
  unharmed — it loses a binding, not an identity. The engine tree is *derived output* of Scene state,
  never the source of truth for it.

> **v0.1.0 scope:** at most one Scene is `active` at a time, and an active Scene is projected onto
> exactly one `Workspace` on one monitor. Concurrent Scenes per monitor are a deliberate deferral —
> the model above already permits them (`substrate` becomes a set), and nothing in Phase 1 needs them
> to prove the North Star.

## Semantic Home

A window's **Semantic Home** is what that window *is for*, independent of where it currently is. It is
a category, not a place:

| Home | Means |
| --- | --- |
| `development` | Building software — editors, terminals, agents, local previews |
| `communication` | Talking to people — chat, mail, calls |
| `observability` | Watching systems — dashboards, logs, traces, alerts |
| `personal` | Everything that is the user's own — music, notes, browsing that is not work |

Four categories, fixed in v0.1.0. They are an `enum`, not user-defined strings: a fixed set is
checkable, and the golden journey needs exactly these four. User-defined Homes are a later decision,
and adding a case is a source change with a migration, which is the honest cost.

**Home belongs to the window, not to the Scene.** It is resolved once, when SceneMux first sees a
window, from two inputs and nothing else:

1. a declarative rule table keyed on **application bundle id** — `com.apple.Terminal` →
   `development`, and so on, shipped with defaults and overridable by the user;
2. an explicit user override for that application, which wins.

That is the whole input set, deliberately. Window titles are *not* an input — they are the most
sensitive thing on a person's screen, `AGENTS.md` forbids logging them, and a rule that reads them
would make classification depend on what someone is currently writing. Process lineage is not an input
either; that is G2, and it does not exist in v0.1.0.

### The invariant that makes Home worth having

> **Mounting a window into a Scene never changes its Home.**

This is the single most important invariant in the model, because violating it is so easy and the damage
is so quiet. If LINE is borrowed into "Debug PROD-123" and its Home silently becomes `development`,
then it belongs to a task that ends, the user's chat app has been redefined by an act of borrowing, and
nothing on screen said so. Home changes only when the user changes it, explicitly, for the application.

### Home surface: where a Home resolves to

A Home is a meaning, and meanings cannot receive a window — so each Home has a **Home surface**: the
workspace that Home currently resolves to. It is a lookup, evaluated at the moment it is needed:

- if a workspace is already designated for that Home, that one;
- otherwise the workspace the window was last in outside of any Scene;
- otherwise a workspace created for that Home.

`restore(window)` means *put this window back on its Home surface*. The distinction matters for
correctness: because the surface is resolved late, a Home never holds a stale workspace reference, and
a Scene ending months after it started still restores a window somewhere real. It matters for the UX
too — the companion spec shows the Home *category* on a row, never the workspace number, because the
category is the part that is stable and meaningful.

#### What v0.1.0 implements of the three tiers, and what it does not

Only the middle tier ships in v0.1.0, and the deviation is recorded here rather than left for the next
person to infer from the code:

| Tier | In v0.1.0 | Why |
| --- | --- | --- |
| A workspace designated for that Home | **Deferred — HORO-1221** | There is no way for a user to designate one yet. A `[scene-home]` key naming a workspace per Home is a config change, a settings surface and a migration, and none of it is needed for a window to come back correctly |
| The workspace the window was last in outside any Scene | **Ships.** Recorded as `Attachment.originSurface` at the moment of mounting, and it is what `SceneRestorer` aims at | It is the one answer that is a *fact* rather than a policy: the window was observably there. Invariant I8 is satisfied by replaying an observation, not by resolving a rule |
| A workspace created for that Home | **Declined** | Creating a workspace is a visible change to somebody's desktop, made at the moment a task ends, to hold a window they did not ask to move there. A window whose recorded surface is gone is left where it is and the person is told — `leftInPlace(reason:)` — which is recoverable in a way an invented workspace is not |

So the shipped resolution is narrower than the three tiers above, and deliberately more conservative: a
restore either replays where the window came from or does nothing at all. An attachment with no recorded
surface — written by an earlier build, or by a build that could not see the window's workspace — is
therefore left in place rather than guessed at, which is `SceneRestorer`'s second refusal.

A surface alone is not enough to put a window back, so a second observation is recorded beside it. HORO-1222
adds `Attachment.originArrangement`: whether the engine was laying the window out with its neighbours or it
was floating above them, asked at the same moment the surface is, and replayed when the window goes home. A
window that was floating comes back floating; a window that was tiled comes back tiled.

Both recordings are observations and both may be absent, and absent means the same thing in both places: no
claim, rather than a default. An attachment with no recorded arrangement — written by a build from before
HORO-1222, or taken from a window macOS had minimized, fullscreened or hidden — restores exactly as it did
before, with the arrangement left to the engine. Guessing `tiled` because most windows are tiled would
quietly flatten somebody's floating window on the strength of a value nobody observed.

What is recorded is a *mode* and never a frame: no size, no position, no place among siblings. That is
invariant I11, and it is the reason a window comes back floating at whatever size the Scene left it rather
than at the size it had before it was borrowed. Geometry inside a workspace is the engine's business, and a
Scene that reproduced a tiling tree or a remembered frame would be a second window manager — so that is
declined rather than deferred.

## Slot

A **Slot** is a named role inside a Scene — *the place where the editor goes*, not *the rectangle at
x=848*. v0.1.0 ships five roles:

`editor` · `terminal` · `preview` · `observability` · `communication`

A Slot holds:

| Field | Meaning |
| --- | --- |
| `id: SlotId` | Stable identity, generated once, unique within the Scene |
| `role: SlotRole` | One of the five above. Two Slots may share a role — "two terminals" is legitimate |
| `label: String?` | Optional user text, shown instead of the role name when set |
| `composition: SlotComposition` | `.single`, `.split(SlotOrientation)` or `.tabbed` — how *several* windows share this Slot |
| `order: Int` | Where the Slot sits relative to its siblings. An ordering, not a coordinate |

There is no frame, no origin, no size, no monitor id anywhere in a Slot. Geometry is the engine's
business: the tiling engine already computes rectangles from weights and orientations, on whatever
monitor the workspace is on, and it does it better than a stored rectangle would survive a display
change. A Slot says *what goes where relative to what*; the engine says *how big*.

### Slot identity lives in Scene state, not in the tree

This is the second load-bearing consequence of the engine survey. The obvious implementation — "a Slot
*is* a `TilingContainer`" — cannot work:

- `normalizeContainers.swift` flattens a container down to its single child, so a Slot holding one
  window would evaporate the moment normalization ran;
- an empty Slot has no container at all to be, yet an empty `terminal` Slot is meaningful — it is where
  the terminal *will* go, and the UX draws it;
- containers are rebuilt when windows move, so any identity stored in one is lost on the first drag.

So: **Scene state is the source of truth. Each attachment records which `SlotId` it belongs to, and the
engine tree is projected from that.** A Slot with no attachments exists in Scene state and simply
contributes nothing to the tree. Reconciliation is one-directional — Scene state → engine tree — with
one exception, described in [Reconciliation](#reconciliation-and-the-engine-adapter): when the user
rearranges windows *with the engine's own commands*, the resulting slot membership is read back so that
Scene state follows the user rather than fighting them.

### How composition is realised

| `SlotComposition` | Engine realisation |
| --- | --- |
| `.single`, or any Slot holding one window | The window is bound straight into the workspace's root tiling container. Never wrapped in a container of its own: `normalizeContainers()` flattens a single-child container, so the wrapper would evaporate moments later and the Slot would look like a bug |
| `.split(.horizontal / .vertical)` | A nested `TilingContainer` with `Layout.tiles` in that orientation, the Slot's windows bound into it — the shape `join-with` produces, built the way `JoinWithCommand` builds it. Never `split`, which is a no-op in this engine |
| `.tabbed` | A nested `TilingContainer` with `Layout.tabGroup`, the shape `baseline-verification.md` measured. Built once, with every member bound into it — a tab group dissolves if its members are moved in one at a time |

The nested case the golden journey needs — four windows across a band of the screen, two chat windows
sharing the fifth place as tabs — is exactly the `join-with` shape recorded in the baseline document, so it
is known to work on real geometry rather than assumed.

### When the engine has the last word

`enableNormalizationOppositeOrientationForNestedContainers` is on by default, and it flips a nested
container whose orientation equals its parent's. A `.split(.horizontal)` Slot under a horizontal root
therefore comes out vertical, whatever SceneMux asked for.

SceneMux does not re-project to force it back. It would lose the same argument on the next normalization
pass, and a layout that oscillates is worse than one that is merely not what was asked. Instead the
adapter reads the settled structure back and reports it: the Slot's placement carries the composition the
engine arrived at, and the projection's diagnostics say so in the user's own words — *"SceneMux composed
the terminal Slot of "Debug PROD-123" as a vertical split instead of a horizontal split, because the
window engine normalized it."* The user can then change their configuration or ask for the other
orientation, which are both things they can actually do; being quietly lied to is not.

HORO-1109 exercised this on a real desktop and found the consequence worth stating plainly: under a
horizontal root, `slot compose` cycling from `.split(.vertical)` to `.split(.horizontal)` changes nothing
at all on screen, because both come out vertical. One of the two orientations is always unrealisable, and
which one depends on the substrate's root — so a user cycling a Slot will pass through a step that looks
like a command that did not work. The diagnostic is what distinguishes "did nothing" from "was normalized",
which is why `slot compose`, `mount` and `scene <n>` all print the projection's diagnostics beside their own
reply rather than leaving them for a panel nobody has open. Setting
`enable-normalization-opposite-orientation-for-nested-containers = false` makes both orientations reachable,
and is the user's own escape hatch rather than something SceneMux decides for them.

### A naming collision, stated so nobody trips on it

The inherited engine already uses the word "slot" for something else: `WorkspaceRetainedEmptySlot.swift`
calls a deliberately-kept empty workspace a "retained empty slot", and `Workspace.isOrdinaryEmptySlot`
means "an empty workspace nobody pinned". That is a *spare screenful*, and it has nothing to do with a
SceneMux Slot. Inherited names stay as they are — Phase 0's rule against blind renaming applies to this
too — so SceneMux types carry their own unambiguous names: `Slot`, `SlotId`, `SlotRole`,
`SlotComposition`, `SlotOrientation`, in the SceneMux layer. When prose could be read either way, write
"Scene Slot". `SlotOrientation` is the domain's own `.horizontal` / `.vertical`, deliberately not the
engine's `Orientation` with its `.h` / `.v`: the domain names no engine type at all, which is invariant
I12 and is checked by `script/test_scene_domain_layering.py`.

There is a second collision, and it is a hard one: **`SwiftUI.Scene`**. Three inherited files in
`Sources/AppBundle/ui/` already return `some Scene` from SwiftUI window builders
(`ui/settings/ShortcutSettingsView.swift`, `ui/menubar/MenuBar.swift`, `ui/hud/MessageView.swift`), and a
module-scope `struct Scene` in `AppBundle` would shadow the protocol they mean — turning `some Scene` into
`some` applied to a non-protocol type. Qualifying those inherited files as `some SwiftUI.Scene` would fix
the build by editing inherited UI code, which rule 3 below exists to prevent.

So the domain types live in a namespace: **`enum SceneCore`**, with the types nested inside it and written
`SceneCore.Scene`, `SceneCore.Slot`, `SceneCore.Attachment` at every use site. This is what the Phase 1
tickets mean by "a SceneMux-owned namespace". It costs a prefix and buys three things: `SwiftUI.Scene`
keeps meaning `SwiftUI.Scene` with no inherited file touched, any future collision between product
vocabulary and Apple's (`Slot`, `Attachment`) is pre-empted, and the SceneMux layer is visible at every
call site in a codebase where everything around it is inherited.

## Attachment and Mount

An **Attachment** is the record that a window is participating in a Scene, and on what terms. It is the
only thing in the model that knows *why* a window is on screen:

| Field | Meaning |
| --- | --- |
| `windowRef: WindowRef` | Which window, in a form that survives a restart. See [Persistence](#persistence-intent-not-window-identity) |
| `slotId: SlotId` | Which Scene Slot it participates in |
| `ownership: Ownership` | What ending the Scene may do to it. See [Ownership](#ownership) |
| `homeAtAttachTime: SemanticHome` | The window's Home when it was attached — recorded, never rewritten |
| `originSurface: SubstrateBinding?` | The workspace it was observably on when it was borrowed, and the only place a restore aims at. Absent means SceneMux never saw one |
| `originArrangement: WindowArrangement?` | Whether it was `tiled` or `floating` there, replayed when it goes home. Absent means no claim was recorded, never a default. A mode and never a frame (I11) |
| `origin: AttachmentOrigin` | `.userAction`, `.admission(rule)` or `.restoredFromState` — how it got here |

**Mount** is the interesting kind of attachment: a window whose Home is *elsewhere* temporarily
participating in this Scene. LINE has Home `communication`; borrowing it into "Debug PROD-123" mounts
it. The Scene shows it, the user works with it, and when the Scene ends it goes home.

Formally, for an attachment `a` of a window with Home `h`:

- `a` **is a Mount** when `a.ownership == .borrowed` — the user lent this window to the Scene, and `h` is
  where it goes back to;
- `a` is a plain attachment when `a.ownership == .sceneOwned` — the window is part of this task.

Note that the test is the recorded ownership and not a comparison against `h`. LINE mounted into a
`communication` Slot is a Mount even though the Slot's role matches its Home, because *borrowing* is what
the user did. See [Ownership](#ownership).

`homeAtAttachTime` exists for a specific failure mode: the user re-homes an application (say, moves
Slack from `communication` to `development`) *while* a Scene that borrowed it is still open. What should
ending the Scene do? Answer: **nothing differently.** A restore replays `originSurface` and
`originArrangement`, where the window actually was and how it was actually sitting there when it was
borrowed, so the destination is the one thing a re-home cannot change
— and `homeAtAttachTime` is how the surfaces name that destination, both in the row's reversibility line
and in the HUD line after a close. The recorded value is evidence, not a destination; the surface is the
destination.

What must never happen is the silent version: a row saying `Development` and a window coming back to the
place its Communication windows live, with nothing anywhere connecting the two. So the row says both — it
names the new Home *and* that the window still goes back where it came from — and the close message names
the Home the destination stood for. When [HORO-1221](https://lightning-dust-mite.atlassian.net/browse/HORO-1221)
gives a Home a designated surface of its own, "restore to the Home it has now" becomes expressible for
the first time, and that is the ticket that decides whether it should be.

### The invariants

> 1. **An attachment never mutates the window's Home.** Home changes only by explicit user action on the
>    application. (Restated from [Semantic Home](#semantic-home) because this is where it is violated.)
> 2. **An attachment is always to exactly one Scene.** A window participating in a second Scene is
>    detached from the first, and the user is told. There is no "in two Scenes at once" in v0.1.0 —
>    except for `.sharedPersistent` windows, which are not attached to any Scene at all.
> 3. **Ending a Scene resolves every attachment.** No attachment survives its Scene, and the resolution
>    is determined by ownership alone — never by what is convenient, and never by a guess.

## Ownership

Ownership answers one question: **when this Scene ends, what may SceneMux do to this window?** Three
answers, and the differences between them are the whole point.

| Ownership | Means | On Scene end | May SceneMux ever close it? |
| --- | --- | --- | --- |
| `.borrowed` | Home is elsewhere; lent to this Scene | Restored to its Home surface | **Never** |
| `.sceneOwned` | Exists because of this Scene | Left in place; cleanup is offered explicitly | Only on an explicit user confirmation, per window |
| `.sharedPersistent` | Belongs to the desktop, not to any task | **Untouched.** Not moved, not focused, not resized | **Never** |

Assignment rules, in order:

1. the **action** that created the attachment decides: an explicit *mount* is `.borrowed`, an explicit
   *attach* is `.sceneOwned`. This is a user decision, recorded — never a deduction;
2. a window the user has pinned as shared, or that is not attached to any Scene, is `.sharedPersistent`;
3. **anything else is `.sharedPersistent`.**

> **Corrected on 2026-09-14, during HORO-1102.** An earlier version of these rules inferred ownership by
> comparing a window's Home with "the Slot's serving Home". Implementing the domain model showed that rule
> is wrong in *both* directions against the golden journey below. LINE has Home `communication` and is
> mounted into a `communication` Slot — the Homes *match*, so the old rule made it `.sceneOwned`, when the
> whole point of step 5 is that LINE is `.borrowed`. The browser has Home `personal` and is attached to a
> `preview` Slot — the Homes *differ*, so the old rule made it `.borrowed`, when step 7 requires it to be
> `.sceneOwned` and left in place.
>
> The reason no comparison can work is that the journey's two groups are not distinguishable by Home at
> all: Grafana (`observability`) is scene-owned and LINE (`communication`) is borrowed, and both are
> non-`development` windows in a `development` task. What separates them is the user's intent — *lent for
> this task* versus *part of this task* — which the UX already expresses as two distinct verbs, and which
> the golden journey itself uses: steps 3 and 4 say a window "goes into" or "is attached to" a Slot, while
> step 5 says LINE and Slack are "**mounted**".
>
> So ownership is recorded from the action, not inferred from placement. Comparing Home against a Slot's
> role still has a job, but a smaller and safer one: the UI uses it to *propose* mount rather than attach
> when the user drags a window whose Home looks foreign to the Slot — a default in an interaction the user
> can see and override, owned by the Semantic Home and mounting ticket, not a rule that silently decides
> what may be moved. This also satisfies HORO-1102's invariant that ownership "is not inferred only from
> visual placement".

Rule 3 is the fail-safe, and it is chosen because of what the three classes permit: the most conservative
class is the one SceneMux may not touch at all. So an attachment whose ownership cannot be determined —
corrupt state, an unrecognised persisted value, a window that vanished and came back — degrades to "leave
it completely alone". The failure mode of a bug in this area is therefore *SceneMux does nothing*, which
is recoverable, rather than *SceneMux closes a window*, which is not.

`.sceneOwned` deliberately does **not** mean "closed when the Scene ends", even though the name invites
it. v0.1.0 never closes a window as a *consequence* of a lifecycle transition. Ending a Scene may offer
cleanup, listing the scene-owned windows, and each close requires the user to say so. This is a security
boundary as much as a UX one: `AGENTS.md` requires that corrupted state cannot cause destructive close or
move behaviour, and the cheapest way to guarantee that is for no automatic path to a close to exist.

### Worked example: LINE and Slack borrowed from Communication

The example the Phase 1 acceptance criteria name, traced through the model:

| | LINE | Slack | Grafana | IDE | Music |
| --- | --- | --- | --- | --- | --- |
| Home | `communication` | `communication` | `observability` | `development` | `personal` |
| In the Debug Scene | Mounted into the `communication` Slot | Mounted into the same Slot, `.tabbed` | Attached to the `observability` Slot | Attached to the `editor` Slot | Not attached |
| Ownership | `.borrowed` | `.borrowed` | `.sceneOwned` | `.sceneOwned` | `.sharedPersistent` |
| Home after mounting | `communication` — **unchanged** | `communication` — **unchanged** | `observability` | `development` | `personal` |
| When the Scene ends | Restored to the `communication` Home surface | Restored likewise | Left in place; cleanup offered | Left in place; cleanup offered | Untouched, never even read |

The row that matters is the fourth: after LINE has spent a day inside a debugging Scene, LINE is still a
communication window. Phase 1 acceptance asserts exactly that, and the UX spec renders it — the sidebar
row for LINE reads `Communication · mounted`, not `Development`.

## Lifecycle

```
                 create
                   │
                   ▼
            ┌──────────────┐   enter    ┌──────────────┐
            │   defined    │───────────▶│    active    │
            │ (no windows  │◀───────────│ (projected   │
            │  projected)  │   leave    │  onto a      │
            └──────┬───────┘            │  workspace)  │
                   │                    └──────┬───────┘
                   │  close                    │  close
                   │                           ▼
                   │                    ┌──────────────┐
                   │                    │    ending    │ ◀─┐ resumed after a
                   │                    │ (restoring   │   │ restart or a crash
                   │                    │  borrowed    │───┘
                   │                    │  windows)    │
                   │                    └──────┬───────┘
                   │                           │ every attachment resolved
                   ▼                           ▼
            ┌──────────────────────────────────────────┐
            │                  ended                   │
            │      (kept in state; no attachments)     │
            └──────────────────────────────────────────┘
```

| Transition | Guard | Effects |
| --- | --- | --- |
| `create` → `defined` | Title is non-empty after trimming | A `SceneId` is generated; default Slots are created from the chosen template, or none |
| `enter` (`defined` → `active`) | No other Scene is `active` (v0.1.0); a workspace can be resolved | A `substrate` binding is made; Slot membership is projected onto the tree; focus moves to the highest-ordered non-empty Slot |
| `leave` (`active` → `defined`) | — | The `substrate` binding is dropped. **Attachments are kept.** No window is moved, restored or closed |
| `close` (`defined`/`active` → `ending`) | — | Every attachment is resolved by ownership: `.borrowed` restored, `.sceneOwned` left with cleanup offered, `.sharedPersistent` untouched. The two that need no work are discharged at once, so a Scene with nothing pending reaches `ended` in this same step |
| `ending` → `ended` | Every attachment resolved or provably unresolvable | Attachments are cleared; the Scene stays in state as a record |
| `ending` → `ending` | The app restarted mid-close | The remaining restores are re-attempted; already-restored windows are no-ops |

### Why `leave` moves nothing

Leaving an active Scene is the common case — a person switches to something else and comes back. If
leaving restored borrowed windows, then switching Scenes twice would drag someone's chat window across
the desktop four times. So `leave` is cheap and non-destructive by construction: it drops the projection
and keeps every attachment. The Scene is still *about* those windows; it is simply not on screen.

The visible consequence is that a borrowed window stays where it was until either the Scene is entered
again or the Scene is closed. That is deliberate, it is what makes switching fast, and the UX spec makes
it legible: a `defined` Scene that still holds attachments is drawn differently from an empty one.

### Why `ending` is a state and not a function call

Restoring a borrowed window is asynchronous Accessibility work against other applications' processes, and
any of it can fail: the app is busy, the window was closed by its owner, the machine went to sleep, or
SceneMux itself was quit halfway through. If `close` were a synchronous function, a crash in the middle
would leave borrowed windows stranded in a Scene that no longer exists, with nothing on disk saying they
should go home.

Making `ending` an explicit, persisted state fixes that: the intent to restore is durable, it survives a
restart, and it is re-attempted. A restore whose window cannot be found is a no-op and the Scene still
reaches `ended` — never a close, never a "clean up by closing what I cannot find".

### One orchestrator, and what it hands out

Every transition above is a method on one object, `SceneOrchestrator`, and nothing else in SceneMux may
change a Scene. A lifecycle reachable from a menu item, a hotkey and a sidebar is a lifecycle with three
slightly different ideas of what closing a task means, and the difference shows up as somebody's chat
window left in the wrong place. The orchestrator owns two things: the `SceneWorld` — every Scene, plus the
rules that hold across all of them, such as "at most one is `active`" — and the state file it lives in.

`SceneWorld` is a value, so every operation is "here is the world afterwards" and either produces one that
satisfies every rule or throws. There is no partially-applied world to catch anybody out, which is what
lets the orchestrator save after each operation and know that what it saved makes sense.

The orchestrator decides; it does not act. No method on it moves, resizes, focuses or closes a window —
the closest it comes is `close`, which hands back a **teardown plan**:

| Part of the plan | What it means |
| --- | --- |
| `steps` | Every window in the Scene, in attachment order, each with its ownership and the Home recorded when it was attached |
| `pending` | The steps somebody still has to carry out: the `.borrowed` windows, which are owed a restore |
| `cleanupCandidates` | The `.sceneOwned` windows, left exactly where they are, for a shell to *offer* closing (invariant I6) |

The plan names the windows nothing happens to as well as the ones that move, because "SceneMux will send
LINE and Slack home, leave your terminal and your IDE where they are, and not touch your music player" is
a sentence a person can check before agreeing to it.

Whoever carries out a step reports back one outcome per window: `restored`, `windowIsGone`, `leftInPlace`
or `failed`. The first three finish the promise the attachment stood for, so the attachment is dropped;
`failed` does not, so the attachment stays and the restore is attempted again. That is the whole
re-entrancy mechanism, and it is why there is no retry counter anywhere: **the attachment is the count.**
Once the last pending attachment is discharged the Scene reaches `ended` in the same operation.

### Recovery and fallback, stated exactly

Three failures are ordinary enough to have named, deterministic answers, and none of them may cost anybody
a window.

**A save that fails.** Every change is written before it is believed. If the write fails — a full disk, a
read-only home directory, a sandbox denial — the operation throws, the in-memory world is unchanged, and
`close` hands back no plan, so nothing above starts moving windows on the strength of a decision that is
not on disk. The opposite order is how a borrowed window ends up moved into a Scene that will not exist
after the next launch, with nothing left anywhere saying where it came from. A no-op — the same shortcut
pressed twice — writes nothing at all, because a no-op that can fail on a full disk is not a no-op.

**A teardown interrupted.** A Scene left `ending` by a quit, a crash or a machine going to sleep still holds
the attachments whose restores never happened, so at startup the remaining work is *derived* from state
rather than remembered separately: one plan per closing Scene, containing only what is still owed. Someone
whose laptop died mid-teardown finds their borrowed chat window sent home on the next launch instead of
stranded in a Scene that no longer exists. Re-deriving is also why retrying is always safe: a window that
was already restored is no longer attached, so there is nothing left to do to it (invariant I8).

**A Home that cannot be resolved.** A borrowed window whose Home surface no longer exists is *not* moved
somewhere invented for it, and does not hold its Scene open forever either. It stays exactly where it is,
the outcome is `leftInPlace`, the Scene finishes, and the user is told which window stayed and why. This is
the only teardown outcome that ends a Scene without keeping the promise the attachment stood for, so it is
the one that must always produce a line somebody reads.

**A window that is not the same window.** A `WindowRef` is a bundle id and an ordinal within that
application — deliberately, because invariant I11 keeps titles, frames and `CGWindowID`s out of state. The
cost is that after an application relaunches, the window now sitting at that ordinal is *not provably* the
one the Scene borrowed. So a mismatch is treated as absence, not as a target: the step reports
`windowIsGone` and the Scene finishes, rather than sending whatever now occupies the ordinal off to a Home
it never came from. Restoring the wrong window is worse than restoring none, and the layer that can tell
the difference is the one holding the Accessibility handle.

**State that cannot all be true.** A file can decode perfectly and still describe Scenes that contradict
each other — two claiming one identity, two saved as being on screen. That is discovered above the store,
by the world's own rules, and it is refused exactly as an unreadable file is: zero Scenes, zero window
operations, one diagnostic (invariant I9), and a copy of the bytes kept out of the way of the next save.
Starting safe must never mean starting destructive.

### Deliberately not in v0.1.0

- **`suspend` / `resume` as states distinct from `leave` / `enter`.** They would have no observable
  difference in v0.1.0 — `defined` already is "not on screen, attachments intact". Adding two states
  with identical behaviour buys nothing and doubles the transition table. The names remain available.
- **`save-template`.** A Scene can be created with default Slots; deriving a reusable template from an
  existing Scene is a separate feature with its own persistence surface. Deferred to Phase 2.
- **Automatic close of anything, ever.** See [Ownership](#ownership).

## Admission

**Admission** is the decision *what should happen to this window* — asked once per window SceneMux
becomes aware of, answered by a typed value, and never by a side effect:

```
enum AdmissionDecision {
    case claim(slotId: SlotId, ruleId: String)   // this window belongs there, and SceneMux says so first
    case route(slotId: SlotId, ruleId: String)   // place it in that Slot of the active Scene
    case mount(slotId: SlotId, ruleId: String)   // attach it as .borrowed, leaving its Home alone
    case tab(slotId: SlotId, ruleId: String)     // add it to that Slot's tab group
    case float                                   // leave it floating; do not tile it
    case ignore                                  // not our business. The default
    case quarantine(reason: String)              // something is wrong; touch nothing and say so
}
```

Every attaching case carries the id of the rule that produced it, because a window that moved somewhere
its owner did not expect has to be traceable back to the reason. It is recorded on the attachment as
`AttachmentOrigin.admission(ruleId:)` and survives being written to the state file, so the question is
answerable in the next session too. Which ownership each case implies is stated once, on the decision
itself, so that nothing carrying a decision out can pair a Slot with an ownership of its own choosing.

All seven cases exist in the model because admission is a first-class abstraction that later phases
extend, and a partial enum would force a source change in every `switch` when G2 arrives. **v0.1.0
implements `route`, `mount`, `tab` and `ignore`.** `claim` needs pre-creation containment, which is G2.
`float` is the engine's existing behaviour and needs no SceneMux decision to happen. `quarantine` is
reachable only from the corrupt-state path in [Persistence](#persistence-intent-not-window-identity) —
never from a normal user window.

### Gates

| Gate | What it decides | v0.1.0 |
| --- | --- | --- |
| **G1 — reactive managed** | A window that already exists and the engine has detected: route / mount / tab / ignore | **Implemented** |
| **G2 — proactive, pre-creation** | Ownership established before the window appears, from process lineage: a coding agent's terminal, a launched-by-SceneMux browser | **Not implemented.** See [Extension points](#extension-points) |
| **G3 — session-scoped containment** | A `ManagedSession` or a browser broker owning a whole family of windows | **Not implemented** |

### What a G1 decision may look at

| Input | Allowed | Why |
| --- | --- | --- |
| Application bundle id | Yes | Stable, non-sensitive, already available on the detection event |
| Window role / subrole / level, and the engine's `.window` / `.dialog` / `.popup` classification | Yes | Already computed by `getAxUiElementWindowType`; it is what keeps dialogs out of Slots |
| The active Scene's Slots and their roles | Yes | It is the intent being served |
| An explicit user action (drag, keyboard, menu) | Yes — and it overrides every rule | The user is never overruled by a rule table |
| **Window title** | **No** | The most sensitive text on the screen. `AGENTS.md` forbids logging it, and a rule that reads it makes placement depend on what is being typed |
| **Process lineage / parent pid** | **No, in v0.1.0** | That is G2. SceneMux has no lineage evidence yet, and pretending otherwise is how you get wrong ownership |

Two rules follow from that table and are worth stating as rules, because both are tempting:

> **A Chrome window is not a Playwright window.** Application identity is evidence of *what application
> it is* and nothing more. SceneMux has no browser-session ownership in v0.1.0, so it must never infer
> that a browser window is automation-owned, agent-owned or Scene-owned from its bundle id.
>
> **An unrecognised normal user window is `ignore`.** Not floated, not quarantined, not tiled somewhere
> plausible — left exactly as the inherited engine would have left it. Failing safe means declining to act.

### What a rule is handed

A rule never receives the window. It receives an `AdmissionSubject` — a `WindowRef` (bundle id plus ordinal
within the application), the kind of window the engine decided this was, the workspace the engine put it on,
and whether the detection happened during startup — together with the Home its application resolves to, the
Scene currently on screen, and whether the window is already attached to some Scene. Those parts are
assembled by `SceneRuntime`, the only layer that can see both the engine's report and SceneMux's own Scenes.

So the two forbidden inputs are *absent* rather than merely unused: no field of `AdmissionSubject` could
carry a window title or a parent pid, and `script/test_scene_domain_layering.py` holds `scene/admission/` to
Foundation-only imports and to naming no engine type — so a rule cannot reach past the value it was given to
fetch them. That is a stronger promise than a comment asking it not to.

The engine's classification is read the same way, as *where the engine bound the window*: an
`AdmissionWindowKind` of `managed`, `floating`, `popup` or `setAside`. Re-deriving it from window role and
level would be a second heuristic that could disagree with the engine's own, and the day it disagreed
SceneMux would be moving a dialog into a Slot. Only `managed` is eligible for a Slot at all, which is the
whole of the conservative handling of dialogs and popups: they are not excluded by an editable rule, they
arrive as a kind no rule can route.

Reading the engine's classification rather than re-deriving it has one consequence that has to be said out
loud, because HORO-1109 spent a live pass discovering it: eligibility depends on the user's own tiling
setting. With `automatically-tile-new-windows = false` — which is exactly what
[`baseline-verification.md`](../development/baseline-verification.md) asks for while observing a live
system — the engine binds every new window as a floating one, so its kind is `floating`, so *nothing* is
ever eligible and reactive admission never fires. That is the setting working, not admission failing.
Anyone exercising G1 by hand has to turn new-window tiling back on first, and anyone reading a log where
admission said nothing has to check that setting before concluding the rules are wrong.

### What v0.1.0 decides, in order

`AdmissionRules.decide` is one function that decides by declining. Each row below is a reason to leave the
window alone, checked in this order, and only a window that survives all seven is moved at all:

| # | Declined | Because |
| --- | --- | --- |
| 1 | Anything that is not an ordinary managed window | A dialog, a popup or a minimized window is not the work |
| 2 | Anything detected during startup | A Scene is still `active` after a relaunch, and startup is the engine taking stock rather than a person opening a window |
| 3 | A window already attached to a Scene | Invariant I4, and what makes a second detection of the same window harmless |
| 4 | Every window, when no Scene is on screen | There is no intent to serve. This is the ordinary case |
| 5 | A window not on the active Scene's own workspace | Somebody switched workspaces with the Scene still open; pulling their new window across would move it out from under them |
| 6 | A window whose Home no Slot of this Scene serves | See the table below |
| 7 | A window with nowhere left to go | Every serving Slot is full and none of them is a tab group |

What survives is placed by one of exactly two rules:

| Rule id | Decision | When |
| --- | --- | --- |
| `empty-slot-serving-home` | `route` | The first empty Slot, in Slot order, whose role serves the window's Home |
| `tab-group-serving-home` | `tab` | Every serving Slot is full and one of them is a tab group — which is the Scene saying that more of these are welcome |

Both attach as `.sceneOwned`. `mount`, the `.borrowed` verb, is only ever reached by explicit user action in
v0.1.0: a window first seen while the Scene was already open has no earlier place to be sent back to, and
recording it as borrowed would promise a restore whose destination would have to be invented — which
invariant I8 forbids.

Which Slot roles serve a Home:

| Semantic Home | Slot roles served |
| --- | --- |
| Development | `editor`, `terminal` |
| Communication | `communication` |
| Observability | `observability` |
| Personal | *none* |

`Personal` serving nothing is the load-bearing row. It is both the answer for the applications SceneMux
classifies as the user's own and the answer for every application it has never heard of, because
`HomeRules.fallback` is `personal` — so **both** of the stated rules above fall out of row 6 rather than
existing as special cases that could be edited away. A browser window cannot be routed anywhere by any rule,
and neither can an unrecognised one.

### Where admission attaches, and where it does not

The engine already has the two seams admission needs:

- `tryOnWindowDetected` (`tree/WindowDetectedCallbacks.swift`) fires after a window is bound and is where
  a G1 decision is *requested and applied* in v0.1.0;
- `unbindAndGetBindingDataForNewWindow` (`tree/NewWindowBinding.swift`) computes the engine's initial
  placement. **v0.1.0 does not change it.** The engine places the window as it always has, and admission
  then moves it if the active Scene wants it. One code path, one behaviour to explain, and an unadmitted
  window behaves byte-for-byte as it did in `v0.0.0`. Deciding *before* placement is what `claim` is for,
  and that is G2.

Admission is also deliberately **not** built on the inherited `on-window-detected` config callbacks. Those
run arbitrary commands from the user's config file; `AGENTS.md` forbids introducing free-form command
execution to solve orchestration problems, and a typed decision that the app itself executes is both safer
and testable. The inherited callbacks keep working, unchanged, for the users who already have them.

The hook runs *after* the user's own callbacks, and a callback with `check-further-callbacks = false` returns
before it. That ordering is the same rule as everywhere else in Scene Core: an explicit instruction outranks
a rule.

### What G1 does not do in v0.1.0

Stated rather than fixed, because each of these is a decision to decline rather than an unfinished edge:

- **A Home is coarser than a Slot role.** Nothing admission may read says whether a JetBrains window is an
  editor or a terminal, so a development window fills the first empty development Slot in Slot order. Somebody
  who cares which window goes where mounts it explicitly. Carried by
  [HORO-1225](https://lightning-dust-mite.atlassian.net/browse/HORO-1225), which has to answer what evidence
  could tell the two apart without reading a window title.
- **A `preview` Slot is never filled by a rule.** The windows that belong in one are browser windows, and
  browsers are `personal`. Filling it would mean a rule deciding that somebody's browser is part of a task.
- **No `personal` window is ever admitted**, which includes every application SceneMux has not classified.
- **Nothing is admitted during startup.** Windows that already existed when SceneMux launched are never swept
  into the Scene that happened to be open when it last stopped.
- **Nothing is admitted onto a workspace the Scene is not on.** A window opened after switching away stays
  where it was opened.
- **A full Slot does not overflow.** With no empty serving Slot and no tab group, the answer is `ignore` —
  there is no second-best Slot and no automatic split.
- **A refused attachment is not retried.** If attaching fails, the window is left exactly where the engine put
  it and one diagnostic line says so; the window is never closed, and nothing is moved to make room.
- **No rule produces `claim`, `float` or `quarantine`.** `claim` is G2; `float` is the engine's own existing
  behaviour and needs no decision from SceneMux; `quarantine` is reachable only from the corrupt-state path,
  so a window is quarantined only where something was recorded about it that no longer makes sense — never
  because an ordinary window could not be understood.
- **Nothing is focused, raised or closed by admission**, on any outcome. Invariants I1 and I6 hold through
  every path above, including the failing ones.

## Persistence: intent, not window identity

Scene state is persisted so that a Scene survives quitting the app, and so that a Scene caught mid-`ending`
finishes what it started. The mechanism copies the inherited precedent in
`tree/frozen/persistedFrozenWorld.swift` — it is already proven in this codebase, and copying it means one
persistence idiom to review instead of two:

- `~/Library/Application Support/SceneMux/scene-state.json`, beside the inherited `window-state.json`.
  The directory is `sceneMuxAppName`, so a debug build writes `SceneMux-Debug/` and developing SceneMux
  cannot corrupt the Scenes of the SceneMux being used to develop it;
- a `Codable` envelope `{ version: Int, scenes: [...] }` with an explicit integer version;
- written with `Data.write(to:options: .atomic)`;
- an unknown version, a decode failure or a missing file all resolve to **no Scenes**, never to a partial
  read.

The implementation splits *what the bytes mean* from *where they live*: `SceneStateFormat` turns `Data` into
a `SceneStateLoad`, and `SceneStateStore` owns the file. Every corruption case is then reachable from a
`Data` literal in a test, with no directory to create and no disk to leave dirty.

`SceneStateLoad` has three cases — `noStateFile`, `refused`, `loaded(scenes:quarantined:)` — because a first
run and an unreadable file are different answers, and the bug worth designing out is the one that treats
"I could not read your Scenes" as "you have no Scenes" and then saves an empty file over them. Reading also
never throws: a thrown error invites a `try?`, and a `try?` here is invariant I9's failure mode with the
diagnostic dropped on the way past.

The version is probed on its own, before the payload. That is what lets a future build say "this file is
version 3 and I read 1 to 2" instead of reporting a missing field that did not exist when the file was
written. The migration seam is `SceneStateSchema.oldestReadable`: version 2 means writing `current = 2`,
leaving `oldestReadable` at 1, and reading the older shape where the envelope decodes its Scenes.

### Never in the user's config file

Scene state does **not** go into `~/.config/scenemux/scenemux.toml`, even though the inherited sidebar puts
its own labels there (`ui/sidebar/WorkspaceSidebarConfigEdits.swift`). The config file is a document the
user writes by hand and keeps in version control; Scene state changes every time a window is attached.
Rewriting a hand-edited file on every mount means a bug in that writer destroys someone's configuration —
and `AGENTS.md` lists persisted state as security-sensitive precisely because of this class of accident.
Config is *intent the user expressed*; Scene state is *a record of what happened*. Different files.

The one thing that does belong in the config file is user *intent* about Scene Core: the Home rule table
and per-application overrides. Those are declarative, hand-editable, and reviewed like every other config
key.

Home therefore has an owner on each side of that line, and mixing them up is the mistake to avoid. Which
Home an application *belongs to* is policy: it comes from the config file, the user changes it there, and
the resolution rules are HORO-1107's. `homeAtAttachTime` is not a second copy of that policy — it is
evidence, a record of what the policy said at the moment this window was attached, which is why Scene state
owns it and why re-homing an application later does not rewrite it.

### What is persisted, and what is refused

| Persisted | Not persisted | Why not |
| --- | --- | --- |
| `SceneId`, title, state, slot list with roles/labels/composition/order | — | — |
| Per attachment: application bundle id, `slotId`, ownership, `homeAtAttachTime`, origin | **`CGWindowID`** | A `UInt32` window id is not stable across the owning application's relaunch. The inherited frozen world persists them, but only to restore across *its own* restart, seconds later — a Scene may be reopened next week |
| The Home rule table and user overrides (in the config file) | **Window titles** | Sensitive by default and forbidden as log or state content |
| Slot ordering | **Window frames, monitor ids** | Geometry is derived; a stored rectangle is wrong the moment a display is unplugged |
| — | **Window contents, screenshots, thumbnails** | Never read, never stored |

`WindowRef` is therefore *not* a window id. It is `{ bundleId, ordinalWithinApp }` resolved on load
against live windows: a match reconnects the attachment, and no match drops it. Dropping an attachment is
always safe, because an attachment is only ever permission to move a window that is already there.

### Corruption is fail-safe by construction

> A Scene state file that cannot be read, or that contains a value this build does not understand, results
> in **zero** Scenes and **zero** window operations. It never results in a close, a move or a resize.

`quarantine` exists for the narrower case: state that *parsed* but describes something impossible — an
attachment to a `SlotId` that no longer exists, an ownership value from a newer build. Those attachments
are dropped, their windows are left untouched, and the reason is surfaced once in the UI rather than logged
and forgotten. A user must be able to tell that SceneMux declined to act, or "it did nothing" is
indistinguishable from "it is broken".

The granularity is the **attachment**, never the Scene. An attachment is only ever *permission* to move a
window that is already on screen, so leaving one out can never move, resize or close anything — it can only
make SceneMux do less. Losing a whole Scene over one stale entry would throw away the Slots and the ownership
records of every other window in it, which is strictly more destructive than the problem. So:

| The file says | What happens |
| --- | --- |
| The bytes are not JSON, or the version is unreadable | Refusal. Zero Scenes, one diagnostic |
| A Scene cannot exist at all — no title, two Slots claiming one identity | Refusal (`impossibleScene`). Nothing to leave out would repair it |
| An attachment names a Slot the Scene does not have | The Scene loads without it; quarantine record |
| One window is attached twice | The first attachment is kept, later ones quarantined (I4) |
| An `ended` Scene still holds attachments | The Scene loads with none; quarantine records |
| An attachment entry is not readable at all | The Scene loads without it; quarantine record naming the coding *path* |
| `ownership` is a value this build does not know | Degraded to `.sharedPersistent` by `Ownership.init(from:)` — the attachment is kept and SceneMux may not touch that window |

A refused file is **copied** aside to `scene-state.unreadable.json` before anything else happens. Not moved:
the original stays where the user — and a newer SceneMux that wrote a version this build cannot read — expects
to find it. The copy exists for the other direction, because the next save legitimately replaces the original,
and without a copy that save is the moment the state stopped existing.

An existing copy is never overwritten. If a later refusal has different bytes, the earlier copy is the older
state, and SceneMux has already told someone it kept it; the newer refusal makes no preservation claim rather
than replacing it. Declining to promise costs nothing, because the file being refused is still at its own
path — breaking a promise already made costs the Scenes it was about.

Diagnostics carry coding *paths* and never values. `DecodingError.debugDescription` quotes what it choked on,
Scene state contains application bundle ids, and a diagnostic is the one thing here meant to be screenshotted
and pasted into an issue — so `SceneStateCodingPath` keeps `scenes[2].attachments[1].slotId` and drops the
rest.

## Layering and the engine seam

```
┌─────────────────────────────────────────────────────────────────────┐
│  SceneMux.app                                                       │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │  Scene UI            Sources/AppBundle/scene/ui/              │  │
│  │  Scene sidebar · Scene switcher · lifecycle feedback           │  │
│  │  Built on inherited surfaces (NSPanel, SwiftUI, DesignTokens)  │  │
│  └───────────────────────────┬───────────────────────────────────┘  │
│                              │ reads a snapshot, sends intents      │
│  ┌───────────────────────────▼───────────────────────────────────┐  │
│  │  Scene Core          Sources/AppBundle/scene/                 │  │
│  │  ┌─────────────────────────────────────────────────────────┐  │  │
│  │  │  domain/   Scene · Slot · SemanticHome · Attachment ·    │  │  │
│  │  │            Ownership · SceneState · AdmissionDecision    │  │  │
│  │  │            Value types. Imports Foundation only.         │  │  │
│  │  └─────────────────────────────────────────────────────────┘  │  │
│  │  store/        transitions, invariant checks                   │  │
│  │  admission/    G1 rules → AdmissionDecision                   │  │
│  │  persistence/  versioned envelope, atomic write                │  │
│  │  engine/       SceneEnginePort (protocol)  ◀── the seam        │  │
│  └───────────────────────────┬───────────────────────────────────┘  │
│                              │ WinMuxSceneEngineAdapter             │
│  ┌───────────────────────────▼───────────────────────────────────┐  │
│  │  WinMux-derived engine    tree/ · command/ · config/ · ui/     │  │
│  │  Workspaces · tiling tree · tab groups · AX layer · CLI        │  │
│  │  Inherited. Kept mergeable from upstream.                      │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

Three rules hold this together, and each one is checkable in review — the first two are also checked by
`script/test_scene_domain_layering.py` on every pull request, because a rule that only a reviewer enforces
is a rule that survives exactly as long as reviewers keep noticing:

1. **`scene/domain/` imports `Foundation` and nothing else.** No `AppKit`, no `Common`, no engine type.
   The domain model is where the product's meaning lives, and it must be testable without a window
   server, a monitor, or a running app. This is also what makes the model reviewable by someone who does
   not know the engine.
2. **Scene Core never names an engine type outside `scene/engine/`.** It speaks to `SceneEnginePort`, a
   protocol expressed in Scene vocabulary — "make this Scene's workspace usable", "build this Slot",
   "settle, and tell me what shape each Slot ended up". `WinMuxSceneEngineAdapter` is the single file
   that knows both languages, and it is the only place an upstream rename can reach. The guard holds
   `scene/engine/` to that literally: every file in it but the adapter imports `Foundation` only and names
   no engine type, and the adapter is checked to still name one — an exemption protecting nothing would
   mean the seam had quietly moved somewhere unguarded.
3. **The engine is not modified to know about Scenes.** Not one inherited type gains a `sceneId`. This is
   the Phase 0 rule about mergeability applied to Phase 1: an `upstream` merge that touches
   `NewWindowBinding.swift` or `WorkspaceProjects.swift` must still merge into code its author would
   recognise. Where the engine must call outward — the admission hook on window detection — it calls one
   named function with no Scene types in its signature. That function is `sceneAdmitDetectedWindow(_:)`, one
   line at the tail of `onWindowDetected`, and it lives in the adapter's own file because that is the only
   file allowed to know both a `Window` and a Scene.

`SceneEnginePort` is introduced *with its adapter and its caller, in the ticket that needs it*. It is not
added ahead of time as an empty protocol: the repository's own rules forbid abstractions with no callers,
and an unimplemented seam is a claim rather than a design. Its caller is `SceneProjector`, which walks a
`SceneLayoutPlan` derived from a Scene; what invokes *that* is the Scene enter path in the shell, which
lands with the shell itself under HORO-1106. Until then the seam is exercised by tests against the real
inherited tree, which is why those tests use the engine rather than a fake.

### Reconciliation and the engine adapter

Projection is one-directional: **Scene state → engine tree.** Entering a Scene walks its Slots in order and
asks the adapter to place each attachment's window; the adapter uses the inherited verbs (`join-with`,
`layout tab-group`, tree binding) and the engine computes every rectangle.

Projection is three of the port's methods, and the order they run in is the whole of it:

| Step | Method | What it is for |
| --- | --- | --- |
| 1 | `prepareSubstrate(_:)` | Make the Scene's workspace usable, or refuse. A refusal ends the projection before a single window has moved — better a Scene that did not open than a Scene half-scattered across the wrong workspace |
| 2 | `place(_:on:)`, once per occupied Slot, in Slot order | Build one Slot: resolve its windows, build a container if the composition needs one, bind. Call order *is* Slot order — the port has no position argument, because a Slot's place among its siblings is where it was built, and a second way of saying it could only ever disagree with the first |
| 3 | `settle(_:)` | Run the engine's own normalization and read the resulting composition of each Slot back |

The rest of the port answers what a single operation needs to know, and each entry was added by the ticket
that had a caller for it: `currentSubstrate()` says whether there is anywhere to draw at all,
`focusedWindow()` says which window the person means, `surface(of:)` says where it is right now and
`arrangement(of:)` says how it is sitting there — recorded together as `Attachment.originSurface` and
`Attachment.originArrangement` at the one moment either is knowable — and `move(_:to:as:)` is the whole of
"put this window there, like that", used both to mount one and to send it back. The two questions answer
`nil` in the same circumstances and for the same reason: a window the engine cannot describe is a window
SceneMux makes no claim about. None of them names a container, a frame or a monitor, for the reason the
seam exists.

Two things follow from step 1 being separate. An empty Slot is never offered to the engine at all — there
is nothing to build — but it is still in the report, so the UX can draw it (I13). And a Slot whose windows
have all quit is reported empty rather than filled with a substitute: the Scene said *these* windows, and
"something in roughly the right place" is not what was asked for.

The projection returns a `SceneLayoutReport`: per Slot, what actually happened — realised, realised without
some window, empty, or refused in the engine's own words — plus diagnostics in plain language. Nothing is
thrown away, and nothing is rounded up to success.

The one read-back is user-initiated rearrangement. The inherited engine has its own commands and its own
drag handling, and a user who moves a window with `move right` is expressing intent just as surely as one
who drags it into a Slot in the sidebar. So after the engine settles, Scene Core re-derives which Slot each
attached window now belongs to and updates its own state to match. Two consequences:

- SceneMux never fights the user. A window dragged out of the `terminal` Slot into the `editor` Slot is
  recorded as being in the `editor` Slot, not snapped back.
- A window dragged entirely out of the Scene's substrate is *detached*, not chased. It keeps its Home, it
  keeps its ownership, and the Scene simply no longer lists it.

Read-back reads *structure* — which container a window ended up in — and never geometry. Nothing in Scene
state is derived from a rectangle.

## Invariants

Every one of these is stated so it can be *tested*, and the ticket that introduces the relevant code owns
the test.

| # | Invariant |
| --- | --- |
| I1 | A window's Semantic Home is unchanged by any attach, mount, enter, leave or close. Only an explicit user action on the application changes it |
| I2 | At most one Scene is `active` (v0.1.0) |
| I3 | An `active` Scene has exactly one substrate binding; a `defined`, `ending` or `ended` Scene has none. Structural: the binding is the payload of `SceneState.active` |
| I4 | A window has at most one attachment across all Scenes |
| I5 | `leave` moves, resizes, focuses and closes nothing |
| I6 | No lifecycle transition closes a window. A close happens only from an explicit per-window user confirmation |
| I7 | A `.sharedPersistent` window is never moved, resized, focused or closed by Scene Core |
| I8 | A `.borrowed` window is restored to its Home surface — and, when one was recorded, to the arrangement it had there — exactly once when its Scene reaches `ended` |
| I9 | Unreadable or unrecognised persisted state yields zero Scenes and zero window operations |
| I10 | An unrecognised window receives `ignore`; SceneMux leaves it exactly where the inherited engine put it |
| I11 | No Scene state contains a window title, a window frame, a monitor id or a `CGWindowID` |
| I12 | `scene/domain/`, `scene/lifecycle/`, `scene/shell/` and `scene/admission/` import `Foundation` only; no engine type is named outside `scene/engine/`, where only the adapter may name one |
| I13 | A Slot with no attachments still exists in Scene state and is still shown |
| I14 | `ended` is reachable from `ending` even when every window involved has disappeared |
| I15 | A projection binds, unbinds or moves only the windows its Scene names. Every other window on the substrate keeps its place and its parent |

## Non-goals

Not built in v0.1.0, and not to be smuggled in by an implementation ticket:

- **Cross-process window embedding.** SceneMux never reparents another application's window into a
  SceneMux-owned view, never draws another application's content, and never wraps a native app in a
  container. Composition is achieved by moving and sizing real windows through Accessibility — exactly what
  the inherited engine does. *Native apps stay native* is a constraint on the implementation, not a slogan.
- **Rewriting the WinMux engine.** SceneMux differentiates *above* it. No inherited module is restructured
  to make Scene Core prettier.
- **`ManagedSession`**, in any form.
- **Process lineage or window-to-process attribution.**
- **Coding-agent awareness** — no Claude Code, Codex or OpenCode ownership, detection or special-casing.
- **A Playwright Browser Broker** or any browser-session ownership.
- **Admission gates G2 and G3.**
- **Automatic destruction of anything** — no automatic close, no automatic quit, no "tidy up" that removes
  a user's window without a per-window confirmation.
- **Free-form command execution** as an orchestration mechanism.
- **Reading, logging or persisting window titles or window contents.**
- **Broadening Accessibility or TCC scope.** Scene Core needs exactly the permission the inherited engine
  already requires, and asks for nothing further.
- **Multi-monitor Scenes, concurrent Scenes, Scene templates, Scene sharing, sync.**

## Extension points

These are the places later phases attach. **None of them is code in v0.1.0** — an empty protocol with no
conforming type is a claim, not a design, and the repository's rules forbid abstractions without callers.
What is delivered now is a shape that does not have to be broken to add them:

| Future feature | Where it attaches | What v0.1.0 already got right for it |
| --- | --- | --- |
| **G2 pre-creation containment** | `AdmissionDecision.claim`, decided before `unbindAndGetBindingDataForNewWindow` returns | Admission is already a typed decision function, not a pile of side effects, and `claim` is already in the enum |
| **Process lineage** | A new *input* to a G1/G2 rule, alongside bundle id | The rule inputs are an explicit, closed list — adding one is a visible, reviewable change |
| **`ManagedSession`** | A new `Ownership` case, or an owner reference on `Attachment` | Ownership is already the single thing that decides what closing a Scene may do |
| **Browser broker** | A G3 gate plus a session-scoped owner | `AdmissionDecision` already distinguishes claiming from routing |
| **Scene templates** | A derivation from an existing Scene's Slots | Slots are already data, with no geometry to make a template monitor-specific |
| **Multi-monitor Scenes** | `substrate` becomes a set of bindings | Nothing in the domain model assumes one monitor; Slots carry order, not coordinates |

## The Debug golden journey

This is the journey Phase 1 is accepted against, on a real Mac, under HORO-1109. It is written here in
*model* terms; the companion spec walks the same journey in *screen* terms, and the two must stay in step.

**Setup.** Homes are resolved from bundle ids: the IDE and the coding agent's terminal are `development`,
Grafana is `observability`, the browser is `personal`, LINE and Slack are `communication`. A music window
is open and pinned as shared. No Scene is active.

**1 — Create.** The user creates a Scene titled `Debug PROD-123`. It is `defined`, with four Slots:
`terminal`, `editor`, `preview`, `observability`. No window has moved, and nothing is on screen but the
confirmation.

**2 — Enter.** The Scene becomes `active` and is projected onto a workspace. The Slots are empty, so the
projection places nothing — an empty Scene is a legitimate, quiet state, not an error.

**3 — Populate development.** The coding agent's terminal goes into the `terminal` Slot; the IDE goes into
the `editor` Slot. Both have Home `development`, both are `.sceneOwned`, and the two Slots compose as a
vertical split — realised with `join-with`, since `split` is a no-op here.

**4 — Add observability and preview.** Grafana is attached to the `observability` Slot and the browser to
`preview`. The three-pane shape (one window filling one half, two stacked in the other) is the geometry
`baseline-verification.md` measured, so it is known to work rather than hoped to.

**5 — Borrow communication.** The user needs LINE and Slack for this task. Both are **mounted**: attached
to a `communication` Slot, `.borrowed`, `homeAtAttachTime == communication`, composed `.tabbed` so they
share one region. **Their Home is still `communication`** — I1, the invariant this step exists to prove.
The sidebar row for each reads `Communication · mounted`, and the Home column does not say `Development`.

**6 — Work, and switch away.** The user leaves the Scene and enters another. Nothing moves: no restore, no
resize, no focus change (I5). `Debug PROD-123` is `defined` with all six attachments intact. Re-entering
projects the same composition again.

**7 — End the Scene.** `close` takes it to `ending`, and each attachment resolves by ownership alone:

| Window | Ownership | What happens |
| --- | --- | --- |
| LINE, Slack | `.borrowed` | Restored to the `communication` Home surface, once each. Never closed |
| Terminal, IDE, Grafana, browser | `.sceneOwned` | Left exactly where they are. A cleanup affordance lists them; each close needs the user to say so |
| Music | `.sharedPersistent` | Untouched. Never moved, never focused, never even a candidate |

The Scene reaches `ended`. LINE and Slack are back where communication windows live, and **their Home is
still `communication`** — the fact the whole journey is designed to demonstrate. If SceneMux had quit
during step 7, `ending` is on disk, and the remaining restores are re-attempted on the next launch (I14).

### What this journey proves, and what it does not

Proves: a Scene is a task and not a workspace; a Slot is a role and not a rectangle; borrowing is
reversible and does not redefine what a window is for; ending a Scene is safe by construction.

Does not prove, and must not be claimed: any form of session ownership, any agent integration, any browser
control, any pre-creation containment. See [Non-goals](#non-goals).

## How this design is verified

The domain model is verified by unit tests — it imports `Foundation` only, precisely so that the
invariants above are testable without a window server. So is the lifecycle above it: every transition,
every teardown outcome and the whole interrupted-teardown path are exercised as values, and the
orchestrator against a real state file in a temporary directory, including a directory it is not allowed
to write to. The seam is verified twice over: the projector's order of operations against a recording port,
and the adapter against the real inherited tree — including the golden journey built out of six windows and
five Slots and then measured as actual rectangles. A fake would agree with whatever the adapter believed,
which is the one thing worth doubting. Admission is verified against the real engine too. Everything with a
surface is verified natively, per
[`../development/ui-verification.md`](../development/ui-verification.md): built, launched, driven through
XCTest/XCUITest, Accessibility automation or a real interactive pass, with window-scoped or artifact-scoped
screenshots. Browser automation is not a valid verifier for any of it.

The Phase 1 release gate requires evidence of five things on screen, listed in that document: an active
Debug Scene, multiple semantic Slots, a window shown as Semantic Home versus mounted, split and tab
composition, and lifecycle restore/result state.
