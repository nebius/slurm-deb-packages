ARG BASE_IMAGE=cr.eu-north1.nebius.cloud/soperator/ubuntu:jammy

FROM $BASE_IMAGE

ARG SLURM_VERSION=24.05.5
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
    apt clean

# Install enroot (required for pyxis)
RUN curl -fSsL -o /tmp/enroot_${ENROOT_VERSION}-1_amd64.deb https://github.com/NVIDIA/enroot/releases/download/v${ENROOT_VERSION}/enroot_${ENROOT_VERSION}-1_amd64.deb && \
    curl -fSsL -o /tmp/enroot+caps_${ENROOT_VERSION}-1_amd64.deb https://github.com/NVIDIA/enroot/releases/download/v${ENROOT_VERSION}/enroot+caps_${ENROOT_VERSION}-1_amd64.deb && \
    apt install -y /tmp/*.deb && rm -rf /tmp/*.deb && \
    mkdir -m 777 /usr/share/enroot/enroot-data && \
    mkdir -m 755 /run/enroot && \
    setcap cap_sys_admin+pe /usr/bin/enroot-mksquashovlfs && \
    setcap cap_sys_admin,cap_mknod+pe /usr/bin/enroot-aufs2ovlfs


# Download and build pyxis deb
# TODO @itechdima: keep watching this PR https://github.com/NVIDIA/pyxis/pull/155
RUN cd /usr/src && \
    wget https://github.com/nebius/slurm-deb-packages/releases/download/slurm-packages-${SLURM_VERSION}/slurm-smd_${SLURM_VERSION}-1_amd64.deb && \
    wget https://github.com/nebius/slurm-deb-packages/releases/download/slurm-packages-${SLURM_VERSION}/slurm-smd-dev_${SLURM_VERSION}-1_amd64.deb && \
    apt install -y /usr/src/*.deb && \
    wget https://github.com/itechdima/pyxis/archive/refs/tags/v"$PYXIS_VERSION".tar.gz && \
    tar -xzvf v"$PYXIS_VERSION".tar.gz && \
    rm v"$PYXIS_VERSION".tar.gz && \
    cd pyxis-"$PYXIS_VERSION" && \
    sed -i 's|dh_auto_install -- prefix= libdir=/usr/lib/$(DEB_HOST_MULTIARCH) datarootdir=/usr/share|dh_auto_install -- prefix=/usr libdir=/usr/lib/x86_64-linux-gnu datarootdir=/usr/share|' debian/rules && \
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
