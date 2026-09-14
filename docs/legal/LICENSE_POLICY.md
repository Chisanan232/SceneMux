# License policy

This document states how SceneMux is licensed today, what contributors are
agreeing to, and how a new dependency's license is evaluated. Its purpose is to
keep ownership unambiguous *before* any commercial strategy is decided, so that
no future decision is foreclosed by an accidental license entanglement.

## Current license

SceneMux is distributed under the **MIT License** — the same license as its
upstream WinMux and its ancestor AeroSpace. See `LICENSE.txt`.

MIT is inherited rather than chosen freshly: the inherited code is MIT, and
relicensing someone else's MIT code under different terms is not something a
downstream project may do unilaterally. Any change to SceneMux's license strategy
is therefore a deliberate decision requiring the project owner, not a routine
maintenance change.

### What is and is not covered

| | License holder |
| --- | --- |
| Code reachable from baseline commit `e0ad328e109cb6d2f86b1bdbc3aea9bf7bc5935e` | Zimeng Xiong (WinMux), and AeroSpace authors upstream of that |
| Commits added to `main` after that baseline | SceneMux contributors |

Both sets are MIT. The upstream copyright notice and permission notice ship with
every distribution, as MIT requires, and are not removed or replaced because the
product brand changed.

## Contribution expectations

* Contributions are accepted under the MIT License. Opening a pull request means
  you are licensing your contribution under those terms and confirming you have
  the right to do so.
* Do not paste code from a source whose license you have not read. Code of
  unknown provenance is the single most expensive kind of contribution to
  unwind later.
* Do not copy code from a strong-copyleft or source-available project into this
  repository, even in a small helper. Reimplement from documented behaviour
  instead, or add the project as a dependency after the review below.
* Attribute inherited or adapted code in-place when it comes from somewhere other
  than the WinMux baseline, and add it to `THIRD_PARTY_NOTICES.md`.
* No CLA is required. There is no copyright assignment: contributors keep their
  copyright and license it under MIT.

## Dependency license review

Every new dependency is reviewed before it is merged. Classification drives the
outcome:

| Class | Example SPDX identifiers | Outcome |
| --- | --- | --- |
| **Permissive — allowed** | `MIT`, `BSD-2-Clause`, `BSD-3-Clause`, `Apache-2.0`, `ISC`, `Zlib`, `0BSD`, `Unlicense` | Allowed. Record it in `THIRD_PARTY_NOTICES.md` and ship the notice. |
| **Weak copyleft — requires explicit review** | `LGPL-*`, `MPL-2.0`, `EPL-2.0`, `CDDL-1.0` | Blocked pending an explicit, recorded decision. Dynamic-vs-static linking and per-file obligations must be assessed against how the app is actually built and distributed. |
| **Strong copyleft — requires explicit review, expected to be refused** | `GPL-*`, `AGPL-*` | Blocked. Would impose reciprocal source obligations on SceneMux's own distribution. |
| **Source-available / non-OSI — requires explicit review, expected to be refused** | `SSPL-*`, `BUSL-*`, `Elastic-2.0`, `CC-BY-NC-*`, any custom "free for non-commercial use" term | Blocked. These are not open-source licenses and typically restrict exactly the commercial optionality this policy protects. |
| **Unknown / unstated** | no `LICENSE` file, `NOASSERTION`, ambiguous multi-license | Blocked. An unstated license is not permission. |

"Requires explicit review" means a human decision recorded in the pull request
that adds the dependency, naming the obligation accepted and why. It does not
mean "merge it and revisit later".

### A note on `NOASSERTION`

An SPDX identifier of `NOASSERTION` from an automated scanner means the scanner
could not classify the file — not that the license is unusable. Sparkle is the
current example: its `LICENSE` is MIT text followed by an `EXTERNAL LICENSES`
section for bundled C components, which defeats automatic detection. The correct
response is to read the file and record the real terms, which is what
`THIRD_PARTY_NOTICES.md` does. The correct response is never to guess.

## Repeatable license inventory

`script/license-inventory.py` is the automation for this policy. It cross-checks
three sources that can silently drift apart:

1. `Package.resolved` — what the build actually resolves.
2. `legal/dependency-licenses.json` — the reviewed manifest, with an SPDX
   identifier and notice file per dependency.
3. `legal/third-party-license/` — the notice texts that ship to users.

It fails if a resolved dependency is missing from the manifest, if a manifest
entry no longer appears in the resolved set, if a declared notice file is absent
from disk, or if any declared license falls outside the permissive class without
a recorded review. Run it with:

```shell
python3 script/license-inventory.py
```

It needs no network access and no third-party Python packages, so it is safe to
run in CI and offline. Wiring it into pull-request CI is HORO-1098's scope; until
then it is run manually and before every release.

### Deliberate initial narrowness

The check covers **Swift Package Manager pins plus manually recorded vendored
material**. It does not attempt to walk transitive C/C++ sources vendored inside
those packages, because Swift Package Manager exposes no reliable machine-readable
license graph for them and a heuristic file-scanner would produce more false
alarms than findings. Such material is handled by reading the dependency's own
license file and recording it explicitly — `tomlplusplus`, vendored inside
TOMLKit, is the current example.

## Boundaries of this document

This document describes license obligations only. It makes no claim about
trademark rights, App Store or Mac App Store eligibility, patent grants beyond
what the listed licenses themselves provide, or any commercial right not
contained in those licenses. It is not legal advice.
