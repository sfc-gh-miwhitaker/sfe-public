"""Pair-programmed by SE Community + Cortex Code."""
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest

script = Path(__file__).resolve().parents[1] / "scripts/expire-projects.py"
spec = importlib.util.spec_from_file_location("expiry", script)
expiry = importlib.util.module_from_spec(spec)
spec.loader.exec_module(expiry)


class ExpiryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        previous = Path.cwd()
        os.chdir(self.temp.name)
        self.addCleanup(os.chdir, previous)
        Path('site').mkdir()
        Path('site/retired.json').write_text('{"projects":{}}')
        Path('guide-old').mkdir()
        Path('guide-old/README.md').write_text('# Old\n**Expires:** 2000-01-01\n')
        Path('guide-old/workbook.html').write_text('fixture')
        Path('guide-old/AGENTS.md').write_text('not reader content')
        Path('guide-current').mkdir()
        Path('guide-current/README.md').write_text('# Current\n**Expires:** 2999-01-01\n')
        Path('README.md').write_text('Projects-2\n| [Readable name](guide-old/) | Old | Tags |\n| **Goal** | [Start](guide-old/) | Next |\n')
        Path('AGENTS.md').write_text('- `guide-old` - Old\n- `guide-current` - Current\n')

    def test_archive_records_routes_and_removes_catalog_entry(self):
        self.assertEqual(expiry.find_expired_projects(), ['guide-old'])
        expiry.archive_projects(['guide-old'])
        expiry.update_readme(['guide-old'])
        data = json.loads(Path('site/retired.json').read_text())['projects']['guide-old']
        self.assertIn('/guide-old/workbook.html', data['routes'])
        self.assertIn('/guide-old/README.html', data['routes'])
        self.assertNotIn('/guide-old/AGENTS.md', data['routes'])
        self.assertTrue(Path('_archive/guide-old/README.md').exists())
        self.assertNotIn('(guide-old/)', Path('README.md').read_text())
        self.assertIn('Projects-1', Path('README.md').read_text())
        self.assertNotIn('guide-old', Path('AGENTS.md').read_text())

    def test_existing_archive_is_not_overwritten(self):
        Path('_archive/guide-old').mkdir(parents=True)
        with self.assertRaises(RuntimeError):
            expiry.archive_projects(['guide-old'])
        self.assertTrue(Path('guide-old/README.md').exists())


if __name__ == '__main__':
    unittest.main()
