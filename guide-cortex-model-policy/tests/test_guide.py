"""Pair-programmed by SE Community + Cortex Code.

Documentation regression checks; these do not certify live access enforcement.
"""

from pathlib import Path
import re
import unittest


PROJECT = Path(__file__).resolve().parents[1]
ROOT = PROJECT.parent


def sql_without_literals_and_comments(source):
    """Remove SQL string bodies so generated command text is not executable SQL."""
    return re.sub(r"--[^\n]*|'(?:''|[^'])*'", " ", source)


def assert_inventory_read_only(source):
    executable = sql_without_literals_and_comments(source)
    for statement in executable.split(";"):
        if statement.strip() and not re.match(r"\s*(SHOW|SELECT)\b", statement, re.I):
            raise AssertionError("Inventory permits only SHOW and SELECT statements")
    if re.search(r"\b(GRANT|REVOKE|ALTER|CREATE|DROP|CALL|EXECUTE|INSERT|UPDATE|"
                 r"DELETE|MERGE|TRUNCATE|COPY|PUT|REMOVE)\b", executable, re.I):
        raise AssertionError("Executable mutation in inventory")
    allowed_functions = {
        "CURRENT_ACCOUNT", "CURRENT_ROLE", "CURRENT_SECONDARY_ROLES",
        "SYSTEM$BEHAVIOR_CHANGE_BUNDLE_STATUS", "SUBSTR", "LENGTH", "REPLACE",
        "CHR", "LOWER",
    }
    called_functions = set(re.findall(r"\b([A-Z_][A-Z0-9_$]*)\s*\(", executable.upper()))
    if called_functions - allowed_functions:
        raise AssertionError(f"Non-inventory functions: {called_functions - allowed_functions}")


class ModelPolicyGuideTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.readme = (PROJECT / "README.md").read_text()
        cls.inventory = (PROJECT / "sql/01_inventory.sql").read_text()
        cls.operations = (PROJECT / "docs/01-OPERATIONS.md").read_text()

    def test_inventory_has_no_executable_mutations_or_inference(self):
        assert_inventory_read_only(self.inventory)

    def test_read_only_guard_rejects_mutations_and_model_calls(self):
        for statement in (
            "DELETE FROM example_table;", "INSERT INTO example_table VALUES (1);",
            "UPDATE example_table SET value = 1;", "TRUNCATE TABLE example_table;",
            "SELECT AI_EMBED('example', 'text');", "SELECT AI_SENTIMENT('text');",
            "SELECT SYSTEM$ENABLE_BEHAVIOR_CHANGE_BUNDLE('2026_07');",
            "CALL example_procedure();", "SELECT AI_COMPLETE('example', 'text');",
        ):
            with self.subTest(statement=statement), self.assertRaises(AssertionError):
                assert_inventory_read_only(statement)

    def test_generated_approval_excludes_all_role(self):
        self.assertIn('WHERE "name" <> \'CORTEX-MODEL-ROLE-ALL\'', self.inventory)
        self.assertIn("AS grant_sql", self.inventory)
        self.assertNotRegex(self.inventory, r"(?i)(kimi|claude|qwen|openai|llama)-")

    def test_show_scope_and_both_public_paths_are_preserved(self):
        for text in (self.inventory, self.readme):
            self.assertIn("SHOW CORTEX BASE MODELS IN SCHEMA SNOWFLAKE.MODELS", text)
            self.assertIn("SHOW GRANTS TO APPLICATION ROLE SNOWFLAKE.PUBLIC", text)
            self.assertIn("SHOW GRANTS TO ROLE PUBLIC", text)

    def test_revoke_output_is_paired_and_scoped(self):
        self.assertIn('"granted_to" = \'ROLE\'', self.inventory)
        self.assertIn('"grantee_name" <> \'ACCOUNTADMIN\'', self.inventory)
        self.assertIn("AS restore_sql", self.inventory)
        self.assertIn("AS restore_sql", self.operations)
        self.assertIn("REPLACE(\"grantee_name\", '\"', '\"\"')", self.inventory)

    def test_test_generator_handles_errors_and_caps_output(self):
        self.assertIn("return_error_details => TRUE", self.inventory)
        self.assertIn("max_tokens", self.inventory)
        self.assertIn(": 16}", self.inventory)
        self.assertIn("Do not execute TEST_SQL for embedding", self.inventory)
        self.assertIn("A null response alone", self.readme)
        self.assertIn("normal secondary-role configuration", self.readme)
        self.assertIn("do not sign off account-wide approved-only coverage", self.readme)

    def test_no_legacy_allowlist_reset_or_implicit_approval(self):
        for source in (self.readme, self.operations, self.inventory):
            self.assertNotRegex(
                source, r"CORTEX_MODELS_ALLOWLIST\s*=\s*'(?!None')[^']+'"
            )
        self.assertIn("disabled by default", self.readme)
        self.assertIn("Grant these before removing broad access", self.readme)

    def test_local_markdown_links_resolve(self):
        for markdown in PROJECT.rglob("*.md"):
            for target in re.findall(r"\]\(([^)]+)\)", markdown.read_text()):
                if target.startswith(("https://", "http://", "#")):
                    continue
                self.assertTrue(
                    (markdown.parent / target.split("#")[0]).exists(),
                    f"Broken link in {markdown}: {target}",
                )

    def test_guide_contract(self):
        self.assertIn("## Quick Start", self.readme[:2500])
        from datetime import date
        verified = date.fromisoformat(re.search(r"\*\*Last verified:\*\* (\d{4}-\d{2}-\d{2})", self.readme).group(1))
        expires = date.fromisoformat(re.search(r"\*\*Expires:\*\* (\d{4}-\d{2}-\d{2})", self.readme).group(1))
        self.assertGreaterEqual((expires - verified).days, 0)
        self.assertLessEqual((expires - verified).days, 60)
        self.assertIn("Expires-" + expires.isoformat().replace("-", "--"), self.readme)
        for relative in ("README.md", "ELI5.md", "AGENTS.md", "docs/01-OPERATIONS.md",
                         ".claude/skills/guide-cortex-model-policy/SKILL.md"):
            self.assertIn("Pair-programmed by SE Community + Cortex Code",
                          (PROJECT / relative).read_text())
        self.assertLess(len((PROJECT / "AGENTS.md").read_text().splitlines()), 100)
        skill = PROJECT / ".claude/skills/guide-cortex-model-policy/SKILL.md"
        self.assertLess(len(skill.read_text().splitlines()), 200)
        self.assertFalse((PROJECT / "deploy_all.sql").exists())

    def test_root_catalog_and_path_registration(self):
        self.assertIn("(guide-cortex-model-policy/)", (ROOT / "README.md").read_text())
        self.assertIn("`guide-cortex-model-policy`", (ROOT / "AGENTS.md").read_text())


if __name__ == "__main__":
    unittest.main()
