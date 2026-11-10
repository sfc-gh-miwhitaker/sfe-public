"""Pair-programmed by SE Community + Cortex Code.

Documentation and SQL invariants for the Sigma writeback guide.
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


class SigmaWritebackGuideTests(unittest.TestCase):
    def setUp(self):
        self.walkthrough = (SQL / "walkthrough.sql").read_text()
        self.teardown = (SQL / "teardown.sql").read_text()
        self.readme = (PROJECT / "README.md").read_text()

    def test_walkthrough_never_touches_real_sigma_tables(self):
        body = executable(self.walkthrough)
        self.assertNotRegex(body, r"SIGMA_WRITEBACK\.\"?SIGDS_")

    def test_quoted_identifier_case_pinned(self):
        self.assertIn("QUOTED_IDENTIFIERS_IGNORE_CASE = FALSE", self.walkthrough)

    def test_snapshot_task_not_resumed(self):
        self.assertNotRegex(executable(self.walkthrough), r"ALTER\s+TASK[^;]*RESUME")

    def test_no_placeholders_to_edit(self):
        self.assertNotRegex(executable(self.walkthrough), r"<[a-z_]+>")

    def test_teardown_preserves_shared_database(self):
        body = executable(self.teardown)
        self.assertNotRegex(body, r"DROP\s+DATABASE")
        for name in ("SIGMA_ANALYTICS", "SIGMA_LAB", "SIGMA_WRITEBACK", "SFE_SIGMA_WH",
                     "SIGMA_SERVICE_USER", "SIGMA_DATA_CONSUMER", "SIGMA_SERVICE_ROLE"):
            self.assertIn(name, body)

    def test_sample_data_is_synthetic(self):
        self.assertIn("@example.com", self.walkthrough)

    def test_readme_links_resolve(self):
        for target in re.findall(r"\]\(((?:sql/|ELI5)[^)#]+)", self.readme):
            self.assertTrue((PROJECT / target).exists(), target)

    def test_related_guides_are_external(self):
        section = self.readme.split("## Related Guides", 1)[1].split("##", 1)[0]
        for target in re.findall(r"\]\(([^)]+)\)", section):
            self.assertTrue(target.startswith("https://"), target)

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
