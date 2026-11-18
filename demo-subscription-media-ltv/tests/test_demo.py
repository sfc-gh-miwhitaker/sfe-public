"""Pair-programmed by SE Community + Cortex Code.

Static invariants for the Subscription Media LTV demo. Live behavior is
verified by deploying to a test account and asking the demo script questions
through both agents.
"""

from pathlib import Path
import re
import unittest


PROJECT = Path(__file__).resolve().parents[1]
SQL = PROJECT / "sql"
EXPIRES = "2027-01-16"


def executable(source):
    """Strip comments and string literals."""
    return re.sub(r"--[^\n]*|/\*.*?\*/|'(?:''|[^'])*'", " ", source, flags=re.S)


class SubscriptionMediaLtvTests(unittest.TestCase):
    def setUp(self):
        self.deploy = (PROJECT / "deploy_all.sql").read_text()
        self.teardown = (PROJECT / "teardown_all.sql").read_text()
        self.readme = (PROJECT / "README.md").read_text()
        self.sql_files = sorted(SQL.rglob("*.sql"))

    def test_every_executed_script_exists(self):
        prefix = "@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_DEMOS_REPO/branches/main/demo-subscription-media-ltv/"
        paths = re.findall(r"EXECUTE IMMEDIATE FROM '([^']+)'", self.deploy)
        self.assertEqual(len(paths), 8)
        for path in paths:
            self.assertTrue(path.startswith(prefix), path)
            self.assertTrue((PROJECT / path[len(prefix):]).is_file(), path)

    def test_every_sql_file_is_deployed(self):
        deployed = set(re.findall(r"demo-subscription-media-ltv/(sql/[^']+)'", self.deploy))
        on_disk = {str(p.relative_to(PROJECT)) for p in self.sql_files}
        self.assertEqual(deployed, on_disk)

    def test_readme_tree_matches_files(self):
        tree = self.readme.split("## Project Structure", 1)[1].split("```", 2)[1]
        for line in tree.splitlines()[2:]:
            name = line.strip()
            if name:
                self.assertTrue((PROJECT / name).exists(), name)

    def test_generation_is_deterministic(self):
        for path in self.sql_files:
            body = executable(path.read_text()).upper()
            for banned in ("RANDOM(", "UNIFORM(", "CURRENT_DATE", "CURRENT_TIMESTAMP"):
                self.assertNotIn(banned, body, f"{banned} in {path.name}")

    def test_expiry_dates_agree(self):
        files = [PROJECT / "README.md", PROJECT / "deploy_all.sql", PROJECT / "teardown_all.sql"]
        files += self.sql_files
        for path in files:
            dates = set(re.findall(r"Expires:\s*(\d{4}-\d{2}-\d{2})", path.read_text()))
            self.assertLessEqual(dates, {EXPIRES}, path.name)
        self.assertIn("Expires-2027--01--16", self.readme)

    def test_every_created_object_has_demo_comment(self):
        for path in self.sql_files:
            text = path.read_text()
            for match in re.finditer(r"CREATE OR REPLACE (TABLE|VIEW|AGENT|SEMANTIC VIEW|SNOWFLAKE\.ML\.CLASSIFICATION) (\w+)", text):
                if match.group(2).startswith("TMP_"):
                    continue
                chunk = text[match.end():match.end() + 12000]
                stop = chunk.find(";")
                self.assertIn("DEMO:", chunk[:stop] if match.group(1) != "SEMANTIC VIEW" else chunk, match.group(2))

    def test_agents_use_auto_model_and_budget(self):
        agents = (SQL / "04_cortex" / "03_agents.sql").read_text()
        self.assertEqual(agents.count("orchestration: auto"), 2)
        self.assertEqual(agents.count("seconds:"), 2)
        self.assertEqual(agents.count("tokens:"), 2)

    def test_verified_queries_use_logical_names(self):
        sv = (SQL / "04_cortex" / "02_semantic_views.sql").read_text()
        queries = re.findall(r"SQL '(.*?)'\n", sv)
        self.assertEqual(len(queries), 8)
        for query in queries:
            self.assertNotIn("SNOWFLAKE_EXAMPLE", query)

    def test_teardown_preserves_shared_objects(self):
        body = executable(self.teardown).upper()
        self.assertNotRegex(body, r"DROP DATABASE")
        self.assertNotRegex(body, r"DROP SCHEMA IF EXISTS SNOWFLAKE_EXAMPLE\.(GIT_REPOS|SEMANTIC_MODELS|TOOLS)\b")
        self.assertNotIn("SFE_GIT_API_INTEGRATION", body)

    def test_warehouse_has_statement_timeout(self):
        self.assertIn("STATEMENT_TIMEOUT_IN_SECONDS = 3600", self.deploy)

    def test_no_placeholders_to_edit(self):
        for path in [PROJECT / "deploy_all.sql", PROJECT / "teardown_all.sql", *self.sql_files]:
            self.assertNotRegex(executable(path.read_text()), r"<[a-z_]+>", path.name)


if __name__ == "__main__":
    unittest.main()
