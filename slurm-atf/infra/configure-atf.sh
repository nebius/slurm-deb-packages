#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root=/opt/slurm-atf
slurm_source="${SLURM_SUT_SOURCE_DIR:-${root}/sut/src}"
slurm_build="${SLURM_SUT_BUILD_DIR:-${root}/sut/build}"
slurm_install="${SLURM_SUT_INSTALL_DIR:-${root}/install}"
tests_source="${SLURM_TESTS_SOURCE_DIR:-${root}/tests/common}"
controller_host="${SLURM_ATF_CONTROLLER_HOST:-$(hostname -s)}"
profile="${SLURM_ATF_PROFILE:-generic}"

case "${profile}" in
generic | b200) ;;
*)
	echo "Unsupported SLURM_ATF_PROFILE=${profile}; use generic or b200" >&2
	exit 2
	;;
esac

slurm_config="${script_dir}/config/slurm-${profile}.conf"
gres_config="${script_dir}/config/gres-${profile}.conf"
slurm_conf_tmp="$(mktemp)"
testsuite_conf_tmp="$(mktemp)"
profile_tmp="$(mktemp)"
trap 'rm -f "${slurm_conf_tmp}" "${testsuite_conf_tmp}" "${profile_tmp}"' EXIT

[[ -x "${tests_source}/testsuite/python/run-tests-python" ]] || {
	echo "Python tests snapshot is missing at ${tests_source}" >&2
	exit 2
}

sudo install -d -o slurm -g slurm -m 0755 "${slurm_install}/etc"
sudo install -d -o root -g root -m 0755 /etc/lmod/modules
sudo install -d -o slurm -g slurm -m 0775 \
	/run/slurm-atf \
	/var/lib/slurm-atf \
	/var/lib/slurm-atf/slurmctld \
	/var/lib/slurm-atf/slurmd \
	/var/log/slurm-atf
sudo install -d -o atf -g atf -m 0755 "${root}/results"

# This script is the reset boundary between validation runs. Stop only daemons
# from this isolated prefix, then remove their disposable runtime/state files.
# Multi-slurmd creates one persistent `slurmstepd infinity` systemd scope per
# logical node. An interrupted pytest run can bypass ATF teardown, and killing
# slurmd directly does not remove those orphaned scopes. Verify each scope's
# executable before stopping it so this reset never touches another Slurm.
while read -r stepd_scope _; do
	[[ "${stepd_scope}" =~ ^node[0-9]+_slurmstepd\.scope$ ]] || continue
	stepd_pid="$(sudo systemctl show -p MainPID --value "${stepd_scope}")"
	stepd_exe="$(sudo readlink -f "/proc/${stepd_pid}/exe" 2>/dev/null || true)"
	if [[ "${stepd_exe}" == "${slurm_install}/sbin/slurmstepd" ]]; then
		sudo systemctl stop "${stepd_scope}"
	fi
done < <(
	systemctl list-units --type=scope --state=running \
		'node*_slurmstepd.scope' --no-legend --no-pager
)

sudo pkill -TERM -f \
	"^${slurm_install}/sbin/(slurmctld|slurmdbd|slurmd|slurmstepd|slurmrestd)( |$)" \
	2>/dev/null || true
for _ in {1..50}; do
	if ! sudo pgrep -f \
		"^${slurm_install}/sbin/(slurmctld|slurmdbd|slurmd|slurmstepd|slurmrestd)( |$)" \
		>/dev/null; then
		break
	fi
	sleep 0.1
done
sudo find \
	/run/slurm-atf \
	/var/lib/slurm-atf/slurmctld \
	/var/lib/slurm-atf/slurmd \
	/var/log/slurm-atf \
	-mindepth 1 -delete

sed \
	-e "s|^SlurmctldHost=.*|SlurmctldHost=${controller_host}|" \
	"${slurm_config}" >"${slurm_conf_tmp}"
sed \
	-e "s|^SlurmSourceDir=.*|SlurmSourceDir=${slurm_source}|" \
	-e "s|^SlurmBuildDir=.*|SlurmBuildDir=${slurm_build}|" \
	-e "s|^SlurmInstallDir=.*|SlurmInstallDir=${slurm_install}|" \
	-e "s|^SlurmConfigDir=.*|SlurmConfigDir=${slurm_install}/etc|" \
	"${script_dir}/testsuite.conf" >"${testsuite_conf_tmp}"
cluster_name="$(
	awk -F= '$1 == "ClusterName" { print $2; exit }' \
		"${slurm_conf_tmp}"
)"

sudo install -o slurm -g slurm -m 0644 \
	"${slurm_conf_tmp}" "${slurm_install}/etc/slurm.conf"
sudo install -o slurm -g slurm -m 0600 \
	"${script_dir}/config/slurmdbd.conf" "${slurm_install}/etc/slurmdbd.conf"
for file in cgroup.conf plugstack.conf topology.conf; do
	sudo install -o slurm -g slurm -m 0644 \
		"${script_dir}/config/${file}" "${slurm_install}/etc/${file}"
done
sudo install -o slurm -g slurm -m 0644 \
	"${gres_config}" "${slurm_install}/etc/gres.conf"
printf '%s\n' "${profile}" >"${profile_tmp}"
sudo install -o root -g root -m 0644 \
	"${profile_tmp}" "${slurm_install}/etc/.atf-profile"

jwt_key_tmp="$(mktemp)"
openssl rand -out "${jwt_key_tmp}" 32
sudo install -o slurm -g slurm -m 0600 \
	"${jwt_key_tmp}" "${slurm_install}/etc/jwt_hs256.key"
rm -f "${jwt_key_tmp}"

# The reproducible profile may intentionally use a different cluster name
# from a previous run on this disposable VM.
sudo rm -f /var/lib/slurm-atf/slurmctld/clustername

sudo install -d -o slurm -g slurm -m 0755 "${slurm_install}/etc.orig"
sudo rsync -a --delete "${slurm_install}/etc/" "${slurm_install}/etc.orig/"

sudo install -o root -g root -m 0440 \
	"${script_dir}/system/slurm-atf-sudoers" /etc/sudoers.d/slurm-atf
sudo visudo -cf /etc/sudoers.d/slurm-atf
sudo install -o root -g root -m 0644 \
	"${script_dir}/system/99-slurm-atf.conf" /etc/ld.so.conf.d/99-slurm-atf.conf
sudo install -o root -g root -m 0644 \
	"${script_dir}/system/99-slurm-atf-sysctl.conf" /etc/sysctl.d/99-slurm-atf.conf
sudo install -o root -g root -m 0644 \
	"${script_dir}/system/99-slurm-atf-limits.conf" /etc/security/limits.d/99-slurm-atf.conf
sudo install -o root -g root -m 0644 \
	"${script_dir}/system/zz-slurm-atf-env.sh" /etc/profile.d/zz-slurm-atf-env.sh
sudo install -o root -g root -m 0644 \
	"${script_dir}/modules/openmpi.lua" /etc/lmod/modules/openmpi.lua
sudo install -o root -g root -m 0644 \
	"${script_dir}/modules/mpich.lua" /etc/lmod/modules/mpich.lua

sudo install -o root -g root -m 0755 \
	"${script_dir}/run-env.sh" "${root}/run-env.sh"
sudo install -o root -g root -m 0755 \
	"${script_dir}/run-full-python.sh" "${root}/run-full-python.sh"
sudo install -d -o root -g root -m 0755 "${root}/bin"
sudo install -o root -g root -m 0755 \
	"${script_dir}/bin/openapi-generator-cli" \
	"${root}/bin/openapi-generator-cli"
sudo install -o atf -g atf -m 0644 \
	"${testsuite_conf_tmp}" "${tests_source}/testsuite/testsuite.conf"

sudo "${root}/venv/bin/pip" install -r "${script_dir}/requirements.lock"

if ! command -v nvcc >/dev/null 2>&1 && [[ -x /usr/local/cuda/bin/nvcc ]]; then
	sudo ln -s /usr/local/cuda/bin/nvcc /usr/local/bin/nvcc
fi

sudo ldconfig
sudo sysctl --system

if [[ -e /etc/profile.d/modules.sh ]] &&
	grep -q "/usr/share/modules" /etc/profile.d/modules.sh &&
	[[ ! -d /usr/share/modules ]] &&
	[[ ! -e /etc/profile.d/modules.sh.disabled-by-slurm-atf ]]; then
	sudo mv /etc/profile.d/modules.sh \
		/etc/profile.d/modules.sh.disabled-by-slurm-atf
fi

sudo systemctl enable --now munge mariadb influxdb

# Recreate the disposable accounting database, not only the cluster record.
# `sacctmgr delete cluster` leaves historical job rows behind; recreating a
# cluster with the same name then lets later tests see duplicate JobIDs from a
# previous interrupted/full run. A validation reset must start with no history.
sudo mariadb <<'SQL'
DROP DATABASE IF EXISTS slurm_acct_db;
CREATE DATABASE slurm_acct_db;
SQL

sudo -u slurm -H env SLURM_TESTS_SOURCE_DIR="${tests_source}" \
	SLURM_SUT_INSTALL_DIR="${slurm_install}" \
	"${root}/run-env.sh" "${slurm_install}/sbin/slurmdbd"
sleep 2
# Every validation run must start from a clean accounting cluster. Several ATF
# modules intentionally add and remove the test user's associations; retaining
# a database from an earlier run makes later REST tests order-dependent.
sudo -H "${root}/run-env.sh" "${slurm_install}/bin/sacctmgr" -i \
	delete cluster "${cluster_name}" \
	>/dev/null 2>&1 || true
sudo -H "${root}/run-env.sh" "${slurm_install}/bin/sacctmgr" -i \
	add cluster "${cluster_name}" \
	>/dev/null 2>&1 || true
sudo -H "${root}/run-env.sh" "${slurm_install}/bin/sacctmgr" -i add account root \
	>/dev/null 2>&1 || true
sudo -H "${root}/run-env.sh" "${slurm_install}/bin/sacctmgr" -i add user atf \
	cluster="${cluster_name}" account=root defaultaccount=root adminlevel=Admin \
	>/dev/null 2>&1 || true
sudo -H "${root}/run-env.sh" "${slurm_install}/bin/sacctmgr" -i modify user \
	where name=atf set adminlevel=Admin defaultaccount=root \
	>/dev/null 2>&1 || true

# QOS records are global rather than cluster-scoped, so deleting and recreating
# the disposable cluster does not remove leftovers from an interrupted test.
# A clean reset keeps only Slurm's built-in normal QOS.
stale_qos_csv="$(
	sudo -H "${root}/run-env.sh" "${slurm_install}/bin/sacctmgr" -nP \
		show qos format=Name |
		awk -F'|' '$1 != "" && $1 != "normal" { print $1 }' |
		paste -sd, -
)"
if [[ -n "${stale_qos_csv}" ]]; then
	sudo -H "${root}/run-env.sh" "${slurm_install}/bin/sacctmgr" -i \
		delete qos "${stale_qos_csv}" >/dev/null 2>&1 || true
fi

if sudo test -s /run/slurm-atf/slurmdbd.pid; then
	dbd_pid="$(sudo cat /run/slurm-atf/slurmdbd.pid)"
	if [[ "$(ps -p "${dbd_pid}" -o comm= 2>/dev/null || true)" = slurmdbd ]]; then
		sudo kill "${dbd_pid}"
	fi
fi

echo "ATF configuration is installed."
echo "ATF profile: ${profile}"
echo "Run: sudo -u atf -H ${root}/run-env.sh bash -c \\"
echo "  'cd ${tests_source}/testsuite/python && ./run-tests-python --auto-config tests/test_103_1.py'"
