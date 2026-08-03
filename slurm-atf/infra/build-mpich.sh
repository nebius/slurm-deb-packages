#!/usr/bin/env bash
set -euo pipefail

root=/opt/slurm-atf
slurm_prefix="${SLURM_INSTALL_DIR:-${root}/install}"
jobs="${BUILD_JOBS:-$(nproc)}"

mpich_version=5.0.1
mpich_source="${root}/src/mpich-${mpich_version}"
# The PMI2 dynamic-spawn regression (expect/test_1_94.py) cannot use CH4/UCX:
# CH4 advertises a port name up to 4096 bytes while Slurm PMI2 deliberately
# limits a value to PMI2_MAX_VALLEN (1024).  CH3/sock keeps the dynamic port
# within the PMI2 protocol limit and is the compatibility profile needed by
# Slurm's PMI2 tests.  PMIx coverage is provided separately by OpenMPI.
mpich_device="${MPICH_DEVICE:-ch3:sock}"
mpich_profile="${mpich_device//:/-}"
mpich_build="${root}/build/mpich-${mpich_version}-${mpich_profile}"
mpich_prefix="${root}/mpich/${mpich_version}-${mpich_profile}"
mpich_archive="${root}/src/mpich-${mpich_version}.tar.gz"
mpich_sha256=8c1832a13ddacf071685069f5fadfd1f2877a29e1a628652892c65211b1f3327

if [[ ! -x "${slurm_prefix}/bin/srun" ]]; then
	echo "Slurm must be installed at ${slurm_prefix} before MPICH." >&2
	exit 2
fi

if [[ ! -x "${mpich_source}/configure" ]]; then
	curl -fL \
		"https://www.mpich.org/static/downloads/${mpich_version}/mpich-${mpich_version}.tar.gz" \
		-o "${mpich_archive}"
	echo "${mpich_sha256}  ${mpich_archive}" | sha256sum -c -
	tar -xzf "${mpich_archive}" -C "${root}/src"
fi

mkdir -p "${mpich_build}"
cd "${mpich_build}"
LD_LIBRARY_PATH="${slurm_prefix}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}" \
"${mpich_source}/configure" \
	--prefix="${mpich_prefix}" \
	--with-pmilib=slurm \
	--with-pmi=pmi2 \
	--with-pm=none \
	--with-slurm="${slurm_prefix}" \
	--with-device="${mpich_device}" \
	--disable-fortran \
	CPPFLAGS="-DMISSING_PMI2_KEYVAL_T" \
	CFLAGS="-O2 -g3 -fno-omit-frame-pointer"
make -j"${jobs}"
make install

echo "Slurm-linked MPICH ${mpich_version} (${mpich_device}) is installed in ${mpich_prefix}."
