# HORO-1109 — the Debug golden journey and the Phase 1 regression matrix, interactive verification

The acceptance pass for Scene Core: the golden journey of
[`../../scene-core-architecture.md`](../../scene-core-architecture.md#the-debug-golden-journey) driven
repeatedly on a real Mac, then a regression matrix over the things a Scene has to survive — a relaunch, a
crash, an application quitting, a window renaming itself, a suspend, and the inherited engine being used
outside Scene paths altogether.

The record is **text only, by policy**: visual media captured on this workstation does not leave it, so
nothing in this directory is an image and none was committed or attached anywhere. The passes were still
interactive; what is written below is the state each command reported, transcribed. See
[`../../../development/ui-verification.md`](../../../development/ui-verification.md).

Ten findings came out of it. Seven were defects and are fixed on this branch, with a test each — F2, F3, F4,
F6, F7, F9, F10. One was a documentation gap rather than a defect (F1). Two are open and each carries a
ticket: an inherited order-dependent test (F5) and a reporting defect in `agent query` (F8). Four further
things were found and deliberately left as limits rather than fixed; they are written down in
[`../../scene-core-architecture.md`](../../scene-core-architecture.md#what-interactive-verification-found-and-what-stays-a-limit)
because they belong to the design rather than to a pass, and every one of them is in the ticket table at the
end of this record.

## Method, and why the numbers below can be trusted

Every pass ran under the containment recipe of
[`../../../development/baseline-verification.md`](../../../development/baseline-verification.md): a local
config with every automatic behaviour off and a deliberately empty `[mode.main.binding]`, so no keystroke
could move a window, and every mutating command named its window with `--window-id`. Two configs were used
and the difference matters, so each pass says which:

* `automatically-tile-new-windows = false` — the containment default. A new window is floated, and a floating
  window is never routed by a rule, so **admission cannot be exercised under it at all** (finding F1).
* `automatically-tile-new-windows = true` — used for every admission pass, for exactly that reason.

Homes were mapped onto applications that hold no personal data: TextEdit stood in for the IDE
(`development`), Font Book for Slack and LINE (`communication`). Targets were throwaway TextEdit documents,
Font Book, Calculator and Terminal windows opened for the pass.

The passes ran on a working desktop rather than a cleared one, and that is deliberate: it is the condition
that produced findings F7 and F9, and no unit test can create it. The first snapshot of pass E counted 21
windows, of which nine were the pass's own throwaway targets and the rest — a browser, Xcode, two Finder
windows, Notes, two iTerm2 windows, Slack, LINE, Zoom and the corporate VPN client — were the day's real work,
untouched by any command in this record.

Snapshots are `scenemux agent query` output, taken twice and compared before being trusted, per the
convergence caveat in `baseline-verification.md`. Each records, per window, its id, workspace, `layout` and
frame.

Builds, because the passes span several fixes:

| Passes | Build |
| --- | --- |
| A–C (journey, composition, reporting, ref identity) | `b8ec8eb2` … `4075689f` |
| D (persisted-state tamper) | `c347051b` |
| E (admission on a busy desktop; found F7, F9) | `c347051b`, then `5de7b60e` |
| F (admission after the startup fix) | `343a3ae5` |
| R2–R5 | `0d13e3ea` |
| R6–R9, and F10 live | `ad19a110` |

`ad19a110` is the last code commit on the branch, so the rows that matter most — the crash, the interrupted
teardown, the suspend, and the inherited-engine comparison — all ran on the code that is being merged. Each
pass launched the built debug bundle against its own config and left it running in the background:

```
$ nohup ./.debug/SceneMuxApp --config-path /tmp/horo1109/scenemux.toml >/tmp/horo1109/app.log 2>&1 &
```

The machine was the same throughout: macOS 15.7.7, Accessibility granted, and two monitors — the built-in
Retina display at 1728×1117, which is monitor 1 and carries workspace 1, and a DELL S2722DC at 2560×1440,
which is monitor 2 and carries workspace 2. That is what makes rows R6b and R7 a genuine cross-monitor test
rather than two workspaces on one screen.

## The journey, and the ten findings it produced

The journey itself — create, enter, populate `development`, add observability and preview, borrow
communication, switch away and back, end the Scene — behaved as designed on every pass: Homes never moved,
borrowed windows came back, scene-owned windows stayed, and nothing was closed or focused without a command
saying so. What the passes kept finding was **SceneMux not telling the person what it had done**, which is
why most of the fixes are one sentence of output and a test that pins it.

| # | What the pass found | Fix | Test |
| --- | --- | --- | --- |
| F1 | Admission is silently inert when new-window tiling is off: the engine floats the window, and no rule routes a floating window. Reproduced in both directions on the same build by changing that one config key | documented (`6a60dcd2`); a second doc commit records the split orientation no substrate can realise (`54f7e5f4`) | — |
| F2 | `slot compose` reported the composition that was *asked for*. The pass asked for a horizontal split, was told it had one, and watched nothing change: the substrate had normalized it straight back | `17e1615d`, enabled by `4075689f` | `ef91c9e3` — `SlotCommandTest.testComposingReportsWhatTheEngineSettledOnAndNotOnlyWhatWasAsked` |
| F3 | A `WindowRef` resolved to a window it never named — a relaunched application took an ordinal a Scene still held | `b8ec8eb2`; the limit that remains is documented in `01640c6a` | `76f13fcf` — `WinMuxSceneEngineAdapterTest.testAWindowThatInheritedAClosedWindowsOrdinalIsNotMovedInItsPlace`, and its control `…testAWindowKeepsItsRefWhenALaterWindowOfTheSameApplicationCloses` |
| F4 | Entering a Scene, and mounting into one, adjusted the projection silently; the CLI printed only the intent | `ba494f24`, `b17a95e6` | `0bdc88a9` — `MountCommandTest.testMountingReportsWhatTheProjectionHadToSay`; `4230e693` — `SceneCommandTest.testEnteringReportsWhatTheProjectionHadToSay` |
| F5 | `WindowTabsTest` fails depending on the order tests run in — inherited, reproducible on `main`, unrelated to Scene Core | not fixed: [HORO-1331](https://lightning-dust-mite.atlassian.net/browse/HORO-1331) | passes in the full suite run for this branch, debug and release |
| F6 | A close that left a borrowed window behind said so only on the HUD, and the still-owed count was taken before the close rather than after | `e0b611c1`, `e851fa95`, with `2827ffb1` keeping the last close's report | `b6cc4016` — `SceneCommandTest.testClosingReportsWhatIsStillOwedRatherThanWhatItSetOutToDo` and `…testClosingSaysSoWhenARestoreIsStillOwed`; `c347051b` — `…testClosingNamesABorrowedWindowThatDidNotGoHome` |
| F7 | **High.** A Slot was built *inside* a tab group that had become the workspace root, stranding a Scene's window off-screen behind a stranger's tab | `5de7b60e` — the adapter finds the tiling root instead of assuming the root tiles | `ca1c9a4c` — `WinMuxSceneEngineAdapterTest.testASlotIsNotBuiltInsideATabGroupThatBecameTheRoot` |
| F8 | `agent query` omitted a nested tab group from `inventory.tabGroups` and `reasoning.rawTrees`, while `slot list` and the screen both had it right | not fixed: [HORO-1330](https://lightning-dust-mite.atlassian.net/browse/HORO-1330) — a reporting surface rather than Scene state | — |
| F9 | **High.** The startup admission guard was unreachable in the running app — see below | `343a3ae5` | `0d13e3ea` — `SceneAdmissionHookTest.testAWindowFoundWhileSceneMuxIsStartingUpIsLeftAlone` |
| F10 | `slot list` counted a window whose application had quit, with nothing to say so | `992bdbf2` | `ad19a110` — `SlotCommandTest.testListingSaysWhenAnAttachedWindowCannotBeSeen` |

### F7, measured

The defect: with the workspace root a tab group — which `smartLayoutAtStartup` makes it on any desktop of
more than three windows — a Slot was projected into that tab group, so the Scene's window became an inactive
tab of a group full of windows the Scene did not own, parked off the visible area at `x = 1727, y = 1116`.

After `5de7b60e`, on the same busy desktop, the Scene's own tab group is a **sibling tile** of the
strangers' one:

```
pane-tabgroup-21094   tabs [21094, 21188]    539pt tall   ← the Scene's Slot
pane-tabgroup-98      tabs [98, …]           539pt tall   ← windows the Scene does not own
                      vertical split, both visible
```

No Scene window was stranded, and no window belonging to anybody else was moved into or out of a Slot.

### F9, counted

The guard said "nothing is admitted during startup" and read the engine's `isStartup`, which is a TaskLocal
true only inside the single `.startup` refresh session. The pass measured what that actually covers by adding
two inherited `on-window-detected` callbacks to the local config — one matching
`if.during-scenemux-startup = true`, one matching `false`, both with `check-further-callbacks = true` so
admission still ran — each appending a line to a log:

```
during-startup:   1
after-startup:   19
```

One window in twenty. The consequence, reproduced: relaunching with a Scene left on screen attached **five
windows the person already had open**, with no user action, each recorded as
`origin: admission(ruleId: empty-slot-serving-home)`.

After the fix — `isSceneMuxStartingUp`, a latch bracketing the whole of `initAppBundle`'s startup task — pass
F on the same desktop:

```
after-startup:  19      admissions: 0      slot 1: empty      slot 2: empty
```

and the control, which is what makes that a fix rather than admission simply switched off: a TextEdit window
opened *after* launch was the 20th detection and **was** admitted, by `empty-slot-serving-home`, as
attachment ordinal 4.

### F10, live on the final build

The state the fix is about was produced by quitting an application mid-Scene (row R2) and survived a crash
and relaunch (row R6):

```
$ ./.debug/scenemux slot list
1   terminal        3 windows · tabs
2   communication   empty
SceneMux cannot see 1 of the 3 windows in the terminal slot (TextEdit) — the application may have quit,
or macOS may be holding it minimized or hidden. Nothing was removed from the Scene, and nothing was moved.
```

The attachment stays, on purpose: Scene state is intent. What was missing was the sentence.

### Admission v1 (G1), as the passes found it

Three boundaries, all observed rather than reasoned about, and all of them intended:

* **It is reactive only.** A window is considered when the engine detects it, so a window that was already
  open when a Slot appeared is not swept into that Slot. Pass F is the measurement: 19 windows already on the
  desktop, 0 admissions, and the TextEdit window opened *after* launch admitted as the only detection that
  arrived while a Slot was waiting. Populating a Slot from what is already open is `mount`, deliberately.
* **It never sees the window.** A rule receives an `AdmissionSubject` — a `WindowRef`, the kind the engine
  already decided on, the surface the window is on, and whether this was startup. No title and no content, so
  nothing in it could classify a Chrome window as a Playwright window. The G2 and G3 gates are not in v0.1.0
  and nothing here pretends otherwise.
* **A declined window is left exactly where it is**, which means it can sit inside a Slot's region looking
  like a member of the Scene while the Scene has no record of it. That is containment, it is G2, and it is
  [HORO-1332](https://lightning-dust-mite.atlassian.net/browse/HORO-1332).

And the one that is a trap rather than a boundary: with `automatically-tile-new-windows = false`, admission is
silently inert (F1), because the engine floats the new window and a floating window is never routed.

## Pass D — persisted state, tampered with by hand

Two edits to `~/Library/Application Support/SceneMux-Debug/scene-state.json` with the app stopped: one
attachment's `originSurface` key deleted, another's `"ownership"` set to `"possessed"` — a raw value no build
has ever emitted.

```
relaunch → state loaded with no error
$ scenemux scene list   → 1   Tamper D   active   2 slots   active
$ scenemux slot list    → 1  communication  1 window / 2  terminal  1 window
$ scenemux scene close --yes
Closing Tamper D.
1 borrowed window goes back to its Home
1 shared window is not touched
Font Book did not go back — nothing was closed or moved
$ scenemux scene list
SceneMux left com.apple.FontBook#0 where it was when "Tamper D" ended: SceneMux has no record of where it
came from.
windows after close:  20513 Font Book ws=1 floating 848x1078@32,38   (unchanged)
                      20516 Terminal  ws=1 floating 850x1071@880,38  (unchanged)
```

The unknown ownership degraded to `Ownership.failSafe == .sharedPersistent`, so teardown counted it as shared
and did not touch it; the attachment with no recorded Home surface was left in place and said so. **Neither
tamper produced a destructive close or move** — which is the property this pass exists to check.

## The regression matrix

| Row | What it covers | Result |
| --- | --- | --- |
| R1 | The golden journey, repeatedly, on a real Mac | Pass — behaved as designed on every pass; every defect above was in *reporting*, or in placement on a busy desktop, never in ownership or lifecycle |
| R2 | An application quits mid-Scene, then relaunches | Pass, with a defect: nothing moved and nothing was lost, and the Scene kept the attachment as designed — but the listing did not say the window was gone (**F10**), and the relaunched window took a fresh ordinal, which is the documented `WindowRef` limit |
| R3 | A modal sheet appears (TextEdit's Open panel) | Pass — **no detection at all**: the engine's popup handling filters it before `tryOnWindowDetected`, so admission never sees it. Nothing was attached, nothing moved |
| R4 | A window renames itself while in a Slot | Pass — Terminal `20517`, mounted and borrowed, had its title changed from inside the shell (escape sequence, then `cd /var/log`). Slot membership, the attachment and `slot list` were identical before and after. Two earlier attempts via `osascript` on TextEdit did **not** change the AX title and proved nothing; they are discarded, not reported as passes |
| R5 | Enter / leave cycles | Pass — three cycles, identical each time: `Entered Debug PROD-123` / `Left Debug PROD-123. Nothing moved.` / with none on screen, `No Scene is on screen, so there was nothing to do.` Slot counts unchanged throughout |
| R6a | `kill -9` with a Scene active, then relaunch | Pass — see below |
| R6b | An interrupted teardown is finished on the next launch (I14) | Pass — see below |
| R7 | Display geometry | **Partly verified**, gap carried as [HORO-1335](https://lightning-dust-mite.atlassian.net/browse/HORO-1335). Multi-monitor is covered: R6b borrowed a window from monitor 1 into a Scene whose substrate was workspace 2 on the DELL, and the restore brought it back. Display *reconfiguration* — unplugging the second monitor, or changing a resolution — was **not** verified: `displayplacer` is not installed and adding it is a workstation change, and the only other routes are physical. Recorded as not verified rather than claimed |
| R8 | Sleep / wake | **Verified by proxy, and labelled as one**, gap carried as [HORO-1335](https://lightning-dust-mite.atlassian.net/browse/HORO-1335). The app was suspended with `SIGSTOP` for 15s and resumed with `SIGCONT`. Real system sleep was not induced: it locks this workstation, and a locked screen would have ended the interactive pass. See below |
| R9 | The inherited engine, outside Scene paths | Pass — matched `baseline-verification.md` command for command, and Scene state was byte-identical afterwards. See below |
| R10 | Unit and integration suites | Pass — 824 tests with 0 failures in both `swift test` and `swift test -c release`, plus the five scripted guards (derivation provenance, update-feed isolation, appcast validator, Scene domain layering, license inventory). The full output is in the pull request, not here |

### R6a — a crash, with a Scene on screen

`kill -9` on a session with `Debug PROD-123` active and three attachments, then relaunch on `ad19a110`:

```
$ scenemux scene list   → 1   Debug PROD-123   active   2 slots   active
$ scenemux slot list    → 1   terminal  3 windows · tabs / 2  communication  empty
                          + the F10 sentence naming the window whose application had quit
state file: 3 attachments, ownerships and origins unchanged
```

Seventeen windows were open at that relaunch and **none was admitted** — F9's fix holding on the path that
matters most, since a crash is exactly when a Scene is left on screen.

Ten windows changed frame across the crash, and none of them moved in the sense that matters: before the
crash they were inactive tabs of the workspace's root tab group, parked at `x = 1727, y = 1116`; after it the
fresh session re-discovered them as floating (`automatically-tile-new-windows = false`) and put them back on
screen at *identical sizes*. Sizes are unchanged in all ten; only positions differ, and the difference is the
tab-group parking being unwound. No Scene attachment and no Scene command was involved.

### R6b — an interrupted teardown, finished on the next launch

The discriminating setup, because a restore that has nothing to do proves nothing: a Scene entered on
workspace 2 (the DELL) borrowing a Terminal window from workspace 1.

```
mounted:   20516 Terminal ws=2 h_tiles 2558x1407@1728,-145
state:     borrowed, originSurface {"workspaceName": "1"}, originArrangement "floating"
```

The app was then `kill -9`ed and that Scene's persisted state was set by hand to `{"ending": {}}` with its
attachment intact. **This is a synthetic fixture and is labelled as one**: it is byte-for-byte the shape the
product itself writes when `close` begins — the state before the patch was recorded as
`{"active": {"_0": {"workspaceName": "2"}}}` — but a crash cannot be timed to land inside teardown, so the
state was produced rather than caught.

On relaunch, with no command given:

```
20516 Terminal ws=1 floating 2558x1043@32,56        ← back on workspace 1, and floating, as recorded
state file: HORO-1109 teardown resume → {"ended": {}}, attachments 0
$ scenemux scene list → 1   Debug PROD-123   defined   2 slots   3 windows
```

Both halves of the record were honoured — the surface *and* the arrangement — and the Scene reached `ended`.
It is absent from `scene list` because an `ended` Scene is deliberately filtered out of the numbered list
(`SceneShellSnapshot`); the record of it is in the state file.

### R8 — suspend and resume

```
$ kill -STOP <pid>      ps STAT → TN
$ scenemux scene list   (issued while suspended: blocked, did not fail)
$ kill -CONT <pid>      ps STAT → SN
→ 1   Debug PROD-123   active   2 slots   active      (the blocked call completed, correctly)
snapshot diff across suspend/resume: 16 windows, 0 differences
$ scenemux slot list    identical to before, F10 sentence included
```

A command issued while the app is suspended waits rather than failing, which is the right shape for a wake:
nothing times out into a wrong answer.

### R9 — the inherited engine still behaves as the baseline recorded

Eight mutations with no Scene on screen, on three throwaway windows, compared against
`baseline-verification.md`:

```
layout tiling ×3     20515 563x1071@32,38 / 20516 563x1071@597,38 / 20513 565x1078@1162,38
                     (baseline: x = 32 / 597 / 1162, 565 wide — Terminal quantizes to character cells)
layout tab-group     one group tabgroup-20515, tabs [20515, 20516, 20513],
                     inactive members parked at 1727,1116, active tab inset to y=74 for the strip
join-with right      20515 850x1071@32,38 | 20516 850x539@880,38 / 20513 848x539@880,577
                     (baseline: 848x1078 left, 848x539 stacked right — the split-plus-tab Slot shape)
focus --window-id    exact, every time
scene-state.json     md5 2dea14609d825705fa76c7380631af43 before and after all eight
$ scenemux slot list → No Scene is on screen, so there was nothing to do.
```

One row did not reproduce cleanly and is reported as it happened: `focus tab-next` advanced once,
`20515 → 20516`, and then stopped advancing. It is focus-relative, and the focused window had by then been
taken *outside the group* by other applications — the snapshots show focus on `20517`, then on Xcode `188`,
neither of them named by any command. That is the baseline's own warning about focus not being contained,
observed again on a desktop in use; it is not a Scene Core path.

## What these passes did **not** prove

* **Display reconfiguration** — unplugging a monitor, or changing a resolution. Row R7, with the reason;
  carried as [HORO-1335](https://lightning-dust-mite.atlassian.net/browse/HORO-1335).
* **Real sleep and wake.** Row R8 is a `SIGSTOP`/`SIGCONT` proxy and is labelled as one everywhere it
  appears; carried as [HORO-1335](https://lightning-dust-mite.atlassian.net/browse/HORO-1335).
* **Anything about a malformed state *document*.** Pass D tampered with values inside valid JSON; an
  unparseable file is `SceneStateStoreTest`'s concern, and is covered there.
* **That the fixed reporting defects were the only reporting defects.** F8 is an open one, found on the last
  pass that looked for it.
* **The subjective half of the golden journey.** Whether managing work instead of windows *feels* right is
  not a machine-checkable claim, and nothing here pretends to have checked it.

## Every limit, and the ticket that carries it

| Limit | Ticket |
| --- | --- |
| `agent query` omits a nested tab group (F8) | [HORO-1330](https://lightning-dust-mite.atlassian.net/browse/HORO-1330) |
| Inherited `WindowTabsTest` is order dependent (F5) | [HORO-1331](https://lightning-dust-mite.atlassian.net/browse/HORO-1331) |
| A declined window can sit inside a Slot's region — G2 | [HORO-1332](https://lightning-dust-mite.atlassian.net/browse/HORO-1332) |
| The inherited startup layout tab-groups a busy desktop — root cause of F7 | [HORO-1333](https://lightning-dust-mite.atlassian.net/browse/HORO-1333) |
| An attachment has no window session identity — residue of F3 and F10 | [HORO-1334](https://lightning-dust-mite.atlassian.net/browse/HORO-1334) |
| Display reconfiguration and real sleep/wake unverified — R7, R8 | [HORO-1335](https://lightning-dust-mite.atlassian.net/browse/HORO-1335) |
| `scene list` claims there are no Scenes when all of them have ended — seen in R6b | [HORO-1336](https://lightning-dust-mite.atlassian.net/browse/HORO-1336) |

## Containment, and what this pass did to the desktop

Every mutating command named its window by id, and no window belonging to anything other than the pass's own
throwaway applications was ever named. The throwaway windows — TextEdit documents, Font Book, Calculator, a
second Finder window and three Terminal windows — were closed, and their applications quit, at the end of the
pass. The debug app was stopped with `SIGTERM`, and the debug Scene state file was restored from the backup
taken before the pass: nine Scenes, no attachments, exactly as it began.

Two things did change for windows that were not targets, and both are worth stating plainly because neither
is invisible to the person using the machine:

* **Running a tiling window manager on a desktop in use rearranges it.** The passes' own layouts were
  unwound — every window was floated and the tree flattened at the end — but a floated window goes back to
  the position the engine remembers, not to wherever a person had dragged it before SceneMux first managed
  it. Several windows therefore ended the pass stacked at the top-left of the visible rect. Nothing was
  closed and no document was touched.
* **Workspace membership of non-target windows was re-derived across app restarts.** Two windows physically
  on the DELL were reported on workspace 1 before a restart and workspace 2 after it, with no command naming
  them: workspace membership follows the monitor a window is on, and a fresh session re-reads it. One iTerm2
  window that had been observed migrating between monitors earlier in the ticket was moved back to workspace
  2 at cleanup, by id.

No visual artifact of any kind was produced for this record, and none was uploaded anywhere.
