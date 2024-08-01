FROM nvidia/cuda:12.2.2-cudnn8-devel-ubuntu20.04

ARG DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && \
    apt -y install \
        git  \
        build-essential \
        devscripts \
        debhelper \
        fakeroot \
        wget \
        equivs \
        autoconf \
        pkg-config \
        libssl-dev \
        libpam0g-dev \
        libtool \
        libjansson-dev \
        libjson-c-dev \
        munge \
        libmunge-dev \
        libjwt0 \
        libjwt-dev \
        libhwloc-dev \
        liblz4-dev \
        flex \
        libevent-dev \
        jq \
        squashfs-tools \
        zstd \
        zlibc \
        zlib1g-dev

# Download Slurm
ARG SLURM_VERSION=24.05.2
RUN cd /usr/src && \
    wget https://download.schedmd.com/slurm/slurm-${SLURM_VERSION}.tar.bz2 && \
    tar -xvf slurm-${SLURM_VERSION}.tar.bz2 && \
    rm -rf slurm-${SLURM_VERSION}.tar.bz2

# Install PMIx in order to build Slurm with PMIx support
# Slurm deb packages will be already compiled with PMIx support even without it, but only with v3, while we use v5
ARG PMIX_VERSION=5.0.3
RUN cd /usr/src && \
    wget https://github.com/openpmix/openpmix/releases/download/v${PMIX_VERSION}/pmix-${PMIX_VERSION}.tar.gz && \
    tar -xzvf pmix-${PMIX_VERSION}.tar.gz && \
    rm -rf pmix-${PMIX_VERSION}.tar.gz && \
    cd /usr/src/pmix-${PMIX_VERSION} && \
    ./configure && \
    make -j$(nproc) && \
    make install


# Build deb packages for Slurm
RUN cd /usr/src/slurm-${SLURM_VERSION} && \
    mk-build-deps -i debian/control -t "apt-get -o Debug::pkgProblemResolver=yes --no-install-recommends -y" && \
    debuild -b -uc -us

################################################################
# RESULT
################################################################
# /usr/src/slurm-smd-client_24.05.02-1_amd64.deb
# /usr/src/slurm-smd-dev_24.05.02-1_amd64.deb
# /usr/src/slurm-smd-doc_24.05.02-1_all.deb
# /usr/src/slurm-smd-libnss-slurm_24.05.02-1_amd64.deb
# /usr/src/slurm-smd-libpam-slurm-adopt_24.05.02-1_amd64.deb
# /usr/src/slurm-smd-libpmi0_24.05.02-1_amd64.deb
# /usr/src/slurm-smd-libpmi2-0_24.05.02-1_amd64.deb
# /usr/src/slurm-smd-libslurm-perl_24.05.02-1_amd64.deb
# /usr/src/slurm-smd-openlava_24.05.02-1_all.deb
# /usr/src/slurm-smd-sackd_24.05.02-1_amd64.deb
# /usr/src/slurm-smd-slurmctld_24.05.02-1_amd64.deb
# /usr/src/slurm-smd-slurmd_24.05.02-1_amd64.deb
# /usr/src/slurm-smd-slurmdbd_24.05.02-1_amd64.deb
# /usr/src/slurm-smd-slurmrestd_24.05.02-1_amd64.deb
# /usr/src/slurm-smd-sview_24.05.02-1_amd64.deb
# /usr/src/slurm-smd-torque_24.05.02-1_all.deb
# /usr/src/slurm-smd_24.05.02-1_amd64.deb
################################################################

RUN cd /usr/src && \
    git clone https://github.com/NVIDIA/nccl.git && \
    cd nccl && \
    make -j pkg.debian.build

#####################################################################
# RESULT
#####################################################################
# /usr/src/nccl/build/pkg/deb/libnccl-dev_2.22.3-1+cuda12.2_amd64.deb
# /usr/src/nccl/build/pkg/deb/libnccl2_2.22.3-1+cuda12.2_amd64.deb
#####################################################################

RUN cd /usr/src && \
    git clone https://github.com/NVIDIA/nccl-tests.git && \
    cd nccl-tests && \
    make

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
################################################################

# Move all deb files in one directory
RUN mkdir /usr/src/debs && \
    mv /usr/src/*.deb /usr/src/debs/ && \
    mv /usr/src/nccl/build/pkg/deb/*.deb /usr/src/debs/ && \
    ls -la /usr/src/debs/

# Create tar.gz archive with NCCL-tests binaries
RUN cd /usr/src/nccl-tests/build && \
    tar -czvf nccl-tests-perf.tar.gz *_perf
