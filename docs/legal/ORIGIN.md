# Origin and derivation

SceneMux is a derivative work. This document records exactly what it derives
from, at which commit, and how the two projects relate going forward. It exists
so that provenance is a checkable fact rather than institutional memory.

## Lineage

```
AeroSpace  (MIT, nikitabobko/AeroSpace)
    └── WinMux  (MIT, ZimengXiong/winmux)          — direct upstream
            └── SceneMux  (MIT, Chisanan232/SceneMux)
```

SceneMux did not author AeroSpace's or WinMux's original code. Both remain the
work of their respective authors under their own copyright, and both notices are
retained in this repository.

## Direct upstream

| Field | Value |
| --- | --- |
| Upstream project | WinMux |
| Upstream repository | <https://github.com/ZimengXiong/winmux> |
| Upstream license | MIT |
| Upstream copyright | Copyright (c) 2026 Zimeng Xiong |
| Derivation baseline commit | `e0ad328e109cb6d2f86b1bdbc3aea9bf7bc5935e` |
| Baseline commit subject | `Record WinMux 0.5.4 release build` |
| Baseline commit date | 2026-09-07 |
| Baseline upstream version | WinMux 0.5.4 |
| Derivation date | 2026-09-14 |

Everything reachable from that baseline commit is inherited. Everything
committed to `main` after it is SceneMux-owned work. `git log
e0ad328e109cb6d2f86b1bdbc3aea9bf7bc5935e..main` is therefore the exact,
machine-checkable boundary between the two — no annotation or bookkeeping is
needed to tell them apart.

## Ancestral upstream

WinMux is itself a derivative of AeroSpace (<https://github.com/nikitabobko/AeroSpace>,
MIT). WinMux already documented that relationship, and SceneMux preserves it
unchanged: see `legal/README.md` and
`legal/third-party-license/LICENSE-Aerospace.txt`.

Because AeroSpace's MIT terms flow through WinMux to SceneMux, AeroSpace's
copyright notice and permission notice must continue to ship with SceneMux
distributions. They are not optional attribution courtesies.

## How this repository was established

SceneMux is a **standalone, non-fork repository seeded with the complete
upstream commit history**. It is not a GitHub fork.

* The full upstream commit DAG was preserved: 1795 commits at migration time,
  root commit `fe9119011acc19f11f61286d34f61308c96d8f23`, reachable from
  SceneMux `main`.
* No history was rewritten, squashed, or truncated. The baseline commit SHA in
  SceneMux is byte-identical to the upstream commit SHA, which is what makes the
  provenance claim above independently verifiable by anyone with a clone.
* The repository was created uninitialized, so no default README or LICENSE
  commit was injected ahead of the inherited root commit.
* GitHub reports `fork = false` with no parent, source, or template
  relationship, so SceneMux does not participate in WinMux's fork network.

Detaching from the fork network was deliberate, not cosmetic. A fork shares pull
requests, security-advisory scope, and release-feed affinity with its parent;
SceneMux needs an independent trust boundary for its own signing keys, update
feed, and advisories.

### Inherited release tags were deliberately not imported

WinMux had reached `v0.5.4` at the baseline. Those 13 inherited SemVer tags
(`v0.1.1` … `v0.5.4`) were **not** pushed into SceneMux. `0.5.4` outranks
SceneMux's `v0.0.0` and `v0.1.0` in any SemVer comparison, so importing them
would corrupt release ordering, "latest release" lookups, and update-feed
version resolution. They are recorded as provenance only.

SceneMux's release namespace starts clean at `v0.0.0`. See
`docs/release/RELEASE_MAPPING.md`.

## Upstream sync policy

The upstream remote is configured **fetch-only and tag-free**:

```
git remote add upstream https://github.com/ZimengXiong/winmux.git
git remote set-url --push upstream DISABLED_no_push_to_upstream
git config remote.upstream.tagOpt --no-tags
```

* **Pushing to upstream is disabled at the remote level.** SceneMux work cannot
  reach WinMux by an accidental `git push upstream`.
* **Tag fetching is disabled.** A routine `git fetch upstream` cannot leak
  WinMux release tags back into SceneMux's release namespace.
* Adopting upstream changes is a normal reviewed merge or cherry-pick through a
  pull request, like any other change. Upstream commits are never force-pushed
  onto `main`.
* SceneMux does not promise to track upstream. Divergence is expected: SceneMux
  is a task-oriented orchestration layer, not a WinMux rebrand.

## Attribution rules

* Upstream notices are never removed merely because the product brand changed.
* SceneMux does not claim authorship of inherited code.
* SceneMux's own brand, name, and visual assets are its own. WinMux and
  AeroSpace marks are used only nominatively — to state truthfully what SceneMux
  derives from — and are not reused as SceneMux branding.
* Neither the MIT license nor this document grants any trademark rights in
  "WinMux" or "AeroSpace".

See `docs/legal/LICENSE_POLICY.md` for how licensing decisions are made from
here, and `THIRD_PARTY_NOTICES.md` for the bundled-dependency inventory.
