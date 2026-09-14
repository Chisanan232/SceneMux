# Contributing to SceneMux

SceneMux is developed ticket by ticket, and the same rules apply to humans and to agents.

| Read this | For |
| --- | --- |
| [`docs/development/workflow.md`](docs/development/workflow.md) | Worktrees, branch names, commit granularity, pull requests, the mandatory self-review loop, merging |
| [`docs/development/ui-verification.md`](docs/development/ui-verification.md) | How native AppKit/SwiftUI UI is verified, and screenshot discipline |
| [`docs/development/release.md`](docs/development/release.md) | Release preconditions, tagging, GitHub Releases, postconditions |
| [`docs/release/RELEASE_MAPPING.md`](docs/release/RELEASE_MAPPING.md) | The one-to-one mapping between Git tags, GitHub Releases and Jira Fix Versions |
| [`docs/development/upstream-sync.md`](docs/development/upstream-sync.md) | The `origin`/`upstream` convention, when to adopt upstream work, how to decide a conflict, and when a fix belongs upstream |
| [`docs/development/baseline-verification.md`](docs/development/baseline-verification.md) | How the inherited engine behaves, so a SceneMux regression can be told apart from inherited behaviour |
| [`docs/legal/ORIGIN.md`](docs/legal/ORIGIN.md) | Where this code comes from, the exact derivation baseline, and the upstream sync policy |
| [`docs/legal/LICENSE_POLICY.md`](docs/legal/LICENSE_POLICY.md) | How a new dependency or contribution is reviewed |
| [`AGENTS.md`](AGENTS.md) | The orientation an automated contributor needs, and the precedence order of all of the above |

## The short version

1. One ticket, one branch, one worktree created from the latest `origin/main`. Never commit on
   `main`.
2. Branch name: `<version-or-phase>/<ticket>/<short-summary>`.
3. One commit is one very small coherent change, described as
   `<GitEmoji> (<scope>): <key point as summary>`.
4. Verify before opening a pull request:
   ```shell
   make build VERSION=0.0.0                       # zero errors, zero warnings
   source ./script/setup.sh && swift test         # zero failures, pinned toolchain
   python3 script/test_update_feed_isolation.py
   python3 script/test_validate_appcast.py
   python3 script/license-inventory.py
   ```
5. Open a pull request titled `[<ticket>] <GitEmoji> (<scope>): <summary>`, filling in every section
   of [the template](.github/PULL_REQUEST_TEMPLATE.md) with real evidence.
6. Self-review your own change as an independent reviewer would; fix what you find, rerun the
   verification, and review again until a pass finds nothing.
7. Merge with **Create a merge commit**. Squash and rebase merging are disabled here on purpose.

## Two things this repository will not accept

**Silent relicensing or lost attribution.** SceneMux derives from WinMux (MIT), which derives from
AeroSpace (MIT). Inherited copyright headers, license texts and third-party notices stay.
`python3 script/license-inventory.py` fails the build if the reviewed manifest, what the build
resolves, and the notices that ship stop agreeing.

**A blind global rename.** Product-facing identity is SceneMux; inherited engine internals keep their
inherited names so that merges from `upstream` remain tractable.
