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
│  SCENES                                  ⌃⌥S │
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
│ + New Scene                             ⌃⌥N  │
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

`⌃⌥N` from anywhere, `+ New Scene` in the sidebar, or typing a name that matches nothing in the switcher
and confirming.
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

`⏎` in the switcher, click the Scene row, or `⌃⌥1…9`. On entry: the Scene's Slots project onto the current
workspace, focus lands in the highest-ordered non-empty Slot, and the menu bar item changes to the Scene's
title. An entered Scene with no attachments shows [the empty-Scene state](#empty-error-and-recovery-states)
and moves nothing.

### Leave

`⌃⌥0`, *Leave Scene* in the menu bar item, or entering another Scene. **Nothing moves** — that is invariant
I5, and it is the flow most likely to be "helpfully" broken by a later ticket. The Scene's row drops to
`defined, with attachments`, the menu bar item returns to *No Scene*, and no HUD appears, because nothing
happened that the user needs to be told about.

### Close

`⌃⌥⌫` for the active Scene, `⌘⌫` on a selected row in the switcher, or *Close Scene* in a row's context
menu. This is the only flow that touches windows,
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

`⌃⌥⇧N` for the active Scene, or `+` on a Scene's row when expanded. A Slot needs a role and nothing else:

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
| Keyboard | Select the window row in the switcher, then `⌥↑` / `⌥↓` to move it to the previous/next Slot |
| Command | `⌃⌥⇧M` opens the switcher in *move-to-slot* mode: type a role, `⏎` |
| From the screen | Focus a window, then `⌃⌥⇧1…5` to send it to the *n*-th Slot of the active Scene |

When the dragged window's Home looks foreign to the Slot's role, the drop is *proposed* as a **borrow**: the
drop highlight is dashed and the drop hint reads *"Mount here · stays a Communication window"*. The user is
told what borrowing means at the moment they do it, not after — and the proposal is only a default. Holding
`⌥` while dropping takes the other branch, and the hint changes to *"Attach here · this Scene owns it"*.

The comparison chooses which of the two verbs the drop bar offers; it never decides ownership on its own.
Ownership is whichever verb the drop actually performed, which is why an override is a real override and not
a suggestion the system quietly reinterprets. See
[Ownership](scene-core-architecture.md#ownership).

### Composing several windows in one Slot

Composition is a property of the Slot, cycled from its row and shown in its trailing text:

```
   ├ ✉  Communication       2 windows            ←  .single   (most recent on top)
   ├ ✉  Communication       2 windows · split ⬍   ←  .split(.v)
   └ ✉  Communication       2 windows · tabs     ←  .tabbed
```

| Path | Interaction |
| --- | --- |
| Keyboard | `⌃⌥⇧C` cycles the focused window's Slot: single → split → tabs |
| Pointer | Click the composition chip in the Slot's trailing area; a three-item dropdown |
| Drag | Drop a window *onto another window row* inside the same Slot to make it tabbed — the same gesture the inherited tab strip already uses |

Under the hood `.split` is realised with `join-with` and `.tabbed` with `layout tab-group`; the inherited
`split` command is a no-op in this engine and is not used. That is invisible to the user and is recorded
here only so nobody designs a UI affordance around a command that does nothing.

Orientation for `.split` is offered as ⬍ / ⬌ and nothing finer. Fractions, weights and resize handles stay
where they already work — on the windows themselves, through the inherited engine's own resize behaviour,
which the Scene UI neither replaces nor mirrors.

## Lifecycle feedback

Everything SceneMux does to someone's windows is reported once, in a transient HUD built on the inherited
`NSPanelHud` / `MessageView`, for about 2.5 seconds, dismissible with Esc, and never stacking more than one
at a time. The wording rule is: **say what happened to which windows, in the user's vocabulary.**

| Event | HUD | Why it exists |
| --- | --- | --- |
| Scene entered | `Debug PROD-123 · 4 slots, 6 windows` | Confirms which Scene now owns the screen |
| Scene left | *(none)* | Nothing happened to any window. A HUD would be noise |
| Windows restored | `2 windows went back to Communication — LINE, Slack` | The single most important thing to confirm: borrowing was reversed |
| Restore target missing | `Slack could not be found — nothing was closed or moved` | Distinguishes "declined to act" from "broke something" |
| Scene-owned windows left | `4 windows left in place` | Says explicitly that closing the Scene did *not* close them |
| Shared window skipped | *(only on an attempt)* `Music is shared — left untouched` | Only when the user tried; otherwise silence is correct |
| Window ignored by admission | `Preview app isn't part of this Scene` — once per application, then suppressed | Principle 5. An unexplained non-action reads as a bug |
| Attachment dropped on load | `1 window from “Debug PROD-123” is no longer open` | Explains a Scene that came back smaller than it left |
| State could not be read | `Scene state couldn't be read — no windows were changed` + a *Show details* affordance | The corrupt-state case; see below |

Two anti-patterns, banned explicitly because both are conventional and both are wrong here:

- **No HUD for a leave.** Frequent, harmless, and a toast on every Scene switch trains the user to ignore
  toasts — including the one that matters.
- **No progress bar for restores.** The Scene row's `restoring…` state is the progress indicator. A modal
  progress window while another application's window is being moved would block the user out of the very
  thing being moved.

## Empty, error and recovery states

### An empty Scene

Entering a Scene with no attachments is normal — it is what step 2 of the golden journey does — and it must
read as an invitation rather than a failure:

```
┌──────────────────────────────────────────────┐
│ ▌ Debug PROD-123                    active   │
│   ⌨  Terminal                        empty   │
│   ✎  Editor                          empty   │
│   ◫  Preview                         empty   │
│   ◷  Observability                   empty   │
│                                              │
│   Focus a window and press ⌃⌥⇧1 to put it    │
│   in the first slot.                         │
└──────────────────────────────────────────────┘
```

No window is moved, nothing is auto-populated, and no application is launched. An empty Slot stays listed;
that is invariant I13, and it is what makes a Slot a plan rather than a leftover.

### No Scenes at all

First run, and after a state file is discarded. One line and one action — *"No scenes yet. A scene is one
task: `Debug PROD-123`, `Review the release notes`. ⌃⌥N"* — and, critically, **the app behaves exactly as
`v0.0.0` did.** Every window keeps working, the inherited sidebar keeps working, and nothing about the
desktop changes because Scene Core has no data.

### Unreadable or unrecognised state

The fail-safe path from
[Persistence](scene-core-architecture.md#persistence-intent-not-window-identity), given a surface:

```
┌────────────────────────────────────────────────────┐
│  Scene state couldn’t be read                      │
│                                                    │
│  No windows were changed. Your windows are exactly │
│  where they were.                                  │
│                                                    │
│  Scenes are unavailable until this is resolved.    │
│  The unreadable file was kept at                   │
│  ~/Library/Application Support/SceneMux/           │
│      scene-state.json                              │
│                                                    │
│      [ Start with no scenes ]   [ Reveal file ]    │
└────────────────────────────────────────────────────┘
```

Four properties of this screen are requirements, not styling:

1. **It states that nothing was changed** — the user's first fear is that their windows were rearranged by
   a broken file, and the answer is no.
2. **It does not delete the file.** *Start with no scenes* moves it aside; nothing is destroyed without the
   user, per `AGENTS.md`.
3. **It offers no repair.** A half-understood state file is not something to guess at.
4. **It appears once per launch,** and is reachable again from Settings — not repeated every time a Scene
   surface opens.

### A Scene caught mid-close

If the app quit while a Scene was `ending`, the next launch shows the Scene as `restoring…` and finishes:

```
│ ▌ Debug PROD-123                restoring…   │
│   Finishing: 1 window goes back to Communication
```

A window that no longer exists is skipped with the "could not be found" HUD. Nothing is closed to reach a
tidy state — the Scene reaches `ended` with an honest report instead (invariant I14).

## Keyboard first, pointer equal

### Two kinds of shortcut, and why the distinction matters

**Global bindings** are declared in the user's config under `[mode.main.binding]`, like every other binding
in this app, and work while any application is focused. **Panel-local keys** work only while a SceneMux
panel already has key focus. Confusing the two produces a product that steals shortcuts from the user's
editor, so they are specified separately.

### Global bindings: the `ctrl-alt` namespace

Every combination below was checked against `resources/default-config.toml` at `13d6ee1a`: the inherited
default config binds `alt`, `alt-shift`, `alt-cmd`, `alt-cmd-shift`, `cmd-shift`, `ctrl`, `ctrl-shift`,
`ctrl-cmd-shift`, `cmd-ctrl` and `ctrl-f` — and **not one `ctrl-alt` combination.** So Scene Core takes
`ctrl-alt` as its own namespace — written `⌃⌥` in the diagrams above — and collides with nothing a user
of `v0.0.0` already has.

| Binding | Command | Action |
| --- | --- | --- |
| `ctrl-alt-s` | `scene switcher` | Toggle the Scene switcher. The entry point for everything |
| `ctrl-alt-n` | `scene new` | Create a Scene — the switcher opens with the name field focused |
| `ctrl-alt-1…9` | `scene <n>` | Enter the *n*-th Scene |
| `ctrl-alt-h` / `ctrl-alt-l` | `scene prev` / `scene next` | Previous / next Scene — mirroring `ctrl-h`/`ctrl-l` for workspaces and `alt-cmd-h`/`alt-cmd-l` for projects |
| `ctrl-alt-0` | `scene leave` | Leave the active Scene. Moves nothing |
| `ctrl-alt-backspace` | `scene close` | Close the active Scene — opens the confirmation panel; never closes anything directly |
| `ctrl-alt-shift-1…5` | `slot <n>` | Send the focused window to the *n*-th Slot of the active Scene |
| `ctrl-alt-shift-m` | `slot move` | Open the switcher in *move-to-slot* mode: type a role, `⏎` |
| `ctrl-alt-shift-n` | `slot new` | Add a Slot to the active Scene |
| `ctrl-alt-shift-c` | `slot compose` | Cycle the focused window's Slot: single → split → tabs |

These are *defaults*, expressed in the inherited config language, and therefore rebindable by the user like
anything else. The Scene commands are also plain CLI commands (`scenemux scene …`), which is what makes the
whole flow scriptable and testable — the same property the inherited `palette` command has, which likewise
ships with no default binding.

### Panel-local keys

Inside the switcher or a focused sidebar: `↑`/`↓` move the selection, `→`/`←` expand and collapse,
type-to-filter narrows, `⏎` activates the selection, `⇥` moves between sections, `⌘⏎` enters a Scene without
closing the switcher, `⌥↑`/`⌥↓` move a selected window row between Slots, `⌘⌫` closes the selected Scene,
`F2` or a second `⏎` renames in place, and `esc` dismisses — reverting an in-progress edit rather than
committing it.

The switcher is the keyboard surface, and the **sidebar never takes key focus on its own.** It expands on
hover and it is driven by the pointer; a window manager's rail that grabbed the keyboard from the focused
application would be a defect, not a feature.

### The pointer path, in full

Everything above is also reachable without the keyboard, because a design where the mouse is a lesser
citizen is not a macOS design:

| Operation | Pointer path |
| --- | --- |
| Enter a Scene | Click its row, or its badge on the collapsed rail |
| Create / rename | `+ New Scene`; double-click a title to rename |
| Leave / close | The Scene row's context menu, or the menu bar item |
| Put a window in a Slot | Drag its row onto the Slot row |
| Borrow a window | The same drag — the drop bar offers *mount* by default when the Homes differ, `⌥` takes the other branch |
| Reorder Slots | Drag a Slot row within its Scene |
| Compose | Click the composition chip, or drop a window onto another window row in the same Slot |
| Detach | Drag a window row out of the Scene, or *Remove from Scene* in its context menu |

Drag targets follow the rules the inherited sidebar already establishes (`WorkspaceSidebarDropTargets.swift`,
`WorkspaceSidebarDropDelegate.swift`) so that both sidebars feel like one product. Two Scene-specific rules:
a drop between two Slots is **not** a target, because a window belongs in a role rather than between roles;
and a drop onto a `.sharedPersistent` window is refused with the "shared — left untouched" HUD, because I7
says that window is not SceneMux's to move.

## Accessibility and macOS-native behaviour

### Accessibility

Scene Core's UI is how a person decides what happens to their windows, so it cannot be pointer-and-eyesight
only. Requirements, each verifiable:

| Requirement | What it means concretely |
| --- | --- |
| Every row has an accessibility label | `"Debug PROD-123, scene, active, 6 windows"`; a Slot: `"Communication slot, 2 windows, tabbed"`; a window: `"LINE, Communication, mounted"` — the same facts the row shows, never a window title |
| Every control has a role and a value | Rows are buttons with a selected state; the composition chip is a pop-up button; the rail badges are buttons, not decorative images |
| Hierarchy is expressed structurally | Scene → Slot → window is an outline with disclosure state, so VoiceOver announces depth instead of the user inferring it from indentation |
| No meaning by colour alone | Every state differs in shape and in text as well as in fill. See [Scene appearance](#scene-appearance-by-state) |
| Full keyboard access | Every operation has a keyboard path; focus order follows the visual order; the focused row has a visible focus ring, not just a fill change |
| Reduced transparency | `NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency` replaces the glass material with an opaque surface. The inherited `chrome-style = 'solid'` config path already does this and is reused |
| Reduced motion | `accessibilityDisplayShouldReduceMotion` drops the `MotionToken` springs to instant state changes. Nothing in this design depends on an animation to be understood |
| Increased contrast | Stroke and text tokens step up to their high-contrast values; the dashed mounted edge remains distinguishable |
| Dynamic text | Rows lay out from the text's measured height rather than a hardcoded row height, so a larger system font does not clip |
| Announcements | Restore, refusal and recovery HUDs post an accessibility announcement — otherwise a user with VoiceOver gets no notification that borrowed windows went home |

### macOS-native behaviour

| Behaviour | Requirement |
| --- | --- |
| Focus | Sidebar, switcher and HUD are non-activating panels; SceneMux does not become the active application to show them. The `WinMuxPanelLayer` conventions already in the codebase are followed |
| Modality | Nothing is application-modal. The close-confirmation is a panel, not a sheet that blocks the desktop |
| `esc` | Dismisses any Scene surface and reverts an in-progress edit. Never commits |
| Spaces and full screen | Panels join all Spaces and are suppressed over native full-screen windows through the existing `FullscreenChromeSuppression` path |
| Displays | Everything is laid out in points and follows the inherited sidebar's per-display configuration. No pixel constants; nothing breaks when a display is unplugged, because no geometry is stored |
| Appearance | Light and dark both supported through the existing tokens; the accent hue follows the system accent where the user has not chosen a Scene colour |
| Menu bar | The menu bar item shows the active Scene's title, truncated in the middle, and *No Scene* when none is active. It is the one always-visible piece of Scene state |
| System conventions | `⏎` to rename, `⌘⌫` to delete a selection, `⇥` to traverse, double-click to edit in place, and context menus on every row — because a macOS user already knows these |
| Permissions | No new permission is requested. Scene Core needs exactly the Accessibility grant the engine already requires, and asks for nothing else |

## The Debug golden journey, on screen

The same journey as
[the architecture document's walkthrough](scene-core-architecture.md#the-debug-golden-journey), in screen
terms. This is what HORO-1109 exercises on a real Mac and what the `v0.1.0` release evidence shows.

**Step 3–5, the composed Scene.** One monitor, one workspace, four Slots. The engine computes every
rectangle; the diagram shows the *shape*, which is the `join-with right` geometry already measured in
`baseline-verification.md`:

```
┌──────┬───────────────────────────────┬───────────────────────────────┐
│ ▓▓   │  Editor slot                  │  Observability slot           │
│ ░░   │                               │                               │
│ ··   │  IDE                          │  Grafana                      │
│      │  (Development, scene)         │  (Observability, scene)       │
│  +   │                               ├───────────────────────────────┤
│      │                               │  Preview slot                 │
│      │                               │  Browser (Personal, scene)    │
│      ├───────────────────────────────┼───────────────────────────────┤
│      │  Terminal slot                │ ┌ LINE ┬ Slack ┐  ← tab strip │
│      │  Terminal                     │ │ Communication slot          │
│      │  (Development, scene)         │ │ mounted · borrowed          │
└──────┴───────────────────────────────┴─┴─────────────────────────────┘
  rail        split (join-with)            tabbed (layout tab-group)
```

The five things the release gate must show are all in one frame: an **active Scene** (the filled badge on
the rail, the menu bar title), **multiple semantic Slots** (four, each labelled by role), **Home versus
mounted** (LINE and Slack read `Communication · mounted` in the sidebar while the IDE reads
`Development`), **split and tab composition** (the `join-with` shape and the tab strip), and — in the next
step — **lifecycle restore state**.

**Step 7, closing the Scene.** The confirmation panel from [Close](#close), then the restore HUD:

```
┌────────────────────────────────────────────────────┐
│  2 windows went back to Communication              │
│      LINE · Slack                                  │
│  4 windows left in place                           │
└────────────────────────────────────────────────────┘
```

and the sidebar afterwards, which is the assertion the whole journey exists to make:

```
│ SHARED                                             │
│   Music                              persistent    │
│                                                    │
│ (no active scene)                                  │
│   Debug PROD-123                     closed        │
```

LINE and Slack are back among communication windows, and if the user opens the Home rules in Settings, both
still read **Communication**. Nothing about borrowing them changed what they are for.

### Screenshot discipline for this evidence

Per [`../development/ui-verification.md`](../development/ui-verification.md), and non-negotiable on this
machine: capture **window-scoped or region-scoped** images only, never the whole screen; look at every image
before attaching it; and never publish a window title. That constrains the evidence — a full-desktop shot of
the composed Scene is not permitted — so the composition evidence is assembled from per-window captures plus
the sidebar panel, and the sidebar rows are the primary evidence for Home-versus-mounted because they are
the surface that shows the claim without showing anyone's content.

## Open questions for the implementation tickets

Not blockers, and each has a stated default so no ticket stalls waiting for an answer:

| Question | Default if nobody decides | Ticket that decides |
| --- | --- | --- |
| Does the Scene sidebar replace the inherited workspace sidebar, or sit beside it? | **Beside it**, as a separate section in the same panel — replacing an inherited surface in Phase 1 removes a working feature | The Scene UI ticket |
| Do Scene rows carry a user-chosen colour? | Yes, reusing `WorkspaceSidebarColor`, decorative only | The Scene UI ticket |
| Where do Home rules live in Settings — a new pane or the existing General pane? | **A new pane**, because per-application rules are a list that will grow | The Semantic Home ticket |
| Is `scene` one CLI command with subcommands or several top-level commands? | **One command with subcommands** (`scene new`, `scene close`), matching the inherited `project` command's shape | The Scene command ticket |

## What HORO-1106 shipped, and where it deviates

This specification was written before the shell existed. HORO-1106 built it, and the differences below are
deliberate. They are recorded here because an undocumented deviation reads as a defect to the next person,
and because a deviation that is really a *not yet* needs a ticket rather than somebody's memory.

| Surface | In this build |
| --- | --- |
| Scene switcher | `ui/scene/SceneSwitcherPanel.swift` — the non-activating floating panel, type-to-filter, inline naming and renaming, Slot chips, composition chip, close confirmation |
| Menu bar item | `ui/scene/SceneMenuBarSection.swift` and `SceneMenuBarLabel.swift` — the active Scene's title, a quick switch, *Leave* and *Close…* |
| Transient HUD | `ui/scene/SceneMessageHud.swift` — one message at a time, queued rather than stacked |
| Global bindings | The Scene half of the `ctrl-alt` namespace, in `resources/default-config.toml` |
| Scene sidebar | Not built — HORO-1216 |
| Settings pane | Not built — Home rules are HORO-1107, and the unreadable-state diagnostic appears in the switcher's empty state and on the HUD instead of behind a pane |

Almost every deviation has one cause: **nothing in this build attaches a window to a Slot.** Mounting
arrives with HORO-1107 and admission with HORO-1108, so anything above that describes a window *inside* a
Slot describes a shipped, tested presentation model with nothing yet to present.

| Specified above | In this build | Why |
| --- | --- | --- |
| A hover-expanding Scene rail beside the workspace sidebar | The switcher carries the Scene → Slot → window outline; there is no rail | A rail's value is the *persistent* view of windows in Slots. Until one can be attached, the rail would take 44pt of every screen to say nothing. HORO-1216 |
| A `SHARED` section, last | Not shown | `.sharedPersistent` reaches an attachment only by degradation (`Ownership.failSafe`), so there is currently nothing truthful to list. `SceneShellCloseSummary` already words the shared group and will show it the moment one exists |
| Window rows beneath Slot rows | `SceneShellWindowRow` and `SceneSwitcherWindowRow.swift` exist and are tested, and no Slot has a window to render | Shipped now so the layer is guarded before the ticket that fills it |
| `ctrl-alt-shift-1…5` → `slot <n>` | Unbound | There is no `slot <n>` command: *the focused window* → Slot needs the mapping attachments provide. A binding that silently does nothing is worse than an absent one. HORO-1217 |
| `ctrl-alt-shift-m` → `slot move` | Unbound | No move-to-slot mode, for the same reason. HORO-1217 |
| `ctrl-alt-shift-n` → `slot new` | Unbound; *Add slot* chips on the active Scene's row instead | `slot new` requires `--role`, so a default binding would have to choose a role on the user's behalf. HORO-1217 |
| `ctrl-alt-shift-c` → cycle *the focused window's* Slot | Unbound; `slot compose --slot <n>` addresses a Slot by number, and the Slot row's chip does it by pointer | The focused window's Slot is not knowable yet. HORO-1217 |
| `⌥↑` / `⌥↓` move a window row between Slots | Not implemented | Moves an attachment. HORO-1217 |
| `→` / `←` to disclose, `⇥` between sections | Not implemented | The switcher expands the selected Scene and has one section, so there is nothing yet to disclose or traverse |
| A second `⏎` on a selected row renames it | `⏎` always enters; `F2`, a double-click or the row's *Rename…* renames | The two things this specification asks `⏎` for cannot both be true of the same key: the row that is selected is the row the user is about to enter, and a key whose meaning depends on how recently it was last pressed would rename a task at the moment somebody meant to start one. `F2` is unambiguous, and both pointer paths remain |
| Drag and drop: window onto Slot, Slot reorder, drop-to-tab, detach | Not implemented | Every one of them moves an attachment. HORO-1216 |
| `☐ also close these (asks for each)` in the close confirmation | The ownership grouping ships; the checkbox does not | With no scene-owned windows the checkbox would govern nothing, and per-window asking belongs with `SceneOrchestrator.resolve` in HORO-1107 |
| Menu bar reads *No Scene* when none is active | The always-visible label is the icon alone; *No Scene* is the menu's first line | A permanent *No Scene* in the menu bar of somebody who has never made one is noise, and the menu answers the question the moment it is asked |
| HUD for about 2.5 seconds | 2.5 seconds, except a message carrying *Show details* — only `stateUnreadable` — which stays until dismissed | A disclosure that vanishes two seconds after being opened cannot be read |
| HUD dismissible with `esc` | `esc` reaches it through a local event monitor, so while SceneMux is the active application | The alternative is a HUD that takes the keyboard away from the user's application, which a window manager must never do. The dwell covers every other case |
| Nine lifecycle HUD lines | Three: Scene entered, attachments dropped on load, state unreadable | The other six report what happened to an attached window. `SceneShellMessage` is where they go |
| — | `scene close --yes`, which is not in this specification | The CLI needs a close that does not wait for a panel; without it a script would hang or be refused. The interactive paths still confirm |

None of this relaxes the architecture: `scene/shell/` remains Foundation-only and names no engine type, which
`script/test_scene_domain_layering.py` now checks in the guards job — a row that cannot reach a window cannot
put a window title on screen.
