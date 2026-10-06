"""Pair-programmed by SE Community + Cortex Code."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "get-project.sh"


class RetrievalTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / "source"
        self.destination = self.root / "checkout"
        self.home = self.root / "home"
        self.home.mkdir()
        self.env = dict(os.environ, HOME=str(self.home), GIT_CONFIG_NOSYSTEM="1",
                        GIT_CONFIG_GLOBAL=os.devnull, SFE_REPOSITORY=str(self.source),
                        SFE_DESTINATION=str(self.destination))
        self.git("init", "-b", "main", str(self.source), cwd=self.root)
        for project in ("guide-first", "guide-new", "demo-test", "shared"):
            (self.source / project).mkdir()
            (self.source / project / "README.md").write_text("# Fixture\n")
        (self.source / "guide-no-readme").mkdir()
        (self.source / "guide-no-readme" / "notes.txt").write_text("Not a project")
        self.commit()

    def git(self, *args, cwd=None):
        return subprocess.run(["git", "-c", "core.hooksPath=/dev/null", "-c",
                               "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
                               *args], cwd=cwd or self.source, env=self.env,
                              capture_output=True, text=True, check=True)

    def commit(self):
        self.git("add", ".")
        self.git("commit", "-m", "fixture")

    def run_helper(self, name):
        return subprocess.run(["bash", str(SCRIPT), name], cwd=self.root, env=self.env,
                              capture_output=True, text=True)

    def test_list_and_new_project(self):
        result = self.run_helper("--list")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), ["demo-test", "guide-first", "guide-new"])
        self.assertFalse(self.destination.exists())

    def test_invalid_and_unknown(self):
        for name in ("../guide-first", "--upload-pack=oops", "guide-missing"):
            result = self.run_helper(name)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("list", result.stderr)
        self.assertFalse(self.destination.exists())

    def test_fresh_repeat_and_update(self):
        for name in ("guide-new", "demo-test"):
            result = self.run_helper(name)
            self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.destination / "guide-new/README.md").exists())
        self.assertFalse((self.destination / "guide-first").exists())
        (self.source / "guide-new/README.md").write_text("# Changed\n")
        self.commit()
        result = self.run_helper("guide-new")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.destination / "guide-new/README.md").read_text(), "# Changed\n")
        self.assertFalse((self.home / ".gitconfig").exists())
        self.assertFalse((self.home / ".config/git/hooks").exists())

    def test_dirty_checkout_refused(self):
        self.assertEqual(self.run_helper("guide-new").returncode, 0)
        target = self.destination / "guide-new/README.md"
        target.write_text("Keep my changes")
        result = self.run_helper("demo-test")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("local changes", result.stderr)
        self.assertEqual(target.read_text(), "Keep my changes")

    def test_wrong_destination_refused(self):
        self.git("init", str(self.destination), cwd=self.root)
        self.git("remote", "add", "origin", "https://example.invalid/other.git", cwd=self.destination)
        result = self.run_helper("guide-new")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("another repository", result.stderr)

    def test_divergent_checkout_refused(self):
        self.assertEqual(self.run_helper("guide-new").returncode, 0)
        (self.destination / "guide-new/README.md").write_text("Local commit")
        self.git("add", ".", cwd=self.destination)
        self.git("commit", "-m", "local fixture", cwd=self.destination)
        result = self.run_helper("demo-test")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("local or divergent commits", result.stderr)

    def test_ignored_local_files_are_preserved(self):
        (self.source / '.gitignore').write_text('local-notes.txt\n')
        self.commit()
        self.assertEqual(self.run_helper('guide-new').returncode, 0)
        notes = self.destination / 'local-notes.txt'
        notes.write_text('Must survive')
        result = self.run_helper('demo-test')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('ignored local files', result.stderr)
        self.assertEqual(notes.read_text(), 'Must survive')


if __name__ == "__main__":
    unittest.main()
