# Updating a Slurm release pin

One JSON file describes both package source identity and the ATF tests source.
Never use `*-latest.tar.bz2` in CI.

For a new release:

1. Copy the nearest manifest to `<version>.json`.
2. Read the release tarball SHA256 from
   `https://download.schedmd.com/slurm/SHA256` and verify the downloaded file.
3. Resolve both the annotated tag object and its peeled commit:

   ```bash
   git ls-remote https://github.com/SchedMD/slurm.git \
     "refs/tags/slurm-26-05-2-1" \
     "refs/tags/slurm-26-05-2-1^{}"
   ```

4. Pin one explicit master commit for Python/Expect tests. Download its archive
   once, calculate SHA256 and record both values; never record the moving word
   `master` as the test identity.
5. Add empty `baseline/series` and `harness/<version>/series` files. Product
   patches must not be copied into either baseline series.
6. Validate all manifests and unit tests:

   ```bash
   for manifest in slurm-packages/releases/*.json; do
     python3 slurm-atf/ci/manifest.py validate "$manifest" >/dev/null
   done
   PYTHONPATH=slurm-atf/ci python3 -m unittest \
     slurm-atf/ci/test_manifest.py \
     slurm-atf/ci/test_apply_patch_series.py \
     slurm-atf/ci/test_compare_junit.py
   ```

This repository starts its manifest history at Slurm `26.05.2`; do not add
25.x manifests or baseline directories. Slurm 25.x continues to use the
unchanged legacy `slurm_packages.yml` plus `slurm-packages/Dockerfile` build
path, which deliberately has no manifest, patch or ATF dependency. Updating
the 26.x package workflow matrix for a later release remains a separate,
visible change.
