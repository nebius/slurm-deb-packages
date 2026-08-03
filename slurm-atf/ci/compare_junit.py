#!/usr/bin/env python3
"""Compare baseline and candidate pytest JUnit reports by testcase identity."""

from __future__ import annotations

import argparse
import json
import sys
import xml.etree.ElementTree as ET
from collections import Counter
from dataclasses import dataclass
from pathlib import Path


VALID_EXTRA_STATUSES = {"passed", "xfailed", "skipped"}


@dataclass(frozen=True)
class Case:
    nodeid: str
    status: str
    message: str


def _case_status(element: ET.Element) -> tuple[str, str]:
    error = element.find("error")
    if error is not None:
        return "error", error.get("message", "")

    failure = element.find("failure")
    if failure is not None:
        return "failed", failure.get("message", "")

    skipped = element.find("skipped")
    if skipped is not None:
        skip_type = skipped.get("type", "")
        status = "xfailed" if skip_type == "pytest.xfail" else "skipped"
        return status, skipped.get("message", "")

    return "passed", ""


def load_report(path: Path) -> dict[str, Case]:
    try:
        root = ET.parse(path).getroot()
    except (OSError, ET.ParseError) as exc:
        raise ValueError(f"cannot read JUnit report {path}: {exc}") from exc

    cases: dict[str, Case] = {}
    for element in root.iter("testcase"):
        file_name = element.get("file")
        if not file_name:
            classname = element.get("classname", "unknown")
            file_name = f"{classname.replace('.', '/')}.py"
        name = element.get("name", "unnamed")
        module_name = file_name.removesuffix(".py").replace("/", ".")
        classname = element.get("classname", "")
        class_path = ""
        if classname.startswith(f"{module_name}."):
            class_path = classname[len(module_name) + 1 :].replace(".", "::")
        nodeid_parts = [file_name]
        if class_path:
            nodeid_parts.append(class_path)
        nodeid_parts.append(name)
        nodeid = "::".join(nodeid_parts)
        if nodeid in cases:
            raise ValueError(f"duplicate testcase identity in {path}: {nodeid}")
        status, message = _case_status(element)
        cases[nodeid] = Case(nodeid=nodeid, status=status, message=message)

    if not cases:
        raise ValueError(f"JUnit report contains no testcases: {path}")
    return cases


def compare(
    baseline: dict[str, Case],
    candidate: dict[str, Case],
    extra_ok: set[str],
) -> dict[str, object]:
    baseline_ids = set(baseline)
    candidate_ids = set(candidate)
    common_ids = baseline_ids & candidate_ids

    changed = [
        {
            "nodeid": nodeid,
            "baseline": baseline[nodeid].status,
            "candidate": candidate[nodeid].status,
        }
        for nodeid in sorted(common_ids)
        if baseline[nodeid].status != candidate[nodeid].status
    ]
    baseline_only = sorted(baseline_ids - candidate_ids)
    candidate_only = sorted(candidate_ids - baseline_ids)
    candidate_only_bad = [
        {
            "nodeid": nodeid,
            "status": candidate[nodeid].status,
        }
        for nodeid in candidate_only
        if candidate[nodeid].status not in extra_ok
    ]

    baseline_counts = Counter(case.status for case in baseline.values())
    candidate_counts = Counter(case.status for case in candidate.values())
    ok = not changed and not baseline_only and not candidate_only_bad

    return {
        "ok": ok,
        "baseline_total": len(baseline),
        "candidate_total": len(candidate),
        "common_total": len(common_ids),
        "baseline_counts": dict(sorted(baseline_counts.items())),
        "candidate_counts": dict(sorted(candidate_counts.items())),
        "changed": changed,
        "baseline_only": baseline_only,
        "candidate_only": [
            {"nodeid": nodeid, "status": candidate[nodeid].status}
            for nodeid in candidate_only
        ],
        "candidate_only_bad": candidate_only_bad,
        "candidate_extra_allowed_statuses": sorted(extra_ok),
    }


def _table_counts(result: dict[str, object]) -> list[str]:
    statuses = ["passed", "skipped", "xfailed", "failed", "error"]
    baseline_counts = result["baseline_counts"]
    candidate_counts = result["candidate_counts"]
    assert isinstance(baseline_counts, dict)
    assert isinstance(candidate_counts, dict)
    lines = ["| Variant | " + " | ".join(statuses) + " | Total |", "|---|---:|---:|---:|---:|---:|---:|"]
    for label, counts, total in (
        ("baseline", baseline_counts, result["baseline_total"]),
        ("candidate", candidate_counts, result["candidate_total"]),
    ):
        values = [str(counts.get(status, 0)) for status in statuses]
        lines.append(f"| {label} | " + " | ".join(values) + f" | {total} |")
    return lines


def render_markdown(result: dict[str, object]) -> str:
    verdict = "PASS" if result["ok"] else "FAIL"
    lines = [
        f"# Slurm ATF A/B comparison: {verdict}",
        "",
        *_table_counts(result),
        "",
        f"Common testcases: **{result['common_total']}**.",
    ]

    changed = result["changed"]
    assert isinstance(changed, list)
    lines.extend(["", f"## Changed common outcomes ({len(changed)})", ""])
    if changed:
        lines.extend(["| Test | Baseline | Candidate |", "|---|---|---|"])
        for item in changed:
            lines.append(
                f"| `{item['nodeid']}` | {item['baseline']} | {item['candidate']} |"
            )
    else:
        lines.append("None.")

    baseline_only = result["baseline_only"]
    assert isinstance(baseline_only, list)
    lines.extend(["", f"## Missing from candidate ({len(baseline_only)})", ""])
    if baseline_only:
        lines.extend(f"- `{nodeid}`" for nodeid in baseline_only)
    else:
        lines.append("None.")

    candidate_only = result["candidate_only"]
    assert isinstance(candidate_only, list)
    lines.extend(["", f"## Candidate-only tests ({len(candidate_only)})", ""])
    if candidate_only:
        lines.extend(
            f"- `{item['nodeid']}`: **{item['status']}**" for item in candidate_only
        )
    else:
        lines.append("None.")

    bad = result["candidate_only_bad"]
    assert isinstance(bad, list)
    if bad:
        allowed = ", ".join(result["candidate_extra_allowed_statuses"])
        lines.extend(
            [
                "",
                f"Candidate-only tests must have one of: `{allowed}`; "
                f"{len(bad)} did not.",
            ]
        )
    return "\n".join(lines) + "\n"


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Require identical outcomes for all common tests, no tests removed "
            "from candidate, and successful candidate-only tests."
        )
    )
    parser.add_argument("baseline", type=Path)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("--json-output", type=Path)
    parser.add_argument("--markdown-output", type=Path)
    parser.add_argument(
        "--candidate-extra-ok",
        default="passed",
        help="comma-separated statuses accepted for candidate-only tests (default: passed)",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    extra_ok = {value.strip() for value in args.candidate_extra_ok.split(",") if value.strip()}
    unknown = extra_ok - VALID_EXTRA_STATUSES
    if unknown or not extra_ok:
        print(
            "invalid --candidate-extra-ok; choose from "
            + ", ".join(sorted(VALID_EXTRA_STATUSES)),
            file=sys.stderr,
        )
        return 2

    try:
        result = compare(load_report(args.baseline), load_report(args.candidate), extra_ok)
    except ValueError as exc:
        print(exc, file=sys.stderr)
        return 2

    markdown = render_markdown(result)
    print(markdown, end="")
    if args.markdown_output:
        args.markdown_output.write_text(markdown, encoding="utf-8")
    if args.json_output:
        args.json_output.write_text(
            json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
