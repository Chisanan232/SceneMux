# Release mapping

SceneMux is planned in Jira and released from Git. Those two systems use
different naming styles on purpose: Jira Fix Version names are descriptive so a
human scanning a backlog knows what the release *means*, while Git tags stay
strict SemVer so tooling can compare them. This document is the single
authoritative mapping between them.

**Every Jira Fix Version maps one-to-one to exactly one Git tag and exactly one
GitHub Release.** There are no many-to-one or one-to-many relationships.

| Git tag | GitHub Release title | Jira Fix Version | Jira version ID | Planned release date |
| --- | --- | --- | --- | --- |
| `v0.0.0` | SceneMux v0.0.0 — Independent Foundation | `SceneMux v0.0.0 / Independent Foundation` | `10199` | 2026-09-15 |
| `v0.1.0` | SceneMux v0.1.0 — Scene Core | `SceneMux v0.1.0 / Scene Core` | `10200` | 2026-09-21 |

Jira project: `HORO` at <https://lightning-dust-mite.atlassian.net>.

## Rules

* The Git tag is the canonical release identifier. Tags are plain SemVer
  (`v<major>.<minor>.<patch>`) and are never renamed to match a Jira label.
* A Jira Fix Version name is `SceneMux <git tag> / <theme>`. The tag embedded in
  the name is what makes the mapping unambiguous without consulting this table.
* The GitHub Release title is `SceneMux <git tag> — <theme>`, using the same
  theme as the Fix Version. Em dash in GitHub, slash in Jira; the theme text
  itself must match.
* Do not create a second Jira version for a tag that already has one. Reuse the
  existing version instead.
* Do not publish a Git tag that has no corresponding Jira Fix Version.

## Version lineage

SceneMux's release namespace starts at `v0.0.0` and is entirely its own.

SceneMux inherits its Git history from WinMux, which had already reached
`v0.5.4`. Those 13 inherited SemVer tags (`v0.1.1` … `v0.5.4`) were deliberately
**not** pushed into the SceneMux repository: `0.5.4` outranks `0.0.0` and
`0.1.0` in any SemVer comparison, so their presence would corrupt release
ordering, update-feed resolution, and "latest release" lookups. They are
recorded as provenance only.

The exact derivation baseline is recorded separately under `docs/legal/`
(HORO-1096).

## Campaign work-item allocation

| Fix Version | Jira work items |
| --- | --- |
| `SceneMux v0.0.0 / Independent Foundation` | HORO-1093, HORO-1095, HORO-1096, HORO-1097, HORO-1098, HORO-1099, HORO-1100, HORO-1111 |
| `SceneMux v0.1.0 / Scene Core` | HORO-1094, HORO-1101 … HORO-1110 |

The delivery Epic HORO-1092 references both Fix Versions, since it spans both
releases. Discovery Idea HVDL-28 carries no Fix Version: it is a Product
Discovery record, not delivery work.
