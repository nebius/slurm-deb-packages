FROM cr.eu-north1.nebius.cloud/soperator/ubuntu:noble

ARG SLURM_VERSION
ARG ENROOT_VERSION
ARG PYXIS_VERSION

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
        zstd

# Add Nebius public registry
RUN curl -fsSL https://dr.nebius.cloud/public.gpg -o /usr/share/keyrings/nebius.gpg.pub && \
    codename="$(. /etc/os-release && echo $VERSION_CODENAME)" && \
    echo "deb [signed-by=/usr/share/keyrings/nebius.gpg.pub] https://dr.nebius.cloud/ $codename main" > /etc/apt/sources.list.d/nebius.list

# Download enroot
RUN if [ "$ARCH" == "linux/amd64" ]; then \
        ARCH="amd64" \
    else \
        ARCH="arm64" \
    fi && \
    curl -fSsL -o /tmp/enroot_4.0.1-1_${ARCH}.deb https://github.com/NVIDIA/enroot/releases/download/v${ENROOT_VERSION}/enroot_${ENROOT_VERSION}_${ARCH}-1.deb && \
    curl -fSsL -o /tmp/enroot+caps_4.0.1-1_${ARCH}.deb https://github.com/NVIDIA/enroot/releases/download/v${ENROOT_VERSION}/enroot+caps_${ENROOT_VERSION}-1_${ARCH}.deb

# Install downloaded packages & rm them
RUN apt-get update && \
    apt install -y /tmp/*.deb && \
    rm -rf /tmp/*.deb && \
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
    sed -i "s/^VERSION\s\+?=\s\+.*/VERSION   ?= ${SLURM_VERSION}-${PYXIS_VERSION}/" Makefile && \
    sed -i "s|dh_auto_install -- prefix=.*|dh_auto_install -- prefix=/usr libdir=/usr/lib/${ARCH}-linux-gnu datarootdir=/usr/share|" debian/rules && \
    { echo "nvslurm-plugin-pyxis (${SLURM_VERSION}-${PYXIS_VERSION}-1) UNRELEASED; urgency=medium"; echo ""; echo "  * Release ${PYXIS_VERSION} for Slurm ${SLURM_VERSION}"; echo ""; echo " -- NEBIUS <amialiusik@nebius.com>  Tue, 28 Jan 2025 00:17:05 +0000"; echo ""; cat debian/changelog; } > debian/changelog.new && mv debian/changelog.new debian/changelog && \
    make orig && \
    make deb

################################################################
# RESULT
################################################################
#ls -la ../nvslurm-plugin-pyxis_24.11.5-0.21.0-1_amd64.deb
#-rw-r--r-- 1 root root 21698 Jun 19 12:32 ../nvslurm-plugin-pyxis_24.11.5-0.21.0-1_amd64.deb
################################################################

# Move deb files
RUN mkdir /usr/src/debs && \
    mv /usr/src/nvslurm-plugin-pyxis*.deb /usr/src/debs/
