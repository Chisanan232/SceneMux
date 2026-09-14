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
| `composition: SlotComposition` | `.single`, `.split(Orientation)` or `.tabbed` — how *several* windows share this Slot |
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
| `.single` | The window is bound into the workspace's tiling tree at the Slot's ordinal position |
| `.split(.h / .v)` | Sibling windows joined with `join-with` in that orientation — never `split`, which is a no-op in this engine |
| `.tabbed` | A `TilingContainer` with `Layout.tabGroup`, the shape `baseline-verification.md` measured |

The nested case the golden journey needs — one window filling the left half, two stacked on the right —
is exactly the `join-with right` shape recorded in the baseline document, so it is known to work on real
geometry rather than assumed.

### A naming collision, stated so nobody trips on it

The inherited engine already uses the word "slot" for something else: `WorkspaceRetainedEmptySlot.swift`
calls a deliberately-kept empty workspace a "retained empty slot", and `Workspace.isOrdinaryEmptySlot`
means "an empty workspace nobody pinned". That is a *spare screenful*, and it has nothing to do with a
SceneMux Slot. Inherited names stay as they are — Phase 0's rule against blind renaming applies to this
too — so SceneMux types carry their own unambiguous names: `Slot`, `SlotId`, `SlotRole`,
`SlotComposition`, in the SceneMux layer. When prose could be read either way, write "Scene Slot".

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
ending the Scene do? Answer: restore to the Home the window has **now**, and use `homeAtAttachTime` only
to explain to the user what changed — the UX spec shows this as a one-line note on the restore feedback,
never as a silent divergence. The recorded value is evidence, not a destination.

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
| `close` (`defined`/`active` → `ending`) | — | Every attachment is resolved by ownership: `.borrowed` restored, `.sceneOwned` left with cleanup offered, `.sharedPersistent` untouched |
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
    case claim(SlotRef)       // this window belongs to that Slot, and SceneMux says so first
    case route(SlotRef)       // place it in that Slot of the active Scene
    case mount(SlotRef)       // attach it as .borrowed, leaving its Home alone
    case tab(SlotRef)         // add it to that Slot's tab group
    case float                // leave it floating; do not tile it
    case ignore               // not our business. The default
    case quarantine(Reason)   // something is wrong; touch nothing and say so
}
```

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

## Persistence: intent, not window identity

Scene state is persisted so that a Scene survives quitting the app, and so that a Scene caught mid-`ending`
finishes what it started. The mechanism copies the inherited precedent in
`tree/frozen/persistedFrozenWorld.swift` — it is already proven in this codebase, and copying it means one
persistence idiom to review instead of two:

- `~/Library/Application Support/SceneMux/scene-state.json`, beside the inherited `window-state.json`;
- a `Codable` envelope `{ version: Int, scenes: [...] }` with an explicit integer version;
- written with `Data.write(to:options: .atomic)`;
- an unknown version, a decode failure or a missing file all resolve to **no Scenes**, never to a partial
  read.

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

Three rules hold this together, and each one is checkable in review:

1. **`scene/domain/` imports `Foundation` and nothing else.** No `AppKit`, no `Common`, no engine type.
   The domain model is where the product's meaning lives, and it must be testable without a window
   server, a monitor, or a running app. This is also what makes the model reviewable by someone who does
   not know the engine.
2. **Scene Core never names an engine type outside `scene/engine/`.** It speaks to `SceneEnginePort`, a
   protocol expressed in Scene vocabulary — "make this Scene's projection current", "place this window in
   this Slot", "put this window back on this Home surface". `WinMuxSceneEngineAdapter` is the single file
   that knows both languages, and it is the only place an upstream rename can reach.
3. **The engine is not modified to know about Scenes.** Not one inherited type gains a `sceneId`. This is
   the Phase 0 rule about mergeability applied to Phase 1: an `upstream` merge that touches
   `NewWindowBinding.swift` or `WorkspaceProjects.swift` must still merge into code its author would
   recognise. Where the engine must call outward — the admission hook on window detection — it calls one
   named function with no Scene types in its signature.

`SceneEnginePort` is introduced *with its adapter and its callers, in the ticket that needs it*. It is not
added ahead of time as an empty protocol: the repository's own rules forbid abstractions with no callers,
and an unimplemented seam is a claim rather than a design.

### Reconciliation and the engine adapter

Projection is one-directional: **Scene state → engine tree.** Entering a Scene walks its Slots in order and
asks the adapter to place each attachment's window; the adapter uses the inherited verbs (`join-with`,
`layout tab-group`, tree binding) and the engine computes every rectangle.

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
| I8 | A `.borrowed` window is restored to its Home surface exactly once when its Scene reaches `ended` |
| I9 | Unreadable or unrecognised persisted state yields zero Scenes and zero window operations |
| I10 | An unrecognised window receives `ignore`; SceneMux leaves it exactly where the inherited engine put it |
| I11 | No Scene state contains a window title, a window frame, a monitor id or a `CGWindowID` |
| I12 | `scene/domain/` imports `Foundation` only; no engine type is named outside `scene/engine/` |
| I13 | A Slot with no attachments still exists in Scene state and is still shown |
| I14 | `ended` is reachable from `ending` even when every window involved has disappeared |

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
invariants above are testable without a window server. The engine adapter and admission are verified
against the real engine. Everything with a surface is verified natively, per
[`../development/ui-verification.md`](../development/ui-verification.md): built, launched, driven through
XCTest/XCUITest, Accessibility automation or a real interactive pass, with window-scoped or artifact-scoped
screenshots. Browser automation is not a valid verifier for any of it.

The Phase 1 release gate requires evidence of five things on screen, listed in that document: an active
Debug Scene, multiple semantic Slots, a window shown as Semantic Home versus mounted, split and tab
composition, and lifecycle restore/result state.
