ARG BASE_IMAGE=cr.eu-north1.nebius.cloud/soperator/cuda_base:13.0.2-ubuntu24.04-nccl2.28.7-1-14542c2

FROM $BASE_IMAGE

ARG ARCH=x64
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        git \
        build-essential \
        autoconf \
        automake \
        libtool \
        libibverbs-dev \
        librdmacm-dev \
        libibumad-dev \
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
