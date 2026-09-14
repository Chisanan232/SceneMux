#!/usr/bin/env python3
"""Cross-check SceneMux's dependency licenses against the reviewed manifest.

Three things can silently drift apart: what the build actually resolves, what a
human reviewed, and what notices ship to users. This script fails when they do.

  Package.resolved              what Swift Package Manager resolves
  legal/dependency-licenses.json  what was reviewed, with an SPDX id per entry
  legal/third-party-license/    the notice texts that ship

Checks performed:
  1. every spm-pin in the manifest is present in Package.resolved
  2. every pin in Package.resolved is present in the manifest
  3. every declared notice file exists on disk and is non-empty
  4. every entry states an SPDX identifier, and every term is in the allowlist

Needs no network access and no third-party packages, so it is safe in CI and
offline. See docs/legal/LICENSE_POLICY.md for how a license class is decided.

Exit status: 0 when the inventory is consistent, 1 when it is not.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
MANIFEST = REPO_ROOT / "legal" / "dependency-licenses.json"
RESOLVED = REPO_ROOT / "Package.resolved"

# An SPDX expression may combine terms, e.g. "MIT AND BSD-2-Clause AND Zlib".
# Split on the operators so each term is checked against the allowlist.
SPDX_SPLIT = re.compile(r"\s+(?:AND|OR|WITH)\s+")


def spdx_terms(expression: str) -> list[str]:
    return [term.strip("()") for term in SPDX_SPLIT.split(expression) if term.strip("()")]


def main() -> int:
    manifest = json.loads(MANIFEST.read_text())
    resolved = json.loads(RESOLVED.read_text())

    allowlist = set(manifest["permissive_allowlist"])
    entries = manifest["dependencies"]
    by_identity = {e["identity"]: e for e in entries}
    pinned = {p["identity"] for p in resolved["pins"]}
    declared_pins = {e["identity"] for e in entries if e["source"] == "spm-pin"}

    problems: list[str] = []

    # 1 + 2. the resolved set and the reviewed set must agree exactly.
    for identity in sorted(declared_pins - pinned):
        problems.append(
            f"{identity}: recorded as an spm-pin in the manifest but absent from "
            f"Package.resolved. If it was removed, drop it from the manifest too."
        )
    for identity in sorted(pinned - declared_pins):
        entry = by_identity.get(identity)
        if entry is None:
            problems.append(
                f"{identity}: resolved by Swift Package Manager but not in the manifest. "
                f"Review its license and add it — see docs/legal/LICENSE_POLICY.md."
            )
        else:
            problems.append(
                f"{identity}: resolved as an spm-pin but the manifest records it as "
                f"source={entry['source']!r}. Correct the source field."
            )

    # 3. notices must actually ship.
    for entry in entries:
        notice = REPO_ROOT / entry["notice"]
        if not notice.is_file():
            problems.append(f"{entry['identity']}: notice file {entry['notice']} is missing.")
        elif notice.stat().st_size == 0:
            problems.append(f"{entry['identity']}: notice file {entry['notice']} is empty.")

    # 4. licenses must be stated, and must be permissive. An absent or blank SPDX
    # field is a failure in its own right: an unstated license is not permission,
    # and without this check an empty string would pass the loop below silently.
    for entry in entries:
        expression = (entry.get("spdx") or "").strip()
        if not expression:
            problems.append(
                f"{entry['identity']}: no SPDX license identifier recorded. An unstated "
                f"license is not permission — see docs/legal/LICENSE_POLICY.md."
            )
            continue
        for term in spdx_terms(expression):
            if term not in allowlist:
                problems.append(
                    f"{entry['identity']}: license term {term!r} is not in the permissive "
                    f"allowlist. It requires an explicit recorded review before merging — "
                    f"see docs/legal/LICENSE_POLICY.md."
                )

    # Report the inventory whether or not it passed: a failing run should still
    # show what the state actually is.
    versions = {p["identity"]: p["state"].get("version") or p["state"]["revision"][:12]
                for p in resolved["pins"]}
    width = max(len(e["name"]) for e in entries)
    print(f"{'DEPENDENCY'.ljust(width)}  {'SOURCE':<10} {'VERSION':<14} LICENSE")
    for entry in sorted(entries, key=lambda e: (e["source"], e["identity"])):
        version = versions.get(entry["identity"], "-")
        spdx = (entry.get("spdx") or "").strip() or "UNSTATED"
        print(f"{entry['name'].ljust(width)}  {entry['source']:<10} {version:<14} {spdx}")

    print()
    if problems:
        print(f"FAIL: {len(problems)} license inventory problem(s):")
        for problem in problems:
            print(f"  - {problem}")
        return 1

    print(f"OK: {len(entries)} dependencies recorded, {len(pinned)} Swift Package Manager "
          f"pins reconciled, all notices present, all licenses permissive.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
