#!/usr/bin/env python3

import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

import compare_junit


class CompareJunitTests(unittest.TestCase):
    def write_report(self, directory: Path, name: str, cases: list[tuple[str, str]]) -> Path:
        root = ET.Element("testsuites")
        suite = ET.SubElement(root, "testsuite")
        for nodeid, status in cases:
            file_name, test_name = nodeid.split("::", 1)
            testcase = ET.SubElement(
                suite,
                "testcase",
                {"file": file_name, "classname": file_name.removesuffix(".py").replace("/", "."), "name": test_name},
            )
            if status == "failed":
                ET.SubElement(testcase, "failure", {"message": "failed"})
            elif status == "error":
                ET.SubElement(testcase, "error", {"message": "error"})
            elif status == "skipped":
                ET.SubElement(testcase, "skipped", {"type": "pytest.skip", "message": "skip"})
            elif status == "xfailed":
                ET.SubElement(testcase, "skipped", {"type": "pytest.xfail", "message": "xfail"})
        path = directory / name
        ET.ElementTree(root).write(path, encoding="utf-8", xml_declaration=True)
        return path

    def test_identical_common_and_passing_candidate_extra_are_accepted(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            baseline_path = self.write_report(
                directory,
                "baseline.xml",
                [("tests/test_a.py::test_pass", "passed"), ("tests/test_a.py::test_known", "failed")],
            )
            candidate_path = self.write_report(
                directory,
                "candidate.xml",
                [
                    ("tests/test_a.py::test_pass", "passed"),
                    ("tests/test_a.py::test_known", "failed"),
                    ("tests/test_patch.py::test_regression", "passed"),
                ],
            )
            result = compare_junit.compare(
                compare_junit.load_report(baseline_path),
                compare_junit.load_report(candidate_path),
                {"passed"},
            )
            self.assertTrue(result["ok"])
            self.assertEqual(len(result["candidate_only"]), 1)

    def test_changed_common_outcome_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            baseline = self.write_report(directory, "baseline.xml", [("tests/test_a.py::test_a", "passed")])
            candidate = self.write_report(directory, "candidate.xml", [("tests/test_a.py::test_a", "failed")])
            result = compare_junit.compare(
                compare_junit.load_report(baseline),
                compare_junit.load_report(candidate),
                {"passed"},
            )
            self.assertFalse(result["ok"])
            self.assertEqual(len(result["changed"]), 1)

    def test_removed_test_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            baseline = self.write_report(directory, "baseline.xml", [("tests/test_a.py::test_a", "passed")])
            candidate = self.write_report(directory, "candidate.xml", [("tests/test_b.py::test_b", "passed")])
            result = compare_junit.compare(
                compare_junit.load_report(baseline),
                compare_junit.load_report(candidate),
                {"passed"},
            )
            self.assertFalse(result["ok"])
            self.assertEqual(result["baseline_only"], ["tests/test_a.py::test_a"])

    def test_skipped_candidate_extra_requires_explicit_opt_in(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            baseline = self.write_report(directory, "baseline.xml", [("tests/test_a.py::test_a", "passed")])
            candidate = self.write_report(
                directory,
                "candidate.xml",
                [("tests/test_a.py::test_a", "passed"), ("tests/test_patch.py::test_new", "skipped")],
            )
            baseline_report = compare_junit.load_report(baseline)
            candidate_report = compare_junit.load_report(candidate)
            self.assertFalse(compare_junit.compare(baseline_report, candidate_report, {"passed"})["ok"])
            self.assertTrue(
                compare_junit.compare(baseline_report, candidate_report, {"passed", "skipped"})["ok"]
            )


if __name__ == "__main__":
    unittest.main()
