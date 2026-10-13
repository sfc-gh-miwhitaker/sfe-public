"""Executable source-SQL regressions; Pair-programmed by SE Community + Cortex Code.

Run with: uv run --no-project --with sqlglot==30.22.0 --with duckdb==1.5.6 --with pytz python <this-file>
Default: in-memory DuckDB, after SQLGlot Snowflake-to-DuckDB translation.
Opt in to Snowflake SELECT/EXPLAIN only using AI_SPEND_TEST_CONNECTION and
AI_SPEND_TEST_ACCOUNT (expected CURRENT_ACCOUNT()). No default connection, DDL,
vendor calls, or persistent objects. Each CLI invocation uses the explicit connection.
The first remote statement is an identity probe. The source query bodies are parsed
from the checked-in SQL, not reimplemented; only base inputs, table references and
clock functions are substituted. SELECT tests do not validate DT refresh eligibility,
DDL upgrades, grants, stored-procedure transactions or Analyst/agent behavior.
"""
from __future__ import annotations

import datetime as dt
from decimal import Decimal
import json
import os
from pathlib import Path
import re
import subprocess
import unittest

import duckdb
import sqlglot
from sqlglot import exp
from sqlglot.tokens import TokenType

ROOT = Path(__file__).resolve().parents[1]
NOW = dt.date(2026, 10, 13)
SQL_FILES = [ROOT / 'sql' / name for name in (
    '05_snowflake_native.sql', '06_normalize.sql', '07_gold_dts.sql',
    '09_monitoring.sql')]


def through_semicolon(text):
    tokens = sqlglot.tokenize(text, read='snowflake')
    end = next((token.start for token in tokens if token.token_type == TokenType.SEMICOLON), len(text))
    return text[:end]


def query_definitions():
    definitions = {}
    pattern = r'CREATE OR (?:REPLACE VIEW|ALTER DYNAMIC TABLE)\s+(AI_SPEND\.\w+\.\w+)'
    for path in SQL_FILES:
        text = path.read_text()
        for match in re.finditer(pattern, text):
            statement = through_semicolon(text[match.end():])
            body = re.search(r'\bAS\s*\n', statement)
            if not body:
                raise AssertionError(f'Missing query body: {match.group(1)}')
            definitions[match.group(1)] = sqlglot.parse_one(statement[body.end():], read='snowflake')
    return definitions


QUERIES = query_definitions()


def source_schemas():
    text = (ROOT / 'sql/01_landing.sql').read_text()
    schemas = {}
    for match in re.finditer(r'CREATE TABLE IF NOT EXISTS\s+(AI_SPEND\.\w+\.\w+)', text):
        statement = sqlglot.parse_one(through_semicolon(text[match.start():]), read='snowflake')
        schemas[match.group(1)] = {column.name: column.args['kind'].sql(dialect='snowflake')
                                 for column in statement.this.expressions if isinstance(column, exp.ColumnDef)}
    for match in re.finditer(r'ALTER TABLE (AI_SPEND\.\w+\.\w+) ADD COLUMN IF NOT EXISTS (\w+) (\w+(?:\([^)]*\))?)', text):
        schemas[match.group(1)][match.group(2)] = match.group(3)
    schemas['SNOWFLAKE.ACCOUNT_USAGE.USERS'] = dict(USER_ID='NUMBER', NAME='VARCHAR', TYPE='VARCHAR')
    common = dict(USER_ID='NUMBER', USER_NAME='VARCHAR', USER_TAGS='ARRAY', REQUEST_ID='VARCHAR',
                  TOKEN_CREDITS='NUMBER(38,9)', TOKENS='NUMBER', METADATA='OBJECT')
    schemas['SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AI_FUNCTIONS_USAGE_HISTORY'] = dict(
        USER_ID='VARCHAR', START_TIME='TIMESTAMP_LTZ', CREDITS='NUMBER(38,9)',
        FUNCTION_NAME='VARCHAR', MODEL_NAME='VARCHAR', ROLE_NAMES='ARRAY', QUERY_ID='VARCHAR')
    schemas['SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AGENT_USAGE_HISTORY'] = dict(common, START_TIME='TIMESTAMP_LTZ', AGENT_NAME='VARCHAR')
    schemas['SNOWFLAKE.ACCOUNT_USAGE.SNOWFLAKE_COWORK_USAGE_HISTORY'] = dict(common, START_TIME='TIMESTAMP_LTZ', SNOWFLAKE_COWORK_NAME='VARCHAR')
    schemas['SNOWFLAKE.ACCOUNT_USAGE.SNOWFLAKE_COCO_USAGE_HISTORY'] = dict(common, USAGE_TIME='TIMESTAMP_TZ', INTERFACE='VARCHAR')
    return schemas


SCHEMAS = source_schemas()


def literal(value, kind):
    if value is None:
        return f'NULL::{kind}'
    if kind in ('VARIANT', 'OBJECT', 'ARRAY'):
        encoded = json.dumps(value).replace("'", "''")
        return f"PARSE_JSON('{encoded}')::{kind}"
    if isinstance(value, bool):
        return f'{str(value).upper()}::{kind}'
    return "'" + str(value).replace("'", "''") + f"'::{kind}"


def fixture_query(schema, rows):
    projections = [', '.join(f'{literal(row.get(column), kind)} AS {column}' for column, kind in schema.items())
                   for row in rows or [{}]]
    text = ' UNION ALL '.join('SELECT ' + projection for projection in projections)
    if not rows:
        text += ' WHERE FALSE'
    return sqlglot.parse_one(text, read='snowflake')


def build_query(target, fixtures):
    """Inline the source dependency graph as CTEs; never resolve live source data."""
    ctes, names = [], {}

    def resolve(name):
        if name in names:
            return names[name]
        override = fixtures.get(name)
        if isinstance(override, exp.Query):
            query = override.copy()
        else:
            query = QUERIES[name].copy() if name in QUERIES else fixture_query(SCHEMAS[name], override or [])
        for table in list(query.find_all(exp.Table)):
            if not table.catalog:
                continue
            dependency = '.'.join(part.name for part in table.parts).upper()
            alias = table.args.get('alias')
            replacement = exp.to_table(resolve(dependency))
            replacement.set('alias', alias.copy() if alias else exp.TableAlias(this=exp.to_identifier(table.name)))
            table.replace(replacement)
        for node in list(query.walk()):
            if isinstance(node, exp.CurrentDate):
                node.replace(sqlglot.parse_one("'2026-10-13'::DATE", read='snowflake'))
            elif isinstance(node, exp.CurrentTimestamp):
                node.replace(sqlglot.parse_one("'2026-10-13 12:00:00+00:00'::TIMESTAMP_TZ", read='snowflake'))
        alias = 'fixture_' + str(len(names))
        names[name] = alias
        ctes.append(exp.CTE(this=query, alias=exp.TableAlias(this=exp.to_identifier(alias))))
        return alias

    root = resolve(target)
    query = exp.select(*[exp.column(column) for column in QUERIES[target].named_selects]).from_(root)
    query.set('with_', exp.With(expressions=ctes))
    # Guard the execution boundary: all relations are local CTE names or VALUES.
    assert all(not table.catalog and not table.db for table in query.find_all(exp.Table))
    assert not any(isinstance(node, (exp.Create, exp.Insert, exp.Delete, exp.Update, exp.Command)) for node in query.walk())
    return query


class Runner:
    def __init__(self):
        self.connection = os.environ.get('AI_SPEND_TEST_CONNECTION')
        self.local = duckdb.connect()
        if self.connection:
            expected = os.environ.get('AI_SPEND_TEST_ACCOUNT')
            if not expected:
                raise RuntimeError('Set AI_SPEND_TEST_ACCOUNT to the approved account locator; no implicit target allowed')
            identity = self.remote('SELECT CURRENT_ACCOUNT() AS ACCOUNT, CURRENT_REGION() AS REGION, CURRENT_USER() AS USERNAME, CURRENT_ROLE() AS ACTIVE_ROLE')
            if identity[0]['ACCOUNT'] != expected:
                raise RuntimeError('Test account mismatch; stopped before regression SQL')
            print('Explicit test-connection identity verified; SELECT/EXPLAIN only', flush=True)

    def remote(self, sql):
        result = subprocess.run(['snow', 'sql', '--connection', self.connection, '--stdin',
                                 '--format', 'json', '--enable-templating', 'NONE'],
                                input=sql, text=True, capture_output=True, timeout=180)
        if result.returncode:
            raise AssertionError(result.stderr)
        rows = json.loads(result.stdout)
        # Snow CLI serializes DECIMAL as strings; preserve precision, never cast IDs.
        numeric_columns = {'NATIVE_QTY', 'CREDITS', 'COST_AMOUNT', 'METERED_COST',
                           'ALLOCATED_COST', 'MONTH_TOTAL_COST', 'COST_PER_PERSON',
                           'RECLAIMABLE_COST', 'MOM_GROWTH_PCT', 'ANNUAL_RUN_RATE_FLAT',
                           'ANNUAL_RUN_RATE_TRENDED'}
        for row in rows:
            for column in numeric_columns & row.keys():
                if row[column] is not None:
                    row[column] = Decimal(str(row[column]))
        return rows

    def run(self, target, fixtures, explain=False):
        query = build_query(target, fixtures)
        if self.connection:
            return self.remote(('EXPLAIN ' if explain else '') + query.sql(dialect='snowflake'))
        # Snowflake VARIANT-to-string removes JSON quotes; DuckDB JSON casts do not.
        for cast in list(query.find_all(exp.Cast)):
            if isinstance(cast.this, exp.JSONExtract) and cast.args['to'].this == exp.DataType.Type.VARCHAR:
                cast.set('this', exp.JSONExtractScalar(this=cast.this.this.copy(), expression=cast.this.expression.copy()))
        # DuckDB has no untyped ARRAY/OBJECT; choose local equivalents only.
        # Remote Snowflake tests retain every source type unchanged.
        for kind in list(query.find_all(exp.DataType)):
            if kind.this == exp.DataType.Type.ARRAY and not kind.expressions:
                kind.set('expressions', [exp.DataType.build('VARCHAR')])
            elif kind.this in (exp.DataType.Type.OBJECT, exp.DataType.Type.VARIANT):
                kind.replace(exp.DataType.build('JSON'))
        cursor = self.local.execute(('EXPLAIN ' if explain else '') + query.sql(dialect='duckdb'))
        return [dict(zip([column[0].upper() for column in cursor.description], row)) for row in cursor.fetchall()]


class ReportingSQLTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.runner = Runner()

    def setUp(self):
        self.fixtures = {}

    def add(self, name, **row):
        self.fixtures.setdefault(name, []).append(row)

    def platform(self, key='GITHUB_COPILOT', **changes):
        row = dict(PLATFORM_KEY=key, DISPLAY_NAME=key, COST_MODEL='METERED', NATIVE_UNIT='CREDITS',
                   IS_ACTIVE=True, SUPPORTS_USER_GRAIN=True, SUPPORTS_USER_COST=True,
                   SUPPORTS_ACTIVITY_DEPTH=True, EXPECTED_LAG_HOURS=48)
        self.add('AI_SPEND.CONTROL.PLATFORM_REGISTRY', **dict(row, **changes))

    def identity(self, subject='reader', platform='GITHUB_COPILOT', **changes):
        row = dict(PLATFORM_KEY=platform, SUBJECT_KEY=subject, PERSON_KEY=subject,
                   ENTITY_KIND='PERSON', CONFIDENCE='ASSERTED', DEPARTMENT='Engineering',
                   VALID_FROM='2026-01-01', VALID_TO='9999-12-31', UPDATED_AT='2026-01-01 00:00:00+00:00')
        self.add('AI_SPEND.CONTROL.IDENTITY_MAP', **dict(row, **changes))

    def partition(self, day='2026-09-01', run='old', status='SUCCEEDED', completed='2026-10-10 10:00:00+00:00', records=None):
        records = records if records is not None else [('reader', 1)]
        self.add('AI_SPEND.CONTROL.PULL_RUN_LOG', PLATFORM_KEY='GITHUB_COPILOT', REPORT_NAME='USER_USAGE',
                 RUN_ID=run, STATUS=status, COMPLETED_AT=completed, STARTED_AT=completed, WATERMARK_TO=day)
        self.add('AI_SPEND.CONTROL.REPORT_SNAPSHOT', PLATFORM_KEY='GITHUB_COPILOT', REPORT_NAME='USER_USAGE',
                 RUN_ID=run, PARTITION_DATE=day, RECORD_COUNT=len(records))
        for number, (subject, qty) in enumerate(records):
            self.add('AI_SPEND.RAW.LANDING_AI_USAGE', PLATFORM_KEY='GITHUB_COPILOT', REPORT_NAME='USER_USAGE',
                     BILLING_CONTEXT='GITHUB_ENTERPRISE', RUN_ID=run, SOURCE_ROW_NUMBER=number,
                     SOURCE_FILE=run, LOADED_AT=completed,
                     RECORD=dict(day=day, user_login=subject, ai_credits_used=qty, code_acceptance_activity_count=1))

    def native(self, day='2026-09-01', subject=1, qty=1, **changes):
        row = dict(USER_ID=subject, USER_NAME=str(subject), USAGE_TIME=day+' 12:00:00+00:00',
                   TOKEN_CREDITS=qty, TOKENS=10, REQUEST_ID=f'{day}-{subject}', INTERFACE='desktop')
        self.add('SNOWFLAKE.ACCOUNT_USAGE.SNOWFLAKE_COCO_USAGE_HISTORY', **dict(row, **changes))

    def rate(self, platform='SNOWFLAKE_CORTEX', **changes):
        row = dict(PLATFORM_KEY=platform, VALID_FROM='2026-01-01', VALID_TO='9999-12-31',
                   UNIT_COST=2, CURRENCY_CODE='USD', UPDATED_AT='2026-01-01 00:00:00+00:00')
        self.add('AI_SPEND.CONTROL.PLATFORM_RATE', **dict(row, **changes))

    def rows(self, name):
        return self.runner.run('AI_SPEND.'+name, self.fixtures)

    def test_all_query_bodies_explain_with_typed_empty_sources(self):
        for target in QUERIES:
            with self.subTest(target=target):
                self.runner.run(target, {}, explain=True)

    def test_snapshot_restatement_preserves_breakdowns_and_removes_omitted_subject(self):
        self.platform()
        self.partition(records=[('reader', 100), ('removed', 200)])
        self.partition(run='new', completed='2026-10-11 10:00:00+00:00', records=[('reader', 2), ('reader', 3)])
        rows = self.rows('SHAPED.UNIFIED_AI_USAGE')
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]['NATIVE_QTY'], 5)
        self.assertEqual(rows[0]['SUBJECT_KEY'], 'reader')
        self.assertIsNone(rows[0]['COST_AMOUNT'])

    def test_empty_partition_removes_previous_and_failed_run_is_invisible(self):
        self.platform()
        self.partition()
        self.partition(run='failed', status='FAILED', completed='2026-10-12 10:00:00+00:00', records=[('reader', 999)])
        self.assertEqual(self.rows('SHAPED.UNIFIED_AI_USAGE')[0]['NATIVE_QTY'], 1)
        self.partition(run='empty', completed='2026-10-11 10:00:00+00:00', records=[])
        self.assertEqual(self.rows('SHAPED.UNIFIED_AI_USAGE'), [])

    def test_missing_and_overlapping_rates_do_not_create_money(self):
        self.platform('SNOWFLAKE_CORTEX')
        self.native(qty=5)
        self.assertEqual(self.rows('SHAPED.UNIFIED_AI_USAGE')[0]['COST_STATUS'], 'MISSING_RATE')
        self.rate()
        self.assertEqual(self.rows('SHAPED.UNIFIED_AI_USAGE')[0]['COST_AMOUNT'], 10)
        self.rate(UNIT_COST=7)
        row = self.rows('SHAPED.UNIFIED_AI_USAGE')[0]
        self.assertIsNone(row['COST_AMOUNT'])
        self.assertEqual(row['COST_STATUS'], 'INVALID_COST_INPUT')

    def test_historical_identity_and_month_start_seat_allocation(self):
        self.platform()
        self.partition(day='2026-08-31')
        self.partition(day='2026-09-02', run='sep')
        self.identity(VALID_TO='2026-08-31', DEPARTMENT='Old')
        self.identity(VALID_FROM='2026-09-01', DEPARTMENT='New')
        self.assertEqual({str(row['USAGE_DATE']): row['DEPARTMENT'] for row in self.rows('SHAPED.UNIFIED_AI_USAGE')},
                         {'2026-08-31': 'Old', '2026-09-02': 'New'})
        self.seat(month='2026-08-01')
        self.assertEqual(self.rows('CONTROL.V_PERSON_DIRECTORY')[0]['DEPARTMENT'], 'Old')

    def seat(self, month='2026-09-01', **changes):
        row = dict(PLATFORM_KEY='GITHUB_COPILOT', PERSON_KEY='reader', PERIOD_MONTH=month,
                   SEAT_MONTHLY_COST=30, CURRENCY_CODE='USD', IS_ACTIVE_IN_PERIOD=True, SOURCE_NAME='FINANCE')
        self.add('AI_SPEND.CONTROL.SEAT_ENTITLEMENT', **dict(row, **changes))

    def test_dormancy_requires_complete_closed_period_and_billed_identity(self):
        self.platform()
        self.identity()
        self.seat()
        self.assertEqual(self.rows('GOLD.SEAT_UTILIZATION')[0]['UTILIZATION_BAND'], 'UNKNOWN_INCOMPLETE_COVERAGE')
        self.add('AI_SPEND.CONTROL.ACTIVITY_COVERAGE', PLATFORM_KEY='GITHUB_COPILOT', PERIOD_MONTH='2026-09-01', IS_COMPLETE=False)
        self.assertEqual(self.rows('GOLD.SEAT_UTILIZATION')[0]['RECLAIMABLE_COST'], 0)
        self.fixtures['AI_SPEND.CONTROL.ACTIVITY_COVERAGE'][0]['IS_COMPLETE'] = True
        self.assertEqual(self.rows('GOLD.SEAT_UTILIZATION')[0]['UTILIZATION_BAND'], 'DORMANT')
        self.assertEqual(self.rows('GOLD.SEAT_UTILIZATION')[0]['RECLAIMABLE_COST'], 30)
        self.fixtures['AI_SPEND.CONTROL.SEAT_ENTITLEMENT'][0]['SOURCE_NAME'] = 'GITHUB_ROSTER_ESTIMATE'
        self.assertEqual(self.rows('GOLD.SEAT_UTILIZATION')[0]['UTILIZATION_BAND'], 'UNKNOWN_BILLING_ESTIMATE')

    def test_native_records_are_not_requests_and_missing_subject_cost_survives(self):
        self.platform('SNOWFLAKE_CORTEX')
        self.native(subject=None, qty=2, REQUEST_ID='same')
        self.native(subject=None, qty=3, REQUEST_ID='same')
        row = self.rows('RAW.V_SNOWFLAKE_NATIVE_USAGE')[0]
        self.assertEqual((row['CREDITS'], row['REQUEST_COUNT'], row['METERING_RECORD_COUNT']), (5, 1, 2))
        self.assertEqual(row['ENTITY_KIND'], 'UNKNOWN')
        self.assertEqual(row['SUBJECT_KEY'], 'UNKNOWN_USER')

    def test_nonhuman_subjects_excluded_from_ranks_but_kept_in_total(self):
        self.platform('SNOWFLAKE_CORTEX')
        self.rate()
        for subject, kind in [(1, 'PERSON'), (2, 'PERSON'), (3, 'PERSON'), (4, 'SERVICE'), (0, 'PERSON')]:
            self.add('SNOWFLAKE.ACCOUNT_USAGE.USERS', USER_ID=subject, NAME=str(subject), TYPE=kind)
            self.identity(str(subject), 'SNOWFLAKE_CORTEX')
            self.native(subject=subject, qty=subject+1)
        self.native(subject=99, qty=1000)
        tiers = self.rows('GOLD.AI_ENGAGEMENT_TIERS')
        self.assertEqual({row['PERSON_KEY'] for row in tiers}, {'1', '2', '3'})
        self.assertEqual(sum(row['ALLOCATED_COST'] for row in self.rows('GOLD.AI_SPEND_ALLOCATED')), 2030)
        department = next(row for row in self.rows('GOLD.AI_SPEND_BY_DEPARTMENT') if row['DEPARTMENT'] == 'Engineering')
        self.assertEqual(department['PEOPLE'], 3)
        self.assertEqual(department['COST_PER_PERSON'], 6)

    def test_currency_separation_and_empty_human_denominator(self):
        self.platform('SNOWFLAKE_CORTEX')
        self.native(day='2026-08-31', qty=10)
        self.native(day='2026-09-01', qty=10)
        self.rate(VALID_TO='2026-08-31', CURRENCY_CODE='USD')
        self.rate(VALID_FROM='2026-09-01', CURRENCY_CODE='EUR')
        rows = self.rows('GOLD.AI_SPEND_BY_DEPARTMENT')
        self.assertEqual({row['CURRENCY_CODE'] for row in rows}, {'USD', 'EUR'})
        self.assertTrue(all(row['COST_PER_PERSON'] is None for row in rows))

    def test_future_seats_do_not_anchor_and_short_window_does_not_annualize(self):
        self.platform()
        self.identity()
        self.partition(day='2026-10-02')
        self.seat(month='2026-10-01')
        row = self.rows('GOLD.AI_SPEND_FORECAST')[0]
        self.assertEqual(str(row['AS_OF_DATE']), '2026-10-02')
        self.assertEqual(row['OBSERVED_DAYS_LAST_30D'], 2)
        self.assertIsNone(row['ANNUAL_RUN_RATE_FLAT'])
        self.assertIsNone(row['ANNUAL_RUN_RATE_TRENDED'])

    def test_forecast_full_recent_but_partial_prior_suppresses_growth(self):
        self.platform('SNOWFLAKE_CORTEX')
        self.rate()
        for offset in range(30):
            self.native(day=str(NOW - dt.timedelta(days=offset+1)))
        row = self.rows('GOLD.AI_SPEND_FORECAST')[0]
        self.assertEqual(row['OBSERVED_DAYS_LAST_30D'], 30)
        self.assertAlmostEqual(float(row['ANNUAL_RUN_RATE_FLAT']), 730)
        self.assertIsNone(row['MOM_GROWTH_PCT'])
        self.assertIsNone(row['ANNUAL_RUN_RATE_TRENDED'])

    def test_required_reports_failed_first_run_never_success_and_native_states(self):
        self.platform()
        self.platform('SNOWFLAKE_CORTEX')
        for platform, report, kind in [('GITHUB_COPILOT', 'USER_USAGE', 'EXTERNAL'),
                                       ('GITHUB_COPILOT', 'SEATS', 'EXTERNAL'),
                                       ('SNOWFLAKE_CORTEX', 'CORTEX_CODE', 'NATIVE')]:
            self.add('AI_SPEND.CONTROL.REPORT_REGISTRY', PLATFORM_KEY=platform, REPORT_NAME=report, SOURCE_KIND=kind, IS_REQUIRED=True)
        self.partition(status='FAILED')
        states = {row['REPORT_NAME']: row['REPORT_STATUS'] for row in self.rows('CONTROL.V_REPORT_HEALTH')}
        self.assertEqual(states, {'USER_USAGE': 'FAILED', 'SEATS': 'NEVER_PULLED', 'CORTEX_CODE': 'NO_OBSERVED_USAGE'})
        self.native(day='2026-10-12')
        states = {row['REPORT_NAME']: row['REPORT_STATUS'] for row in self.rows('CONTROL.V_REPORT_HEALTH')}
        self.assertEqual(states['CORTEX_CODE'], 'OBSERVED_RECENT_USAGE')
        self.assertEqual(next(row for row in self.rows('CONTROL.V_PIPELINE_HEALTH') if row['PLATFORM_KEY'] == 'GITHUB_COPILOT')['HEALTH_STATUS'], 'REPORT_REVIEW_REQUIRED')

    def test_extension_points_are_inert_even_when_active(self):
        for key in ('CHATGPT_ENTERPRISE', 'BOX_AI', 'M365_COPILOT'):
            self.platform(key)
        self.partition()
        for view in ('CHATGPT_ENTERPRISE', 'BOX_AI', 'M365_COPILOT'):
            self.assertEqual(self.rows('SHAPED.V_SHRED_'+view), [])

    def external_cost_rows(self, rows):
        # Test the extension contract without activating an illustrative vendor parser.
        schema = dict(PLATFORM_KEY='VARCHAR', REPORT_NAME='VARCHAR', BILLING_CONTEXT='VARCHAR',
                      USAGE_DATE='DATE', SUBJECT_KEY='VARCHAR', SUBJECT_DISPLAY_NAME='VARCHAR',
                      ENTITY_KIND='VARCHAR', NATIVE_QTY='NUMBER(38,6)', ACTIVITY_COUNT='NUMBER',
                      VENDOR_ENGAGEMENT_LABEL='VARCHAR', COST_BASIS='VARCHAR', BILLABLE_NATIVE_QTY='NUMBER(38,6)',
                      REPORTED_COST_AMOUNT='NUMBER(38,6)', REPORTED_CURRENCY='VARCHAR', RUN_ID='VARCHAR',
                      PULLED_AT='TIMESTAMP_TZ', SOURCE_FILE='VARCHAR', SOURCE_ROW_NUMBER='NUMBER', LOADED_AT='TIMESTAMP_TZ')
        defaults = dict(PLATFORM_KEY='GITHUB_COPILOT', REPORT_NAME='USER_USAGE', BILLING_CONTEXT='GITHUB_ENTERPRISE',
                        USAGE_DATE='2026-09-01', SUBJECT_KEY='reader', ENTITY_KIND='PERSON', NATIVE_QTY=100, RUN_ID='old')
        self.fixtures['AI_SPEND.SHAPED.V_EXTERNAL_USAGE'] = fixture_query(schema, [dict(defaults, **row) for row in rows])

    def test_reported_currency_preserved_billable_only_and_activity_not_charged(self):
        self.platform()
        self.partition()
        self.rate('GITHUB_COPILOT', UNIT_COST=7)
        self.external_cost_rows([
            dict(SUBJECT_KEY='reported', COST_BASIS='REPORTED_CURRENCY', REPORTED_COST_AMOUNT=1.255, REPORTED_CURRENCY='EUR'),
            dict(SUBJECT_KEY='billable', COST_BASIS='BILLABLE_NATIVE', BILLABLE_NATIVE_QTY=2),
            dict(SUBJECT_KEY='activity', COST_BASIS='ACTIVITY_ONLY'),
            dict(SUBJECT_KEY='bad_currency', COST_BASIS='REPORTED_CURRENCY', REPORTED_COST_AMOUNT=9, REPORTED_CURRENCY='bad')])
        rows = {row['SUBJECT_KEY']: row for row in self.rows('SHAPED.UNIFIED_AI_USAGE')}
        self.assertAlmostEqual(float(rows['reported']['COST_AMOUNT']), 1.255)
        self.assertEqual(rows['reported']['CURRENCY_CODE'], 'EUR')
        self.assertEqual(rows['billable']['COST_AMOUNT'], 14)
        self.assertIsNone(rows['activity']['COST_AMOUNT'])
        self.assertIsNone(rows['bad_currency']['COST_AMOUNT'])
        self.assertEqual(rows['bad_currency']['COST_STATUS'], 'INVALID_COST_INPUT')

    def test_same_day_currency_breakdowns_remain_separate(self):
        self.platform()
        self.partition()
        self.identity()
        self.external_cost_rows([
            dict(COST_BASIS='REPORTED_CURRENCY', REPORTED_COST_AMOUNT=10, REPORTED_CURRENCY='USD'),
            dict(COST_BASIS='REPORTED_CURRENCY', REPORTED_COST_AMOUNT=20, REPORTED_CURRENCY='EUR')])
        self.assertEqual({row['CURRENCY_CODE']: row['MONTH_TOTAL_COST'] for row in self.rows('GOLD.AI_SPEND_BY_DEPARTMENT')},
                         {'USD': 10, 'EUR': 20})
        self.assertEqual(self.rows('GOLD.AI_ENGAGEMENT_TIERS')[0]['ACTIVE_DAYS'], 1)

    def test_invalid_entity_is_unknown_and_service_mapping_not_human(self):
        self.platform()
        self.partition()
        self.identity(ENTITY_KIND='SERVICE')
        self.external_cost_rows([dict(COST_BASIS='ACTIVITY_ONLY'),
                                 dict(SUBJECT_KEY='invalid', ENTITY_KIND=None, COST_BASIS='ACTIVITY_ONLY')])
        self.assertEqual({row['ENTITY_KIND'] for row in self.rows('SHAPED.UNIFIED_AI_USAGE')}, {'SERVICE', 'UNKNOWN'})
        self.assertEqual(self.rows('GOLD.AI_ENGAGEMENT_TIERS'), [])

    def test_forecast_sixty_days_and_pricing_gap_gate(self):
        self.platform('SNOWFLAKE_CORTEX')
        self.rate()
        for offset in range(60):
            self.native(day=str(NOW - dt.timedelta(days=offset+1)))
        row = self.rows('GOLD.AI_SPEND_FORECAST')[0]
        self.assertAlmostEqual(float(row['ANNUAL_RUN_RATE_TRENDED']), 730)
        self.assertEqual(row['MOM_GROWTH_PCT'], 0)
        self.fixtures['AI_SPEND.CONTROL.PLATFORM_RATE'][0]['VALID_FROM'] = '2026-09-01'
        row = self.rows('GOLD.AI_SPEND_FORECAST')[0]
        self.assertGreater(row['UNPRICED_ROWS_60D'], 0)
        self.assertIsNone(row['ANNUAL_RUN_RATE_FLAT'])
        self.assertIsNone(row['ANNUAL_RUN_RATE_TRENDED'])

    def test_successful_sibling_cannot_hide_never_pulled_seats(self):
        self.platform()
        self.partition(day='2026-10-12', completed='2026-10-13 10:00:00+00:00')
        for report in ('USER_USAGE', 'SEATS'):
            self.add('AI_SPEND.CONTROL.REPORT_REGISTRY', PLATFORM_KEY='GITHUB_COPILOT', REPORT_NAME=report,
                     SOURCE_KIND='EXTERNAL', IS_REQUIRED=True)
        self.assertEqual({row['REPORT_NAME']: row['REPORT_STATUS'] for row in self.rows('CONTROL.V_REPORT_HEALTH')},
                         {'USER_USAGE': 'HEALTHY', 'SEATS': 'NEVER_PULLED'})
        self.assertEqual(self.rows('CONTROL.V_PIPELINE_HEALTH')[0]['HEALTH_STATUS'], 'REPORT_REVIEW_REQUIRED')

    def test_semantic_human_cost_metric_executes_on_matching_population(self):
        text = (ROOT / 'sql/08_semantic_view_agent.sql').read_text()
        expression = re.search(r'spend.cost_per_person AS (.+)\n', text).group(1)
        metric = sqlglot.parse_one(expression, read='snowflake')
        for column in metric.find_all(exp.Column):
            column.set('this', exp.to_identifier({'allocated_cost_fact': 'ALLOCATED_COST',
                                                 'entity_kind': 'ENTITY_KIND', 'person': 'PERSON_KEY'}[column.name]))
            column.set('table', None)
        query = exp.select(metric.as_('COST_PER_PERSON')).from_('AI_SPEND.GOLD.AI_SPEND_ALLOCATED')
        target = 'TEST.SEMANTIC.HUMAN_METRIC'
        QUERIES[target] = query
        schema = dict(ALLOCATED_COST='NUMBER(38,6)', ENTITY_KIND='VARCHAR', PERSON_KEY='VARCHAR')
        try:
            rows = [dict(ALLOCATED_COST=10, ENTITY_KIND='PERSON', PERSON_KEY='reader'),
                    dict(ALLOCATED_COST=1000, ENTITY_KIND='SERVICE', PERSON_KEY='service'),
                    dict(ALLOCATED_COST=100, ENTITY_KIND='PERSON', PERSON_KEY='UNRESOLVED:source:user')]
            self.fixtures['AI_SPEND.GOLD.AI_SPEND_ALLOCATED'] = fixture_query(schema, rows)
            self.assertEqual(self.runner.run(target, self.fixtures)[0]['COST_PER_PERSON'], 10)
            self.fixtures['AI_SPEND.GOLD.AI_SPEND_ALLOCATED'] = fixture_query(schema, rows[1:])
            self.assertIsNone(self.runner.run(target, self.fixtures)[0]['COST_PER_PERSON'])
        finally:
            QUERIES.pop(target)

    def test_publication_delay_is_not_failed_pull_or_stale_source(self):
        self.platform()
        self.identity()
        self.partition(day='2026-10-10', completed='2026-10-13 10:00:00+00:00')
        self.fixtures['AI_SPEND.CONTROL.PULL_RUN_LOG'][0]['WATERMARK_TO'] = '2026-10-11'
        self.add('AI_SPEND.CONTROL.REPORT_REGISTRY', PLATFORM_KEY='GITHUB_COPILOT', REPORT_NAME='USER_USAGE',
                 SOURCE_KIND='EXTERNAL', IS_REQUIRED=True)
        self.assertEqual(self.rows('CONTROL.V_REPORT_HEALTH')[0]['REPORT_STATUS'], 'HEALTHY')
        self.assertEqual(self.rows('CONTROL.V_PIPELINE_HEALTH')[0]['HEALTH_STATUS'], 'HEALTHY')
        self.fixtures['AI_SPEND.CONTROL.PULL_RUN_LOG'][0]['WATERMARK_TO'] = '2026-10-09'
        self.assertEqual(self.rows('CONTROL.V_REPORT_HEALTH')[0]['REPORT_STATUS'], 'SOURCE_BEHIND')

    def test_semantic_seat_metrics_exclude_nonbilled_rows(self):
        text = (ROOT / 'sql/08_semantic_view_agent.sql').read_text()
        expressions = []
        for name in ('seat_count', 'total_seat_cost'):
            expression = sqlglot.parse_one(re.search(r'seats\.'+name+r' AS (.+)\n', text).group(1), read='snowflake')
            for column in expression.find_all(exp.Column):
                column.set('this', exp.to_identifier({'is_billed': 'IS_ACTIVE_IN_PERIOD',
                                                     'seat_person': 'PERSON_KEY', 'seat_cost_fact': 'SEAT_MONTHLY_COST'}[column.name]))
                column.set('table', None)
            expressions.append(expression.as_(name.upper()))
        target = 'TEST.SEMANTIC.SEAT_METRICS'
        QUERIES[target] = exp.select(*expressions).from_('AI_SPEND.GOLD.SEAT_UTILIZATION')
        schema = dict(PERSON_KEY='VARCHAR', SEAT_MONTHLY_COST='NUMBER(38,4)', IS_ACTIVE_IN_PERIOD='BOOLEAN')
        self.fixtures['AI_SPEND.GOLD.SEAT_UTILIZATION'] = fixture_query(schema, [
            dict(PERSON_KEY='billed', SEAT_MONTHLY_COST=30, IS_ACTIVE_IN_PERIOD=True),
            dict(PERSON_KEY='not_billed', SEAT_MONTHLY_COST=100, IS_ACTIVE_IN_PERIOD=False)])
        try:
            row = self.runner.run(target, self.fixtures)[0]
            self.assertEqual(row['SEAT_COUNT'], 1)
            self.assertEqual(float(row['TOTAL_SEAT_COST']), 30)
        finally:
            QUERIES.pop(target)

    def test_semantic_person_access_and_grant_preservation_contract(self):
        text = (ROOT / 'sql/08_semantic_view_agent.sql').read_text()
        tokens = sqlglot.tokenize(text, read='snowflake')
        words = [token.text.upper() for token in tokens]
        # Public facts and person dimensions intentionally exist: do not call this
        # an aggregate boundary. This checks the authored contract, not live RBAC.
        self.assertNotIn('PRIVATE', words)
        self.assertIn('SPEND', words)
        self.assertRegex(text, r'spend\.person AS PERSON_KEY')
        self.assertRegex(text, r'spend\.allocated_cost_fact AS ALLOCATED_COST')
        self.assertRegex(text, r'CREATE OR ALTER SEMANTIC VIEW AI_SPEND.GOLD.AI_SPEND_SV')
        self.assertRegex(text, r'CREATE OR REPLACE AGENT AI_SPEND.GOLD.AI_SPEND_AGENT\s+COPY GRANTS')
        self.assertIn('NOT an', text)

    def test_dynamic_table_clock_functions_only_in_filters(self):
        for path in SQL_FILES:
            for name in re.findall(r'CREATE OR ALTER DYNAMIC TABLE\s+(AI_SPEND\.\w+\.\w+)', path.read_text()):
                for node in QUERIES[name].walk():
                    if isinstance(node, (exp.CurrentDate, exp.CurrentTimestamp)):
                        self.assertIsNotNone(node.find_ancestor(exp.Where, exp.Having, exp.Qualify), name)

    def test_open_period_and_unknown_identity_never_dormant(self):
        self.platform()
        self.identity()
        self.seat(month='2026-10-01')
        self.add('AI_SPEND.CONTROL.ACTIVITY_COVERAGE', PLATFORM_KEY='GITHUB_COPILOT', PERIOD_MONTH='2026-10-01', IS_COMPLETE=True)
        self.assertEqual(self.rows('GOLD.SEAT_UTILIZATION')[0]['UTILIZATION_BAND'], 'UNKNOWN_INCOMPLETE_COVERAGE')
        self.fixtures['AI_SPEND.CONTROL.SEAT_ENTITLEMENT'][0]['PERIOD_MONTH'] = '2026-09-01'
        self.fixtures['AI_SPEND.CONTROL.ACTIVITY_COVERAGE'][0]['PERIOD_MONTH'] = '2026-09-01'
        self.fixtures['AI_SPEND.CONTROL.IDENTITY_MAP'] = []
        self.assertEqual(self.rows('GOLD.SEAT_UTILIZATION')[0]['UTILIZATION_BAND'], 'UNKNOWN_IDENTITY')
        self.assertEqual(self.rows('GOLD.SEAT_UTILIZATION')[0]['RECLAIMABLE_COST'], 0)

    def test_no_projection_wildcards(self):
        for query in QUERIES.values():
            for select in query.find_all(exp.Select):
                self.assertFalse(any(item.is_star for item in select.expressions))


if __name__ == '__main__':
    unittest.main(verbosity=2)
