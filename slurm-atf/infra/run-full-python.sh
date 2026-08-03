#!/usr/bin/env bash
set -euo pipefail

results_root="${SLURM_ATF_RESULTS_ROOT:-/opt/slurm-atf/results}"
run_id="${SLURM_ATF_RUN_ID:-full-$(date -u +%Y%m%d-%H%M%S)}"
run_dir="${results_root}/${run_id}"
atf_root="${SLURM_ATF_ROOT:-/opt/slurm-atf}"
slurm_source="${SLURM_SUT_SOURCE_DIR:-${atf_root}/sut/src}"
slurm_install="${SLURM_SUT_INSTALL_DIR:-${atf_root}/install}"
tests_source="${SLURM_TESTS_SOURCE_DIR:-${atf_root}/tests/common}"

mkdir -p "${run_dir}"
exec 9>"/tmp/slurm-atf-python.lock"
if ! flock -n 9; then
	echo "Another Slurm Python ATF run already owns /tmp/slurm-atf-python.lock" >&2
	exit 75
fi

exec > >(tee -a "${run_dir}/pytest.out") 2>&1

echo "run_id=${run_id}"
echo "started_utc=$(date -u --iso-8601=seconds)"
echo "host=$(hostname -f)"
slurm_release_meta="$(awk '$1 == "Version:" {print $2; exit}' "${slurm_source}/META")"
echo "slurm_release_meta=${slurm_release_meta}"
echo "slurm_version=$(${slurm_install}/bin/sinfo --version)"
echo "tests_master_commit=$(jq -r '.tests.master_commit' \"${SLURM_RELEASE_MANIFEST}\" 2>/dev/null || echo unknown)"
echo "atf_profile=$(cat ${slurm_install}/etc/.atf-profile 2>/dev/null || echo unknown)"
echo "python_version=$(python3 --version 2>&1)"
echo "pytest_version=$(pytest --version)"
if command -v nvidia-smi >/dev/null 2>&1; then
	nvidia-smi --query-gpu=index,name,uuid,driver_version,memory.total \
		--format=csv,noheader >"${run_dir}/gpu-inventory.csv" || \
		printf '%s\n' "nvidia-smi present but no GPU inventory available" \
			>"${run_dir}/gpu-inventory.csv"
else
	printf '%s\n' "no NVIDIA driver on this VM" \
		>"${run_dir}/gpu-inventory.csv"
fi
env | sort >"${run_dir}/environment.txt"
dpkg-query -W -f='${binary:Package}\t${Version}\n' | sort \
	>"${run_dir}/package-inventory.tsv"

ulimit -c unlimited
cd "${tests_source}/testsuite/python"

set +e
./run-tests-python \
	--auto-config \
	-vv \
	-s \
	-ra \
	--tb=long \
	--durations=200 \
	--junitxml="${run_dir}/junit.xml" \
	"$@"
status=$?
set -e

mkdir -p "${run_dir}/daemon-logs" "${run_dir}/config"
if [[ -d /var/log/slurm-atf ]]; then
	find /var/log/slurm-atf -maxdepth 1 -type f -readable -exec \
		cp -p {} "${run_dir}/daemon-logs/" \;
fi
find "${slurm_install}/etc" -maxdepth 1 -type f -name '*.conf' -readable \
	-exec cp -p {} "${run_dir}/config/" \;
find "${slurm_install}/etc" -maxdepth 1 -type f -name '*.conf' -readable \
	-print0 | sort -z | xargs -0 sha256sum \
	>"${run_dir}/config.sha256" || true

echo "${status}" >"${run_dir}/exit-status"
echo "finished_utc=$(date -u --iso-8601=seconds)"
echo "exit_status=${status}"
exit "${status}"
