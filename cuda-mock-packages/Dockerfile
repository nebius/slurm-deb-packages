ARG BASE_IMAGE=ubuntu:jammy

FROM $BASE_IMAGE

ARG DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && \
    apt -y install \
        equivs

COPY cuda-mock-packages/ /cuda-mock-packages

WORKDIR cuda-mock-packages

RUN ARCH=$(uname -m) && \
    case "$ARCH" in \
      x86_64) ARCH_DEB=amd64 ;; \
      aarch64) ARCH_DEB=arm64 ;; \
      *) echo "Unsupported architecture: $ARCH" && exit 1 ;; \
    esac && \
    echo "Using architecture: $ARCH_DEB" && \
    sed -i "s/^Architecture: .*/Architecture: ${ARCH_DEB}/" cuda-drivers && \
    sed -i "s/^Architecture: .*/Architecture: ${ARCH_DEB}/" nvidia-open

RUN equivs-build cuda-drivers
RUN equivs-build nvidia-open

################################################################
# RESULT
################################################################
# ls -la /cuda-mock-packages/*.deb
#-rw-r--r-- 1 root root 2004 Feb  3 13:25 cuda-drivers_9999.1.1_amd64.deb
#-rw-r--r-- 1 root root 2000 Feb  3 13:24 nvidia-open_9999.1.1_amd64.deb
################################################################

