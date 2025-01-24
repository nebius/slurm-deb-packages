ARG BASE_IMAGE=nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04

FROM $BASE_IMAGE

ARG SLURM_VERSION=24.05.5
ARG OPENMPI_VERSION=4.1.7a1
ARG OPENMPI_SUBVERSION=1.2310055
ARG OFED_VERSION=23.10-2.1.3.1
ARG ENROOT_VERSION=3.5.0
ARG PYXIS_VERSION=0.20.0

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
        curl \
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
        zlib1g \
        zlib1g-dev \
        libpmix2 \
        libpmix-dev

# Download Slurm
RUN cd /usr/src && \
    wget https://download.schedmd.com/slurm/slurm-${SLURM_VERSION}.tar.bz2 && \
    tar -xvf slurm-${SLURM_VERSION}.tar.bz2 && \
    rm -rf slurm-${SLURM_VERSION}.tar.bz2

# Install Openmpi
RUN cd /etc/apt/sources.list.d && \
    wget https://linux.mellanox.com/public/repo/mlnx_ofed/${OFED_VERSION}/$(. /etc/os-release; echo $ID$VERSION_ID)/mellanox_mlnx_ofed.list && \
    wget -qO - https://www.mellanox.com/downloads/ofed/RPM-GPG-KEY-Mellanox | apt-key add - && \
    apt update && \
    apt install openmpi=${OPENMPI_VERSION}-${OPENMPI_SUBVERSION}

ENV LD_LIBRARY_PATH=/lib/x86_64-linux-gnu:/usr/lib/x86_64-linux-gnu:/usr/local/nvidia/lib:/usr/local/nvidia/lib64:/usr/local/cuda/targets/x86_64-linux/lib:/usr/mpi/gcc/openmpi-${OPENMPI_VERSION}/lib
ENV PATH=$PATH:/usr/mpi/gcc/openmpi-${OPENMPI_VERSION}/bin

# Build deb packages for Slurm
RUN cd /usr/src/slurm-${SLURM_VERSION} && \
    sed -i 's/--with-pmix\b/--with-pmix=\/usr\/lib\/x86_64-linux-gnu\/pmix2/' debian/rules && \
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

# Install enroot (required for pyxis)
RUN curl -fSsL -o /tmp/enroot_${ENROOT_VERSION}-1_amd64.deb https://github.com/NVIDIA/enroot/releases/download/v${ENROOT_VERSION}/enroot_${ENROOT_VERSION}-1_amd64.deb && \
    curl -fSsL -o /tmp/enroot+caps_${ENROOT_VERSION}-1_amd64.deb https://github.com/NVIDIA/enroot/releases/download/v${ENROOT_VERSION}/enroot+caps_${ENROOT_VERSION}-1_amd64.deb && \
    apt install -y /tmp/*.deb && rm -rf /tmp/*.deb && \
    mkdir -m 777 /usr/share/enroot/enroot-data && \
    mkdir -m 755 /run/enroot && \
    setcap cap_sys_admin+pe /usr/bin/enroot-mksquashovlfs && \
    setcap cap_sys_admin,cap_mknod+pe /usr/bin/enroot-aufs2ovlfs


# Download and build pyxis deb
RUN cd /usr/src && \
    dpkg -i ../slurm-smd_24.05.5-1_amd64.deb && \
    dpkg -i ../slurm-smd-dev_24.05.5-1_amd64.deb && \
    wget https://github.com/NVIDIA/pyxis/archive/refs/tags/v"$PYXIS_VERSION".tar.gz && \
    tar -xzvf v"$PYXIS_VERSION".tar.gz && \
    rm v"$PYXIS_VERSION".tar.gz && \
    cd pyxis-"$PYXIS_VERSION" && \
    sed -i 's|dh_auto_install -- prefix= libdir=/usr/lib/$(DEB_HOST_MULTIARCH) datarootdir=/usr/share|dh_auto_install -- prefix=/usr libdir=/usr/lib/x86_64-linux-gnu datarootdir=/usr/share|' debian/rules && \
    make orig && \
    make deb \
    make install prefix=/usr libdir=/usr/lib/x86_64-linux-gnu

################################################################
# RESULT
################################################################
# ls -la ../nvslurm-plugin-pyxis*.deb
# /usr/src/nvslurm-plugin-pyxis_0.20.0-1_amd64.deb
################################################################

# Move deb files
RUN mkdir /usr/src/debs && \
    mv /usr/src/*.deb /usr/src/debs/

# Create tar.gz archive with NCCL-tests binaries
RUN cd /usr/src/nccl-tests/build && \
    tar -czvf nccl-tests-perf.tar.gz *_perf
