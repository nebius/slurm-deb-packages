ARG BASE_IMAGE=ubuntu:jammy

FROM $BASE_IMAGE

ARG SLURM_VERSION=24.05.7
ARG ENROOT_VERSION=3.5.0
ARG PYXIS_VERSION=0.21.0

ARG DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && \
    apt -y install \
        wget \
        curl \
        git \
        build-essential \
        devscripts \
        debhelper \
        fakeroot \
        autoconf \
        pkg-config \
        libssl-dev \
        libpam0g-dev \
        libtool \
        libjansson-dev \
        libjson-c-dev \
        libmunge-dev \
        libhwloc-dev \
        liblz4-dev \
        flex \
        libevent-dev \
        squashfs-tools \
        zstd \
        libpmix2 \
        libpmix-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Add Nebius public registry
RUN curl -fsSL https://dr.nebius.cloud/public.gpg -o /usr/share/keyrings/nebius.gpg.pub && \
    echo "deb [signed-by=/usr/share/keyrings/nebius.gpg.pub] https://dr.nebius.cloud/ stable main" > /etc/apt/sources.list.d/nebius.list

# Install enroot (required for pyxis)
RUN apt-get update && \
    apt install -y enroot=${ENROOT_VERSION}-1 enroot+caps=${ENROOT_VERSION}-1 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -m 777 /usr/share/enroot/enroot-data && \
    mkdir -m 755 /run/enroot && \
    setcap cap_sys_admin+pe /usr/bin/enroot-mksquashovlfs && \
    setcap cap_sys_admin,cap_mknod+pe /usr/bin/enroot-aufs2ovlfs


# Download and build pyxis deb
# TODO @itechdima: keep watching this PR https://github.com/NVIDIA/pyxis/pull/155
RUN apt-get update && apt install -y slurm-smd=${SLURM_VERSION}-1 slurm-smd-dev=${SLURM_VERSION}-1 && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    cd /usr/src && \
    wget https://github.com/itechdima/pyxis/archive/refs/tags/v"$PYXIS_VERSION".tar.gz && \
    tar -xzvf v"$PYXIS_VERSION".tar.gz && \
    rm v"$PYXIS_VERSION".tar.gz && \
    cd pyxis-"$PYXIS_VERSION" && \
    ARCH=$(uname -m) && \
    sed -i 's|dh_auto_install -- prefix= libdir=/usr/lib/${ARCH} datarootdir=/usr/share|dh_auto_install -- prefix=/usr libdir=/usr/lib/${ARCH}-linux-gnu datarootdir=/usr/share|' debian/rules && \
    make orig && \
    make deb

################################################################
# RESULT
################################################################
# ls -la ../nvslurm-plugin-pyxis*.deb
# /usr/src/nvslurm-plugin-pyxis_0.20.0-1_amd64.deb
################################################################

# Move deb files
RUN mkdir /usr/src/debs && \
    mv /usr/src/nvslurm-plugin-pyxis*.deb /usr/src/debs/
