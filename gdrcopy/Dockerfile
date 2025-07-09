ARG BASE_IMAGE=cr.eu-north1.nebius.cloud/soperator/cuda:12.9.0-cudnn-devel-ubuntu24.04

FROM $BASE_IMAGE

ARG DGRCOPY_VERSION=2.5

ARG DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && \
    apt -y install \
        git  \
        build-essential \
        wget \
        devscripts \
        debhelper \
        fakeroot \
        pkg-config \
        dkms

# Download gdrcopy sources
RUN git clone --branch v${DGRCOPY_VERSION} --depth 1 https://github.com/NVIDIA/gdrcopy

# Build deb packages
RUN cd gdrcopy/packages && \
    sed -i 's/gdrdrv-dkms (= @FULL_VERSION@), //g' debian-meta/control && \
    CUDA=/usr/local/cuda ./build-deb-packages.sh && \
    mkdir debs && \
    mv *.deb debs && \
    rm -rf debs/gdrdrv-dkms*.deb && \
    ls -la debs

################################################################
# RESULT
################################################################
# gdrcopy-tests_2.5_amd64.Ubuntu24_04+cuda12.4.deb
# gdrcopy_2.5_amd64.Ubuntu24_04.deb
# libgdrapi_2.5_amd64.Ubuntu24_04.deb
################################################################
