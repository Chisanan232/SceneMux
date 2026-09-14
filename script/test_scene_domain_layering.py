"""Prove the Scene Core layers stay independent of the inherited engine.

Invariant I12 of docs/design/scene-core-architecture.md: `scene/domain/` imports
`Foundation` only, and names no engine type. That is what makes the meaning of the
product testable without a window server, and what keeps an `upstream` merge of
WinMux from touching SceneMux's own layer.

`scene/lifecycle/` is held to the same rule against the engine, for a different
reason: it decides what happens to a window and must never be able to do it. A
lifecycle that could reach a `MacWindow` would eventually reach one, and then
"nothing here touches a window" would be a comment rather than a fact.

`scene/engine/` is where the two worlds finally meet, so the rule there is about
width rather than height: exactly one file — the adapter — may name an engine
type, and everything else in the layer stays on the Scene side of the seam. A
seam that is only mostly narrow is not a seam.

A rule like this decays the moment it is only written down, because the convenient
thing to do is always to reach for the engine type that is already there. So it is
checked here, in the guards job, where reaching for it fails the build.
"""

import re
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SOURCES = REPO / "Sources"
SCENE = SOURCES / "AppBundle" / "scene"
DOMAIN = SCENE / "domain"
LIFECYCLE = SCENE / "lifecycle"
ENGINE = SCENE / "engine"

# The one file in the repository allowed to hold both vocabularies at once.
ADAPTER = ENGINE / "WinMuxSceneEngineAdapter.swift"

# Every kind of Swift declaration that introduces a type name.
DECLARATION = re.compile(
    r"^\s*(?:(?:public|internal|fileprivate|private|open|final|indirect)\s+)*"
    r"(?:struct|class|enum|protocol|actor|typealias)\s+([A-Za-z_]\w*)",
    re.MULTILINE,
)
IDENTIFIER = re.compile(r"\b[A-Za-z_]\w*\b")
LINE_COMMENT = re.compile(r"//[^\n]*")
BLOCK_COMMENT = re.compile(r"/\*.*?\*/", re.DOTALL)
IMPORT = re.compile(r"^\s*import\s+([A-Za-z_][\w.]*)", re.MULTILINE)

# Compiler-synthesized names that mean "this type's own coding keys" wherever they
# appear. The engine declares them too, but a shared spelling is not a shared type.
SYNTHESIZED = {"CodingKeys"}

# Named in prose, not in code: doc comments explain what the domain deliberately is
# not, and that explanation is the point of them.
def strip_comments(source: str) -> str:
    return LINE_COMMENT.sub("", BLOCK_COMMENT.sub("", source))


def swift_files(directory: Path) -> list[Path]:
    return sorted(directory.rglob("*.swift"))


class SceneDomainLayeringTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.domain_files = swift_files(DOMAIN)
        cls.domain_types = set()
        for path in cls.domain_files:
            cls.domain_types.update(DECLARATION.findall(path.read_text()))

        cls.lifecycle_files = swift_files(LIFECYCLE)
        cls.engine_files = [path for path in swift_files(ENGINE) if path != ADAPTER]

        # Two exclusion sets, because the two layers are allowed different things. The
        # domain may not name even a Scene Core type from another layer — it is the one
        # layer that describes the product on its own. The lifecycle may name Scene Core
        # freely, and the engine not at all.
        cls.engine_types = cls.declared_outside(DOMAIN) - cls.domain_types - SYNTHESIZED
        cls.engine_types_beyond_scene_core = cls.declared_outside(SCENE) - SYNTHESIZED

    @staticmethod
    def declared_outside(directory: Path) -> set[str]:
        declared = set()
        for path in swift_files(SOURCES):
            if directory in path.parents or path.parent == directory:
                continue
            declared.update(DECLARATION.findall(path.read_text()))
        return declared

    def test_the_domain_layer_exists(self):
        # Without this, every check below would pass by having nothing to check.
        self.assertTrue(self.domain_files, f"no Swift files under {DOMAIN}")
        self.assertIn("Scene", self.domain_types)
        self.assertIn("Slot", self.domain_types)

    def test_the_lifecycle_layer_exists(self):
        self.assertTrue(self.lifecycle_files, f"no Swift files under {LIFECYCLE}")
        self.assertIn("SceneWorld", {n for p in self.lifecycle_files for n in DECLARATION.findall(p.read_text())})

    def test_the_engine_layer_exists_and_has_exactly_one_adapter(self):
        self.assertTrue(self.engine_files, f"no Swift files under {ENGINE} besides the adapter")
        self.assertTrue(ADAPTER.is_file(), f"{ADAPTER.relative_to(REPO)} is missing")
        self.assertIn("SceneEnginePort", {n for p in self.engine_files for n in DECLARATION.findall(p.read_text())})

    def test_engine_type_names_were_actually_collected(self):
        # And without this, "no engine type is named" could pass by finding no engine
        # types at all — a green check that proves nothing.
        for sentinel in ("Workspace", "TreeNode", "MacWindow", "Monitor"):
            self.assertIn(sentinel, self.engine_types, f"{sentinel} should be an engine type")
            self.assertIn(sentinel, self.engine_types_beyond_scene_core, f"{sentinel} should be an engine type")

    def test_domain_imports_foundation_only(self):
        for path in self.domain_files:
            for module in IMPORT.findall(path.read_text()):
                self.assertEqual(
                    module,
                    "Foundation",
                    f"{path.relative_to(REPO)} imports {module}; the domain imports Foundation only",
                )

    def test_domain_names_no_engine_type(self):
        for path in self.domain_files:
            named = set(IDENTIFIER.findall(strip_comments(path.read_text())))
            trespassers = sorted(named & self.engine_types)
            self.assertEqual(
                trespassers,
                [],
                f"{path.relative_to(REPO)} names engine types {trespassers}; "
                "the adapter in scene/engine/ translates at the seam",
            )

    def test_lifecycle_imports_foundation_only(self):
        for path in self.lifecycle_files:
            for module in IMPORT.findall(path.read_text()):
                self.assertEqual(
                    module,
                    "Foundation",
                    f"{path.relative_to(REPO)} imports {module}; the lifecycle imports Foundation only",
                )

    def test_lifecycle_names_no_engine_type(self):
        for path in self.lifecycle_files:
            named = set(IDENTIFIER.findall(strip_comments(path.read_text())))
            trespassers = sorted(named & self.engine_types_beyond_scene_core)
            self.assertEqual(
                trespassers,
                [],
                f"{path.relative_to(REPO)} names engine types {trespassers}; deciding what happens to a "
                "window is this layer's job, and doing it is not",
            )


    def test_the_engine_layer_imports_foundation_only_apart_from_the_adapter(self):
        for path in self.engine_files:
            for module in IMPORT.findall(path.read_text()):
                self.assertEqual(
                    module,
                    "Foundation",
                    f"{path.relative_to(REPO)} imports {module}; only "
                    f"{ADAPTER.name} reaches across the seam",
                )


    def test_only_the_adapter_names_an_engine_type(self):
        for path in self.engine_files:
            named = set(IDENTIFIER.findall(strip_comments(path.read_text())))
            trespassers = sorted(named & self.engine_types_beyond_scene_core)
            self.assertEqual(
                trespassers,
                [],
                f"{path.relative_to(REPO)} names engine types {trespassers}; the seam is "
                f"{ADAPTER.name} and nothing else, so that it stays narrow enough to reason about",
            )

if __name__ == "__main__":
    unittest.main()
