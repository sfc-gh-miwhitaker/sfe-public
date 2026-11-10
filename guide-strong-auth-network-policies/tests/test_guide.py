"""Pair-programmed by SE Community + Cortex Code.

Documentation and SQL invariants for the strong auth network policy guide.
Live behavior is verified by running the scripts on the test account.
"""

from pathlib import Path
import re
import unittest


PROJECT = Path(__file__).resolve().parents[1]
SQL = PROJECT / "sql"
READ_ONLY = ("01_find_at_risk_users.sql", "02_inventory_ips_per_user.sql",
             "03_recommend_and_generate.sql", "05_monitor.sql")


def executable(source):
    """Strip comments and string literals."""
    return re.sub(r"--[^\n]*|/\*.*?\*/|'(?:''|[^'])*'", " ", source, flags=re.S)


class StrongAuthNetworkPolicyGuideTests(unittest.TestCase):
    def setUp(self):
        self.readme = (PROJECT / "README.md").read_text()
        self.scripts = {p.name: p.read_text() for p in SQL.glob("*.sql")}

    def test_read_only_scripts_change_nothing(self):
        for name in READ_ONLY:
            body = executable(self.scripts[name])
            self.assertNotRegex(body, r"\b(CREATE|ALTER|DROP|GRANT|INSERT|UPDATE|DELETE|MERGE)\b", name)

    def test_internal_snowflake_ip_excluded(self):
        for name in ("02_inventory_ips_per_user.sql", "03_recommend_and_generate.sql"):
            self.assertIn("'0.0.0.0'", self.scripts[name], name)

    def test_never_attaches_account_policy(self):
        for name, text in self.scripts.items():
            self.assertNotRegex(executable(text), r"ALTER\s+ACCOUNT\s+SET\s+NETWORK_POLICY", name)

    def test_generator_drafts_only_reviewed_addresses(self):
        self.assertIn("review_flag IN ('STABLE', 'REVIEW')", self.scripts["03_recommend_and_generate.sql"])

    def test_runbook_defaults_to_practice_user(self):
        self.assertIn("SET svc_user   = 'SFE_NETPOL_PRACTICE_SVC'", self.scripts["04_evaluate_attach_migrate.sql"])

    def test_runbook_order(self):
        text = executable(self.scripts["04_evaluate_attach_migrate.sql"])
        steps = [text.index(s) for s in ("EVALUATE_CANDIDATE_NETWORK_POLICY", "SET NETWORK_POLICY",
                                         "ADD PROGRAMMATIC ACCESS TOKEN", "SET TYPE = SERVICE", "UNSET PASSWORD")]
        self.assertEqual(steps, sorted(steps))

    def test_teardown_preserves_shared_database(self):
        body = executable(self.scripts["99_teardown.sql"])
        self.assertNotRegex(body, r"DROP\s+DATABASE")
        for name in ("SFE_NETPOL_PRACTICE_SVC", "SFE_NETPOL_PRACTICE_ROLE", "SFE_NETPOL_PRACTICE"):
            self.assertIn(name, body)

    def test_no_temp_tables(self):
        for name, text in self.scripts.items():
            self.assertNotIn("TEMPORARY TABLE", text.upper(), name)

    def test_no_real_ip_addresses(self):
        allowed = {"0.0.0.0"}
        for path in PROJECT.rglob("*"):
            if path.suffix in {".md", ".sql"}:
                for ip in re.findall(r"\b\d{1,3}(?:\.\d{1,3}){3}\b", path.read_text()):
                    self.assertIn(ip, allowed, f"{path.name}: {ip}")

    def test_readme_links_resolve(self):
        for target in re.findall(r"\]\(((?:sql/|ELI5)[^)#]+)", self.readme):
            self.assertTrue((PROJECT / target).exists(), target)

    def test_every_script_is_linked(self):
        for name in self.scripts:
            self.assertIn(f"sql/{name}", self.readme, name)

    def test_dates_agree(self):
        expires = re.search(r"\*\*Expires:\*\* (\d{4}-\d{2}-\d{2})", self.readme).group(1)
        self.assertIn(expires.replace("-", "--"), self.readme)
        self.assertIn(expires, (PROJECT / "ELI5.md").read_text())
        for name, text in self.scripts.items():
            self.assertIn(expires, text, name)

    def test_no_em_dashes(self):
        for path in PROJECT.rglob("*"):
            if path.suffix in {".md", ".sql", ".py"}:
                self.assertNotIn("\u2014", path.read_text(), str(path))


if __name__ == "__main__":
    unittest.main()
