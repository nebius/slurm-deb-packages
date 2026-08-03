#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
	acl autoconf automake bash-completion bc bison build-essential check \
	curl dejagnu elfutils expect file flex gdb git hdf5-helpers hdf5-tools hwloc jq \
	influxdb influxdb-client libbpf-dev libcurl4-openssl-dev libdbus-1-dev libevent-dev \
	libfreeipmi-dev libhdf5-dev libhttp-parser-dev libhwloc-dev \
	libgtk2.0-dev libipmimonitoring-dev libjson-c-dev libjwt-dev \
	liblua5.3-dev liblz4-dev libmariadb-dev libmount-dev libmunge-dev \
	libncurses-dev libnuma-dev libpam0g-dev libperl-dev librdkafka-dev \
	libreadline-dev librrd-dev libssl-dev libsubunit-dev libsystemd-dev \
	libtool libyaml-dev libzstd-dev lmod lsof man2html-base \
	mariadb-client mariadb-server munge netcat-openbsd numactl \
	openjdk-17-jre-headless parallel perl-doc libswitch-perl pkg-config procps psmisc \
	python3-dev python3-venv ripgrep rsync socat strace sudo tcl tcl-dev \
	tree unzip valgrind wget zip

# NVIDIA GPU images can pin every libxnvctrl0 version below zero to protect
# the driver stack.  Ubuntu's MPICH pulls it indirectly through hwloc/PMIx.
# Select the userspace library matching the active driver explicitly.
xnvctrl_candidate="$(
	apt-cache policy libxnvctrl0 |
		awk '/Candidate:/ {print $2; exit}'
)"
if [[ "${xnvctrl_candidate}" == "(none)" ]] &&
	command -v nvidia-smi >/dev/null 2>&1; then
	gpu_driver_version="$(
		nvidia-smi --query-gpu=driver_version --format=csv,noheader |
			head -n1
	)"
	xnvctrl_version="$(
		apt-cache madison libxnvctrl0 |
			awk -v prefix="${gpu_driver_version}-" \
				'index($3, prefix) == 1 {print $3; exit}'
	)"
	if [[ -z "${xnvctrl_version}" ]]; then
		echo "No libxnvctrl0 package matches NVIDIA ${gpu_driver_version}" >&2
		exit 1
	fi
	sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
		"libxnvctrl0=${xnvctrl_version}"
fi
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y mpich libmpich-dev

if ! getent group slurm >/dev/null; then
	sudo groupadd --system slurm
fi
if ! getent passwd slurm >/dev/null; then
	sudo useradd --system --gid slurm --home-dir /var/lib/slurm \
		--shell /bin/bash slurm
fi
sudo usermod --home /var/lib/slurm --shell /bin/bash slurm
if ! getent passwd atf >/dev/null; then
	sudo useradd --create-home --shell /bin/bash atf
fi
sudo usermod -aG slurm atf
if ! getent passwd atf-test >/dev/null; then
	sudo useradd --create-home --shell /bin/bash atf-test
fi

# build-stack.sh runs the build as the unprivileged atf account and elevates
# only its install steps.  Install the disposable-VM sudo policy before the
# build, not later in configure-atf.sh, so a pristine CI image can complete
# its first build without an interactive password prompt.
sudo install -o root -g root -m 0440 \
	"${script_dir}/system/slurm-atf-sudoers" /etc/sudoers.d/slurm-atf
sudo visudo -cf /etc/sudoers.d/slurm-atf

sudo install -d -o atf -g atf -m 0755 \
	/opt/slurm-atf \
	/opt/slurm-atf/build \
	/opt/slurm-atf/mpich \
	/opt/slurm-atf/results \
	/opt/slurm-atf/src \
	/opt/slurm-atf/sut \
	/opt/slurm-atf/tests
sudo install -d -o slurm -g slurm -m 0775 \
	/run/slurm-atf \
	/var/lib/slurm-atf \
	/var/lib/slurm-atf/slurmctld \
	/var/lib/slurm-atf/slurmd \
	/var/log/slurm-atf
sudo install -d -o slurm -g slurm -m 0755 /var/lib/slurm

sudo chown munge:munge /etc/munge/munge.key
sudo chmod 0400 /etc/munge/munge.key
sudo systemctl enable --now munge mariadb influxdb

sudo mariadb <<'SQL'
CREATE DATABASE IF NOT EXISTS slurm_acct_db;
CREATE USER IF NOT EXISTS 'slurm'@'localhost'
  IDENTIFIED BY '';
ALTER USER 'slurm'@'localhost' IDENTIFIED BY '';
GRANT ALL PRIVILEGES ON *.* TO 'slurm'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
SQL

sudo python3 -m venv /opt/slurm-atf/venv
sudo /opt/slurm-atf/venv/bin/pip install --upgrade pip

echo "Base packages, users, MUNGE, MariaDB, and directories are ready."
