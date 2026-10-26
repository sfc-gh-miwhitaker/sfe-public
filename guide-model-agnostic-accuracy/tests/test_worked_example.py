"""Local configuration/fixture checks; not a Snowflake compiler or Agent evaluation.

Pair-programmed by SE Community + Cortex Code
Requires PyYAML. Run from the repository root with unittest discovery.
"""

import csv
import io
import json
import re
import sqlite3
import unittest
from decimal import ROUND_HALF_UP, Decimal
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
DOCUMENT = (ROOT / "WORKED-EXAMPLE.md").read_text()


class UniqueLoader(yaml.SafeLoader):
    """Reject duplicate keys instead of silently accepting overwritten config."""


def unique_mapping(loader, node, deep=False):
    result = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node, deep=deep)
        if key in result:
            raise ValueError(f"Duplicate YAML key: {key}")
        result[key] = loader.construct_object(value_node, deep=deep)
    return result


UniqueLoader.add_constructor(
    yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, unique_mapping
)


def example(name, language):
    pattern = rf"<!-- example: {re.escape(name)} -->\n```{language}\n(.*?)\n```"
    matches = re.findall(pattern, DOCUMENT, re.DOTALL)
    if len(matches) != 1:
        raise AssertionError(f"Expected one {name} block; found {len(matches)}")
    return matches[0]


def expected_metrics(rows):
    amounts = [Decimal(row["ORDER_AMOUNT_USD"]) for row in rows
               if row["ORDER_STATUS"] == "COMPLETED"]
    revenue = sum(amounts, Decimal(0))
    count = len(amounts)
    average = ((revenue / count).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
               if count else None)
    return float(revenue), count, float(average) if average is not None else None


class WorkedExampleTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # UniqueLoader subclasses SafeLoader and only changes duplicate-key handling.
        cls.semantic = yaml.load(example("semantic-view", "yaml"), Loader=UniqueLoader)  # nosec B506
        cls.agent = yaml.load(example("agent", "yaml"), Loader=UniqueLoader)  # nosec B506
        fixtures = re.findall(r"```csv\n(.*?)\n```", DOCUMENT, re.DOTALL)
        cls.channels, cls.orders = [list(csv.DictReader(io.StringIO(block)))
                                    for block in fixtures]
        cls.connection = sqlite3.connect(":memory:")
        cls.connection.execute(
            "CREATE TABLE ORDERS (ORDER_ID INTEGER, ORDER_DATE TEXT, CHANNEL_ID INTEGER, "
            "ORDER_STATUS TEXT, ORDER_AMOUNT_USD REAL)"
        )
        cls.connection.execute("CREATE TABLE CHANNELS (CHANNEL_ID INTEGER, CHANNEL_NAME TEXT)")
        cls.connection.executemany(
            "INSERT INTO ORDERS VALUES (?, ?, ?, ?, ?)",
            [(int(row["ORDER_ID"]), row["ORDER_DATE"], int(row["CHANNEL_ID"]),
              row["ORDER_STATUS"], float(row["ORDER_AMOUNT_USD"])) for row in cls.orders],
        )
        cls.connection.executemany(
            "INSERT INTO CHANNELS VALUES (?, ?)",
            [(int(row["CHANNEL_ID"]), row["CHANNEL_NAME"]) for row in cls.channels],
        )
        for table in cls.semantic["tables"]:
            columns = [column for section in ("dimensions", "time_dimensions", "facts")
                       for column in table.get(section, [])]
            projections = ", ".join(f'{column["expr"]} AS {column["name"]}'
                                    for column in columns)
            # Execute repository SQL expressions only in the disposable in-memory fixture.
            cls.connection.execute(
                f'CREATE VIEW __{table["name"]} AS SELECT {projections} '  # nosec B608
                f'FROM {table["base_table"]["table"]}'
            )

    @classmethod
    def tearDownClass(cls):
        cls.connection.close()

    def scoped_orders(self, start, end, channel=None):
        channel_ids = {row["CHANNEL_ID"] for row in self.channels
                       if channel is None or row["CHANNEL_NAME"] == channel}
        return [row for row in self.orders if start <= row["ORDER_DATE"] < end
                and row["CHANNEL_ID"] in channel_ids]

    def test_yaml_loader_rejects_duplicate_keys_and_python_tags(self):
        for source, error in [
            ("name: first\nname: second\n", ValueError),
            ("!!python/object:builtins.object {}", yaml.constructor.ConstructorError),
        ]:
            with self.subTest(source=source), self.assertRaises(error):
                # Exercise the SafeLoader subclass, including its unsafe-tag rejection.
                yaml.load(source, Loader=UniqueLoader)  # nosec B506

    def test_yaml_structure_and_references(self):
        tables = {table["name"]: table for table in self.semantic["tables"]}
        self.assertEqual(set(tables), {"orders", "channels"})
        self.assertEqual(self.semantic["name"], "SALES_PERFORMANCE")
        for table in tables.values():
            self.assertEqual(table["base_table"]["database"], "SNOWFLAKE_EXAMPLE")
            self.assertEqual(table["base_table"]["schema"], "ACCURACY_SALES")
            columns = {column["name"]: column for section in
                       ("dimensions", "time_dimensions", "facts")
                       for column in table.get(section, [])}
            self.assertTrue(set(table["primary_key"]["columns"]) <= columns.keys())
            self.assertTrue(all(column.get("description") for column in columns.values()))
        relationship, = self.semantic["relationships"]
        left = tables[relationship["left_table"]]
        right = tables[relationship["right_table"]]
        for pair in relationship["relationship_columns"]:
            left_type = next(column["data_type"] for column in left["dimensions"]
                             if column["name"] == pair["left_column"])
            right_type = next(column["data_type"] for column in right["dimensions"]
                              if column["name"] == pair["right_column"])
            self.assertEqual(left_type, right_type)
        self.assertNotIn("relationship_type", relationship)
        self.assertNotIn("join_type", relationship)

    def test_fixture_contract_and_enum_coverage(self):
        self.assertEqual(len(self.orders), 10)
        self.assertEqual(len({row["ORDER_ID"] for row in self.orders}), len(self.orders))
        channel_ids = {row["CHANNEL_ID"] for row in self.channels}
        self.assertEqual(len(channel_ids), len(self.channels))
        self.assertTrue(all(row["CHANNEL_ID"] in channel_ids for row in self.orders))
        self.assertTrue(all(all(value for value in row.values()) for row in self.orders))
        self.assertTrue(all(Decimal(row["ORDER_AMOUNT_USD"]) >= 0 for row in self.orders))
        for table in self.semantic["tables"]:
            for column in table["dimensions"]:
                if column.get("is_enum"):
                    rows = self.orders if table["name"] == "orders" else self.channels
                    self.assertEqual(set(column["sample_values"]),
                                     {row[column["expr"]] for row in rows})

    def test_vqr_queries_match_independent_arithmetic(self):
        queries = self.semantic["verified_queries"]
        self.assertEqual(len(queries), 3)
        expected_total = expected_metrics(self.scoped_orders("2026-01-01", "2026-02-01"))
        self.assertEqual(expected_total, (750.0, 5, 150.0))
        expected_web = expected_metrics(self.scoped_orders("2026-01-01", "2026-02-01", "Web"))
        breakdown = [(channel["CHANNEL_NAME"], *expected_metrics(self.scoped_orders(
            "2026-01-01", "2026-02-01", channel["CHANNEL_NAME"]))) for channel in self.channels]
        breakdown.sort(key=lambda row: (-row[1], row[0]))
        expected = {"january_totals": [expected_total], "january_by_channel": breakdown,
                    "january_web": [expected_web]}
        for query in queries:
            with self.subTest(query=query["name"]):
                self.assertNotRegex(query["sql"], r"(?i)SELECT\s+\*")
                self.assertEqual(self.connection.execute(query["sql"]).fetchall(),
                                 expected[query["name"]])

    def test_metric_expressions_without_default_filter(self):
        metrics = self.semantic["tables"][0]["metrics"]
        projection = ", ".join(metric["expr"] for metric in metrics)
        for start, end, channel in [
            ("2026-01-01", "2026-02-01", None),
            ("2026-01-10", "2026-01-21", None),
            ("2026-02-01", "2026-02-02", None),
            ("2026-01-01", "2026-02-01", "Partner"),
            ("2026-03-01", "2026-04-01", None),
        ]:
            with self.subTest(start=start, end=end, channel=channel):
                # Projection is repository SQL under test; filter values stay parameterized.
                sql = (f"SELECT {projection} FROM __orders AS orders "  # nosec B608
                       "JOIN __channels AS channels ON orders.channel_id = channels.channel_id "
                       "WHERE orders.order_date >= ? AND orders.order_date < ?")
                parameters = [start, end]
                if channel:
                    sql += " AND channels.channel_name = ?"
                    parameters.append(channel)
                actual = list(self.connection.execute(sql, parameters).fetchone())
                if actual[2] is not None:
                    actual[2] = float(Decimal(str(actual[2])).quantize(
                        Decimal("0.01"), rounding=ROUND_HALF_UP))
                self.assertEqual(tuple(actual), expected_metrics(self.scoped_orders(start, end, channel)))

    def test_documented_acceptance_numbers(self):
        cases = {
            "Held-out range": ("2026-01-10", "2026-01-21", None),
            "Held-out boundary": ("2026-02-01", "2026-02-02", None),
            "Held-out zero eligibility": ("2026-01-01", "2026-02-01", "Partner"),
            "Held-out empty period": ("2026-03-01", "2026-04-01", None),
        }
        vqr_questions = {query["question"] for query in self.semantic["verified_queries"]}
        for label, scope in cases.items():
            match = re.search(rf"^\| {label} \| (.*?) \| (.*?) \|$", DOCUMENT, re.MULTILINE)
            if match is None:
                self.fail(f"Missing acceptance case: {label}")
            self.assertNotIn(match[1], vqr_questions)
            revenue, count, average = expected_metrics(self.scoped_orders(*scope))
            self.assertIn(f"USD {revenue:.2f}", match[2])
            self.assertIn(f"{count} completed order", match[2])
            self.assertIn(f"USD {average:.2f} AOV" if average is not None
                          else "AOV not applicable", match[2])
        for channel in self.channels:
            name = channel["CHANNEL_NAME"]
            revenue, count, average = expected_metrics(self.scoped_orders(
                "2026-01-01", "2026-02-01", name))
            average_text = f"{average:.2f}" if average is not None else "Not applicable"
            self.assertIn(f"| {name} | {revenue:.2f} | {count} | {average_text} |", DOCUMENT)

    def test_agent_and_ground_truth_consistency(self):
        tool, = self.agent["tools"]
        name = tool["tool_spec"]["name"]
        self.assertEqual(set(self.agent["tool_resources"]), {name})
        self.assertEqual(tool["tool_spec"]["type"], "cortex_analyst_text_to_sql")
        self.assertEqual(self.agent["tool_resources"][name]["semantic_view"],
                         "SNOWFLAKE_EXAMPLE.ACCURACY_SALES." + self.semantic["name"])
        self.assertEqual(self.agent["models"]["orchestration"], "auto")
        self.assertTrue(all(value > 0 for value in self.agent["orchestration"]["budget"].values()))
        numeric = json.loads(example("numeric-ground-truth", "json"))
        clarification = json.loads(example("clarification-ground-truth", "json"))
        self.assertEqual(numeric["ground_truth_invocations"][0]["tool_name"], name)
        self.assertEqual(clarification["ground_truth_invocations"], [])
        for literal in ("400.00", "133.33", "3 completed orders"):
            self.assertIn(literal, numeric["ground_truth_output"])
        self.assertEqual(set(self.semantic["module_custom_instructions"]),
                         {"sql_generation", "question_categorization"})

    def test_reader_links_and_no_placeholders(self):
        readme = (ROOT / "README.md").read_text()
        self.assertIn("WORKED-EXAMPLE.md", readme)
        for relative in re.findall(r"\]\(([^)]+)\)", DOCUMENT):
            if not relative.startswith("https://"):
                self.assertTrue((ROOT / relative.split("#")[0]).is_file(), relative)
        for language, block in re.findall(r"```(yaml|json|csv)\n(.*?)\n```", DOCUMENT, re.DOTALL):
            self.assertNotRegex(block, r"<[A-Za-z_][A-Za-z0-9_ -]*>|\[TBD\]|\{\{.*?\}\}", language)
        self.assertIn("Pair-programmed by SE Community + Cortex Code", DOCUMENT)
        self.assertEqual(len(re.findall(r"^## [1-5]\. ", readme, re.MULTILINE)), 5)
        self.assertIn("**Review baseline:** 2026-09-04 | **Expires:** 2026-11-03", readme)


if __name__ == "__main__":
    unittest.main()
