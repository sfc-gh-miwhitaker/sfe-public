"""Pair-programmed by SE Community + Cortex Code."""
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from datetime import date
from unittest.mock import patch

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

    def policy_fixture(self, reviewed='2026-09-01', deadline='2026-10-31', basis='verified'):
        Path('guide-current/README.md').unlink()
        label = 'Last verified' if basis == 'verified' else 'Review baseline'
        Path('guide-old/README.md').write_text(
            f'![Expires](https://img.shields.io/badge/Expires-{deadline.replace("-", "--")}-orange)\n'
            f'**{label}:** {reviewed} | **Expires:** {deadline} | **Status:** ACTIVE\n')

    def test_dated_archive_preserves_previous_revision(self):
        Path('_archive/guide-old').mkdir(parents=True)
        Path('_archive/guide-old/README.md').write_text('previous archive')
        with patch.object(expiry, 'utc_today', return_value=date(2026, 10, 6)):
            expiry.archive_projects(['guide-old'], preserve_previous=True)
        self.assertEqual(Path('_archive/guide-old/README.md').read_text(), 'previous archive')
        self.assertTrue(Path('_archive/guide-old-2026-10-06/README.md').is_file())

    def test_archive_does_not_change_local_only_ignore_rules(self):
        Path('.gitignore').write_text('_archive/\n')
        expiry.archive_projects(['guide-old'])
        self.assertEqual(Path('.gitignore').read_text(), '_archive/\n')

    def test_sixty_days_and_on_date_retirement(self):
        self.policy_fixture()
        expiry.validate_policy(date(2026, 10, 6))
        self.assertEqual(expiry.find_expired_projects(date(2026, 10, 30)), [])
        self.assertEqual(expiry.find_expired_projects(date(2026, 10, 31)), ['guide-old'])

    def test_shorter_deadline_is_valid(self):
        self.policy_fixture(deadline='2026-09-15')
        expiry.validate_policy(date(2026, 10, 6))

    def test_overlong_deadline_is_rejected(self):
        self.policy_fixture(deadline='2026-11-01')
        with self.assertRaisesRegex(ValueError, '60 days'):
            expiry.validate_policy(date(2026, 10, 6))

    def test_future_review_is_rejected(self):
        self.policy_fixture(reviewed='2026-10-07')
        with self.assertRaisesRegex(ValueError, 'future'):
            expiry.validate_policy(date(2026, 10, 6))

    def test_missing_review_record_is_rejected(self):
        self.policy_fixture()
        readme = Path('guide-old/README.md')
        readme.write_text(readme.read_text().replace('**Last verified:** 2026-09-01 | ', ''))
        with self.assertRaisesRegex(ValueError, 'guide-old'):
            expiry.validate_policy(date(2026, 10, 6))

    def test_badge_mismatch_is_rejected(self):
        self.policy_fixture()
        readme = Path('guide-old/README.md')
        readme.write_text(readme.read_text().replace('2026--10--31', '2027--10--31'))
        with self.assertRaisesRegex(ValueError, 'badge'):
            expiry.validate_policy(date(2026, 10, 6))

    def test_legacy_baseline_does_not_claim_verification(self):
        self.policy_fixture(basis='legacy-baseline')
        expiry.validate_policy(date(2026, 10, 6))
        readme = Path('guide-old/README.md')
        self.assertNotIn('Last verified', readme.read_text())
        readme.write_text(readme.read_text() + '\n**Last verified:** 2026-09-01\n')
        with self.assertRaisesRegex(ValueError, 'exactly one'):
            expiry.validate_policy(date(2026, 10, 6))

    def test_sync_only_shortens_and_is_idempotent(self):
        self.policy_fixture(deadline='2026-12-31')
        expiry.sync_headers()
        self.assertIn('**Expires:** 2026-10-31', Path('guide-old/README.md').read_text())
        before = Path('guide-old/README.md').read_text()
        expiry.sync_headers()
        self.assertEqual(before, Path('guide-old/README.md').read_text())
        readme = Path('guide-old/README.md')
        readme.write_text(before.replace('2026-10-31', '2026-09-15').replace('2026--10--31', '2026--09--15'))
        expiry.sync_headers()
        self.assertIn('**Expires:** 2026-09-15', readme.read_text())

    def test_dry_run_never_writes(self):
        self.policy_fixture(deadline='2026-09-15')
        before = {str(file): file.read_bytes() for file in Path('.').rglob('*') if file.is_file()}
        with patch('sys.argv', ['expire-projects.py', '--dry-run']), patch.object(expiry, 'utc_today', return_value=date(2026, 10, 6)):
            expiry.main()
        self.assertEqual(before, {str(file): file.read_bytes() for file in Path('.').rglob('*') if file.is_file()})

    def test_invalid_sync_is_non_mutating(self):
        self.policy_fixture(reviewed='2999-01-01', deadline='2999-12-31')
        before = Path('guide-old/README.md').read_bytes()
        with self.assertRaisesRegex(ValueError, 'future'):
            expiry.sync_headers()
        self.assertEqual(before, Path('guide-old/README.md').read_bytes())

    def test_invalid_metadata_blocks_archive(self):
        self.policy_fixture(deadline='2026-12-31')
        with patch('sys.argv', ['expire-projects.py']), patch.object(expiry, 'utc_today', return_value=date(2026, 10, 6)):
            with self.assertRaises(ValueError):
                expiry.main()
        self.assertTrue(Path('guide-old/README.md').exists())

    def test_archive_removes_continuation_lines_and_publication_settings(self):
        Path('AGENTS.md').write_text('- `guide-old` - retired\n  continuation\n  another line\n\n- `guide-current` - retain\n  retained continuation\n')
        Path('site/publication.json').write_text(json.dumps({'pilot': ['guide-old', 'guide-current'],
            'extraFiles': ['guide-old/workbook.html', 'guide-current/extra.md']}))
        expiry.archive_projects(['guide-old'])
        expiry.update_readme(['guide-old'])
        self.assertNotIn('another line', Path('AGENTS.md').read_text())
        self.assertIn('retained continuation', Path('AGENTS.md').read_text())
        settings = json.loads(Path('site/publication.json').read_text())
        self.assertEqual(settings['pilot'], ['guide-current'])
        self.assertEqual(settings['extraFiles'], ['guide-current/extra.md'])
        self.assertIn('**Archived:**', Path('_archive/guide-old/README.md').read_text())

    def test_only_project_directories_are_eligible(self):
        Path('docs').mkdir()
        Path('docs/README.md').write_text('**Expires:** 2000-01-01')
        self.assertEqual(expiry.find_expired_projects(), ['guide-old'])


class RepositoryPolicyTests(unittest.TestCase):
    def test_current_metadata_meets_policy(self):
        previous = Path.cwd()
        os.chdir(script.parents[2])
        try:
            expiry.validate_policy()
        finally:
            os.chdir(previous)

    def test_catalog_and_intent_members_exist(self):
        root = script.parents[2]
        readme = (root / 'README.md').read_text()
        import re
        for project in re.findall(r'\]\(((?:guide|demo)-[^/)]+)/\)', readme):
            self.assertTrue((root / project / 'README.md').is_file(), project)
        for project in re.findall(r'^(?:- |\d+\. )`((?:guide|demo)-[^`]+)`', (root / 'AGENTS.md').read_text(), re.M):
            self.assertTrue((root / project / 'README.md').is_file(), project)

    def test_archive_boundary_and_no_internal_review_artifacts(self):
        root = script.parents[2]
        self.assertIn('_archive/', (root / '.gitignore').read_text().splitlines())
        self.assertNotIn('!/_archive/', (root / '.gitignore').read_text())
        self.assertFalse((root / '.github/project-reviews.json').exists())
        self.assertFalse((root / 'docs/expiration-migration-2026-10-06.md').exists())


if __name__ == '__main__':
    unittest.main()
