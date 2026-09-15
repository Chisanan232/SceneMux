# HORO-1222 — A borrowed window comes back as what it was, interactive verification

Four passes over the built debug app on a real Mac, recorded in text. HORO-1107 proved that a borrowed
window comes back to the *workspace* it came from and recorded, in its own evidence, that it came back
**tiled** whether or not it had been floating. This is the pass that closes that gap: what the window was —
laid out with its neighbours, or floating above them — is now recorded beside the surface and replayed.

The record is **text only, by policy**: visual media captured on this workstation does not leave it, so
nothing in this directory is an image and none was committed or attached anywhere. The pass itself was
still interactive; what is written below is the state each command reported, transcribed. See
[`../../../development/ui-verification.md`](../../../development/ui-verification.md).

## Method, and why the numbers below can be trusted

The pass ran under the containment recipe in
[`../../../development/baseline-verification.md`](../../../development/baseline-verification.md): a config
with nothing automatic enabled and a deliberately empty `[mode.main.binding]`, so no key could move a
window by accident, and every mutating command targeted by `--window-id` rather than by focus.

```
$ ./.debug/SceneMuxApp --config-path /tmp/horo1222/scenemux.toml   # git 4dcf589a
$ ./.debug/scenemux doctor
accessibility: granted / screen capture: granted
[1] Built-in Retina Display 1728x1117 (main) activeWorkspace=1
```

Targets were throwaway TextEdit documents and Activity Monitor, and nothing else. The baseline snapshot was
taken only once `scenemux agent query` returned the same answer twice, per the convergence caveat in
`baseline-verification.md`. Each snapshot records, per window, its id, its workspace and its `layout` —
which is the engine's own word for the thing this ticket is about: `floating` or `h_tiles`.

## Pass 1 — a floating window and a tiled one, borrowed together and returned together

The discriminating setup: two windows, different arrangements, mounted into the same Scene, so that a
restore cannot get both right by accident.

```
before:  4176 TextEdit workspace=1 layout=floating
         4177 TextEdit workspace=1 layout=h_tiles
$ scenemux scene new --title 'HORO-1222 arrangement' --template development   # Scene 5
$ scenemux workspace 2 && scenemux scene 5                                   # substrate: workspace 2
$ scenemux focus --window-id 4176 && scenemux mount --slot 2
$ scenemux focus --window-id 4177 && scenemux mount --slot 1
inside:  4176 workspace=2 layout=h_tiles
         4177 workspace=2 layout=h_tiles
$ scenemux scene close --yes
after:   4176 TextEdit workspace=1 layout=floating
         4177 TextEdit workspace=1 layout=h_tiles
```

The middle snapshot is the whole reason the defect existed: **inside the Scene both windows are tiled**, so
nothing observable at teardown time distinguishes them. Before this ticket, `4176` came back `h_tiles`. It
now comes back `floating`, and `4177` still comes back `h_tiles`.

## Pass 2 — the same, mid-Scene, one window at a time

`unmount` is the explicit half of the borrowed-window promise, and it runs the same restorer.

```
before:  4176 TextEdit workspace=1 layout=floating
         4202 Activity Monitor workspace=1 layout=h_tiles
$ scenemux workspace 2 && scenemux scene 5    # 'HORO-1222 pass 2', substrate: workspace 2
$ scenemux focus --window-id 4176 && scenemux mount --slot 2
$ scenemux focus --window-id 4202 && scenemux mount --slot 1
inside:  4176 workspace=2 layout=h_tiles / 4202 workspace=2 layout=h_tiles
$ scenemux focus --window-id 4176 && scenemux unmount
→ "TextEdit went back to where it came from. Its Home is still Personal."
         4176 workspace=1 layout=floating          # editor Slot went to 'empty'
         4202 workspace=2 layout=h_tiles           # untouched, still in the Scene
$ scenemux scene close --yes
         4202 Activity Monitor workspace=1 layout=h_tiles
```

Two windows of two different applications, so the `WindowRef` (bundle id plus ordinal) is unambiguous —
pass 1 used two windows of the same application and got them individually right, which is worth knowing but
is not what pass 2 is for.

## Pass 3 — the recording survives a restart, and a same-surface restore still re-arranges

What is on disk, written by this build, for a tiled window borrowed into a Scene:

```
HORO-1222 pass 3 | {"bundleId": "com.apple.ActivityMonitor", "ordinalWithinApp": 0}
                 | surface {"workspaceName": "1"} | arrangement "tiled"
```

The app was then killed and relaunched. A fresh session re-discovers windows and, with
`automatically-tile-new-windows = false`, floats them: after the restart `4202` was `floating` on workspace
1 — which is *the recorded surface*. So the restore had nowhere to move the window to and something to
change about it anyway:

```
$ scenemux scene list      → 5  HORO-1222 pass 3  active  4 slots  active
$ scenemux slot list       → 1  terminal  1 window
         4202 Activity Monitor workspace=1 layout=floating
$ scenemux scene close --yes
         4202 Activity Monitor workspace=1 layout=h_tiles
```

This is the case a "has it moved yet?" shortcut gets wrong, and the case
`WinMuxSceneEngineAdapterTest.testAWindowAlreadyOnItsSurfaceIsStillPutBackAsWhatItWas` pins.

## Pass 4 — state written before this ticket restores exactly as it did before

The migration, exercised on a real state file rather than a fixture. A tiled window was borrowed, the app
was stopped, and `originArrangement` was deleted from the persisted attachment — which is byte-for-byte the
shape a build from before HORO-1222 writes:

```
$ python3 - <<'…'   # remove the key from ~/Library/Application Support/SceneMux-Debug/scene-state.json
keys removed: 1
remaining originArrangement occurrences: 0
$ ./.debug/SceneMuxApp --config-path /tmp/horo1222/scenemux.toml   # relaunch
$ scenemux scene list      → 5  HORO-1222 pass 4  active  4 slots  active
$ scenemux slot list       → 1  terminal  1 window
         4202 Activity Monitor workspace=1 layout=floating
$ scenemux scene close --yes
         4202 Activity Monitor workspace=1 layout=floating
```

The old-format state loaded with no diagnostics and the attachment came back. On close the window kept the
arrangement the engine had given it — which is exactly what happens on `main`. The check discriminates: had
the absent record been read as `tiled`, because most windows are tiled, the window would have come back
`h_tiles`. Absent means *no claim*, not a default.

## What this pass did **not** prove

* **A window comes back floating at whatever size the Scene left it.** What is recorded is a layout mode and
  never a frame — invariant I11 — so the inherited engine's own restore of a remembered floating size
  (`LayoutCommand`'s `lastFloatingSize`) is deliberately not replayed here. Position and size after a
  floating restore are the engine's, not SceneMux's. A known limitation of `v0.1.0`.
* **Anything about minimized, fullscreened or hidden windows.** `arrangement(of:)` answers nothing for those,
  which is the same "no claim" path pass 4 exercised, but no such window was borrowed.
* **Multi-monitor.** One display was attached throughout.

## Containment

Every window that was not a target was on workspace 1 with the arrangement it started with, in every
snapshot of every pass. No mutating command named a window other than `4176`, `4177` and `4202`.

One observation worth recording because it looks alarming and is not a mutation: the fullscreen iTerm2
window (`59`, `macos_native_fullscreen`) left SceneMux's inventory after the second app restart and did not
return. Its frame and its Space were unchanged throughout — the session running the pass was inside it — and
no command ever named it. A `macos_native_fullscreen` window on its own Space is simply not always
re-discovered by a fresh session, which is a reading of the inventory rather than a change to the desktop.

The throwaway documents were closed without saving, Activity Monitor was quit, the debug app was stopped,
and the persisted Scene list ended the pass with the same four Scenes it started with and no attachments.
