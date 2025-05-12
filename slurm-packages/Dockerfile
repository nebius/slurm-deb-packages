ARG BASE_IMAGE=cr.eu-north1.nebius.cloud/soperator/nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04

FROM $BASE_IMAGE

ARG SLURM_VERSION=24.05.7
ARG OPENMPI_VERSION=4.1.7a1
ARG OPENMPI_SUBVERSION=1.2310055
ARG OFED_VERSION=23.10-2.1.3.1

ARG DEBIAN_FRONTEND=noninteractive

ARG LD_LIBRARY_PATH=/lib/x86_64-linux-gnu:/usr/lib/x86_64-linux-gnu:/usr/local/nvidia/lib:/usr/local/nvidia/lib64:/usr/local/cuda/targets/x86_64-linux/lib:/usr/mpi/gcc/openmpi-${OPENMPI_VERSION}/lib


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

ENV PATH=$PATH:/usr/mpi/gcc/openmpi-${OPENMPI_VERSION}/bin

# Build deb packages for Slurm
RUN cd /usr/src/slurm-${SLURM_VERSION} && \
    ARCH=$(uname -m) && \
    sed -i 's/--with-pmix\b/--with-pmix=\/usr\/lib\/${ARCH}-linux-gnu\/pmix2/' debian/rules && \
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

# Move deb files
RUN mkdir /usr/src/debs && \
    mv /usr/src/*.deb /usr/src/debs/
