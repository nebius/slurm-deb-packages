FROM cr.eu-north1.nebius.cloud/soperator/ubuntu:jammy

ARG DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && \
    apt -y install \
        equivs

RUN mkdir -p mocks
COPY cuda-mock-packages/cuda-drivers /mocks
COPY cuda-mock-packages/nvidia-open /mocks

WORKDIR mocks
RUN equivs-build cuda-drivers
RUN equivs-build nvidia-open

################################################################
# RESULT
################################################################
# ls -la /mocks/*.deb
#-rw-r--r-- 1 root root 2004 Feb  3 13:25 cuda-drivers_9999.1.1_amd64.deb
#-rw-r--r-- 1 root root 2000 Feb  3 13:24 nvidia-open_9999.1.1_amd64.deb
################################################################

