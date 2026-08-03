# Slurm product patch series

This mechanism is only used by the Slurm 26.x package and ATF workflows. The
legacy 25.x package build remains native and never reads this directory.

Every Slurm source variant has an explicit series under:

```text
slurm-packages/patches/<release>/<patchset>/series
```

`baseline/series` must remain empty. A future Nebius patch set should use its
own immutable identifier, for example `nebius-v1`, and list patches in the
exact order in which they are applied:

```text
0001-first-product-change.patch
0002-second-product-change.patch
```

Patch filenames are basenames; comments and blank lines are ignored. The same
series is used for both the Debian package source and the ATF SUT source. Test
harness compatibility changes do not belong here; they live under
`slurm-atf/harness/`. Tests introduced specifically for a product patch live
under `slurm-atf/patch-tests/` and are counted separately from common A/B
comparison.

A product patch set must also bump the Debian package revision in
`debian/changelog`; otherwise vanilla and patched packages have the same dpkg
version and cannot be compared or upgraded safely.
