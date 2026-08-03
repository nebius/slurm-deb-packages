#!/usr/bin/env bash
set -euo pipefail

atf_root="${SLURM_ATF_ROOT:-/opt/slurm-atf}"
slurm_install="${SLURM_SUT_INSTALL_DIR:-${atf_root}/install}"
tests_source="${SLURM_TESTS_SOURCE_DIR:-${atf_root}/tests/common}"

export PATH="${atf_root}/bin:${atf_root}/venv/bin:${slurm_install}/bin:${slurm_install}/sbin:${atf_root}/openmpi/5.0.9/bin:${atf_root}/pmix/5.0.11/bin:/usr/local/cuda/bin:${PATH}"
export LD_LIBRARY_PATH="${slurm_install}/lib:${slurm_install}/lib/slurm:${atf_root}/openmpi/5.0.9/lib:${atf_root}/pmix/5.0.11/lib:/usr/local/cuda/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
export PKG_CONFIG_PATH="/opt/slurm-atf/pmix/5.0.11/lib/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"
export MODULEPATH="/etc/lmod/modules:/usr/share/lmod/lmod/modulefiles"
export SLURM_TESTSUITE_CONF="${tests_source}/testsuite/testsuite.conf"
export SLURM_CONF="${slurm_install}/etc/slurm.conf"
export SLURM_TEST_USER="${SLURM_TEST_USER:-atf-test}"

exec "$@"
