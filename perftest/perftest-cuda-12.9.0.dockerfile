ARG BASE_IMAGE=cr.eu-north1.nebius.cloud/soperator/cuda:12.9.0-cudnn-devel-ubuntu24.04

FROM $BASE_IMAGE

ARG ARCH=x64
ARG DEBIAN_FRONTEND=noninteractive
ARG MELLANOX_REPO_URL=https://linux.mellanox.com/public/repo/doca/3.1.0

RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates wget && \
    DPKG_ARCH="$(dpkg --print-architecture)" && \
    case "$DPKG_ARCH" in \
      amd64) MLNX_ARCH=x86_64 ;; \
      arm64) MLNX_ARCH=arm64 ;; \
      *) echo "Unsupported architecture: $DPKG_ARCH" && exit 1 ;; \
    esac && \
    echo "deb ${MELLANOX_REPO_URL}/ubuntu24.04/${MLNX_ARCH} ./" > /etc/apt/sources.list.d/mellanox_doca.list && \
    wget -qO - https://linux.mellanox.com/public/repo/doca/GPG-KEY-Mellanox.pub | apt-key add - && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        git \
        build-essential \
        autoconf \
        automake \
        libtool \
        libibverbs-dev=2507mlnx58-1.2507097 \
        librdmacm-dev=2507mlnx58-1.2507097 \
        libibumad-dev=2507mlnx58-1.2507097 \
        libpci-dev \
        libmlx5-1 \
        pkg-config && \
    rm -rf /var/lib/apt/lists/*


# Build perftest from source
RUN git clone https://github.com/linux-rdma/perftest.git /tmp/perftest && \
    cd /tmp/perftest && \
    ./autogen.sh && \
    ./configure --enable-cudart && \
    make

# Collect required binaries into /usr/src/perftest
RUN mkdir -p /usr/src/perftest && \
    cp /tmp/perftest/ib_* /usr/src/perftest/

################################################################
# RESULT
################################################################
# /usr/src/perftest/ib_*   (all ib_* binaries)
################################################################

# Create tar.gz archive with the ib_* perftest binaries
RUN cd /usr/src/perftest && \
    tar -czvf perftest-${ARCH}.tar.gz ib_*
