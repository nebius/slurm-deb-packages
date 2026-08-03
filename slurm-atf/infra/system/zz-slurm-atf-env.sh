# Keep Slurm ATF login shells isolated from the VM image's bundled
# Mellanox OpenMPI/PMIx environment.  ATF deliberately runs privileged
# commands through "bash -lc", so /etc/profile.d/openmpi.sh would otherwise
# put its PMIx 3 runtime ahead of the PMIx 5 instance used to build Slurm.
if [ "${SLURM_TESTSUITE_CONF:-}" = "/opt/slurm-atf/tests/common/testsuite/testsuite.conf" ]; then
	export PATH="/opt/slurm-atf/bin:/opt/slurm-atf/venv/bin:/opt/slurm-atf/install/bin:/opt/slurm-atf/install/sbin:/opt/slurm-atf/openmpi/5.0.9/bin:/opt/slurm-atf/pmix/5.0.11/bin:/usr/local/cuda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
	export LD_LIBRARY_PATH="/opt/slurm-atf/install/lib:/opt/slurm-atf/install/lib/slurm:/opt/slurm-atf/openmpi/5.0.9/lib:/opt/slurm-atf/pmix/5.0.11/lib:/usr/local/cuda/lib64"
	export SLURM_TEST_USER="${SLURM_TEST_USER:-atf-test}"
	export PKG_CONFIG_PATH="/opt/slurm-atf/openmpi/5.0.9/lib/pkgconfig:/opt/slurm-atf/pmix/5.0.11/lib/pkgconfig"
	export MODULEPATH="/etc/lmod/modules:/usr/share/lmod/lmod/modulefiles"
	export SLURM_CONF="/opt/slurm-atf/install/etc/slurm.conf"
fi
