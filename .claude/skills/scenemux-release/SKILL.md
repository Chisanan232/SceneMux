---
name: scenemux-release
description: Release SceneMux — verify the release gates, create the annotated Git tag, publish the GitHub Release, and record the evidence in Jira. Use when a Jira release ticket asks for a SceneMux version to be tagged and released.
---

# Releasing SceneMux

`docs/development/release.md` is the source of truth. This skill is the ordered checklist for
executing it; when the two disagree, the document wins. Read it before you start — it explains *why*
each gate exists, which matters when one of them fails.

Naming comes from `docs/release/RELEASE_MAPPING.md`. Never invent a tag, a Release title or a Fix
Version name.

## 0. Scope guard

A bare `gh` in this repository resolves to the `upstream` remote — the project SceneMux derives
from — not to SceneMux. Every `gh` call needs `--repo Chisanan232/SceneMux`.

```shell
git -C <repo> rev-parse --show-toplevel        # is this the repository you think it is?
git -C <repo> remote get-url origin            # https://github.com/Chisanan232/SceneMux.git
gh repo view Chisanan232/SceneMux --json isFork,parent,nameWithOwner
```

Stop if `isFork` is not `false`, or if `parent` is not `null`.

## 1. Verify the preconditions

Work through the numbered precondition table in `docs/development/release.md`. Record the actual
output of each check — that output is the evidence you will attach to Jira, so collect it as you go
rather than reconstructing it afterwards.

Do not proceed with a red or unexplained gate. A pending check is a reason to wait; a failing check is
a reason to stop.

## 2. Draft the release notes

Three parts, in this order:

1. What SceneMux itself delivered in this release.
2. What is inherited foundation from WinMux/AeroSpace — labelled as inherited.
3. **What is not yet included** — as its own explicit list.

A reader must not be able to mistake inherited engine capability for SceneMux-owned work, and must
not be able to assume a capability that is still on the roadmap.

## 3. Build and check the artifact

```shell
make release VERSION=<version> PUBLISH=0
```

Then confirm the archive's bundle version fields, `codesign --verify`, the generated `appcast.xml`,
and that the app launches. If no signing identity exists on the machine, use the ad-hoc invocation
documented in `docs/development/release.md` and say so in the release notes — never fabricate or
reuse Apple credentials, and never claim a build is notarized when it is not.

## 4. Tag and publish

```shell
git tag -a v<version> <verified-main-sha> -m "SceneMux v<version> — <theme>"
git push origin v<version>
gh release create v<version> --repo Chisanan232/SceneMux \
    --title "SceneMux v<version> — <theme>" --notes-file <notes>
```

Published tags are never moved and never force-pushed.

## 5. Verify the postconditions and record evidence

Work through the postcondition table in `docs/development/release.md`. Then, on the Jira release
ticket, record: the release commit SHA, the tag, the GitHub Release URL, the build and test results,
the UI evidence, and anything a gate flagged. Mark the Jira Fix Version released with the date from
the mapping, and transition the release ticket and its parent Story to Done.

## Stop and ask a human when

- Apple signing or notarization credentials would be needed.
- Publishing an update feed is being considered — that grants a signing key the power to replace the
  application on users' machines.
- A precondition cannot be satisfied without changing what the release contains.
- The repository is not the standalone `Chisanan232/SceneMux` you expected.
