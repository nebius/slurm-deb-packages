#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../.." && pwd)"
infra_dir="${repo_root}/slurm-atf/infra"
manifest="${SLURM_RELEASE_MANIFEST:?set SLURM_RELEASE_MANIFEST}"
output_dir="${SLURM_ATF_CI_OUTPUT:?set SLURM_ATF_CI_OUTPUT}"
atf_root="${SLURM_ATF_ROOT:-/opt/slurm-atf}"
run_id="${SLURM_ATF_RUN_ID:-baseline-$(date -u +%Y%m%d-%H%M%S)}"
vm_image="${SLURM_ATF_VM_IMAGE_ID:-unknown}"
vm_shape="${SLURM_ATF_VM_SHAPE:-unknown}"

manifest="$(realpath "${manifest}")"
mkdir -p "${output_dir}"

"${infra_dir}/bootstrap-deps.sh"
"${script_dir}/prepare-sources.sh" "${manifest}" baseline

version="$(jq -r '.release.version' "${manifest}")"
sut_source="${atf_root}/sut/src"
sut_build="${atf_root}/sut/build-${version}"
sut_install="${atf_root}/install"
tests_source="${atf_root}/tests/common"

sudo install -d -o root -g root -m 0755 "${atf_root}/repro"
sudo rsync -a --delete "${repo_root}/slurm-atf/" "${atf_root}/repro/slurm-atf/"
sudo chown -R atf:atf "${atf_root}/sut" "${atf_root}/tests" \
	"${atf_root}/build" "${atf_root}/src"

sudo -u atf -H env \
	SLURM_SUT_SOURCE_DIR="${sut_source}" \
	SLURM_SUT_BUILD_DIR="${sut_build}" \
	SLURM_SUT_INSTALL_DIR="${sut_install}" \
	BUILD_JOBS="${BUILD_JOBS:-$(nproc)}" \
	"${infra_dir}/build-stack.sh"

sudo -u atf -H env \
	SLURM_SUT_SOURCE_DIR="${sut_source}" \
	SLURM_SUT_BUILD_DIR="${sut_build}" \
	SLURM_SUT_INSTALL_DIR="${sut_install}" \
	SLURM_TESTS_SOURCE_DIR="${tests_source}" \
	SLURM_ATF_PROFILE="$(jq -r '.atf.profile' "${manifest}")" \
	"${infra_dir}/configure-atf.sh"

set +e
sudo -u atf -H env \
	SLURM_SUT_SOURCE_DIR="${sut_source}" \
	SLURM_SUT_BUILD_DIR="${sut_build}" \
	SLURM_SUT_INSTALL_DIR="${sut_install}" \
	SLURM_TESTS_SOURCE_DIR="${tests_source}" \
	SLURM_RELEASE_MANIFEST="${manifest}" \
	SLURM_ATF_RUN_ID="${run_id}" \
	"${atf_root}/run-env.sh" "${atf_root}/run-full-python.sh"
pytest_status=$?
set -e

run_dir="${atf_root}/results/${run_id}"
[[ -s "${run_dir}/junit.xml" ]] || {
	echo "ATF did not produce ${run_dir}/junit.xml" >&2
	exit 1
}

key_tmp="$(mktemp)"
trap 'rm -f "${key_tmp}"' EXIT
python3 "${script_dir}/manifest.py" --repo-root "${repo_root}" \
	baseline-key "${manifest}" \
	--output "${key_tmp}" \
	--vm-image "${vm_image}" \
	--vm-shape "${vm_shape}" \
	--architecture "$(uname -m)" \
	--package-inventory "${run_dir}/package-inventory.tsv" |
	sudo -u atf tee "${run_dir}/baseline-key" >/dev/null
sudo install -o atf -g atf -m 0644 \
	"${key_tmp}" "${run_dir}/baseline-key.json"
sudo install -o atf -g atf -m 0644 \
	"${manifest}" "${run_dir}/release-manifest.json"
printf '%s\n' "${pytest_status}" |
	sudo -u atf tee "${run_dir}/pytest-exit-status" >/dev/null
sudo rsync -a "${run_dir}/" "${output_dir}/"
sudo chown -R "$(id -u):$(id -g)" "${output_dir}"

echo "Baseline artifact created with pytest status ${pytest_status}."
# Baselines may retain upstream failures. Their exact testcase outcomes are the
# comparison contract, so existence and integrity of JUnit are the job gate.
