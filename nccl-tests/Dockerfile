ARG CUDA_VERSION
FROM cr.eu-north1.nebius.cloud/ml-containers/cuda:${CUDA_VERSION}-ubuntu24.04-20260220145309

ARG OPENMPI_VERSION=4.1.9a1
ARG OPENMPI_SUBVERSION=1.20250722.92f9fca4eb.2507097
ARG MELLANOX_REPO_URL=https://linux.mellanox.com/public/repo/doca/3.1.0

ARG DEBIAN_FRONTEND=noninteractive

ARG LD_LIBRARY_PATH=/usr/mpi/gcc/openmpi-${OPENMPI_VERSION}/lib:/lib/x86_64-linux-gnu:/usr/lib/x86_64-linux-gnu:/usr/local/nvidia/lib:/usr/local/nvidia/lib64:/usr/local/cuda/targets/x86_64-linux/lib

# Install dependencies
RUN apt-get update && \
    apt -y install \
        git  \
        build-essential \
        wget \
        libpmix2 \
        libpmix-dev

# Install Openmpi
RUN ARCH="$(dpkg --print-architecture)" && \
    case "$ARCH" in \
      amd64) MLNX_ARCH=x86_64 ;; \
      arm64) MLNX_ARCH=arm64 ;; \
      *) echo "Unsupported architecture: $ARCH" && exit 1 ;; \
    esac && \
    echo "deb ${MELLANOX_REPO_URL}/ubuntu24.04/${MLNX_ARCH} ./" > /etc/apt/sources.list.d/mellanox_doca.list && \
    wget -qO - https://linux.mellanox.com/public/repo/doca/GPG-KEY-Mellanox.pub | apt-key add - && \
    apt update && \
    apt install openmpi=${OPENMPI_VERSION}-${OPENMPI_SUBVERSION}

ENV PATH=/usr/mpi/gcc/openmpi-${OPENMPI_VERSION}/bin:$PATH

ARG NCCL_TESTS_VERSION
# Build binaries
RUN cd /usr/src && \
    git clone --branch v${NCCL_TESTS_VERSION} --depth 1 https://github.com/NVIDIA/nccl-tests.git && \
    cd nccl-tests && \
    make && \
    make MPI=1 MPI_HOME=/usr/mpi/gcc/openmpi-${OPENMPI_VERSION} CUDA_HOME=/usr/local/cuda BUILDDIR=build_mpi && \
    for f in build_mpi/*_perf; do mv "$f" "${f}_mpi"; done && \
    mv build_mpi/*_mpi build

################################################################
# RESULT
################################################################
# /usr/src/nccl-tests/build/all_gather_perf
# /usr/src/nccl-tests/build/all_reduce_perf
# /usr/src/nccl-tests/build/alltoall_perf
# /usr/src/nccl-tests/build/broadcast_perf
# /usr/src/nccl-tests/build/gather_perf
# /usr/src/nccl-tests/build/hypercube_perf
# /usr/src/nccl-tests/build/reduce_perf
# /usr/src/nccl-tests/build/reduce_scatter_perf
# /usr/src/nccl-tests/build/scatter_perf
# /usr/src/nccl-tests/build/sendrecv_perf

# /usr/src/nccl-tests/build/all_gather_perf_mpi
# /usr/src/nccl-tests/build/all_reduce_perf_mpi
# /usr/src/nccl-tests/build/alltoall_perf_mpi
# /usr/src/nccl-tests/build/broadcast_perf_mpi
# /usr/src/nccl-tests/build/gather_perf_mpi
# /usr/src/nccl-tests/build/hypercube_perf_mpi
# /usr/src/nccl-tests/build/reduce_perf_mpi
# /usr/src/nccl-tests/build/reduce_scatter_perf_mpi
# /usr/src/nccl-tests/build/scatter_perf_mpi
# /usr/src/nccl-tests/build/sendrecv_perf_mpi
################################################################

# Create tar.gz archive with NCCL-tests binaries
RUN cd /usr/src/nccl-tests/build && \
    tar -czvf nccl-tests-perf-$(uname -m).tar.gz *_perf*
