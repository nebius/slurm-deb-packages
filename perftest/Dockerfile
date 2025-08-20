ARG BASE_IMAGE=cr.eu-north1.nebius.cloud/soperator/cuda:12.9.0-cudnn-devel-ubuntu24.04

FROM $BASE_IMAGE

ARG ARCH=x64
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        git \
        build-essential \
        autoconf \
        libtool \
        libibverbs-dev \
        librdmacm-dev \
        libibumad-dev \
        libpci-dev \
        libmlx5-1 && \
    rm -rf /var/lib/apt/lists/*


# Build perftest from source
RUN git clone https://github.com/linux-rdma/perftest.git /tmp/perftest && \
    cd /tmp/perftest && \
    ./autogen.sh && \
    ./configure --enable-cudart && \
    make

# Collect required binaries into /usr/src/perftest
RUN mkdir -p /usr/src/perftest && \
    cp /tmp/perftest/ib_write_bw /usr/src/perftest/ && \
    cp /tmp/perftest/ib_write_lat /usr/src/perftest/

################################################################
# RESULT
################################################################
# /usr/src/perftest/ib_write_bw
# /usr/src/perftest/ib_write_lat
################################################################

# Create tar.gz archive with the two perftest binaries
RUN cd /usr/src/perftest && \
    tar -czvf perftest-${ARCH}.tar.gz ib_write_bw ib_write_lat
