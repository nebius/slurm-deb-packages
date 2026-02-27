ARG CUDA_VERSION
FROM cr.eu-north1.nebius.cloud/ml-containers/cuda:${CUDA_VERSION}-ubuntu24.04-20260227111638

ARG DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && \
    apt -y install \
        git  \
        build-essential \
        devscripts  \
        debhelper  \
        fakeroot

ARG NCCL_VERSION
# Build binaries
RUN cd /usr/src && \
    git clone --branch v${NCCL_VERSION}-1 --depth 1 https://github.com/NVIDIA/nccl.git && \
    cd nccl && \
    make pkg.debian.build && \
    ls -lah build/pkg/deb/

################################################################
# RESULT
################################################################
# libnccl2_2.29.7-1+cuda13.0_amd64.deb
# libnccl-dev_2.29.7-1+cuda13.0_amd64.deb

# Move deb files
RUN mkdir /usr/src/debs && \
    mv /usr/src/nccl/build/pkg/deb/*.deb /usr/src/debs/
