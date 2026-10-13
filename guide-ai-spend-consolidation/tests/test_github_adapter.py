"""Offline adapter regressions. Pair-programmed by SE Community + Cortex Code.

Run: python3 <this-file> (stdlib only; no Snowflake or provider connection).
Executes the actual Python handler extracted from sql/03, with HTTP, secrets,
and Snowpark I/O replaced by strict fakes. Publication executes the source view
in SQLite with only qualified table names and QUALIFY syntax adapted. These
checks do not certify Snowflake DDL, transaction durability, grants, EAI or upload
runtime support. test_reporting_sql.py separately exercises reporting SQL.
"""
from __future__ import annotations

import ast
from datetime import date, datetime, timedelta, timezone
import json
from pathlib import Path
import re
import sqlite3
import sys
from types import ModuleType, SimpleNamespace
import unittest
from unittest.mock import Mock, patch

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / 'sql/03_pull_github_copilot.sql').read_text()
HANDLER = SOURCE.split('$$', 2)[1]
NOW = datetime(2026, 10, 13, 7, tzinfo=timezone.utc)
DAY = date(2026, 10, 10)
HOST = 'reports.example.invalid'
URL = f'https://{HOST}/report.ndjson?signature=synthetic'


class ClockType(type):
    def __instancecheck__(cls, instance):
        return isinstance(instance, datetime)


class Clock(datetime, metaclass=ClockType):
    @classmethod
    def now(cls, tz=None):
        return NOW.astimezone(tz) if tz else NOW.replace(tzinfo=None)


class Response:
    def __init__(self, payload=None, records=None, status=200, body=None):
        self.payload = payload
        self.status_code = status
        self.body = body if body is not None else '\n'.join(json.dumps(row) for row in records or []).encode()
        self.closed = False

    def json(self):
        return self.payload

    def iter_content(self, chunk_size):
        for offset in range(0, len(self.body), chunk_size):
            yield self.body[offset:offset + chunk_size]

    def __enter__(self):
        return self

    def __exit__(self, *args):
        self.closed = True


class HTTP:
    def __init__(self, responses):
        self.responses = list(responses)
        self.calls = []
        self.trust_env = True
        self.headers = {}
        self.auth = None

    def get(self, url, **kwargs):
        self.calls.append((url, kwargs))
        if not self.responses:
            raise AssertionError('Unexpected HTTP request; no live fallback')
        response = self.responses.pop(0)
        if isinstance(response, Exception):
            raise response
        return response

    def __enter__(self):
        return self

    def __exit__(self, *args):
        pass


class Row(dict):
    def as_dict(self):
        return dict(self)


class Session:
    """Record effects of actual handler statements, without reimplementing it."""
    def __init__(self, active=None):
        self.active = [(True,)] if active is None else active
        self.statements = []
        self.uploads = {}
        self.upload_status = 'UPLOADED'
        self.copy_result = None
        self.fail_on = None
        self.logs = []
        self.manifests = []
        self.landed = []
        self.events = []
        self.file = SimpleNamespace(put_stream=self.put_stream)

    def put_stream(self, stream, path, **options):
        self.events.append('upload')
        if options != dict(auto_compress=False, overwrite=False):
            raise AssertionError('Unsafe upload options')
        if path in self.uploads:
            raise AssertionError('Attempt to overwrite evidence')
        self.uploads[path] = stream.read()
        return SimpleNamespace(status=self.upload_status)

    def sql(self, sql, params=None):
        def collect(*, statement_params):
            self.statements.append((sql, params, statement_params))
            text = ' '.join(sql.split())
            if self.fail_on and self.fail_on in text:
                raise RuntimeError('untrusted database error with synthetic-secret')
            if text.startswith('SELECT IS_ACTIVE'):
                return self.active
            if text.startswith('COPY INTO'):
                self.events.append('copy')
                if 'ON_ERROR = ABORT_STATEMENT' not in text:
                    raise AssertionError('COPY must abort on errors')
                path = re.search(r'FROM (@AI_SPEND.RAW.AI_USAGE_STAGE/[^\s]+)', text).group(1)
                rows = [json.loads(line) for line in self.uploads[path].splitlines()]
                for row in rows:
                    self.landed.append(dict(run_id=params[4], record=row))
                return self.copy_result if self.copy_result is not None else [Row(rows_loaded=len(rows), status='LOADED')]
            if text.startswith('INSERT INTO AI_SPEND.CONTROL.REPORT_SNAPSHOT'):
                self.events.append('manifest')
                self.manifests.append(list(params))
                return []
            if text.startswith('INSERT INTO AI_SPEND.CONTROL.PULL_RUN_LOG'):
                self.events.append('log:' + params[5])
                self.logs.append(list(params))
                return []
            raise AssertionError('Unexpected SQL: ' + text)
        return SimpleNamespace(collect=collect)


def usage(login='reader', day=DAY, **changes):
    return dict(dict(user_login=login, day=day.isoformat(), ai_credits_used=1.25,
                     code_acceptance_activity_count=2), **changes)


def seat(login='reader', **changes):
    return dict(dict(assignee={'login': login}, created_at='2026-10-01T12:00:00Z'), **changes)


def report_response(day=DAY, links=None):
    return Response(payload=dict(report_day=day.isoformat(), download_links=links if links is not None else [URL]))


def current_partitions(session):
    """Execute the actual success filter, join and window, not a Python facsimile."""
    source = (ROOT / 'sql/06_normalize.sql').read_text()
    query = re.search(r'V_CURRENT_REPORT_PARTITIONS AS\s*(.*?);', source, re.S).group(1)
    query = query.replace('AI_SPEND.CONTROL.REPORT_SNAPSHOT', 'snapshots').replace('AI_SPEND.CONTROL.PULL_RUN_LOG', 'runs')
    select, window = query.split('QUALIFY ', 1)
    # SQLite supports the same ROW_NUMBER window but needs an outer WHERE.
    window = re.sub(r'\)\s*=\s*1\s*$', ') AS partition_rank', window.strip())
    select = select.replace('FROM snapshots', ', ' + window + '\nFROM snapshots', 1)
    query = 'SELECT PLATFORM_KEY, REPORT_NAME, PARTITION_DATE, RUN_ID, RECORD_COUNT FROM (' + select + ') WHERE partition_rank = 1'
    with sqlite3.connect(':memory:') as database:
        database.execute('CREATE TABLE snapshots(RUN_ID, PLATFORM_KEY, REPORT_NAME, PARTITION_DATE, RECORD_COUNT)')
        database.execute('CREATE TABLE runs(RUN_ID, PLATFORM_KEY, REPORT_NAME, COMPLETED_AT, STATUS)')
        database.executemany('INSERT INTO snapshots VALUES (?, ?, ?, ?, ?)',
                             [(run, platform, report, day.isoformat(), count) for run, platform, report, day, count in session.manifests])
        database.executemany('INSERT INTO runs VALUES (?, ?, ?, ?, ?)',
                             [(row[0], row[1], row[2], row[4].isoformat(), row[5]) for row in session.logs])
        return database.execute(query).fetchall()


class AdapterTests(unittest.TestCase):
    def setUp(self):
        self.http = HTTP([])
        self.secret = Mock(return_value='synthetic-token')
        requests = ModuleType('requests')
        requests.Session = lambda: self.http
        snowflake = ModuleType('_snowflake')
        snowflake.get_generic_secret_string = self.secret
        snowpark = ModuleType('snowflake.snowpark')
        snowpark.Session = Session
        self.module = {'__name__': 'extracted_github_adapter'}
        with patch.dict(sys.modules, {'requests': requests, '_snowflake': snowflake,
                                     'snowflake': ModuleType('snowflake'), 'snowflake.snowpark': snowpark}):
            exec(compile(HANDLER, str(ROOT / 'sql/03_pull_github_copilot.sql'), 'exec'), self.module)
        self.module.update(ORG='synthetic-org', DOWNLOAD_HOSTS=frozenset({HOST}),
                           datetime=Clock, FIRST_RUN_DAYS=3)
        self.session = Session()

    def call(self, name, *args):
        return self.module[name](*args)

    def run_pull(self, report='USER_USAGE', since=None, responses=()):
        self.http.responses = list(responses)
        return self.call('pull', self.session, report, since)

    def failure(self, report='USER_USAGE', since=None, responses=(), message=None):
        with self.assertRaisesRegex(RuntimeError, 'inspect PULL_RUN_LOG'):
            self.run_pull(report, since, responses)
        self.assertEqual(self.session.logs[-1][5], 'FAILED')
        self.assertNotIn('SUCCEEDED', [row[5] for row in self.session.logs])
        if message:
            self.assertIn(message, self.session.logs[-1][12])

    def one_day(self):
        self.module.update(FIRST_RUN_DAYS=1, RESTATEMENT_OVERLAP_DAYS=1)

    def test_all_download_links_preserve_records_and_request_contract(self):
        self.one_day()
        second = URL.replace('report.ndjson', 'second.ndjson')
        records = [usage(extra={'untouched': [None, 'metadata']}), usage('second')]
        result = self.run_pull(responses=[report_response(links=[URL, second]),
                                         Response(records=records[:1]), Response(records=records[1:])])
        self.assertEqual(result['rows_loaded'], 2)
        self.assertEqual([row['record'] for row in self.session.landed], records)
        self.assertEqual([url for url, _ in self.http.calls[1:]], [URL, second])
        api_url, options = self.http.calls[0]
        self.assertEqual(api_url, 'https://api.github.com/orgs/synthetic-org/copilot/metrics/reports/users-1-day')
        self.assertEqual(options['params'], {'day': DAY.isoformat()})
        self.assertEqual(options['headers']['X-GitHub-Api-Version'], '2026-03-10')
        self.assertEqual(options['headers']['Authorization'], 'Bearer synthetic-token')
        self.assertFalse(self.http.trust_env)
        self.assertIsNone(self.http.auth)
        self.assertNotIn('Authorization', self.http.headers)
        for _, options in self.http.calls[1:]:
            self.assertNotIn('headers', options)
            self.assertNotIn('auth', options)
            self.assertFalse(options['allow_redirects'])
        self.assertEqual(self.session.events, ['upload', 'copy', 'manifest', 'log:SUCCEEDED'])
        self.assertEqual(self.session.manifests[0][4], 2)
        for sql, _, params in self.session.statements:
            self.assertNotIn('ALTER SESSION', sql)
            self.assertTrue(params['QUERY_TAG'].startswith('AI_SPEND:GITHUB_COPILOT:'))

    def test_every_usage_record_and_every_file_is_validated(self):
        bad_rows = [None, [], {}, usage(user_login=' '), usage(user_login=' reader'),
                    usage(day=date(2026, 10, 9)), usage(ai_credits_used=None),
                    usage(ai_credits_used=True), usage(ai_credits_used='1'),
                    usage(ai_credits_used=-1), usage(ai_credits_used=float('inf')),
                    usage(ai_credits_used=float('nan')), usage(ai_credits_used=10**32),
                    usage(ai_credits_used=0.0000001), usage(code_acceptance_activity_count=1.5),
                    usage(code_acceptance_activity_count=True), usage(code_acceptance_activity_count=10**38)]
        for bad in bad_rows:
            with self.subTest(record=bad):
                self.setUp()
                self.one_day()
                self.failure(responses=[report_response(links=[URL, URL+'2']), Response(records=[usage()]),
                                        Response(records=[bad])], message='SCHEMA_DRIFT')
                self.assertFalse(self.session.uploads)
                self.assertFalse(self.session.manifests)

    def test_every_seat_record_and_assignment_timestamp_validated(self):
        for bad in [None, {}, seat(assignee=None), seat(assignee={'login': ''}),
                    seat(assignee={'login': ' reader'}), seat(created_at=None),
                    seat(created_at='not-a-time'), seat(created_at='2026-10-01T12:00:00')]:
            with self.subTest(record=bad):
                self.setUp()
                self.failure('SEATS', responses=[Response(payload={'total_seats': 2, 'seats': [seat(), bad]})], message='SCHEMA_DRIFT')
                self.assertFalse(self.session.uploads)

    def test_malformed_seat_envelopes_never_mean_empty(self):
        for payload in [None, [], {}, {'total_seats': 0}, {'seats': []},
                        {'total_seats': 0, 'seats': {}}, {'total_seats': True, 'seats': []},
                        {'total_seats': -1, 'seats': []}, {'total_seats': '0', 'seats': []}]:
            with self.subTest(payload=payload):
                self.setUp()
                self.failure('SEATS', responses=[Response(payload=payload)], message='SCHEMA_DRIFT')
                self.assertFalse(self.session.manifests)

    def test_seat_pagination_all_pages_and_counts(self):
        self.module['PAGE_SIZE'] = 2
        self.run_pull('SEATS', responses=[Response(payload={'total_seats': 3, 'seats': [seat('a'), seat('b')]}),
                                         Response(payload={'total_seats': 3, 'seats': [seat('c')]})])
        self.assertEqual([options['params'] for _, options in self.http.calls],
                         [{'per_page': 2, 'page': 1}, {'per_page': 2, 'page': 2}])
        self.assertEqual(self.session.logs[0][7:9], [3, 3])

    def test_changed_totals_short_overfull_and_duplicate_seats_fail(self):
        for total, batch in [(4, [seat('c')]), (3, []), (3, [seat('c'), seat('d')]), (3, [seat('A')])]:
            with self.subTest(total=total, batch=batch):
                self.setUp()
                self.module['PAGE_SIZE'] = 2
                self.failure('SEATS', responses=[Response(payload={'total_seats': 3, 'seats': [seat('a'), seat('b')]}),
                                                Response(payload={'total_seats': total, 'seats': batch})], message='INCOMPLETE_SNAPSHOT')
                self.assertFalse(self.session.manifests)

    def test_page_limit_is_failure_not_truncated_success(self):
        self.module.update(MAX_PAGES=2, PAGE_SIZE=1)
        self.failure('SEATS', responses=[Response(payload={'total_seats': 3, 'seats': [seat('a')]}),
                                        Response(payload={'total_seats': 3, 'seats': [seat('b')]})], message='PAGINATION_LIMIT')
        self.assertEqual(len(self.http.calls), 2)
        self.assertFalse(self.session.uploads)

    def test_duplicate_users_and_links_fail(self):
        for links, responses in [([URL, URL], []), ([URL, URL+'2'], [Response(records=[usage('reader')]), Response(records=[usage('READER')])])]:
            with self.subTest(links=links):
                self.setUp()
                self.one_day()
                self.failure(responses=[report_response(links=links)] + responses, message='SCHEMA_DRIFT')
                self.assertFalse(self.session.manifests)

    def test_usage_envelope_day_and_missing_links_fail(self):
        for payload in [None, {}, {'day': DAY.isoformat(), 'download_links': [URL]},
                        {'report_day': '2026-10-09', 'download_links': [URL]},
                        {'report_day': DAY.isoformat(), 'download_links': []},
                        {'report_day': DAY.isoformat(), 'download_links': [None]},
                        {'report_day': DAY.isoformat(), 'download_links': URL}]:
            with self.subTest(payload=payload):
                self.setUp()
                self.one_day()
                self.failure(responses=[Response(payload=payload)])
                self.assertFalse(self.session.manifests)

    def test_valid_empty_usage_and_seats_create_zero_manifest(self):
        for report, responses in [('USER_USAGE', [report_response(), Response(body=b'\n  \n')]),
                                  ('SEATS', [Response(payload={'total_seats': 0, 'seats': []})])]:
            with self.subTest(report=report):
                self.setUp()
                self.one_day()
                self.assertEqual(self.run_pull(report, responses=responses)['rows_loaded'], 0)
                self.assertEqual(self.session.manifests[0][4], 0)
                self.assertFalse(self.session.uploads)
                self.assertEqual(self.session.logs[0][7:9], [0, 0])
                self.assertEqual(len(current_partitions(self.session)), 1)

    def test_partial_failed_run_hidden_by_actual_successful_partition_sql(self):
        self.module.update(FIRST_RUN_DAYS=2, RESTATEMENT_OVERLAP_DAYS=1)
        first = DAY - timedelta(days=1)
        self.run_pull(responses=[report_response(first), Response(records=[usage(day=first)]),
                                 report_response(), Response(records=[usage()])])
        previous = current_partitions(self.session)
        with self.assertRaises(RuntimeError):
            self.run_pull(responses=[report_response(first), Response(records=[usage(day=first, ai_credits_used=99)]),
                                     Response(status=503)])
        self.assertEqual(len(self.session.manifests), 3)
        self.assertEqual(len(self.session.landed), 3)
        self.assertEqual(self.session.logs[-1][5], 'FAILED')
        self.assertEqual(current_partitions(self.session), previous)
        with patch.object(Clock, 'now', return_value=NOW + timedelta(seconds=2)):
            self.run_pull(responses=[report_response(first), Response(records=[]), report_response(), Response(records=[])])
        self.assertEqual([row[4] for row in current_partitions(self.session)], [0, 0])
        self.assertEqual([row[5] for row in self.session.logs], ['SUCCEEDED', 'FAILED', 'SUCCEEDED'])

    def test_inactive_missing_ambiguous_registry_fail_before_credentials(self):
        for active in [[], [(False,)], [(None,)], [(True,), (True,)]]:
            with self.subTest(active=active):
                self.setUp()
                self.session.active = active
                self.failure(message='CONFIG')
                self.secret.assert_not_called()
                self.assertFalse(self.http.calls)

    def test_invalid_configuration_logs_failure_without_credentials(self):
        for config in [dict(ORG='your-organization'), dict(ORG='org/path'), dict(DOWNLOAD_HOSTS=frozenset()),
                       dict(MAX_PAGES=0), dict(PAGE_SIZE=101), dict(FIRST_RUN_DAYS=0),
                       dict(RESTATEMENT_OVERLAP_DAYS=0), dict(PUBLICATION_LAG_DAYS=-1)]:
            with self.subTest(config=config):
                self.setUp()
                self.module.update(config)
                self.failure(message='CONFIG')
                self.secret.assert_not_called()
                self.assertFalse(self.http.calls)

    def test_unsupported_report_not_logged_verbatim(self):
        self.failure(report='synthetic-secret', message='CONFIG')
        self.assertEqual(self.session.logs[0][2], 'INVALID_REPORT')
        self.assertNotIn('synthetic-secret', repr(self.session.logs))

    def test_put_status_requires_uploaded_before_copy_or_manifest(self):
        for status in ['SKIPPED', 'ERROR', None]:
            with self.subTest(status=status):
                self.setUp()
                self.one_day()
                self.session.upload_status = status
                self.failure(responses=[report_response(), Response(records=[usage()])], message='STAGE_UPLOAD_NOT_COMPLETED')
                self.assertNotIn('copy', self.session.events)
                self.assertFalse(self.session.manifests)

    def test_copy_counts_and_completion_status(self):
        for result in [[], [Row(rows_loaded=0, status='LOADED')], [Row(rows_loaded=2, status='LOADED')],
                       [Row(status='LOADED')], [Row(rows_loaded=1, status='PARTIALLY_LOADED')],
                       [Row(rows_loaded=True, status='LOADED')], [Row(rows_loaded=1.5, status='LOADED')]]:
            with self.subTest(result=result):
                self.setUp()
                self.one_day()
                self.session.copy_result = result
                self.failure(responses=[report_response(), Response(records=[usage()])], message='COPY_')
                self.assertFalse(self.session.manifests)
        self.setUp()
        self.one_day()
        self.session.copy_result = [Row(ROWS_LOADED=1, STATUS='LOADED')]
        self.assertEqual(self.run_pull(responses=[report_response(), Response(records=[usage()])])['rows_loaded'], 1)

    def test_copy_exception_and_manifest_exception_never_publish(self):
        for operation in ['COPY INTO', 'INSERT INTO AI_SPEND.CONTROL.REPORT_SNAPSHOT']:
            with self.subTest(operation=operation):
                self.setUp()
                self.one_day()
                self.session.fail_on = operation
                self.failure(responses=[report_response(), Response(records=[usage()])])
                self.assertFalse(current_partitions(self.session))
                self.assertNotIn('synthetic-secret', repr(self.session.logs))

    def test_unapproved_download_urls_rejected_before_network(self):
        urls = [f'http://{HOST}/report', 'https://unapproved.example.invalid/report',
                f'https://{HOST}.other.invalid/report', f'https://{HOST}:80/report',
                f'https://{HOST}:0/report', f'https://{HOST}:synthetic-secret/report',
                f'https://user:pass@{HOST}/report', f'https://{HOST}/report#fragment',  # pragma: allowlist secret
                f'\nhttps://{HOST}/report', f'https://{HOST}\t/report', '//'+HOST+'/report']
        for url in urls:
            with self.subTest(url=url):
                self.setUp()
                self.one_day()
                self.failure(responses=[report_response(links=[url])], message='UNAPPROVED_DOWNLOAD_URL')
                self.assertEqual(len(self.http.calls), 1)
                self.assertNotIn('synthetic-secret', repr(self.session.logs))

    def test_explicit_https_port_443_accepted(self):
        self.one_day()
        self.run_pull(responses=[report_response(links=[URL.replace(HOST, HOST+':443')]), Response(records=[])])
        self.assertEqual(self.session.logs[0][5], 'SUCCEEDED')

    def test_redirects_and_non_200_never_followed_or_empty(self):
        for status in [204, 301, 302, 307, 401, 403, 404, 429, 500]:
            for download in [False, True]:
                with self.subTest(status=status, download=download):
                    self.setUp()
                    self.one_day()
                    responses = [report_response(), Response(status=status)] if download else [Response(status=status)]
                    self.failure(responses=responses, message='HTTP_')
                    self.assertEqual(len(self.http.calls), 2 if download else 1)
                    self.assertTrue(all(options['allow_redirects'] is False for _, options in self.http.calls))
                    self.assertFalse(self.session.manifests)

    def test_bad_json_encoding_size_and_external_errors_redacted(self):
        for response in [Response(body=b'{bad json'), Response(body=b'\xff'),
                         ValueError('synthetic-secret'), RuntimeError('synthetic-secret')]:
            with self.subTest(response=response):
                self.setUp()
                self.one_day()
                self.failure(responses=[report_response(), response])
                self.assertNotIn('synthetic-secret', repr(self.session.logs))
        self.setUp()
        self.one_day()
        self.module['MAX_REPORT_BYTES'] = 2
        self.failure(responses=[report_response(), Response(body=b'123')], message='REPORT_TOO_LARGE')

    def test_first_run_and_restatement_watermarks_are_utc_exclusive_bounds(self):
        first = DAY - timedelta(days=2)
        responses = []
        for day in [first, first + timedelta(days=1), DAY]:
            responses.extend([report_response(day), Response(records=[])])
        self.run_pull(responses=responses)
        self.assertEqual(self.session.logs[0][9:11], [datetime(2026, 10, 8, tzinfo=timezone.utc),
                                                    datetime(2026, 10, 11, tzinfo=timezone.utc)])
        # Equivalent instant in a non-UTC offset must not shift the report day.
        since = datetime(2026, 10, 10, 20, tzinfo=timezone(timedelta(hours=-4)))
        self.http.calls.clear()
        self.run_pull(since=since, responses=responses)
        days = [options['params']['day'] for url, options in self.http.calls if url.startswith('https://api.github.com')]
        self.assertEqual(days, ['2026-10-08', '2026-10-09', '2026-10-10'])
        self.assertEqual(self.session.logs[-1][9:11], self.session.logs[0][9:11])

    def test_history_gaps_and_future_watermarks_fail_without_advancing(self):
        for since in [datetime(2026, 9, 1, tzinfo=timezone.utc), datetime(2026, 10, 12, tzinfo=timezone.utc),
                      datetime(2026, 10, 11, 1, tzinfo=timezone.utc), datetime(2026, 10, 10)]:
            with self.subTest(since=since):
                self.setUp()
                self.failure(since=since)
                self.assertFalse(self.http.calls)
                self.assertFalse(self.session.manifests)

    def test_seat_snapshot_uses_capture_day_not_usage_lag(self):
        self.run_pull('SEATS', responses=[Response(payload={'total_seats': 1, 'seats': [seat()]})])
        self.assertEqual(self.session.manifests[0][3], NOW.date())
        self.assertEqual(self.session.logs[0][9:11], [NOW, NOW])

    def test_unavailable_failure_log_still_raises_sanitized_error(self):
        self.session.fail_on = 'INSERT INTO AI_SPEND.CONTROL.PULL_RUN_LOG'
        with self.assertRaisesRegex(RuntimeError, 'failure log unavailable') as caught:
            self.run_pull('SEATS', responses=[Response(status=403)])
        self.assertNotIn('synthetic-secret', str(caught.exception))
        self.assertFalse(current_partitions(self.session))

    def test_success_log_failure_cannot_publish_staged_records(self):
        self.one_day()
        self.session.fail_on = 'INSERT INTO AI_SPEND.CONTROL.PULL_RUN_LOG'
        with self.assertRaisesRegex(RuntimeError, 'failure log unavailable'):
            self.run_pull(responses=[report_response(), Response(records=[usage()])])
        self.assertEqual(len(self.session.manifests), 1)
        self.assertFalse(current_partitions(self.session))

    def test_orchestrator_upload_ancestors_use_caller_rights_and_raise(self):
        definitions = re.findall(r'CREATE OR REPLACE PROCEDURE\s+(\S+)\(.*?EXECUTE AS (\w+)', SOURCE, re.S)
        rights = dict(definitions)
        self.assertEqual(rights['AI_SPEND.CONTROL.PULL_GITHUB_ALL'], 'CALLER')
        self.assertEqual(rights['AI_SPEND.CONTROL.PULL_GITHUB_COPILOT'], 'CALLER')
        orchestrator = SOURCE.split('CREATE OR REPLACE PROCEDURE AI_SPEND.CONTROL.PULL_GITHUB_ALL()', 1)[1]
        self.assertIn("STATUS = 'SUCCEEDED'", orchestrator)
        self.assertIn('IF (FAILED > 0) THEN RAISE PULL_FAILURE', orchestrator)
        self.assertNotIn('SKIPPED_INACTIVE', orchestrator)
        self.assertIn('ALTER TASK AI_SPEND.CONTROL.TASK_PULL_GITHUB_COPILOT SUSPEND', orchestrator)
        self.assertNotIn(' RESUME;', orchestrator)
        ast.parse(HANDLER)

    def test_seat_projection_only_updates_roster_estimates_not_finance(self):
        projection = SOURCE.split('CREATE OR REPLACE PROCEDURE AI_SPEND.CONTROL.PROJECT_GITHUB_SEATS(', 1)[1].split('$$;', 1)[0]
        condition = re.search(r'WHEN MATCHED AND (.*?) THEN UPDATE SET', projection, re.S).group(1)
        with sqlite3.connect(':memory:') as database:
            for source_name, expected in [('FINANCE', False), ('GITHUB_ROSTER_ESTIMATE', True), (None, False)]:
                allowed = database.execute('SELECT '+condition+' FROM (SELECT ? AS SOURCE_NAME) target', [source_name]).fetchone()[0]
                self.assertEqual(bool(allowed), expected)
        self.assertIn('r.PLATFORM_KEY = s.PLATFORM_KEY', projection)
        self.assertIn('r.REPORT_NAME = s.REPORT_NAME', projection)

    def test_registry_update_expressions_preserve_custom_values_on_rerun(self):
        text = (ROOT / 'sql/01_landing.sql').read_text()
        update = text.split('WHEN MATCHED THEN UPDATE SET', 1)[1].split('WHEN NOT MATCHED', 1)[0]
        assignments = re.findall(r'^\s*tgt\.(\w+)\s*=\s*(.*?)(?=,\s*\n\s*tgt\.|\Z)', update, re.S | re.M)
        self.assertEqual(len(assignments), 5)
        source = dict(PLATFORM_KEY='GITHUB_COPILOT', NOTES='corrected source note',
                      LEGACY_NOTES='recognized shipped note', SUPPORTS_ACTIVITY_DEPTH=True,
                      SUPPORTS_USER_COST=False, SUPPORTS_USER_GRAIN=True, NATIVE_UNIT='PROMPTS')
        with sqlite3.connect(':memory:') as database:
            database.create_function('IFF', 3, lambda condition, yes, no: yes if condition else no)
            def apply(target):
                target_sql = ', '.join(':'+key+' AS '+key for key in target)
                source_sql = ', '.join(':src_'+key+' AS '+key for key in source)
                projection = ', '.join(expression+' AS '+key for key, expression in assignments)
                params = dict(target, **{'src_'+key: value for key, value in source.items()})
                row = database.execute('SELECT '+projection+' FROM (SELECT '+target_sql+
                                       ') tgt CROSS JOIN (SELECT '+source_sql+') src', params).fetchone()
                return dict(target, **dict(zip([key for key, _ in assignments], row)))
            custom = dict(PLATFORM_KEY='GITHUB_COPILOT', NOTES='operator-qualified billing source',
                          SUPPORTS_ACTIVITY_DEPTH=False, SUPPORTS_USER_COST=True,
                          SUPPORTS_USER_GRAIN=False, NATIVE_UNIT='CUSTOM_UNITS')
            self.assertEqual(apply(custom), custom)
            legacy = dict(custom, NOTES=source['LEGACY_NOTES'], SUPPORTS_ACTIVITY_DEPTH=None)
            upgraded = apply(legacy)
            self.assertEqual(upgraded['NOTES'], source['NOTES'])
            self.assertFalse(upgraded['SUPPORTS_USER_COST'])
            self.assertTrue(upgraded['SUPPORTS_ACTIVITY_DEPTH'])
            self.assertEqual(apply(upgraded), upgraded)
            legacy.update(PLATFORM_KEY='M365_COPILOT', NATIVE_UNIT='ACTIVE_DAYS')
            upgraded = apply(legacy)
            self.assertEqual(upgraded['NATIVE_UNIT'], 'PROMPTS')
            self.assertTrue(upgraded['SUPPORTS_USER_GRAIN'])
            self.assertEqual(apply(upgraded), upgraded)

    def test_exact_page_cap_completion_and_oversized_page(self):
        self.module.update(MAX_PAGES=1, PAGE_SIZE=1)
        self.run_pull('SEATS', responses=[Response(payload={'total_seats': 1, 'seats': [seat()]})])
        self.assertEqual(self.session.logs[0][5], 'SUCCEEDED')
        self.setUp()
        self.module['PAGE_SIZE'] = 1
        self.failure('SEATS', responses=[Response(payload={'total_seats': 2, 'seats': [seat('a'), seat('b')]})],
                     message='page exceeds')

    def test_rerun_preserves_operator_settings_and_corrects_known_notes(self):
        text = (ROOT / 'sql/01_landing.sql').read_text()
        update = text.split('WHEN MATCHED THEN UPDATE SET', 1)[1].split('WHEN NOT MATCHED', 1)[0]
        self.assertNotRegex(update, r'tgt\.(?:IS_ACTIVE|CREDENTIAL_OBJECT_FQN|EXPECTED_LAG_HOURS|BILLING_CONTEXT)\s*=')
        self.assertIn('COALESCE(tgt.SUPPORTS_ACTIVITY_DEPTH, src.SUPPORTS_ACTIVITY_DEPTH)', update)
        self.assertIn('tgt.NOTES = src.LEGACY_NOTES', update)
        self.assertNotIn('UPDATE AI_SPEND.CONTROL.PLATFORM_REGISTRY\nSET SUPPORTS_ACTIVITY_DEPTH', text)
        network = (ROOT / 'sql/02_network_secrets.sql').read_text()
        self.assertNotIn('CREATE OR REPLACE NETWORK RULE', network)
        self.assertIn('CREATE EXTERNAL ACCESS INTEGRATION IF NOT EXISTS', network)
        for path in ['01_landing.sql', '02_network_secrets.sql', '03_pull_github_copilot.sql']:
            self.assertIn('Expires: 2026-11-09', (ROOT / 'sql' / path).read_text())


if __name__ == '__main__':
    unittest.main(verbosity=2)
