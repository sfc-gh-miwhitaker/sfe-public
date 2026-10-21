"""Pair-programmed by SE Community + Cortex Code.

Documentation regression checks; these do not exercise live replication.
"""

from pathlib import Path
import re
import unittest


PROJECT = Path(__file__).resolve().parents[1]
SQL = PROJECT / "sql"


def executable(source):
    """Strip comments and string literals."""
    return re.sub(r"--[^\n]*|/\*.*?\*/|'(?:''|[^'])*'", " ", source, flags=re.S)


class CrossCloudReplicationGuideTests(unittest.TestCase):
    def test_preflight_is_read_only(self):
        body = executable((SQL / "01_preflight.sql").read_text())
        for statement in filter(str.strip, body.split(";")):
            self.assertRegex(statement.strip(), r"^(USE ROLE|SHOW|SELECT)\b", statement)

    def test_cutover_is_commented_out(self):
        body = executable((SQL / "05_verify_and_cutover.sql").read_text())
        self.assertNotRegex(body, r"\b(PRIMARY|SUSPEND|RESUME)\s*;")

    def test_security_integrations_ship_with_roles(self):
        source = (SQL / "03_source_aws.sql").read_text()
        self.assertIn("SECURITY INTEGRATIONS", source)
        self.assertRegex(source, r"OBJECT_TYPES = [^']*\bROLES\b")

    def test_names_consistent_across_scripts(self):
        for name in ("ACCOUNT_FG", "PRIMARY_CONN", "AZURE_DR"):
            for script in ("03_source_aws.sql", "05_verify_and_cutover.sql"):
                if name == "AZURE_DR" and script.startswith("05"):
                    continue
                self.assertIn(name, (SQL / script).read_text(), f"{name} in {script}")

    def test_readme_links_resolve(self):
        readme = (PROJECT / "README.md").read_text()
        for target in re.findall(r"\]\(((?:sql/|ELI5)[^)#]+)", readme):
            self.assertTrue((PROJECT / target).exists(), target)

    def test_readme_dates_agree_with_badge(self):
        readme = (PROJECT / "README.md").read_text()
        expires = re.search(r"\*\*Expires:\*\* (\d{4}-\d{2}-\d{2})", readme).group(1)
        self.assertIn(expires.replace("-", "--"), readme)

    def test_billing_points_at_target(self):
        readme = (PROJECT / "README.md").read_text()
        self.assertIn("billed in the **target**", readme)


if __name__ == "__main__":
    unittest.main()
