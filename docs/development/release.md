# Release procedure

This is the tool-agnostic source of truth for releasing SceneMux. A release is an annotated Git tag
plus a GitHub Release plus recorded Jira evidence — never one of the three on its own.

Naming of tags, Fix Versions and Release titles is fixed by
[`docs/release/RELEASE_MAPPING.md`](../release/RELEASE_MAPPING.md). That table is authoritative; this
document does not restate it.

An agent following this procedure may use the repository skill at
`.claude/skills/scenemux-release/SKILL.md`, which is a thin wrapper around this document. When the
two disagree, this document wins.

## Preconditions

Every one of these must hold before anything is tagged. Each is checkable; none is a judgement call.

| # | Precondition | How it is checked |
| --- | --- | --- |
| 1 | The release ticket's work is merged. Its pull request state is `MERGED`. | `gh pr view <n> --repo Chisanan232/SceneMux --json state,mergeCommit` |
| 2 | Local `main` equals `origin/main`, freshly fetched, with a clean tree. | `git fetch origin --prune`, `git status --short --branch` |
| 3 | The commit to be tagged is on `origin/main` and is a merge commit of a reviewed pull request. | `git log origin/main --oneline -1`, `git cat-file -p <sha> \| grep ^parent` |
| 4 | The repository is standalone: not a fork, no parent, no source. | `gh repo view Chisanan232/SceneMux --json isFork,parent` |
| 5 | The inherited history is present and the derivation baseline matches `docs/legal/ORIGIN.md`. | `git log --oneline \| wc -l`, `git cat-file -t <baseline sha>` |
| 6 | No inherited upstream SemVer tag exists in this repository. | `git tag --list` (see the version-lineage rule in the mapping) |
| 7 | Provenance and legal records are present and consistent. | `python3 script/license-inventory.py` |
| 8 | The update feed is still isolated. | `python3 script/test_update_feed_isolation.py` |
| 9 | The appcast validator still passes its own tests. | `python3 script/test_validate_appcast.py` |
| 10 | The build is clean. | `make build VERSION=<version>` — exit 0, zero errors, zero warnings |
| 11 | Tests pass. | `swift test` — zero failures |
| 12 | CI on the release commit is green, or every non-green check is explained in the release ticket. | `gh pr checks` / `gh api repos/Chisanan232/SceneMux/commits/<sha>/check-runs` |
| 13 | A Release build succeeds and the app launches. | `make release VERSION=<version> PUBLISH=0`, then run the binary |
| 14 | Screenshot or artifact evidence for the release gate exists. | see [`ui-verification.md`](ui-verification.md) |
| 15 | The Jira Fix Version for this tag exists, and its work items are all Done. | Jira REST `/rest/api/3/version/<id>` and a JQL on `fixVersion` |
| 16 | Release notes are written and distinguish SceneMux-owned work from the inherited foundation, and state what is **not** included. | review the drafted notes |

If a precondition cannot be met, stop and record why on the release ticket. Do not tag around it.

## Signing

`make release` archives with `CODESIGN_IDENTITY` and then asserts that the signature's authority
matches `EXPECTED_CODESIGN_AUTHORITY_PREFIX`. Both are overridable, as is `CODE_SIGN_STYLE`.

```shell
# Developer ID / Apple Development identity present in the keychain (preferred)
make release VERSION=0.1.0 CODESIGN_IDENTITY="Apple Development" DEVELOPMENT_TEAM=<team>

# No signing identity available: ad-hoc signature, honestly labelled as such
make release VERSION=0.0.0 \
    CODESIGN_IDENTITY=- \
    CODE_SIGN_STYLE=Manual \
    EXPECTED_CODESIGN_AUTHORITY_PREFIX='Signature=adhoc'
```

An ad-hoc signed build is **not** notarized and **not** Gatekeeper-approved: macOS will require the
user to right-click and choose *Open* on first launch. That is acceptable for a foundation release
only if the release notes say so. Notarization (`NOTARIZE=1`, `NOTARYTOOL_PROFILE=<profile>`) needs
Apple credentials and is a human-authorized step — never invent or reuse credentials to satisfy it.

## Procedure

1. **Draft the notes.** State what SceneMux itself delivered, what is inherited foundation, and — as
   its own explicit list — what is *not yet* included. A reader must not be able to mistake inherited
   engine capability for SceneMux-owned work.
2. **Build the artifact** with `make release VERSION=<version> PUBLISH=0` and verify it: bundle
   version fields, `codesign --verify`, the absence of `SUFeedURL` and `SUPublicEDKey` from the built
   `Info.plist`, and the app launching. No `appcast.xml` is produced — see
   [Update feed](#update-feed).
3. **Create the annotated tag** on the verified `origin/main` commit and push it:
   ```shell
   git tag -a v<version> <sha> -m "SceneMux v<version> — <theme>"
   git push origin v<version>
   ```
   Tags are never moved and never force-pushed once published.
4. **Publish the GitHub Release** against this repository explicitly:
   ```shell
   gh release create v<version> --repo Chisanan232/SceneMux \
       --title "SceneMux v<version> — <theme>" --notes-file <notes>
   ```
   Publish it yourself rather than letting `make release` do it: with `PUBLISH=1` the target titles
   the Release `<app name> <version>` (`SceneMux 0.0.0`), which is not the title the mapping
   requires. Build with `PUBLISH=0`, then create the Release explicitly with the mapped title.
   A bare `gh` here resolves to the `upstream` remote; see the warning in
   [`workflow.md`](workflow.md#beware-of-gh-base-repo-resolution). `make release` pins `--repo`
   through `RELEASE_REPO` for the same reason.
5. **Attach the artifacts**: the `.zip` and, once SceneMux publishes an update feed, `appcast.xml`.

## Postconditions

| # | Postcondition | How it is checked |
| --- | --- | --- |
| 1 | The annotated tag exists on the remote and points at the verified commit. | `git ls-remote --tags origin`, `git cat-file -t v<version>` is `tag` |
| 2 | The GitHub Release exists under `Chisanan232/SceneMux`, with the title from the mapping. | `gh release view v<version> --repo Chisanan232/SceneMux` |
| 3 | The release notes contain the "not yet included" list. | read the published notes |
| 4 | The Jira release ticket records the commit SHA, the tag, the Release URL and the verification evidence. | the Jira comment |
| 5 | The Jira Fix Version is released, with the correct release date. | Jira REST `/rest/api/3/version/<id>` |
| 6 | The release ticket and its parent Story are Done. | Jira |
| 7 | No unintended tag or release was created against the `upstream` repository. | `gh release list --repo Chisanan232/SceneMux` and nothing new upstream |

## Update feed

SceneMux ships with **no** Sparkle feed until it owns a signed release channel. Do not add
`SUFeedURL` or `SUPublicEDKey` to `resources/SceneMux-Info.plist` or to `project.yml` as part of a
release. `script/test_update_feed_isolation.py` enforces this and additionally requires that any
feed added later points at `https://github.com/Chisanan232/SceneMux/releases/`.

Publishing a feed is a security decision — it grants a signing key the power to replace the
application on users' machines — and is made deliberately, not as a side effect of a release.

`make release` therefore defaults to `APPCAST=0`: it builds and verifies the archive, and generates
no appcast. The inherited pipeline generated one unconditionally, which is the wrong default for a
project with no feed — Sparkle's `generate_appcast` needs an ed25519 private key in the keychain to
sign the archive, so an unconditional appcast step turns "create the key that can replace the
application on every user's machine" into a prerequisite for building a release at all.

When SceneMux does own a signed release channel, that ordering is what changes:

1. create the ed25519 key pair with Sparkle's `generate_keys`, which stores the private half in the
   keychain and prints the public half — this is the step that requires human authorization, because
   it is the moment the signing power comes into existence;
2. add `SUFeedURL` (pointing at `https://github.com/Chisanan232/SceneMux/releases/`) and the printed
   `SUPublicEDKey` under their own reviewed change, not during a release;
3. release with `APPCAST=1`, which generates `appcast.xml`, validates it with
   `script/validate-appcast.py`, and attaches it to the GitHub Release.

Step 1 is what `APPCAST=1` technically depends on: without the private key in the keychain,
`generate_appcast` reports `Private key for account ed25519 not found in the Keychain (-25300)`, and
`script/validate-appcast.py` then rejects the unsigned archive. Steps 2 and 3 are not enforced by the
build, which is exactly why they are written down here: a signed appcast that no shipped build points
at is a feed nobody consumes, and a feed key created ahead of the reviewed decision to have one is
the thing this default exists to prevent.
