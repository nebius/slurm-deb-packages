from __future__ import annotations

import importlib.util
import json
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock


REPO_ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = Path(__file__).with_name("manifest.py")
SPEC = importlib.util.spec_from_file_location("slurm_atf_manifest", MODULE_PATH)
assert SPEC and SPEC.loader
manifest_module = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(manifest_module)


class ManifestTests(unittest.TestCase):
    def test_release_manifests_validate(self) -> None:
        paths = sorted((REPO_ROOT / "slurm-packages/releases").glob("*.json"))
        self.assertTrue(paths)
        for path in paths:
            with self.subTest(path=path):
                data = manifest_module.load_manifest(path, REPO_ROOT)
                self.assertEqual(data["release"]["version"], path.stem)

    def test_baseline_key_contains_empty_series_and_exact_release(self) -> None:
        manifest = REPO_ROOT / "slurm-packages/releases/26.05.2.json"
        result = manifest_module.build_key(
            manifest, REPO_ROOT, "image-1", "32vcpu-128gb", "x86_64", None
        )
        self.assertEqual(len(result["baseline_key"]), 64)
        self.assertEqual(result["payload"]["release"]["version"], "26.05.2")
        self.assertEqual(result["payload"]["product"]["patches"], [])
        self.assertEqual(result["payload"]["harness"]["patches"], [])

    def test_github_output_uses_manifest_values(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / "github-output"
            subprocess.run(
                [
                    "python3",
                    str(MODULE_PATH),
                    "github-output",
                    str(REPO_ROOT / "slurm-packages/releases/26.05.2.json"),
                    "--output",
                    str(output),
                ],
                cwd=REPO_ROOT,
                check=True,
            )
            values = dict(
                line.split("=", 1) for line in output.read_text().splitlines()
            )
            self.assertEqual(values["slurm_version"], "26.05.2")
            self.assertTrue(values["slurm_tarball_sha256"].startswith("01151f23"))

    def test_invalid_checksum_is_rejected(self) -> None:
        source = REPO_ROOT / "slurm-packages/releases/26.05.2.json"
        data = json.loads(source.read_text())
        data["release"]["tarball_sha256"] = "not-a-checksum"
        with mock.patch.object(Path, "read_text", return_value=json.dumps(data)):
            with self.assertRaises(manifest_module.ManifestError):
                manifest_module.load_manifest(source, REPO_ROOT)


if __name__ == "__main__":
    unittest.main()
