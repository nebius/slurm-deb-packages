# Slurm release ATF

This directory runs the Python and Expect ATF suite against a released Slurm
build. It is intentionally separate from the Debian package container build:
ATF needs the complete source and build trees plus an isolated installation
prefix, while package validation needs the actual `.deb` artifacts.

This infrastructure starts at Slurm `26.05.2`. The legacy Slurm 25.x package
workflow remains a native build without manifests, product patches or ATF.

The scripts are only for a disposable Ubuntu 24.04 VM. They install packages,
create local users, reset a local MariaDB database, change sysctls and start
test daemons. The GitHub workflow refuses to run unless the VM image contains
`/etc/slurm-atf-disposable`.

## Source model

Release manifests under `slurm-packages/releases/` are the source of truth.
They pin four independent identities:

- the official release tag and peeled commit;
- the official release tarball and SHA256;
- one exact master commit used only as the testsuite snapshot;
- the test snapshot archive and SHA256.

Master is never built as the product under test. On the VM the trees are:

```text
/opt/slurm-atf/sut/src       verified release tarball, optionally product-patched
/opt/slurm-atf/sut/build-*   out-of-tree build of that release
/opt/slurm-atf/install       isolated Slurm installation
/opt/slurm-atf/tests/master  pristine pinned master snapshot
/opt/slurm-atf/tests/common  snapshot plus common harness overlay
```

`testsuite.conf` lives in `tests/common`, but points all source, build, binary,
header and library lookups at the release SUT. This avoids accidentally testing
master binaries merely because Python tests only exist on master.

## Vanilla baseline now

The repository currently contains no product patches and no harness patches.
Every `baseline/series` and `harness/<version>/series` is deliberately empty.
The first complete run calibrates which master tests are compatible with each
release. Any later harness fix must be minimal, versioned and applied equally
to vanilla and candidate runs.

The `Slurm ATF vanilla baseline` workflow runs its control plane on a standard
GitHub-hosted Ubuntu runner. It authenticates with Nebius CLI, creates a fresh
Ubuntu 24.04 VM, derives a public SSH key from the private CI key and injects it
with cloud-init. The exact workflow checkout is copied to the VM and ATF runs
there over SSH. No self-hosted GitHub runner registration is needed.

The VM name is `slurm-atf-<github-run-id>-<attempt>`. It gets a dynamic public
IP and a managed boot disk; deleting the instance therefore deletes its disk as
well. Cleanup runs with `always()` after evidence collection. The workflow
input `keep_vm_on_failure=true` is the explicit exception for interactive SSH
debugging; a successful run is always deleted.

### GitHub environment configuration

The job uses the `e2e` GitHub environment and mirrors the Nebius CLI setup in
the soperator E2E workflow. Nebius CLI is pinned to `0.12.253` in the workflow.
Configure these environment or repository values:

| Kind | Name | Purpose |
| --- | --- | --- |
| Variable | `NEBIUS_CLI_CONFIG` | Complete Nebius CLI `config.yaml`, including all selectable profiles but no private key. |
| Secret | `NEBIUS_PRIVATE_KEY` | PEM private key for the service-account profile selected by the workflow. |
| Secret | `SLURM_ATF_SSH_PRIVATE_KEY` | Unencrypted OpenSSH private key used to reach the disposable VM. |
| Variable | `PROFILE_ENV_VAR` | Optional default name of the variable containing the ATF VM profile YAML. |
| Variable | for example `SLURM_ATF_PROFILE` | The actual VM profile shown below. |

The selected VM profile variable reuses soperator's `nebius_project_id` field
and adds a `slurm_atf` object:

```yaml
nebius_project_id: project-e00example
nebius_region: eu-north1
nebius_tenant_id: tenant-e00example
slurm_atf:
  image_id: computeimage-e00-immutable-ubuntu-2404
  subnet_id: vpcsubnet-e00example
  security_group_id: vpcsecuritygroup-e00example
  platform: cpu-d3
  preset: 32vcpu-128gb
  boot_disk_gib: 512
  boot_disk_type: network_ssd
  ssh_user: slurm-atf-ci
```

`image_id`, `subnet_id`, `platform` and `preset` are required. The image must
be an immutable Ubuntu 24.04 image. `boot_disk_gib`, `boot_disk_type` and
`ssh_user` default to `512`, `network_ssd` and `slurm-atf-ci`. The security
group is optional at the schema level; whichever group is effective must allow
TCP/22 from GitHub-hosted runners.

When dispatching the workflow:

- `profile_env_var` selects the GitHub variable containing the VM YAML; if it
  is empty, `vars.PROFILE_ENV_VAR` supplies the default variable name;
- `nebius_cli_profile` selects an existing profile inside
  `vars.NEBIUS_CLI_CONFIG`; the workflow injects `secrets.NEBIUS_PRIVATE_KEY`
  only into that profile and calls every cloud operation with `--profile`;
- `keep_vm_on_failure` defaults to `false`. If set, the job summary contains
  the VM ID, public IP and SSH command, and manual deletion becomes mandatory.

The Nebius service account needs permission to create, read and delete Compute
instances, their managed disks and dynamic public IP allocations in the
selected project.

Manual execution on a disposable VM is also possible:

```bash
sudo touch /etc/slurm-atf-disposable
export SLURM_RELEASE_MANIFEST="$PWD/slurm-packages/releases/26.05.2.json"
export SLURM_ATF_CI_OUTPUT="$PWD/atf-result"
export SLURM_ATF_VM_IMAGE_ID="ubuntu-24.04-immutable-id"
export SLURM_ATF_VM_SHAPE="32vcpu-128gb"
slurm-atf/ci/run-baseline.sh
```

The output includes JUnit, the complete pytest log, environment/GPU inventory,
the exact manifest and `baseline-key.json`. Pytest may return non-zero while a
baseline is being calibrated; the artifact is still produced because its exact
per-nodeid outcomes are the future comparison contract.

### Permanent baseline storage

The 30-day Actions artifact is diagnostic transport between jobs. The durable
comparison input is a dedicated GitHub Release whose tag is content-addressed:

```text
slurm-atf-baseline-26.05.2-<64-character-baseline-key>
```

The release contains the complete evidence archive, its SHA256 file and a
machine-readable publication descriptor:

```text
slurm-atf-baseline-26.05.2-<baseline-key>.tar.gz
slurm-atf-baseline-26.05.2-<baseline-key>.tar.gz.sha256
slurm-atf-baseline-26.05.2-<baseline-key>.json
```

The archive contains `junit.xml`, logs, inventory, the release manifest and
`baseline-key.json`. Baseline releases use `make_latest: false`, so they do not
replace the latest Debian package release. An existing tag is checked for the
complete asset set and is never overwritten. A different baseline identity
must be published under a new key.

Download a known baseline for a candidate comparison with GitHub CLI:

```bash
version=26.05.2
baseline_key='<64-character-baseline-key>'
tag="slurm-atf-baseline-${version}-${baseline_key}"
prefix="${tag}"

gh release download "${tag}" \
  --pattern "${prefix}.tar.gz" \
  --pattern "${prefix}.tar.gz.sha256" \
  --pattern "${prefix}.json" \
  --dir baseline-download

(cd baseline-download && sha256sum -c "${prefix}.tar.gz.sha256")
mkdir baseline-result
tar -xzf "baseline-download/${prefix}.tar.gz" -C baseline-result
```

## Adding the first two product patches later

Create one patchset instead of modifying baseline:

```text
slurm-packages/patches/26.05.2/nebius-v1/
  series
  0001-first-change.patch
  0002-second-change.patch
```

The same ordered series must feed the Debian Docker build and the ATF SUT.
Never put source-changing Slurm patches under `slurm-atf/harness/`.

Patch-specific regression tests are separate:

```text
slurm-atf/patch-tests/26.05.2/nebius-v1/
  series
  0001-add-regression-tests.patch
  nodeids.txt
```

Candidate validation will perform two runs after a clean reset:

1. common tests from exactly the same `tests/common` tree as vanilla, compared
   by pytest nodeid and outcome;
2. only `nodeids.txt` from a separate tests copy with patch-specific tests.

This keeps extra successful tests visible without inflating or changing the
common baseline count. A cached vanilla result is reusable only when its whole
baseline key matches (release, test snapshot, series checksums, infrastructure
commit, image, shape, architecture and profile). Any mismatch requires a fresh
paired vanilla/candidate run before calling it a Slurm regression.
