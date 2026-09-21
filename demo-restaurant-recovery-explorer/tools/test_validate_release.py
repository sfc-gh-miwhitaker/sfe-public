"""Pair-programmed by SE Community + Cortex Code."""

import unittest

from validate_release import validate_value


class ContractValueTests(unittest.TestCase):
    def test_required_null_rejected(self):
        with self.assertRaises(ValueError):
            validate_value(None, {"nullable": False})

    def test_nullable_value_preserved(self):
        validate_value(None, {"nullable": True})

    def test_numeric_bounds_and_integer_types(self):
        field = {"kind": "number", "type": "NUMBER(12,0)", "nullable": False, "minimum": 0}
        validate_value(0, field)
        for value in (-1, 1.5, True, "1", float("nan"), float("inf")):
            with self.subTest(value=value), self.assertRaises(ValueError):
                validate_value(value, field)

    def test_enum(self):
        field = {"kind": "string", "type": "VARCHAR", "nullable": False, "values": ["USD"]}
        validate_value("USD", field)
        with self.assertRaises(ValueError):
            validate_value("EUR", field)

    def test_dates(self):
        field = {"kind": "string", "type": "DATE", "nullable": False}
        validate_value("2026-09-14", field)
        for value in ("2026-02-30", "20260914"):
            with self.subTest(value=value), self.assertRaises(ValueError):
                validate_value(value, field)

    def test_timestamp_requires_timezone(self):
        field = {"kind": "string", "type": "TIMESTAMP_TZ", "nullable": False}
        validate_value("2026-09-14T12:00:00Z", field)
        with self.assertRaises(ValueError):
            validate_value("2026-09-14T12:00:00", field)


if __name__ == "__main__":
    unittest.main()
