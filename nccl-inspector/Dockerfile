ARG CUDA_VERSION
FROM cr.eu-north1.nebius.cloud/ml-containers/cuda:${CUDA_VERSION}-ubuntu24.04-20260227111638

ARG DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN echo 'deb [trusted=yes] https://repo.goreleaser.com/apt/ /' | tee /etc/apt/sources.list.d/goreleaser.list && \
    apt-get update && \
    apt -y install \
        git  \
        build-essential \
        nfpm

ARG NCCL_REPO_OWNER
ARG NCCL_VERSION

# Build shared library
RUN cd /usr/src && \
    git clone --branch v${NCCL_VERSION} --depth 1 https://github.com/${NCCL_REPO_OWNER}/nccl && \
    cd nccl/plugins/profiler/inspector && \
    make && \
    ls -lah *.so

COPY nccl-inspector/config/ /usr/src/nccl/plugins/profiler/inspector
WORKDIR /usr/src/nccl/plugins/profiler/inspector

# Build copyright file
RUN chmod +x copyright.sh && \
    ./copyright.sh

ARG NCCL_VERSION_MAJOR
ARG NCCL_VERSION_RELEASE
ARG NCCL_ARCH

# Build deb package
RUN mkdir out && \
    nfpm package -p deb -t out && \
    ls -lah ./out/*.deb

# Move deb files
RUN mkdir /usr/src/debs && \
    mv /usr/src/nccl/plugins/profiler/inspector/out/*.deb /usr/src/debs/
