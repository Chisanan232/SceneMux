# Agent guide

You are working on **SceneMux**, a task-oriented desktop application multiplexer for macOS.

> Stop managing windows. Start managing work.
> Every task has a scene. Every window has a place.

Native applications stay native. SceneMux orchestrates windows that other applications own; it does
not replace or reimplement them.

## Precedence order

More than one file can tell you how to work here. When they disagree, the earlier one wins:

1. The Jira ticket you are executing — its acceptance criteria are the contract.
2. [`docs/development/workflow.md`](docs/development/workflow.md) — worktrees, branches, commits,
   pull requests, self-review, merging.
3. [`docs/development/release.md`](docs/development/release.md) — release gates.
4. [`docs/development/ui-verification.md`](docs/development/ui-verification.md) — how to verify
   native UI.
5. [`docs/legal/LICENSE_POLICY.md`](docs/legal/LICENSE_POLICY.md) and
   [`docs/legal/ORIGIN.md`](docs/legal/ORIGIN.md) — licensing and provenance.
6. This file, for orientation.

`CLAUDE.md` and `.claude/skills/` are thin pointers into the documents above, never a second source
of truth.

## The rules that are easy to get wrong here

**This repository derives from another project.** SceneMux comes from
[WinMux](https://github.com/ZimengXiong/winmux) (MIT), which comes from
[AeroSpace](https://github.com/nikitabobko/AeroSpace) (MIT). The full inherited history is present in
this repository on purpose.

- Never silently relicense inherited code, and never remove an inherited copyright or notice. A
  material licensing change is a decision for the repository owner, not for you.
- **Never run a global `s/WinMux/SceneMux/g`.** Product-facing identity is SceneMux. Inherited
  engine-internal names (`WinMuxPackage`, `WinMuxAny`, `applyWinMuxLayer`,
  `JSONEncoder.winMuxDefault`, …) stay as they are so `upstream` merges remain tractable. The
  intended layering is `SceneMux.app` → SceneMux-specific layer → inherited engine.
- Inherited *inputs* keep working through documented aliases: a WinMux or AeroSpace config is
  imported by copy on first launch, `WINMUX_*` exec variables are still exported alongside
  `SCENEMUX_*`, the `during-winmux-startup` matcher is still accepted, and the
  `setWinMuxFullscreen` agent operation is still accepted next to `setSceneMuxFullscreen`.
- **`upstream` is read-only.** Its push URL is disabled. A bare `gh` command in this repository
  resolves to `upstream`, not to SceneMux — always pass `--repo Chisanan232/SceneMux`.
- **No inherited SemVer tag is a SceneMux release.** SceneMux's release namespace starts at
  `v0.0.0`. See [`docs/release/RELEASE_MAPPING.md`](docs/release/RELEASE_MAPPING.md).

**Treat these as security-sensitive**, and say what you did about them in the pull request:
Accessibility permission and TCC, window and application metadata, the update feed and code signing,
repository migration and release operations, persisted Scene state, shell execution, file paths,
process identity.

- Do not introduce free-form command execution to make window orchestration easier.
- Do not log window contents.
- Do not broaden Accessibility or TCC scope silently.
- Do not let corrupted persisted state reach destructive close or move behaviour.
- Do not use an administrator merge to bypass a failing check.

## Domain vocabulary

Use these words precisely; they are the product, not decoration.

| Term | Meaning |
| --- | --- |
| **Semantic Home** | Where a window *belongs* by purpose — Development, Communication, Observability, Personal. It is a property of the window, not a place on screen. Mounting a window into a Scene must not mutate its Semantic Home. |
| **Scene** | A task context, e.g. `Debug PROD-123`. A Scene is **not** a workspace with a number. |
| **Slot** | A semantic role inside a Scene — Editor, Terminal, Preview, Observability, Communication. A Slot is **not** a fixed pixel rectangle. |
| **Mount / Attachment** | A window temporarily participating in a Scene, without changing where it belongs. |
| **Ownership** | How a window's lifetime relates to the Scene: `borrowed` (restored when the Scene ends), `sceneOwned` (follows explicit cleanup), `sharedPersistent` (never touched by Scene teardown). |
| **Admission** | The decision made about a newly observed window. The typed model allows CLAIM, ROUTE, MOUNT, TAB, FLOAT, IGNORE and QUARANTINE. Unknown ordinary user windows fail safe: IGNORE. |

Do not infer ownership from an application's identity. A Chrome window is not an automation-owned
browser merely because it is Chrome.

## Building and running

```shell
make build VERSION=0.0.0   # SPM debug build; must be warning-free
swift test                 # the unit tests — `swift build --target AppBundleTests` only compiles them
make run                   # launch the debug app
make xcodeproj             # regenerate SceneMux.xcodeproj from project.yml
make release VERSION=x.y.z # Release archive; see docs/development/release.md before using it
```

`make` rewrites the tracked files `Sources/Common/versionGenerated.swift` and
`Sources/Common/gitHashGenerated.swift`. Restore them before committing.

## Before you open a pull request

Run the self-review loop in [`docs/development/workflow.md`](docs/development/workflow.md) to a clean
pass, fill in every section of [`.github/PULL_REQUEST_TEMPLATE.md`](.github/PULL_REQUEST_TEMPLATE.md)
with real evidence, and merge with **Create a merge commit**.
