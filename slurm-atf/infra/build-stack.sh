#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root=/opt/slurm-atf
slurm_source="${SLURM_SUT_SOURCE_DIR:-${root}/sut/src}"
slurm_build="${SLURM_SUT_BUILD_DIR:-${root}/sut/build}"
slurm_install="${SLURM_SUT_INSTALL_DIR:-${root}/install}"
jobs="${BUILD_JOBS:-$(nproc)}"

pmix_source="${root}/src/openpmix"
pmix_build="${root}/build/pmix-5.0.11"
pmix_prefix="${root}/pmix/5.0.11"
pmix_commit=3795947f0fa625f406f1d085d1e70a8413b3febc

ompi_source="${root}/src/openmpi-5.0.9"
ompi_build="${root}/build/openmpi-5.0.9"
ompi_prefix="${root}/openmpi/5.0.9"
ompi_commit=b79100b3fbbf45b3c6ed82a6b67b6346f8cfdc41

# Ubuntu 24.04 ships a 6.8 linux-libc-dev even on the NVIDIA 6.11 kernel.
# Slurm's namespace/linux plugin needs the BPF token definitions added in 6.9.
# Overlay only bpf.h from the running kernel's UAPI headers so configure and
# the cgroup plugin are compiled against the feature actually supported by the
# running kernel.
bpf_uapi_root="${root}/kernel-uapi"
kernel_bpf_header="/usr/src/linux-headers-$(uname -r)/include/uapi/linux/bpf.h"
bpf_root=/usr
nvml_args=()
if [[ -f /usr/local/cuda/include/nvml.h ]]; then
	nvml_args+=(--with-nvml=/usr/local/cuda)
fi
if [[ -f "${kernel_bpf_header}" ]] && grep -q BPF_TOKEN_CREATE "${kernel_bpf_header}"; then
	sudo install -D -m 0644 "${kernel_bpf_header}" \
		"${bpf_uapi_root}/include/linux/bpf.h"
	bpf_root="${bpf_uapi_root}"
fi

if [[ ! -f "${slurm_source}/META" ]]; then
	echo "Slurm source is missing at ${slurm_source}" >&2
	echo "Run slurm-atf/ci/prepare-sources.sh first." >&2
	exit 2
fi

if [[ ! -d "${pmix_source}/.git" ]]; then
	git clone --branch v5.0.11 --depth 1 \
		https://github.com/openpmix/openpmix.git "${pmix_source}"
fi
if [[ ! -d "${ompi_source}/.git" ]]; then
	git clone --branch v5.0.9 --depth 1 \
		https://github.com/open-mpi/ompi.git "${ompi_source}"
fi
if [[ "$(git -C "${pmix_source}" rev-parse HEAD)" != "${pmix_commit}" ]]; then
	echo "PMIx v5.0.11 did not resolve to pinned ${pmix_commit}" >&2
	exit 1
fi
if [[ "$(git -C "${ompi_source}" rev-parse HEAD)" != "${ompi_commit}" ]]; then
	echo "OpenMPI v5.0.9 did not resolve to pinned ${ompi_commit}" >&2
	exit 1
fi

(
	cd "${pmix_source}"
	./autogen.pl
	mkdir -p "${pmix_build}"
	cd "${pmix_build}"
	"${pmix_source}/configure" \
		--prefix="${pmix_prefix}" \
		--with-hwloc=/usr \
		--with-hwloc-libdir=/usr/lib/x86_64-linux-gnu \
		--with-libevent=/usr \
		--with-libevent-libdir=/usr/lib/x86_64-linux-gnu
	make -j"${jobs}"
	make install
)

(
	cd "${ompi_source}"
	./autogen.pl
	mkdir -p "${ompi_build}"
	cd "${ompi_build}"
	PKG_CONFIG_PATH="${pmix_prefix}/lib/pkgconfig" \
	"${ompi_source}/configure" \
		--prefix="${ompi_prefix}" \
		--with-pmix="${pmix_prefix}" \
		--with-pmix-libdir="${pmix_prefix}/lib" \
		--with-libevent=/usr \
		--with-libevent-libdir=/usr/lib/x86_64-linux-gnu \
		--with-hwloc=/usr \
		--with-hwloc-libdir=/usr/lib/x86_64-linux-gnu \
		--with-slurm \
		--disable-mpi-fortran \
		CFLAGS="-O2 -g3 -fno-omit-frame-pointer"
	make -j"${jobs}"
	make install
)

(
	cd "${slurm_source}"
	if [[ ! -x ./configure ]]; then
		autoreconf -fi
	fi
	mkdir -p "${slurm_build}"
	cd "${slurm_build}"
	PKG_CONFIG_PATH="${pmix_prefix}/lib/pkgconfig" \
	CPPFLAGS="-I${bpf_root}/include" \
	"${slurm_source}/configure" \
		--prefix="${slurm_install}" \
		--sysconfdir="${slurm_install}/etc" \
		--localstatedir=/var/lib/slurm-atf \
		--runstatedir=/run/slurm-atf \
		--enable-multiple-slurmd \
		--enable-pam \
		"${nvml_args[@]}" \
		--with-pmix="${pmix_prefix}" \
		--with-json=/usr \
		--with-jwt=/usr \
		--with-yaml=/usr \
		--with-hdf5=yes \
		--with-lz4=/usr \
		--with-hwloc=/usr \
		--with-bpf="${bpf_root}" \
		--with-lua \
		--with-freeipmi=/usr \
		CFLAGS="-O2 -g3 -fno-omit-frame-pointer"
	make -j"${jobs}"
	make check
	sudo make install
	# MPICH's --with-pmilib=slurm configure probes the separately shipped
	# Slurm PMI2 client header/library; the top-level install omits them.
	sudo make -C "${slurm_build}/contribs/pmi2" install
	# expect/test7.2 validates Slurm's separately shipped PMI1 client API.
	sudo make -C "${slurm_build}/contribs/pmi" install
	# Torque/OpenLava/seff wrappers import the generated Slurm Perl API.
	sudo make -C "${slurm_build}/contribs/perlapi" install
	# The ATF compatibility tests invoke these scripts by their installed
	# command names.  They are deliberately not installed by the top-level
	# Slurm target.
	for contrib in torque openlava seff; do
		sudo make -C "${slurm_build}/contribs/${contrib}" install
	done
	# test_125_1 auto-config otherwise tries to copy these as SlurmUser into
	# the root-owned installation prefix and fails before starting Slurm.
	sudo install -o root -g root -m 0755 \
		"${slurm_source}/src/plugins/burst_buffer/datawarp/dw_wlm_cli" \
		"${slurm_install}/sbin/dw_wlm_cli"
	sudo install -o root -g root -m 0755 \
		"${slurm_source}/src/plugins/burst_buffer/datawarp/dwstat" \
		"${slurm_install}/sbin/dwstat"
)

# The PMI2 tests require MPICH linked to the PMI2 client library installed by
# this exact Slurm build. Ubuntu's MPICH is linked to PMIx instead, so every
# rank sees itself as rank zero when launched through `srun --mpi=pmi2`.
BUILD_JOBS="${jobs}" SLURM_INSTALL_DIR="${slurm_install}" \
	"${script_dir}/build-mpich.sh"

echo "PMIx, OpenMPI, Slurm, and Slurm-linked MPICH are built and installed."
