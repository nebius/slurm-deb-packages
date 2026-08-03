#!/usr/bin/env python3
"""Validate Slurm release manifests and create reproducible baseline keys."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import platform
import re
import subprocess
import sys
from pathlib import Path
from typing import Any, Optional


SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
COMMIT_RE = re.compile(r"^[0-9a-f]{40}$")
VERSION_RE = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+$")


class ManifestError(ValueError):
    pass


def load_manifest(path: Path, repo_root: Path) -> dict[str, Any]:
    path = path.resolve()
    repo_root = repo_root.resolve()
    try:
        relative_manifest = path.relative_to(repo_root)
    except ValueError as exc:
        raise ManifestError(f"manifest must be inside repository: {path}") from exc
    if relative_manifest.parts[:2] != ("slurm-packages", "releases"):
        raise ManifestError(
            "manifest must be stored below slurm-packages/releases"
        )
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ManifestError(f"cannot read {path}: {exc}") from exc

    if data.get("schema") != 1:
        raise ManifestError("manifest schema must be 1")

    required = {
        "release": (
            "version",
            "tag",
            "tag_object",
            "commit",
            "tarball_url",
            "tarball_sha256",
        ),
        "tests": (
            "repository",
            "master_commit",
            "snapshot_url",
            "snapshot_sha256",
            "harness_series",
        ),
        "product": ("baseline_series",),
        "atf": (
            "profile",
            "layout_version",
            "pmix_tag",
            "pmix_commit",
            "openmpi_tag",
            "openmpi_commit",
            "mpich_version",
            "mpich_sha256",
        ),
    }
    for section, keys in required.items():
        value = data.get(section)
        if not isinstance(value, dict):
            raise ManifestError(f"missing object: {section}")
        for key in keys:
            if value.get(key) in (None, ""):
                raise ManifestError(f"missing value: {section}.{key}")

    release = data["release"]
    tests = data["tests"]
    if not VERSION_RE.fullmatch(release["version"]):
        raise ManifestError("release.version must be MAJOR.MINOR.MICRO")
    for name in ("tag_object", "commit"):
        if not COMMIT_RE.fullmatch(release[name]):
            raise ManifestError(f"release.{name} must be a 40-character SHA")
    if not COMMIT_RE.fullmatch(tests["master_commit"]):
        raise ManifestError("tests.master_commit must be a 40-character SHA")
    for name in ("pmix_commit", "openmpi_commit"):
        if not COMMIT_RE.fullmatch(data["atf"][name]):
            raise ManifestError(f"atf.{name} must be a 40-character SHA")
    for section, name in (
        (release, "tarball_sha256"),
        (tests, "snapshot_sha256"),
        (data["atf"], "mpich_sha256"),
    ):
        if not SHA256_RE.fullmatch(section[name]):
            raise ManifestError(f"{name} must be a lowercase SHA256")
    expected_tag = "slurm-" + release["version"].replace(".", "-") + "-1"
    if release["tag"] != expected_tag:
        raise ManifestError(f"release.tag must be {expected_tag}")
    if tests["master_commit"] not in tests["snapshot_url"]:
        raise ManifestError("tests.snapshot_url must contain tests.master_commit")
    for url_name, url in (
        ("release.tarball_url", release["tarball_url"]),
        ("tests.snapshot_url", tests["snapshot_url"]),
    ):
        if not isinstance(url, str) or not url.startswith("https://"):
            raise ManifestError(f"{url_name} must use https")

    for key in (tests["harness_series"], data["product"]["baseline_series"]):
        path_value = Path(key)
        if path_value.is_absolute() or ".." in path_value.parts:
            raise ManifestError(f"series path must stay inside repository: {key}")
        if not (repo_root / path_value).is_file():
            raise ManifestError(f"series file does not exist: {key}")
    return data


def series_fingerprint(repo_root: Path, relative_series: str) -> dict[str, Any]:
    series_path = repo_root / relative_series
    patches: list[dict[str, str]] = []
    for raw_line in series_path.read_text(encoding="utf-8").splitlines():
        entry = raw_line.partition("#")[0].strip()
        if not entry:
            continue
        if Path(entry).name != entry or entry.startswith("."):
            raise ManifestError(f"invalid patch basename in {relative_series}: {entry}")
        patch_path = series_path.parent / entry
        if not patch_path.is_file():
            raise ManifestError(f"missing patch in {relative_series}: {entry}")
        patches.append(
            {
                "name": entry,
                "sha256": hashlib.sha256(patch_path.read_bytes()).hexdigest(),
            }
        )
    return {
        "series": relative_series,
        "series_sha256": hashlib.sha256(series_path.read_bytes()).hexdigest(),
        "patches": patches,
    }


def repo_commit(repo_root: Path) -> str:
    try:
        return subprocess.check_output(
            ["git", "-C", str(repo_root), "rev-parse", "HEAD"], text=True
        ).strip()
    except (OSError, subprocess.CalledProcessError) as exc:
        raise ManifestError(f"cannot resolve infrastructure commit: {exc}") from exc


def build_key(
    manifest_path: Path,
    repo_root: Path,
    vm_image: str,
    vm_shape: str,
    architecture: str,
    package_inventory: Optional[Path] = None,
) -> dict[str, Any]:
    manifest = load_manifest(manifest_path, repo_root)
    payload = {
        "schema": 1,
        "manifest_sha256": hashlib.sha256(manifest_path.read_bytes()).hexdigest(),
        "release": manifest["release"],
        "tests": {
            key: manifest["tests"][key]
            for key in (
                "repository",
                "master_commit",
                "snapshot_url",
                "snapshot_sha256",
            )
        },
        "product": series_fingerprint(
            repo_root, manifest["product"]["baseline_series"]
        ),
        "harness": series_fingerprint(
            repo_root, manifest["tests"]["harness_series"]
        ),
        "atf": {
            **manifest["atf"],
            "infra_commit": repo_commit(repo_root),
            "vm_image": vm_image,
            "vm_shape": vm_shape,
            "architecture": architecture,
            "os": platform.platform(),
            "package_inventory_sha256": (
                hashlib.sha256(package_inventory.read_bytes()).hexdigest()
                if package_inventory
                else "not-provided"
            ),
        },
    }
    canonical = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode()
    return {
        "baseline_key": hashlib.sha256(canonical).hexdigest(),
        "payload": payload,
    }


def command_validate(args: argparse.Namespace) -> int:
    data = load_manifest(args.manifest.resolve(), args.repo_root.resolve())
    print(json.dumps(data, indent=2, sort_keys=True))
    return 0


def command_github_output(args: argparse.Namespace) -> int:
    data = load_manifest(args.manifest.resolve(), args.repo_root.resolve())
    values = {
        "slurm_version": data["release"]["version"],
        "slurm_tarball_url": data["release"]["tarball_url"],
        "slurm_tarball_sha256": data["release"]["tarball_sha256"],
        "tests_commit": data["tests"]["master_commit"],
    }
    destination = args.output or Path(os.environ["GITHUB_OUTPUT"])
    with destination.open("a", encoding="utf-8") as stream:
        for key, value in values.items():
            if "\n" in value:
                raise ManifestError(f"newline is not allowed in output {key}")
            stream.write(f"{key}={value}\n")
    return 0


def command_key(args: argparse.Namespace) -> int:
    result = build_key(
        args.manifest.resolve(),
        args.repo_root.resolve(),
        args.vm_image,
        args.vm_shape,
        args.architecture,
        args.package_inventory,
    )
    args.output.write_text(
        json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    print(result["baseline_key"])
    return 0


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--repo-root", type=Path, default=Path(__file__).resolve().parents[2]
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    validate = subparsers.add_parser("validate")
    validate.add_argument("manifest", type=Path)
    validate.set_defaults(handler=command_validate)

    github = subparsers.add_parser("github-output")
    github.add_argument("manifest", type=Path)
    github.add_argument("--output", type=Path)
    github.set_defaults(handler=command_github_output)

    key = subparsers.add_parser("baseline-key")
    key.add_argument("manifest", type=Path)
    key.add_argument("--output", type=Path, required=True)
    key.add_argument("--vm-image", required=True)
    key.add_argument("--vm-shape", required=True)
    key.add_argument("--architecture", default=platform.machine())
    key.add_argument("--package-inventory", type=Path)
    key.set_defaults(handler=command_key)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    try:
        return args.handler(args)
    except (ManifestError, KeyError, OSError) as exc:
        print(exc, file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
