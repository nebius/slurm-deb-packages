ARG BASE_IMAGE=cr.eu-north1.nebius.cloud/soperator/cuda:12.9.0-cudnn-devel-ubuntu24.04

FROM $BASE_IMAGE

ARG ARCH=x64
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    build-essential git cmake

RUN git clone --depth 1 --branch v12.9 https://github.com/NVIDIA/cuda-samples.git /tmp/cuda-samples

ENV TESTS="Samples/1_Utilities/deviceQuery Samples/0_Introduction/simpleMultiGPU Samples/0_Introduction/vectorAdd Samples/5_Domain_Specific/p2pBandwidthLatencyTest"

RUN mkdir -p /tmp/cuda-samples/build && cd /tmp/cuda-samples/build && mkdir -p /usr/src/cuda-samples && \
    cmake -DCMAKE_CUDA_COMPILER=/usr/local/cuda/bin/nvcc .. && \
    for SRC in $TESTS; do \
        BIN=$(basename $SRC); \
        make -C /tmp/cuda-samples/build/$SRC -j$(nproc) && \
        cp /tmp/cuda-samples/build/$SRC/$BIN /usr/src/cuda-samples/$BIN; \
    done

################################################################
# RESULT
################################################################
# /usr/src/cuda-samples/deviceQuery
# /usr/src/cuda-samples/p2pBandwidthLatencyTest
# /usr/src/cuda-samples/simpleMultiGPU
# /usr/src/cuda-samples/vectorAdd
################################################################

# Create tar.gz archive with cuda-samples binaries
RUN cd /usr/src/cuda-samples && \
    tar -czvf cuda-samples-${ARCH}.tar.gz .
