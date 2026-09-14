# Scene Core native UX specification

**Status:** canonical for Phase 1 (`v0.1.0`). Written under HORO-1101, before any Scene UI exists.
**Companion:** [`scene-core-architecture.md`](scene-core-architecture.md) — the model this specifies the
surface for. Every term used here (Scene, Semantic Home, Mount, Slot, ownership, lifecycle) is defined
there, and this document does not redefine any of them. Where the two disagree about *meaning*, that
document wins; where they disagree about a *surface*, this one does.

**Fidelity:** low. Diagrams are ASCII, sized in real points where a real constraint exists, and exist to
be argued with in review — not to be traced. Branding, iconography and final art are explicitly out of
scope for this ticket.

## Design principles

1. **The user manages Scenes, not windows.** Every surface here answers "what am I working on?" before
   "where is that window?". A screen that leads with window management has failed the North Star.
2. **Keyboard first, mouse fully supported.** Every operation is reachable without touching the trackpad,
   and every operation is also reachable by pointer and by drag. Neither is a second-class path.
3. **Meaning is visible; geometry is not.** The UI shows Home categories, Slot roles and ownership. It
   never shows a rectangle, a monitor number or a window id, because none of those are what the user is
   deciding about.
4. **Nothing destructive is implicit.** No screen closes a window as a side effect of anything. When
   SceneMux is about to touch someone's windows, the screen says which ones and on what terms first.
5. **Silence is a bug.** If SceneMux declines to act — an ignored window, a dropped attachment, a
   restore that could not find its target — it says so, once, visibly. "It did nothing" must never be
   indistinguishable from "it is broken".
6. **Native, and recognisably this app.** Built with AppKit and SwiftUI on the surfaces the app already
   has, in the visual vocabulary it already has (`GlassToken`, `RadiusToken`, `MotionToken` in
   `Sources/AppBundle/ui/core/DesignTokens.swift`). No web view, no custom chrome that fights macOS.

## Surfaces, and what each one is for

All five already exist in the app; Scene Core adds to them rather than inventing new window kinds.

| Surface | Existing implementation | Scene Core's use |
| --- | --- | --- |
| **Scene sidebar** | `ui/sidebar/WorkspaceSidebarPanel.swift` — a non-activating `NSPanel` rail that expands on hover | The persistent view of Scenes → Slots → windows. The primary pointer surface |
| **Scene switcher** | `ui/hud/SwitcherPalette.swift`, toggled by the `palette` command | The keyboard-first way to enter, create or find a Scene. Type-to-filter, no pointer needed |
| **Menu bar item** | `ui/menubar/MenuBar.swift`, `TrayMenuModel.swift` | The always-visible answer to "which Scene am I in?", plus a quick switch and *Leave Scene* |
| **Transient HUD** | `ui/hud/NSPanelHud.swift`, `MessageView.swift` | Lifecycle feedback: restored, left alone, refused, recovered |
| **Settings** | `ui/settings/` | Home rules per application, Scene defaults, and the recovery affordance for unreadable state |

Nothing in Scene Core needs a new window class, a modal sheet that blocks the app, or a full-screen
takeover. The sidebar and the switcher are panels precisely so that they can appear over another
application's window without stealing its focus — which is what a window manager's own UI must do.

## The Scene sidebar

Three levels, and only three: **Scene → Slot → window.** The inherited sidebar shows
project → workspace → window; the Scene sidebar is the same rail, the same hover expansion, the same row
metrics, with the levels renamed to the things the user is actually managing.

Collapsed (the resting state — a rail of Scene badges, no titles):

```
┌────┐
│ ▓▓ │  ← active Scene, filled badge
│ ░░ │  ← defined Scene with attachments
│ ·· │  ← defined Scene, empty
│    │
│ +  │  ← new Scene
└────┘
 44pt
```

Expanded on hover or on focus:

```
┌──────────────────────────────────────────────┐
│  SCENES                                  ⌘⇧S │
├──────────────────────────────────────────────┤
│ ▌ Debug PROD-123                    active   │  ← accent bar, filled row
│   ├ ⌨  Terminal            1 window          │
│   │   └ Terminal                Development  │
│   ├ ✎  Editor              1 window          │
│   │   └ IDE                     Development  │
│   ├ ◫  Preview             1 window          │
│   │   └ Browser                 Personal     │
│   ├ ◷  Observability       1 window          │
│   │   └ Grafana                 Observability│
│   └ ✉  Communication       2 windows · tabs  │
│       ├ LINE          Communication · mounted│
│       └ Slack         Communication · mounted│
│                                              │
│   Review release notes             2 windows │
│   Onboarding                          empty  │
│                                              │
│ + New Scene                              ⌘N  │
├──────────────────────────────────────────────┤
│ SHARED                                       │
│   Music                          persistent  │
└──────────────────────────────────────────────┘
 260pt
```

Row anatomy, per level:

| Level | Leading | Title | Trailing | Notes |
| --- | --- | --- | --- | --- |
| Scene | State badge | Scene title, editable in place | `active` / *n* windows / `empty` | `RadiusToken.row`; accent bar on the active Scene only |
| Slot | Role glyph | Slot label, or the role name when unlabelled | Window count, and `· tabs` / `· split` when composed | An empty Slot is shown, dimmed — it is where something *will* go |
| Window | App icon (`AppIconProvider`) | Application name | **Semantic Home**, plus `· mounted` when borrowed | Never the window title. See [Privacy](#privacy-in-the-ui) |

Three deliberate choices:

- **The Shared section is separate and last.** `.sharedPersistent` windows are not in any Scene, and
  putting them under one would imply a Scene could reclaim them. They are listed so the user can see that
  SceneMux knows about them and is leaving them alone.
- **Slot rows show composition, not layout.** `· tabs` and `· split` say *how these windows share a
  region*. No proportion, no orientation degrees, no pixel count.
- **The window row's trailing text is the Home category.** It is the one piece of information that a
  window's row must carry, because it is the thing borrowing must not change.

### Privacy in the UI

No surface in this specification displays a window title, and no evidence gathered while verifying it may
either — `AGENTS.md` forbids logging window contents, and a screenshot of a sidebar full of window titles
is a leak of the user's work. Rows are identified by application name and icon. The inherited sidebar's
own window rows and its `WindowTitleCache` are unchanged; Scene Core simply does not adopt them.

## Scene appearance by state

The four lifecycle states of [the model](scene-core-architecture.md#lifecycle) must be distinguishable at
a glance, and — this is the part that is easy to get wrong — **an inactive Scene that still holds windows
must not look like an empty one.** It is the difference between "I have work parked here" and "there is
nothing here", and it is exactly the state `leave` produces.

| State | Badge | Row fill | Title | Trailing | Accent bar |
| --- | --- | --- | --- | --- | --- |
| `active` | Filled | `GlassToken.fillActive` | `textPrimary` | `active` | Yes |
| `defined`, with attachments | Half-filled | `GlassToken.fillResting` | `textPrimary` | *n* windows | No |
| `defined`, empty | Outline | `GlassToken.fillFaint` | `textSecondary` | `empty` | No |
| `ending` | Filled, with a progress ring | `fillResting` | `textPrimary` | `restoring…` | No |
| `ended` | — | — | — | — | Not listed; see [Recovery](#empty-error-and-recovery-states) |

Three rules keep this honest:

- **Fill and stroke opacity are not the only signal.** Every state also differs in badge shape and in
  trailing text, because opacity alone fails for a user with reduced contrast, and fails completely in a
  screenshot compressed for a ticket.
- **`ending` is visible.** Restoring borrowed windows takes real time against other applications, and a
  Scene that is mid-restore says so rather than appearing frozen.
- **No colour-only meaning.** Scene rows may carry an accent hue, reusing the inherited
  `WorkspaceSidebarColor` palette, but hue never carries meaning that is not also carried by shape or
  text.

## Flows

### Create

`⌘N` in the sidebar, `+ New Scene`, or typing a name that matches nothing in the switcher and confirming.
One field, inline, no dialog:

```
┌──────────────────────────────────────────────┐
│ ▌ [Debug PROD-123                        ]   │  ← inline text field, focused
│   Slots:  ( Development )  ( Empty )         │  ← two choices, no wizard
└──────────────────────────────────────────────┘
```

*Development* pre-creates `terminal`, `editor`, `preview` and `observability` Slots; *Empty* creates none.
Two options, because a template picker is a Phase 2 feature and a wizard for a task name is an insult.
Enter creates and stays put — **creating does not enter.** Nothing on the user's screen moves, which is
what makes creating a Scene a free action.

### Rename

Double-click the title, or `⏎` on a selected row. Inline field, Enter commits, Esc reverts. The `SceneId`
is untouched, so nothing about a Scene depends on its name.

### Enter

`⏎` in the switcher, click the Scene row, or `⌘⌥1…9`. On entry: the Scene's Slots project onto the current
workspace, focus lands in the highest-ordered non-empty Slot, and the menu bar item changes to the Scene's
title. An entered Scene with no attachments shows [the empty-Scene state](#empty-error-and-recovery-states)
and moves nothing.

### Leave

`⌘⌥0`, *Leave Scene* in the menu bar item, or entering another Scene. **Nothing moves** — that is invariant
I5, and it is the flow most likely to be "helpfully" broken by a later ticket. The Scene's row drops to
`defined, with attachments`, the menu bar item returns to *No Scene*, and no HUD appears, because nothing
happened that the user needs to be told about.

### Close

`⌘⌫` on a selected Scene, or *Close Scene* in its context menu. This is the only flow that touches windows,
so it is the only one that asks first:

```
┌────────────────────────────────────────────────────┐
│  Close “Debug PROD-123”?                           │
│                                                    │
│  2 borrowed windows go back to their Home          │
│      LINE          → Communication                 │
│      Slack         → Communication                 │
│                                                    │
│  4 scene windows stay where they are               │
│      Terminal · IDE · Grafana · Browser            │
│      ☐ also close these  (asks for each)           │
│                                                    │
│  1 shared window is not touched                    │
│      Music                                         │
│                                                    │
│                       [ Cancel ]  [ Close Scene ]  │
└────────────────────────────────────────────────────┘
```

The panel is grouped by *ownership*, because ownership is what decides the outcome — the user is being
shown the model's actual reasoning rather than a generic warning. The cleanup checkbox is unchecked, and
checking it still asks per window: no single click in this product closes four applications' windows.

The panel is a non-modal `NSPanel` attached to the sidebar, not an application-modal sheet: SceneMux must
never block the user's other applications to ask itself a question.

## Home versus mounted

This is the distinction Phase 1 acceptance looks for on screen, so it is specified precisely rather than
left to a designer's instinct.

A window row shows its **Semantic Home** as trailing text, always, in every Scene and in the Shared
section. When the window is a **Mount** — borrowed, its Home elsewhere — the row gains three things:

```
│   ├ ✉  Communication          2 windows · tabs  │
│   │   ├ ◐ LINE          Communication · mounted │
│   │   └ ◐ Slack         Communication · mounted │
│   ├ ✎  Editor                       1 window    │
│   │   └   IDE                       Development │
```

1. a **borrow glyph** (`◐`) in the leading position, beside the app icon;
2. the suffix **`· mounted`** after the Home category;
3. a **dashed leading edge** on the row instead of a solid one.

Three signals, again, so that the distinction survives greyscale, reduced transparency and a compressed
screenshot. What the row must *never* do is show `Development` because LINE happens to be inside a
development Scene — that is invariant I1 rendered, and it is the single assertion the Phase 1 UI evidence
exists to support.

Hovering or focusing a mounted row reveals its reversibility, in plain words:

```
│   │   ├ ◐ LINE      Communication · mounted  ⏎↩ │
│           Borrowed into this Scene. Goes back to
│           Communication when the Scene closes.
```

If the user has re-homed the application since it was mounted, that line becomes the one place the change
is explained — *"Home changed to Development while borrowed; will go back to Development"* — rather than a
silent difference between what the row said yesterday and where the window goes today.

## Slots and composition

### Creating a Slot

`⌘⇧N` on a selected Scene, or `+` on the Scene's row when expanded. A Slot needs a role and nothing else:

```
┌──────────────────────────────────────────────┐
│  Add Slot to “Debug PROD-123”                │
│   ( ⌨ Terminal ) ( ✎ Editor ) ( ◫ Preview )  │
│   ( ◷ Observability ) ( ✉ Communication )    │
│   Label (optional): [                     ]  │
└──────────────────────────────────────────────┘
```

Five roles, chosen by click or by arrow keys, one optional label. There is no size field, no position
field and no monitor picker anywhere in this panel, because a Slot has no geometry — see
[Slot](scene-core-architecture.md#slot). Duplicate roles are allowed: two terminals is a normal thing to
want.

### Putting a window into a Slot

| Path | Interaction |
| --- | --- |
| Drag | Drag a window row onto a Slot row. The Slot row shows a drop highlight; dropping between two Slots is not a target, because a window belongs *in* a role, not between roles |
| Keyboard | Select the window row, `⌘⌥→` / `⌘⌥←` to move it to the next/previous Slot |
| Command | `⌘⇧M` opens the switcher in *move-to-slot* mode: type a role, `⏎` |
| From the screen | Focus a window, then `⌘⌥⇧1…5` to send the focused window to the *n*-th Slot of the active Scene |

Dragging a window whose Home differs from the Slot's serving Home shows the drop as a **borrow**: the drop
highlight is dashed and the drop hint reads *"Mount here · stays a Communication window"*. The user is told
what borrowing means at the moment they do it, not after.

### Composing several windows in one Slot

Composition is a property of the Slot, cycled from its row and shown in its trailing text:

```
   ├ ✉  Communication       2 windows            ←  .single   (most recent on top)
   ├ ✉  Communication       2 windows · split ⬍   ←  .split(.v)
   └ ✉  Communication       2 windows · tabs     ←  .tabbed
```

| Path | Interaction |
| --- | --- |
| Keyboard | `⌘⇧\` cycles the selected Slot's composition: single → split → tabs |
| Pointer | Click the composition chip in the Slot's trailing area; a three-item dropdown |
| Drag | Drop a window *onto another window row* inside the same Slot to make it tabbed — the same gesture the inherited tab strip already uses |

Under the hood `.split` is realised with `join-with` and `.tabbed` with `layout tab-group`; the inherited
`split` command is a no-op in this engine and is not used. That is invisible to the user and is recorded
here only so nobody designs a UI affordance around a command that does nothing.

Orientation for `.split` is offered as ⬍ / ⬌ and nothing finer. Fractions, weights and resize handles stay
where they already work — on the windows themselves, through the inherited engine's own resize behaviour,
which the Scene UI neither replaces nor mirrors.
