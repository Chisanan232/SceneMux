"""Prove the Scene Core domain layer stays independent of the inherited engine.

Invariant I12 of docs/design/scene-core-architecture.md: `scene/domain/` imports
`Foundation` only, and names no engine type. That is what makes the meaning of the
product testable without a window server, and what keeps an `upstream` merge of
WinMux from touching SceneMux's own layer.

A rule like this decays the moment it is only written down, because the convenient
thing to do is always to reach for the engine type that is already there. So it is
checked here, in the guards job, where reaching for it fails the build.
"""

import re
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SOURCES = REPO / "Sources"
DOMAIN = SOURCES / "AppBundle" / "scene" / "domain"

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

        cls.engine_types = set()
        for path in swift_files(SOURCES):
            if DOMAIN in path.parents:
                continue
            cls.engine_types.update(DECLARATION.findall(path.read_text()))
        cls.engine_types -= cls.domain_types | SYNTHESIZED

    def test_the_domain_layer_exists(self):
        # Without this, every check below would pass by having nothing to check.
        self.assertTrue(self.domain_files, f"no Swift files under {DOMAIN}")
        self.assertIn("Scene", self.domain_types)
        self.assertIn("Slot", self.domain_types)

    def test_engine_type_names_were_actually_collected(self):
        # And without this, "no engine type is named" could pass by finding no engine
        # types at all — a green check that proves nothing.
        for sentinel in ("Workspace", "TreeNode", "MacWindow", "Monitor"):
            self.assertIn(sentinel, self.engine_types, f"{sentinel} should be an engine type")

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


if __name__ == "__main__":
    unittest.main()
