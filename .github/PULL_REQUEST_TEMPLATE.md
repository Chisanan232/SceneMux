<!--
Title format: [<ticket>] <GitEmoji> (<scope>): <key point as summary>
Example:      [HORO-1098] 👷 (ci): Add the pull request build and test workflow.

Answer every section. A section that does not apply says "Not applicable" and why — an empty
section reads as an unanswered question. See docs/development/workflow.md.
-->

## Jira ticket

<!-- Ticket link, parent Story/Epic, and the Fix Version this lands in. -->

## Objective

<!-- One paragraph: what this change is for. -->

## Scope

<!-- What actually changed. Group it so a reviewer can navigate the diff. -->

## Out of scope

<!-- What a reader might reasonably expect here but will not find, and which ticket owns it. -->

## Architecture / design impact

<!--
Does this respect the layering — SceneMux code above the derived engine rather than tangled into it?
Does it keep inherited engine names intact where renaming them would break an `upstream` merge?
Does it change any public contract (CLI, config keys, agent operations, persisted state)?
If it introduces or changes a domain concept (Semantic Home, Scene, Slot, Mount, ownership,
admission), state the contract, not just the code.
-->

## Test evidence

<!--
Commands and their real output. Not "tests pass".

| Check | Command | Result |
| --- | --- | --- |
| Build | `make build VERSION=0.0.0` | exit 0, 0 errors, 0 warnings |
| Tests | `source ./script/setup.sh && swift test` | N tests, 0 failures |
| Update-feed isolation | `python3 script/test_update_feed_isolation.py` | OK |
| Appcast validation | `python3 script/test_validate_appcast.py` | OK |
| License inventory | `python3 script/license-inventory.py` | OK |

List the tests this PR adds. A behaviour change with no new test needs a reason.
-->

## Security review

<!--
Answer the ones this change can touch, and say so when it touches none:

- Accessibility / TCC permission: scope broadened? whose TCC entry is reset?
- Window and application metadata: what is read, what is persisted, what is logged?
- Update feed and code signing: any feed key, signing identity, or notarization change?
- Repository, tag or release operations: pinned to Chisanan232/SceneMux?
- Persisted Scene / world state: can corrupted state cause destructive close or move behaviour?
- Shell execution: any new free-form command execution? (do not add any merely for convenience)
- File paths and process identity: any new trust placed in a path or a process name?
- Secrets: none added, and none present in the diff.
-->

## UI verification

<!--
Required for any change a user can see. Native AppKit/SwiftUI is verified with XCTest/XCUITest,
Accessibility automation, AppleScript, or manual interaction on a real Mac — never with browser
automation. See docs/development/ui-verification.md.

State: what was built and launched, what was verified and how, what was NOT verified, why, and
which ticket carries it. Do not leave a gap implied.
-->

## Screenshots

<!--
Attach the evidence, and say what each image proves.

Never attach a full-screen capture: use `screencapture -o -l <windowID>`, `-R x,y,w,h`, or `-w`, or
prefer artifact-scoped evidence (rendered asset, extracted icon, PlistBuddy dump). If a capture
picks up anything private, delete it and say so here.

"No UI change" is a valid answer. Silence is not.
-->

## Known limitations

<!-- Honest list. Each item names the follow-up ticket that owns it. -->

## Release impact

<!--
Which Fix Version this targets. Anything breaking for existing users (CLI name, bundle id, config
path, config keys, agent operation names). Version or update-channel changes. Anything the release
notes must mention.
-->

## Self-review

<!-- Confirm the mandatory self-review loop in docs/development/workflow.md was run to a clean pass. -->

- [ ] I reviewed this change as an independent senior reviewer, fixed everything I found with atomic
      commits, reran the full verification, and repeated the review until a pass found nothing.
- [ ] Every commit is one small coherent change with a `<GitEmoji> (<scope>): <summary>` message.
- [ ] No generated file, build artifact, or debugging aid rode along in the diff.
- [ ] This will be merged with **Create a merge commit** — not squash, not rebase.
