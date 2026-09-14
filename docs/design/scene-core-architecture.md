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
| `state: SceneState` | `defined`, `active`, `ending` or `ended`. See [Lifecycle](#lifecycle). |
| `substrate: SubstrateBinding?` | Non-`nil` only while `active`: which engine `Workspace` this Scene is currently projected onto. An adapter detail, never an identity. |

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
