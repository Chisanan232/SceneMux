# HORO-1107 — Semantic Home and mounting, interactive verification

Captures from an interactive pass over the built debug app on a real Mac. HORO-1106 built the surfaces
that *describe* windows in Slots; this ticket is the first one in which there are windows to describe,
so these captures are the first evidence that the Phase 1 distinction — a window's Home is one fact and
its place in a Scene is another — is visible rather than merely designed.

Every image is a single-window capture of SceneMux's *own* window — `screencapture -o -l <windowID>` —
of the switcher panel, the close confirmation and the lifecycle HUD. No full-screen capture was taken.
No other application's window, content or **title** appears in any of them: SceneMux's window rows name
the application, never the document. See
[`../../../development/ui-verification.md`](../../../development/ui-verification.md).

| Capture | What it proves |
| --- | --- |
| [`01-switcher-mounted.png`](01-switcher-mounted.png) | One window borrowed into the editor Slot of `Debug PROD-123`, shown as `Development · mounted` — the Home the rules gave the application and the fact that it is in a Scene, side by side and separate (invariant I1) |
| [`02-switcher-three-slots.png`](02-switcher-three-slots.png) | Three semantic Slots populated at once, two different Homes (`Development`, `Observability`), and the editor Slot composed as a `split ⬍` with two windows in it |
| [`03-switcher-tabs-and-owned.png`](03-switcher-tabs-and-owned.png) | The same Scene with the editor Slot cycled to `tabs`, and the difference between the two ownerships on screen: the borrowed rows say `mounted`, the scene-owned row in the preview Slot says only `Development` |
| [`04-close-confirmation.png`](04-close-confirmation.png) | The close confirmation with real windows in it: *3 borrowed windows go back to their Home* and *1 scene window stays where it is*. Nothing has been closed at this point, and nothing ever is (invariant I6) |
| [`05-hud-window-went-home.png`](05-hud-window-went-home.png) | The HUD after a close, naming the Home a window went back to rather than a workspace number |

## What was exercised, and what it showed

The pass ran under the containment recipe in
[`../../../development/baseline-verification.md`](../../../development/baseline-verification.md): a config
with nothing automatic enabled, whose only bindings are the `ctrl-alt` namespace Scene Core owns, and every
window focused by `--window-id` before a command that acts on the focused window. Four throwaway TextEdit
documents and Activity Monitor were the only targets.

Home policy came from that config's `[scene-home]` table, which is the point of the ticket — `TextEdit` is
`development` there and `personal` in the shipped defaults, so `home show` has something to disagree with:

```
$ scenemux home show --app com.apple.TextEdit
com.apple.TextEdit is Development, according to your config.
$ scenemux home show --app com.linecorp.LINE
com.linecorp.LINE is Communication, according to SceneMux’s defaults.
$ scenemux home show --app com.example.Unheard
com.example.Unheard is Personal, according to the default for applications SceneMux does not know.
$ scenemux home list | head -3
com.apple.activitymonitor    Observability   your config
com.apple.console            Observability
com.apple.dt.instruments     Observability
```

Mounting was driven both ways — `scenemux mount --slot 2` over the socket, and the new global bindings
`⌃⌥⇧1` and `⌃⌥⇧U` posted at the session event tap — and both moved the window into the Scene's Slot on the
Scene's workspace. `⌃⌥⇧U` gave one window back mid-Scene: its Slot went to `empty` and the window returned
to workspace 1, the surface recorded when it was borrowed, while the other three windows stayed where they
were.

Closing the Scene then did what the confirmation said: the three borrowed windows returned to workspace 1
and the scene-owned window stayed on workspace 2. All five windows were still open afterwards, and the
application's Home was unchanged — `home show` still answered `Development, according to your config`,
because a Scene never writes Home policy.

Containment held. In the inventory taken after the pass, every window that was not a target was still
`floating` on workspace 1 — the one exception being an iTerm window that was already
`macos_native_fullscreen` before the pass started.

## What this pass did **not** prove

* **A restored window comes back to its workspace, not to its previous layout mode.** All four throwaway
  windows were `floating` before they were mounted and were `h_tiles` after they came home: the recorded
  `Attachment.originSurface` is a workspace, so that is all a restore replays. HORO-1222 carries it, and
  the `v0.1.0` evidence bar's "returned to their owner's arrangement" cannot be claimed until it is closed.
* **The inherited engine's window inventory is populated by activation events.** A freshly launched server
  reported two windows for minutes until an application was activated, after which it saw twenty. Nothing
  in Scene Core depends on this, but a pass that starts by reading an inventory should activate something
  first and wait for the count to settle — the same caveat `baseline-verification.md` records for frames.
