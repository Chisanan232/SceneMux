# Upstream sync

SceneMux derives from WinMux and intends to keep consuming WinMux improvements. That only stays
affordable if the boundary between the two is explicit, so this document defines it: how the remotes
are configured, when upstream work is adopted, how a conflict is decided, and when a fix belongs
upstream instead of here.

Provenance facts — the lineage, the exact derivation baseline, the attribution rules — live in
[`docs/legal/ORIGIN.md`](../legal/ORIGIN.md). This document is about the mechanics.

## Remote convention

| Remote | Fetch | Push | Tags |
| --- | --- | --- | --- |
| `origin` | `https://github.com/Chisanan232/SceneMux.git` | same | normal |
| `upstream` | `https://github.com/ZimengXiong/winmux.git` | **disabled** (`DISABLED_no_push_to_upstream`) | **never fetched** (`remote.upstream.tagOpt = --no-tags`) |

Both restrictions exist because the failure they prevent is silent:

- A push URL of `DISABLED_no_push_to_upstream` is not a valid remote, so `git push upstream` fails
  instead of publishing SceneMux work into the project SceneMux derives from.
- Without `--no-tags`, an ordinary `git fetch upstream` imports upstream's `v0.1.1` … `v0.5.4` tags.
  `0.5.4` outranks every version SceneMux will publish for years, which would corrupt release
  ordering, "latest release" lookups and update-feed version resolution.

A bare `gh` command in this repository resolves to `upstream`, not to SceneMux — see
[`workflow.md`](workflow.md#beware-of-gh-base-repo-resolution).

## The script

```shell
script/upstream.sh check     # assert the boundary is intact — offline, no network
script/upstream.sh setup     # create or repair the remote, idempotently
script/upstream.sh fetch     # fetch upstream without tags, then report divergence
script/upstream.sh status    # how far the two have diverged
```

`check` asserts seven things: the `origin` URL, the `upstream` URL, the disabled push URL, the
`--no-tags` setting, that the derivation baseline commit exists in the clone, that it is an ancestor
of `HEAD`, and that no inherited upstream release tag has appeared. It reads the baseline SHA from
`docs/legal/ORIGIN.md` instead of carrying its own copy, so provenance keeps exactly one source of
truth.

Run `check` after cloning, and before adopting upstream work.

## When to adopt upstream work

Adopt it when it is worth reviewing, not on a schedule. SceneMux does not promise to track upstream —
divergence is expected, because SceneMux is a task-oriented orchestration layer rather than a WinMux
rebrand.

Worth adopting:

- A correctness or safety fix in the inherited engine — window management, the Accessibility layer,
  the tree, config parsing, the CLI/server protocol.
- A performance fix in a path SceneMux still uses unchanged.
- A macOS-compatibility fix for a new OS release.

Usually not worth adopting:

- Upstream product identity, branding, marketing copy, or release plumbing. SceneMux owns its own.
- Features that contradict the SceneMux domain model — anything that makes a Scene equal a numbered
  workspace, or a Slot equal a pixel rectangle.
- A change that would require unpicking the SceneMux layer to apply. Take the idea, not the diff.

## How to adopt it

Adoption is a normal ticketed change: a branch, a worktree, a pull request, the full verification and
the self-review loop from [`workflow.md`](workflow.md). Nothing merges to `main` outside a pull
request, and upstream commits are never force-pushed onto `main`.

```shell
script/upstream.sh check
script/upstream.sh fetch
git log --oneline HEAD..upstream/main            # what upstream has that SceneMux does not
git merge upstream/main                          # a whole sync
git cherry-pick <sha>                            # one fix
```

Prefer `cherry-pick` for a single fix and `merge` for a whole sync. Either way the commit message says
which upstream commit it came from, so the boundary stays greppable. Record the adopted upstream SHA
range in the pull request body.

## How to review a conflict

`git log <baseline>..main` is the exact list of SceneMux-owned commits, so any conflicting hunk
belongs to one of three groups. Decide by group, not file by file:

**1. SceneMux identity — keep the SceneMux side.**
Product name, bundle identifiers, config paths (`~/.config/scenemux/scenemux.toml`), the `scenemux`
CLI name, `SCENEMUX_*` exec variables, the app icon and logo, the Sparkle configuration, `README.md`,
`makefile` release plumbing, `project.yml`. Adopting upstream's version of any of these would
re-brand SceneMux back to WinMux — the exact regression `script/test_update_feed_isolation.py` and the
identity work in HORO-1097 exist to prevent.

**2. Inherited engine internals — take the upstream side.**
Names like `WinMuxPackage`, `WinMuxAny`, `applyWinMuxLayer` and `JSONEncoder.winMuxDefault` are
deliberately left inherited so that these hunks apply cleanly. Do not rename them to reduce a
conflict; renaming *causes* the next one. Never run a global `s/WinMux/SceneMux/g`.

**3. Inherited inputs that SceneMux still accepts — keep both.**
The `WINMUX_*` exec variables, the `during-winmux-startup` matcher key, the `setWinMuxFullscreen`
agent operation and the WinMux/AeroSpace config import all exist so that an inherited setup keeps
working. A conflict here is resolved by keeping the alias *and* the canonical spelling, never by
dropping either.

After resolving: `make build VERSION=0.0.0`, `source ./script/setup.sh && swift test`, the three guard
scripts, and `script/upstream.sh check`. A sync that silently changes SceneMux identity is a failed
sync even when it compiles.

## Keeping conflicts cheap

Add a seam only when it removes a conflict you have actually hit. Speculative abstraction over
inherited engine internals costs more than the conflict it was meant to avoid, because every upstream
hunk then lands on code that no longer looks like upstream's.

In practice:

- New SceneMux behaviour goes in new files, not as edits threaded through inherited ones.
- Where inherited code must call into SceneMux, add one call site, not a refactor of its surroundings.
- Where SceneMux needs different behaviour, prefer a parameter or an injected policy over an edit to
  the inherited algorithm.
- Leave inherited formatting, ordering and naming alone. A cosmetic edit is a permanent conflict for
  no benefit.

## When a fix belongs upstream

If a defect reproduces in unmodified WinMux — i.e. it is in the inherited engine and does not depend
on any SceneMux change — it is an upstream defect. Fixing it only here means carrying the patch
forever and re-resolving it at every sync.

For those, offer the fix upstream: a small, SceneMux-free patch against WinMux, submitted from a
separate clone or a personal fork of WinMux. **Not through this repository's `upstream` remote** — its
push URL is disabled on purpose, and this repository's history is not a suitable source for an
upstream pull request.

Keep the two records separate: a pre-existing upstream defect is not a SceneMux regression, and
labelling it as one wastes the next person's time. See
[`baseline-verification.md`](baseline-verification.md) for the inherited-behaviour baseline this
distinction is measured against.
