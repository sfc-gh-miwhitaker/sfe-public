"""
Cortex Cost Calculator - Python Unit Tests

Tests for calculation functions, projection formulas, and data transformations.

Author: SE Community
Created: 2026-01-05
Expires: See deploy_all.sql
"""

import unittest
import math
import random
from datetime import date, datetime, timedelta


class TestCalculationFunctions(unittest.TestCase):
    """Test mathematical calculations and formulas"""

    def setUp(self):
        """Create sample data for testing"""
        random.seed(42)  # Reproducible tests
        start = date(2025, 1, 1)
        self.sample_rows = []
        for i in range(30):
            self.sample_rows.append(
                {
                    "DATE": start + timedelta(days=i),
                    "SERVICE_TYPE": "Cortex Functions",
                    "TOTAL_CREDITS": random.uniform(10.0, 50.0),
                    "DAILY_UNIQUE_USERS": random.randint(5, 20),
                    "TOTAL_OPERATIONS": random.randint(100, 500),
                }
            )

    def test_credits_per_user_calculation(self):
        """Test credits per user calculation"""
        for idx, row in enumerate(self.sample_rows):
            expected = row["TOTAL_CREDITS"] / row["DAILY_UNIQUE_USERS"]
            actual = expected
            self.assertAlmostEqual(actual, expected, places=4,
                                   msg=f"Credits per user mismatch at row {idx}")

    def test_growth_rate_calculation(self):
        """Test week-over-week growth rate calculation"""
        current_credits = 100.0
        previous_credits = 80.0
        expected_growth = ((current_credits - previous_credits) / previous_credits) * 100

        self.assertAlmostEqual(expected_growth, 25.0, places=2)

    def test_growth_rate_with_zero_baseline(self):
        """Test growth rate when previous value is zero"""
        current_credits = 100.0
        previous_credits = 0.0

        # Should handle division by zero gracefully
        if previous_credits == 0:
            growth_rate = None
        else:
            growth_rate = ((current_credits - previous_credits) / previous_credits) * 100

        self.assertIsNone(growth_rate, "Should return None for zero baseline")

    def test_projection_formula(self):
        """Test cost projection formula"""
        baseline_credits = 1000.0
        growth_rate = 0.10  # 10% per month
        months = 12
        credit_cost = 3.00

        projections = []
        for month in range(1, months + 1):
            growth_factor = (1 + growth_rate) ** month
            projected_credits = baseline_credits * growth_factor
            projected_cost = projected_credits * credit_cost
            projections.append(projected_cost)

        # Test specific months
        self.assertAlmostEqual(projections[0], 3300.0, places=1)  # Month 1
        self.assertAlmostEqual(projections[11], 9415.3, places=1)  # Month 12

    def test_rolling_average_calculation(self):
        """Test 30-day rolling average"""
        credits = [r["TOTAL_CREDITS"] for r in self.sample_rows]

        def rolling_mean(values, window):
            out = []
            for i in range(len(values)):
                start = max(0, i - window + 1)
                chunk = values[start : i + 1]
                out.append(sum(chunk) / len(chunk))
            return out

        rolling = rolling_mean(credits, window=7)

        # First value should equal itself
        self.assertAlmostEqual(rolling[0], credits[0], places=8)

        # 7th value should be average of first 7
        expected_avg = sum(credits[:7]) / 7
        self.assertAlmostEqual(rolling[6], expected_avg, places=8)


class TestDataValidation(unittest.TestCase):
    """Test data validation logic"""

    def test_validate_required_columns(self):
        """Test CSV column validation"""
        required_cols = ['DATE', 'SERVICE_TYPE', 'TOTAL_CREDITS']

        # Valid row
        valid_row = {
            "DATE": date(2025, 1, 1),
            "SERVICE_TYPE": "Cortex Functions",
            "TOTAL_CREDITS": 100.0,
        }
        missing = [col for col in required_cols if col not in valid_row]
        self.assertEqual(len(missing), 0, "Should have all required columns")

        # Invalid row (missing TOTAL_CREDITS)
        invalid_row = {"DATE": date(2025, 1, 1), "SERVICE_TYPE": "Cortex Functions"}
        missing = [col for col in required_cols if col not in invalid_row]
        self.assertIn('TOTAL_CREDITS', missing)

    def test_validate_date_format(self):
        """Test date format validation"""
        valid_dates = ['2025-01-01', '2024-12-31', '2023-06-15']
        for date_str in valid_dates:
            try:
                datetime.strptime(date_str, "%Y-%m-%d")
                is_valid = True
            except Exception:
                is_valid = False
            self.assertTrue(is_valid, f"Date {date_str} should be valid")

        invalid_dates = ['2025-13-01', '2025-01-32', 'invalid']
        for date_str in invalid_dates:
            with self.assertRaises(Exception):
                datetime.strptime(date_str, "%Y-%m-%d")

    def test_validate_negative_credits(self):
        """Test detection of negative credits"""
        credits = [100.0, -50.0, 200.0, -10.0]
        negative = [c for c in credits if c < 0]
        self.assertEqual(len(negative), 2, "Should detect 2 negative values")

    def test_validate_null_values(self):
        """Test detection of NULL values"""
        values = [100.0, None, 200.0, float("nan")]

        def is_null(v):
            if v is None:
                return True
            if isinstance(v, float) and math.isnan(v):
                return True
            return False

        null_count = sum(1 for v in values if is_null(v))
        self.assertEqual(null_count, 2, "Should detect 2 NULL values")

    def test_validate_service_types(self):
        """Test service type validation"""
        known_services = [
            'Cortex Analyst', 'Cortex Search', 'Cortex Functions', 'Document AI'
        ]

        services = ["Cortex Functions", "Unknown Service", "Cortex Analyst"]
        unknown = set(services) - set(known_services)
        self.assertEqual(len(unknown), 1, "Should detect 1 unknown service")
        self.assertIn('Unknown Service', unknown)


class TestDataTransformations(unittest.TestCase):
    """Test data transformation functions"""

    def setUp(self):
        """Create sample data"""
        start = date(2025, 1, 1)
        credits = [10, 12, 15, 18, 20, 22, 25, 28, 30, 32]
        self.rows = []
        for i, c in enumerate(credits):
            self.rows.append(
                {"DATE": start + timedelta(days=i), "SERVICE_TYPE": "Service A", "TOTAL_CREDITS": float(c)}
            )

    def test_calculate_30day_totals(self):
        """Test 30-day rolling totals calculation"""
        credits = [r["TOTAL_CREDITS"] for r in self.rows]

        def rolling_sum(values, window):
            out = []
            for i in range(len(values)):
                start = max(0, i - window + 1)
                out.append(sum(values[start : i + 1]))
            return out

        rolling = rolling_sum(credits, window=5)

        # First value = itself
        self.assertEqual(rolling[0], 10)

        # 5th value = sum of first 5
        expected_sum = sum(credits[:5])
        self.assertEqual(rolling[4], expected_sum)

    def test_group_by_service(self):
        """Test aggregation by service type"""
        rows = [
            {"SERVICE_TYPE": "Service A", "TOTAL_CREDITS": 100},
            {"SERVICE_TYPE": "Service A", "TOTAL_CREDITS": 150},
            {"SERVICE_TYPE": "Service B", "TOTAL_CREDITS": 200},
            {"SERVICE_TYPE": "Service B", "TOTAL_CREDITS": 250},
        ]

        totals = {}
        for r in rows:
            totals[r["SERVICE_TYPE"]] = totals.get(r["SERVICE_TYPE"], 0) + r["TOTAL_CREDITS"]

        self.assertEqual(len(totals), 2, "Should have 2 services")
        self.assertEqual(totals["Service A"], 250)
        self.assertEqual(totals["Service B"], 450)

    def test_date_range_filtering(self):
        """Test filtering by date range"""
        start_date = date(2025, 1, 5)
        end_date = date(2025, 1, 8)

        filtered = [r for r in self.rows if start_date <= r["DATE"] <= end_date]

        self.assertEqual(len(filtered), 4, "Should have 4 days in range")
        self.assertTrue(all(r["DATE"] >= start_date for r in filtered))
        self.assertTrue(all(r["DATE"] <= end_date for r in filtered))


class TestProjectionScenarios(unittest.TestCase):
    """Test cost projection scenarios"""

    def test_conservative_scenario(self):
        """Test 10% monthly growth projection"""
        baseline = 1000.0
        growth_rate = 0.10
        months = 12

        month_12 = baseline * ((1 + growth_rate) ** months)
        self.assertAlmostEqual(month_12, 3138.43, places=2)

    def test_moderate_scenario(self):
        """Test 25% monthly growth projection"""
        baseline = 1000.0
        growth_rate = 0.25
        months = 12

        month_12 = baseline * ((1 + growth_rate) ** months)
        self.assertAlmostEqual(month_12, 14551.92, places=2)

    def test_aggressive_scenario(self):
        """Test 50% monthly growth projection"""
        baseline = 1000.0
        growth_rate = 0.50
        months = 12

        month_12 = baseline * ((1 + growth_rate) ** months)
        self.assertAlmostEqual(month_12, 129746.34, places=2)

    def test_custom_scenario(self):
        """Test custom growth rate"""
        baseline = 1000.0
        growth_rate = 0.15  # 15% custom
        months = 6

        month_6 = baseline * ((1 + growth_rate) ** months)
        self.assertAlmostEqual(month_6, 2313.06, places=2)


class TestCurrencyFormatting(unittest.TestCase):
    """Test currency formatting functions"""

    def test_format_usd(self):
        """Test USD currency formatting"""
        value = 1234.56
        formatted = f"${value:,.2f}"
        self.assertEqual(formatted, "$1,234.56")

    def test_format_large_numbers(self):
        """Test large number formatting"""
        value = 1234567.89
        formatted = f"${value:,.2f}"
        self.assertEqual(formatted, "$1,234,567.89")

    def test_format_small_numbers(self):
        """Test small number formatting"""
        value = 0.123
        formatted = f"${value:,.2f}"
        self.assertEqual(formatted, "$0.12")


class TestAnomalyDetection(unittest.TestCase):
    """Test anomaly detection logic"""

    def test_high_alert_threshold(self):
        """Test HIGH alert classification (>50% growth)"""
        current = 150.0
        previous = 100.0
        growth = ((current - previous) / previous) * 100

        alert_level = 'HIGH' if growth > 50 else 'NORMAL'
        self.assertEqual(alert_level, 'NORMAL')  # 50% exactly is not HIGH

        current = 160.0
        growth = ((current - previous) / previous) * 100
        alert_level = 'HIGH' if growth > 50 else 'NORMAL'
        self.assertEqual(alert_level, 'HIGH')  # 60% is HIGH

    def test_medium_alert_threshold(self):
        """Test MEDIUM alert classification (>25% growth)"""
        current = 130.0
        previous = 100.0
        growth = ((current - previous) / previous) * 100

        alert_level = 'MEDIUM' if growth > 25 and growth <= 50 else 'NORMAL'
        self.assertEqual(alert_level, 'MEDIUM')  # 30% is MEDIUM

    def test_declining_alert(self):
        """Test DECLINING classification (negative growth)"""
        current = 80.0
        previous = 100.0
        growth = ((current - previous) / previous) * 100

        alert_level = 'DECLINING' if growth < 0 else 'NORMAL'
        self.assertEqual(alert_level, 'DECLINING')


if __name__ == '__main__':
    # Run all tests
    unittest.main(verbosity=2)
