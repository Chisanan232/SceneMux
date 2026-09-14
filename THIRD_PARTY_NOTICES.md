# Third-party notices

SceneMux distributes code written by other people. This file lists all of it and
points at the license text that must accompany each piece. Every license below is
permissive, and every one requires that its copyright notice and permission
notice travel with the software — which is what this file and the
`legal/third-party-license/` directory exist to do.

The machine-readable form of this inventory is `legal/dependency-licenses.json`.
`script/license-inventory.py` reconciles it against `Package.resolved` and against
the notice files on disk, so this document cannot quietly fall out of date. Run:

```shell
python3 script/license-inventory.py
```

## Inherited codebase

SceneMux is a derivative work. These are not dependencies — they are the code
SceneMux is built out of.

### WinMux — MIT

* Source: <https://github.com/ZimengXiong/winmux>
* Copyright (c) 2026 Zimeng Xiong
* License text: [`legal/LICENSE.txt`](legal/LICENSE.txt)

The direct upstream. SceneMux derives from WinMux at baseline commit
`e0ad328e109cb6d2f86b1bdbc3aea9bf7bc5935e` (WinMux 0.5.4), and its window
engine is the foundation SceneMux builds on. SceneMux does not claim authorship
of that code. See [`docs/legal/ORIGIN.md`](docs/legal/ORIGIN.md).

### AeroSpace — MIT

* Source: <https://github.com/nikitabobko/AeroSpace>
* License text: [`legal/third-party-license/LICENSE-Aerospace.txt`](legal/third-party-license/LICENSE-Aerospace.txt)

The ancestral upstream: WinMux is itself a derivative of AeroSpace, so
AeroSpace's MIT terms flow through WinMux to SceneMux. Its notice is a
distribution obligation, not a courtesy.

### ShellParserGenerated — MIT

* Location: [`ShellParserGenerated/`](ShellParserGenerated/) (local Swift package in this repository)
* License text: [`legal/LICENSE.txt`](legal/LICENSE.txt)

The ANTLR-generated parser for the configuration language, committed to this
repository. Inherited from the WinMux baseline and covered by the same MIT terms.

## Bundled dependencies

Resolved by Swift Package Manager and linked into the shipped application.

### ANTLR v4 — BSD-3-Clause

* Source: <https://github.com/antlr/antlr4>, version 4.13.1
* License text: [`legal/third-party-license/LICENSE-antlr.txt`](legal/third-party-license/LICENSE-antlr.txt)

Parser generator for the built-in shell-like configuration language. Its
`Antlr4Static` runtime is statically linked into the app through the in-repo
`ShellParserGenerated` package, so the notice obligation applies to binary
distributions as well as source.

### HotKey — MIT

* Source: <https://github.com/soffes/HotKey>, version 0.2.1
* License text: [`legal/third-party-license/LICENSE-HotKey.txt`](legal/third-party-license/LICENSE-HotKey.txt)

Swift wrapper around the macOS Carbon API for listening to global keyboard
shortcuts.

### ISSoundAdditions — MIT

* Source: <https://github.com/InerziaSoft/ISSoundAdditions>, version 2.0.1
* License text: [`legal/third-party-license/LICENSE-ISSoundAdditions.txt`](legal/third-party-license/LICENSE-ISSoundAdditions.txt)

Convenience API for reading and changing the system output volume.

### MASShortcut — BSD-2-Clause

* Source: <https://github.com/rxhanson/MASShortcut>, revision `2f9fbb3f959b7a683c6faaf9638d22afad37a235`
* Copyright (c) 2012-2013, Vadim Shpakovski
* License text: [`legal/third-party-license/LICENSE-MASShortcut.txt`](legal/third-party-license/LICENSE-MASShortcut.txt)

Keyboard-shortcut recorder control used by the settings UI. Pinned to a revision
rather than a released version.

### Sparkle — MIT AND BSD-2-Clause AND Zlib

* Source: <https://github.com/sparkle-project/Sparkle>, version 2.9.6
* License text: [`legal/third-party-license/LICENSE-Sparkle.txt`](legal/third-party-license/LICENSE-Sparkle.txt)

Application auto-update framework, including EdDSA signature verification of
update archives.

Sparkle's license needs a word of explanation, because automated scanners report
it as `NOASSERTION` — its `LICENSE` file is MIT text followed by an
`EXTERNAL LICENSES` section for bundled C components, which defeats automatic
classification. Reading the file gives:

| Component | Terms |
| --- | --- |
| Sparkle itself | MIT — Andy Matuschak, Elgato Systems, Kornel Lesiński, Mayur Pawashe, C.W. Betts, Petroules Corporation, Big Nerd Ranch |
| `bspatch.c` / `bsdiff.c` from bsdiff 4.3 | BSD-2-Clause — Colin Percival |
| `sais.c` / `sais.h` from sais-lite | MIT — Yuta Mori |
| Portable Ed25519 implementation | Zlib — Orson Peters |
| `SUSignatureVerifier.m` | BSD-2-Clause — Mark Hamlin |

Every component is permissive. `NOASSERTION` here means "the scanner could not
tell", not "the license is unclear".

### swift-collections — Apache-2.0

* Source: <https://github.com/apple/swift-collections>, version 1.3.0
* License text: [`legal/third-party-license/LICENSE-swift-collections.txt`](legal/third-party-license/LICENSE-swift-collections.txt)

Additional Swift collection types such as ordered and deque containers.

### TOMLKit — MIT

* Source: <https://github.com/LebJe/TOMLKit>, version 0.5.5
* License text: [`legal/third-party-license/LICENSE-TOMLKIT.txt`](legal/third-party-license/LICENSE-TOMLKIT.txt)

Swift wrapper over the `tomlplusplus` C++ TOML parser; reads the user
configuration file.

### tomlplusplus — MIT

* Source: <https://github.com/marzer/tomlplusplus>
* License text: [`legal/third-party-license/LICENSE-tomlplusplus.txt`](legal/third-party-license/LICENSE-tomlplusplus.txt)

The actual TOML parser, used indirectly through TOMLKit's Swift API. It ships as
C++ sources inside TOMLKit rather than as a Swift Package Manager pin of its own,
so it is recorded manually rather than discovered from `Package.resolved`.

## Adding a dependency

Read [`docs/legal/LICENSE_POLICY.md`](docs/legal/LICENSE_POLICY.md) first. In
short: permissive licenses are allowed and must be recorded here; weak copyleft,
strong copyleft, source-available, and unknown licenses are blocked pending an
explicit recorded review. A dependency added without a manifest entry and a
notice file will fail `script/license-inventory.py`.
