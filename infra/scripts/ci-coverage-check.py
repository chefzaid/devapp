#!/usr/bin/env python3
"""Create a non-blocking JUnit result for the repository-wide line coverage policy."""

from __future__ import annotations

import os
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


def local_name(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def coverage_counts(report: Path) -> tuple[int, int]:
    root = ET.parse(report).getroot()
    tag = local_name(root.tag)

    if tag == "report":
        for counter in root:
            if local_name(counter.tag) == "counter" and counter.get("type") == "LINE":
                covered = int(counter.get("covered", "0"))
                missed = int(counter.get("missed", "0"))
                return covered, covered + missed

    if tag == "coverage":
        covered_value = root.get("lines-covered")
        valid_value = root.get("lines-valid")
        if covered_value is not None and valid_value is not None:
            return int(float(covered_value)), int(float(valid_value))

        line_rate = root.get("line-rate")
        if line_rate is not None:
            return round(float(line_rate) * 10_000), 10_000

    raise ValueError(f"unsupported coverage XML format: {tag}")


def write_result(
    output: Path,
    minimum: float,
    percentage: float,
    details: list[str],
    errors: list[str],
) -> bool:
    passed = not errors and percentage >= minimum
    suite = ET.Element(
        "testsuite",
        {
            "name": "coverage-policy",
            "tests": "1",
            "failures": "0" if passed else "1",
            "errors": "0",
        },
    )
    case = ET.SubElement(
        suite,
        "testcase",
        {
            "classname": "unit-tests",
            "name": f"combined line coverage is at least {minimum:.0f}%",
        },
    )
    summary = (
        f"Combined line coverage: {percentage:.2f}% (required: {minimum:.2f}%). "
        + "; ".join(details + errors)
    )
    ET.SubElement(case, "system-out").text = summary
    if not passed:
        ET.SubElement(case, "failure", {"message": summary}).text = summary
    ET.ElementTree(suite).write(output, encoding="utf-8", xml_declaration=True)
    return passed


def main() -> int:
    minimum = float(os.environ.get("COVERAGE_MINIMUM", "80"))
    output = Path("coverage-policy-junit.xml")
    reports = [Path(argument) for argument in sys.argv[1:]]
    details: list[str] = []
    errors: list[str] = []
    covered_total = 0
    line_total = 0

    if not reports:
        errors.append("no coverage reports were provided")

    for report in reports:
        try:
            covered, lines = coverage_counts(report)
            if lines <= 0:
                raise ValueError("report contains no coverable lines")
            covered_total += covered
            line_total += lines
            details.append(f"{report}: {covered * 100 / lines:.2f}%")
        except (OSError, ET.ParseError, ValueError) as error:
            errors.append(f"{report}: {error}")

    percentage = covered_total * 100 / line_total if line_total else 0.0
    passed = write_result(output, minimum, percentage, details, errors)
    status = "passed" if passed else "failed"
    Path("coverage-policy.env").write_text(
        f"COVERAGE_POLICY_STATUS={status}\nTOTAL_LINE_COVERAGE={percentage:.2f}\n",
        encoding="utf-8",
    )
    print(f"TOTAL_COVERAGE={percentage:.2f}%")
    for detail in details:
        print(detail)
    for error in errors:
        print(f"coverage report error: {error}", file=sys.stderr)
    if not passed:
        print(
            f"Coverage policy failed: {percentage:.2f}% is below {minimum:.2f}%. "
            "The failed JUnit policy check is reported by the optional test job.",
            file=sys.stderr,
        )
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
