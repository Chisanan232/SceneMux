# HORO-1107 — Semantic Home and mounting, interactive verification

An interactive pass over the built debug app on a real Mac, recorded in text. HORO-1106 built the surfaces
that *describe* windows in Slots; this ticket is the first one in which there are windows to describe, so
this is the first evidence that the Phase 1 distinction — a window's Home is one fact and its place in a
Scene is another — is visible rather than merely designed.

The record is **text only, by policy**: visual media captured on this workstation does not leave it, so
nothing in this directory is an image and none was committed or attached anywhere. The pass itself was
still interactive and the surfaces were still read on screen; what is written below is the state each one
showed, transcribed. See
[`../../../development/ui-verification.md`](../../../development/ui-verification.md).

| Surface, and the state it was in | What it proves |
| --- | --- |
| The switcher with `Debug PROD-123` expanded, one window borrowed into the editor Slot: the window row showed the application's name, its Home as the rules gave it, and the mounted marker | A window's Home and its place in a Scene are shown as two separate facts, and mounting did not change the first (invariant I1) |
| The same Scene with three Slots occupied, holding windows of two different Homes, the editor Slot's composition read back as a split | Several semantic Slots populated at once, and composition reported by the engine rather than asserted by the Scene |
| The same Scene after the editor Slot was cycled to tabs, with a scene-owned window in a further Slot | Composition belongs to the Slot, and the two ownerships are distinguishable on the row: the borrowed rows carry the mounted marker, the scene-owned row does not |
| The close confirmation, listing three borrowed windows to go back to their Home and one scene window to stay where it is, with nothing done until it was confirmed | The plan is stated for real windows before anything moves, and closing a window is not among the outcomes it offers (invariant I6) |
| The HUD after confirming, naming the Home the borrowed windows went back to and stating that the Scene's own window was left in place | The lifecycle reports a Home rather than a workspace number, and says the non-event out loud |

The exact wording of every string above is pinned by unit tests rather than by this record —
`SceneShellMessageTest`, `SceneShellWindowRowTest`, `SceneShellSlotRowTest` and `SceneShellCloseSummaryTest`
assert the sentences, and the pass confirmed the surfaces show them for real windows.

No window title, document name or window content appeared on any surface read during the pass: SceneMux's
rows name the application only (invariant I11).

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
