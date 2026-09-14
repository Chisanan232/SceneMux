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
