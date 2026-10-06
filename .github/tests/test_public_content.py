"""Pair-programmed by SE Community + Cortex Code."""

import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest

script = Path(__file__).resolve().parents[1] / "scripts/check-public-content.py"
spec = importlib.util.spec_from_file_location("public_content", script)
policy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(policy)


class PublicContentTests(unittest.TestCase):
    def test_private_paths_at_any_depth(self):
        for name in ["guide/.env", "nested/.env.production", "a/key.P8",
                     "_archive/README.md", "nested/.cursor/state.json",
                     ".claude/settings.local.json", "guide/.claude/projects/log.json",
                     ".cortex/mcp.json", ".snowflake/cortex/plans/plan.md",
                     "guide/.builddemo-state.json", "audit_reports/result.md"]:
            with self.subTest(name=name):
                self.assertIsNotNone(policy.path_problem(name))

    def test_public_tooling_and_templates_remain_allowed(self):
        for name in ["AGENTS.md", ".claude/skills/example/SKILL.md",
                     "guide/.cortex/skills/example/SKILL.md", ".env.example",
                     "nested/.env.template", ".github/tests/test_policy.py"]:
            self.assertIsNone(policy.path_problem(name), name)

    def test_host_exceptions_are_exact_not_file_or_line_wide(self):
        host = "privateorg-privateaccount" + ".snowflakecomputing.com"
        text = "placeholder example <YOUR_VALUE> " + host
        self.assertEqual(policy.scan_text(text), [(1, "literal Snowflake account hostname")])
        self.assertEqual(policy.scan_text("example\n" + host)[0][0], 2)
        self.assertTrue(policy.scan_text("https://" + host + "/api"))
        self.assertTrue(policy.scan_text("xy98765.us-east-1" + ".snowflakecomputing.com"))
        self.assertTrue(policy.scan_text("xy12345.attacker" + ".snowflakecomputing.com"))

    def test_placeholder_hosts_and_public_example_are_allowed(self):
        for text in ["<org>-<account>.snowflakecomputing.com",
                     "${ACCOUNT}.snowflakecomputing.com",
                     "<account-identifier>.snowflakecomputing.com",
                     "xy12345.snowflakecomputing.com"]:
            self.assertEqual(policy.scan_text(text), [], text)

    def test_narratives_and_internal_links(self):
        samples = ["Internal " + "material describes improvements",
                   "current internal " + "launch signals",
                   "These came from internal " + "channels",
                   "## What Was " + "Verified in This Guide",
                   "The authoring " + "account lacked privileges",
                   "/Users/" + "person/private/file",
                   "https://snowflake" + ".slack.com/archives/C123",
                   "https://snowflake" + ".atlassian.net/wiki/page"]
        for text in samples:
            self.assertTrue(policy.scan_text(text), text)

    def test_text_types_deletions_and_binary_review(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            host = "privateorg-privateaccount" + ".snowflakecomputing.com"
            for name in ["README.md", "page.html", "config.json", "notes.txt"]:
                (root / name).write_text(host)
            (root / "image.png").write_bytes(b"\x89PNG\0")
            failures, binaries = policy.check_paths(
                root, ["README.md", "page.html", "config.json", "notes.txt", "removed.md", "image.png"])
            self.assertEqual(len(failures), 4)
            self.assertEqual(binaries, ["image.png"])

    def test_symlink_rejected_without_reading_target(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "link").symlink_to(root / "missing")
            failures, _ = policy.check_paths(root, ["link", "../outside"])
            self.assertEqual(len(failures), 2)

    def test_clean_index_and_untracked_files_are_scanned(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            subprocess.run(["git", "init", "-q", str(root)], check=True)
            (root / "README.md").write_text("safe")
            subprocess.run(["git", "-C", str(root), "add", "README.md"], check=True)
            # A clean index comparison does not control the full-file scanner.
            (root / "README.md").write_text("## What Was " + "Verified in This Guide")
            (root / "new.md").write_text("safe new file")
            (root / ".gitignore").write_text("_archive/\n")
            (root / "_archive").mkdir()
            (root / "_archive/private.md").write_text("ignored")
            names = policy.candidate_paths(root)
            self.assertIn("README.md", names)
            self.assertIn("new.md", names)
            self.assertNotIn("_archive/private.md", names)
            result = subprocess.run(["python3", str(script)], cwd=root, capture_output=True, text=True)
            self.assertEqual(result.returncode, 1)
            self.assertIn("README.md:1: authoring ledger", result.stdout)
            self.assertNotIn("## What Was", result.stdout)


if __name__ == "__main__":
    unittest.main()
