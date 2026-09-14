# Development workflow

This is the tool-agnostic source of truth for how a change reaches `main` in this repository.
Humans and agents follow the same rules. If any other file disagrees with this one, this one wins
(see [`AGENTS.md`](../../AGENTS.md) for the precedence order).

## One ticket, one worktree

Every change belongs to a ticket in the [`HORO` Jira project](https://lightning-dust-mite.atlassian.net).
Work happens in a dedicated git worktree created from the latest `main`, never in the primary
working tree and never directly on `main`.

Worktrees live **outside** the repository working tree, so a build in one ticket can never see
another ticket's files:

```shell
git -C <repo> fetch origin --prune
git -C <repo> worktree add <worktrees-root>/SceneMux/<TICKET> -b <branch> origin/main
```

Preconditions before the first commit of a ticket:

1. `origin` is `https://github.com/Chisanan232/SceneMux.git` — verify it, do not assume the current
   directory is the repository you think it is.
2. The base is the current `origin/main`, freshly fetched.
3. The tree is clean.

After the ticket's pull request is merged: fetch, confirm `origin/main` contains the merge, then
remove the worktree (`git worktree remove <path>` + `git worktree prune`) and create the next
ticket's worktree from the updated `main`.

### `upstream` is read-only

This repository also has an `upstream` remote pointing at the project it derives from
(see [`docs/legal/ORIGIN.md`](../legal/ORIGIN.md)). Its push URL is deliberately disabled. Never
push to it, and never publish a release against it — see
[Beware of `gh` base-repo resolution](#beware-of-gh-base-repo-resolution).

Run `script/upstream.sh check` to assert the boundary is intact. Adopting upstream work, deciding a
conflict and offering a fix upstream are covered by
[`upstream-sync.md`](upstream-sync.md).

## Branch naming

```
<version-or-phase>/<ticket>/<short-summary>
```

- `<version-or-phase>` — the release or phase the work lands in: `phase-0`, `phase-1`, `v0.2.0`.
- `<ticket>` — the exact ticket key, e.g. `HORO-1098`.
- `<short-summary>` — two to four words, `kebab-case`.

Example: `phase-0/HORO-1098/development-governance`.

When the ticket states a branch name, use that exact name.

## Commits: one small coherent change each

**One commit is one very small coherent change.** Rename one variable. Add one data model. Add one
property. Add one helper. Add one mock. Adjust one logic unit. Add one test. Rename one config
identity. Reset one version field.

A single test is one commit. A helper, a mock, a fixture and the test that uses them are four
commits. Never create an "implement the whole ticket" commit.

The reason is reviewability: a reader must be able to reconstruct *what* was done and *in what
order* from `git log --oneline` alone.

### Commit message format

```
<GitEmoji> (<scope>): <key point as summary>
```

The emoji is a literal Unicode emoji from [gitmoji.dev](https://gitmoji.dev). The scope is the
affected area — `scene`, `branding`, `agent`, `config`, `ci`, `legal`, `release`, … The summary is
imperative and ends with a period.

```
✨ (scene): Add Scene identifier value type.
♻️ (branding): Rename release product to SceneMux.
✅ (scene): Add Scene lifecycle transition test.
🔒️ (update): Isolate SceneMux Sparkle feed.
📝 (legal): Record WinMux derivation baseline.
🐛 (release): Pin gh release publishing to the SceneMux repository.
👷 (ci): Add the macOS build and test pull request job.
```

### Generated files dirty the tree

`make` regenerates `Sources/Common/versionGenerated.swift` and
`Sources/Common/gitHashGenerated.swift`, which are both tracked. Any build therefore leaves those
two files modified. Restore them before committing:

```shell
git checkout -- Sources/Common/versionGenerated.swift Sources/Common/gitHashGenerated.swift
```

`git commit` stages nothing on its own but commits everything already in the index — run
`git status --short` before `git add`, so a stray generated file does not ride along in an otherwise
atomic commit.

## Verification before a pull request

| What | Command | Requirement |
| --- | --- | --- |
| Build | `make build VERSION=0.0.0` | exit 0, zero errors, zero warnings |
| Tests | `source ./script/setup.sh && swift test` | zero failures |
| Update-feed isolation | `python3 script/test_update_feed_isolation.py` | pass |
| Appcast validation | `python3 script/test_validate_appcast.py` | pass |
| License inventory | `python3 script/license-inventory.py` | pass |

Building needs the **macOS 26 SDK**, i.e. Xcode 26 or newer. The inherited UI calls the Liquid Glass
API `glassEffect` behind a runtime `if #available(macOS 26.0, *)` check, and a runtime check still
needs the symbol at compile time. On Xcode 16 the build fails in
`Sources/AppBundle/ui/core/DesignTokens.swift` with `value of type 'Color' has no member
'glassEffect'`. The deployment target stays macOS 13.

Source `script/setup.sh` before running `swift` directly. It defines a `swift` function that runs
`swiftly run swift`, which resolves the toolchain pinned in `.swift-version`. A bare `swift` is
whichever toolchain Xcode happens to ship — a different compiler from the one CI and `make build` use.

`swift build --target AppBundleTests` **compiles** the tests without running them. It is not a
substitute for `swift test`.

CI runs the suite twice — once as above and once as `swift test -c release`. The table asks only for
the debug run because it is the fast one, but run the release one locally too when a change touches
command parsing, configuration bootstrap or anything the settings UI writes back to disk: HORO-1175
was a crash that existed only under `-O`, and a debug run cannot see that class of defect.

A cold Swift or Xcode build can take longer than ten minutes. Run it in the background and grep the
log for `error:` and the recorded exit code rather than trusting a truncated tail.

## Pull requests

- **Never merge locally into `main`.** Every change reaches `main` through a pull request.
- Title: `[<ticket>] <GitEmoji> (<scope>): <key point as summary>`.
- Body: follow [`.github/PULL_REQUEST_TEMPLATE.md`](../../.github/PULL_REQUEST_TEMPLATE.md). Every
  section is answered; a section that does not apply says so and why.
- Open it against the right repository explicitly:
  `gh pr create --repo Chisanan232/SceneMux --base main --head <branch>`.

### Self-review loop — mandatory

After implementation and before merge, review your own change as an independent senior reviewer
would:

1. Does it satisfy every acceptance criterion in the ticket, not just the easy ones?
2. Is anything out of the ticket's scope? Is anything in scope missing?
3. Is the layering respected — SceneMux code above the derived engine, not tangled into it?
4. Are inherited names left alone where renaming them would break `upstream` merges?
5. Is provenance and licensing untouched or correctly updated?
6. Does every commit hold exactly one small change, with a correct emoji, scope and summary?
7. Are there leftover debugging aids, dead code, commented-out code, or committed build artifacts?
8. Are new behaviours covered by tests, and do the tests assert behaviour rather than internals?
9. Do the security questions in the template have real answers — permissions, update feed and
   signing, persisted state, shell execution, file paths, logging of window contents?
10. Is anything destructive newly reachable from corrupted or unexpected state?
11. Is user-visible text accurate, including help text and documentation?
12. Does the documentation still match the code after the change?
13. Is the evidence in the PR body reproducible from the commands quoted, with real output?
14. Are the known limitations honest and each assigned to a follow-up ticket?

**If the review finds anything: fix it with atomic commits, rerun the full verification, and perform
the entire review again from the top.** Repeat until a pass finds nothing. Do not merge because the
change "looks probably okay".

## Merging

- Merge method is **Create a merge commit**. Squash and rebase merging are disabled on the
  repository; do not re-enable them.
- If required checks are merely pending, wait for them.
- Administrator merge is acceptable to get a verified change in, but **never** to bypass a failing
  required check and **never** to bury an unresolved review defect.
- After merging: fetch, confirm the merge commit is on `origin/main`, then record the pull request
  URL, the merge commit SHA and the verification evidence on the Jira ticket and transition it to
  Done.

## UI work

UI changes require the application to actually be built and launched, with evidence. Native AppKit
and SwiftUI cannot be verified with a browser automation tool. See
[`ui-verification.md`](ui-verification.md).

## Releases

Releases are tag-and-GitHub-Release events performed only from a verified, merged `main`. See
[`release.md`](release.md).

## Beware of `gh` base-repo resolution

A bare `gh` command in this repository resolves to the **`upstream`** remote, i.e. to the project
SceneMux derives from — not to SceneMux:

```shell
$ gh repo view --json nameWithOwner -q .nameWithOwner
ZimengXiong/winmux
```

Always pass `--repo Chisanan232/SceneMux` (or export `GH_REPO=Chisanan232/SceneMux`) to every `gh`
invocation that reads or writes repository state: pull requests, merges, releases, tags. The
`release` target in the `makefile` does this for you through the `RELEASE_REPO` variable.
