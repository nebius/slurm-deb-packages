ARG BASE_IMAGE=cr.eu-north1.nebius.cloud/soperator/cuda:12.9.0-cudnn-devel-ubuntu24.04

FROM $BASE_IMAGE

ARG OPENMPI_VERSION=4.1.7a1
ARG OPENMPI_SUBVERSION=1.2404066
ARG OFED_VERSION=24.04-0.7.0.0
ARG ARCH=x64

ARG DEBIAN_FRONTEND=noninteractive

ARG LD_LIBRARY_PATH=/lib/x86_64-linux-gnu:/usr/lib/x86_64-linux-gnu:/usr/local/nvidia/lib:/usr/local/nvidia/lib64:/usr/local/cuda/targets/x86_64-linux/lib:/usr/mpi/gcc/openmpi-${OPENMPI_VERSION}/lib

# Install dependencies
RUN apt-get update && \
    apt -y install \
        git  \
        build-essential \
        wget \
        libpmix2 \
        libpmix-dev

# Install Openmpi
RUN cd /etc/apt/sources.list.d && \
    wget https://linux.mellanox.com/public/repo/mlnx_ofed/${OFED_VERSION}/ubuntu24.04/mellanox_mlnx_ofed.list && \
    wget -qO - https://www.mellanox.com/downloads/ofed/RPM-GPG-KEY-Mellanox | apt-key add - && \
    apt update && \
    apt install openmpi=${OPENMPI_VERSION}-${OPENMPI_SUBVERSION}

ENV PATH=$PATH:/usr/mpi/gcc/openmpi-${OPENMPI_VERSION}/bin

# Build binaries
RUN cd /usr/src && \
    git clone --branch v2.16.4 --depth 1 https://github.com/NVIDIA/nccl-tests.git && \
    cd nccl-tests && \
    make && \
    make MPI=1 MPI_HOME=/usr/mpi/gcc/openmpi-4.1.7a1 CUDA_HOME=/usr/local/cuda BUILDDIR=build_mpi && \
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
    tar -czvf nccl-tests-perf-${ARCH}.tar.gz *_perf*

