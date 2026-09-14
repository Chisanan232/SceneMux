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
