"""Pair-programmed by SE Community + Cortex Code.

Validate a retained synthetic fixture without modifying source observations.
"""

import argparse
import hashlib
import itertools
import json
import math
from collections import Counter
from datetime import date, datetime, timedelta
from pathlib import Path


def require(condition, message):
    if not condition:
        raise ValueError(message)


def validate_value(value, field):
    if value is None:
        require(field["nullable"], "required value is null")
        return
    kind = field["kind"]
    valid = {
        "string": isinstance(value, str),
        "boolean": type(value) is bool,
        "number": type(value) in (int, float) and math.isfinite(value),
    }
    require(valid[kind], f"wrong type for {kind}")
    if "values" in field:
        require(value in field["values"], "invalid enum")
    for bound, operator in (("minimum", lambda left, right: left >= right),
                            ("maximum", lambda left, right: left <= right)):
        if bound in field:
            require(operator(value, field[bound]), f"outside {bound}")
    if field["type"] == "DATE":
        require(date.fromisoformat(value).isoformat() == value, "invalid ISO date")
    if field["type"] == "TIMESTAMP_TZ":
        require(datetime.fromisoformat(value).tzinfo is not None, "missing timezone")
    if field["type"].endswith(",0)"):
        require(value == int(value), "fractional integer")


def validate_release(directory):
    manifest = json.loads((directory / "manifest.json").read_text())
    require(manifest["synthetic"] is True, "Only synthetic fixtures are supported")
    inventory = {}
    documents = {}
    for filename, expected in manifest["files"].items():
        require(Path(filename).name == filename, "Invalid manifest filename")
        payload = (directory / filename).read_bytes()
        require(len(payload) == expected["bytes"], f"{filename}: size mismatch")
        require(hashlib.sha256(payload).hexdigest() == expected["sha256"],
                f"{filename}: checksum mismatch")
        documents[filename] = json.loads(payload)
        if "rows" in expected:
            require(len(documents[filename]) == expected["rows"], f"{filename}: row count")
        inventory[filename] = {**expected, "verified": True}
    schemas = documents["data_dictionary.json"]["tables"]
    tables = {name: documents[schema["file"]] for name, schema in schemas.items()}
    for name, schema in schemas.items():
        keys = set()
        fields = {field["name"] for field in schema["fields"]}
        for position, row in enumerate(tables[name]):
            require(set(row) == fields, f"{name}[{position}]: field mismatch")
            require(row["RELEASE_ID"] == manifest["releaseId"], f"{name}: release mismatch")
            key = tuple(row[column] for column in schema["grain"])
            require(key not in keys, f"{name}: duplicate grain {key}")
            keys.add(key)
            for field in schema["fields"]:
                try:
                    validate_value(row[field["name"]], field)
                except (ValueError, TypeError) as error:
                    raise ValueError(f"{name}[{position}].{field['name']}: {error}") from error
        for foreign in schema["foreignKeys"]:
            targets = {tuple(row[column] for column in foreign["references"])
                       for row in tables[foreign["table"]]}
            for row in tables[name]:
                key = tuple(row[column] for column in foreign["columns"])
                require(None in key or key in targets, f"{name}: dangling reference {key}")

    calendar = sorted(tables["calendar"], key=lambda row: row["WEEK_START"])
    roster = {row["RESTAURANT_ID"]: row for row in tables["roster"]}
    for position, period in enumerate(calendar):
        start = date.fromisoformat(period["WEEK_START"])
        require(start.weekday() == 0, "Calendar week must start Monday")
        require(period["WEEK_END_EXCLUSIVE"] == (start + timedelta(days=7)).isoformat(),
                "Calendar week length")
        require(period["IS_COMPLETE"] == (period["WEEK_END_EXCLUSIVE"] <= manifest["asOf"]),
                "Calendar completeness")
        if position:
            require(calendar[position - 1]["WEEK_END_EXCLUSIVE"] == period["WEEK_START"],
                    "Calendar gap")
        expected_baseline = calendar[position - 52]["WEEK_START"] if position >= 52 else None
        require(period["BASELINE_WEEK"] == expected_baseline, "Baseline mapping mismatch")
    performance = tables["performance"]
    dimension_fields = {field["name"]: field for field in schemas["performance"]["fields"]}
    dayparts = dimension_fields["DAYPART"]["values"]
    channels = dimension_fields["CHANNEL"]["values"]
    require(len(performance) == len(roster) * len(calendar) * len(dayparts) * len(channels),
            "Performance grid has absent rows")
    for row in performance:
        restaurant = roster[row["RESTAURANT_ID"]]
        require((row["GUESTS"] is not None and row["NET_SALES"] is not None)
                if row["IS_COMPLETE"] else (row["GUESTS"] is None and row["NET_SALES"] is None),
                "Performance completeness/null mismatch")
        inactive = row["WEEK_START"] < restaurant["OPEN_DATE"] or (
            restaurant["CLOSE_DATE"] and row["WEEK_START"] >= restaurant["CLOSE_DATE"])
        require(not inactive or (row["GUESTS"] == 0 and row["NET_SALES"] == 0),
                "Nonzero or unknown performance outside lifecycle")
        require(row["AVAILABLE_AT"] <= manifest["asOfTimestamp"], "Future performance availability")
    previous = {}
    transfers = Counter()
    for row in sorted(tables["workforce"], key=lambda item: item["WEEK_START"]):
        closing = (row["OPENING_HEADCOUNT"] + row["HIRES"] + row["TRANSFERS_IN"]
                   - row["SEPARATIONS"] - row["TRANSFERS_OUT"])
        require(closing == row["CLOSING_HEADCOUNT"], "Workforce stock/flow imbalance")
        key = (row["RESTAURANT_ID"], row["ROLE"])
        require(key not in previous or previous[key] == row["OPENING_HEADCOUNT"],
                "Workforce continuity mismatch")
        previous[key] = closing
        require(sum(row[column] for column in ("TENURE_UNDER_90_DAYS", "TENURE_90_TO_364_DAYS",
                                               "TENURE_365_PLUS_DAYS")) == closing,
                "Workforce tenure mismatch")
        transfers[(row["WEEK_START"], row["ROLE"])] += row["TRANSFERS_IN"] - row["TRANSFERS_OUT"]
    require(not any(transfers.values()), "Internal transfers do not reconcile")

    periods = [period for period in calendar if period["IS_COMPLETE"]][-8:]
    require(len(periods) == 8 and all(period["BASELINE_WEEK"] for period in periods),
            "Eight complete mapped weeks unavailable")
    indexed = {(row["RESTAURANT_ID"], row["WEEK_START"], row["DAYPART"], row["CHANNEL"]): row
               for row in performance}
    results = []
    for restaurant in roster.values():
        current, baseline, excluded = 0, 0, 0
        for period, daypart, channel in itertools.product(periods, dayparts, channels):
            current_row = indexed[(restaurant["RESTAURANT_ID"], period["WEEK_START"], daypart, channel)]
            baseline_row = indexed[(restaurant["RESTAURANT_ID"], period["BASELINE_WEEK"], daypart, channel)]
            if not current_row["IS_COMPLETE"] or not baseline_row["IS_COMPLETE"]:
                excluded += 1
            else:
                current += current_row["GUESTS"]
                baseline += baseline_row["GUESTS"]
        lifecycle = "Comparable"
        if restaurant["OPEN_DATE"] >= periods[-1]["WEEK_END_EXCLUSIVE"] or (
            restaurant["CLOSE_DATE"] and restaurant["CLOSE_DATE"] <= periods[0]["BASELINE_WEEK"]):
            lifecycle = "Outside comparison"
        elif restaurant["CLOSE_DATE"] and restaurant["CLOSE_DATE"] < periods[-1]["WEEK_END_EXCLUSIVE"]:
            lifecycle = "Closure"
        elif restaurant["OPEN_DATE"] > periods[0]["BASELINE_WEEK"]:
            lifecycle = "Opening"
        paired = len(periods) * len(dayparts) * len(channels) - excluded
        results.append({"restaurant_id": restaurant["RESTAURANT_ID"],
                        "restaurant": restaurant["RESTAURANT_NAME"], "lifecycle": lifecycle,
                        "current_guests": current if paired else None,
                        "baseline_guests": baseline if paired else None,
                        "guest_change": current - baseline if paired else None,
                        "paired_observations": paired, "excluded_pairs": excluded})
    changes = [row["guest_change"] for row in results if row["guest_change"] is not None]
    summary = {"net_guest_change": sum(changes),
               "gross_restaurant_loss": -sum(change for change in changes if change < 0),
               "offsetting_gains": sum(change for change in changes if change > 0),
               "excluded_pairs": sum(row["excluded_pairs"] for row in results),
               "without_closures": sum(row["guest_change"] for row in results
                                       if row["lifecycle"] != "Closure" and row["guest_change"] is not None)}
    return {"attribution": "Pair-programmed by SE Community + Cortex Code", "status": "passed",
            "release_id": manifest["releaseId"], "synthetic": True, "files": inventory,
            "window_start": periods[0]["WEEK_START"],
            "window_end_exclusive": periods[-1]["WEEK_END_EXCLUSIVE"],
            "baseline_start": periods[0]["BASELINE_WEEK"],
            "checks": ["checksums, byte sizes and row counts", "dictionary types, nullability and bounds",
                       "unique grains and foreign keys", "calendar continuity and baseline mappings",
                       "performance grid, null/completeness, lifecycle and availability",
                       "workforce stock/flow, continuity, tenure and internal transfers"],
            "limitations": ["Generator reproducibility not verified; retained fixture only",
                            "Ratings, reviews, operations and promotions: structural checks only",
                            "Guest changes use complete pairs; excluded pairs are not imputed"],
            "summary": summary, "restaurants": sorted(results, key=lambda row: (
                row["guest_change"] is None, row["guest_change"] or 0))}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("release", type=Path)
    parser.add_argument("--report", type=Path, required=True)
    arguments = parser.parse_args()
    report = validate_release(arguments.release.resolve())
    arguments.report.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"status": report["status"], "summary": report["summary"],
                      "dates": [report["window_start"], report["window_end_exclusive"]]}, indent=2))
