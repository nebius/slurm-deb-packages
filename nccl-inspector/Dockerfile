ARG CUDA_VERSION
FROM cr.eu-north1.nebius.cloud/ml-containers/cuda:${CUDA_VERSION}-ubuntu24.04-20260227111638 AS builder

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
ARG NCCL_VERSION_MAJOR
ARG NCCL_VERSION_RELEASE
ARG NCCL_ARCH
ARG NCCL_CUDA_VERSION
ARG PATH_TO_INSPECTOR

COPY nccl-inspector/config/ /usr/src/nccl-inspector

# Build shared library
RUN cd /usr/src && \
    git clone --branch v${NCCL_VERSION} --depth 1 https://github.com/${NCCL_REPO_OWNER}/nccl && \
    cd nccl/${PATH_TO_INSPECTOR} && \
    make && \
    ls -lah *.so && \
    mv *.so /usr/src/nccl-inspector && \
    cp README.md /usr/src/nccl/LICENSE.txt /usr/src/nccl-inspector/ && \
    cp /usr/src/nccl/README.md /usr/src/nccl-inspector/README-nccl.md

WORKDIR /usr/src/nccl-inspector

# Build copyright file
RUN chmod +x copyright.sh && \
    ./copyright.sh /usr/src/nccl > copyright

# Build deb package
RUN mkdir out && \
    nfpm package -p deb -t out && \
    ls -lah ./out/*.deb

FROM cr.eu-north1.nebius.cloud/soperator/busybox
COPY --from=builder /usr/src/nccl-inspector/out /debs
CMD ["true"]
