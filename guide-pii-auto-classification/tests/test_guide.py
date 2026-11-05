"""Pair-programmed by SE Community + Cortex Code.

Documentation and SQL invariants for the PII auto-classification guide.
Live behavior is verified by running sql/walkthrough.sql on the test account.
"""

from pathlib import Path
import re
import unittest


PROJECT = Path(__file__).resolve().parents[1]
SQL = PROJECT / "sql"


def executable(source):
    """Strip comments and string literals."""
    return re.sub(r"--[^\n]*|/\*.*?\*/|'(?:''|[^'])*'", " ", source, flags=re.S)


class PiiAutoClassificationGuideTests(unittest.TestCase):
    def setUp(self):
        self.walkthrough = (SQL / "walkthrough.sql").read_text()
        self.teardown = (SQL / "teardown.sql").read_text()
        self.readme = (PROJECT / "README.md").read_text()

    def test_profile_never_set_on_shared_database(self):
        body = executable(self.walkthrough)
        self.assertNotRegex(body, r"ALTER\s+DATABASE[^;]*CLASSIFICATION_PROFILE")
        self.assertRegex(body, r"ALTER\s+SCHEMA\s+SNOWFLAKE_EXAMPLE\.PII_DATA\s+SET\s+CLASSIFICATION_PROFILE")

    def test_profile_unset_before_replace(self):
        unset = self.walkthrough.index("UNSET CLASSIFICATION_PROFILE")
        replace = self.walkthrough.index("CLASSIFICATION_PROFILE PII_PROFILE(")
        self.assertLess(unset, replace)

    def test_no_placeholders_to_edit(self):
        self.assertNotRegex(executable(self.walkthrough), r"<[a-z_]+>")

    def test_teardown_preserves_shared_database(self):
        body = executable(self.teardown)
        self.assertNotRegex(body, r"DROP\s+DATABASE")
        for name in ("PII_DATA", "PII_GOVERNANCE", "SFE_PII_CLASSIFICATION_WH",
                     "PII_ANALYST", "PII_CLASSIFICATION_ADMIN"):
            self.assertIn(name, body)

    def test_sample_data_is_synthetic(self):
        self.assertIn("@example.com", self.walkthrough)
        self.assertIn("(555) ", self.walkthrough)

    def test_readme_links_resolve(self):
        for target in re.findall(r"\]\(((?:sql/|ELI5)[^)#]+)", self.readme):
            self.assertTrue((PROJECT / target).exists(), target)

    def test_dates_agree(self):
        expires = re.search(r"\*\*Expires:\*\* (\d{4}-\d{2}-\d{2})", self.readme).group(1)
        self.assertIn(expires.replace("-", "--"), self.readme)
        self.assertIn(expires, self.walkthrough)
        self.assertIn(expires, (PROJECT / "ELI5.md").read_text())

    def test_no_em_dashes(self):
        for path in PROJECT.rglob("*"):
            if path.suffix in {".md", ".sql", ".py"}:
                self.assertNotIn("\u2014", path.read_text(), str(path))


if __name__ == "__main__":
    unittest.main()
