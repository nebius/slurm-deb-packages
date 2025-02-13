ARG BASE_IMAGE=nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04

FROM $BASE_IMAGE

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
RUN git clone --branch v2.4.4 --depth 1 https://github.com/NVIDIA/gdrcopy && cd gdrcopy/packages

# Build deb packages
RUN sed -i 's/gdrdrv-dkms (= @FULL_VERSION@), //g' debian-meta/control && \
    CUDA=/usr/local/cuda ./build-deb-packages.sh && \
    mkdir debs && \
    mv *.deb debs && \
    rm -rf debs/gdrdrv-dkms_2.4.4_amd64.Ubuntu22_04.deb && \
    ls -la debs

################################################################
# RESULT
################################################################
# gdrcopy-tests_2.4.4_amd64.Ubuntu22_04+cuda12.4.deb
# gdrcopy_2.4.4_amd64.Ubuntu22_04.deb
# libgdrapi_2.4.4_amd64.Ubuntu22_04.deb
################################################################
