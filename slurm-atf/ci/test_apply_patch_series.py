from __future__ import annotations

import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
APPLY_SERIES = REPO_ROOT / "slurm-packages/apply-patch-series.sh"


class ApplyPatchSeriesTests(unittest.TestCase):
    def test_empty_baseline_series_changes_nothing(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / "source"
            source.mkdir()
            original = source / "value.txt"
            original.write_text("vanilla\n")
            series = root / "series"
            series.write_text("# no product patches\n")
            record = root / "record"

            subprocess.run(
                [str(APPLY_SERIES), str(source), str(series), str(record)],
                check=True,
            )

            self.assertEqual(original.read_text(), "vanilla\n")
            self.assertEqual(record.read_text(), "")

    def test_ordered_series_is_applied_and_fingerprinted(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / "source"
            source.mkdir()
            (source / "value.txt").write_text("before\n")
            patch = root / "0001-change.patch"
            patch.write_text(
                "diff --git a/value.txt b/value.txt\n"
                "index 90be1f3..2ee42b1 100644\n"
                "--- a/value.txt\n"
                "+++ b/value.txt\n"
                "@@ -1 +1 @@\n"
                "-before\n"
                "+after\n"
            )
            series = root / "series"
            series.write_text("0001-change.patch\n")
            record = root / "record"

            subprocess.run(
                [str(APPLY_SERIES), str(source), str(series), str(record)],
                check=True,
            )

            self.assertEqual((source / "value.txt").read_text(), "after\n")
            self.assertIn("0001-change.patch", record.read_text())


if __name__ == "__main__":
    unittest.main()
