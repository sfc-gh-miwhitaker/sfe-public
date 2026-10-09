"""Pair-programmed by SE Community + Cortex Code."""

import importlib.util
import contextlib
import io
from unittest.mock import patch
import json
import tempfile
import unittest
from pathlib import Path

SPEC = importlib.util.spec_from_file_location(
    "generate_config", Path(__file__).resolve().parents[1] / "tools/generate_config.py"
)
GENERATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GENERATOR)


class ConfigTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.executable = self.root / "CoCo binary"
        self.executable.touch()
        self.workdir = self.root / "Task folder"
        self.workdir.mkdir()

    def test_paths_with_spaces_and_no_bypass(self):
        config = GENERATOR.build_config(str(self.executable), "development", str(self.workdir))
        server = config["mcpServers"]["coco-snowflake"]
        self.assertEqual(server["command"], str(self.executable.resolve()))
        self.assertEqual(server["args"], ["mcp", "serve", "--connection", "development", "--workdir", str(self.workdir.resolve())])
        self.assertEqual(json.loads(json.dumps(config)), config)
        self.assertEqual(set(server), {"command", "args"})

    def test_missing_executable_fails(self):
        for executable in [None, str(self.root / "absent")]:
            with self.subTest(executable=executable), self.assertRaisesRegex(ValueError, "CLI"):
                GENERATOR.build_config(executable, "development", str(self.workdir))

    def test_invalid_connection_fails(self):
        for connection in ["", "   ", "--bypass", "development\nother"]:
            with self.subTest(connection=connection), self.assertRaises(ValueError):
                GENERATOR.build_config(str(self.executable), connection, str(self.workdir))

    def test_missing_directory_fails(self):
        for directory in ["", str(self.root / "absent"), str(self.executable)]:
            with self.subTest(directory=directory), self.assertRaises(ValueError):
                GENERATOR.build_config(str(self.executable), "development", directory)

    def test_stdout_is_json_and_prompts_stay_on_stderr(self):
        stdout, stderr = io.StringIO(), io.StringIO()
        with patch.object(GENERATOR.shutil, "which", return_value=str(self.executable)), \
             patch("builtins.input", side_effect=["development", str(self.workdir)]), \
             contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            self.assertEqual(GENERATOR.main(), 0)
        self.assertIn("coco-snowflake", json.loads(stdout.getvalue())["mcpServers"])
        self.assertIn("preserve existing", stderr.getvalue())

    def test_invalid_input_emits_no_config(self):
        stdout, stderr = io.StringIO(), io.StringIO()
        with patch.object(GENERATOR.shutil, "which", return_value=str(self.executable)), \
             patch("builtins.input", side_effect=["--bypass", str(self.workdir)]), \
             contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            self.assertEqual(GENERATOR.main(), 1)
        self.assertEqual(stdout.getvalue(), "")
        self.assertIn("Cannot generate", stderr.getvalue())

    def test_no_files_are_changed(self):
        settings = self.root / "claude_desktop_config.json"
        original = '{"mcpServers":{"existing":{"command":"existing-tool"}}}'
        settings.write_text(original)
        before = sorted(str(file) for file in self.root.rglob("*"))
        GENERATOR.build_config(str(self.executable), "development", str(self.workdir))
        self.assertEqual(settings.read_text(), original)
        self.assertEqual(before, sorted(str(file) for file in self.root.rglob("*")))


if __name__ == "__main__":
    unittest.main()
