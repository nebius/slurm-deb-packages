ARG BASE_IMAGE=cr.eu-north1.nebius.cloud/ml-containers/neubuntu:noble-20260202145316

FROM $BASE_IMAGE

ARG SLURM_VERSION
ARG LD_LIBRARY_PATH

ARG OPENMPI_VERSION=4.1.9a1
ARG OPENMPI_SUBVERSION=1.20250722.92f9fca4eb.2507097
ARG MELLANOX_REPO_URL=https://linux.mellanox.com/public/repo/doca/3.1.0

ARG DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt install -y --update \
        git  \
        build-essential \
        devscripts \
        debhelper \
        fakeroot \
        wget \
        curl \
        equivs \
        autoconf \
        pkg-config \
        libssl-dev \
        libpam0g-dev \
        libtool \
        libjansson-dev \
        libjson-c-dev \
        munge \
        libmunge-dev \
        libjwt2 \
        libjwt-dev \
        libhwloc-dev \
        liblz4-dev \
        flex \
        libevent-dev \
        jq \
        squashfs-tools \
        zstd \
        zlib1g \
        zlib1g-dev \
        libpmix-dev


# Download Slurm
RUN cd /usr/src && \
    wget https://download.schedmd.com/slurm/slurm-${SLURM_VERSION}.tar.bz2 && \
    tar -xvf slurm-${SLURM_VERSION}.tar.bz2 && \
    rm -rf slurm-${SLURM_VERSION}.tar.bz2

# Install Openmpi
RUN ARCH="$(dpkg --print-architecture)" && \
    case "$ARCH" in \
      amd64) MLNX_ARCH=x86_64 ;; \
      arm64) MLNX_ARCH=arm64 ;; \
      *) echo "Unsupported architecture: $ARCH" && exit 1 ;; \
    esac && \
    echo "deb ${MELLANOX_REPO_URL}/ubuntu24.04/${MLNX_ARCH} ./" > /etc/apt/sources.list.d/mellanox_doca.list && \
    wget -qO - https://linux.mellanox.com/public/repo/doca/GPG-KEY-Mellanox.pub | apt-key add - && \
    apt update && \
    apt install openmpi=${OPENMPI_VERSION}-${OPENMPI_SUBVERSION}

ENV PATH=/usr/mpi/gcc/openmpi-${OPENMPI_VERSION}/bin:$PATH

# Build deb packages for Slurm
RUN cd /usr/src/slurm-${SLURM_VERSION} && \
    ARCH=$(uname -m) && \
    sed -i "s|--with-pmix\b|--with-pmix=/usr/lib/${ARCH}-linux-gnu/pmix2|" debian/rules && \
    mk-build-deps -i debian/control -t "apt-get -o Debug::pkgProblemResolver=yes --no-install-recommends -y" && \
    debuild -b -uc -us

################################################################
# RESULT
################################################################
# /usr/src/slurm-smd_25.05.5-1_amd64.deb
# /usr/src/slurm-smd-client_25.05.5-1_amd64.deb
# /usr/src/slurm-smd-dev_25.05.5-1_amd64.deb
# /usr/src/slurm-smd-doc_25.05.5-1_all.deb
# /usr/src/slurm-smd-libnss-slurm_25.05.5-1_amd64.deb
# /usr/src/slurm-smd-libpam-slurm-adopt_25.05.5-1_amd64.deb
# /usr/src/slurm-smd-libpmi0_25.05.5-1_amd64.deb
# /usr/src/slurm-smd-libpmi2-0_25.05.5-1_amd64.deb
# /usr/src/slurm-smd-libslurm-perl_25.05.5-1_amd64.deb
# /usr/src/slurm-smd-openlava_25.05.5-1_all.deb
# /usr/src/slurm-smd-sackd_25.05.5-1_amd64.deb
# /usr/src/slurm-smd-slurmctld_25.05.5-1_amd64.deb
# /usr/src/slurm-smd-slurmd_25.05.5-1_amd64.deb
# /usr/src/slurm-smd-slurmdbd_25.05.5-1_amd64.deb
# /usr/src/slurm-smd-slurmrestd_25.05.5-1_amd64.deb
# /usr/src/slurm-smd-sview_25.05.5-1_amd64.deb
# /usr/src/slurm-smd-torque_25.05.5-1_all.deb
################################################################

# Move deb files
RUN mkdir /usr/src/debs && \
    mv /usr/src/*.deb /usr/src/debs/
