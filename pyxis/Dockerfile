ARG BASE_IMAGE=cr.eu-north1.nebius.cloud/ml-containers/neubuntu:noble-20260220113744

# Empty by default. Override with a `slurm_debs` build context holding
# slurm-smd and slurm-smd-dev debs to install them instead of the apt ones.
FROM scratch AS slurm_debs

FROM $BASE_IMAGE

ARG SLURM_VERSION
ARG SLURM_APT_VERSION
ARG ENROOT_VERSION
ARG PYXIS_VERSION
# When set, enroot debs are downloaded from this release URL instead of the
# Nebius apt repo (which has no packages for some distributions)
ARG ENROOT_DEBS_URL=

ARG DEBIAN_FRONTEND=noninteractive

# TODO: drop once the neubuntu resolute base image is fixed. Workarounds for it:
# - apt 3 rejects the ASCII-armored Nebius key shipped as nebius.gpg.pub
# - some packages (curl, libcurl4t64) are installed at versions missing from the
#   image's apt snapshot, which breaks installing their -dev counterparts
RUN . /etc/os-release && \
    if [ "${VERSION_CODENAME}" = "resolute" ]; then \
      cp /usr/share/keyrings/nebius.gpg.pub /usr/share/keyrings/nebius.asc && \
      sed -i 's#/usr/share/keyrings/nebius.gpg.pub#/usr/share/keyrings/nebius.asc#' /etc/apt/sources.list.d/nebius.list && \
      apt-get update && \
      pkgs=$(apt list --installed 2>/dev/null | awk -F/ '/\[installed,local\]/ {print $1}' | \
        while read -r p; do \
          v=$(apt-cache madison "$p" | awk -F'|' 'NR==1 {gsub(/ /, "", $2); print $2}'); \
          if [ -n "$v" ]; then echo "$p=$v"; fi; \
        done) && \
      if [ -n "$pkgs" ]; then apt-get install -y --allow-downgrades $pkgs; fi; \
    fi

# Install dependencies
RUN apt-get update && \
    apt -y install \
      git \
      devscripts \
      debhelper \
      fakeroot

# Install enroot (required for pyxis)
RUN apt-get update && \
    if [ -n "${ENROOT_DEBS_URL}" ]; then \
      arch=$(dpkg --print-architecture) && \
      wget -P /tmp/enroot-debs \
        "${ENROOT_DEBS_URL}/enroot_${ENROOT_VERSION}-1_${arch}.deb" \
        "${ENROOT_DEBS_URL}/enroot+caps_${ENROOT_VERSION}-1_${arch}.deb" && \
      apt install -y /tmp/enroot-debs/*.deb && \
      rm -rf /tmp/enroot-debs; \
    else \
      apt install -y enroot=${ENROOT_VERSION}-1 enroot+caps=${ENROOT_VERSION}-1; \
    fi && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -m 777 /usr/share/enroot/enroot-data && \
    mkdir -m 755 /run/enroot && \
    setcap cap_sys_admin+pe /usr/bin/enroot-mksquashovlfs && \
    setcap cap_sys_admin,cap_mknod+pe /usr/bin/enroot-aufs2ovlfs

# Download and build pyxis deb
RUN --mount=type=bind,from=slurm_debs,target=/tmp/slurm-debs \
    apt-get update && \
    if [ -n "$(ls -A /tmp/slurm-debs)" ]; then \
      arch=$(dpkg --print-architecture) && \
      apt install -y \
        "/tmp/slurm-debs/slurm-smd_${SLURM_APT_VERSION}_${arch}.deb" \
        "/tmp/slurm-debs/slurm-smd-dev_${SLURM_APT_VERSION}_${arch}.deb"; \
    else \
      apt install -y slurm-smd=${SLURM_APT_VERSION} slurm-smd-dev=${SLURM_APT_VERSION}; \
    fi && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    cd /usr/src && \
    wget https://github.com/nvidia/pyxis/archive/refs/tags/v"$PYXIS_VERSION".tar.gz && \
    tar -xzvf v"$PYXIS_VERSION".tar.gz && \
    rm v"$PYXIS_VERSION".tar.gz && \
    cd pyxis-"$PYXIS_VERSION" && \
    ARCH=$(uname -m) && \
    export PYXIS_VER="${SLURM_VERSION}-${PYXIS_VERSION}" && \
    sed -i "s|dh_auto_install -- prefix=.*|dh_auto_install -- prefix=/usr libdir=/usr/lib/${ARCH}-linux-gnu datarootdir=/usr/share|" debian/rules && \
    { echo "nvslurm-plugin-pyxis (${SLURM_VERSION}-${PYXIS_VERSION}-1) UNRELEASED; urgency=medium"; echo ""; echo "  * Release ${PYXIS_VERSION} for Slurm ${SLURM_VERSION}"; echo ""; echo " -- NEBIUS <amialiusik@nebius.com>  Tue, 24 Feb 2026 00:17:05 +0000"; echo ""; cat debian/changelog; } > debian/changelog.new && mv debian/changelog.new debian/changelog && \
    make orig && \
    make deb

################################################################
# RESULT
################################################################
#ls -la ../nvslurm-plugin-pyxis_24.11.5-0.23.0-1_amd64.deb
#-rw-r--r-- 1 root root 21698 Jun 19 12:32 ../nvslurm-plugin-pyxis_24.11.5-0.23.0-1_amd64.deb
################################################################

# Move deb files
RUN mkdir /usr/src/debs && \
    mv /usr/src/nvslurm-plugin-pyxis*.deb /usr/src/debs/
