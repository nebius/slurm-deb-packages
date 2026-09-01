ARG BASE_IMAGE=cr.eu-north1.nebius.cloud/ml-containers/training:noble-20260819102426

FROM $BASE_IMAGE

ARG SLURM_VERSION
ARG LD_LIBRARY_PATH
ARG SLURM_SOURCE_URL=

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


# Download Slurm. The default preserves the existing SchedMD build, while a
# source build can provide a different release archive.
RUN set -eux; \
    source_url="${SLURM_SOURCE_URL:-https://download.schedmd.com/slurm/slurm-${SLURM_VERSION}.tar.bz2}"; \
    archive=/tmp/slurm-source-archive; \
    wget -O "${archive}" "${source_url}"; \
    cd /usr/src; \
    tar -xf "${archive}"; \
    rm -f "${archive}"; \
    test -d "slurm-${SLURM_VERSION}"

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
